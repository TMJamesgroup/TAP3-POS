# TAP3 POS — Cash drawer and printer completion tracker
Updated: 2026-11-15

## Release gate
**NOT READY FOR LIVE CASH OPERATIONS.** Simulator only; no hardware printer or cash drawer commands enabled.

| Milestone | Status | Evidence / next gate |
|---|---|---|
| Four-drawer browser simulator | Implemented, deployed previously | Cash Drawer Lab; data resets on refresh |
| Opening/closing count simulation | Implemented in simulator | Browser lab only |
| Shift handoff UI | Implemented, deployed previously | Two counts; no separate authenticated identities |
| Bluetooth / USB / Ethernet selector | Implemented in simulator | No discovery, pairing, print transport, or drawer kick |
| Cash persistence schema | Committed; NOT APPLIED | db/cash_drawer_foundation.sql; review against live DB |
| Server-side authorization helpers | Committed; NOT INTEGRATED | cash/cash-controls.js |
| Automated cash tests | PASSING in GitHub Actions run 43739620565 | npm run test:cash and Python unittest; CI workflow added |
| Cash readiness API | DEPLOYED (Render latest live) | GET /api/cash/readiness; always reports production disabled |
| Dedicated POS database | CREATED — provisioning (Render dpg-dbsuhlrbc2fs73cjvdf0-a); not connected | Verify available, configure POS service connection securely, inspect schema before migration |\n| Authenticated cash APIs | NOT STARTED | Staff session identity, role, restaurant scope, transaction locks |
| Live register cash workflow | NOT CONNECTED | Wire authenticated cash APIs to register UI |
| Management backend reporting | NOT CONNECTED | Separate management site, blind counts, discrepancy approval |
| Physical printer and drawer transport | NOT IMPLEMENTED | Compatible hardware, Android/Windows bridge, integration tests |
| End-of-day reconciliation | NOT IMPLEMENTED | Closing and reconciliation with durable audit |
| Production acceptance testing | NOT STARTED | End-to-end tests with hardware and recovery scenarios |

## Next execution order
1. COMPLETE: GitHub Actions run 43739620565 passed; Render commit e7cf3a27 deployed live. Independently check readiness endpoint response when possible.
2. Review real database and authentication model without exposing cash write endpoints.
3. Apply migration in controlled staging, then implement transaction-safe authorized cash APIs.
4. Wire register and separate management UI.
5. Implement supported hardware transports and test four-drawer shift end-to-end.
6. Verify reconciliation, audit, and recovery; only then consider production enablement.

## Change log
- 2026-11-15: Added four-drawer browser simulator, transport selector, shift handoff, backend simulation, SQL schema, validation helpers, tests, CI configuration, and cash readiness API.
- Each future change should update this tracker with observed test and deployment results, not assumed success.

- 2026-11-15: Verified GitHub Actions run 43739620565 completed successfully and Render latest deployment for commit e7cf3a27 is live. Production cash remains disabled.

- 2026-11-15: Render inventory verified: only tmj-command-center-db and restaurant-workforce-db listed. Dedicated POS database is missing. No production migration applied; keep cash writes disabled until separate database exists and secure auth is integrated.

- 2026-11-15: Created dedicated Render Postgres tap3-pos-db (dpg-dbsuhlrbc2fs73cjvdf0-a), basic_256mb paid plan, Virginia, 1 GB. Render reports status creating. No connection credentials exposed, no schema migration applied, no live cash writes enabled. Next: wait for available, connect POS service via secure environment variable and verify schema.

## TAP 2.0 Menu Import (2026-11-17)
- Owner-supplied menu catalog committed: `data/tap2-menu.json` (84 priced/variant/TBD entries: 65 confirmed, 3 proposed, 16 TBD).
- Guarded importer committed: `scripts/import-tap2-menu.mjs`; dry-run default, `--apply` requires DATABASE_URL and TAP2_RESTAURANT_ID, verifies restaurant name.
- **NOT IMPORTED INTO LIVE DATABASE**: POS connection and TAP 2.0 restaurant record not verified. Modifier configuration still requires POS integration. Proposed boneless wings and unpriced items excluded from sale.
