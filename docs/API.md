# HoneyDo2Done API Documentation

## Base URL

```
https://your-project.supabase.co/functions/v1
```

## Authentication

Most endpoints require authentication via JWT token:

```bash
Authorization: Bearer <your-jwt-token>
```

Service role endpoints (webhooks) use service role key.

## Edge Functions

### 1. Lindy Webhook

**Endpoint**: `POST /lindy-webhook`

**Purpose**: Receive voice/SMS intake from Lindy

**Authentication**: Webhook signature verification

**Headers**:
```
x-lindy-signature: <signature>
Content-Type: application/json
```

**Request Body**:
```json
{
  "event": "call_completed",
  "phone_number": "+1234567890",
  "transcript": "My WiFi keeps dropping...",
  "extracted_data": {
    "name": "Jennifer",
    "title": "WiFi Issues"
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "task_id": "uuid",
    "status": "captured",
    "next_step": "triage",
    "message": "Task captured successfully..."
  }
}
```

---

### 2. Task Triage Start

**Endpoint**: `POST /task-triage-start/{task_id}`

**Purpose**: Generate and send triage questions

**Authentication**: Bearer token (user or service role)

**Response**:
```json
{
  "success": true,
  "data": {
    "task_id": "uuid",
    "questions": [
      {
        "id": "q1",
        "prompt": "When did you first notice this?",
        "answer_type": "text",
        "required": true
      }
    ],
    "message_sent": true,
    "sms_sent": true
  }
}
```

---

### 3. Task Triage Answer

**Endpoint**: `POST /task-triage-answer/{task_id}`

**Purpose**: Process user answers to triage questions

**Authentication**: Bearer token

**Request Body**:
```json
{
  "answers": {
    "q1": "Two days ago",
    "q2": "Reset the router"
  },
  "answer_text": "Two days ago. I reset the router."
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "task_id": "uuid",
    "triage_complete": true,
    "status": "awaiting_decision",
    "decision_options": {
      "recommendation": "diy",
      "why": ["Simple fix", "Safe to attempt"],
      "diy_assessment": {
        "difficulty": "easy",
        "time_estimate_minutes": 15,
        "tools_needed": [],
        "risk_level": "low",
        "stop_conditions": ["If issue persists"]
      },
      "pro_estimate_range": {
        "low": 100,
        "high": 200
      }
    }
  }
}
```

---

### 4. Task Briefs Generate

**Endpoint**: `POST /task-briefs-generate/{task_id}`

**Purpose**: Generate persona-specific task briefs

**Authentication**: Bearer token

**Request Body** (optional):
```json
{
  "target_user_id": "uuid",
  "persona_override": "technical_partner"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "task_id": "uuid",
    "briefs": {
      "creator": {
        "persona": "household_ceo",
        "brief": "Your WiFi is acting up..."
      },
      "assignee": {
        "persona": "technical_partner",
        "brief": "**Technical Brief**: WiFi dropping intermittently..."
      }
    },
    "count": 2
  }
}
```

---

### 5. Task DIY Start

**Endpoint**: `POST /task-diy-start/{task_id}`

**Purpose**: Start DIY mode and generate plan

**Authentication**: Bearer token (required)

**Response**:
```json
{
  "success": true,
  "data": {
    "task_id": "uuid",
    "status": "diy_in_progress",
    "diy_plan": {
      "title": "Reset WiFi Router",
      "difficulty": "easy",
      "time_estimate_minutes": 15,
      "tools_needed": [],
      "materials_needed": [],
      "safety_warnings": [],
      "stop_conditions": ["If lights don't come back on"],
      "steps": [
        {
          "number": 1,
          "title": "Locate Router",
          "instruction": "Find your WiFi router...",
          "safety_note": null
        }
      ],
      "verification": "Test WiFi connection",
      "if_it_doesnt_work": "Contact your ISP"
    },
    "message": "DIY plan generated. Good luck!"
  }
}
```

---

### 6. Task Pro Request

**Endpoint**: `POST /task-pro-request/{task_id}`

**Purpose**: Request professional help

**Authentication**: Bearer token (required)

**Request Body** (optional):
```json
{
  "notes": "Prefer morning appointments",
  "preferred_date": "2024-01-15",
  "urgency": "urgent"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "task_id": "uuid",
    "partner_request_id": "uuid",
    "status": "pro_requested",
    "estimate_range": {
      "low": 150,
      "high": 300
    },
    "message": "Pro request created...",
    "next_steps": "You'll receive updates as partners respond."
  }
}
```

---

## Error Responses

All endpoints return errors in this format:

```json
{
  "success": false,
  "error": {
    "code": "TASK_NOT_FOUND",
    "message": "Task not found",
    "details": "Additional context"
  }
}
```

**Common Error Codes**:
- `UNAUTHORIZED` (401): Authentication required or failed
- `FORBIDDEN` (403): Insufficient permissions
- `TASK_NOT_FOUND` (404): Task does not exist
- `INVALID_STATUS` (400): Invalid task status for operation
- `AI_ERROR` (500): AI service failure
- `WEBHOOK_ERROR` (500): Webhook processing failure

---

## Database Direct Access (Supabase)

### Tasks

**List tasks**:
```typescript
const { data, error } = await supabase
  .from('tasks')
  .select('*')
  .eq('household_id', householdId)
  .order('created_at', { ascending: false });
```

**Get task with messages**:
```typescript
const { data, error } = await supabase
  .from('tasks')
  .select(`
    *,
    task_messages(*),
    task_artifacts(*)
  `)
  .eq('id', taskId)
  .single();
```

**Subscribe to task updates**:
```typescript
const channel = supabase
  .channel('task-updates')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'tasks',
      filter: `id=eq.${taskId}`
    },
    (payload) => {
      console.log('Task updated:', payload);
    }
  )
  .subscribe();
```

### Task Messages (Chat)

**Send message**:
```typescript
const { data, error } = await supabase
  .from('task_messages')
  .insert({
    task_id: taskId,
    sender_id: userId,
    sender_type: 'user',
    content: 'This is my message'
  });
```

**Subscribe to new messages**:
```typescript
const channel = supabase
  .channel('task-messages')
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'task_messages',
      filter: `task_id=eq.${taskId}`
    },
    (payload) => {
      console.log('New message:', payload.new);
    }
  )
  .subscribe();
```

---

## Rate Limits

- Edge Functions: 100 requests/minute per IP
- Webhook: 1000 requests/minute (verified signatures)
- Database: Per Supabase plan limits

---

## Testing

Use cURL for testing:

```bash
# Test triage start
curl -X POST \
  https://your-project.supabase.co/functions/v1/task-triage-start/TASK_ID \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"

# Test DIY start
curl -X POST \
  https://your-project.supabase.co/functions/v1/task-diy-start/TASK_ID \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## Webhooks (Outbound)

n8n workflows can be triggered via webhooks. See `/n8n/README.md` for configuration.
