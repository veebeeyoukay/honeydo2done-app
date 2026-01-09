// Task Triage Answer - Process user answers and update task

import { createSupabaseClient, getAuthUser } from '../_shared/supabase.ts';
import {
  logTaskEvent,
  storeArtifact,
  sendTaskMessage,
  updateTaskStatus,
  successResponse,
  errorResponse,
  corsResponse,
  triggerN8nWorkflow,
} from '../_shared/utils.ts';
import { extractStructuredData, generateDecisionPrompt } from '../_shared/ai.ts';
import { selectPersona, isTriageComplete } from '../_shared/persona.ts';
import type { Task } from '../_shared/types.ts';

interface TriageAnswerPayload {
  answers: Record<string, any>; // question_id: answer
  answer_text?: string; // Raw text if from SMS
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

    const payload: TriageAnswerPayload = await req.json();

    console.log('Processing triage answers for task:', taskId);

    // Fetch task
    const { data: task, error: taskError } = await supabase
      .from('tasks')
      .select('*')
      .eq('id', taskId)
      .single() as { data: Task | null; error: any };

    if (taskError || !task) {
      return errorResponse('TASK_NOT_FOUND', 'Task not found', taskError);
    }

    // Verify user has access
    if (userId && task.created_by !== userId && task.assigned_to !== userId) {
      return errorResponse('UNAUTHORIZED', 'You do not have access to this task', null, 403);
    }

    // Store answers in task_messages
    const answerText = payload.answer_text ||
      Object.entries(payload.answers)
        .map(([qId, answer]) => `${qId}: ${answer}`)
        .join('\n');

    await sendTaskMessage(
      supabase,
      taskId,
      userId || task.created_by,
      'user',
      answerText,
      undefined,
      { answers: payload.answers }
    );

    // Log event
    await logTaskEvent(
      supabase,
      taskId,
      'triage_a_received',
      'user',
      userId || task.created_by,
      { answers: payload.answers }
    );

    // Merge answers into triage_data
    const updatedTriageData = {
      ...task.triage_data,
      ...payload.answers,
    };

    // Re-extract structured data with new information
    const combinedDescription = `${task.description}\n\nAdditional info: ${answerText}`;

    const persona = await selectPersona(supabase, task.created_by, taskId);

    const aiExtraction = await extractStructuredData(
      taskId,
      combinedDescription,
      task.structured_data,
      persona
    );

    let updatedStructuredData = task.structured_data;

    if (aiExtraction.ok) {
      updatedStructuredData = {
        ...task.structured_data,
        ...aiExtraction.result,
      };

      // Store updated extraction
      await storeArtifact(
        supabase,
        taskId,
        'ai_structured_extract',
        updatedStructuredData,
        aiExtraction.model,
        aiExtraction.confidence
      );
    }

    // Update task
    await supabase
      .from('tasks')
      .update({
        triage_data: updatedTriageData,
        structured_data: updatedStructuredData,
        category: updatedStructuredData.category || task.category,
        priority: updatedStructuredData.urgency || task.priority,
      })
      .eq('id', taskId);

    // Check if triage is complete
    const triageComplete = isTriageComplete(updatedStructuredData, persona);

    console.log('Triage complete:', triageComplete);

    if (triageComplete) {
      // Generate decision prompt
      const decisionPrompt = await generateDecisionPrompt(
        taskId,
        { ...task, structured_data: updatedStructuredData },
        persona
      );

      if (decisionPrompt.ok) {
        // Store decision prompt
        await storeArtifact(
          supabase,
          taskId,
          'ai_structured_extract',
          { decision_prompt: decisionPrompt.result },
          decisionPrompt.model
        );

        // Send decision options to user
        const decisionMessage = formatDecisionMessage(decisionPrompt.result, persona);

        await sendTaskMessage(
          supabase,
          taskId,
          null,
          'ai',
          decisionMessage,
          persona,
          { decision_prompt: decisionPrompt.result }
        );
      }

      // Update to awaiting_decision
      await updateTaskStatus(
        supabase,
        taskId,
        'awaiting_decision',
        null,
        'system',
        { triage_completed_at: new Date().toISOString() }
      );

      // Trigger decision workflow
      await triggerN8nWorkflow('task-decision-ready', {
        task_id: taskId,
        user_id: task.created_by,
        recommendation: decisionPrompt.result?.recommendation,
      });

      return successResponse({
        task_id: taskId,
        triage_complete: true,
        status: 'awaiting_decision',
        decision_options: decisionPrompt.result,
      });
    }

    // Triage not complete - might need more questions
    return successResponse({
      task_id: taskId,
      triage_complete: false,
      status: 'triaging',
      message: 'Thanks! I may have a few more questions.',
    });

  } catch (error) {
    console.error('Triage answer error:', error);
    return errorResponse(
      'TRIAGE_ANSWER_ERROR',
      'Failed to process triage answer',
      error instanceof Error ? error.message : String(error),
      500
    );
  }
});

function formatDecisionMessage(decision: any, persona: string): string {
  const { recommendation, why, diy_assessment, pro_estimate_range } = decision;

  let message = '';

  if (persona === 'patient_guide') {
    message = `💙 Okay, I understand the situation. Here's what I recommend:\n\n`;
  } else {
    message = `Based on what you've told me, here's my recommendation:\n\n`;
  }

  if (recommendation === 'diy') {
    message += `✅ **You can handle this yourself!**\n\n`;
    message += `Difficulty: ${diy_assessment.difficulty}\n`;
    message += `Time: ~${diy_assessment.time_estimate_minutes} minutes\n\n`;
    message += why.join('\n');
    message += `\n\nWould you like DIY instructions?`;
  } else if (recommendation === 'assign') {
    message += `🔧 **This might be good for your household's tech person.**\n\n`;
    message += why.join('\n');
    message += `\n\nWho should handle this?`;
  } else {
    message += `👨‍🔧 **I recommend getting a pro for this one.**\n\n`;
    message += why.join('\n');
    message += `\n\nEstimate: $${pro_estimate_range.low} - $${pro_estimate_range.high}`;
    message += `\n\nWould you like me to find a pro?`;
  }

  return message;
}
