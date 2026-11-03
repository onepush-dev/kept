#!/bin/sh
# Kept on Railway: Postgres wait → create db → `kept bootstrap` → `kept migrate` → server.
# Runs as root only to fix the volume's ownership, then everything runs as kept (10001).
set -eu
: "${PGHOST:?PGHOST (the Postgres private domain) is required}"
: "${PGPASSWORD:?PGPASSWORD (the Postgres superuser password) is required}"
export PGPORT="${PGPORT:-5432}" PGUSER="${PGUSER:-postgres}" PGCONNECT_TIMEOUT=5
DB="${KEPT_DB_NAME:-kept}"
for v in KEPT_DB_OWNER_PASSWORD KEPT_DB_APP_PASSWORD KEPT_DB_AUTH_PASSWORD KEPT_DB_SYSTEM_PASSWORD; do
  eval "val=\${$v:-}"; [ -n "$val" ] || { echo "railway-start: $v is required" >&2; exit 1; }
done

# Railway mounts the volume root-owned; Kept runs as uid 10001.
mkdir -p /data/config
if [ "$(stat -c %u /data)" != "10001" ] || [ "$(stat -c %u /data/config)" != "10001" ]; then
  echo "railway-start: chown /data to kept (10001)"
  chown -R 10001:10001 /data
fi
chmod 700 /data/config
run() { setpriv --reuid=10001 --regid=10001 --clear-groups --inh-caps=-all -- "$@"; }

echo "railway-start: waiting for Postgres at $PGHOST:$PGPORT"
i=0
until PGDATABASE=postgres psql -Atqc 'select 1' >/dev/null 2>&1; do
  i=$((i+1)); [ $i -lt 90 ] || { echo "railway-start: Postgres not reachable" >&2; exit 1; }
  sleep 2
done
if [ "$(PGDATABASE=postgres psql -Atqc "select 1 from pg_database where datname = '$DB'")" != "1" ]; then
  echo "railway-start: creating database $DB"
  PGDATABASE=postgres psql -v ON_ERROR_STOP=1 -qc "create database \"$DB\""
fi

echo "railway-start: kept bootstrap"
PGDATABASE="$DB" run kept bootstrap

OWNER_URL="postgres://kept_owner:${KEPT_DB_OWNER_PASSWORD}@${PGHOST}:${PGPORT}/${DB}"
export KEPT_DATABASE_URL="${KEPT_DATABASE_URL:-postgres://kept_app:${KEPT_DB_APP_PASSWORD}@${PGHOST}:${PGPORT}/${DB}}"
export KEPT_AUTH_DATABASE_URL="${KEPT_AUTH_DATABASE_URL:-postgres://kept_auth:${KEPT_DB_AUTH_PASSWORD}@${PGHOST}:${PGPORT}/${DB}}"
export KEPT_SYSTEM_DATABASE_URL="${KEPT_SYSTEM_DATABASE_URL:-postgres://kept_system:${KEPT_DB_SYSTEM_PASSWORD}@${PGHOST}:${PGPORT}/${DB}}"
export KEPT_OWNER_DATABASE_URL="${KEPT_OWNER_DATABASE_URL:-$OWNER_URL}"
# The superuser and the raw login passwords never reach the server process.
unset PGPASSWORD PGHOST PGPORT PGUSER PGDATABASE PGCONNECT_TIMEOUT \
  KEPT_DB_OWNER_PASSWORD KEPT_DB_APP_PASSWORD KEPT_DB_AUTH_PASSWORD KEPT_DB_SYSTEM_PASSWORD KEPT_DB_NAME

echo "railway-start: kept migrate"
run kept migrate

echo "railway-start: starting Kept"
exec setpriv --reuid=10001 --regid=10001 --clear-groups --inh-caps=-all -- \
  node --import /app/apps/server/dist/observability/tracing.js /app/apps/server/dist/main.js
