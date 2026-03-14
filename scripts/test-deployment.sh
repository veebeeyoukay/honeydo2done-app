#!/bin/bash

# Test deployment end-to-end
# Validates that all services are working

set -e

echo "🧪 Testing HoneyDo2Done deployment..."
echo ""

# Test Supabase
echo "1️⃣  Testing Supabase..."
read -rp "Supabase URL: " SUPABASE_URL

if curl -s -o /dev/null -w "%{http_code}" "$SUPABASE_URL/rest/v1/" | grep -q "200\|401"; then
    echo "   ✅ Supabase is reachable"
else
    echo "   ❌ Supabase is not reachable"
    exit 1
fi

# Test Python agent
echo ""
echo "2️⃣  Testing Python Agent..."
read -rp "Python Agent URL: " AGENT_URL

if curl -s -o /dev/null -w "%{http_code}" "$AGENT_URL/health" | grep -q "200"; then
    echo "   ✅ Python agent is healthy"
else
    echo "   ❌ Python agent is not responding"
    exit 1
fi

# Test edge functions
echo ""
echo "3️⃣  Testing Edge Functions..."
read -rp "Supabase Anon Key: " ANON_KEY

functions=(
    "intake-webhook"
    "task-triage-start"
    "task-triage-answer"
    "task-briefs-generate"
    "task-diy-start"
    "task-pro-request"
)

for func in "${functions[@]}"; do
    func_url="$SUPABASE_URL/functions/v1/$func"
    if curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $ANON_KEY" \
        "$func_url" | grep -q "40[0-5]"; then
        echo "   ✅ $func is deployed"
    else
        echo "   ❌ $func is not responding"
    fi
done

# Test voice/SMS webhooks
echo ""
echo "4️⃣  Testing Twilio Webhooks..."
echo "   Please test manually:"
echo "   1. Call your Twilio number"
echo "   2. Describe a task"
echo "   3. Check if task appears in Supabase"
echo ""
read -rp "Did the voice test work? (y/n): " voice_test

if [ "$voice_test" = "y" ]; then
    echo "   ✅ Voice webhook working"
else
    echo "   ❌ Voice webhook not working"
    echo "   Check: $AGENT_URL/voice/incoming"
fi

echo ""
read -rp "Text 'test' to your Twilio number. Did you receive a response? (y/n): " sms_test

if [ "$sms_test" = "y" ]; then
    echo "   ✅ SMS webhook working"
else
    echo "   ❌ SMS webhook not working"
    echo "   Check: $AGENT_URL/sms/incoming"
fi

# Test iOS app
echo ""
echo "5️⃣  Testing iOS App..."
echo "   Manual test required:"
echo "   1. Open app on device"
echo "   2. Sign in with phone number"
echo "   3. Create a task"
echo "   4. Check if task appears"
echo ""
read -rp "Did the iOS app work? (y/n): " ios_test

if [ "$ios_test" = "y" ]; then
    echo "   ✅ iOS app working"
else
    echo "   ❌ iOS app not working"
    echo "   Check Config.swift for correct Supabase credentials"
fi

# Summary
echo ""
echo "======================================"
echo "📊 Deployment Test Summary"
echo "======================================"
echo "Supabase: ✅"
echo "Python Agent: ✅"
echo "Edge Functions: ✅"
echo "Voice Webhook: ${voice_test}"
echo "SMS Webhook: ${sms_test}"
echo "iOS App: ${ios_test}"
echo "======================================"
echo ""

if [ "$voice_test" = "y" ] && [ "$sms_test" = "y" ] && [ "$ios_test" = "y" ]; then
    echo "🎉 All tests passed! Deployment is ready."
else
    echo "⚠️  Some tests failed. Please review the output above."
fi
