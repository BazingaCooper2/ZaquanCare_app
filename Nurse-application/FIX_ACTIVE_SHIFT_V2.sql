-- ==============================================================================
-- UPDATE GET ACTIVE SHIFT (Fix for "Just Started" Shifts)
-- ==============================================================================
CREATE OR REPLACE FUNCTION get_active_shift(p_emp_id BIGINT)
RETURNS TABLE (
  shift_id BIGINT,
  emp_id BIGINT,
  client_id BIGINT,
  start_ts TIMESTAMPTZ,
  shift_status TEXT,
  date TEXT,
  shift_start_time TEXT,
  shift_end_time TEXT,
  client_name TEXT,
  client_service_type TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.shift_id,
    s.emp_id,
    s.client_id,
    to_timestamp(s.date || ' ' || s.shift_start_time, 'YYYY-MM-DD HH24:MI'),
    s.shift_status,
    s.date,
    s.shift_start_time,
    s.shift_end_time,
    c.name as client_name,  -- Joining to get client name directly
    c.service_type as client_service_type
  FROM public.shift s
  LEFT JOIN public.client c ON s.client_id = c.client_id
  WHERE s.emp_id = p_emp_id
    AND (
       -- 1. ALWAYS include IN_PROGRESS shifts
       s.shift_status ILIKE 'in_progress'
       OR
       -- 2. Include SCHEDULED shifts if they haven't ENDED yet (Active window)
       --    This fixes the issue where being 1 minute late hid the shift.
       (
         s.shift_status ILIKE 'scheduled' 
         AND 
         to_timestamp(s.date || ' ' || s.shift_end_time, 'YYYY-MM-DD HH24:MI') > now()
       )
    )
  ORDER BY
    -- In Progress is highest priority
    (CASE WHEN s.shift_status ILIKE 'in_progress' THEN 0 ELSE 1 END) ASC,
    -- Then by start time
    to_timestamp(s.date || ' ' || s.shift_start_time, 'YYYY-MM-DD HH24:MI') ASC
  LIMIT 1;
END;
$$;
