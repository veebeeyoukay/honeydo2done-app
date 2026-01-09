# n8n Workflow Templates for HoneyDo2Done

This directory contains n8n workflow templates for automating task processing, partner matching, reminders, and follow-ups.

## Workflows

### 1. New Task Processing
**Trigger**: Webhook from Supabase (task.created event)
**Purpose**: Handle initial task capture, AI extraction, and triage

### 2. Pro Request to Booking
**Trigger**: Webhook when task.status = pro_requested
**Purpose**: Match partners, send job briefs, coordinate acceptance

### 3. Task Reminders
**Trigger**: Schedule (daily check)
**Purpose**: Send D-1 and H-2 reminders for scheduled tasks

### 4. Satisfaction Follow-up
**Trigger**: Webhook when task.status = completed
**Purpose**: Request rating, handle feedback, trigger referrals

## Setup

1. **Install n8n**
   ```bash
   npm install -g n8n
   # or
   docker run -it --rm --name n8n -p 5678:5678 n8nio/n8n
   ```

2. **Import workflows**
   - Access n8n at http://localhost:5678
   - Go to Workflows > Import
   - Select each JSON file from this directory

3. **Configure credentials**
   - Supabase API credentials (URL + service role key)
   - Lindy API key (for SMS)
   - Anthropic API key (if workflows call AI directly)

4. **Activate workflows**
   - Test each workflow with sample data
   - Activate for production use

## Webhook URLs

Once activated, n8n will provide webhook URLs for each workflow:
- New Task Processing: `https://your-n8n.app/webhook/new-task-processing`
- Pro Request: `https://your-n8n.app/webhook/pro-request-to-booking`
- Task Decision Ready: `https://your-n8n.app/webhook/task-decision-ready`

Add these to your `.env` file:
```bash
N8N_WEBHOOK_URL=https://your-n8n.app/webhook
```

## Supabase Triggers

You can set up Supabase database triggers to automatically call n8n webhooks:

```sql
-- Example: Trigger on task status change
CREATE OR REPLACE FUNCTION notify_task_status_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://your-n8n.app/webhook/task-status-changed',
    body := json_build_object(
      'task_id', NEW.id,
      'old_status', OLD.status,
      'new_status', NEW.status,
      'timestamp', NOW()
    )::text
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER task_status_changed
AFTER UPDATE OF status ON tasks
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION notify_task_status_change();
```

## Testing

Each workflow template includes test data. Use the "Execute Workflow" button in n8n to test with sample payloads.

## Monitoring

Enable n8n's execution history to monitor:
- Success/failure rates
- Execution times
- Error patterns

Access at: Executions > All Executions
