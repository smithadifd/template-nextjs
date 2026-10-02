#!/usr/bin/env bash
set -euo pipefail

script=${DEPLOY_SCRIPT:-"$(cd "$(dirname "$0")/.." && pwd)/deploy.sh"}
case_name=${1:-all}
scratch=$(mktemp -d)
trap 'rm -r "$scratch"' EXIT
mkdir -p "$scratch/bin" "$scratch/app/.git"
touch "$scratch/app/.env.production"
export TEST_LOG="$scratch/log" TEST_STATE="$scratch/state"
: > "$TEST_LOG"
printf '%s\n' oldcommit > "$TEST_STATE"

cat > "$scratch/bin/git" <<'STUB'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >> "$TEST_LOG"
case "$*" in
  'remote get-url origin') echo 'git@example.invalid:example/app.git' ;;
  'rev-parse --abbrev-ref HEAD') echo main ;;
  'diff --quiet HEAD'|'fetch origin main --quiet'|'fetch origin main') ;;
  'rev-parse origin/main') echo newcommit ;;
  'rev-parse HEAD')
    if [ "$PWD" = "$DEPLOY_REMOTE_PATH" ]; then cat "$TEST_STATE"; else echo newcommit; fi ;;
  'rev-parse --short HEAD') cat "$TEST_STATE" ;;
  'reset --hard origin/main') echo newcommit > "$TEST_STATE" ;;
  'reset --hard oldcommit') echo oldcommit > "$TEST_STATE" ;;
  *) echo "Unexpected git: $*" >&2; exit 1 ;;
esac
STUB
cat > "$scratch/bin/ssh" <<'STUB'
#!/usr/bin/env bash
printf 'ssh %s\n' "$*" >> "$TEST_LOG"
if [ "$1" = -G ]; then echo 'hostname example.invalid'; exit 0; fi
[ "$1" = "$DEPLOY_REMOTE" ] || exit 1
shift
[ "$*" = 'bash -s' ] || exit 1
bash -s
STUB
cat > "$scratch/bin/docker" <<'STUB'
#!/usr/bin/env bash
printf 'docker %s\n' "$*" >> "$TEST_LOG"
STUB
cat > "$scratch/bin/docker-compose" <<'STUB'
#!/usr/bin/env bash
printf 'docker-compose %s\n' "$*" >> "$TEST_LOG"
printf 'docker-compose PATH=%s\n' "$PATH" >> "$TEST_LOG"
STUB
cat > "$scratch/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "$TEST_LOG"
[ "${CURL_PASS:-0}" = 1 ]
STUB
cat > "$scratch/bin/sleep" <<'STUB'
#!/usr/bin/env bash
printf 'sleep %s\n' "$*" >> "$TEST_LOG"
STUB
chmod +x "$scratch/bin/"*
export PATH="$scratch/bin:$PATH" DEPLOY_REMOTE=app-alias DEPLOY_REMOTE_PATH="$scratch/app"
export DEPLOY_REPO_URL='git@example.invalid:example/app.git'
fail() { echo "FAIL [$case_name]: $1" >&2; if [ -f "$scratch/output" ]; then cat "$scratch/output" >&2; fi; exit 1; }
run_deploy() { bash "$script" > "$scratch/output" 2>&1; }
assert_has() { grep -Eq -- "$1" "$2" || fail "$3"; }

case "$case_name" in
  alias)
    for target in '' 'user@host' 'host:22' 'your-host' '-p22'; do
      if DEPLOY_REMOTE="$target" bash "$script" --dry-run > "$scratch/output" 2>&1; then
        fail "accepted invalid SSH target: '$target'"
      fi
      assert_has 'DEPLOY_REMOTE must be a configured SSH alias' "$scratch/output" 'missing alias validation message'
    done
    ;;
  compose)
    export CURL_PASS=1
    run_deploy || fail 'deployment with default compose command failed'
    assert_has 'docker-compose -f .* build' "$TEST_LOG" 'default compose build was not used'
    assert_has 'docker-compose -f .* up -d' "$TEST_LOG" 'default compose up was not used'
    : > "$TEST_LOG"
    export DEPLOY_COMPOSE_CMD='docker compose'
    run_deploy || fail 'deployment with configured compose command failed'
    assert_has 'docker compose -f .* build' "$TEST_LOG" 'configured compose build was not used'
    assert_has 'docker compose -f .* up -d' "$TEST_LOG" 'configured compose up was not used'
    if grep -Eq '^docker-compose ' "$TEST_LOG"; then fail 'default compose ran despite override'; fi
    ;;
  default-path)
    export CURL_PASS=1
    run_deploy || fail 'deployment with default compose PATH failed'
    assert_has '^docker-compose PATH=/usr/local/bin:/usr/syno/bin:' "$TEST_LOG" 'default compose did not receive the Synology PATH prefix'
    ;;
  backoff)
    if run_deploy; then fail 'unhealthy deployment succeeded'; fi
    actual=$(grep '^sleep ' "$TEST_LOG" | tr '\n' ',')
    [ "$actual" = 'sleep 1,sleep 2,sleep 4,sleep 8,sleep 8,sleep 8,sleep 8,sleep 8,sleep 8,' ] || fail "wrong capped backoff: $actual"
    assert_has 'Health check failed after 10 attempts: http://example.invalid:3000/health' "$scratch/output" 'failed URL missing'
    assert_has 'Logs: ssh app-alias .*docker-compose.*logs --tail 50' "$scratch/output" 'log-tail command missing'
    ;;
  rollback)
    if run_deploy; then fail 'unhealthy deployment succeeded'; fi
    assert_has 'git reset --hard oldcommit' "$TEST_LOG" 'previous remote commit was not restored'
    [ "$(cat "$TEST_STATE")" = oldcommit ] || fail 'remote commit was not restored'
    [ "$(grep -Ec '^docker-compose .* up -d$' "$TEST_LOG")" = 2 ] || fail 'compose was not restarted after rollback'
    assert_has 'Restored previous remote commit' "$scratch/output" 'rollback was not reported'
    ;;
  dry-run)
    bash "$script" --dry-run > "$scratch/output" 2>&1 || fail 'dry run failed'
    assert_has 'Dry run for SSH alias app-alias' "$scratch/output" 'dry-run plan missing'
    [ ! -s "$TEST_LOG" ] || fail 'dry run contacted a command stub'
    ;;
  all)
    for part in alias compose default-path backoff rollback dry-run; do
      "$0" "$part" || exit 1
    done
    echo 'PASS: 6 deploy shell tests'
    ;;
  *) fail "unknown test: $case_name" ;;
esac
if [ "$case_name" != all ]; then echo "PASS: $case_name"; fi
