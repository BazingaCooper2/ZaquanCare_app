-- Migration: Update shift_change_requests table to support new request types and signature
-- Run this migration in your Supabase SQL editor

-- 1. Add signature_url column if it doesn't exist
ALTER TABLE public.shift_change_requests 
ADD COLUMN IF NOT EXISTS signature_url TEXT;

-- 2. Update the constraint to allow new request types
ALTER TABLE public.shift_change_requests 
DROP CONSTRAINT IF EXISTS shift_change_requests_request_type_check;

ALTER TABLE public.shift_change_requests 
ADD CONSTRAINT shift_change_requests_request_type_check 
CHECK (
  request_type = ANY (
    ARRAY[
      'partial_shift_change'::text,
      'full_day_leave'::text,
      'client_booking_ended_early'::text,
      'client_not_home'::text,
      'client_cancelled'::text,
      'late_notification'::text
    ]
  )
);

