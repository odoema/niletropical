-- Reconciliation-only SECURITY DEFINER execution-surface hardening.
-- These functions are trigger/internal helpers or privileged admin/payment
-- helpers with no verified public application caller.
-- DO NOT deploy until caller-path tests pass.

-- Pricing approval is authenticated/admin-only by function contract.
revoke execute on function public.apply_pricing_recommendation(uuid) from anon;
grant execute on function public.apply_pricing_recommendation(uuid) to authenticated;
grant execute on function public.apply_pricing_recommendation(uuid) to service_role;

-- Payment failure is not used by the current Flutter/payment Edge Function
-- paths; it can mutate payment/order state and release reservations.
revoke execute on function public.fail_order_payment(uuid, text) from anon, authenticated;
grant execute on function public.fail_order_payment(uuid, text) to service_role;

-- Trigger-only helpers do not need Data API RPC execution.
revoke execute on function public.enqueue_order_lifecycle_notification() from anon, authenticated;
revoke execute on function public.record_order_status_history() from anon, authenticated;

-- Notification queue helpers are invoked by trusted server-side trigger paths.
revoke execute on function public.queue_order_notification(uuid, text, text, text, text) from anon, authenticated;
revoke execute on function public.queue_order_push_notification(uuid, text, text) from anon, authenticated;

-- Product main-image replacement is an authenticated privileged admin path;
-- remove only the anonymous execution surface here.
revoke execute on function public.admin_replace_product_main_image(uuid, text, text) from anon;
grant execute on function public.admin_replace_product_main_image(uuid, text, text) to authenticated;
grant execute on function public.admin_replace_product_main_image(uuid, text, text) to service_role;
