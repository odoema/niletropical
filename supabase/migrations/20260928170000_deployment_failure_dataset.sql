-- 20260928170000_deployment_failure_dataset.sql
-- Deployment learning dataset: root causes, evidence, prevention controls.
-- This is observational data; never classify an incident without evidence.

create table if not exists public.deployment_root_cause_taxonomy (
  code text primary key,
  family text not null,
  description text not null,
  prevention_control text,
  active boolean not null default true
);

insert into public.deployment_root_cause_taxonomy(code,family,description,prevention_control) values
('CODE_ANALYSIS','application','Static analysis/lint gate blocks build before tests or compilation.','Run the exact CI analyzer locally/pre-commit and make the warning policy explicit.'),
('FLUTTER_WEB_BUILD','application','Flutter/Dart web compilation failure.','Run flutter build web --release against the same CI Flutter channel before push.'),
('SUPABASE_API_SYNC','data','Deployment workflow data synchronization/API operation failed.','Dry-run payloads and validate production schema/API responses before mutation.'),
('WORKFLOW_CANCELLATION','ci','Run was cancelled by workflow concurrency or superseded by a newer run.','Batch related commits; distinguish cancellation from technical failure.'),
('ENVIRONMENT_CONFIGURATION','ci','Required environment, secret, target, or configuration mismatch.','Validate production configuration before build.'),
('DEPENDENCY','ci','Dependency resolution, package, SDK, or toolchain failure.','Pin toolchains/lockfiles and test dependency installation in CI-equivalent environment.'),
('TEST_FAILURE','application','Automated test failure blocks deployment.','Run the complete CI test suite before push.'),
('ARTIFACT_ASSEMBLY','deployment','Build succeeded but artifact assembly or verification failed.','Verify required output files and paths before upload.'),
('DEPLOYMENT_PROVIDER','deployment','External deployment provider rejected or failed deployment.','Verify provider status, permissions, artifact, and deployment logs.'),
('UNCLASSIFIED','unknown','A failed run is known but evidence is insufficient to establish root cause.','Investigate job logs before assigning a root-cause category.')
on conflict(code) do nothing;

create table if not exists public.deployment_failure_records (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'github_actions',
  repository text not null,
  workflow_name text,
  run_id bigint,
  run_number integer,
  commit_sha text,
  branch text,
  event_name text,
  attempt integer,
  status text,
  conclusion text,
  failed_job text,
  failed_step text,
  root_cause_category text not null references public.deployment_root_cause_taxonomy(code),
  root_cause_subcategory text,
  symptom text,
  error_signature text,
  evidence_url text,
  evidence jsonb not null default '{}'::jsonb,
  detection_stage text,
  remediation text,
  prevention_control text,
  duration_seconds integer,
  occurred_at timestamptz,
  resolved_at timestamptz,
  recurrence_key text,
  evidence_confidence text not null default 'confirmed'
    check (evidence_confidence in ('confirmed','probable','unclassified')),
  taxonomy_version text not null default '1',
  created_at timestamptz not null default now(),
  unique(provider, run_id, run_number, root_cause_category, failed_job, failed_step)
);

create index if not exists deployment_failure_records_category_idx
  on public.deployment_failure_records(root_cause_category, root_cause_subcategory);
create index if not exists deployment_failure_records_occurred_idx
  on public.deployment_failure_records(occurred_at desc);
create index if not exists deployment_failure_records_signature_idx
  on public.deployment_failure_records(error_signature);

alter table public.deployment_failure_records enable row level security;
revoke all on public.deployment_failure_records from anon, authenticated;
grant select, insert, update on public.deployment_failure_records to authenticated;

drop policy if exists deployment_failure_records_staff on public.deployment_failure_records;
create policy deployment_failure_records_staff
  on public.deployment_failure_records for all to authenticated
  using ((select public.is_staff()))
  with check ((select public.is_staff()));

create or replace view public.deployment_failure_summary as
select root_cause_category,
       coalesce(root_cause_subcategory,'unspecified') root_cause_subcategory,
       count(*) failure_count,
       count(distinct run_id) affected_runs,
       min(occurred_at) first_seen,
       max(occurred_at) last_seen
from public.deployment_failure_records
group by 1,2
order by failure_count desc, last_seen desc;

-- Verified historical incidents currently available from GitHub Actions.
-- Do not add a root cause unless job evidence supports it.
insert into public.deployment_failure_records
(provider,repository,workflow_name,run_id,run_number,commit_sha,branch,event_name,conclusion,
 root_cause_category,root_cause_subcategory,symptom,error_signature,evidence_url,evidence,
 detection_stage,evidence_confidence,recurrence_key,occurred_at)
values
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36411181681,785,'7f55303fac1a78f97ad040aeb14bc287b3e588fb','feature/publishing-studio-complete','pull_request','failure','CODE_ANALYSIS','flutter_analyze','Static analysis gate exited 1 before tests/build.','flutter analyze exit 1','https://github.com/odoema/niletropical/actions/runs/36411181681','{"verified_from_job_logs":true}'::jsonb,'analyze','confirmed','CODE_ANALYSIS','2026-09-28T10:41:19Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36410970075,784,'64ad3a4f8476e2fbf9aa2cc26d1471cb3081bf7a','feature/publishing-studio-complete','pull_request','failure','CODE_ANALYSIS','flutter_analyze','Static analysis gate exited 1 before tests/build.','flutter analyze exit 1','https://github.com/odoema/niletropical/actions/runs/36410970075','{"verified_from_job_logs":true}'::jsonb,'analyze','confirmed','CODE_ANALYSIS','2026-09-28T10:39:08Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36410736316,783,'cedd5f5ad7add07acf0dadd7356821efb304fd5b','feature/publishing-studio-complete','pull_request','failure','CODE_ANALYSIS','flutter_analyze','Static analysis gate exited 1 before tests/build.','flutter analyze exit 1','https://github.com/odoema/niletropical/actions/runs/36410736316','{"verified_from_job_logs":true}'::jsonb,'analyze','confirmed','CODE_ANALYSIS','2026-09-28T10:36:44Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36410354535,782,'4696807388aa7feaa3ffb997dcda228e976ba1ac','feature/publishing-studio-complete','pull_request','failure','CODE_ANALYSIS','flutter_analyze','Static analysis gate exited 1 before tests/build.','flutter analyze exit 1','https://github.com/odoema/niletropical/actions/runs/36410354535','{"verified_from_job_logs":true}'::jsonb,'analyze','confirmed','CODE_ANALYSIS','2026-09-28T10:32:53Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36409957883,781,'2617ef31e1da6f0287f575eaee40c1bbe0e00a73','feature/publishing-studio-complete','pull_request','failure','CODE_ANALYSIS','flutter_analyze','Static analysis gate exited 1 before tests/build.','flutter analyze exit 1','https://github.com/odoema/niletropical/actions/runs/36409957883','{"verified_from_job_logs":true}'::jsonb,'analyze','confirmed','CODE_ANALYSIS','2026-09-28T10:28:55Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36388707604,780,'3eaf0d556b75b15e20fc065db38fabeb635a435','feature/publishing-studio-complete','pull_request','failure','CODE_ANALYSIS','flutter_analyze','Static analysis gate exited 1 before tests/build.','flutter analyze exit 1','https://github.com/odoema/niletropical/actions/runs/36388707604','{"verified_from_job_logs":true}'::jsonb,'analyze','confirmed','CODE_ANALYSIS','2026-09-28T06:53:21Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36384590321,778,'47f8a0bb0a26ae7b76388835dfe3549a6e77252b','feature/publishing-studio-complete','pull_request','failure','CODE_ANALYSIS','flutter_analyze','Static analysis gate exited 1 before tests/build.','flutter analyze exit 1','https://github.com/odoema/niletropical/actions/runs/36384590321','{"verified_from_job_logs":true}'::jsonb,'analyze','confirmed','CODE_ANALYSIS','2026-09-28T06:03:22Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36381711332,773,'309661909a5e106a01fc71008e59dbc1f97c8b79','feature/publishing-studio-complete','pull_request','failure','CODE_ANALYSIS','flutter_analyze','Static analysis gate exited 1 before tests/build.','flutter analyze exit 1','https://github.com/odoema/niletropical/actions/runs/36381711332','{"verified_from_job_logs":true}'::jsonb,'analyze','confirmed','CODE_ANALYSIS','2026-09-28T05:23:35Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36343772764,726,'ba1abd26f483d008491d5126a515e718f12086b4','master','push','failure','FLUTTER_WEB_BUILD','dart2js','Dart2JS failed with unmatched parentheses/braces in product_list_screen.dart.','product_list_screen.dart:54/150 syntax errors','https://github.com/odoema/niletropical/actions/runs/36343772764','{"verified_from_job_logs":true}'::jsonb,'build_web','confirmed','FLUTTER_WEB_BUILD','2026-09-27T19:16:52Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36343502511,725,'9b7f32ac75f8ecff8fa7240fb03506d878d47d9e','master','push','failure','FLUTTER_WEB_BUILD','dart2js','Flutter web compilation failed in product_list_screen.dart.','product_list_screen.dart syntax error','https://github.com/odoema/niletropical/actions/runs/36343502511','{"verified_from_job_logs":true}'::jsonb,'build_web','confirmed','FLUTTER_WEB_BUILD','2026-09-27T19:12:30Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36343281657,724,'e8f517cf31fdbe48e812724cd67bf20673c8443','master','push','failure','FLUTTER_WEB_BUILD','dart2js','Flutter web compilation failed in product_list_screen.dart.','product_list_screen.dart syntax error','https://github.com/odoema/niletropical/actions/runs/36343281657','{"verified_from_job_logs":true}'::jsonb,'build_web','confirmed','FLUTTER_WEB_BUILD','2026-09-27T19:08:57Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36343005157,723,'325edbe65247733e94d30d0737b63e0e6f87bd2e','master','push','failure','FLUTTER_WEB_BUILD','dart2js','Flutter web compilation failed in product_list_screen.dart.','product_list_screen.dart syntax error','https://github.com/odoema/niletropical/actions/runs/36343005157','{"verified_from_job_logs":true}'::jsonb,'build_web','confirmed','FLUTTER_WEB_BUILD','2026-09-27T19:04:32Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36340592592,17,'49746e8ad5c32b66afb24f387330481bdd13e38b','master','push','failure','SUPABASE_API_SYNC','rest_api','Supabase REST API returned HTTP 400 during high-confidence product creation.','curl HTTP 400','https://github.com/odoema/niletropical/actions/runs/36340592592','{"verified_from_job_logs":true}'::jsonb,'catalogue_sync','confirmed','SUPABASE_API_SYNC','2026-09-27T18:25:31Z'),
('github_actions','odoema/niletropical','Deploy Nile Tropical Website + Flutter App',36351054899,748,'1ef8af2ec2648fd57b7943e509b57f720687a326','master','push','failure','UNCLASSIFIED','evidence_gap','GitHub reports failure but job details are unavailable through the connected API.','job evidence unavailable','https://github.com/odoema/niletropical/actions/runs/36351054899','{"verified_from_job_logs":false}'::jsonb,'unknown','unclassified','UNCLASSIFIED','2026-09-27T21:15:45Z')
on conflict do nothing;

create table if not exists public.deployment_run_records (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'github_actions',
  repository text not null,
  workflow_name text,
  run_id bigint,
  run_number integer,
  commit_sha text,
  branch text,
  event_name text,
  attempt integer,
  status text,
  conclusion text,
  run_url text,
  started_at timestamptz,
  completed_at timestamptz,
  recorded_at timestamptz not null default now(),
  unique(provider,run_id,attempt)
);
create index if not exists deployment_run_records_conclusion_idx
  on public.deployment_run_records(conclusion,recorded_at desc);
create index if not exists deployment_run_records_workflow_idx
  on public.deployment_run_records(workflow_name,run_number desc);

alter table public.deployment_run_records enable row level security;
revoke all on public.deployment_run_records from anon, authenticated;
grant select, insert on public.deployment_run_records to authenticated;

drop policy if exists deployment_run_records_staff on public.deployment_run_records;
create policy deployment_run_records_staff
  on public.deployment_run_records for all to authenticated
  using ((select public.is_staff()))
  with check ((select public.is_staff()));
