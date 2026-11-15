-- TAP3 POS cash drawer persistence foundation, NOT automatically applied.
-- Apply only after reviewing existing database, migrations, grants, and service identity.
-- Application MUST authenticate staff and authorize restaurant/drawer/role server-side.
BEGIN;
CREATE TABLE IF NOT EXISTS public.pos_cash_drawers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
 label text NOT NULL CHECK (length(trim(label)) BETWEEN 1 AND 100),
 register_key text NOT NULL CHECK (length(trim(register_key)) BETWEEN 1 AND 100),
 opening_bank_cents bigint NOT NULL DEFAULT 0 CHECK (opening_bank_cents >= 0),
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (restaurant_id,label),
 UNIQUE (restaurant_id,register_key),
 UNIQUE (id,restaurant_id)
);
CREATE TABLE IF NOT EXISTS public.pos_cash_shifts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
 drawer_id uuid NOT NULL,
 assigned_staff_id uuid NOT NULL REFERENCES public.staff(id),
 opened_at timestamptz NOT NULL DEFAULT now(),
 closed_at timestamptz,
 opening_count_cents bigint NOT NULL CHECK (opening_count_cents >= 0),
 closing_count_cents bigint CHECK (closing_count_cents >= 0),
 status text NOT NULL CHECK (status IN ('open','closed','variance_hold')),
 FOREIGN KEY (drawer_id,restaurant_id) REFERENCES public.pos_cash_drawers(id,restaurant_id),
 CHECK ((status = 'closed' AND closed_at IS NOT NULL) OR (status <> 'closed' AND closed_at IS NULL)),
 UNIQUE (id,restaurant_id,drawer_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS pos_cash_one_open_shift_per_drawer
 ON public.pos_cash_shifts(drawer_id) WHERE status IN ('open','variance_hold');
CREATE TABLE IF NOT EXISTS public.pos_cash_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 event_key uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
 restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
 drawer_id uuid NOT NULL,
 shift_id uuid,
 actor_staff_id uuid REFERENCES public.staff(id),
 event_type text NOT NULL CHECK (event_type IN
 ('bank_configured','opening_count','opening_variance','drawer_open_requested',
 'drawer_open_denied','cash_sale','cash_refund','paid_in','paid_out','safe_drop',
 'blind_count','transfer_out','transfer_in','transfer_variance',
 'closing_count','closing_variance','shift_closed','manager_resolution')),
 amount_delta_cents bigint NOT NULL DEFAULT 0,
 counted_cents bigint CHECK (counted_cents >= 0),
 reason text NOT NULL CHECK (length(trim(reason)) BETWEEN 1 AND 500),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY (drawer_id,restaurant_id) REFERENCES public.pos_cash_drawers(id,restaurant_id),
 FOREIGN KEY (shift_id,restaurant_id,drawer_id) REFERENCES public.pos_cash_shifts(id,restaurant_id,drawer_id)
);
CREATE INDEX IF NOT EXISTS pos_cash_events_by_drawer_time
 ON public.pos_cash_events(restaurant_id,drawer_id,occurred_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS pos_cash_events_by_actor_time
 ON public.pos_cash_events(restaurant_id,actor_staff_id,occurred_at DESC);
-- Append-only audit trail: never rewrite or delete events; use compensating entries.
CREATE OR REPLACE FUNCTION public.pos_cash_events_immutable()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Cash events are append-only'; END $$;
DROP TRIGGER IF EXISTS pos_cash_events_no_changes ON public.pos_cash_events;
CREATE TRIGGER pos_cash_events_no_changes
 BEFORE UPDATE OR DELETE ON public.pos_cash_events
 FOR EACH ROW EXECUTE FUNCTION public.pos_cash_events_immutable();
-- Default deny for ordinary SQL roles; table owner / BYPASSRLS must still be controlled.
ALTER TABLE public.pos_cash_drawers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_cash_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_cash_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_cash_drawers FORCE ROW LEVEL SECURITY;
ALTER TABLE public.pos_cash_shifts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.pos_cash_events FORCE ROW LEVEL SECURITY;
-- No permissive policies supplied intentionally. Do NOT grant client-side access.
COMMIT;
