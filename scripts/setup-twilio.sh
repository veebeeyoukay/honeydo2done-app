#!/bin/bash

# Setup Twilio for HoneyDo2Done
# This script helps configure Twilio webhooks

set -e

echo "📞 Setting up Twilio for HoneyDo2Done..."
echo ""

# Get Python agent URL
read -rp "Enter your Python agent URL (e.g., https://your-app.railway.app): " AGENT_URL

# Remove trailing slash
AGENT_URL="${AGENT_URL%/}"

echo ""
echo "✅ Configuration ready!"
echo ""
echo "📝 Manual Steps - Configure these in Twilio Console:"
echo "   https://console.twilio.com/us1/develop/phone-numbers/manage/incoming"
echo ""
echo "1. Select your phone number"
echo "2. Under 'Voice Configuration':"
echo "   - A CALL COMES IN: Webhook"
echo "   - URL: ${AGENT_URL}/voice/incoming"
echo "   - HTTP POST"
echo ""
echo "3. Under 'Messaging Configuration':"
echo "   - A MESSAGE COMES IN: Webhook"
echo "   - URL: ${AGENT_URL}/sms/incoming"
echo "   - HTTP POST"
echo ""
echo "4. Under 'Status Callback':"
echo "   - URL: ${AGENT_URL}/voice/status"
echo "   - HTTP POST"
echo ""
echo "5. Click 'Save' at the bottom"
echo ""
echo "🧪 Testing:"
echo "   - Call your Twilio number and describe a task"
echo "   - Text your Twilio number with a task description"
echo ""

# Optionally use Twilio CLI if installed
if command -v twilio &> /dev/null; then
    echo "🔧 Twilio CLI detected. Would you like to configure automatically? (y/n)"
    read -r auto_config

    if [ "$auto_config" = "y" ]; then
        echo "Enter your Twilio phone number (with country code, e.g., +15555551234):"
        read -r PHONE_NUMBER

        echo "Configuring webhooks..."

        twilio phone-numbers:update "$PHONE_NUMBER" \
            --voice-url="${AGENT_URL}/voice/incoming" \
            --voice-method=POST \
            --sms-url="${AGENT_URL}/sms/incoming" \
            --sms-method=POST \
            --status-callback="${AGENT_URL}/voice/status" \
            --status-callback-method=POST

        echo "✅ Webhooks configured automatically!"
    fi
else
    echo "💡 Tip: Install Twilio CLI for easier configuration:"
    echo "   npm install -g twilio-cli"
fi

echo ""
echo "🎉 Twilio setup complete!"
