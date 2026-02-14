#!/usr/bin/env bash
set -e

# Phase 1 server bootstrap script for Ubuntu.
# This script prepares a host so the Node.js app can run consistently.

# ---- Basic guardrails ----
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root (example: sudo bash scripts/setup.sh)"
  exit 1
fi

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
apt-get update
apt-get install -y curl ca-certificates gnupg git build-essential

# ---- Install Node.js LTS (includes npm) ----
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# ---- Create app directories used by deployment/runtime ----
# logs: application/service logs
# data: optional persistent app data
# public/uploads: uploaded product images
mkdir -p "${APP_ROOT}"
mkdir -p "${APP_ROOT}/logs"
mkdir -p "${APP_ROOT}/data"
mkdir -p "${APP_ROOT}/public/uploads"

# ---- Assign directory ownership to application user ----
if id "${APP_USER}" >/dev/null 2>&1; then
  chown -R "${APP_USER}:${APP_USER}" "${APP_ROOT}"
else
  echo "Warning: user '${APP_USER}' not found, skipping chown."
fi

# ---- Print quick verification info ----
echo "Setup complete."
node --version
npm --version
echo "Created directories under ${APP_ROOT}: logs, data, public/uploads"
