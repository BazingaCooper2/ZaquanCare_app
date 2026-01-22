-- ==============================================================================
-- GET ACTIVE SHIFT (Authoritative Source of Truth)
--
-- Logic:
-- 1. Returns ONE shift (Limit 1).
-- 2. Strictly prioritizes 'in_progress' shifts (Active).
-- 3. Then returns the next 'scheduled' shift in the future.
-- 4. IGNORES 'scheduled' shifts in the past (Late/Missed are handled elsewhere or manual).
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
  shift_end_time TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.shift_id,
    s.emp_id,
    s.client_id,
    to_timestamp(s.date || ' ' || s.shift_start_time, 'YYYY-MM-DD HH24:MI'), -- Return Proper TZ-aware
    s.shift_status,
    s.date,
    s.shift_start_time,
    s.shift_end_time
  FROM public.shift s
  WHERE s.emp_id = p_emp_id
    AND (
       -- 1. ALWAYS include IN_PROGRESS shifts (Active Work)
       s.shift_status ILIKE 'in_progress'
       OR
       -- 2. Include SCHEDULED shifts ONLY if they are in the Future (Strict)
       (s.shift_status ILIKE 'scheduled' AND (s.date || ' ' || s.shift_start_time)::timestamp > now()::timestamp)
    )
  ORDER BY
    -- Prioritize In Progress explicitly to be safe? 
    -- If I have a future shift and a past in-progress shift, In Progress should win.
    (CASE WHEN s.shift_status ILIKE 'in_progress' THEN 0 ELSE 1 END) ASC,
    (s.date || ' ' || s.shift_start_time)::timestamp ASC
  LIMIT 1;
END;
$$;
