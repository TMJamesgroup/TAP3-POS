# TAP3 POS full restoration plan

The existing Render React screen is an authenticated multi-device beta, **not** the original complete TAP3 POS experience. Do not mistake it for feature parity.

## Original demo reference
- https://tap3-pos-demo.torriemjames.chatgpt.site
- Original demo was browser-local HTML/CSS/JavaScript; source has not been recovered or verified.
- Preserve its touch-first navigation, photo-based menu cards, register, table/floor views, kitchen/bar display, and manager dashboard as design reference. Do not copy an unverified source.

## Required full POS modules
1. Register: fast order entry, categories, modifiers, quantities, notes, seat assignment, open tabs, split/merge checks, discounts/voids subject to manager approval.
2. Floor: interactive tables, seating, statuses, timers, transfers, reservations/host map.
3. Kitchen & bar: routed tickets, separate stations, expo, bump/recall, timestamps and order-ready notifications.
4. Workforce: owner/manager/server/bartender/kitchen/host access, time clock, sidework, employee portal, training/hiring integrations.
5. Management: real-time operations, audit logs, sales reports (only when genuine payments exist), inventory and recipe costing, vendor operations.
6. Customer: QR and online ordering, receipts, loyalty/RankFlo integration.
7. Hardware: Android/Windows touch screens, handhelds, printers, cash drawers, supported payment terminals after separate payment approval.

## Current implementation
- GitHub: TMJamesgroup/TAP3-POS; Render: tap3-pos-beta.
- Supabase: restaurant, staff, tables, menu, tickets, ticket_items, audit_events; restaurant-scoped RLS.
- Shared ordering uses 4-second polling. Payments disabled.
- Current simplified UI has only Orders/Kitchen/Management; no original design parity.

## Restoration sequence
1. Recover original demo source or reproduce verified layout in a separate feature branch; do not overwrite production with an unverified mockup.
2. Rebuild touch-first shell and floor/register/KDS screens against the secured shared data model.
3. Extend database with checks, seats, modifiers, stations, permissions and audit; test cross-device ordering and tenant isolation.
4. Add workforce, inventory, analytics and integrations in modules.
5. Run build, permission tests and actual two-device acceptance tests before calling it production-ready.

## Critical constraints
- TAP 2.0 Dover beta first; no real payments until approved integration.
- Never expose service-role keys in browser.
- No public signup; owner provisions staff.
- Preserve restaurant tenant boundaries and manager-only privileged actions.
