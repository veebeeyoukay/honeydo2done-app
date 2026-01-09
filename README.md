# HoneyDo2Done MVP

AI-powered relationship-aware task management and home services platform.

## Architecture

- **Backend**: Supabase (PostgreSQL, Auth, Storage, Edge Functions)
- **AI**: Claude (via Anthropic API)
- **Voice/SMS**: Lindy integration
- **Workflows**: n8n automation
- **Mobile**: React Native (Expo)
- **Voice-to-Text**: Whisper API

## Project Structure

```
├── supabase/              # Supabase backend
│   ├── migrations/        # Database migrations
│   ├── functions/         # Edge functions
│   └── config.toml        # Supabase config
├── mobile/                # React Native mobile app
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
- Supabase CLI
- Expo CLI
- n8n instance

### Setup

1. **Backend**
```bash
cd supabase
supabase init
supabase db reset
```

2. **Mobile App**
```bash
cd mobile
npm install
npm start
```

3. **Environment Variables**
See `.env.example` files in each directory.

## Development

### Phase 1: Backbone (Week 1)
- ✓ Database schema
- ✓ Lindy webhook
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
