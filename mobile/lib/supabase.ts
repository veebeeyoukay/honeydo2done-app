import 'react-native-url-polyfill/auto';
import { createClient } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});

// Types from database
export type Task = {
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
  structured_data: any;
  triage_data: any;
  wants_pro: boolean;
  is_diy: boolean;
  is_extended_family: boolean;
  scheduled_at?: string;
  started_at?: string;
  completed_at?: string;
  created_at: string;
  updated_at: string;
};

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

export type TaskMessage = {
  id: string;
  task_id: string;
  sender_id?: string;
  sender_type: 'user' | 'ai' | 'partner' | 'system';
  content: string;
  persona_used?: string;
  metadata: any;
  created_at: string;
};
