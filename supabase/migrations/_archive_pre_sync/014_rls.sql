-- Nile Tropical Uganda — 014_rls.sql
-- Enforces §50 (roles) and §51 (RLS) at the database layer. The Flutter UI
-- must never be the only thing preventing unauthorized access — every
-- table a client can reach directly is covered here.
--
-- Role summary (see 002_profiles_roles.sql for has_role()/is_staff()):
--   super_admin  — everything
--   manager      — operations: products, inventory, delivery, reports
--   sales        — orders/customers
--   inventory    — products/inventory
--   finance      — payments/financial reports
--   content      — CMS
--   courier      — assigned deliveries only
--
-- Guest order tracking (§35) deliberately does NOT rely on RLS granting
-- anon SELECT on `orders` by token, since that would need the token in a
-- WHERE clause the client controls. Instead it goes through the
-- SECURITY DEFINER function `track_order()` below, which returns only a
-- narrow, non-sensitive projection.

alter table profiles enable row level security;
alter table user_roles enable row level security;
alter table categories enable row level security;
alter table products enable row level security;
alter table product_variants enable row level security;
alter table product_images enable row level security;
alter table product_videos enable row level security;
alter table batches enable row level security;
alter table stock_movements enable row level security;
alter table customers enable row level security;
alter table customer_addresses enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table order_status_history enable row level security;
alter table payments enable row level security;
alter table payment_transactions enable row level security;
alter table delivery_zones enable row level security;
alter table delivery_partners enable row level security;
alter table couriers enable row level security;
alter table shipments enable row level security;
alter table delivery_events enable row level security;
alter table proof_of_delivery enable row level security;
alter table testimonials enable row level security;
alter table customer_stories enable row level security;
alter table videos enable row level security;
alter table banners enable row level security;
alter table pages enable row level security;
alter table faqs enable row level security;
alter table promotions enable row level security;
alter table discounts enable row level security;
alter table coupons enable row level security;
alter table promotional_popups enable row level security;
alter table notifications enable row level security;
alter table notification_templates enable row level security;
alter table notification_logs enable row level security;
alter table audit_logs enable row level security;

-- ---------------------------------------------------------------------
-- profiles / user_roles — staff only, self or super_admin
-- ---------------------------------------------------------------------
create policy profiles_self_read on profiles for select
  using (id = auth.uid() or has_role('super_admin'));
create policy profiles_self_update on profiles for update
  using (id = auth.uid() or has_role('super_admin'));
create policy user_roles_super_admin_manage on user_roles for all
  using (has_role('super_admin')) with check (has_role('super_admin'));
create policy user_roles_self_read on user_roles for select
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- Catalog — public can read active/published products; product/inventory
-- staff can write.
-- ---------------------------------------------------------------------
create policy categories_public_read on categories for select
  using (is_active);
create policy categories_staff_write on categories for all
  using (has_role('manager') or has_role('inventory') or has_role('super_admin'))
  with check (has_role('manager') or has_role('inventory') or has_role('super_admin'));

create policy products_public_read on products for select
  using (is_active and deleted_at is null);
create policy products_staff_manage on products for all
  using (has_role('manager') or has_role('inventory') or has_role('super_admin'))
  with check (has_role('manager') or has_role('inventory') or has_role('super_admin'));

create policy variants_public_read on product_variants for select
  using (is_active);
create policy variants_staff_manage on product_variants for all
  using (has_role('manager') or has_role('inventory') or has_role('super_admin'))
  with check (has_role('manager') or has_role('inventory') or has_role('super_admin'));

create policy product_images_public_read on product_images for select using (true);
create policy product_images_staff_manage on product_images for all
  using (has_role('manager') or has_role('inventory') or has_role('content') or has_role('super_admin'))
  with check (has_role('manager') or has_role('inventory') or has_role('content') or has_role('super_admin'));

create policy product_videos_public_read on product_videos for select using (true);
create policy product_videos_staff_manage on product_videos for all
  using (has_role('manager') or has_role('content') or has_role('super_admin'))
  with check (has_role('manager') or has_role('content') or has_role('super_admin'));

-- ---------------------------------------------------------------------
-- Inventory — staff (inventory/manager/super_admin) only. Never exposed to
-- customers or anon.
-- ---------------------------------------------------------------------
create policy batches_staff_only on batches for all
  using (has_role('inventory') or has_role('manager') or has_role('super_admin'))
  with check (has_role('inventory') or has_role('manager') or has_role('super_admin'));
create policy stock_movements_staff_only on stock_movements for all
  using (has_role('inventory') or has_role('manager') or has_role('super_admin'))
  with check (has_role('inventory') or has_role('manager') or has_role('super_admin'));

-- ---------------------------------------------------------------------
-- Customers — a customer can read/update only their own record (once
-- linked to an auth account); staff (sales/manager/super_admin) see all.
-- Guest checkout inserts happen via a SECURITY DEFINER function, not a
-- direct anon INSERT, so no anon insert policy is granted here.
-- ---------------------------------------------------------------------
create policy customers_self_read on customers for select
  using (auth_user_id = auth.uid() or has_role('sales') or has_role('manager') or has_role('super_admin'));
create policy customers_self_update on customers for update
  using (auth_user_id = auth.uid() or has_role('sales') or has_role('manager') or has_role('super_admin'));
create policy customer_addresses_self on customer_addresses for all
  using (
    exists (select 1 from customers c where c.id = customer_id and c.auth_user_id = auth.uid())
    or has_role('sales') or has_role('manager') or has_role('super_admin')
  )
  with check (
    exists (select 1 from customers c where c.id = customer_id and c.auth_user_id = auth.uid())
    or has_role('sales') or has_role('manager') or has_role('super_admin')
  );

-- ---------------------------------------------------------------------
-- Orders — "Customer can read own orders" (§51). Direct anon SELECT/INSERT
-- is intentionally NOT granted; order creation and guest tracking go
-- through SECURITY DEFINER functions (013_functions.sql / below) so price,
-- stock and order-number generation stay server-authoritative (§53).
-- ---------------------------------------------------------------------
create policy orders_owner_read on orders for select
  using (
    exists (select 1 from customers c where c.id = customer_id and c.auth_user_id = auth.uid())
    or has_role('sales') or has_role('manager') or has_role('finance') or has_role('super_admin')
  );
create policy orders_staff_manage on orders for update
  using (has_role('sales') or has_role('manager') or has_role('super_admin'))
  with check (has_role('sales') or has_role('manager') or has_role('super_admin'));

create policy order_items_owner_read on order_items for select
  using (
    exists (
      select 1 from orders o
      join customers c on c.id = o.customer_id
      where o.id = order_id and c.auth_user_id = auth.uid()
    )
    or has_role('sales') or has_role('manager') or has_role('finance') or has_role('super_admin')
  );

create policy order_status_history_staff_read on order_status_history for select
  using (
    exists (
      select 1 from orders o
      join customers c on c.id = o.customer_id
      where o.id = order_id and c.auth_user_id = auth.uid()
    )
    or has_role('sales') or has_role('manager') or has_role('super_admin')
  );

-- ---------------------------------------------------------------------
-- Payments — finance/manager/super_admin only. Customers never read
-- payment_transactions (raw provider payloads may contain sensitive data).
-- Webhook writes come from an Edge Function using the service role key,
-- which bypasses RLS entirely — no anon/customer policy is needed or
-- granted here.
-- ---------------------------------------------------------------------
create policy payments_finance_read on payments for select
  using (has_role('finance') or has_role('manager') or has_role('super_admin'));
create policy payments_finance_manage on payments for update
  using (has_role('finance') or has_role('super_admin'))
  with check (has_role('finance') or has_role('super_admin'));
create policy payment_transactions_finance_read on payment_transactions for select
  using (has_role('finance') or has_role('super_admin'));

-- ---------------------------------------------------------------------
-- Delivery — zones/partners readable by anyone (needed to show fees at
-- checkout); couriers restricted to their own assigned shipments (§32,
-- §51 "courier can read assigned shipments").
-- ---------------------------------------------------------------------
create policy delivery_zones_public_read on delivery_zones for select using (is_active);
create policy delivery_zones_staff_manage on delivery_zones for all
  using (has_role('manager') or has_role('super_admin'))
  with check (has_role('manager') or has_role('super_admin'));

create policy delivery_partners_public_read on delivery_partners for select using (is_active);
create policy delivery_partners_staff_manage on delivery_partners for all
  using (has_role('manager') or has_role('super_admin'))
  with check (has_role('manager') or has_role('super_admin'));

create policy couriers_self_read on couriers for select
  using (auth_user_id = auth.uid() or has_role('manager') or has_role('super_admin'));
create policy couriers_staff_manage on couriers for insert
  with check (has_role('manager') or has_role('super_admin'));
create policy couriers_staff_update on couriers for update
  using (has_role('manager') or has_role('super_admin'))
  with check (has_role('manager') or has_role('super_admin'));

create policy shipments_courier_read on shipments for select
  using (
    exists (select 1 from couriers c where c.id = courier_id and c.auth_user_id = auth.uid())
    or has_role('manager') or has_role('sales') or has_role('super_admin')
  );
create policy shipments_courier_update on shipments for update
  using (
    exists (select 1 from couriers c where c.id = courier_id and c.auth_user_id = auth.uid())
    or has_role('manager') or has_role('super_admin')
  )
  with check (
    exists (select 1 from couriers c where c.id = courier_id and c.auth_user_id = auth.uid())
    or has_role('manager') or has_role('super_admin')
  );
create policy shipments_staff_create on shipments for insert
  with check (has_role('manager') or has_role('sales') or has_role('super_admin'));

create policy delivery_events_courier_insert on delivery_events for insert
  with check (
    exists (
      select 1 from shipments s
      join couriers c on c.id = s.courier_id
      where s.id = shipment_id and c.auth_user_id = auth.uid()
    )
    or has_role('manager') or has_role('super_admin')
  );
create policy delivery_events_read on delivery_events for select
  using (
    exists (
      select 1 from shipments s
      join couriers c on c.id = s.courier_id
      where s.id = shipment_id and c.auth_user_id = auth.uid()
    )
    or has_role('manager') or has_role('sales') or has_role('super_admin')
  );

create policy pod_courier_insert on proof_of_delivery for insert
  with check (
    exists (select 1 from couriers c where c.id = courier_id and c.auth_user_id = auth.uid())
    or has_role('manager') or has_role('super_admin')
  );
create policy pod_staff_read on proof_of_delivery for select
  using (has_role('manager') or has_role('sales') or has_role('finance') or has_role('super_admin'));

-- ---------------------------------------------------------------------
-- Content / CMS — public reads only published rows; content/manager staff
-- write. Consent constraint from 009_content.sql already blocks publishing
-- without consent at the schema level.
-- ---------------------------------------------------------------------
create policy testimonials_public_read on testimonials for select using (is_published);
create policy testimonials_staff_manage on testimonials for all
  using (has_role('content') or has_role('manager') or has_role('super_admin'))
  with check (has_role('content') or has_role('manager') or has_role('super_admin'));

create policy stories_public_read on customer_stories for select using (is_published);
create policy stories_staff_manage on customer_stories for all
  using (has_role('content') or has_role('manager') or has_role('super_admin'))
  with check (has_role('content') or has_role('manager') or has_role('super_admin'));

create policy videos_public_read on videos for select using (is_published);
create policy videos_staff_manage on videos for all
  using (has_role('content') or has_role('manager') or has_role('super_admin'))
  with check (has_role('content') or has_role('manager') or has_role('super_admin'));

create policy banners_public_read on banners for select using (is_active);
create policy banners_staff_manage on banners for all
  using (has_role('content') or has_role('manager') or has_role('super_admin'))
  with check (has_role('content') or has_role('manager') or has_role('super_admin'));

create policy pages_public_read on pages for select using (is_published);
create policy pages_staff_manage on pages for all
  using (has_role('content') or has_role('manager') or has_role('super_admin'))
  with check (has_role('content') or has_role('manager') or has_role('super_admin'));

create policy faqs_public_read on faqs for select using (is_active);
create policy faqs_staff_manage on faqs for all
  using (has_role('content') or has_role('manager') or has_role('super_admin'))
  with check (has_role('content') or has_role('manager') or has_role('super_admin'));

-- ---------------------------------------------------------------------
-- Promotions / popup — public reads active only; finance/manager write.
-- ---------------------------------------------------------------------
create policy promotions_public_read on promotions for select using (is_active);
create policy promotions_staff_manage on promotions for all
  using (has_role('manager') or has_role('finance') or has_role('super_admin'))
  with check (has_role('manager') or has_role('finance') or has_role('super_admin'));

create policy discounts_public_read on discounts for select using (is_active);
create policy discounts_staff_manage on discounts for all
  using (has_role('manager') or has_role('finance') or has_role('super_admin'))
  with check (has_role('manager') or has_role('finance') or has_role('super_admin'));

create policy coupons_staff_only on coupons for all
  using (has_role('manager') or has_role('finance') or has_role('super_admin'))
  with check (has_role('manager') or has_role('finance') or has_role('super_admin'));

create policy popups_public_read on promotional_popups for select using (is_active);
create policy popups_staff_manage on promotional_popups for all
  using (has_role('manager') or has_role('content') or has_role('super_admin'))
  with check (has_role('manager') or has_role('content') or has_role('super_admin'));

-- ---------------------------------------------------------------------
-- Notifications — staff only, never exposed to customers/anon.
-- ---------------------------------------------------------------------
create policy notifications_staff_read on notifications for select
  using (has_role('sales') or has_role('manager') or has_role('super_admin'));
create policy notification_logs_staff_read on notification_logs for select
  using (has_role('sales') or has_role('manager') or has_role('super_admin'));
create policy notification_templates_staff_manage on notification_templates for all
  using (has_role('manager') or has_role('super_admin'))
  with check (has_role('manager') or has_role('super_admin'));

-- ---------------------------------------------------------------------
-- Audit logs — super_admin only.
-- ---------------------------------------------------------------------
create policy audit_logs_super_admin_only on audit_logs for select
  using (has_role('super_admin'));

-- ---------------------------------------------------------------------
-- Guest order tracking (§35): a narrow, non-sensitive lookup by order
-- number + phone OR tracking_token, bypassing the orders RLS policy above
-- (which requires a matching authenticated customer). This is the only
-- sanctioned way an unauthenticated visitor sees order data.
-- ---------------------------------------------------------------------
create or replace function track_order(p_order_number text, p_phone_or_token text)
returns table (
  order_number text,
  status order_status,
  payment_status payment_status,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select o.order_number, o.status, o.payment_status, o.created_at
  from orders o
  where o.order_number = p_order_number
    and (o.customer_phone = p_phone_or_token or o.tracking_token::text = p_phone_or_token);
$$;

grant execute on function track_order(text, text) to anon, authenticated;
