// Persona selection service - deterministic persona selection logic

import type { PersonaType, User, HouseholdMember, Task } from './types.ts';
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

export interface PersonaContext {
  user: User;
  task?: Task;
  householdMember?: HouseholdMember;
}

/**
 * Select the appropriate persona for a user based on context
 *
 * Priority order:
 * 1. Task-specific override (e.g., DIY mode)
 * 2. Household member persona override
 * 3. Extended family flag (Patient Guide)
 * 4. User's default persona preference
 * 5. Fallback: Household CEO
 */
export async function selectPersona(
  supabase: SupabaseClient,
  userId: string,
  taskId?: string
): Promise<PersonaType> {
  // Fetch user
  const { data: user } = await supabase
    .from('users')
    .select('*')
    .eq('id', userId)
    .single();

  if (!user) {
    return 'household_ceo'; // Default fallback
  }

  // If task is provided, check task-specific context
  if (taskId) {
    const { data: task } = await supabase
      .from('tasks')
      .select('*, household_members!household_id(*)')
      .eq('id', taskId)
      .single();

    if (task) {
      // DIY mode → DIY Mentor
      if (task.is_diy && task.assigned_to === userId) {
        return 'diy_mentor';
      }

      // Extended family → Patient Guide
      if (task.is_extended_family) {
        return 'patient_guide';
      }

      // Check if user is assigned as Technical Partner
      if (task.assigned_to === userId && task.assigned_to !== task.created_by) {
        // Fetch household member role
        const { data: member } = await supabase
          .from('household_members')
          .select('*')
          .eq('household_id', task.household_id)
          .eq('user_id', userId)
          .single();

        if (member?.persona_override) {
          return member.persona_override;
        }

        // Default to Technical Partner for assignees
        return 'technical_partner';
      }
    }
  }

  // Check user's default persona preference
  if (user.persona_type) {
    return user.persona_type;
  }

  // Fallback to Household CEO
  return 'household_ceo';
}

/**
 * Get persona-specific messaging tone and style
 */
export function getPersonaTone(persona: PersonaType): string {
  const tones: Record<PersonaType, string> = {
    household_ceo: `
      Warm, efficient, executive summary style.
      Focus on: what happened, what we're doing, what you need to know/decide.
      Use casual but respectful language.
      Example: "Your router's acting up. Let me ask a couple quick questions so we can get this fixed."
    `,
    technical_partner: `
      Detailed, structured, technical brief style.
      Include: symptoms, diagnostics, likely causes, recommended approach.
      Use precise technical language but remain accessible.
      Example: "WiFi dropping intermittently. Symptoms: 2.4GHz stable, 5GHz drops every 15min. Possible firmware issue or channel interference."
    `,
    patient_guide: `
      Simple, warm, reassuring, step-by-step style.
      Avoid jargon. Use simple analogies. Provide clear next steps.
      Emphasize that help is available.
      Example: "Your internet is having trouble. Don't worry - this happens sometimes. I'm going to help you fix it. First, can you tell me when you first noticed it?"
    `,
    diy_mentor: `
      Instructional, encouraging, safety-first style.
      Provide: clear steps, required tools, safety warnings, stop conditions.
      Encourage but set clear boundaries for when to call a pro.
      Example: "Great! You can handle this. Here's what you'll need: [tools]. IMPORTANT: If you smell gas or see sparks, stop immediately and call a pro."
    `,
  };

  return tones[persona];
}

/**
 * Format a message using persona-specific tone
 */
export function formatWithPersona(
  content: string,
  persona: PersonaType,
  context?: Record<string, any>
): string {
  // This is a simplified version. In production, you'd use Claude to reformat.
  // For MVP, we can use simple templates or pass-through.

  const prefixes: Record<PersonaType, string> = {
    household_ceo: '',
    technical_partner: '**Technical Brief**: ',
    patient_guide: '💙 ',
    diy_mentor: '🔧 ',
  };

  return `${prefixes[persona]}${content}`;
}

/**
 * Determine if triage is complete based on persona
 */
export function isTriageComplete(
  structuredData: Record<string, any>,
  persona: PersonaType
): boolean {
  // Minimum required fields for all personas
  const requiredFields = ['category', 'symptoms', 'urgency'];

  const hasRequired = requiredFields.every(field =>
    structuredData[field] &&
    (Array.isArray(structuredData[field]) ? structuredData[field].length > 0 : true)
  );

  // Patient Guide needs less detail
  if (persona === 'patient_guide') {
    return hasRequired;
  }

  // Technical Partner needs more detail
  if (persona === 'technical_partner') {
    const technicalFields = ['location_in_home', 'duration', 'what_tried'];
    return hasRequired && technicalFields.every(field => structuredData[field]);
  }

  // Standard completeness
  return hasRequired && (structuredData.location_in_home || structuredData.duration);
}
