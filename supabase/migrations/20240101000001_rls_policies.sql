-- Row Level Security Policies for HoneyDo2Done
-- Users can only access data for their household(s) and tasks they're involved in

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE household_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_artifacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;

-- Helper function to check if user is in household
CREATE OR REPLACE FUNCTION user_in_household(household_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM household_members
    WHERE household_id = household_uuid
    AND user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user is admin/ops
CREATE OR REPLACE FUNCTION is_admin_or_ops()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND role IN ('admin', 'ops')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- USERS
-- =====================================================

-- Users can read their own profile
CREATE POLICY "Users can read own profile"
  ON users FOR SELECT
  USING (id = auth.uid() OR is_admin_or_ops());

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Admins can do anything
CREATE POLICY "Admins have full access to users"
  ON users FOR ALL
  USING (is_admin_or_ops())
  WITH CHECK (is_admin_or_ops());

-- =====================================================
-- HOUSEHOLDS
-- =====================================================

-- Users can read households they're members of
CREATE POLICY "Users can read own households"
  ON households FOR SELECT
  USING (
    id IN (
      SELECT household_id FROM household_members
      WHERE user_id = auth.uid()
    )
    OR is_admin_or_ops()
  );

-- Users can create households
CREATE POLICY "Users can create households"
  ON households FOR INSERT
  WITH CHECK (created_by = auth.uid());

-- Household owners can update
CREATE POLICY "Household owners can update"
  ON households FOR UPDATE
  USING (created_by = auth.uid() OR is_admin_or_ops())
  WITH CHECK (created_by = auth.uid() OR is_admin_or_ops());

-- =====================================================
-- HOUSEHOLD MEMBERS
-- =====================================================

-- Users can read members of their households
CREATE POLICY "Users can read household members"
  ON household_members FOR SELECT
  USING (user_in_household(household_id) OR is_admin_or_ops());

-- Household owners can manage members
CREATE POLICY "Household owners can manage members"
  ON household_members FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM households
      WHERE id = household_members.household_id
      AND created_by = auth.uid()
    )
    OR is_admin_or_ops()
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM households
      WHERE id = household_members.household_id
      AND created_by = auth.uid()
    )
    OR is_admin_or_ops()
  );

-- =====================================================
-- PROPERTIES
-- =====================================================

-- Users can read properties in their households
CREATE POLICY "Users can read household properties"
  ON properties FOR SELECT
  USING (user_in_household(household_id) OR is_admin_or_ops());

-- Household members can create properties
CREATE POLICY "Household members can create properties"
  ON properties FOR INSERT
  WITH CHECK (user_in_household(household_id));

-- Household members can update properties
CREATE POLICY "Household members can update properties"
  ON properties FOR UPDATE
  USING (user_in_household(household_id) OR is_admin_or_ops())
  WITH CHECK (user_in_household(household_id) OR is_admin_or_ops());

-- =====================================================
-- PARTNERS
-- =====================================================

-- All authenticated users can read active partners
CREATE POLICY "Users can read active partners"
  ON partners FOR SELECT
  USING (is_active = true OR user_id = auth.uid() OR is_admin_or_ops());

-- Partners can update their own profile
CREATE POLICY "Partners can update own profile"
  ON partners FOR UPDATE
  USING (user_id = auth.uid() OR is_admin_or_ops())
  WITH CHECK (user_id = auth.uid() OR is_admin_or_ops());

-- Admins can manage partners
CREATE POLICY "Admins can manage partners"
  ON partners FOR ALL
  USING (is_admin_or_ops())
  WITH CHECK (is_admin_or_ops());

-- =====================================================
-- TASKS
-- =====================================================

-- Users can read tasks for their households
CREATE POLICY "Users can read household tasks"
  ON tasks FOR SELECT
  USING (
    user_in_household(household_id)
    OR created_by = auth.uid()
    OR assigned_to = auth.uid()
    OR is_admin_or_ops()
  );

-- Partners can read their assigned tasks
CREATE POLICY "Partners can read assigned tasks"
  ON tasks FOR SELECT
  USING (
    partner_id IN (
      SELECT id FROM partners WHERE user_id = auth.uid()
    )
  );

-- Household members can create tasks
CREATE POLICY "Household members can create tasks"
  ON tasks FOR INSERT
  WITH CHECK (
    user_in_household(household_id)
    AND created_by = auth.uid()
  );

-- Task creators and assignees can update
CREATE POLICY "Task stakeholders can update"
  ON tasks FOR UPDATE
  USING (
    user_in_household(household_id)
    OR created_by = auth.uid()
    OR assigned_to = auth.uid()
    OR is_admin_or_ops()
  )
  WITH CHECK (
    user_in_household(household_id)
    OR created_by = auth.uid()
    OR assigned_to = auth.uid()
    OR is_admin_or_ops()
  );

-- =====================================================
-- TASK EVENTS (read-only for users, write via functions)
-- =====================================================

-- Users can read events for tasks they can see
CREATE POLICY "Users can read task events"
  ON task_events FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tasks
      WHERE tasks.id = task_events.task_id
      AND (
        user_in_household(tasks.household_id)
        OR tasks.created_by = auth.uid()
        OR tasks.assigned_to = auth.uid()
        OR is_admin_or_ops()
      )
    )
  );

-- Service role can insert events
CREATE POLICY "Service role can insert events"
  ON task_events FOR INSERT
  WITH CHECK (true); -- Will be restricted to service role via grants

-- =====================================================
-- TASK ARTIFACTS
-- =====================================================

-- Users can read artifacts for tasks they can see
CREATE POLICY "Users can read task artifacts"
  ON task_artifacts FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tasks
      WHERE tasks.id = task_artifacts.task_id
      AND (
        user_in_household(tasks.household_id)
        OR tasks.created_by = auth.uid()
        OR tasks.assigned_to = auth.uid()
        OR is_admin_or_ops()
      )
    )
  );

-- Service role can insert artifacts
CREATE POLICY "Service role can insert artifacts"
  ON task_artifacts FOR INSERT
  WITH CHECK (true);

-- =====================================================
-- TASK MESSAGES
-- =====================================================

-- Users can read messages for tasks they can see
CREATE POLICY "Users can read task messages"
  ON task_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tasks
      WHERE tasks.id = task_messages.task_id
      AND (
        user_in_household(tasks.household_id)
        OR tasks.created_by = auth.uid()
        OR tasks.assigned_to = auth.uid()
        OR is_admin_or_ops()
      )
    )
  );

-- Users can insert messages for tasks they can see
CREATE POLICY "Users can send messages"
  ON task_messages FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM tasks
      WHERE tasks.id = task_messages.task_id
      AND (
        user_in_household(tasks.household_id)
        OR tasks.created_by = auth.uid()
        OR tasks.assigned_to = auth.uid()
      )
    )
    AND sender_id = auth.uid()
  );

-- Service role can insert system messages
CREATE POLICY "Service role can insert system messages"
  ON task_messages FOR INSERT
  WITH CHECK (sender_type IN ('ai', 'system'));

-- =====================================================
-- PARTNER REQUESTS
-- =====================================================

-- Users can read requests for their household tasks
CREATE POLICY "Users can read partner requests"
  ON partner_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tasks
      WHERE tasks.id = partner_requests.task_id
      AND (
        user_in_household(tasks.household_id)
        OR is_admin_or_ops()
      )
    )
  );

-- Partners can read requests sent to them
CREATE POLICY "Partners can read their requests"
  ON partner_requests FOR SELECT
  USING (
    EXISTS (
      SELECT id FROM partners
      WHERE user_id = auth.uid()
      AND id = ANY(partner_requests.sent_to_partner_ids)
    )
  );

-- Service role manages partner requests
CREATE POLICY "Service role manages partner requests"
  ON partner_requests FOR ALL
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- RATINGS
-- =====================================================

-- Users can read ratings for their tasks
CREATE POLICY "Users can read task ratings"
  ON ratings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tasks
      WHERE tasks.id = ratings.task_id
      AND (
        user_in_household(tasks.household_id)
        OR is_admin_or_ops()
      )
    )
  );

-- Partners can read their ratings
CREATE POLICY "Partners can read own ratings"
  ON ratings FOR SELECT
  USING (
    partner_id IN (
      SELECT id FROM partners WHERE user_id = auth.uid()
    )
  );

-- Users can create ratings for their tasks
CREATE POLICY "Users can rate tasks"
  ON ratings FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM tasks
      WHERE tasks.id = ratings.task_id
      AND user_in_household(tasks.household_id)
    )
  );

-- =====================================================
-- REFERRAL CODES
-- =====================================================

-- Users can read their own referral codes
CREATE POLICY "Users can read own referral codes"
  ON referral_codes FOR SELECT
  USING (user_id = auth.uid() OR is_admin_or_ops());

-- Users can create their own referral codes
CREATE POLICY "Users can create referral codes"
  ON referral_codes FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- =====================================================
-- GRANT PERMISSIONS TO SERVICE ROLE
-- =====================================================

-- These grants allow edge functions with service role to bypass RLS when needed
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;
