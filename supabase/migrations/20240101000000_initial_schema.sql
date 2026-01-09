-- HoneyDo2Done MVP Initial Schema
-- Phase 1: Core tables and enums

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- ENUMS
-- =====================================================

CREATE TYPE user_role AS ENUM ('customer', 'partner', 'admin', 'ops');

CREATE TYPE persona_type AS ENUM (
  'household_ceo',      -- Warm, executive summaries
  'technical_partner',  -- Detailed technical briefs
  'patient_guide',      -- Simple, reassuring language
  'diy_mentor'          -- Step-by-step with safety
);

CREATE TYPE communication_preference AS ENUM (
  'minimal',      -- Only critical updates
  'standard',     -- Normal updates
  'detailed'      -- Verbose updates
);

CREATE TYPE task_status AS ENUM (
  'captured',
  'triaging',
  'awaiting_decision',
  'diy_in_progress',
  'pro_requested',
  'pro_assigned',
  'scheduled',
  'in_progress',
  'completed',
  'cancelled'
);

CREATE TYPE task_priority AS ENUM ('low', 'normal', 'high', 'urgent');

CREATE TYPE task_category AS ENUM (
  'smart_home',
  'tech_guard',
  'aqua_tech',
  'garage_tech',
  'hvac',
  'electrical',
  'plumbing',
  'general',
  'other'
);

CREATE TYPE partner_request_status AS ENUM (
  'draft',
  'sent',
  'accepted',
  'rejected',
  'expired'
);

CREATE TYPE task_event_type AS ENUM (
  'created',
  'triage_q_sent',
  'triage_a_received',
  'triage_completed',
  'assigned',
  'diy_started',
  'pro_requested',
  'pro_matched',
  'pro_accepted',
  'scheduled',
  'started',
  'completed',
  'cancelled',
  'rated',
  'reopened'
);

CREATE TYPE actor_type AS ENUM ('user', 'ai', 'partner', 'system');

CREATE TYPE artifact_type AS ENUM (
  'ai_structured_extract',
  'ai_triage_questions',
  'ai_brief_household',
  'ai_brief_tech',
  'ai_brief_patient',
  'ai_diy_plan',
  'transcript',
  'photo',
  'video'
);

-- =====================================================
-- CORE TABLES
-- =====================================================

-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE,
  phone TEXT UNIQUE,
  full_name TEXT NOT NULL,
  role user_role NOT NULL DEFAULT 'customer',
  persona_type persona_type DEFAULT 'household_ceo',
  communication_preference communication_preference DEFAULT 'standard',
  avatar_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Households (for grouping users)
CREATE TABLE households (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Household members (many-to-many with persona override)
CREATE TABLE household_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member', -- owner, member, extended_family
  persona_override persona_type,
  is_extended_family BOOLEAN NOT NULL DEFAULT false,
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(household_id, user_id)
);

-- Properties
CREATE TABLE properties (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  address_line1 TEXT NOT NULL,
  address_line2 TEXT,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  zip TEXT NOT NULL,
  property_type TEXT, -- single_family, condo, etc.
  notes TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Partners (pros)
CREATE TABLE partners (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  business_name TEXT NOT NULL,
  contact_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT NOT NULL,
  categories task_category[] NOT NULL DEFAULT '{}',
  service_zips TEXT[] NOT NULL DEFAULT '{}',
  rating DECIMAL(3, 2) DEFAULT 0.00,
  total_jobs INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  hourly_rate_low INTEGER,
  hourly_rate_high INTEGER,
  response_time_minutes INTEGER,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tasks
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  partner_id UUID REFERENCES partners(id) ON DELETE SET NULL,

  -- Core fields
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  status task_status NOT NULL DEFAULT 'captured',
  priority task_priority NOT NULL DEFAULT 'normal',
  category task_category,

  -- Structured data (AI extracted)
  structured_data JSONB DEFAULT '{}'::jsonb, -- location, symptoms, duration, etc.
  triage_data JSONB DEFAULT '{}'::jsonb, -- Q&A pairs

  -- Flags
  wants_pro BOOLEAN NOT NULL DEFAULT false,
  is_diy BOOLEAN NOT NULL DEFAULT false,
  is_extended_family BOOLEAN NOT NULL DEFAULT false,

  -- Timestamps
  scheduled_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Task events (immutable audit log)
CREATE TABLE task_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  type task_event_type NOT NULL,
  actor_type actor_type NOT NULL,
  actor_id UUID, -- nullable for system events
  payload JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Task artifacts (AI outputs, photos, transcripts)
CREATE TABLE task_artifacts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  type artifact_type NOT NULL,
  content JSONB NOT NULL, -- structured data
  storage_path TEXT, -- for photos/videos
  model TEXT, -- e.g., 'claude-opus-4-5' for AI artifacts
  confidence DECIMAL(3, 2), -- 0.00 to 1.00
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Task messages (chat/triage Q&A)
CREATE TABLE task_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
  sender_type actor_type NOT NULL,
  content TEXT NOT NULL,
  persona_used persona_type,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Partner requests (pro pipeline state)
CREATE TABLE partner_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  status partner_request_status NOT NULL DEFAULT 'draft',
  sent_to_partner_ids UUID[] NOT NULL DEFAULT '{}',
  accepted_partner_id UUID REFERENCES partners(id) ON DELETE SET NULL,
  estimate_range_low INTEGER,
  estimate_range_high INTEGER,
  scheduled_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ratings
CREATE TABLE ratings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  partner_id UUID REFERENCES partners(id) ON DELETE SET NULL,
  score INTEGER NOT NULL CHECK (score >= 1 AND score <= 5),
  feedback TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Referral codes
CREATE TABLE referral_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  uses INTEGER NOT NULL DEFAULT 0,
  max_uses INTEGER DEFAULT 10,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

CREATE INDEX idx_household_members_household ON household_members(household_id);
CREATE INDEX idx_household_members_user ON household_members(user_id);

CREATE INDEX idx_properties_household ON properties(household_id);

CREATE INDEX idx_partners_active ON partners(is_active);
CREATE INDEX idx_partners_categories ON partners USING GIN(categories);
CREATE INDEX idx_partners_zips ON partners USING GIN(service_zips);

CREATE INDEX idx_tasks_household ON tasks(household_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_created_by ON tasks(created_by);
CREATE INDEX idx_tasks_assigned_to ON tasks(assigned_to);
CREATE INDEX idx_tasks_partner ON tasks(partner_id);
CREATE INDEX idx_tasks_created_at ON tasks(created_at DESC);

CREATE INDEX idx_task_events_task ON task_events(task_id);
CREATE INDEX idx_task_events_created_at ON task_events(created_at DESC);

CREATE INDEX idx_task_artifacts_task ON task_artifacts(task_id);
CREATE INDEX idx_task_artifacts_type ON task_artifacts(type);

CREATE INDEX idx_task_messages_task ON task_messages(task_id);
CREATE INDEX idx_task_messages_created_at ON task_messages(created_at);

CREATE INDEX idx_partner_requests_task ON partner_requests(task_id);
CREATE INDEX idx_partner_requests_status ON partner_requests(status);

CREATE INDEX idx_ratings_task ON ratings(task_id);
CREATE INDEX idx_ratings_partner ON ratings(partner_id);

-- =====================================================
-- UPDATED_AT TRIGGERS
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_households_updated_at BEFORE UPDATE ON households
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_properties_updated_at BEFORE UPDATE ON properties
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_partners_updated_at BEFORE UPDATE ON partners
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_partner_requests_updated_at BEFORE UPDATE ON partner_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
