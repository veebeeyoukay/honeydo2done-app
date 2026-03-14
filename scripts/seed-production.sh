#!/bin/bash

# Seed production database with initial data
# Creates test users and sample partner data

set -e

echo "🌱 Seeding production database..."
echo ""
echo "⚠️  WARNING: This will add test data to your production database!"
echo "   Only run this on a fresh deployment."
echo ""
read -rp "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Get Supabase credentials
read -rp "Supabase URL: " SUPABASE_URL
read -rsp "Supabase Service Role Key: " SUPABASE_KEY
echo ""

echo "📊 Creating seed data..."

cd scripts

# Set environment variables for seed script
export SUPABASE_URL="$SUPABASE_URL"
export SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_KEY"

# Run seed script
npm install
node seed-data.js

echo ""
echo "✅ Production seeding complete!"
echo ""
echo "📝 Created:"
echo "  - 3 test users (Jennifer, Vikas, Mimi)"
echo "  - 2 households"
echo "  - 1 property"
echo "  - 3 sample tasks"
echo "  - 3 partner contacts"
echo ""
echo "🔐 Login credentials will be sent via SMS/email"
echo "   (or check Supabase Auth dashboard)"
