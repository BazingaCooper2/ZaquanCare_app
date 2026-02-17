-- ==============================================================================
-- ADD IMMEDIATE SHIFT FOR TESTING 'CLIENT BOOKING ENDED EARLY'
-- ==============================================================================

-- 1. Ensure a test client exists
INSERT INTO public.client (
    first_name, 
    last_name, 
    location, 
    phone_number, 
    patient_location, -- Using existing column name from schema
    service_type, 
    notes, 
    email
)
SELECT 
    'Test', 
    'Client (India)', 
    'Apollo Hospital, Chennai', 
    '9999999999', 
    '13.0630,80.2559', 
    'Hospital', 
    'Temporary test client for routing', 
    'test@test.com'
WHERE NOT EXISTS (
    SELECT 1 FROM public.client WHERE phone_number = '9999999999'
);

-- 2. Insert a shift starting NOW for the specific employee (Replace YOUR_EMP_ID)
-- If you don't know your ID, this script picks the first employee found.
WITH target_employee AS (
    SELECT emp_id FROM public.employee LIMIT 1 -- OR replace with specific ID: SELECT 123
),
target_client AS (
    SELECT client_id FROM public.client WHERE phone_number = '9999999999' LIMIT 1
)
INSERT INTO public.shift (
    emp_id,
    client_id,
    date,
    shift_start_time,
    shift_end_time,
    shift_status,
    service_type,
    start_latitude,
    start_longitude
)
SELECT 
    e.emp_id,
    c.client_id,
    CURRENT_DATE::TEXT, -- Store as TEXT to match schema
    TO_CHAR(NOW(), 'HH24:MI'), -- Current time
    TO_CHAR(NOW() + INTERVAL '8 hours', 'HH24:MI'), -- 8 hours from now
    'scheduled',
    'Hospital',
    13.0630,
    80.2559
FROM target_employee e, target_client c;

-- 3. Verify the insertion
SELECT * FROM public.shift 
WHERE date = CURRENT_DATE::TEXT 
ORDER BY shift_id DESC 
LIMIT 1;
