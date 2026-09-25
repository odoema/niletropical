-- Nile Tropical — final Google Auth + Web Push production reconciliation.
-- This migration repairs the earlier push migration so the existing
-- customer/order/SMS notification system remains intact while Web Push
-- is added as a second channel.

-- 1. Align push subscriptions with Supabase Auth and the existing
--    customers.user_id ownership chain.
alter table public.push_subscriptions
  add column if not exists auth_user_id uuid
    references auth.users(id) on delete cascade;

alter table public.push_subscriptions
  alter column customer_id drop not null;

create index if not exists idx_push_subscriptions_auth_user_id
  on public.push_subscriptions(auth_user_id);

create index if not exists idx_customers_user_id
  on public.customers(user_id);

update public.push_subscriptions ps
set
  auth_user_id = c.user_id,
  customer_id = coalesce(ps.customer_id, c.id),
  updated_at = now()
from public.customers c
where ps.auth_user_id is null
  and ps.customer_id = c.id
  and c.user_id is not null;

-- 2. Only the authenticated owner can manage their browser subscription.
alter table public.push_subscriptions enable row level security;

revoke all on public.push_subscriptions from anon;
grant select, insert, update, delete on public.push_subscriptions to authenticated;
grant all on public.push_subscriptions to service_role;

drop policy if exists push_subscriptions_select_own on public.push_subscriptions;
drop policy if exists push_subscriptions_insert_own on public.push_subscriptions;
drop policy if exists push_subscriptions_update_own on public.push_subscriptions;
drop policy if exists push_subscriptions_delete_own on public.push_subscriptions;

create policy push_subscriptions_select_own
on public.push_subscriptions
for select to authenticated
using ((select auth.uid()) = auth_user_id);

create policy push_subscriptions_insert_own
on public.push_subscriptions
for insert to authenticated
with check ((select auth.uid()) = auth_user_id);

create policy push_subscriptions_update_own
on public.push_subscriptions
for update to authenticated
using ((select auth.uid()) = auth_user_id)
with check ((select auth.uid()) = auth_user_id);

create policy push_subscriptions_delete_own
on public.push_subscriptions
for delete to authenticated
using ((select auth.uid()) = auth_user_id);

-- 3. Google OAuth identity -> existing Nile Tropical customer.
--    Matching is against the verified Auth email and only an unlinked
--    customer row can be claimed.
create or replace function public.link_current_user_customer()
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_uid uuid := (select auth.uid());
  v_email text;
  v_customer_id uuid;
begin
  if v_uid is null then
    return null;
  end if;

  select u.email
    into v_email
  from auth.users u
  where u.id = v_uid;

  select c.id
    into v_customer_id
  from public.customers c
  where c.user_id = v_uid
  order by c.created_at asc
  limit 1;

  if v_customer_id is not null then
    return v_customer_id;
  end if;

  if v_email is null or btrim(v_email) = '' then
    return null;
  end if;

  select c.id
    into v_customer_id
  from public.customers c
  where c.user_id is null
    and lower(btrim(c.email::text)) = lower(btrim(v_email))
  order by c.created_at asc
  limit 1;

  if v_customer_id is null then
    return null;
  end if;

  update public.customers
  set user_id = v_uid,
      updated_at = now()
  where id = v_customer_id
    and user_id is null;

  if not found then
    return null;
  end if;

  return v_customer_id;
end;
$$;

revoke all on function public.link_current_user_customer() from public;
grant execute on function public.link_current_user_customer() to authenticated;

-- 4. Queue a Web Push log only when the order's customer is linked to
--    the current Supabase Auth identity and has a registered browser.
create or replace function public.queue_order_push_notification(
  p_order_id uuid,
  p_event_key text,
  p_fallback_message text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_customer_id uuid;
  v_auth_user_id uuid;
  v_recipient text;
  v_log_id uuid;
begin
  select o.customer_id, c.user_id, coalesce(c.email::text, '')
    into v_customer_id, v_auth_user_id, v_recipient
  from public.orders o
  left join public.customers c on c.id = o.customer_id
  where o.id = p_order_id;

  if v_customer_id is null or v_auth_user_id is null then
    return null;
  end if;

  if not exists (
    select 1
    from public.push_subscriptions ps
    where ps.auth_user_id = v_auth_user_id
  ) then
    return null;
  end if;

  insert into public.notification_logs(
    order_id,
    customer_id,
    channel,
    recipient,
    event_key,
    provider,
    status
  )
  values (
    p_order_id,
    v_customer_id,
    'push',
    v_recipient,
    p_event_key,
    'web_push',
    'pending'
  )
  returning id into v_log_id;

  return v_log_id;
end;
$$;

revoke all on function public.queue_order_push_notification(uuid, text, text) from public;
grant execute on function public.queue_order_push_notification(uuid, text, text) to authenticated;

-- 5. One lifecycle trigger, two channels.
--    The previous push migration accidentally replaced the SMS trigger.
--    This version preserves the existing SMS queue and adds Web Push.
create or replace function public.enqueue_order_lifecycle_notification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_event text;
  v_fallback text;
  v_sms_recipient text;
begin
  if tg_op = 'INSERT' then
    v_event := 'order_received';
    v_fallback :=
      'Nile Tropical: We have received your order ' ||
      new.order_number ||
      '. Thank you for shopping with us.';
  elsif new.status is distinct from old.status then
    v_event := case new.status::text
      when 'payment_confirmed' then 'payment_confirmed'
      when 'order_confirmed' then 'order_confirmed'
      when 'dispatched' then 'dispatched'
      when 'out_for_delivery' then 'out_for_delivery'
      when 'delivered' then 'delivered'
      when 'cancelled' then 'order_cancelled'
      else null
    end;

    if v_event is null then
      return new;
    end if;

    v_fallback := case v_event
      when 'payment_confirmed' then
        'Nile Tropical: Payment for order ' || new.order_number ||
        ' has been confirmed. We are preparing your items.'
      when 'order_confirmed' then
        'Nile Tropical: Your order ' || new.order_number ||
        ' has been confirmed and is being prepared.'
      when 'dispatched' then
        'Nile Tropical: Your order ' || new.order_number ||
        ' has been dispatched and is on its way.'
      when 'out_for_delivery' then
        'Nile Tropical: Your order ' || new.order_number ||
        ' is now out for delivery.'
      when 'delivered' then
        'Nile Tropical: Your order ' || new.order_number ||
        ' has been delivered. Thank you for shopping with us!'
      when 'order_cancelled' then
        'Nile Tropical: Your order ' || new.order_number ||
        ' has been cancelled. Please contact us if you need assistance.'
    end;
  else
    return new;
  end if;

  -- The live orders schema stores the customer phone as a snapshot.
  v_sms_recipient := coalesce(
    nullif(btrim(new.customer_phone_snapshot), ''),
    nullif(btrim(new.customer_email::text), '')
  );

  if v_sms_recipient is not null then
    perform public.queue_order_notification(
      new.id,
      v_sms_recipient,
      'sms',
      v_event,
      v_fallback
    );
  end if;

  perform public.queue_order_push_notification(
    new.id,
    v_event,
    v_fallback
  );

  return new;
end;
$$;

drop trigger if exists enqueue_order_lifecycle_notification on public.orders;

create trigger enqueue_order_lifecycle_notification
after insert or update of status
on public.orders
for each row
execute function public.enqueue_order_lifecycle_notification();

comment on function public.enqueue_order_lifecycle_notification() is
'Queues Nile Tropical SMS and Web Push notifications for order lifecycle events without breaking guest checkout.';
