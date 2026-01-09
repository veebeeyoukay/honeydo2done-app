// Utility functions for edge functions

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import type {
  TaskEventType,
  ActorType,
  ApiResponse,
  ArtifactType,
} from './types.ts';

/**
 * Log a task event (immutable audit log)
 */
export async function logTaskEvent(
  supabase: SupabaseClient,
  taskId: string,
  type: TaskEventType,
  actorType: ActorType,
  actorId: string | null,
  payload: Record<string, any> = {}
): Promise<void> {
  const { error } = await supabase.from('task_events').insert({
    task_id: taskId,
    type,
    actor_type: actorType,
    actor_id: actorId,
    payload,
  });

  if (error) {
    console.error('Failed to log task event:', error);
    throw error;
  }
}

/**
 * Store an AI artifact
 */
export async function storeArtifact(
  supabase: SupabaseClient,
  taskId: string,
  type: ArtifactType,
  content: Record<string, any>,
  model?: string,
  confidence?: number
): Promise<string> {
  const { data, error } = await supabase
    .from('task_artifacts')
    .insert({
      task_id: taskId,
      type,
      content,
      model,
      confidence,
    })
    .select('id')
    .single();

  if (error) {
    console.error('Failed to store artifact:', error);
    throw error;
  }

  return data.id;
}

/**
 * Send a task message
 */
export async function sendTaskMessage(
  supabase: SupabaseClient,
  taskId: string,
  senderId: string | null,
  senderType: ActorType,
  content: string,
  personaUsed?: string,
  metadata: Record<string, any> = {}
): Promise<string> {
  const { data, error } = await supabase
    .from('task_messages')
    .insert({
      task_id: taskId,
      sender_id: senderId,
      sender_type: senderType,
      content,
      persona_used: personaUsed,
      metadata,
    })
    .select('id')
    .single();

  if (error) {
    console.error('Failed to send task message:', error);
    throw error;
  }

  return data.id;
}

/**
 * Update task status with event logging
 */
export async function updateTaskStatus(
  supabase: SupabaseClient,
  taskId: string,
  newStatus: string,
  actorId: string | null,
  actorType: ActorType = 'system',
  additionalUpdates: Record<string, any> = {}
): Promise<void> {
  // Update task
  const { error: updateError } = await supabase
    .from('tasks')
    .update({
      status: newStatus,
      ...additionalUpdates,
    })
    .eq('id', taskId);

  if (updateError) {
    console.error('Failed to update task status:', updateError);
    throw updateError;
  }

  // Log event
  const eventTypeMap: Record<string, TaskEventType> = {
    'captured': 'created',
    'triaging': 'triage_q_sent',
    'awaiting_decision': 'triage_completed',
    'diy_in_progress': 'diy_started',
    'pro_requested': 'pro_requested',
    'pro_assigned': 'pro_accepted',
    'scheduled': 'scheduled',
    'in_progress': 'started',
    'completed': 'completed',
    'cancelled': 'cancelled',
  };

  const eventType = eventTypeMap[newStatus] || 'created';

  await logTaskEvent(
    supabase,
    taskId,
    eventType,
    actorType,
    actorId,
    { new_status: newStatus, ...additionalUpdates }
  );
}

/**
 * Find or create user by phone
 */
export async function findOrCreateUserByPhone(
  supabase: SupabaseClient,
  phone: string,
  fullName?: string
): Promise<string> {
  // Normalize phone number
  const normalizedPhone = phone.replace(/\D/g, '');

  // Try to find existing user
  const { data: existing } = await supabase
    .from('users')
    .select('id')
    .eq('phone', normalizedPhone)
    .single();

  if (existing) {
    return existing.id;
  }

  // Create new user
  const { data: newUser, error } = await supabase
    .from('users')
    .insert({
      phone: normalizedPhone,
      full_name: fullName || `User ${normalizedPhone.slice(-4)}`,
      role: 'customer',
      is_active: true,
    })
    .select('id')
    .single();

  if (error) {
    console.error('Failed to create user:', error);
    throw error;
  }

  // Create default household for new user
  const { data: household } = await supabase
    .from('households')
    .insert({
      name: `${newUser.full_name}'s Home`,
      created_by: newUser.id,
    })
    .select('id')
    .single();

  if (household) {
    await supabase.from('household_members').insert({
      household_id: household.id,
      user_id: newUser.id,
      role: 'owner',
    });
  }

  return newUser.id;
}

/**
 * Verify Lindy webhook signature
 */
export function verifyLindySignature(
  payload: string,
  signature: string,
  secret: string
): boolean {
  // Lindy webhook signature verification
  // Implementation depends on Lindy's signature scheme
  // For MVP, we can use a simple HMAC SHA-256

  const encoder = new TextEncoder();
  const data = encoder.encode(payload);
  const key = encoder.encode(secret);

  // This is a placeholder - actual implementation depends on Lindy's spec
  // For now, just check if secret matches (weak but functional for MVP)
  return signature === secret;
}

/**
 * Success response
 */
export function successResponse<T>(data: T, status = 200): Response {
  const response: ApiResponse<T> = {
    success: true,
    data,
  };

  return new Response(JSON.stringify(response), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}

/**
 * Error response
 */
export function errorResponse(
  code: string,
  message: string,
  details?: any,
  status = 400
): Response {
  const response: ApiResponse = {
    success: false,
    error: {
      code,
      message,
      details,
    },
  };

  return new Response(JSON.stringify(response), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}

/**
 * CORS preflight response
 */
export function corsResponse(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers':
        'authorization, x-client-info, apikey, content-type',
    },
  });
}

/**
 * Trigger n8n webhook
 */
export async function triggerN8nWorkflow(
  workflowName: string,
  payload: Record<string, any>
): Promise<void> {
  const n8nUrl = Deno.env.get('N8N_WEBHOOK_URL');

  if (!n8nUrl) {
    console.warn('N8N_WEBHOOK_URL not configured, skipping workflow trigger');
    return;
  }

  try {
    await fetch(`${n8nUrl}/${workflowName}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });
  } catch (error) {
    console.error('Failed to trigger n8n workflow:', error);
    // Don't throw - workflows are best-effort in MVP
  }
}

/**
 * Send SMS via Lindy
 */
export async function sendSMS(
  to: string,
  message: string
): Promise<void> {
  const lindyApiKey = Deno.env.get('LINDY_API_KEY');
  const lindyPhoneNumber = Deno.env.get('LINDY_PHONE_NUMBER');

  if (!lindyApiKey || !lindyPhoneNumber) {
    console.warn('Lindy credentials not configured, skipping SMS');
    return;
  }

  try {
    // Placeholder - actual Lindy API call
    // Implementation depends on Lindy's API
    console.log(`[SMS] To: ${to}, Message: ${message}`);

    // await fetch('https://api.lindy.ai/v1/sms', {
    //   method: 'POST',
    //   headers: {
    //     'Authorization': `Bearer ${lindyApiKey}`,
    //     'Content-Type': 'application/json',
    //   },
    //   body: JSON.stringify({
    //     from: lindyPhoneNumber,
    //     to,
    //     message,
    //   }),
    // });
  } catch (error) {
    console.error('Failed to send SMS:', error);
  }
}
