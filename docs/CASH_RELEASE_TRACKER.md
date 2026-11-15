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
| Automated cash tests | Added, NOT YET VERIFIED PASSING | npm run test:cash and Python unittest; CI workflow added |
| Cash readiness API | Committed; DEPLOYMENT PENDING | GET /api/cash/readiness; always reports production disabled |
| Authenticated cash APIs | NOT STARTED | Staff session identity, role, restaurant scope, transaction locks |
| Live register cash workflow | NOT CONNECTED | Wire authenticated cash APIs to register UI |
| Management backend reporting | NOT CONNECTED | Separate management site, blind counts, discrepancy approval |
| Physical printer and drawer transport | NOT IMPLEMENTED | Compatible hardware, Android/Windows bridge, integration tests |
| End-of-day reconciliation | NOT IMPLEMENTED | Closing and reconciliation with durable audit |
| Production acceptance testing | NOT STARTED | End-to-end tests with hardware and recovery scenarios |

## Next execution order
1. Verify CI and latest Render deployment; fix any failing tests.
2. Review real database and authentication model without exposing cash write endpoints.
3. Apply migration in controlled staging, then implement transaction-safe authorized cash APIs.
4. Wire register and separate management UI.
5. Implement supported hardware transports and test four-drawer shift end-to-end.
6. Verify reconciliation, audit, and recovery; only then consider production enablement.

## Change log
- 2026-11-15: Added four-drawer browser simulator, transport selector, shift handoff, backend simulation, SQL schema, validation helpers, tests, CI configuration, and cash readiness API.
- Each future change should update this tracker with observed test and deployment results, not assumed success.
