#!/usr/bin/env node

/**
 * Seed test data for HoneyDo2Done development
 *
 * Creates:
 * - Test users (Jennifer, Vikas, Mimi)
 * - Household with members
 * - Sample property
 * - Test tasks
 * - Sample partners
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL || 'http://localhost:54321';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

if (!supabaseKey) {
  console.error('Error: SUPABASE_SERVICE_ROLE_KEY not set');
  console.log('Usage: SUPABASE_SERVICE_ROLE_KEY=your-key node scripts/seed-data.js');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function seedData() {
  console.log('🌱 Seeding test data...\n');

  try {
    // 1. Create test users
    console.log('Creating users...');

    const users = [
      {
        email: 'jennifer@example.com',
        phone: '+15555551001',
        full_name: 'Jennifer Smith',
        role: 'customer',
        persona_type: 'household_ceo',
        communication_preference: 'standard',
      },
      {
        email: 'vikas@example.com',
        phone: '+15555551002',
        full_name: 'Vikas Smith',
        role: 'customer',
        persona_type: 'technical_partner',
        communication_preference: 'detailed',
      },
      {
        email: 'mimi@example.com',
        phone: '+15555551003',
        full_name: 'Mimi Johnson',
        role: 'customer',
        persona_type: 'patient_guide',
        communication_preference: 'minimal',
      },
    ];

    const createdUsers = [];

    for (const user of users) {
      const { data, error } = await supabase
        .from('users')
        .insert(user)
        .select()
        .single();

      if (error) {
        console.error(`Error creating user ${user.full_name}:`, error.message);
      } else {
        console.log(`✓ Created user: ${data.full_name} (${data.id})`);
        createdUsers.push(data);
      }
    }

    const jennifer = createdUsers[0];
    const vikas = createdUsers[1];
    const mimi = createdUsers[2];

    // 2. Create household for Jennifer
    console.log('\nCreating household...');

    const { data: household, error: householdError } = await supabase
      .from('households')
      .insert({
        name: "Jennifer's Home",
        created_by: jennifer.id,
      })
      .select()
      .single();

    if (householdError) {
      throw householdError;
    }

    console.log(`✓ Created household: ${household.name} (${household.id})`);

    // 3. Add household members
    console.log('\nAdding household members...');

    const members = [
      {
        household_id: household.id,
        user_id: jennifer.id,
        role: 'owner',
        is_extended_family: false,
      },
      {
        household_id: household.id,
        user_id: vikas.id,
        role: 'member',
        persona_override: 'technical_partner',
        is_extended_family: false,
      },
    ];

    for (const member of members) {
      await supabase.from('household_members').insert(member);
    }

    console.log('✓ Added Jennifer (owner)');
    console.log('✓ Added Vikas (technical partner)');

    // 4. Create property
    console.log('\nCreating property...');

    const { data: property, error: propertyError } = await supabase
      .from('properties')
      .insert({
        household_id: household.id,
        name: 'Main House',
        address_line1: '123 Main St',
        city: 'Tampa',
        state: 'FL',
        zip: '33601',
        property_type: 'single_family',
      })
      .select()
      .single();

    if (propertyError) {
      throw propertyError;
    }

    console.log(`✓ Created property: ${property.name}`);

    // 5. Create Mimi's household (extended family)
    console.log('\nCreating extended family household...');

    const { data: mimiHousehold, error: mimiHouseholdError } = await supabase
      .from('households')
      .insert({
        name: "Mimi's Home",
        created_by: mimi.id,
      })
      .select()
      .single();

    if (mimiHouseholdError) {
      throw mimiHouseholdError;
    }

    await supabase.from('household_members').insert({
      household_id: mimiHousehold.id,
      user_id: mimi.id,
      role: 'owner',
      is_extended_family: true,
    });

    // Add Jennifer as extended family member of Mimi's household
    await supabase.from('household_members').insert({
      household_id: mimiHousehold.id,
      user_id: jennifer.id,
      role: 'extended_family',
      is_extended_family: true,
    });

    console.log(`✓ Created Mimi's household with Jennifer as extended family`);

    // 6. Create sample tasks
    console.log('\nCreating sample tasks...');

    const tasks = [
      {
        household_id: household.id,
        property_id: property.id,
        created_by: jennifer.id,
        title: 'WiFi Router Issues',
        description: 'The 5GHz band on our WiFi router keeps dropping. Started yesterday.',
        status: 'captured',
        priority: 'normal',
        category: 'smart_home',
        structured_data: {
          category: 'smart_home',
          location_in_home: 'Office',
          symptoms: ['5GHz drops frequently', '2.4GHz works fine'],
          duration: '1 day',
          what_tried: ['Reset router'],
          urgency: 'normal',
          confidence: 0.85,
        },
      },
      {
        household_id: household.id,
        property_id: property.id,
        created_by: jennifer.id,
        assigned_to: vikas.id,
        title: 'Pool Pump Making Noise',
        description: 'Pool pump is making a grinding noise when it starts.',
        status: 'awaiting_decision',
        priority: 'high',
        category: 'aqua_tech',
        structured_data: {
          category: 'aqua_tech',
          location_in_home: 'Backyard',
          symptoms: ['Grinding noise on startup', 'Unusual vibration'],
          duration: '3 days',
          urgency: 'high',
          safety_flags: ['mechanical_failure'],
          confidence: 0.90,
        },
      },
      {
        household_id: mimiHousehold.id,
        created_by: jennifer.id,
        title: "Help Mimi with TV Remote",
        description: "Mimi's TV remote isn't working. Need to help her troubleshoot.",
        status: 'triaging',
        priority: 'normal',
        category: 'tech_guard',
        is_extended_family: true,
        structured_data: {
          category: 'tech_guard',
          location_in_home: 'Living room',
          symptoms: ['Remote not responding'],
          confidence: 0.70,
        },
      },
    ];

    for (const task of tasks) {
      const { data, error } = await supabase
        .from('tasks')
        .insert(task)
        .select()
        .single();

      if (error) {
        console.error(`Error creating task:`, error.message);
      } else {
        console.log(`✓ Created task: ${data.title} (${data.status})`);
      }
    }

    // 7. Create sample partners
    console.log('\nCreating sample partners...');

    const partners = [
      {
        business_name: 'Tampa Tech Solutions',
        contact_name: 'Mike Rodriguez',
        phone: '+15555552001',
        email: 'mike@tampatech.example.com',
        categories: ['smart_home', 'tech_guard'],
        service_zips: ['33601', '33602', '33603'],
        rating: 4.8,
        total_jobs: 127,
        is_active: true,
        hourly_rate_low: 75,
        hourly_rate_high: 125,
        response_time_minutes: 15,
      },
      {
        business_name: 'AquaClear Pool Service',
        contact_name: 'Sarah Johnson',
        phone: '+15555552002',
        email: 'sarah@aquaclear.example.com',
        categories: ['aqua_tech'],
        service_zips: ['33601', '33602', '33605'],
        rating: 4.9,
        total_jobs: 203,
        is_active: true,
        hourly_rate_low: 100,
        hourly_rate_high: 150,
        response_time_minutes: 30,
      },
      {
        business_name: 'Home Handyman Services',
        contact_name: 'John Davis',
        phone: '+15555552003',
        email: 'john@homehandyman.example.com',
        categories: ['general', 'garage_tech', 'hvac'],
        service_zips: ['33601', '33602', '33603', '33604'],
        rating: 4.6,
        total_jobs: 89,
        is_active: true,
        hourly_rate_low: 60,
        hourly_rate_high: 100,
        response_time_minutes: 45,
      },
    ];

    for (const partner of partners) {
      const { data, error } = await supabase
        .from('partners')
        .insert(partner)
        .select()
        .single();

      if (error) {
        console.error(`Error creating partner:`, error.message);
      } else {
        console.log(`✓ Created partner: ${data.business_name} (${data.categories.join(', ')})`);
      }
    }

    console.log('\n✅ Seed data created successfully!\n');

    console.log('Test Accounts:');
    console.log('─────────────────────────────────────────');
    console.log('Jennifer (Household CEO)');
    console.log(`  Email: jennifer@example.com`);
    console.log(`  Phone: +15555551001`);
    console.log(`  ID: ${jennifer.id}`);
    console.log('');
    console.log('Vikas (Technical Partner)');
    console.log(`  Email: vikas@example.com`);
    console.log(`  Phone: +15555551002`);
    console.log(`  ID: ${vikas.id}`);
    console.log('');
    console.log('Mimi (Patient Guide / Extended Family)');
    console.log(`  Email: mimi@example.com`);
    console.log(`  Phone: +15555551003`);
    console.log(`  ID: ${mimi.id}`);
    console.log('─────────────────────────────────────────\n');

  } catch (error) {
    console.error('\n❌ Error seeding data:', error.message);
    process.exit(1);
  }
}

seedData();
