# Chatbot Database Setup

## Required Database Changes

Before using the chatbot features, you need to update your `shift_change_requests` table:

### 1. Run the Migration

Execute the SQL migration file in your Supabase SQL Editor:

**File:** `migrations/update_shift_change_requests.sql`

This migration will:
- Add `signature_url` column to store signature image URLs
- Update the constraint to allow new request types:
  - `client_booking_ended_early`
  - `client_not_home`
  - `client_cancelled`
  - `late_notification`

### 2. Create Storage Bucket for Signatures ⚠️ REQUIRED

**This step is REQUIRED before using "Call in Sick" feature!**

Create a storage bucket for sick leave signatures:

1. Go to **Supabase Dashboard → Storage**
   - Direct link: `https://supabase.com/dashboard/project/asbfhxdomvclwsrekdxi/storage/buckets`
2. Click **"New bucket"** button (top right)
3. **Bucket name:** `sick_leave_signatures` (must be exact)
4. **Public bucket:** Toggle ON ⚠️ **IMPORTANT: Must be ON!**
5. Click **"Create bucket"**

**If the bucket already exists but you're getting RLS errors:**

1. Go to **Storage → sick_leave_signatures bucket**
2. Click **"Settings"** tab
3. Toggle **"Public bucket"** to **ON**
4. Click **"Save"**

**Common Errors:**
- "Bucket not found" → Bucket doesn't exist, create it
- "row-level security policy" or "403 Unauthorized" → Bucket is not public, enable "Public bucket" in settings

### 3. Verify Table Structure

After running the migration, your table should have:
- `signature_url` (TEXT) - for storing signature image URLs
- Updated constraint allowing all new request types

## How It Works

### 1. Call in Sick
- User provides reason and signature
- Signature is uploaded to `sick_leave_signatures` bucket
- Request is saved with `request_type: 'full_day_leave'` and `signature_url`
- Supervisor is notified via email

### 2. Client Booking Ended Early
- User provides start time and end time
- Request is saved with `request_type: 'client_booking_ended_early'`
- Times are stored in `requested_start_time` and `requested_end_time`
- Supervisor is notified via email

### 3. Client Not Home / Client Cancelled
- User selects option directly
- Request is saved with reason in `reason` column
- Request type: `'client_not_home'` or `'client_cancelled'`
- Supervisor is notified via email

## Testing

After setup, test each feature:
1. **Call in Sick**: Should prompt for reason and signature
2. **Client Booking Ended Early**: Should prompt for start/end times
3. **Client Not Home**: Should send directly
4. **Client Cancelled**: Should send directly

All requests should appear in `shift_change_requests` table and supervisors should receive email notifications.

