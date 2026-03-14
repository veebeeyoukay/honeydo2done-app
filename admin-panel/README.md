# HoneyDo2Done Admin Panel

Web-based admin panel for managing partners, viewing tasks, and operations.

## Features

- 📊 Task Dashboard - View all tasks by status
- 👥 Partner Management - Add, edit, and manage pro partners
- 🔄 Manual Assignment - Assign partners to tasks manually
- 📈 Analytics - View key metrics
- ⚙️ Operations Tools - Bulk updates and manual overrides

## Tech Stack

- **Frontend**: Next.js 14 + React
- **Styling**: Tailwind CSS
- **Backend**: Supabase (direct connection)
- **Auth**: Supabase Auth (admin role required)

## Setup

### 1. Install Dependencies

```bash
cd admin-panel
npm install
```

### 2. Configure Environment

Create `.env.local`:

```bash
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### 3. Run Development Server

```bash
npm run dev
```

Open [http://localhost:3001](http://localhost:3001)

### 4. Create Admin User

In Supabase SQL Editor:

```sql
-- Create admin user
INSERT INTO auth.users (email, encrypted_password, email_confirmed_at)
VALUES ('admin@honeydone.com', crypt('your-password', gen_salt('bf')), now());

-- Get the user ID and update role
UPDATE users
SET role = 'admin'
WHERE email = 'admin@honeydone.com';
```

## Features

### Task Dashboard

- View all tasks with filters (status, priority, category)
- Click to view details and chat history
- Quick actions: assign partner, change status
- Search by title or description

### Partner Management

- List all partners with contact info
- Add new partners with service areas
- Edit partner details
- Activate/deactivate partners
- View partner stats (jobs completed, rating)

### Manual Assignment

- Browse pro-requested tasks
- Search and filter available partners
- Assign partner with one click
- Send notification to customer and partner

### Analytics

- Tasks by status (pie chart)
- Tasks by category
- Partner utilization
- Average resolution time
- Customer satisfaction

## Deployment

### Vercel (Recommended)

```bash
npm install -g vercel
vercel
```

Add environment variables in Vercel dashboard.

### Docker

```bash
docker build -t honeydone-admin .
docker run -p 3001:3001 --env-file .env.local honeydone-admin
```

## Security

- Admin panel requires authentication
- Only users with `role = 'admin'` or `role = 'ops'` can access
- Service role key used for privileged operations
- CSRF protection enabled
- Rate limiting on API routes

## Usage

### Add a Partner

1. Navigate to Partners page
2. Click "Add Partner"
3. Fill in:
   - Business name
   - Contact name
   - Phone & email
   - Service categories
   - Service ZIP codes
   - Hourly rate range
4. Click "Save"

### Assign Partner to Task

1. Navigate to Tasks page
2. Filter by "Pro Requested"
3. Click on a task
4. Click "Assign Partner"
5. Search or browse partners
6. Click "Assign"
7. Partner and customer are notified

### View Analytics

1. Navigate to Dashboard
2. View real-time metrics
3. Filter by date range
4. Export data as CSV

## API Routes

Admin panel includes API routes for operations:

- `POST /api/partners` - Create partner
- `PUT /api/partners/[id]` - Update partner
- `POST /api/tasks/[id]/assign` - Assign partner to task
- `PUT /api/tasks/[id]/status` - Update task status
- `GET /api/analytics` - Get analytics data

## Troubleshooting

### Cannot login

- Check user has `role = 'admin'` in database
- Verify Supabase URL and keys in `.env.local`
- Check browser console for errors

### Partners not loading

- Verify RLS policies allow admin access
- Check service role key is correct
- Review Supabase logs

### Assignment not working

- Ensure task is in `pro_requested` status
- Verify partner is active
- Check partner's service ZIPs match task property
