# 🚀 Quick Deployment Guide

## All Your Keys in One Place

### Supabase Keys
- **Project URL:** `https://asbfhxdomvclwsrekdxi.supabase.co`
- **Project Ref:** `asbfhxdomvclwsrekdxi`
- **Anon Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzYmZoeGRvbXZjbHdzcmVrZHhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzMjI3OTUsImV4cCI6MjA2OTg5ODc5NX0.0VzbWIc-uxIDhI03g04n8HSPRQ_p01UTJQ1sg8ggigU`
- **Service Role Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzYmZoeGRvbXZjbHdzcmVrZHhpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NDMyMjc5NSwiZXhwIjoyMDY5ODk4Nzk1fQ.iPXQg3KBXGXNlJwMzv5Novm0Qnc7Y5sPNE4RYxg3wqI`

### Email Keys
- **Resend API Key:** `re_ZDZNM8Qv_GTXNpw3oNCrM5rSsLubBcLys`

## Step-by-Step Deployment

### 1️⃣ Add Secrets to Supabase

Go to: **Supabase Dashboard → Settings → Edge Functions → Secrets**

Add these two secrets:

```
RESEND_API_KEY
↓
re_ZDZNM8Qv_GTXNpw3oNCrM5rSsLubBcLys

SUPABASE_SERVICE_ROLE_KEY
↓
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzYmZoeGRvbXZjbHdzcmVrZHhpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NDMyMjc5NSwiZXhwIjoyMDY5ODk4Nzk1fQ.iPXQg3KBXGXNlJwMzv5Novm0Qnc7Y5sPNE4RYxg3wqI
```

### 2️⃣ Set Up Supervisor in Database

Run this in Supabase SQL Editor:

```sql
-- Create supervisor
INSERT INTO public.supervisors (full_name, email, phone, department)
VALUES ('John Smith', 'john.smith@yourcompany.com', '416-555-0100', 'Nursing')
ON CONFLICT (email) DO NOTHING;

-- Get supervisor ID
SELECT id, full_name, email FROM public.supervisors;

-- Assign to employees (replace 1 with actual supervisor ID)
UPDATE public.employee
SET supervisor_id = 1
WHERE emp_id = 16;

-- Verify
SELECT 
  e.emp_id,
  e.first_name || ' ' || e.last_name as employee_name,
  s.full_name as supervisor_name,
  s.email as supervisor_email
FROM public.employee e
LEFT JOIN public.supervisors s ON e.supervisor_id = s.id
WHERE e.emp_id = 16;
```

### 3️⃣ Deploy Function

```bash
cd Nurse-application
supabase link --project-ref asbfhxdomvclwsrekdxi
supabase functions deploy chatbot-handle-request
```

### 4️⃣ Test

```bash
curl -X POST 'https://asbfhxdomvclwsrekdxi.supabase.co/functions/v1/chatbot-handle-request' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzYmZoeGRvbXZjbHdzcmVrZHhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzMjI3OTUsImV4cCI6MjA2OTg5ODc5NX0.0VzbWIc-uxIDhI03g04n8HSPRQ_p01UTJQ1sg8ggigU' \
  -H 'Content-Type: application/json' \
  -d '{"emp_id": 16, "message": "I want to take leave today"}'
```

## ✅ Done!

That's it! Your chatbot will now send emails when nurses request leave.

## 📚 More Details

See `NEXT_STEPS.md` for complete instructions
