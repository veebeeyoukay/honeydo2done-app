// Task Briefs Generate - Create persona-specific briefs

import { createSupabaseClient, getAuthUser } from '../_shared/supabase.ts';
import {
  storeArtifact,
  sendTaskMessage,
  successResponse,
  errorResponse,
  corsResponse,
} from '../_shared/utils.ts';
import { generateBrief } from '../_shared/ai.ts';
import { selectPersona } from '../_shared/persona.ts';
import type { Task, PersonaType } from '../_shared/types.ts';

interface BriefGeneratePayload {
  target_user_id?: string; // If generating for specific user
  persona_override?: PersonaType; // Force specific persona
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

    const supabase = createSupabaseClient(authHeader);

    // Get task ID from URL
    const url = new URL(req.url);
    const pathParts = url.pathname.split('/');
    const taskId = pathParts[pathParts.length - 2];

    if (!taskId) {
      return errorResponse('MISSING_TASK_ID', 'Task ID is required');
    }

    const payload: BriefGeneratePayload = await req.json().catch(() => ({}));

    console.log('Generating briefs for task:', taskId);

    // Fetch task
    const { data: task, error: taskError } = await supabase
      .from('tasks')
      .select('*')
      .eq('id', taskId)
      .single() as { data: Task | null; error: any };

    if (taskError || !task) {
      return errorResponse('TASK_NOT_FOUND', 'Task not found', taskError);
    }

    const briefs: Record<string, any> = {};

    // Generate brief for creator (Household CEO style)
    const creatorPersona = payload.persona_override ||
      await selectPersona(supabase, task.created_by, taskId);

    const creatorBrief = await generateBrief(taskId, task, creatorPersona);

    if (creatorBrief.ok) {
      const briefType = `ai_brief_${creatorPersona.replace('_', '')}` as any;

      await storeArtifact(
        supabase,
        taskId,
        briefType,
        { brief: creatorBrief.result, recipient: 'creator' },
        creatorBrief.model
      );

      briefs.creator = {
        persona: creatorPersona,
        brief: creatorBrief.result,
      };
    }

    // Generate brief for assignee if exists (Technical Partner style)
    if (task.assigned_to && task.assigned_to !== task.created_by) {
      const assigneePersona = await selectPersona(supabase, task.assigned_to, taskId);

      const assigneeBrief = await generateBrief(taskId, task, assigneePersona);

      if (assigneeBrief.ok) {
        const briefType = `ai_brief_${assigneePersona.replace('_', '')}` as any;

        await storeArtifact(
          supabase,
          taskId,
          briefType,
          { brief: assigneeBrief.result, recipient: 'assignee' },
          assigneeBrief.model
        );

        // Send brief to assignee via task message
        await sendTaskMessage(
          supabase,
          taskId,
          null,
          'ai',
          assigneeBrief.result,
          assigneePersona,
          { recipient: task.assigned_to, brief_type: 'assignment' }
        );

        briefs.assignee = {
          persona: assigneePersona,
          brief: assigneeBrief.result,
        };

        console.log('Assignee brief sent to:', task.assigned_to);
      }
    }

    // Generate brief for specific target user if requested
    if (payload.target_user_id && payload.target_user_id !== task.created_by) {
      const targetPersona = payload.persona_override ||
        await selectPersona(supabase, payload.target_user_id, taskId);

      const targetBrief = await generateBrief(taskId, task, targetPersona);

      if (targetBrief.ok) {
        const briefType = `ai_brief_${targetPersona.replace('_', '')}` as any;

        await storeArtifact(
          supabase,
          taskId,
          briefType,
          { brief: targetBrief.result, recipient: payload.target_user_id },
          targetBrief.model
        );

        briefs.target = {
          persona: targetPersona,
          brief: targetBrief.result,
        };
      }
    }

    console.log('Briefs generated:', Object.keys(briefs));

    return successResponse({
      task_id: taskId,
      briefs,
      count: Object.keys(briefs).length,
    });

  } catch (error) {
    console.error('Brief generation error:', error);
    return errorResponse(
      'BRIEF_GENERATION_ERROR',
      'Failed to generate briefs',
      error instanceof Error ? error.message : String(error),
      500
    );
  }
});
