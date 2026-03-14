#!/bin/bash

# Deploy Supabase project
# This script deploys database migrations and edge functions to Supabase

set -e

echo "🚀 Deploying HoneyDo2Done to Supabase..."

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Installing..."
    npm install -g supabase
fi

# Check if logged in
if ! supabase projects list &> /dev/null; then
    echo "📝 Please login to Supabase:"
    supabase login
fi

# Link to project if not already linked
if [ ! -f "supabase/.temp/project-ref" ]; then
    echo "🔗 Linking to Supabase project..."
    echo "Please enter your project reference (from Supabase dashboard):"
    read -r PROJECT_REF
    cd supabase
    supabase link --project-ref "$PROJECT_REF"
    cd ..
fi

echo "📊 Deploying database migrations..."
cd supabase
supabase db push

echo "⚡ Deploying edge functions..."

# Deploy all edge functions
functions=(
    "intake-webhook"
    "task-triage-start"
    "task-triage-answer"
    "task-briefs-generate"
    "task-diy-start"
    "task-pro-request"
)

for func in "${functions[@]}"; do
    echo "  Deploying $func..."
    supabase functions deploy "$func" --no-verify-jwt
done

echo "🔐 Setting secrets..."
echo "Enter your secrets (press Enter to skip if already set):"

read -rp "ANTHROPIC_API_KEY: " anthropic_key
if [ -n "$anthropic_key" ]; then
    supabase secrets set ANTHROPIC_API_KEY="$anthropic_key"
fi

read -rp "OPENAI_API_KEY: " openai_key
if [ -n "$openai_key" ]; then
    supabase secrets set OPENAI_API_KEY="$openai_key"
fi

read -rp "N8N_WEBHOOK_URL: " n8n_url
if [ -n "$n8n_url" ]; then
    supabase secrets set N8N_WEBHOOK_URL="$n8n_url"
fi

echo "✅ Supabase deployment complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Note your Supabase URL and anon key from the dashboard"
echo "  2. Update Python agent .env file with these values"
echo "  3. Deploy Python agent (./scripts/deploy-python-agent.sh)"
echo ""
