# TAP3 POS backend implementation plan

Current deployed application is a **non-production, browser-local demonstration**. It has no shared database or authentication. Do not use it to process actual restaurant orders or sensitive employee/customer information.

## Architecture
- React/Vite client on Render
- Node.js API (to be implemented)
- Dedicated PostgreSQL database, separated from TMJ Command Center
- Server-side authenticated sessions and role-based permissions
- Tenant isolation by restaurant_id on every query
- Audit trail for ticket modifications, voids and administrative actions
- Server-sent events or WebSockets for kitchen/bar updates
- Payment processing intentionally disabled for beta

## Deployment blocker
Render allows only one active free PostgreSQL database per account. A separate free POS database was rejected on 2026-11-10. Do not reuse the Command Center database without a reviewed isolation design. Database provisioning, secrets, migrations, API endpoints, auth, and cross-device tests remain pending.

## Data model
See db/schema.sql. Do not run migrations against production without backups and access review.
