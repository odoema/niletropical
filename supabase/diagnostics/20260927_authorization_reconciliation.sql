-- Nile Tropical: read-only authorization reconciliation diagnostic
-- Production target: ououfhsswyqutcczdtnb
-- SAFE: SELECT-only. Do not assign roles, alter RLS, alter data, or deploy.
-- Run against an approved environment/connection with sufficient metadata visibility.

-- 1. Current role helper definitions.
select
  n.nspname as schema_name,
  p.proname,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer,
  pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('has_role', 'is_staff', 'delivery_ops_authorized')
order by p.proname;

-- 2. SECURITY DEFINER public functions: review every externally callable function.
select
  n.nspname as schema_name,
  p.proname,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
order by p.proname, arguments;

-- 3. Exact live RLS policies. This is the authoritative policy-name/expression inventory.
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- 4. Policies using the broad is_staff() helper.
select
  schemaname,
  tablename,
  policyname,
  cmd,
  roles,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and (
    coalesce(qual, '') ilike '%is_staff%'
    or coalesce(with_check, '') ilike '%is_staff%'
  )
order by tablename, policyname;

-- 5. Policies by operational domain. This makes screen/action reconciliation faster.
select
  tablename,
  policyname,
  cmd,
  roles,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'orders','order_items','order_status_history',
    'customers','customer_addresses',
    'product_variants','warehouse_stock','stock_movements','stock_reservations',
    'shipments','delivery_events','delivery_partners','delivery_zones','couriers',
    'proof_of_delivery',
    'payment_transactions','payment_webhook_events','cod_collections',
    'notification_logs','notification_templates','push_subscriptions',
    'audit_logs','app_error_logs',
    'products','product_images','product_videos',
    'pricing_recommendations','categories',
    'pages','faqs','banners','testimonials','videos','promotions',
    'website_media_slots','coupon_redemptions'
  )
order by tablename, policyname;

-- 6. Role assignments (aggregate only; do not mutate production roles).
select role, count(*) as assigned_users
from public.user_roles
group by role
order by role;

-- 7. Order lifecycle accepted-status list from the live function body.
select
  p.proname,
  pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'update_order_status';
