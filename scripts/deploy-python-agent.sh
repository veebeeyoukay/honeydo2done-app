#!/bin/bash

# Deploy Python Agent to Railway or Fly.io
# Choose your platform: railway or fly

set -e

PLATFORM="${1:-railway}" # Default to Railway

echo "🚀 Deploying Python Agent to $PLATFORM..."

if [ "$PLATFORM" = "railway" ]; then
    deploy_railway
elif [ "$PLATFORM" = "fly" ]; then
    deploy_fly
else
    echo "❌ Invalid platform. Use: ./deploy-python-agent.sh [railway|fly]"
    exit 1
fi

function deploy_railway() {
    echo "🚂 Deploying to Railway..."

    # Check if Railway CLI is installed
    if ! command -v railway &> /dev/null; then
        echo "📦 Installing Railway CLI..."
        npm install -g @railway/cli
    fi

    # Login
    if ! railway whoami &> /dev/null; then
        echo "📝 Please login to Railway:"
        railway login
    fi

    cd python-agent

    # Initialize if needed
    if [ ! -f "railway.json" ]; then
        echo "🔧 Initializing Railway project..."
        railway init
    fi

    # Set environment variables
    echo "🔐 Setting environment variables..."
    echo "Enter your environment variables:"

    read -rp "SUPABASE_URL: " supabase_url
    railway variables set SUPABASE_URL="$supabase_url"

    read -rp "SUPABASE_SERVICE_ROLE_KEY: " supabase_key
    railway variables set SUPABASE_SERVICE_ROLE_KEY="$supabase_key"

    read -rp "ANTHROPIC_API_KEY: " anthropic_key
    railway variables set ANTHROPIC_API_KEY="$anthropic_key"

    read -rp "OPENAI_API_KEY: " openai_key
    railway variables set OPENAI_API_KEY="$openai_key"

    read -rp "TWILIO_ACCOUNT_SID: " twilio_sid
    railway variables set TWILIO_ACCOUNT_SID="$twilio_sid"

    read -rp "TWILIO_AUTH_TOKEN: " twilio_token
    railway variables set TWILIO_AUTH_TOKEN="$twilio_token"

    read -rp "TWILIO_PHONE_NUMBER: " twilio_phone
    railway variables set TWILIO_PHONE_NUMBER="$twilio_phone"

    # Deploy
    echo "🚀 Deploying to Railway..."
    railway up

    # Get the URL
    RAILWAY_URL=$(railway domain)
    echo ""
    echo "✅ Deployment complete!"
    echo "🌐 Your agent is live at: $RAILWAY_URL"
    echo ""
    echo "📝 Next steps:"
    echo "  1. Configure Twilio webhooks to point to: $RAILWAY_URL"
    echo "  2. Voice URL: $RAILWAY_URL/voice/incoming"
    echo "  3. SMS URL: $RAILWAY_URL/sms/incoming"
    echo ""

    cd ..
}

function deploy_fly() {
    echo "✈️  Deploying to Fly.io..."

    # Check if flyctl is installed
    if ! command -v flyctl &> /dev/null; then
        echo "📦 Installing Fly.io CLI..."
        curl -L https://fly.io/install.sh | sh
    fi

    # Login
    if ! flyctl auth whoami &> /dev/null; then
        echo "📝 Please login to Fly.io:"
        flyctl auth login
    fi

    cd python-agent

    # Initialize if needed
    if [ ! -f "fly.toml" ]; then
        echo "🔧 Initializing Fly.io app..."
        flyctl launch --no-deploy
    fi

    # Set secrets
    echo "🔐 Setting secrets..."
    echo "Enter your environment variables:"

    read -rp "SUPABASE_URL: " supabase_url
    flyctl secrets set SUPABASE_URL="$supabase_url"

    read -rp "SUPABASE_SERVICE_ROLE_KEY: " supabase_key
    flyctl secrets set SUPABASE_SERVICE_ROLE_KEY="$supabase_key"

    read -rp "ANTHROPIC_API_KEY: " anthropic_key
    flyctl secrets set ANTHROPIC_API_KEY="$anthropic_key"

    read -rp "OPENAI_API_KEY: " openai_key
    flyctl secrets set OPENAI_API_KEY="$openai_key"

    read -rp "TWILIO_ACCOUNT_SID: " twilio_sid
    flyctl secrets set TWILIO_ACCOUNT_SID="$twilio_sid"

    read -rp "TWILIO_AUTH_TOKEN: " twilio_token
    flyctl secrets set TWILIO_AUTH_TOKEN="$twilio_token"

    read -rp "TWILIO_PHONE_NUMBER: " twilio_phone
    flyctl secrets set TWILIO_PHONE_NUMBER="$twilio_phone"

    # Deploy
    echo "🚀 Deploying to Fly.io..."
    flyctl deploy

    # Get the URL
    FLY_URL=$(flyctl info --json | jq -r '.Hostname')
    echo ""
    echo "✅ Deployment complete!"
    echo "🌐 Your agent is live at: https://$FLY_URL"
    echo ""
    echo "📝 Next steps:"
    echo "  1. Configure Twilio webhooks to point to: https://$FLY_URL"
    echo "  2. Voice URL: https://$FLY_URL/voice/incoming"
    echo "  3. SMS URL: https://$FLY_URL/sms/incoming"
    echo ""

    cd ..
}
