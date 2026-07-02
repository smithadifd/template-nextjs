#!/usr/bin/env bash
set -euo pipefail

# ===========================================
# Deploy — self-hosted Docker Compose over SSH
# ===========================================
# Usage: ./scripts/deploy.sh
#
# Preflight (local) → SSH to the host → pull → compose build/up → health poll.
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
REMOTE="${DEPLOY_REMOTE:-your-host}"                       # ssh alias or user@host
REMOTE_PATH="${DEPLOY_REMOTE_PATH:-/path/to/app}"          # project dir on the host
REMOTE_PRE_CMD="${DEPLOY_REMOTE_PRE_CMD:-true}"            # e.g. PATH export for the host's docker
REPO_URL="${DEPLOY_REPO_URL:-$(git remote get-url origin 2>/dev/null || echo 'git@github.com:you/your-repo.git')}"
COMPOSE_FILE="${DEPLOY_COMPOSE_FILE:-docker-compose.prod.yml}"
APP_PORT="${DEPLOY_APP_PORT:-3000}"                        # host port from docker-compose.prod.yml
HEALTH_PATH="${DEPLOY_HEALTH_PATH:-/health}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

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
  info "Connecting to $REMOTE..."

  ssh "$REMOTE" bash -s <<REMOTE_SCRIPT
set -euo pipefail
$REMOTE_PRE_CMD

if [ ! -d "$REMOTE_PATH/.git" ]; then
  echo "Cloning repository..."
  mkdir -p "$REMOTE_PATH"
  git clone "$REPO_URL" "$REMOTE_PATH"
else
  echo "Pulling latest changes..."
  cd "$REMOTE_PATH"
  git fetch origin main
  git reset --hard origin/main
fi

cd "$REMOTE_PATH"
echo "Now at commit: \$(git rev-parse --short HEAD)"

if [ ! -f ".env.production" ]; then
  echo "ERROR: .env.production not found at $REMOTE_PATH/.env.production"
  echo "Create it on the host and fill in production values (never committed)."
  exit 1
fi

echo "--- Building image ---"
docker-compose -f "$COMPOSE_FILE" --env-file .env.production build

echo "--- Starting container ---"
docker-compose -f "$COMPOSE_FILE" --env-file .env.production up -d

echo "--- Status ---"
docker-compose -f "$COMPOSE_FILE" ps
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
  local attempt=1 max_attempts=10

  while [ $attempt -le $max_attempts ]; do
    if curl -sf --max-time 5 "$url" > /dev/null 2>&1; then
      info "Health check passed: $url"
      return 0
    fi
    warn "Attempt $attempt/$max_attempts — waiting for app to start..."
    sleep 3
    ((attempt++))
  done

  error "Health check failed after $max_attempts attempts."
  error "Logs: ssh $REMOTE 'cd $REMOTE_PATH && docker-compose -f $COMPOSE_FILE logs --tail 50'"
  return 1
}

main() {
  echo "========================================="
  echo "  Deploy — $REMOTE"
  echo "========================================="
  preflight
  deploy
  healthcheck
  info "Deployment successful."
}

main "$@"
