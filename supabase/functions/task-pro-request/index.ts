// Task Pro Request - Request professional help

import { createSupabaseClient, getAuthUser } from '../_shared/supabase.ts';
import {
  logTaskEvent,
  updateTaskStatus,
  successResponse,
  errorResponse,
  corsResponse,
  triggerN8nWorkflow,
} from '../_shared/utils.ts';
import type { Task, TaskCategory } from '../_shared/types.ts';

interface ProRequestPayload {
  notes?: string;
  preferred_date?: string;
  urgency?: 'normal' | 'urgent';
}

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

    if (!userId) {
      return errorResponse('UNAUTHORIZED', 'Authentication required', null, 401);
    }

    const supabase = createSupabaseClient(authHeader);

    // Get task ID from URL
    const url = new URL(req.url);
    const pathParts = url.pathname.split('/');
    const taskId = pathParts[pathParts.length - 2];

    if (!taskId) {
      return errorResponse('MISSING_TASK_ID', 'Task ID is required');
    }

    const payload: ProRequestPayload = await req.json().catch(() => ({}));

    console.log('Requesting pro for task:', taskId);

    // Fetch task with property info
    const { data: task, error: taskError } = await supabase
      .from('tasks')
      .select('*, properties(*)')
      .eq('id', taskId)
      .single() as { data: any; error: any };

    if (taskError || !task) {
      return errorResponse('TASK_NOT_FOUND', 'Task not found', taskError);
    }

    // Verify user has access
    if (task.created_by !== userId) {
      return errorResponse('UNAUTHORIZED', 'Only task creator can request a pro', null, 403);
    }

    // Check if task is in valid state
    const validStatuses = ['awaiting_decision', 'captured', 'triaging', 'diy_in_progress'];
    if (!validStatuses.includes(task.status)) {
      return errorResponse(
        'INVALID_STATUS',
        `Cannot request pro from status: ${task.status}`
      );
    }

    // Get estimate range from structured data or AI decision
    let estimateRangeLow = 100;
    let estimateRangeHigh = 300;

    // Try to get from AI artifacts
    const { data: artifacts } = await supabase
      .from('task_artifacts')
      .select('content')
      .eq('task_id', taskId)
      .eq('type', 'ai_structured_extract')
      .order('created_at', { ascending: false })
      .limit(1);

    if (artifacts && artifacts.length > 0) {
      const decisionPrompt = artifacts[0].content?.decision_prompt;
      if (decisionPrompt?.pro_estimate_range) {
        estimateRangeLow = decisionPrompt.pro_estimate_range.low;
        estimateRangeHigh = decisionPrompt.pro_estimate_range.high;
      }
    }

    // Create partner request
    const { data: partnerRequest, error: prError } = await supabase
      .from('partner_requests')
      .insert({
        task_id: taskId,
        status: 'draft',
        estimate_range_low: estimateRangeLow,
        estimate_range_high: estimateRangeHigh,
        notes: payload.notes,
        scheduled_at: payload.preferred_date || null,
      })
      .select()
      .single();

    if (prError || !partnerRequest) {
      console.error('Failed to create partner request:', prError);
      throw new Error('Failed to create partner request');
    }

    // Update task
    await updateTaskStatus(
      supabase,
      taskId,
      'pro_requested',
      userId,
      'user',
      {
        wants_pro: true,
        is_diy: false, // Cancel DIY if it was active
      }
    );

    // Log event
    await logTaskEvent(
      supabase,
      taskId,
      'pro_requested',
      'user',
      userId,
      {
        partner_request_id: partnerRequest.id,
        estimate_range: `$${estimateRangeLow}-$${estimateRangeHigh}`,
        urgency: payload.urgency,
      }
    );

    // Trigger n8n workflow for partner matching
    await triggerN8nWorkflow('pro-request-to-booking', {
      task_id: taskId,
      partner_request_id: partnerRequest.id,
      category: task.category,
      zip: task.properties?.zip,
      urgency: payload.urgency || 'normal',
      estimate_range: {
        low: estimateRangeLow,
        high: estimateRangeHigh,
      },
    });

    console.log('Pro request created, workflow triggered');

    return successResponse({
      task_id: taskId,
      partner_request_id: partnerRequest.id,
      status: 'pro_requested',
      estimate_range: {
        low: estimateRangeLow,
        high: estimateRangeHigh,
      },
      message: 'Pro request created. We\'re finding the best match for you!',
      next_steps: 'You\'ll receive updates as partners respond.',
    });

  } catch (error) {
    console.error('Pro request error:', error);
    return errorResponse(
      'PRO_REQUEST_ERROR',
      'Failed to request pro',
      error instanceof Error ? error.message : String(error),
      500
    );
  }
});
