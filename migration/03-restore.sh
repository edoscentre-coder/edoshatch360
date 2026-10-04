#!/usr/bin/env bash
# Restore into the DESTINATION project. Schema must already exist.
#
# THE SEED-DATA PROBLEM, and why this truncates rather than skipping files.
#
# Thirteen of the 34 migrations contain INSERT statements. Four have "demo"
# in the name; the rest do not -- 0011 seeds plans and FAQs, 0027 and 0029
# seed weight benchmarks and the Isa Brown rearing chart, 0032 rewrites
# trial subscriptions. Some of the other INSERTs sit inside CREATE FUNCTION
# bodies (0007, 0008) and never execute at migration time at all.
#
# So "skip the demo migrations" is not a rule you can apply by reading
# filenames, and getting it wrong means seeded rows collide with real ones:
# duplicate keys if you are lucky, silently doubled sales figures if you are
# not.
#
# Skipping them is also wrong for a second reason -- later migrations ALTER
# and UPDATE the rows earlier ones seeded. Omit 0011 and 0032 has nothing to
# update.
#
# So: run all 34 migrations exactly as written, let them seed whatever they
# seed, then truncate every table and load the real data. The source project
# is the only authority on what the rows should be, and it already contains
# the genuine versions of everything the migrations seed -- its weight
# benchmarks, plans and FAQs come across in the dump like any other data.
set -euo pipefail
: "${DST_DB_URL:?export DST_DB_URL first (destination project connection string)}"

AUTH="dump/auth"; DATA="dump/data"
[[ -f "${AUTH}/users.csv" ]] || { echo "No auth dump. Run 02-dump-auth.sh."; exit 1; }
ls "${DATA}"/*.sql >/dev/null 2>&1 || { echo "No data dump. Run 01-dump-data.sh."; exit 1; }

TABLES=$(grep -v '^#' tables-in-order.txt | grep -v '^$')
LIST=$(echo "$TABLES" | sed "s/.*/'&'/" | paste -sd,)

echo "== verifying destination schema =="
missing=$(psql "$DST_DB_URL" -At -c \
  "select count(*) from (select unnest(array[$LIST]) as t) x
    where not exists (select 1 from information_schema.tables
                      where table_schema='public' and table_name=x.t)")
[[ "$missing" == "0" ]] || { echo "  $missing of 37 tables missing. Run migrations first."; exit 1; }
echo "  all 37 tables present"

echo "== clearing migration-seeded rows =="
QUALIFIED=$(echo "$TABLES" | sed 's/^/public./' | paste -sd,)
psql "$DST_DB_URL" -v ON_ERROR_STOP=1 -c \
  "truncate table ${QUALIFIED} restart identity cascade;"
echo "  37 tables truncated (sequences reset)"

echo "== phase 1: auth =="
U_COLS=$(cat "${AUTH}/users.columns"); I_COLS=$(cat "${AUTH}/identities.columns")
psql "$DST_DB_URL" -v ON_ERROR_STOP=1 <<SQL
begin;
\copy auth.users (${U_COLS}) from '${AUTH}/users.csv' with (format csv, header true)
\copy auth.identities (${I_COLS}) from '${AUTH}/identities.csv' with (format csv, header true)
commit;
SQL
echo "  auth loaded"

echo "== phase 2: application data =="
{
  echo "begin;"
  for f in $(ls "${DATA}"/*.sql | sort); do
    echo "\echo '  loading $(basename "$f")'"
    echo "\i ${f}"
  done
  echo "commit;"
} > dump/_restore-all.sql
psql "$DST_DB_URL" -v ON_ERROR_STOP=1 -f dump/_restore-all.sql

echo
echo "== destination row counts =="
psql "$DST_DB_URL" -c \
  "select c.relname, (xpath('/row/cnt/text()', query_to_xml(
     format('select count(*) as cnt from public.%I', c.relname),false,true,'')))[1]::text::bigint as rows
   from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind='r' and c.relname like 'edoshatch360%'
     and (xpath('/row/cnt/text()', query_to_xml(
          format('select count(*) as cnt from public.%I', c.relname),false,true,'')))[1]::text::bigint > 0
   order by rows desc"
echo
echo "Expect 558 rows total. Spot-check these against the source:"
echo "  daily_records 213   sale_items 60   weight_benchmarks 57   sales 39"
echo "If weight_benchmarks is 114 you truncated nothing and seeded twice."
