-- ==============================================================================
-- NEXT SCHEDULE IMPLEMENTATION (RPC)
-- ==============================================================================
--
-- WHY to_timestamp(date || ' ' || shift_start_time) IS REQUIRED:
-- 1. The 'date' and 'shift_start_time' are stored as TEXT, not native timestamps.
-- 2. Simple string comparison fail for mixed formats or edge cases (e.g. crossing years).
-- 3. We must combine them into a single atomic TIMESTAMP WITH TIME ZONE to accurately
--    compare against 'now()' and strictly order chronological events.
--
-- LOGIC:
-- - Filters ONLY future shifts (strictly > now())
-- - Orders by the computed timestamp (ASC)
-- - Limits to exactly 1 result (The immediate next shift)
--
-- USAGE IN FLUTTER:
-- final data = await supabase.rpc('get_next_shift', params: {'p_emp_id': 123});
--
-- ==============================================================================

CREATE OR REPLACE FUNCTION get_next_shift(p_emp_id BIGINT)
RETURNS SETOF public.shift AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM public.shift
  WHERE emp_id = p_emp_id
    AND (
      to_timestamp(
        date || ' ' || shift_start_time,
        'YYYY-MM-DD HH24:MI'
      ) > now()
    )
  ORDER BY
    to_timestamp(
      date || ' ' || shift_start_time,
      'YYYY-MM-DD HH24:MI'
    ) ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;
