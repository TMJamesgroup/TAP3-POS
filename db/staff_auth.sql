ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_staff_auth_user_id ON public.staff(auth_user_id);
CREATE POLICY staff_read_own_profile ON public.staff FOR SELECT TO authenticated USING (auth_user_id = (SELECT auth.uid()));
-- No INSERT, UPDATE or DELETE policies are granted to client roles.
-- Provision staff only via trusted admin backend; do not derive roles from user_metadata.
