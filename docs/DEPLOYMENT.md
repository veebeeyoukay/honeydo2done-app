# HoneyDo2Done Deployment Guide

## Prerequisites

- Supabase account
- Anthropic API key (Claude)
- OpenAI API key (Whisper)
- Lindy account
- n8n instance (self-hosted or cloud)
- Expo account (for mobile app)

---

## 1. Supabase Setup

### Create Project

1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Note your project URL and keys:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY` (keep secret!)

### Run Migrations

```bash
cd supabase

# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Run migrations
supabase db push
```

### Deploy Edge Functions

```bash
# Deploy all functions
supabase functions deploy lindy-webhook
supabase functions deploy task-triage-start
supabase functions deploy task-triage-answer
supabase functions deploy task-briefs-generate
supabase functions deploy task-diy-start
supabase functions deploy task-pro-request

# Set secrets
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set LINDY_WEBHOOK_SECRET=...
supabase secrets set LINDY_API_KEY=...
supabase secrets set N8N_WEBHOOK_URL=https://your-n8n.app/webhook
```

### Enable Realtime

```sql
-- Enable realtime for task updates
ALTER PUBLICATION supabase_realtime ADD TABLE tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE task_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE task_events;
```

---

## 2. Lindy Setup

### Create Lindy Agent

1. Go to [lindy.ai](https://lindy.ai)
2. Create new agent: "HoneyDo2Done Intake"
3. Configure:
   - **Voice**: Enable phone calls
   - **SMS**: Enable SMS messaging
   - **Instructions**: "You are a home task intake assistant. Listen to the user describe their home issue and extract key details."

### Add Webhook

1. In Lindy agent settings, add webhook
2. URL: `https://your-project.supabase.co/functions/v1/lindy-webhook`
3. Secret: Generate secure secret and save to Supabase secrets
4. Events: Enable "Call Completed" and "Message Received"

### Test Integration

```bash
# Test with sample payload
curl -X POST \
  https://your-project.supabase.co/functions/v1/lindy-webhook \
  -H "x-lindy-signature: YOUR_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "call_completed",
    "phone_number": "+1234567890",
    "transcript": "My WiFi is not working",
    "extracted_data": {},
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }'
```

---

## 3. n8n Setup

### Option A: Self-Hosted

```bash
# Using Docker
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n
```

### Option B: n8n Cloud

1. Sign up at [n8n.io](https://n8n.io)
2. Create new workspace

### Import Workflows

1. Access n8n at http://localhost:5678 (or cloud URL)
2. Go to Workflows
3. Click Import from File
4. Import each workflow from `/n8n/workflows/`
   - `new-task-processing.json`
   - `pro-request-to-booking.json`

### Configure Credentials

Add these credentials in n8n:

**Supabase HTTP Header Auth**:
- Header Name: `Authorization`
- Value: `Bearer YOUR_SERVICE_ROLE_KEY`

**Supabase HTTP Header Auth (for apikey)**:
- Header Name: `apikey`
- Value: `YOUR_SERVICE_ROLE_KEY`

**Lindy API**:
- Header Name: `Authorization`
- Value: `Bearer YOUR_LINDY_API_KEY`

### Activate Workflows

1. Test each workflow with sample data
2. Click "Active" toggle for each workflow
3. Note webhook URLs for each
4. Update Supabase secrets with n8n webhook URL

---

## 4. Mobile App Deployment

### Configure Environment

Create `mobile/.env`:

```bash
EXPO_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

### Build with EAS

```bash
cd mobile

# Install EAS CLI
npm install -g eas-cli

# Login
eas login

# Configure
eas build:configure

# Build for iOS
eas build --platform ios

# Build for Android
eas build --platform android

# Submit to stores
eas submit --platform ios
eas submit --platform android
```

### Over-the-Air Updates

```bash
# Publish update without rebuilding
eas update --branch production --message "Bug fixes"
```

---

## 5. Environment Variables Summary

### Supabase Edge Functions

Set via `supabase secrets set`:

```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
LINDY_WEBHOOK_SECRET=your-secret
LINDY_API_KEY=your-lindy-key
LINDY_PHONE_NUMBER=+1234567890
N8N_WEBHOOK_URL=https://your-n8n.app/webhook
```

### Mobile App

Set in `mobile/.env`:

```bash
EXPO_PUBLIC_SUPABASE_URL=https://...
EXPO_PUBLIC_SUPABASE_ANON_KEY=...
```

### n8n

Set in n8n credentials:

- Supabase URL
- Supabase Service Role Key
- Lindy API credentials

---

## 6. Post-Deployment Checklist

### Database

- [ ] All migrations applied successfully
- [ ] RLS policies active and tested
- [ ] Realtime enabled for required tables
- [ ] Seed data added (optional)

### Edge Functions

- [ ] All functions deployed
- [ ] Secrets configured
- [ ] CORS working correctly
- [ ] Error logging enabled

### Lindy Integration

- [ ] Webhook receiving calls
- [ ] Signature verification working
- [ ] Phone/SMS configured
- [ ] Test call completed successfully

### n8n Workflows

- [ ] All workflows imported
- [ ] Credentials configured
- [ ] Workflows activated
- [ ] Test runs successful

### Mobile App

- [ ] iOS build successful
- [ ] Android build successful
- [ ] Push notifications configured
- [ ] Deep linking working

---

## 7. Monitoring & Logging

### Supabase Logs

```bash
# View edge function logs
supabase functions logs lindy-webhook

# View database logs
supabase db logs
```

### n8n Execution History

Access at: n8n Dashboard > Executions

Filter by:
- Failed executions
- Execution time
- Workflow name

### Mobile App Monitoring

Use Sentry or similar:

```typescript
// mobile/app/_layout.tsx
import * as Sentry from 'sentry-expo';

Sentry.init({
  dsn: 'your-sentry-dsn',
  enableInExpoDevelopment: true,
  debug: true,
});
```

---

## 8. Scaling Considerations

### Database

- Enable connection pooling (Supavisor)
- Add indexes for frequent queries
- Consider read replicas for heavy read workload

### Edge Functions

- Monitor cold start times
- Increase function memory if needed (4GB max)
- Consider caching AI responses

### n8n

- Use queue mode for high throughput
- Separate workflows for different priorities
- Monitor webhook response times

---

## 9. Backup & Recovery

### Database Backups

Automatic daily backups in Supabase Pro plan.

Manual backup:

```bash
supabase db dump -f backup.sql
```

### Restore

```bash
psql -h db.your-project.supabase.co -U postgres -d postgres -f backup.sql
```

---

## 10. Security Hardening

### Enable 2FA

Enable on all accounts:
- Supabase
- Anthropic
- Lindy
- n8n
- Expo

### Rotate Secrets

Quarterly rotation of:
- API keys
- Webhook secrets
- Service role keys

### Audit RLS Policies

Test with:

```sql
-- Test as specific user
SET request.jwt.claim.sub = 'user-uuid';
SELECT * FROM tasks;
```

### Rate Limiting

Configure in Supabase dashboard:
- Edge functions: 100 req/min per IP
- Auth: 30 req/min per IP

---

## Support

- **Supabase**: [supabase.com/docs](https://supabase.com/docs)
- **n8n**: [docs.n8n.io](https://docs.n8n.io)
- **Expo**: [docs.expo.dev](https://docs.expo.dev)
- **Lindy**: [docs.lindy.ai](https://docs.lindy.ai)
