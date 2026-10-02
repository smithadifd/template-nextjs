#!/usr/bin/env bash
set -euo pipefail

# ===========================================
# Deploy — self-hosted Docker Compose over SSH
# ===========================================
# Usage: ./scripts/deploy.sh [--dry-run]
#
# Preflight (local) → SSH to the host → pull → compose build/up → health poll.
# If the health check fails, restore the previous remote commit and rebuild.
# Database migrations may not be reversible; check migration compatibility before
# relying on this rollback for an app with persistent data.
# This is the pre-extraction shape of the shared `deploy-compose` script; a
# project parameterizes it rather than forking the logic.
#
# Configure via ./.deploy.env (gitignored) or environment variables. Every value
# below is a PLACEHOLDER — set them for your host. No real hostnames/ports/paths
# are baked in.
#
# Prerequisites:
#   - SSH key auth to the host (so `ssh "$DEPLOY_REMOTE"` works non-interactively)
#   - .env.production on the host at $DEPLOY_REMOTE_PATH/.env.production
#   - git + docker available on the host

if [ -f "$(dirname "$0")/../.deploy.env" ]; then
  # shellcheck disable=SC1091
  source "$(dirname "$0")/../.deploy.env"
fi

# --- Placeholders — override in .deploy.env or the environment ---
REMOTE="${DEPLOY_REMOTE:-}"                                 # configured SSH alias
REMOTE_PATH="${DEPLOY_REMOTE_PATH:-/path/to/app}"          # project dir on the host

COMPOSE_FILE="${DEPLOY_COMPOSE_FILE:-docker-compose.prod.yml}"
COMPOSE_CMD="${DEPLOY_COMPOSE_CMD:-docker-compose}"
if [[ "$COMPOSE_CMD" == docker-compose ]]; then
  REMOTE_PRE_CMD="${DEPLOY_REMOTE_PRE_CMD:-export PATH=/usr/local/bin:/usr/syno/bin:\$PATH}"
else
  REMOTE_PRE_CMD="${DEPLOY_REMOTE_PRE_CMD:-true}"
fi
APP_PORT="${DEPLOY_APP_PORT:-3000}"                        # host port from docker-compose.prod.yml
HEALTH_PATH="${DEPLOY_HEALTH_PATH:-/health}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

validate_config() {
  if [[ ! "$REMOTE" =~ ^[a-zA-Z0-9_.-]+$ ]] || [[ "$REMOTE" == -* ]] || [[ "$REMOTE" == "your-host" ]]; then
    error "DEPLOY_REMOTE must be a configured SSH alias (no user@host or port)."
    exit 1
  fi
  if [[ -z "$COMPOSE_CMD" ]]; then
    error "DEPLOY_COMPOSE_CMD must name a compose command."
    exit 1
  fi
}

dry_run() {
  info "Dry run for SSH alias $REMOTE"
  info "Remote path: $REMOTE_PATH; compose command: $COMPOSE_CMD"
  info "Would run preflight, deploy, health check, and rollback on health failure."
}

# ------------------------------------------
# Pre-flight (local)
# ------------------------------------------
preflight() {
  info "Running pre-flight checks..."

  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$branch" != "main" ]]; then
    error "Not on main (currently on: $branch). Merge to main first."
    exit 1
  fi

  if ! git diff --quiet HEAD 2>/dev/null; then
    error "Uncommitted changes. Commit or stash first."
    exit 1
  fi

  git fetch origin main --quiet
  local local_hash remote_hash
  local_hash=$(git rev-parse HEAD)
  remote_hash=$(git rev-parse origin/main)
  if [[ "$local_hash" != "$remote_hash" ]]; then
    warn "Local main differs from origin/main."
    read -rp "Continue anyway? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
  fi

  info "Pre-flight passed. Deploying commit: ${local_hash:0:8}"
}

# ------------------------------------------
# Deploy (on the host)
# ------------------------------------------
deploy() {
  local REPO_URL="${DEPLOY_REPO_URL:-$(git remote get-url origin 2>/dev/null || echo 'git@github.com:you/your-repo.git')}"
  info "Connecting to $REMOTE..."

  ssh "$REMOTE" bash -s <<REMOTE_SCRIPT
set -euo pipefail
$REMOTE_PRE_CMD

if [ ! -d "$REMOTE_PATH/.git" ]; then
  previous_commit=""
  echo "Cloning repository..."
  mkdir -p "$REMOTE_PATH"
  git clone "$REPO_URL" "$REMOTE_PATH"
else
  echo "Pulling latest changes..."
  cd "$REMOTE_PATH"
  previous_commit=\$(git rev-parse HEAD)
  git fetch origin main
  git reset --hard origin/main
fi

printf '%s\n' "\$previous_commit" > "$REMOTE_PATH/.deploy-previous-commit"

cd "$REMOTE_PATH"
echo "Now at commit: \$(git rev-parse --short HEAD)"

if [ ! -f ".env.production" ]; then
  echo "ERROR: .env.production not found at $REMOTE_PATH/.env.production"
  echo "Create it on the host and fill in production values (never committed)."
  exit 1
fi

echo "--- Building image ---"
$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file .env.production build

echo "--- Starting container ---"
$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file .env.production up -d

echo "--- Status ---"
$COMPOSE_CMD -f "$COMPOSE_FILE" ps
REMOTE_SCRIPT

  info "Deploy commands sent."
}

# ------------------------------------------
# Health check
# ------------------------------------------
healthcheck() {
  info "Running health check..."

  local host
  host=$(ssh -G "$REMOTE" | awk '/^hostname / {print $2}')
  [ -n "$host" ] || host="$REMOTE"

  local url="http://${host}:${APP_PORT}${HEALTH_PATH}"
  local attempt=1 max_attempts=10 delay=1

  while [ $attempt -le $max_attempts ]; do
    if curl -sf --max-time 5 "$url" > /dev/null 2>&1; then
      info "Health check passed: $url"
      return 0
    fi
    if [ "$attempt" -lt "$max_attempts" ]; then
      warn "Attempt $attempt/$max_attempts — retrying in ${delay}s..."
      sleep "$delay"
      delay=$((delay * 2))
      [ "$delay" -le 8 ] || delay=8
    fi
    ((attempt++))
  done

  error "Health check failed after $max_attempts attempts: $url"
  error "Logs: ssh $REMOTE 'cd $REMOTE_PATH && $COMPOSE_CMD -f $COMPOSE_FILE logs --tail 50'"
  return 1
}

rollback() {
  warn "Health check failed; restoring the last-known-good remote commit."
  ssh "$REMOTE" bash -s <<REMOTE_SCRIPT
set -euo pipefail
$REMOTE_PRE_CMD
cd "$REMOTE_PATH"
previous_commit=\$(cat .deploy-previous-commit)
if [ -z "\$previous_commit" ]; then
  echo "No previous remote commit exists; rollback is unavailable."
  exit 1
fi
git reset --hard "\$previous_commit"
$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file .env.production build
$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file .env.production up -d
REMOTE_SCRIPT
  warn "Restored previous remote commit. Verify service health and migration compatibility."
}

main() {
  if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != "--dry-run" ]; }; then
    error "Usage: $0 [--dry-run]"
    exit 2
  fi
  validate_config
  if [ "${1:-}" = "--dry-run" ]; then
    dry_run
    return 0
  fi
  echo "========================================="
  echo "  Deploy — $REMOTE"
  echo "========================================="
  preflight
  deploy
  if ! healthcheck; then
    rollback || error "Rollback failed; inspect the remote service."
    return 1
  fi
  info "Deployment successful."
}

main "$@"
