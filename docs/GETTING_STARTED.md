# Getting Started with HoneyDo2Done Development

## Quick Start (5 minutes)

```bash
# 1. Clone repo
git clone https://github.com/veebeeyoukay/Honey-do-2-done.git
cd Honey-do-2-done

# 2. Install dependencies
npm install

# 3. Set up Supabase locally
cd supabase
supabase start
supabase db reset

# 4. Copy environment file
cp ../.env.example .env
# Edit .env with your keys

# 5. Start mobile app
cd ../mobile
npm install
npm start
```

---

## Detailed Setup

### 1. Prerequisites

Install these tools:

```bash
# Node.js 18+
node --version

# Supabase CLI
npm install -g supabase

# Expo CLI
npm install -g expo-cli eas-cli

# Docker (for local Supabase)
docker --version
```

### 2. Supabase Local Development

Start local Supabase:

```bash
cd supabase
supabase start
```

This starts:
- PostgreSQL (port 54322)
- PostgREST API (port 54321)
- Studio UI (port 54323)
- Inbucket (email testing, port 54324)
- Edge Runtime (port 54288)

Access Supabase Studio: http://localhost:54323

### 3. Run Migrations

```bash
# Apply all migrations
supabase db reset

# Or individually
supabase migration up
```

### 4. Seed Test Data

```bash
# Run seed script
node scripts/seed-data.js
```

This creates:
- Test users (Jennifer, Vikas, Mimi)
- Test household
- Sample tasks
- Test partners

### 5. Start Edge Functions Locally

```bash
supabase functions serve
```

Functions available at:
- http://localhost:54321/functions/v1/lindy-webhook
- http://localhost:54321/functions/v1/task-triage-start/{id}
- etc.

### 6. Start Mobile App

```bash
cd mobile
npm install

# Start Expo
npm start

# Or directly on device
npm run ios     # iOS simulator
npm run android # Android emulator
npm run web     # Web browser
```

---

## Testing the Flows

### Flow A: Voice Intake → Triage → Decision

**Step 1**: Simulate Lindy webhook

```bash
curl -X POST http://localhost:54321/functions/v1/lindy-webhook \
  -H "Content-Type: application/json" \
  -H "x-lindy-signature: dev-secret" \
  -d '{
    "event": "call_completed",
    "phone_number": "+15555551234",
    "transcript": "My WiFi router keeps dropping the 5GHz connection. It started yesterday and I have already tried resetting it twice. The 2.4GHz seems fine though.",
    "extracted_data": {
      "name": "Jennifer Smith"
    },
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }'
```

**Step 2**: Check task was created

```sql
-- In Supabase Studio SQL Editor
SELECT * FROM tasks ORDER BY created_at DESC LIMIT 1;
```

**Step 3**: Check triage questions were sent

```sql
SELECT * FROM task_messages WHERE task_id = 'YOUR_TASK_ID';
```

**Step 4**: Answer triage questions

```bash
curl -X POST http://localhost:54321/functions/v1/task-triage-answer/TASK_ID \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT" \
  -d '{
    "answers": {
      "q1": "Yesterday afternoon",
      "q2": "Reset router twice, checked cables"
    }
  }'
```

**Step 5**: Check decision prompt

Task should now be in `awaiting_decision` status with AI recommendation.

### Flow B: DIY Mode

```bash
curl -X POST http://localhost:54321/functions/v1/task-diy-start/TASK_ID \
  -H "Authorization: Bearer YOUR_JWT"
```

Check response for DIY plan with steps.

### Flow C: Pro Request

```bash
curl -X POST http://localhost:54321/functions/v1/task-pro-request/TASK_ID \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "notes": "Prefer morning",
    "urgency": "normal"
  }'
```

---

## Development Workflow

### Making Database Changes

```bash
# Create new migration
supabase migration new add_new_field

# Edit the generated file in supabase/migrations/

# Apply migration
supabase db reset

# Or push to remote
supabase db push
```

### Modifying Edge Functions

1. Edit function in `supabase/functions/`
2. Test locally:
   ```bash
   supabase functions serve
   ```
3. Deploy to remote:
   ```bash
   supabase functions deploy function-name
   ```

### Mobile App Development

```bash
cd mobile

# Start with cache clearing
npm start -- --clear

# Run tests
npm test

# Type check
npx tsc --noEmit

# Lint
npm run lint
```

### Testing AI Integration

Set test mode in edge functions:

```typescript
// In _shared/ai.ts
const TEST_MODE = Deno.env.get('TEST_MODE') === 'true';

if (TEST_MODE) {
  // Return mock responses
  return {
    ok: true,
    result: { /* mock data */ }
  };
}
```

---

## Common Tasks

### Get a User's JWT Token

```sql
-- In Supabase Studio SQL Editor
SELECT auth.sign(
  json_build_object(
    'sub', id,
    'email', email,
    'role', 'authenticated',
    'exp', extract(epoch from now() + interval '1 hour')
  ),
  current_setting('app.settings.jwt_secret')
) as token
FROM auth.users
WHERE email = 'user@example.com';
```

### View Task Event History

```sql
SELECT
  te.created_at,
  te.type,
  te.actor_type,
  u.full_name as actor,
  te.payload
FROM task_events te
LEFT JOIN users u ON te.actor_id = u.id
WHERE te.task_id = 'YOUR_TASK_ID'
ORDER BY te.created_at;
```

### View AI Artifacts

```sql
SELECT
  type,
  model,
  confidence,
  content,
  created_at
FROM task_artifacts
WHERE task_id = 'YOUR_TASK_ID'
ORDER BY created_at;
```

### Manually Trigger n8n Workflow

```bash
curl -X POST http://localhost:5678/webhook/new-task-processing \
  -H "Content-Type: application/json" \
  -d '{
    "task_id": "uuid",
    "user_id": "uuid",
    "phone": "+15555551234",
    "persona": "household_ceo"
  }'
```

---

## Troubleshooting

### Supabase Functions Won't Start

```bash
# Check Docker
docker ps

# Restart Supabase
supabase stop
supabase start

# Check logs
supabase functions logs --tail
```

### Database Connection Issues

```bash
# Check connection
supabase status

# Reset database
supabase db reset

# Check logs
supabase db logs
```

### Mobile App Not Connecting

1. Check `.env` file exists in `mobile/`
2. Verify Supabase URL is accessible
3. Check network - use local IP for physical devices:
   ```bash
   EXPO_PUBLIC_SUPABASE_URL=http://192.168.1.x:54321
   ```

### AI Calls Failing

1. Verify API keys are set:
   ```bash
   echo $ANTHROPIC_API_KEY
   ```

2. Check function secrets:
   ```bash
   supabase secrets list
   ```

3. Test API key directly:
   ```bash
   curl https://api.anthropic.com/v1/messages \
     -H "x-api-key: $ANTHROPIC_API_KEY" \
     -H "anthropic-version: 2023-06-01" \
     -H "content-type: application/json" \
     -d '{"model":"claude-opus-4-5","max_tokens":100,"messages":[{"role":"user","content":"test"}]}'
   ```

---

## VS Code Setup

Recommended extensions:

```json
{
  "recommendations": [
    "bradlc.vscode-tailwindcss",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "supabase.supabase-vscode",
    "ms-vscode.vscode-typescript-next"
  ]
}
```

Settings (`.vscode/settings.json`):

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "typescript.tsdk": "node_modules/typescript/lib",
  "deno.enable": true,
  "deno.enablePaths": ["./supabase/functions"]
}
```

---

## Next Steps

1. **Customize Personas**: Edit prompts in `supabase/functions/_shared/persona.ts`

2. **Add Categories**: Expand `task_category` enum in migrations

3. **Configure Lindy**: Set up real Lindy agent and webhook

4. **Deploy n8n**: Set up workflows for automation

5. **Test End-to-End**: Run through all 5 flows (A-E) from TRD

6. **Add Partners**: Populate `partners` table with test data

7. **Mobile UI**: Build out complete mobile screens

---

## Resources

- [Supabase Docs](https://supabase.com/docs)
- [Expo Docs](https://docs.expo.dev)
- [Claude API Docs](https://docs.anthropic.com)
- [n8n Docs](https://docs.n8n.io)
- [React Native Docs](https://reactnative.dev)

---

## Getting Help

If you're stuck:

1. Check logs: `supabase functions logs --tail`
2. Review database state in Supabase Studio
3. Test API calls with cURL
4. Check this repo's Issues tab
5. Review the TRD in `docs/TRD.md`
