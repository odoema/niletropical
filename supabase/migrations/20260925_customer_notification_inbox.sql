-- Nile Tropical: customer-facing in-app notification inbox
alter table public.notification_logs enable row level security;

drop policy if exists notification_logs_customer_read on public.notification_logs;
create policy notification_logs_customer_read
on public.notification_logs
for select to authenticated
using (
  exists (
    select 1 from public.customers c
    where c.id = notification_logs.customer_id
      and c.user_id = (select auth.uid())
  )
);

create index if not exists idx_notification_logs_customer_created
  on public.notification_logs(customer_id, created_at desc);
