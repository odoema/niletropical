-- Nile Tropical — production notification queue and order lifecycle wiring
-- IMPORTANT: this migration matches the existing production schema.
-- notification_logs is the production queue table; it does not use notification_id.

alter table public.notification_templates enable row level security;
alter table public.notification_logs enable row level security;

drop policy if exists notification_templates_staff_manage on public.notification_templates;
create policy notification_templates_staff_manage
on public.notification_templates for all
using (has_role('manager') or has_role('super_admin'))
with check (has_role('manager') or has_role('super_admin'));

drop policy if exists notification_logs_staff_read on public.notification_logs;
create policy notification_logs_staff_read
on public.notification_logs for select
using (has_role('sales') or has_role('manager') or has_role('super_admin'));

create index if not exists idx_notification_logs_order_id
  on public.notification_logs(order_id);

create index if not exists idx_notification_logs_created_at
  on public.notification_logs(created_at desc);

create index if not exists idx_notification_logs_status
  on public.notification_logs(status);

create or replace function public.render_notification_template(
  p_event_key text,
  p_order_number text,
  p_fallback text
)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  v_template text;
begin
  select body_template
    into v_template
  from public.notification_templates
  where event_key = p_event_key
    and is_active = true
  order by updated_at desc
  limit 1;

  if v_template is null then
    return p_fallback;
  end if;

  return replace(v_template, '{{order_number}}', coalesce(p_order_number, ''));
end;
$$;

create or replace function public.queue_order_notification(
  p_order_id uuid,
  p_recipient text,
  p_channel text,
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
  v_message text;
  v_log_id uuid;
begin
  if p_recipient is null or btrim(p_recipient) = '' then
    return null;
  end if;

  select order_number, customer_id
    into v_order_number, v_customer_id
  from public.orders
  where id = p_order_id;

  v_message := public.render_notification_template(
    p_event_key,
    v_order_number,
    p_fallback_message
  );

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
    lower(coalesce(p_channel, 'sms')),
    p_recipient,
    p_event_key,
    'queue',
    'pending'
  )
  returning id into v_log_id;

  return v_log_id;
end;
$$;

revoke all on function public.queue_order_notification(
  uuid, text, text, text, text
) from public;

grant execute on function public.queue_order_notification(
  uuid, text, text, text, text
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
      new.order_number || '. Thank you for shopping with us.';
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

  perform public.queue_order_notification(
    new.id,
    new.customer_phone,
    'sms',
    v_event,
    v_fallback
  );

  return new;
end;
$$;

drop trigger if exists enqueue_order_lifecycle_notification on public.orders;
create trigger enqueue_order_lifecycle_notification
after insert or update of status on public.orders
for each row
execute function public.enqueue_order_lifecycle_notification();

comment on function public.enqueue_order_lifecycle_notification() is
'Queues SMS notification records in notification_logs for important order lifecycle events.';
