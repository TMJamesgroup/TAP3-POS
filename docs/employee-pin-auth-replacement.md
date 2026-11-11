# TAP3 POS — independent employee authentication replacement

## Required security architecture
- Back Office uses Supabase owner/manager authentication only.
- POS register uses its own device-bound credential, provisioned by an authenticated owner/manager. A device UUID stored in localStorage is an identifier, **not** a credential.
- Server verifies the device secret against a hashed value, revocation status, restaurant scope, and expiration. Do not expose a service-role key or database password to the browser.
- Employee PIN is checked server-side against the hashed PIN for the **same restaurant** as the authorized device. Enforce four failed attempts, 15-minute lockout, and per-device/IP rate limits. No default or shared PINs.
- Successful PIN verification issues a short-lived employee-scoped session tied to the staff ID, restaurant ID, role, device ID, and session ID; use a server-side session registry for revocation.
- Every POS data mutation and query must validate the employee session and its role at the server, not merely unlock the React interface.
- All cashier actions, refunds, voids, overrides, and employee access must have an audit trail.
- Terminals remain awake while active; locking the UI does not revoke a device credential. Backgrounded or unattended devices must require employee PIN re-entry.
- Device enrollment, revocation, PIN reset, and role assignment remain manager-only, with owner-only operations separately enforced.
- Never use the manager's Supabase JWT to make employee POS requests.
- No production rollout until automated tests cover incorrect PIN, lockout, cross-restaurant isolation, revoked device, revoked employee, privilege escalation, session expiration, and manager functions.

## Existing system issue
The current `pos_verify_my_pin` SQL RPC uses `auth.uid()` to find the currently authenticated owner/manager. The existing React `unlockWithPin` also requires a Supabase login session. Merely bypassing the React check does not authenticate employees and must not be deployed as a solution.

## Rollout
Build and test a standalone POS authentication service and per-employee authorization, then migrate the register API calls. Run synthetic-data tests in staging. Keep existing Back Office and production database unchanged until the security tests pass.
