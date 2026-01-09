// Task DIY Start - Generate DIY plan and start DIY mode

import { createSupabaseClient, getAuthUser } from '../_shared/supabase.ts';
import {
  logTaskEvent,
  storeArtifact,
  sendTaskMessage,
  updateTaskStatus,
  successResponse,
  errorResponse,
  corsResponse,
} from '../_shared/utils.ts';
import { generateDIYPlan } from '../_shared/ai.ts';
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

    console.log('Starting DIY mode for task:', taskId);

    // Fetch task
    const { data: task, error: taskError } = await supabase
      .from('tasks')
      .select('*')
      .eq('id', taskId)
      .single() as { data: Task | null; error: any };

    if (taskError || !task) {
      return errorResponse('TASK_NOT_FOUND', 'Task not found', taskError);
    }

    // Verify user has access (creator or assignee)
    if (task.created_by !== userId && task.assigned_to !== userId) {
      return errorResponse('UNAUTHORIZED', 'You do not have access to this task', null, 403);
    }

    // Check if task is in valid state
    if (task.status !== 'awaiting_decision' && task.status !== 'captured') {
      return errorResponse(
        'INVALID_STATUS',
        `Cannot start DIY from status: ${task.status}`
      );
    }

    // Check for safety flags
    const safetyFlags = task.structured_data?.safety_flags || [];
    const hasCriticalSafety = safetyFlags.some((flag: string) =>
      ['electrical_risk', 'gas_smell', 'structural'].includes(flag)
    );

    if (hasCriticalSafety) {
      console.warn('Task has critical safety flags:', safetyFlags);

      // Still allow but warn heavily
      await sendTaskMessage(
        supabase,
        taskId,
        null,
        'system',
        '⚠️ **SAFETY WARNING**: This task involves potential safety risks. Please carefully review the safety warnings in the DIY plan. If you are not comfortable at any point, stop and contact a professional.',
        'diy_mentor'
      );
    }

    // Generate DIY plan
    const diyPlan = await generateDIYPlan(taskId, task, 'diy_mentor');

    if (!diyPlan.ok || !diyPlan.result) {
      console.error('Failed to generate DIY plan');

      await sendTaskMessage(
        supabase,
        taskId,
        null,
        'ai',
        '❌ I was unable to generate a safe DIY plan for this task. I recommend getting a professional to help. Would you like me to find a pro?',
        'diy_mentor'
      );

      return errorResponse(
        'DIY_PLAN_FAILED',
        'Unable to generate DIY plan. Task may require professional help.',
        diyPlan.warnings
      );
    }

    // Store DIY plan
    await storeArtifact(
      supabase,
      taskId,
      'ai_diy_plan',
      diyPlan.result,
      diyPlan.model
    );

    // Format DIY plan message
    const planMessage = formatDIYPlan(diyPlan.result);

    // Send plan to task chat
    await sendTaskMessage(
      supabase,
      taskId,
      null,
      'ai',
      planMessage,
      'diy_mentor',
      { diy_plan: diyPlan.result }
    );

    // Update task to DIY mode
    await updateTaskStatus(
      supabase,
      taskId,
      'diy_in_progress',
      userId,
      'user',
      {
        is_diy: true,
        assigned_to: userId, // Assign to the user starting DIY
        started_at: new Date().toISOString(),
      }
    );

    // Log event
    await logTaskEvent(
      supabase,
      taskId,
      'diy_started',
      'user',
      userId,
      {
        difficulty: diyPlan.result.difficulty,
        time_estimate: diyPlan.result.time_estimate_minutes,
        safety_warnings: diyPlan.result.safety_warnings?.length || 0,
      }
    );

    console.log('DIY mode started successfully');

    return successResponse({
      task_id: taskId,
      status: 'diy_in_progress',
      diy_plan: diyPlan.result,
      message: 'DIY plan generated. Good luck!',
    });

  } catch (error) {
    console.error('DIY start error:', error);
    return errorResponse(
      'DIY_START_ERROR',
      'Failed to start DIY mode',
      error instanceof Error ? error.message : String(error),
      500
    );
  }
});

function formatDIYPlan(plan: any): string {
  let message = `🔧 **DIY Plan: ${plan.title}**\n\n`;

  message += `⏱️ **Time**: ~${plan.time_estimate_minutes} minutes\n`;
  message += `📊 **Difficulty**: ${plan.difficulty}\n\n`;

  // Safety warnings (PROMINENT)
  if (plan.safety_warnings && plan.safety_warnings.length > 0) {
    message += `⚠️ **SAFETY WARNINGS**\n`;
    plan.safety_warnings.forEach((warning: string) => {
      message += `• ${warning}\n`;
    });
    message += `\n`;
  }

  // Stop conditions
  if (plan.stop_conditions && plan.stop_conditions.length > 0) {
    message += `🛑 **Stop and call a pro if:**\n`;
    plan.stop_conditions.forEach((condition: string) => {
      message += `• ${condition}\n`;
    });
    message += `\n`;
  }

  // Tools needed
  if (plan.tools_needed && plan.tools_needed.length > 0) {
    message += `🔨 **Tools Needed**\n`;
    plan.tools_needed.forEach((tool: string) => {
      message += `• ${tool}\n`;
    });
    message += `\n`;
  }

  // Materials
  if (plan.materials_needed && plan.materials_needed.length > 0) {
    message += `📦 **Materials Needed**\n`;
    plan.materials_needed.forEach((material: string) => {
      message += `• ${material}\n`;
    });
    message += `\n`;
  }

  // Steps
  message += `📝 **Steps**\n\n`;
  plan.steps.forEach((step: any) => {
    message += `**${step.number}. ${step.title}**\n`;
    message += `${step.instruction}\n`;
    if (step.safety_note) {
      message += `⚠️ *${step.safety_note}*\n`;
    }
    message += `\n`;
  });

  // Verification
  if (plan.verification) {
    message += `✅ **Verification**\n${plan.verification}\n\n`;
  }

  // If it doesn't work
  if (plan.if_it_doesnt_work) {
    message += `🔄 **If it doesn't work**\n${plan.if_it_doesnt_work}\n`;
  }

  return message;
}
