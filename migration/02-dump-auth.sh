#!/usr/bin/env bash
# Dump the 30 auth identities belonging to Hatch360.
#
# Only one table references auth.users here (edoshatch360_users), unlike
# PMIS which has two.
#
# Hatch360 happens to own EVERY auth user in the source project -- all 30.
# That is a fact about today, not a licence to skip the filter: CRM and PMIS
# draw from the same pool, and whichever of the three moves last must still
# take only its own.
#
# identities travels with users. The hash is in users, the provider linkage
# in identities; without both, accounts exist and no one can sign in.
set -euo pipefail
: "${SRC_DB_URL:?export SRC_DB_URL first}"

OUT="dump/auth"; mkdir -p "$OUT"
IDS="select id from public.edoshatch360_users"

psql "$SRC_DB_URL" -v ON_ERROR_STOP=1 -c \
  "\copy (select * from auth.users where id in ($IDS)) to '${OUT}/users.csv' with (format csv, header true)"
psql "$SRC_DB_URL" -v ON_ERROR_STOP=1 -c \
  "\copy (select * from auth.identities where user_id in ($IDS)) to '${OUT}/identities.csv' with (format csv, header true)"

for tbl in users identities; do
  psql "$SRC_DB_URL" -At -c \
    "select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns
      where table_schema='auth' and table_name='${tbl}'" > "${OUT}/${tbl}.columns"
done

echo "users:      $(( $(wc -l < "${OUT}/users.csv") - 1 )) rows"
echo "identities: $(( $(wc -l < "${OUT}/identities.csv") - 1 )) rows"
echo; echo "Expect 30 users."
