// Shared TypeScript types for HoneyDo2Done edge functions

export type UserRole = 'customer' | 'partner' | 'admin' | 'ops';

export type PersonaType =
  | 'household_ceo'
  | 'technical_partner'
  | 'patient_guide'
  | 'diy_mentor';

export type CommunicationPreference = 'minimal' | 'standard' | 'detailed';

export type TaskStatus =
  | 'captured'
  | 'triaging'
  | 'awaiting_decision'
  | 'diy_in_progress'
  | 'pro_requested'
  | 'pro_assigned'
  | 'scheduled'
  | 'in_progress'
  | 'completed'
  | 'cancelled';

export type TaskPriority = 'low' | 'normal' | 'high' | 'urgent';

export type TaskCategory =
  | 'smart_home'
  | 'tech_guard'
  | 'aqua_tech'
  | 'garage_tech'
  | 'hvac'
  | 'electrical'
  | 'plumbing'
  | 'general'
  | 'other';

export type PartnerRequestStatus =
  | 'draft'
  | 'sent'
  | 'accepted'
  | 'rejected'
  | 'expired';

export type TaskEventType =
  | 'created'
  | 'triage_q_sent'
  | 'triage_a_received'
  | 'triage_completed'
  | 'assigned'
  | 'diy_started'
  | 'pro_requested'
  | 'pro_matched'
  | 'pro_accepted'
  | 'scheduled'
  | 'started'
  | 'completed'
  | 'cancelled'
  | 'rated'
  | 'reopened';

export type ActorType = 'user' | 'ai' | 'partner' | 'system';

export type ArtifactType =
  | 'ai_structured_extract'
  | 'ai_triage_questions'
  | 'ai_brief_household'
  | 'ai_brief_tech'
  | 'ai_brief_patient'
  | 'ai_diy_plan'
  | 'transcript'
  | 'photo'
  | 'video';

// Database table interfaces
export interface User {
  id: string;
  email?: string;
  phone?: string;
  full_name: string;
  role: UserRole;
  persona_type?: PersonaType;
  communication_preference?: CommunicationPreference;
  avatar_url?: string;
  is_active: boolean;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface Household {
  id: string;
  name: string;
  created_by: string;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface HouseholdMember {
  id: string;
  household_id: string;
  user_id: string;
  role: string; // owner, member, extended_family
  persona_override?: PersonaType;
  is_extended_family: boolean;
  added_at: string;
}

export interface Property {
  id: string;
  household_id: string;
  name: string;
  address_line1: string;
  address_line2?: string;
  city: string;
  state: string;
  zip: string;
  property_type?: string;
  notes?: string;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface Partner {
  id: string;
  user_id?: string;
  business_name: string;
  contact_name: string;
  phone: string;
  email: string;
  categories: TaskCategory[];
  service_zips: string[];
  rating: number;
  total_jobs: number;
  is_active: boolean;
  hourly_rate_low?: number;
  hourly_rate_high?: number;
  response_time_minutes?: number;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface Task {
  id: string;
  household_id: string;
  property_id?: string;
  created_by: string;
  assigned_to?: string;
  partner_id?: string;
  title: string;
  description: string;
  status: TaskStatus;
  priority: TaskPriority;
  category?: TaskCategory;
  structured_data: StructuredTaskData;
  triage_data: Record<string, any>;
  wants_pro: boolean;
  is_diy: boolean;
  is_extended_family: boolean;
  scheduled_at?: string;
  started_at?: string;
  completed_at?: string;
  created_at: string;
  updated_at: string;
}

export interface TaskEvent {
  id: string;
  task_id: string;
  type: TaskEventType;
  actor_type: ActorType;
  actor_id?: string;
  payload: Record<string, any>;
  created_at: string;
}

export interface TaskArtifact {
  id: string;
  task_id: string;
  type: ArtifactType;
  content: Record<string, any>;
  storage_path?: string;
  model?: string;
  confidence?: number;
  created_at: string;
}

export interface TaskMessage {
  id: string;
  task_id: string;
  sender_id?: string;
  sender_type: ActorType;
  content: string;
  persona_used?: PersonaType;
  metadata: Record<string, any>;
  created_at: string;
}

export interface PartnerRequest {
  id: string;
  task_id: string;
  status: PartnerRequestStatus;
  sent_to_partner_ids: string[];
  accepted_partner_id?: string;
  estimate_range_low?: number;
  estimate_range_high?: number;
  scheduled_at?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface Rating {
  id: string;
  task_id: string;
  user_id: string;
  partner_id?: string;
  score: number; // 1-5
  feedback?: string;
  created_at: string;
}

// AI Output Types
export interface StructuredTaskData {
  category?: TaskCategory;
  location_in_home?: string;
  symptoms?: string[];
  duration?: string;
  patterns?: string[];
  what_tried?: string[];
  urgency?: TaskPriority;
  attachments_needed?: string[];
  likely_trade?: string;
  safety_flags?: string[];
  confidence?: number;
}

export interface TriageQuestion {
  id: string;
  prompt: string;
  answer_type: 'text' | 'choice' | 'number' | 'photo' | 'yesno';
  choices?: string[];
  required: boolean;
}

export interface TriageQuestions {
  questions: TriageQuestion[];
  stop_after: number;
}

export interface DecisionPrompt {
  recommendation: 'diy' | 'assign' | 'pro';
  why: string[];
  diy_assessment: {
    difficulty: 'easy' | 'medium' | 'hard' | 'pro_recommended';
    time_estimate_minutes: number;
    tools_needed: string[];
    risk_level: 'low' | 'medium' | 'high';
    stop_conditions: string[];
  };
  pro_estimate_range: {
    low: number;
    high: number;
  };
}

export interface AIResponse<T = any> {
  ok: boolean;
  persona_used: PersonaType;
  task_id: string;
  result: T;
  warnings: string[];
  model?: string;
  confidence?: number;
}

// Lindy webhook payload
export interface LindyWebhookPayload {
  event: string;
  phone_number: string;
  transcript: string;
  extracted_data?: Record<string, any>;
  timestamp: string;
}

// API Response types
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
}
