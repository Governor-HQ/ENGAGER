#!/usr/bin/env bash
# run.sh: runs the classrooms/groups database tests on a throwaway local PostgreSQL 17 cluster.
#
# Usage: bash supabase/db-tests/run.sh [path-to-forward-migration] [path-to-admin-views-migration]
#   The optional argument replaces the real forward migration (for example a deliberately broken copy).
#
# Never connects to a remote database: the cluster is created with initdb in a mktemp -d folder,
# listens on localhost:54329 only, uses trust auth for user postgres, and is always stopped and
# deleted on exit. Works in Linux/macOS bash and Windows Git Bash (PostgreSQL 17 binaries on PATH).
#
# Run 1 (db engager_test):     stub.sql, ../schema.sql, seed_legacy.sql, <migration>, groups.test.sql
# Run 2 (db engager_rollback): stub.sql, ../schema.sql, seed_legacy.sql, <migration>, <rollback>, rollback.test.sql
# Run 3 (db engager_propagation): stub.sql, ../schema.sql, <migration>, propagation.test.sql
# Run 4 (db engager_admin_views): stub.sql, ../schema.sql, <migration>, <admin views migration>, admin_views.test.sql
# Run 5 (db engager_release_gap): stub.sql, ../schema.sql, seed_legacy.sql, <migration>, release_gap.test.sql
# Run 6 (db engager_admin_rollback): stub.sql, ../schema.sql, <migration>, <admin views migration>, <admin views rollback>, admin_rollback.test.sql
# Exit code is non-zero if any test failed or any SQL errored.

set -u
set -o pipefail

PORT=54329
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATION="${1:-$SUPA_DIR/migrations/20261009120000_classrooms_groups.sql}"
ROLLBACK="$SUPA_DIR/rollbacks/20261009120000_classrooms_groups_rollback.sql"
ADMIN_VIEWS_ROLLBACK="$SUPA_DIR/rollbacks/20261020120000_admin_views_rollback.sql"
ADMIN_VIEWS="${2:-$SUPA_DIR/migrations/20261020120000_admin_views.sql}"

die() { echo "FATAL: $*" >&2; exit 2; }

# Native path for the PostgreSQL executables (C:/... on Windows Git Bash, unchanged elsewhere).
native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

[ -f "$MIGRATION" ] || die "migration file not found: $MIGRATION"
MIGRATION="$(cd "$(dirname "$MIGRATION")" && pwd)/$(basename "$MIGRATION")"

for tool in initdb pg_ctl psql createdb pg_isready; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool not found on PATH (PostgreSQL 17 binaries required)"
done
case "$(psql --version)" in
  *" 17."*) ;;
  *) echo "WARNING: expected PostgreSQL 17, found: $(psql --version)" >&2 ;;
esac

if pg_isready -h localhost -p "$PORT" -q >/dev/null 2>&1; then
  die "something is already listening on localhost:$PORT; refusing to touch it"
fi

TMP_ROOT="$(mktemp -d)" || die "mktemp -d failed"
DATA_DIR="$TMP_ROOT/data"
SERVER_LOG="$TMP_ROOT/server.log"
STARTED=0

cleanup() {
  local code=$?
  if [ "$STARTED" = 1 ]; then
    pg_ctl -D "$(native "$DATA_DIR")" -m fast -w -t 60 stop >/dev/null 2>&1 \
      || pg_ctl -D "$(native "$DATA_DIR")" -m immediate -w stop >/dev/null 2>&1
  fi
  rm -rf "$TMP_ROOT"
  exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

echo "Creating throwaway cluster in $TMP_ROOT"
if ! initdb -D "$(native "$DATA_DIR")" -U postgres -A trust -E UTF8 --locale=C >"$TMP_ROOT/initdb.log" 2>&1; then
  cat "$TMP_ROOT/initdb.log" >&2
  die "initdb failed"
fi

STARTED=1
if ! pg_ctl -D "$(native "$DATA_DIR")" -l "$(native "$SERVER_LOG")" -w -t 60 \
     -o "-p $PORT -c listen_addresses=localhost" start >/dev/null 2>&1; then
  cat "$SERVER_LOG" >&2 2>/dev/null
  die "pg_ctl start failed"
fi

PSQL=(psql -X -q -v ON_ERROR_STOP=1 -h localhost -p "$PORT" -U postgres)
TOTAL_FAILED_RUNS=0

# run_suite <db> <test file> <setup files...>
run_suite() {
  local db="$1" test_file="$2"
  shift 2
  echo
  echo "=== $db ==="
  if ! createdb -h localhost -p "$PORT" -U postgres "$db"; then
    echo "$db: 0 passed, 0 failed (createdb failed)"
    return 1
  fi

  local f out
  for f in "$@"; do
    if [ ! -f "$f" ]; then
      echo "ERROR: file not found: $f"
      echo "$db: 0 passed, 0 failed (setup file missing)"
      return 1
    fi
    if ! out="$("${PSQL[@]}" -d "$db" -f "$(native "$f")" 2>&1)"; then
      printf '%s\n' "$out"
      echo "ERROR: SQL error while running $f"
      echo "$db: 0 passed, 0 failed (setup failed)"
      return 1
    fi
    echo "setup ok: $f"
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/  | /'
  done

  local result_file="$TMP_ROOT/$db.out" status passed failed
  "${PSQL[@]}" -d "$db" -f "$(native "$test_file")" 2>&1 | tr -d '\r' | tee "$result_file"
  status=${PIPESTATUS[0]}
  passed=$(grep -c '^PASS ' "$result_file")
  failed=$(grep -c '^FAIL ' "$result_file")
  echo "$db: $passed passed, $failed failed"
  if [ "$status" -ne 0 ]; then
    if [ "$failed" -eq 0 ]; then
      echo "$db: FAILED with an SQL error (psql exit $status); see the error above"
    else
      echo "$db: FAILED (psql exit $status)"
    fi
    return 1
  fi
  if [ "$failed" -ne 0 ] || [ "$passed" -eq 0 ]; then
    echo "$db: FAILED"
    return 1
  fi
  echo "$db: OK"
  return 0
}

echo "Migration under test: $MIGRATION"

run_suite engager_test "$SCRIPT_DIR/groups.test.sql" \
  "$SCRIPT_DIR/stub.sql" "$SUPA_DIR/schema.sql" "$SCRIPT_DIR/seed_legacy.sql" "$MIGRATION" \
  || TOTAL_FAILED_RUNS=$((TOTAL_FAILED_RUNS + 1))

run_suite engager_rollback "$SCRIPT_DIR/rollback.test.sql" \
  "$SCRIPT_DIR/stub.sql" "$SUPA_DIR/schema.sql" "$SCRIPT_DIR/seed_legacy.sql" "$MIGRATION" "$ROLLBACK" \
  || TOTAL_FAILED_RUNS=$((TOTAL_FAILED_RUNS + 1))

run_suite engager_propagation "$SCRIPT_DIR/propagation.test.sql" \
  "$SCRIPT_DIR/stub.sql" "$SUPA_DIR/schema.sql" "$MIGRATION" \
  || TOTAL_FAILED_RUNS=$((TOTAL_FAILED_RUNS + 1))

run_suite engager_admin_views "$SCRIPT_DIR/admin_views.test.sql" \
  "$SCRIPT_DIR/stub.sql" "$SUPA_DIR/schema.sql" "$MIGRATION" "$ADMIN_VIEWS" \
  || TOTAL_FAILED_RUNS=$((TOTAL_FAILED_RUNS + 1))

run_suite engager_release_gap "$SCRIPT_DIR/release_gap.test.sql" \
  "$SCRIPT_DIR/stub.sql" "$SUPA_DIR/schema.sql" "$SCRIPT_DIR/seed_legacy.sql" "$MIGRATION" \
  || TOTAL_FAILED_RUNS=$((TOTAL_FAILED_RUNS + 1))

run_suite engager_admin_rollback "$SCRIPT_DIR/admin_rollback.test.sql" \
  "$SCRIPT_DIR/stub.sql" "$SUPA_DIR/schema.sql" "$MIGRATION" "$ADMIN_VIEWS" "$ADMIN_VIEWS_ROLLBACK" \
  || TOTAL_FAILED_RUNS=$((TOTAL_FAILED_RUNS + 1))

echo
if [ "$TOTAL_FAILED_RUNS" -ne 0 ]; then
  echo "RESULT: FAIL ($TOTAL_FAILED_RUNS of 6 runs failed)"
  exit 1
fi
echo "RESULT: PASS (all 6 runs)"
exit 0
