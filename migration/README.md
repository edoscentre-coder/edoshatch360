# Moving edoshatch360 to its own Supabase project

Hatch360 shares `cnlyuwslpcgosgwdmzav` with CRM, PMIS and POS. **Do CRM and
PMIS first** -- this one has the most moving parts of the three clean
islands, and is the wrong place to learn the process.

## What is being moved

Measured 2026-10-04:

| | |
|---|---|
| Tables | 37 (6 FK levels) |
| Rows | 558 |
| Functions | 34 |
| Triggers | 23 |
| Enum types | **19** |
| Foreign keys **outside** Hatch360 | **0** |
| Tables with FK to `auth.users` | 1 |
| Auth users | 30 |
| Storage objects | 4 in `edoshatch360-branding` (**private**) |
| Self-referencing FKs | none |

## Two things to know before you start

### 1. A missing table was found and fixed

Replaying the migrations produced **36** tables; production has **37**.
`edoshatch360_archive_deleted_tenants` was created directly against the
database on 2026-09-13 and never written into a migration. It holds one
row: an entire tenant -- farms, flocks, records -- archived as jsonb before
it was deleted for being ownerless, with the reason recorded.

It is the last copy of that tenant. Nothing in the repo reads it, so it
would have been dropped silently and nobody would have noticed until it
mattered.

`supabase/migrations/0035_archive_deleted_tenants.sql` now creates it, with
`if not exists` so production is untouched. Drift is closed: 37 and 37.

### 2. Seeding cannot be handled by skipping files

Thirteen of the 35 migrations contain INSERT statements. Only four say
"demo" in the name. `0011` seeds plans and FAQs, `0027` and `0029` seed
weight benchmarks and the Isa Brown rearing chart, `0032` rewrites trial
subscriptions -- and some INSERTs sit inside `CREATE FUNCTION` bodies
(`0007`, `0008`) and never execute at migration time at all.

Skipping by filename is therefore guesswork, and wrong twice over: later
migrations UPDATE rows that earlier ones seeded, so omitting `0011` leaves
`0032` with nothing to work on.

**So run all 35 migrations exactly as written, then truncate, then load.**
`03-restore.sh` does this. The source project is the only authority on what
the rows should be, and the genuine versions of everything the migrations
seed -- benchmarks, plans, FAQs -- come across in the dump like any other
data.

## Prerequisites

```bash
export SRC_DB_URL='postgresql://postgres:...@db.cnlyuwslpcgosgwdmzav.supabase.co:5432/postgres'
export DST_DB_URL='postgresql://postgres:...@db.<new-ref>.supabase.co:5432/postgres'
# storage step only:
export SRC_PROJECT_URL='https://cnlyuwslpcgosgwdmzav.supabase.co'
export DST_PROJECT_URL='https://<new-ref>.supabase.co'
export SRC_SERVICE_KEY='...'
export DST_SERVICE_KEY='...'
```

Never commit these or paste them into a chat. `dump/` is gitignored and
holds real records plus password hashes -- delete it once verified.

## Steps

### 1. Create the destination project
Account B, region `eu-west-1`.

### 2. Build the schema
```bash
cd ..
for f in supabase/migrations/*.sql; do
  echo "== $f"; psql "$DST_DB_URL" -v ON_ERROR_STOP=1 -f "$f"
done
```
All 35, in order, including the new `0035`. This creates the 19 enums, 34
functions, 23 triggers and every RLS policy. Expect seeded demo rows
afterwards -- step 5 removes them.

### 3. Create the bucket
| Bucket | Public |
|---|---|
| `edoshatch360-branding` | **no -- private** |

Private, unlike CRM's and PMIS's branding buckets, which are public. Do not
copy that habit across or these files become readable to anyone with the URL.

### 4. Dump
```bash
cd migration
./01-dump-data.sh    # 37 files, FK order
./02-dump-auth.sh    # expect 30 users
```

### 5. Restore and copy files
```bash
./03-restore.sh      # verifies schema, TRUNCATES, loads auth then data
./04-copy-storage.sh # 4 branding files
```

### 6. Verify before switching anything
- Sign in with an **existing** password. A rejection means identities did
  not load.
- Check `weight_benchmarks` is **57**. If it is 114, the truncate did not
  run and you have seeded twice -- the single most likely failure here.
- Open a flock and walk to its daily records (213 rows, FK level 4). If
  those resolve, everything shallower did.
- Confirm a tenant logo still renders -- the only real check on storage.
- Confirm RLS still isolates the 2 tenants.

### 7. Point the app at it
In Vercel, project `edoshatch360`:
```
NEXT_PUBLIC_SUPABASE_URL      -> https://<new-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY -> new anon key
SUPABASE_SERVICE_ROLE_KEY     -> new service role key
NEXT_PUBLIC_SITE_URL          -> https://edoshatch360.edoscentre.co.ke
```
`NEXT_PUBLIC_SITE_URL` is `http://localhost:3000` today, which is wrong
regardless of this migration.

## Rolling back

Steps 1-6 write nothing to the source. Until step 7, rollback is deleting
the new project.

## Afterwards

Leave the source tables alone for a few days. Dropping them is separate,
deliberate, and the only irreversible step here.
