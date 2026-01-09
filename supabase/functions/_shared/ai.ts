// AI Service Layer - Claude integration with structured outputs

import type {
  AIResponse,
  PersonaType,
  StructuredTaskData,
  TriageQuestions,
  DecisionPrompt,
  Task,
} from './types.ts';
import { getPersonaTone } from './persona.ts';

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY');
const ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages';
const MODEL = 'claude-opus-4-5';

interface ClaudeMessage {
  role: 'user' | 'assistant';
  content: string;
}

async function callClaude(
  messages: ClaudeMessage[],
  systemPrompt: string,
  temperature = 0.3
): Promise<any> {
  if (!ANTHROPIC_API_KEY) {
    throw new Error('ANTHROPIC_API_KEY not configured');
  }

  const response = await fetch(ANTHROPIC_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 4096,
      temperature,
      system: systemPrompt,
      messages,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    console.error('Claude API error:', error);
    throw new Error(`Claude API error: ${response.status}`);
  }

  const result = await response.json();
  return result;
}

/**
 * Extract structured data from task description
 */
export async function extractStructuredData(
  taskId: string,
  description: string,
  existingData?: Partial<StructuredTaskData>,
  persona: PersonaType = 'household_ceo'
): Promise<AIResponse<StructuredTaskData>> {
  const systemPrompt = `You are an AI assistant for HoneyDo2Done, a home task management platform.
Extract structured information from home task descriptions.

${getPersonaTone(persona)}

CRITICAL: Return ONLY valid JSON in the exact format specified. No explanations, no markdown.

Output format:
{
  "category": "smart_home|tech_guard|aqua_tech|garage_tech|hvac|electrical|plumbing|general|other",
  "location_in_home": "string",
  "symptoms": ["string"],
  "duration": "string",
  "patterns": ["string"],
  "what_tried": ["string"],
  "urgency": "low|normal|high|urgent",
  "attachments_needed": ["string"],
  "likely_trade": "wifi|plumbing|electrical|pool|hvac|general",
  "safety_flags": ["electrical_risk|water_leak|gas_smell|ladder_required|structural"],
  "confidence": 0.0-1.0
}

Safety flags are CRITICAL:
- electrical_risk: Any mention of outlets, wiring, breakers, shocks, buzzing
- water_leak: Active water flow, flooding, burst pipes
- gas_smell: Any gas odor (URGENT)
- ladder_required: High ceiling, roof, second story
- structural: Cracks, sagging, foundation issues`;

  const userPrompt = `Task description: "${description}"

${existingData ? `Existing extracted data: ${JSON.stringify(existingData, null, 2)}` : ''}

Extract structured data. Return ONLY the JSON object, nothing else.`;

  try {
    const response = await callClaude(
      [{ role: 'user', content: userPrompt }],
      systemPrompt,
      0.2 // Low temperature for extraction
    );

    const content = response.content[0].text;
    const parsed = JSON.parse(content);

    return {
      ok: true,
      persona_used: persona,
      task_id: taskId,
      result: parsed,
      warnings: parsed.safety_flags || [],
      model: MODEL,
      confidence: parsed.confidence || 0,
    };
  } catch (error) {
    console.error('AI extraction error:', error);
    return {
      ok: false,
      persona_used: persona,
      task_id: taskId,
      result: existingData || {},
      warnings: ['ai_error', 'low_confidence'],
      confidence: 0,
    };
  }
}

/**
 * Generate triage questions
 */
export async function generateTriageQuestions(
  taskId: string,
  description: string,
  structuredData: StructuredTaskData,
  persona: PersonaType
): Promise<AIResponse<TriageQuestions>> {
  const systemPrompt = `You are an AI assistant for HoneyDo2Done.
Generate 2-3 clarifying questions to complete task triage.

${getPersonaTone(persona)}

CRITICAL: Return ONLY valid JSON. No explanations.

Output format:
{
  "questions": [
    {
      "id": "q1",
      "prompt": "string - the question to ask",
      "answer_type": "text|choice|number|photo|yesno",
      "choices": ["option1", "option2"] // only for choice type
      "required": true
    }
  ],
  "stop_after": 3
}

Question strategy:
- Ask about MISSING critical fields first
- Adapt to persona (Patient Guide = simpler, Technical Partner = detailed)
- For safety flags, ask confirming questions
- Keep questions conversational, not form-like`;

  const userPrompt = `Task: "${description}"

Current data: ${JSON.stringify(structuredData, null, 2)}

Missing or unclear: ${getMissingFields(structuredData).join(', ')}

Generate 2-3 questions to complete triage. Return ONLY the JSON object.`;

  try {
    const response = await callClaude(
      [{ role: 'user', content: userPrompt }],
      systemPrompt
    );

    const content = response.content[0].text;
    const parsed = JSON.parse(content);

    return {
      ok: true,
      persona_used: persona,
      task_id: taskId,
      result: parsed,
      warnings: [],
      model: MODEL,
    };
  } catch (error) {
    console.error('AI triage question error:', error);

    // Fallback questions
    return {
      ok: false,
      persona_used: persona,
      task_id: taskId,
      result: {
        questions: [
          {
            id: 'q1',
            prompt: 'When did you first notice this issue?',
            answer_type: 'text',
            required: true,
          },
          {
            id: 'q2',
            prompt: 'Have you tried anything to fix it?',
            answer_type: 'text',
            required: false,
          },
        ],
        stop_after: 2,
      },
      warnings: ['ai_error', 'using_fallback_questions'],
    };
  }
}

/**
 * Generate decision prompt (DIY vs Assign vs Pro)
 */
export async function generateDecisionPrompt(
  taskId: string,
  task: Task,
  persona: PersonaType
): Promise<AIResponse<DecisionPrompt>> {
  const systemPrompt = `You are an AI assistant for HoneyDo2Done.
Analyze the task and recommend DIY vs Assign (household member) vs Pro.

${getPersonaTone(persona)}

CRITICAL: Return ONLY valid JSON.

Output format:
{
  "recommendation": "diy|assign|pro",
  "why": ["reason1", "reason2"],
  "diy_assessment": {
    "difficulty": "easy|medium|hard|pro_recommended",
    "time_estimate_minutes": 0,
    "tools_needed": ["string"],
    "risk_level": "low|medium|high",
    "stop_conditions": ["If X happens, stop and call a pro"]
  },
  "pro_estimate_range": {
    "low": 0,
    "high": 0
  }
}

Decision logic:
- Safety flags = ALWAYS recommend pro
- High urgency + no expertise = pro
- Simple fixes = DIY with clear instructions
- Technical but not dangerous = assign to household technical partner
- Include stop conditions for DIY (when to abort and call pro)`;

  const userPrompt = `Task: "${task.description}"

Category: ${task.category}
Structured data: ${JSON.stringify(task.structured_data, null, 2)}

Recommend DIY, Assign, or Pro. Return ONLY the JSON object.`;

  try {
    const response = await callClaude(
      [{ role: 'user', content: userPrompt }],
      systemPrompt
    );

    const content = response.content[0].text;
    const parsed = JSON.parse(content);

    return {
      ok: true,
      persona_used: persona,
      task_id: taskId,
      result: parsed,
      warnings: [],
      model: MODEL,
    };
  } catch (error) {
    console.error('AI decision error:', error);

    // Safe fallback: recommend pro
    return {
      ok: false,
      persona_used: persona,
      task_id: taskId,
      result: {
        recommendation: 'pro',
        why: ['Unable to assess complexity - recommending professional help for safety'],
        diy_assessment: {
          difficulty: 'pro_recommended',
          time_estimate_minutes: 0,
          tools_needed: [],
          risk_level: 'high',
          stop_conditions: ['Contact a professional'],
        },
        pro_estimate_range: { low: 100, high: 300 },
      },
      warnings: ['ai_error', 'defaulting_to_pro_recommendation'],
    };
  }
}

/**
 * Generate persona-specific brief
 */
export async function generateBrief(
  taskId: string,
  task: Task,
  persona: PersonaType
): Promise<AIResponse<string>> {
  const systemPrompt = `You are an AI assistant for HoneyDo2Done.
Create a ${persona.replace('_', ' ')} brief for this task.

${getPersonaTone(persona)}

Guidelines:
- household_ceo: Warm 2-3 sentence summary. What, why, next step.
- technical_partner: Structured brief with symptoms, diagnostics, recommendation.
- patient_guide: Simple, reassuring explanation with clear next steps.
- diy_mentor: Not used for briefs (only for instructions).

Keep it concise but complete. Use the specified tone.`;

  const userPrompt = `Task: "${task.title}"
Description: "${task.description}"
Category: ${task.category}
Structured data: ${JSON.stringify(task.structured_data, null, 2)}

Create a ${persona} brief. Return plain text (not JSON).`;

  try {
    const response = await callClaude(
      [{ role: 'user', content: userPrompt }],
      systemPrompt,
      0.7 // Higher temperature for creative briefing
    );

    const content = response.content[0].text;

    return {
      ok: true,
      persona_used: persona,
      task_id: taskId,
      result: content,
      warnings: [],
      model: MODEL,
    };
  } catch (error) {
    console.error('AI brief error:', error);
    return {
      ok: false,
      persona_used: persona,
      task_id: taskId,
      result: `Task: ${task.title}\n\n${task.description}`,
      warnings: ['ai_error', 'using_fallback_brief'],
    };
  }
}

/**
 * Generate DIY plan with safety checks
 */
export async function generateDIYPlan(
  taskId: string,
  task: Task,
  persona: PersonaType = 'diy_mentor'
): Promise<AIResponse<any>> {
  const systemPrompt = `You are an AI DIY mentor for HoneyDo2Done.

${getPersonaTone('diy_mentor')}

CRITICAL SAFETY REQUIREMENTS:
1. ALWAYS include stop conditions (when to abort and call a pro)
2. For electrical, gas, structural, or ladder work: include prominent safety warnings
3. If task has safety flags: add gating language like "If you smell gas/see sparks/active leak: STOP and call a pro"
4. Estimate difficulty honestly - don't downplay risks

Output format (JSON):
{
  "title": "string",
  "difficulty": "easy|medium|hard",
  "time_estimate_minutes": 0,
  "tools_needed": ["string"],
  "materials_needed": ["string"],
  "safety_warnings": ["CRITICAL safety warning"],
  "stop_conditions": ["When to stop and call a pro"],
  "steps": [
    {
      "number": 1,
      "title": "string",
      "instruction": "detailed step",
      "safety_note": "optional safety note for this step"
    }
  ],
  "verification": "How to verify the fix worked",
  "if_it_doesnt_work": "Next steps if DIY fails"
}`;

  const safetyFlags = task.structured_data.safety_flags || [];
  const hasSafetyFlags = safetyFlags.length > 0;

  const userPrompt = `Task: "${task.title}"
Description: "${task.description}"
Category: ${task.category}
Structured data: ${JSON.stringify(task.structured_data, null, 2)}
${hasSafetyFlags ? `\nSAFETY FLAGS: ${safetyFlags.join(', ')} - EMPHASIZE SAFETY!` : ''}

Create a DIY plan. Return ONLY the JSON object.`;

  try {
    const response = await callClaude(
      [{ role: 'user', content: userPrompt }],
      systemPrompt
    );

    const content = response.content[0].text;
    const parsed = JSON.parse(content);

    // Validate safety warnings exist for flagged tasks
    if (hasSafetyFlags && (!parsed.safety_warnings || parsed.safety_warnings.length === 0)) {
      parsed.safety_warnings = [
        '⚠️ This task involves potential safety risks. If you are not comfortable or encounter unexpected issues, stop and contact a professional.',
      ];
    }

    return {
      ok: true,
      persona_used: persona,
      task_id: taskId,
      result: parsed,
      warnings: hasSafetyFlags ? ['task_has_safety_flags'] : [],
      model: MODEL,
    };
  } catch (error) {
    console.error('AI DIY plan error:', error);
    return {
      ok: false,
      persona_used: persona,
      task_id: taskId,
      result: null,
      warnings: ['ai_error', 'cannot_generate_diy_plan', 'recommend_pro'],
    };
  }
}

// Helper: Determine missing fields
function getMissingFields(data: StructuredTaskData): string[] {
  const missing: string[] = [];

  if (!data.category) missing.push('category');
  if (!data.location_in_home) missing.push('location');
  if (!data.symptoms || data.symptoms.length === 0) missing.push('symptoms');
  if (!data.duration) missing.push('when it started');
  if (!data.what_tried || data.what_tried.length === 0) missing.push('what you tried');
  if (!data.urgency) missing.push('urgency');

  return missing;
}
