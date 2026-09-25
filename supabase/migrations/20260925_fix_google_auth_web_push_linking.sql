-- Nile Tropical — Google Auth + free Web Push identity alignment.
-- Keeps guest checkout intact while allowing authenticated Google users to
-- receive browser push notifications by Supabase Auth user ID.

alter table public.push_subscriptions
  add column if not exists auth_user_id uuid references auth.users(id) on delete cascade;

alter table public.push_subscriptions
  alter column customer_id drop not null;

update public.push_subscriptions ps
set auth_user_id = c.auth_user_id
from public.customers c
where ps.customer_id = c.id
  and ps.auth_user_id is null;

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

create or replace function public.link_current_user_customer()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_customer_id uuid;
begin
  if v_uid is null then
    return null;
  end if;

  select email into v_email
  from auth.users
  where id = v_uid;

  select id into v_customer_id
  from public.customers
  where auth_user_id = v_uid
  limit 1;

  if v_customer_id is not null then
    return v_customer_id;
  end if;

  if v_email is null or trim(v_email) = '' then
    return null;
  end if;

  select id into v_customer_id
  from public.customers
  where auth_user_id is null
    and lower(trim(email::text)) = lower(trim(v_email))
  order by created_at asc
  limit 1;

  if v_customer_id is not null then
    update public.customers
    set auth_user_id = v_uid,
        updated_at = now()
    where id = v_customer_id
      and auth_user_id is null;
  end if;

  return v_customer_id;
end;
$$;

revoke all on function public.link_current_user_customer() from public;
grant execute on function public.link_current_user_customer() to authenticated;

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
  v_auth_user_id uuid;
  v_recipient text;
  v_email text;
  v_log_id uuid;
begin
  select o.order_number, o.customer_id, c.auth_user_id, u.email
    into v_order_number, v_customer_id, v_auth_user_id, v_email
  from public.orders o
  left join public.customers c on c.id = o.customer_id
  left join auth.users u on u.id = c.auth_user_id
  where o.id = p_order_id;

  v_recipient := coalesce(v_email, '');

  if v_customer_id is null or v_auth_user_id is null then
    return null;
  end if;

  if not exists (
    select 1
    from public.push_subscriptions
    where auth_user_id = v_auth_user_id
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
