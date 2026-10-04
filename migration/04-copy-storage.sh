#!/usr/bin/env bash
# Copy the 4 files in edoshatch360-branding to the new project.
#
# Only four, and only branding -- logos and document headers. Small, but a
# tenant whose logo vanishes from every invoice notices immediately.
#
# Storage lives outside Postgres, so pg_dump never touches it. A database
# migration that "succeeded" while leaving these behind gives you a system
# where every row is present and every download 404s.
#
# Objects are listed from the source DATABASE (storage.objects) rather than
# by walking the API, so the list is exactly what Postgres believes exists.
set -euo pipefail
: "${SRC_DB_URL:?export SRC_DB_URL}"
: "${SRC_PROJECT_URL:?export SRC_PROJECT_URL  (https://<src-ref>.supabase.co)}"
: "${SRC_SERVICE_KEY:?export SRC_SERVICE_KEY}"
: "${DST_PROJECT_URL:?export DST_PROJECT_URL  (https://<new-ref>.supabase.co)}"
: "${DST_SERVICE_KEY:?export DST_SERVICE_KEY}"

TMP="dump/storage"; mkdir -p "$TMP"
ok=0; fail=0

psql "$SRC_DB_URL" -At -F'|' -c \
  "select bucket_id, name, coalesce(metadata->>'mimetype','application/octet-stream')
     from storage.objects where bucket_id like 'edoshatch360%' order by bucket_id, name" \
| while IFS='|' read -r bucket path mime; do
    [[ -z "$bucket" ]] && continue
    local_file="${TMP}/$(echo "${bucket}_${path}" | tr '/' '_')"

    if ! curl -fsSL "${SRC_PROJECT_URL}/storage/v1/object/${bucket}/${path}" \
         -H "Authorization: Bearer ${SRC_SERVICE_KEY}" -o "$local_file"; then
      echo "  DOWNLOAD FAILED  ${bucket}/${path}"; fail=$((fail+1)); continue
    fi

    if curl -fsS -X POST "${DST_PROJECT_URL}/storage/v1/object/${bucket}/${path}" \
         -H "Authorization: Bearer ${DST_SERVICE_KEY}" \
         -H "Content-Type: ${mime}" \
         -H "x-upsert: true" \
         --data-binary "@${local_file}" >/dev/null; then
      echo "  ok  ${bucket}/${path}"; ok=$((ok+1))
    else
      echo "  UPLOAD FAILED    ${bucket}/${path}"; fail=$((fail+1))
    fi
  done

echo
echo "Create the bucket in the destination FIRST or every upload 404s:"
echo "  edoshatch360-branding   PRIVATE"
echo
echo "Note: PRIVATE here. PMIS and CRM each have a PUBLIC branding bucket;"
echo "this one is not. Copy that habit across and the files become readable"
echo "to anyone with the URL."
echo
echo "Then verify the count matches the source:"
echo "  select bucket_id, count(*) from storage.objects group by bucket_id;"
echo "  source has 4 in edoshatch360-branding"
