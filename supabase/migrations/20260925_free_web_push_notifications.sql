-- Nile Tropical — free Web Push notification infrastructure.
-- No SMS gateway, paid sender ID, Firebase billing, or messaging provider.
-- Uses standards-based Web Push + VAPID and GitHub Actions as the dispatcher.

create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_push_subscriptions_customer_id
  on public.push_subscriptions(customer_id);

alter table public.push_subscriptions enable row level security;

revoke all on table public.push_subscriptions from anon;
grant select, insert, update, delete on table public.push_subscriptions to authenticated;
grant all on table public.push_subscriptions to service_role;

drop policy if exists push_subscriptions_select_own on public.push_subscriptions;
create policy push_subscriptions_select_own
on public.push_subscriptions
for select
to authenticated
using ((select auth.uid()) = customer_id);

drop policy if exists push_subscriptions_insert_own on public.push_subscriptions;
create policy push_subscriptions_insert_own
on public.push_subscriptions
for insert
to authenticated
with check ((select auth.uid()) = customer_id);

drop policy if exists push_subscriptions_update_own on public.push_subscriptions;
create policy push_subscriptions_update_own
on public.push_subscriptions
for update
to authenticated
using ((select auth.uid()) = customer_id)
with check ((select auth.uid()) = customer_id);

drop policy if exists push_subscriptions_delete_own on public.push_subscriptions;
create policy push_subscriptions_delete_own
on public.push_subscriptions
for delete
to authenticated
using ((select auth.uid()) = customer_id);

create or replace function public.queue_order_push_notification(
  p_order_id uuid,
  p_event_key text,
  p_fallback_message text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_number text;
  v_customer_id uuid;
  v_recipient text;
  v_log_id uuid;
begin
  select order_number, customer_id, customer_phone
    into v_order_number, v_customer_id, v_recipient
  from public.orders
  where id = p_order_id;

  if v_customer_id is null then
    return null;
  end if;

  if not exists (
    select 1
    from public.push_subscriptions
    where customer_id = v_customer_id
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

revoke all on function public.queue_order_push_notification(
  uuid, text, text
) from public;

grant execute on function public.queue_order_push_notification(
  uuid, text, text
) to authenticated;

create or replace function public.enqueue_order_lifecycle_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event text;
  v_fallback text;
begin
  if tg_op = 'INSERT' then
    v_event := 'order_received';
    v_fallback := 'Nile Tropical: We have received your order ' ||
      new.order_number || '. Thank you.';

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
        ' has been confirmed.'
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
        ' has been delivered. Thank you!'
      when 'order_cancelled' then
        'Nile Tropical: Your order ' || new.order_number ||
        ' has been cancelled.'
    end;
  else
    return new;
  end if;

  perform public.queue_order_push_notification(
    new.id,
    v_event,
    v_fallback
  );

  return new;
end;
$$;

drop trigger if exists enqueue_order_lifecycle_notification
on public.orders;

create trigger enqueue_order_lifecycle_notification
after insert or update of status
on public.orders
for each row
execute function public.enqueue_order_lifecycle_notification();

comment on function public.enqueue_order_lifecycle_notification() is
'Queues free Web Push notification records for important Nile Tropical order lifecycle events.';
