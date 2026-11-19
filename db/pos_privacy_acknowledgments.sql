-- TAP3 POS mandatory privacy acknowledgment for individually authenticated users.
-- Review against actual Supabase RLS policies before applying. NO automatic migration.
-- PIN staff currently share a terminal token and still require separate human identity proof.
CREATE TABLE IF NOT EXISTS public.pos_privacy_acknowledgments (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
 policy_version text NOT NULL,
 policy_sha256 char(64) NOT NULL,
 acknowledged_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,restaurant_id,policy_version,policy_sha256)
);
ALTER TABLE public.pos_privacy_acknowledgments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_privacy_acknowledgments FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.pos_privacy_acknowledgments FROM anon,authenticated;
GRANT SELECT,INSERT ON public.pos_privacy_acknowledgments TO authenticated;
CREATE POLICY pos_privacy_self_select ON public.pos_privacy_acknowledgments
 FOR SELECT TO authenticated USING (
  user_id=(SELECT auth.uid())
  AND EXISTS(SELECT 1 FROM public.staff s WHERE s.auth_user_id=(SELECT auth.uid())
             AND s.restaurant_id=pos_privacy_acknowledgments.restaurant_id AND s.active));
CREATE POLICY pos_privacy_self_insert ON public.pos_privacy_acknowledgments
 FOR INSERT TO authenticated WITH CHECK (
  user_id=(SELECT auth.uid())
  AND EXISTS(SELECT 1 FROM public.staff s WHERE s.auth_user_id=(SELECT auth.uid())
             AND s.restaurant_id=pos_privacy_acknowledgments.restaurant_id AND s.active));

CREATE OR REPLACE FUNCTION public.pos_privacy_accepted() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,public,auth AS $$
 SELECT EXISTS (
  SELECT 1 FROM public.pos_privacy_acknowledgments a
  JOIN public.staff s ON s.restaurant_id=a.restaurant_id
  WHERE s.auth_user_id=(SELECT auth.uid()) AND s.active
    AND a.user_id=(SELECT auth.uid())
    AND a.policy_version='TAP3-2026-11-19-v2'
    AND a.policy_sha256='7bafe099a23ab7f14c0ab9ed6f93f88927e076a8469d2734221b81bd9807dc65'
 );
$$;
REVOKE ALL ON FUNCTION public.pos_privacy_accepted() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pos_privacy_accepted() TO authenticated;

CREATE OR REPLACE FUNCTION public.pos_privacy_status() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog,public,auth AS $$
DECLARE rid uuid;
BEGIN
 SELECT restaurant_id INTO rid FROM public.staff
  WHERE auth_user_id=(SELECT auth.uid()) AND active LIMIT 1;
 IF rid IS NULL THEN RAISE EXCEPTION 'Active staff account required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('acknowledged',public.pos_privacy_accepted(),
   'version','TAP3-2026-11-19-v2','sha256','7bafe099a23ab7f14c0ab9ed6f93f88927e076a8469d2734221b81bd9807dc65');
END;
$$;
REVOKE ALL ON FUNCTION public.pos_privacy_status() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pos_privacy_status() TO authenticated;

CREATE OR REPLACE FUNCTION public.pos_privacy_acknowledge(
 p_version text,p_sha256 text,p_confirmed boolean) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,auth AS $$
DECLARE rid uuid;
BEGIN
 IF p_confirmed IS DISTINCT FROM true OR p_version<>'TAP3-2026-11-19-v2' OR p_sha256<>'7bafe099a23ab7f14c0ab9ed6f93f88927e076a8469d2734221b81bd9807dc65' THEN
  RAISE EXCEPTION 'The current privacy policy must be acknowledged' USING ERRCODE='22023';
 END IF;
 SELECT restaurant_id INTO rid FROM public.staff
  WHERE auth_user_id=(SELECT auth.uid()) AND active LIMIT 1;
 IF rid IS NULL THEN RAISE EXCEPTION 'Active staff account required' USING ERRCODE='42501'; END IF;
 INSERT INTO public.pos_privacy_acknowledgments(user_id,restaurant_id,policy_version,policy_sha256)
 VALUES ((SELECT auth.uid()),rid,'TAP3-2026-11-19-v2','7bafe099a23ab7f14c0ab9ed6f93f88927e076a8469d2734221b81bd9807dc65') ON CONFLICT DO NOTHING;
 RETURN jsonb_build_object('acknowledged',true,'version','TAP3-2026-11-19-v2');
END;
$$;
REVOKE ALL ON FUNCTION public.pos_privacy_acknowledge(text,text,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pos_privacy_acknowledge(text,text,boolean) TO authenticated;

-- Stronger gate for REST table operations. Existing permissive membership policies
-- remain in place; this restrictive policy additionally requires acceptance.
-- Intentionally exempts staff profile and restaurant bootstrap, and does not
-- affect anonymous guest ordering or service_role machine callbacks.
-- SECURITY DEFINER RPCs bypass RLS and require separate review before live rollout.
DO $$
DECLARE item record;
BEGIN
 FOR item IN SELECT c.relname AS name FROM pg_class c
   JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relkind='r' AND c.relrowsecurity
     AND c.relname NOT IN ('staff','restaurants','pos_privacy_acknowledgments')
 LOOP
  EXECUTE format('CREATE POLICY pos_privacy_gate_v2 ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (public.pos_privacy_accepted()) WITH CHECK (public.pos_privacy_accepted())',item.name);
 END LOOP;
END $$;
