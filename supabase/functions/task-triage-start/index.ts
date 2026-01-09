// Task Triage Start - Generate and send triage questions

import { createSupabaseClient, getAuthUser } from '../_shared/supabase.ts';
import {
  logTaskEvent,
  storeArtifact,
  sendTaskMessage,
  updateTaskStatus,
  successResponse,
  errorResponse,
  corsResponse,
  sendSMS,
} from '../_shared/utils.ts';
import { generateTriageQuestions } from '../_shared/ai.ts';
import { selectPersona } from '../_shared/persona.ts';
import type { Task } from '../_shared/types.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return corsResponse();
  }

  if (req.method !== 'POST') {
    return errorResponse('METHOD_NOT_ALLOWED', 'Only POST requests are allowed', null, 405);
  }

  try {
    const authHeader = req.headers.get('Authorization');
    const userId = getAuthUser(authHeader);

    // Can be called by user or system (service role)
    const supabase = createSupabaseClient(authHeader);

    // Get task ID from URL path or body
    const url = new URL(req.url);
    const pathParts = url.pathname.split('/');
    const taskId = pathParts[pathParts.length - 2]; // Expecting /task-triage-start/{taskId}

    if (!taskId) {
      return errorResponse('MISSING_TASK_ID', 'Task ID is required');
    }

    console.log('Starting triage for task:', taskId);

    // Fetch task
    const { data: task, error: taskError } = await supabase
      .from('tasks')
      .select('*')
      .eq('id', taskId)
      .single() as { data: Task | null; error: any };

    if (taskError || !task) {
      return errorResponse('TASK_NOT_FOUND', 'Task not found', taskError);
    }

    // Check if task is in correct state
    if (task.status !== 'captured' && task.status !== 'triaging') {
      return errorResponse(
        'INVALID_STATUS',
        `Task must be in 'captured' or 'triaging' status. Current: ${task.status}`
      );
    }

    // Select persona
    const persona = await selectPersona(supabase, task.created_by, taskId);

    // Generate triage questions
    const aiQuestions = await generateTriageQuestions(
      taskId,
      task.description,
      task.structured_data,
      persona
    );

    if (!aiQuestions.ok) {
      console.warn('AI question generation failed, using fallback');
    }

    // Store questions as artifact
    await storeArtifact(
      supabase,
      taskId,
      'ai_triage_questions',
      aiQuestions.result,
      aiQuestions.model
    );

    // Format questions for messaging
    const questionText = aiQuestions.result.questions
      .map((q, i) => `${i + 1}. ${q.prompt}`)
      .join('\n\n');

    const introMessage = persona === 'patient_guide'
      ? "💙 Let me help you with this. I have a few quick questions to understand the situation better:"
      : "I have a couple quick questions to help figure out the best solution:";

    const fullMessage = `${introMessage}\n\n${questionText}\n\nReply with your answers whenever you're ready.`;

    // Send message in task chat
    await sendTaskMessage(
      supabase,
      taskId,
      null, // AI sender
      'ai',
      fullMessage,
      persona,
      {
        questions: aiQuestions.result.questions,
        question_ids: aiQuestions.result.questions.map(q => q.id),
      }
    );

    // Log event
    await logTaskEvent(
      supabase,
      taskId,
      'triage_q_sent',
      'ai',
      null,
      {
        persona,
        question_count: aiQuestions.result.questions.length,
      }
    );

    // Update task status to triaging
    if (task.status === 'captured') {
      await updateTaskStatus(supabase, taskId, 'triaging', null, 'system');
    }

    // Get user phone for SMS
    const { data: user } = await supabase
      .from('users')
      .select('phone')
      .eq('id', task.created_by)
      .single();

    if (user?.phone) {
      await sendSMS(user.phone, fullMessage);
      console.log('Triage questions sent via SMS');
    }

    console.log('Triage started successfully');

    return successResponse({
      task_id: taskId,
      questions: aiQuestions.result.questions,
      message_sent: true,
      sms_sent: !!user?.phone,
    });

  } catch (error) {
    console.error('Triage start error:', error);
    return errorResponse(
      'TRIAGE_START_ERROR',
      'Failed to start triage',
      error instanceof Error ? error.message : String(error),
      500
    );
  }
});
