// Lindy Webhook - Voice/SMS intake endpoint

import { createSupabaseClient } from '../_shared/supabase.ts';
import {
  findOrCreateUserByPhone,
  logTaskEvent,
  storeArtifact,
  updateTaskStatus,
  successResponse,
  errorResponse,
  corsResponse,
  triggerN8nWorkflow,
  verifyLindySignature,
} from '../_shared/utils.ts';
import { extractStructuredData } from '../_shared/ai.ts';
import { selectPersona } from '../_shared/persona.ts';
import type { LindyWebhookPayload } from '../_shared/types.ts';

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return corsResponse();
  }

  if (req.method !== 'POST') {
    return errorResponse('METHOD_NOT_ALLOWED', 'Only POST requests are allowed', null, 405);
  }

  try {
    // Verify webhook signature
    const signature = req.headers.get('x-lindy-signature') || '';
    const webhookSecret = Deno.env.get('LINDY_WEBHOOK_SECRET') || '';

    const body = await req.text();

    if (webhookSecret && !verifyLindySignature(body, signature, webhookSecret)) {
      console.warn('Invalid webhook signature');
      return errorResponse('INVALID_SIGNATURE', 'Webhook signature verification failed', null, 401);
    }

    // Parse payload
    const payload: LindyWebhookPayload = JSON.parse(body);

    console.log('Lindy webhook received:', {
      event: payload.event,
      phone: payload.phone_number,
    });

    // Create service role client (bypasses RLS)
    const supabase = createSupabaseClient();

    // Find or create user
    const userId = await findOrCreateUserByPhone(
      supabase,
      payload.phone_number,
      payload.extracted_data?.name
    );

    console.log('User resolved:', userId);

    // Get user's household
    const { data: household } = await supabase
      .from('household_members')
      .select('household_id')
      .eq('user_id', userId)
      .single();

    if (!household) {
      throw new Error('User has no household');
    }

    // Create task in 'captured' status
    const taskTitle = payload.extracted_data?.title ||
      `Task from ${payload.phone_number.slice(-4)} - ${new Date().toLocaleString()}`;

    const { data: task, error: taskError } = await supabase
      .from('tasks')
      .insert({
        household_id: household.household_id,
        created_by: userId,
        title: taskTitle,
        description: payload.transcript,
        status: 'captured',
        priority: 'normal',
      })
      .select()
      .single();

    if (taskError || !task) {
      console.error('Failed to create task:', taskError);
      throw new Error('Failed to create task');
    }

    console.log('Task created:', task.id);

    // Store transcript as artifact
    await storeArtifact(
      supabase,
      task.id,
      'transcript',
      {
        source: 'lindy',
        event_type: payload.event,
        transcript: payload.transcript,
        extracted_data: payload.extracted_data || {},
      }
    );

    // Log task creation event
    await logTaskEvent(
      supabase,
      task.id,
      'created',
      'user',
      userId,
      {
        source: 'lindy_webhook',
        phone: payload.phone_number,
      }
    );

    // Select persona for AI processing
    const persona = await selectPersona(supabase, userId, task.id);

    // Extract structured data using AI
    const aiExtraction = await extractStructuredData(
      task.id,
      payload.transcript,
      undefined,
      persona
    );

    if (aiExtraction.ok) {
      // Update task with structured data
      await supabase
        .from('tasks')
        .update({
          structured_data: aiExtraction.result,
          category: aiExtraction.result.category,
          priority: aiExtraction.result.urgency || 'normal',
        })
        .eq('id', task.id);

      // Store AI extraction artifact
      await storeArtifact(
        supabase,
        task.id,
        'ai_structured_extract',
        aiExtraction.result,
        aiExtraction.model,
        aiExtraction.confidence
      );

      console.log('AI extraction completed:', aiExtraction.result.category);
    }

    // Update status to 'triaging' and trigger triage workflow
    await updateTaskStatus(
      supabase,
      task.id,
      'triaging',
      null,
      'system'
    );

    // Trigger n8n workflow for task processing
    await triggerN8nWorkflow('new-task-processing', {
      task_id: task.id,
      user_id: userId,
      phone: payload.phone_number,
      persona,
    });

    console.log('Task processing workflow triggered');

    return successResponse({
      task_id: task.id,
      status: 'captured',
      next_step: 'triage',
      message: 'Task captured successfully. Triage questions will be sent shortly.',
    });

  } catch (error) {
    console.error('Webhook processing error:', error);
    return errorResponse(
      'WEBHOOK_ERROR',
      'Failed to process webhook',
      error instanceof Error ? error.message : String(error),
      500
    );
  }
});
