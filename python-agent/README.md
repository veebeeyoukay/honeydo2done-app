# HoneyDo2Done Python Agent

Python-based voice and SMS agent for task intake, replacing Lindy integration.

## Architecture

- **FastAPI Server**: Handles webhooks from Twilio
- **Twilio**: Voice calls and SMS messaging
- **Whisper API**: Speech-to-text for voice calls
- **Claude**: Conversational AI for triage
- **Supabase**: Database and backend integration

## Features

- 📞 **Inbound Voice Calls**: Transcribe and process spoken task descriptions
- 💬 **SMS Conversations**: Two-way SMS for triage questions and updates
- 🤖 **AI-Powered Triage**: Claude-based conversational agent
- 🔄 **State Management**: Track conversation state per user/task
- 🔗 **Supabase Integration**: Direct integration with edge functions

## Setup

### 1. Install Dependencies

```bash
cd python-agent
pip install -r requirements.txt
```

### 2. Configure Environment

Create `.env` file:

```bash
# Twilio
TWILIO_ACCOUNT_SID=ACxxxxx
TWILIO_AUTH_TOKEN=xxxxx
TWILIO_PHONE_NUMBER=+1234567890

# OpenAI (Whisper)
OPENAI_API_KEY=sk-xxxxx

# Anthropic (Claude)
ANTHROPIC_API_KEY=sk-ant-xxxxx

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=xxxxx

# Server
PORT=8000
HOST=0.0.0.0
BASE_URL=https://your-agent.ngrok.io  # For Twilio webhooks
```

### 3. Run Locally

```bash
# Development with auto-reload
uvicorn main:app --reload --port 8000

# Or with ngrok for Twilio webhooks
ngrok http 8000
```

### 4. Configure Twilio

1. Go to Twilio Console
2. Set webhook URLs:
   - **Voice**: `https://your-agent.ngrok.io/voice/incoming`
   - **SMS**: `https://your-agent.ngrok.io/sms/incoming`
   - **Status Callback**: `https://your-agent.ngrok.io/voice/status`

## Usage

### Voice Call Flow

1. User calls Twilio number
2. Twilio webhook → `/voice/incoming`
3. TwiML prompts user to describe issue
4. Recording sent to Whisper for transcription
5. Agent creates task in Supabase
6. Agent sends follow-up SMS with task link

### SMS Flow

1. User texts Twilio number
2. Twilio webhook → `/sms/incoming`
3. Agent checks for active conversation state
4. If new: create task, start triage
5. If existing: process triage answer
6. Agent responds with next question or decision

## API Endpoints

### `POST /voice/incoming`
Handle inbound voice call

**Response**: TwiML to record message

### `POST /voice/recording`
Process voice recording

**Body**: Twilio recording data
**Action**: Transcribe → Create task → Send SMS

### `POST /sms/incoming`
Handle inbound SMS

**Body**: Twilio SMS data
**Response**: TwiML with reply message

### `POST /sms/outgoing`
Send outbound SMS

**Body**:
```json
{
  "to": "+1234567890",
  "message": "Your task has been created!"
}
```

### `GET /health`
Health check endpoint

## Deployment

### Option 1: Railway

```bash
railway init
railway up
```

Add environment variables in Railway dashboard.

### Option 2: Fly.io

```bash
fly launch
fly secrets set TWILIO_ACCOUNT_SID=xxx ...
fly deploy
```

### Option 3: Docker

```bash
docker build -t honeydone-agent .
docker run -p 8000:8000 --env-file .env honeydone-agent
```

## Development

### Run Tests

```bash
pytest tests/
```

### Type Checking

```bash
mypy .
```

### Linting

```bash
black .
ruff .
```

## Architecture Diagram

```
┌─────────────┐
│   User      │
│ (Phone/SMS) │
└──────┬──────┘
       │
       v
┌─────────────┐
│   Twilio    │
│ Voice + SMS │
└──────┬──────┘
       │
       v
┌─────────────────────┐
│  Python Agent       │
│  (FastAPI)          │
│                     │
│  - Voice Handler    │
│  - SMS Handler      │
│  - Whisper API      │
│  - Claude Agent     │
│  - State Manager    │
└──────┬──────────────┘
       │
       v
┌─────────────────────┐
│   Supabase          │
│  - Edge Functions   │
│  - Database         │
│  - Storage          │
└─────────────────────┘
```

## Conversation State

Stored in Redis or Supabase:

```json
{
  "phone_number": "+1234567890",
  "task_id": "uuid",
  "state": "triaging",
  "current_question": 1,
  "total_questions": 3,
  "answers": {
    "q1": "Yesterday",
    "q2": "Reset router"
  },
  "persona": "household_ceo",
  "created_at": "2024-01-01T12:00:00Z",
  "expires_at": "2024-01-01T18:00:00Z"
}
```

## Logging

Structured logging with context:

```python
logger.info(
    "Task created",
    extra={
        "task_id": task_id,
        "phone": phone_number,
        "source": "voice"
    }
)
```

View logs:
- Local: Console output
- Production: Loguru → stdout → Railway/Fly.io logs

## Monitoring

Key metrics:
- Call duration
- Transcription accuracy
- Task creation rate
- SMS response time
- Error rate by endpoint

Use Sentry for error tracking:

```python
import sentry_sdk
sentry_sdk.init(dsn="your-dsn")
```

## Security

- ✅ Twilio signature validation on all webhooks
- ✅ HTTPS required for production
- ✅ Service role key in environment only
- ✅ Rate limiting on endpoints
- ✅ Input validation with Pydantic

## Cost Considerations

**Twilio**:
- Voice: ~$0.013/min
- SMS: ~$0.0075/message

**OpenAI**:
- Whisper: ~$0.006/min

**Anthropic**:
- Claude: ~$0.015/1K tokens

**Estimated cost per task**: $0.10 - $0.30 depending on length
