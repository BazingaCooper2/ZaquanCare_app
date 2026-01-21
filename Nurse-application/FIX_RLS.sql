-- 1. Enable RLS on the table (good practice, though likely already on)
ALTER TABLE public.shift_offers ENABLE ROW LEVEL SECURITY;

-- 2. Create a policy that allows ANY authenticated user to VIEW (SELECT) all rows
-- This is the "broad" fix to ensure data visibility.
-- Later you can restrict this to "only own offers" if needed.
CREATE POLICY "Allow authenticated view"
ON public.shift_offers
FOR SELECT
TO authenticated
USING (true);

-- 3. Also allow updates if the app needs to Accept/Reject offers
CREATE POLICY "Allow authenticated update"
ON public.shift_offers
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);
