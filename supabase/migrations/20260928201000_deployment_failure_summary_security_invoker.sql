-- Keep deployment intelligence summary subject to caller RLS policies.
create or replace view public.deployment_failure_summary
with (security_invoker = true)
as
select
  root_cause_category,
  coalesce(root_cause_subcategory, 'unspecified') as root_cause_subcategory,
  count(*) as failure_count,
  count(distinct run_id) as affected_runs,
  min(occurred_at) as first_seen,
  max(occurred_at) as last_seen
from public.deployment_failure_records
group by root_cause_category, coalesce(root_cause_subcategory, 'unspecified')
order by count(*) desc, max(occurred_at) desc;
