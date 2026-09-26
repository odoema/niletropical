-- Nile Tropical — canonical order lifecycle / tracking consistency
-- 2026-09-26
--
-- Every UPDATE that changes orders.status is recorded in order_status_history.
-- Payment confirmation is detected from payment_status, not a display-status value.

create or replace function public.record_order_status_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    insert into public.order_status_history (order_id, status, note)
    values (
      new.id,
      new.status,
      case new.status::text
        when 'payment_pending' then 'Payment is awaiting confirmation'
        when 'new_order' then
          case when new.payment_status = 'paid'
            then 'Payment confirmed; order released for processing'
            else 'Order received'
          end
        when 'order_confirmed' then 'Order confirmed and being prepared'
        when 'dispatched' then 'Order dispatched'
        when 'out_for_delivery' then 'Order is out for delivery'
        when 'delivered' then 'Order delivered'
        when 'cancelled' then 'Order cancelled'
        else 'Order status updated to ' || new.status::text
      end
    );
  end if;
  return new;
end;
$$;

drop trigger if exists record_order_status_history_on_update on public.orders;

create trigger record_order_status_history_on_update
after update of status on public.orders
for each row
execute function public.record_order_status_history();


create or replace function public.enqueue_order_lifecycle_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event text;
  v_fallback text;
  v_recipient text;
begin
  if tg_op = 'INSERT' then
    v_event := 'order_received';
    v_fallback :=
      'Nile Tropical: We have received your order ' ||
      new.order_number || '. Thank you for shopping with us.';

  elsif new.payment_status is distinct from old.payment_status
        and new.payment_status = 'paid' then
    v_event := 'payment_confirmed';
    v_fallback :=
      'Nile Tropical: Payment for order ' ||
      new.order_number ||
      ' has been confirmed. We are preparing your items.';

  elsif new.status is distinct from old.status then
    v_event := case new.status::text
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
      else null
    end;
  else
    return new;
  end if;

  v_recipient := coalesce(new.customer_phone_snapshot, new.customer_phone);

  perform public.queue_order_notification(
    new.id, v_recipient, 'sms', v_event, v_fallback
  );

  return new;
end;
$$;

drop trigger if exists enqueue_order_lifecycle_notification on public.orders;

create trigger enqueue_order_lifecycle_notification
after insert or update of status, payment_status on public.orders
for each row
execute function public.enqueue_order_lifecycle_notification();

comment on function public.record_order_status_history() is
'Records every customer-visible order status transition in order_status_history.';

comment on function public.enqueue_order_lifecycle_notification() is
'Queues canonical lifecycle events; payment confirmation is detected from payment_status = paid.';
