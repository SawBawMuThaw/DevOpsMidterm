#!/usr/bin/env bash
set -e
set -o pipefail

# Phase 1 server bootstrap script for Ubuntu.
# This script prepares a host so the Node.js app can run consistently.

STEP=0
TOTAL_STEPS=8
log_step() {
  STEP=$((STEP + 1))
  echo "[${STEP}/${TOTAL_STEPS}] $1"
}

# ---- Basic guardrails ----
log_step "Preflight checks"
if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: please run as root (example: sudo bash scripts/setup.sh)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID}" != "ubuntu" ]]; then
    echo "Warning: this script is designed for Ubuntu. Detected: ${ID}"
  fi
fi

# ---- Configurable paths and owner ----
# Override these with environment variables when needed.
APP_ROOT="${APP_ROOT:-/opt/sample-midterm-node-app}"
APP_USER="${APP_USER:-${SUDO_USER:-ubuntu}}"

echo "Using APP_ROOT=${APP_ROOT}"
echo "Using APP_USER=${APP_USER}"

# ---- Install OS packages needed to build/run Node.js apps ----
log_step "Package index refresh"
apt-get update

log_step "OS package install"
apt-get install -y curl ca-certificates gnupg git build-essential

# ---- Install Node.js LTS (includes npm) ----
log_step "Node.js repo setup"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

log_step "Node.js install"
apt-get install -y nodejs

# ---- Create app directories used by deployment/runtime ----
# logs: application/service logs
# data: optional persistent app data
# public/uploads: uploaded product images
log_step "Directory creation"
mkdir -p "${APP_ROOT}"
mkdir -p "${APP_ROOT}/logs"
mkdir -p "${APP_ROOT}/data"
mkdir -p "${APP_ROOT}/public/uploads"
echo "Created directories under ${APP_ROOT}: logs, data, public/uploads"

# ---- Assign directory ownership to application user ----
OWNERSHIP_STATUS="skipped (user '${APP_USER}' not found)"
log_step "Ownership assignment"
if id "${APP_USER}" >/dev/null 2>&1; then
  chown -R "${APP_USER}:${APP_USER}" "${APP_ROOT}"
  OWNERSHIP_STATUS="applied to ${APP_USER}:${APP_USER}"
  echo "Ownership applied to ${APP_ROOT}"
else
  echo "Warning: user '${APP_USER}' not found, skipping chown."
fi

# ---- Print quick verification info ----
log_step "Verification summary"
echo "Setup complete."
node --version
npm --version
echo "Directory check: ${APP_ROOT}/{logs,data,public/uploads}"
echo "Ownership status: ${OWNERSHIP_STATUS}"
