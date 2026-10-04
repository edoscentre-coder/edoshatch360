-- ──────────────────────────────────────────────────────────────────────
-- Bring edoshatch360_archive_deleted_tenants into the migrations.
--
-- The table already exists in production. It was created directly against
-- the database on 2026-09-13, when a tenant left ownerless by deleted auth
-- users was removed and its data archived first. It holds one row: the
-- whole tenant -- farms, flocks, records, 15 top-level keys of it -- as
-- jsonb, with the reason for the deletion recorded alongside.
--
-- Nothing in this repository creates it, references it, or reads it. It was
-- found while preparing the move to a dedicated Supabase project: replaying
-- the migrations produced 36 tables where production has 37.
--
-- That gap is the whole problem. A migration set that does not describe the
-- live schema is not a description of anything -- the next person to build
-- an environment from it gets a database that is quietly missing the one
-- table holding a deleted tenant's only remaining copy.
--
-- IF NOT EXISTS, because production already has it and must not be
-- disturbed. On a fresh database this creates it; on production it is a
-- no-op that records the truth.
--
-- The archive is append-only by intention: there is no delete policy, and
-- platform admins are the only readers. A row here exists precisely because
-- the original was destroyed, so it is the last copy, not a convenience.
-- ──────────────────────────────────────────────────────────────────────

create table if not exists public.edoshatch360_archive_deleted_tenants (
  id uuid not null default gen_random_uuid(),
  archived_at timestamptz not null default now(),
  reason text,
  payload jsonb not null,
  constraint edoshatch360_archive_deleted_tenants_pkey primary key (id)
);

alter table public.edoshatch360_archive_deleted_tenants enable row level security;

drop policy if exists "archive platform admin only" on public.edoshatch360_archive_deleted_tenants;
create policy "archive platform admin only"
  on public.edoshatch360_archive_deleted_tenants
  for all
  using (public.edoshatch360_is_platform_admin());
