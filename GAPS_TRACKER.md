# Nile Tropical — Backend/Frontend Gap Tracker

Compiled from a full audit of all 39 backend tables against the Flutter app on 2026-09-12.
Update the Status column as work lands. Keep this file in the repo so progress survives across sessions/devices.

Status legend: `Not started` / `In progress` / `Done` / `Blocked`

| # | Gap | Priority | Backend ready? | Effort | Status | Notes |
|---|-----|----------|-----------------|--------|--------|-------|
| 1 | Checkout has no coupon/promo code field | High | Yes (`coupons`, `coupon_redemptions`) | Small | **Done** | Added `validate_coupon` RPC, wired `create_order` to accept + record redemptions, checkout UI has code field + live discount. Test coupon `WELCOME10` (10%) seeded. |
| 2 | No admin "Customers" screen | High | Yes (`customers` table) | Small–Medium | **Done** | Customers list + detail screens wired into admin |
| 3 | No COD cash reconciliation UI | High (if COD is used) | Yes (`cod_collections`) | Medium | **Done** | COD reconciliation screen wired into admin |
| 4 | Courier proof-of-delivery has no photo capture | Medium–High | Yes (`proof_of_delivery` + storage) | Medium | **Done** | Camera capture uploads to private `pod` bucket and submits the correct RPC parameters |
| 5 | No pricing-recommendation review/approval UI | Medium | Yes (`pricing_recommendations`, has a comment describing an approval workflow) | Medium | **Done** | Admin review screen with pending/approved/rejected filters and approval actions |
| 6 | No notification template/log admin screen | Medium | Yes (`notification_templates`, `notification_logs`) | Medium | **Done** | Template editor plus delivery-log viewer wired to the production notification schema |
| 7 | No audit log viewer | Low–Medium | Yes (`audit_logs`, `nile_admin.admin_activity_log`) | Small–Medium | **Done** | Admin audit viewer reads the staff activity log with public-table fallback |
| 8 | No admin Settings screen for feature flags/config | Low–Medium | Yes (`nile_admin.project_config`, `nile_admin.modules` — already has 11 module rows) | Medium | **Done** | Admin module toggles and project configuration editor added |

## Working order (recommended)
Ordered by business impact vs. effort. Re-order anytime — this file is the plan, not a mandate.

1. Coupon field at checkout (#1) — quick, unlocks marketing already set up in CMS
2. Customers admin screen (#2) — quick, high daily-ops value
3. COD reconciliation (#3) — do before #4/#5 if cash orders are already flowing
4. Proof-of-delivery photo capture (#4)
5. Pricing recommendation approvals (#5)
6. Notification templates/logs (#6)
7. Audit log viewer (#7)
8. Admin settings screen (#8)

## Log
- 2026-09-12 — Tracker created after full backend/frontend audit.
- 2026-09-24 — Gaps #2–#4 closed in the admin/courier UI; POD parameter and storage-path consistency fixed.
- 2026-09-12 — Gap #1 closed: coupon support end-to-end (backend RPCs + checkout UI).

- 2026-09-24 — Gaps #5–#8 closed in the admin UI: pricing approvals, notification templates/logs, audit viewer, and admin settings. Navigation and mobile admin menu expanded accordingly.
