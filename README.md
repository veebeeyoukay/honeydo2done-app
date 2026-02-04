# HoneyDo2Done MVP

AI-powered relationship-aware task management and home services platform.

## Architecture

- **Backend**: Supabase (PostgreSQL, Auth, Storage, Edge Functions)
- **AI**: Claude Opus 4.5 (via Anthropic API)
- **Voice/SMS Agent**: Python + Twilio + Whisper
- **Workflows**: n8n automation
- **iOS App**: Native SwiftUI
- **Speech-to-Text**: OpenAI Whisper

## Project Structure

```
├── supabase/              # Supabase backend
│   ├── migrations/        # Database migrations
│   ├── functions/         # Edge functions (6 endpoints)
│   └── config.toml        # Supabase config
├── python-agent/          # Voice/SMS agent (FastAPI + Twilio)
├── ios/                   # Native iOS app (SwiftUI)
├── n8n/                   # n8n workflow templates
├── docs/                  # Documentation
└── scripts/               # Utility scripts
```

## Core Concepts

### Persona System
- **Household CEO**: Warm, executive summaries for primary decision-maker
- **Technical Partner**: Detailed technical briefs for the fix-it person
- **Patient Guide**: Simple, reassuring language for extended family
- **DIY Mentor**: Step-by-step instructions with safety checks

### Task States
captured → triaging → awaiting_decision → [diy_in_progress | pro_requested] → pro_assigned → scheduled → in_progress → completed

## Getting Started

### Prerequisites
- Node.js 18+
- Python 3.11+
- Supabase CLI
- Xcode 15+ (for iOS)
- n8n instance
- Twilio account

### Setup

1. **Backend (Supabase)**
```bash
cd supabase
supabase start
supabase db reset
```

2. **Python Agent (Voice/SMS)**
```bash
cd python-agent
pip install -r requirements.txt
uvicorn main:app --reload
```

3. **iOS App**
```bash
cd ios/HoneyDoApp
open HoneyDoApp.xcodeproj
# Press Cmd+R to run
```

4. **Environment Variables**
See `.env.example` files in each directory.

## Development

### Phase 1: Backbone (Week 1)
- ✓ Database schema
- ✓ Python voice/SMS agent
- ✓ Triage endpoints
- ✓ n8n workflows

### Phase 2: Persona + Briefs (Week 2)
- Persona selection service
- Brief generation
- Task UI

### Phase 3: DIY + Pro Pipeline (Week 3)
- DIY plan generation
- Partner matching
- Booking flow

### Phase 4: Follow-ups (Week 4)
- Satisfaction surveys
- Referral system
- Preference learning

## Testing

### End-to-End Flows
- Flow A: Voice intake → triage → decision
- Flow B: Jennifer → Vikas assignment
- Flow C: Extended family (Mimi)
- Flow D: Get a Pro
- Flow E: Completion + rating

## Security

- Row Level Security (RLS) enforced
- JWT authentication
- Webhook signature verification
- Photo storage with signed URLs

## Documentation

- [Technical Requirements](docs/TRD.md)
- [API Documentation](docs/API.md)
- [Database Schema](docs/SCHEMA.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
