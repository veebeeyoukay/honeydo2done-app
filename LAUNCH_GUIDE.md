# HoneyDo2Done - Complete Launch Guide

This guide will take you from zero to a fully deployed HoneyDo2Done MVP in production.

## 📋 Prerequisites Checklist

Before starting, sign up for these services:

- [ ] **Supabase Account** - https://supabase.com (Free tier OK)
- [ ] **Twilio Account** - https://twilio.com ($20 credit + buy phone number ~$1/month)
- [ ] **Anthropic API** - https://console.anthropic.com (Claude API access)
- [ ] **OpenAI API** - https://platform.openai.com (Whisper API access)
- [ ] **Railway Account** - https://railway.app (Free $5/month credit)
- [ ] **Apple Developer Account** - $99/year (for iOS app)
- [ ] **GitHub Account** - For code hosting

---

## 🚀 Step 1: Deploy Backend (Supabase)

### 1.1 Create Supabase Project

1. Go to https://supabase.com/dashboard
2. Click "New Project"
3. Fill in:
   - Name: `honeydone-mvp`
   - Database Password: (generate strong password, save it!)
   - Region: Choose closest to your users
4. Wait ~2 minutes for provisioning

### 1.2 Note Your Credentials

From Supabase Dashboard > Settings > API:
- **Project URL**: `https://xxxxx.supabase.co`
- **Anon Key**: `eyJhbG...` (public, safe for client)
- **Service Role Key**: `eyJhbG...` (SECRET! Server-side only)

### 1.3 Deploy Database & Functions

```bash
# From project root
cd supabase

# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy migrations
supabase db push

# Deploy edge functions
./scripts/deploy-supabase.sh
```

When prompted, enter:
- ANTHROPIC_API_KEY: `sk-ant-...`
- OPENAI_API_KEY: `sk-...`
- N8N_WEBHOOK_URL: (leave blank for now, add later)

---

## 📞 Step 2: Set Up Twilio

### 2.1 Buy Phone Number

1. Go to https://console.twilio.com
2. Phone Numbers > Buy a Number
3. Search for: `United States`, `Voice`, `SMS`
4. Buy a number (~$1/month)
5. Note your phone number: `+1XXXXXXXXXX`

### 2.2 Get API Credentials

From https://console.twilio.com:
- **Account SID**: `ACxxxx...`
- **Auth Token**: `xxxx...` (click "show" to reveal)

---

## 🐍 Step 3: Deploy Python Agent

### 3.1 Deploy to Railway

```bash
./scripts/deploy-python-agent.sh railway
```

This will:
1. Install Railway CLI
2. Create new Railway project
3. Prompt for environment variables
4. Deploy the Python agent
5. Give you a live URL: `https://your-app.railway.app`

**Enter when prompted**:
- SUPABASE_URL: From Step 1.2
- SUPABASE_SERVICE_ROLE_KEY: From Step 1.2
- ANTHROPIC_API_KEY: `sk-ant-...`
- OPENAI_API_KEY: `sk-...`
- TWILIO_ACCOUNT_SID: From Step 2.2
- TWILIO_AUTH_TOKEN: From Step 2.2
- TWILIO_PHONE_NUMBER: From Step 2.1

### 3.2 Configure Twilio Webhooks

```bash
./scripts/setup-twilio.sh
```

Enter your Railway URL when prompted.

**Or manually** in Twilio Console:
1. Go to Phone Numbers > Manage > Active Numbers
2. Click your number
3. Under "Voice Configuration":
   - A CALL COMES IN: `https://your-app.railway.app/voice/incoming` (POST)
4. Under "Messaging":
   - A MESSAGE COMES IN: `https://your-app.railway.app/sms/incoming` (POST)
5. Save

---

## 📱 Step 4: Build iOS App

### 4.1 Configure Xcode Project

1. Open `ios/HoneyDoApp.xcodeproj` in Xcode
2. Select project > Signing & Capabilities
3. Set your Team (Apple Developer account)
4. Change Bundle Identifier to unique value

### 4.2 Add Supabase Package

1. File > Add Packages
2. Enter: `https://github.com/supabase/supabase-swift`
3. Click "Add Package"

### 4.3 Update Config

Edit `ios/HoneyDoApp/Core/Network/Config.swift`:

```swift
struct Config {
    static let supabaseURL = "https://YOUR_PROJECT.supabase.co"
    static let supabaseAnonKey = "YOUR_ANON_KEY"
    static let openAIAPIKey = "sk-YOUR_OPENAI_KEY"
    static let appVersion = "0.1.0"
}
```

### 4.4 Build & Test

1. Select iPhone simulator
2. Press Cmd+R to run
3. Test:
   - Sign in with phone number
   - Create a task
   - View task list

### 4.5 Deploy to TestFlight

1. Product > Archive (wait ~5 min)
2. Upload to App Store Connect
3. Submit for TestFlight review
4. Add beta testers
5. Share TestFlight link

---

## 🌐 Step 5: Deploy Admin Panel

```bash
cd admin-panel
npm install

# Create environment file
cp .env.local.example .env.local
# Edit .env.local with your Supabase credentials

# Test locally
npm run dev
# Open http://localhost:3001

# Deploy to Vercel
npm install -g vercel
vercel
```

Add environment variables in Vercel dashboard.

---

## 🌱 Step 6: Seed Initial Data

```bash
./scripts/seed-production.sh
```

This creates:
- 3 test users (Jennifer, Vikas, Mimi)
- 2 households
- Sample tasks
- 3 partner contacts

---

## 🧪 Step 7: Test End-to-End

```bash
./scripts/test-deployment.sh
```

Manual tests:

### Test 1: Voice Call
1. Call your Twilio number
2. Say: "My WiFi router is not working. It started yesterday."
3. Hang up
4. Check:
   - Task created in Supabase
   - SMS received with triage questions
5. Reply to SMS with answers
6. Verify task moves to "awaiting_decision"

### Test 2: iOS App
1. Open app on device
2. Sign in with test phone number
3. Create a task
4. View task in list
5. Tap task to see details
6. Start DIY or request pro

### Test 3: Admin Panel
1. Go to https://your-admin.vercel.app
2. Login as admin
3. View task dashboard
4. Try assigning a partner

---

## 👥 Step 8: Onboard Partners

### Option A: Manual Entry (Admin Panel)

1. Go to Admin Panel > Partners
2. Click "Add Partner"
3. Fill in:
   - Business name
   - Contact name
   - Phone & email
   - Categories (e.g., "smart_home", "plumbing")
   - Service ZIPs
   - Hourly rate range
4. Save

### Option B: SQL Import

```sql
INSERT INTO partners (
  business_name, contact_name, phone, email,
  categories, service_zips, hourly_rate_low, hourly_rate_high, is_active
) VALUES
  ('Tampa Tech Solutions', 'Mike Rodriguez', '+15555551001', 'mike@example.com',
   '{"smart_home", "tech_guard"}', '{"33601", "33602"}', 75, 125, true),
  ('AquaClear Pool Service', 'Sarah Johnson', '+15555551002', 'sarah@example.com',
   '{"aqua_tech"}', '{"33601", "33605"}', 100, 150, true);
```

---

## 💰 Step 9: Add Payment (Optional for MVP)

### Stripe Setup

1. Create Stripe account
2. Get API keys
3. Add to Supabase secrets:
   ```bash
   supabase secrets set STRIPE_SECRET_KEY=sk_test_...
   ```

4. Create edge function for checkout:
   ```typescript
   // supabase/functions/create-checkout/index.ts
   import Stripe from 'stripe'

   const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!)

   Deno.serve(async (req) => {
     const { taskId, amount } = await req.json()

     const session = await stripe.checkout.sessions.create({
       payment_method_types: ['card'],
       line_items: [{
         price_data: {
           currency: 'usd',
           unit_amount: amount * 100,
           product_data: {
             name: 'Home Service',
           },
         },
         quantity: 1,
       }],
       mode: 'payment',
       success_url: `honeydone://task/${taskId}/success`,
       cancel_url: `honeydone://task/${taskId}`,
     })

     return new Response(JSON.stringify({ url: session.url }))
   })
   ```

---

## 📊 Step 10: Monitor & Iterate

### Daily Checks

1. **Admin Panel Dashboard**
   - Pro requests needing assignment
   - Failed tasks
   - Partner response times

2. **Supabase Logs**
   - Edge function errors
   - Database slow queries

3. **Railway Logs**
   - Python agent errors
   - Twilio webhook failures

### Weekly Reviews

1. **User Metrics**
   - Signups
   - Task completion rate
   - DIY vs Pro ratio

2. **Partner Metrics**
   - Response time
   - Acceptance rate
   - Customer ratings

3. **Revenue**
   - Tasks completed
   - Average transaction value
   - Partner payouts

---

## 🚨 Troubleshooting

### Voice calls not creating tasks

**Check**:
1. Railway logs: `railway logs`
2. Twilio webhook configuration
3. Supabase edge function logs

**Fix**:
- Verify Railway URL is correct in Twilio
- Check SUPABASE_URL env var in Railway
- Test `/health` endpoint

### SMS not working

**Check**:
1. Twilio messaging configuration
2. Phone number capabilities (SMS enabled)

**Fix**:
- Verify webhook URL in Twilio
- Check conversation state in Redis/memory
- Test with simple message

### iOS app can't login

**Check**:
1. Config.swift has correct Supabase URL
2. Supabase Auth is enabled
3. Phone auth is enabled in Supabase

**Fix**:
- Verify anon key is correct
- Enable phone auth in Supabase dashboard
- Check iOS console for errors

### Partners not receiving job briefs

**Check**:
1. Partner request created in database
2. Python agent can send SMS
3. Partner phone numbers are valid

**Fix**:
- Check n8n workflow is running
- Verify Twilio credits
- Test SMS manually

---

## 💡 Post-Launch Optimizations

### Week 1-2
- [ ] Monitor error rates
- [ ] Fix critical bugs
- [ ] Gather user feedback
- [ ] Optimize AI prompts based on actual conversations

### Week 3-4
- [ ] Add more partners in target area
- [ ] Implement payment flow
- [ ] Add push notifications
- [ ] Improve partner matching algorithm

### Month 2
- [ ] Analytics dashboard
- [ ] Automated partner payouts
- [ ] Referral system
- [ ] Marketing website

---

## 📞 Need Help?

- **GitHub Issues**: Post questions/bugs
- **Supabase Discord**: Database/auth help
- **Twilio Support**: Voice/SMS issues

---

## 🎉 You're Live!

Congratulations! HoneyDo2Done is now live in production.

**Share your launch**:
- Tweet about it
- Post in communities
- Invite friends to beta test

**Next steps**:
1. Get 10 beta users
2. Complete 10 successful tasks
3. Iterate based on feedback
4. Scale up!
