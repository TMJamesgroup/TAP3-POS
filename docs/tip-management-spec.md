# TAP3 POS — Restaurant-configurable tip management

Status: approved design specification; not yet implemented or live.

## Ownership and isolation
Each restaurant owns its tip policies. Policies may be scoped by location, service channel, department, role and shift. No cross-tenant access. POS tip management stays in TAP3 POS, independent of the standalone workforce scheduling product.

## Policy model
- tip_policies: id, restaurant_id, location_id, name, method (individual, tip_out, pool, points, hours, hybrid), scope, effective_from, effective_to, status (draft, approved, active, retired), version, approved_by, approved_at.
- tip_policy_rules: policy_id, priority, source_role, recipient_role, eligible_sales_category, basis (tips, eligible_sales, points_x_hours, hours, fixed), rate, cap, rounding_order, fallback_behavior.
- tip_eligibility: restaurant_id, staff_id, role, eligible_from, eligible_until, classification, payroll_review_status.
- tip_events: immutable events for customer tip, declared cash, refund, reversal, adjustment, tip-out, allocation, payout. Include transaction_id, shift_id, staff_id, source, amount_cents, currency, created_at, idempotency_key.
- tip_allocations: event_id, recipient_staff_id, policy_version_id, amount_cents, calculated_at, calculation_explanation, status.
- tip_settlements: restaurant_id, period, staff_id, gross_tips_cents, tip_outs_cents, allocations_cents, cash_paid_cents, payroll_due_cents, reconciliation_status, approved_by.
- tip_audit: actor, restaurant_id, action, before, after, reason, timestamp.

## Invariants
1. Monetary calculations use integer cents; deterministic largest-remainder rounding, with stable tie-breakers.
2. Allocation amounts sum exactly to the eligible source pool. Never create or destroy tip money by rounding.
3. Idempotent event ingestion, allocations, and exports; no duplicate payout or duplicate processing.
4. Cash tips and card tips are distinct. Tip declarations must not be mistaken for cash received by the business.
5. Mandatory service charges are recorded separately from voluntary tips and are never silently pooled as tips.
6. Refunds, voids and chargebacks generate reversing ledger entries, not deletion.
7. Managers/supervisors cannot receive employee pool distributions under federal rules; qualifying tips received for service solely and directly provided are separately handled. Apply applicable state and local restrictions.
8. For tip-credit employers, policy validation must check permitted pool composition and other legal constraints; restaurant's payroll/legal reviewer approves policy before activation.
9. Changes are versioned and prospective by default. Historic allocations use the policy version in force at the time.
10. Tenant isolation through RLS and verified role-based access; only privileged roles can approve or activate policies.
11. Approval and payout permissions separated where possible; every override requires an audit reason.
12. Labor/scheduling data may be imported from an external workforce system, but POS remains independently operational.

## Workflow
Owner creates draft -> simulation with sample shifts -> validate legal/role constraints -> approve and activate -> ingest POS tip events -> compute allocations -> employee review -> manager exception resolution -> settlement -> payroll export with unique batch IDs and acknowledgements.

## UI
Management > Tips: Overview, Policies, Tip-outs, Pools, Shift reconciliation, Employee ledger, Exceptions, Payroll export, Audit.
Policy editor includes location, channel, position, shift, basis, percentage/points, effective date, simulation, approval and publication.
Employees see their own allocated tips and cash declarations, not other employees' private records.

## Rollout
Phase 1: policy CRUD, approval/versioning, ledger and simulator with synthetic transactions.
Phase 2: card/cash tip ingestion from real POS payment transactions, settlement and reconciliation.
Phase 3: role eligibility controls, pooling, tip-outs, refunds, employee visibility and exports.
Phase 4: payroll connectors, multi-location rules, audit monitoring and reporting.

Do not mark live until database migrations, access policies, unit tests, deployment and real transaction reconciliation are complete.
