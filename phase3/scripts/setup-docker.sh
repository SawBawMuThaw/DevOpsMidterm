#!/usr/bin/env bash
set -e
set -o pipefail

# Phase 3 setup script for Ubuntu.
# Installs Docker Engine, Docker Compose, enables Docker on startup,
# and brings up the application stack via docker compose.

STEP=0
TOTAL_STEPS=6

log_step() {
  STEP=$((STEP + 1))
  echo "[${STEP}/${TOTAL_STEPS}] $1"
}

log_info() {
  echo "[INFO] $1"
}

log_warn() {
  echo "[WARN] $1"
}

log_error() {
  echo "[ERROR] $1"
}

# ---- Preflight checks ----
log_step "Preflight checks"
if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: please run as root (example: sudo bash setup-docker.sh)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  if [[ "${ID}" != "ubuntu" ]]; then
    log_warn "This script is designed for Ubuntu. Detected: ${ID}"
  fi
fi

# ---- Install dependencies ----
log_step "Installing system dependencies"
apt-get update -qq
apt-get install -y \
  curl \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common

log_info "System dependencies installed"

# ---- Install Docker Engine ----
log_step "Installing Docker Engine"
if command -v docker >/dev/null 2>&1; then
  log_info "Docker is already installed: $(docker --version)"
else
  # Add Docker's official GPG key
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  # Add Docker repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list >/dev/null

  apt-get update -qq
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

  log_info "Docker Engine installed: $(docker --version)"
fi

# ---- Install Docker Compose ----
log_step "Installing Docker Compose"
if docker compose version >/dev/null 2>&1; then
  log_info "Docker Compose is already installed: $(docker compose version)"
else
  apt-get install -y docker-compose-plugin
  log_info "Docker Compose installed: $(docker compose version)"
fi

# ---- Enable Docker on startup ----
log_step "Enabling Docker to start on system boot"
systemctl enable docker
systemctl start docker
log_info "Docker service enabled and started"

# ---- Deploy the application ----
log_step "Deploying application with Docker Compose"

# Resolve the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# docker-compose.yml lives one level up from the scripts/ folder
COMPOSE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  log_error "docker-compose.yml not found at ${COMPOSE_FILE}"
  log_error "Make sure you run this script from the repo root:"
  log_error "  sudo bash ./phase3/scripts/setup-docker.sh"
  exit 1
fi

log_info "Found docker-compose.yml at ${COMPOSE_FILE}"
cd "${COMPOSE_DIR}"

# Pull latest images and start containers
docker compose pull
docker compose up -d

log_info "Application stack started"

# ---- Verification summary ----
echo ""
echo "=========================================="
echo "Setup Complete - Verification Summary"
echo "=========================================="
echo "Docker:         $(docker --version)"
echo "Docker Compose: $(docker compose version)"
echo ""
echo "Running containers:"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Docker service on boot: $(systemctl is-enabled docker)"
echo "=========================================="