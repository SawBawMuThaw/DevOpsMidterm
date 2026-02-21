#!/usr/bin/env bash
set -e
set -o pipefail

# Phase 3 setup script for Ubuntu.
# Installs Docker Engine, Docker Compose, enables Docker on startup,
# and brings up the application stack via docker compose.
#
# USAGE:
#   sudo bash setup-docker.sh                        # auto-detects docker-compose.yml
#   sudo bash setup-docker.sh /path/to/compose/dir   # explicit compose directory
#   sudo COMPOSE_DIR=/path/to/dir bash setup-docker.sh
#
# The script resolves docker-compose.yml in this order:
#   1. First argument passed to the script
#   2. $COMPOSE_DIR environment variable
#   3. Directory of this script (same folder)
#   4. One level up from this script (legacy layout: scripts/../docker-compose.yml)
#   5. Current working directory

STEP=0
TOTAL_STEPS=6

log_step() {
  STEP=$((STEP + 1))
  echo "[${STEP}/${TOTAL_STEPS}] $1"
}

log_info()  { echo "[INFO]  $1"; }
log_warn()  { echo "[WARN]  $1"; }
log_error() { echo "[ERROR] $1"; }

# ---- Preflight checks ----
log_step "Preflight checks"

if [[ "${EUID}" -ne 0 ]]; then
  log_error "Please run as root: sudo bash $(basename "$0")"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID}" != "ubuntu" ]]; then
    log_warn "This script is designed for Ubuntu. Detected OS: ${ID}. Proceeding anyway."
  fi
fi

# ---- Resolve docker-compose.yml location ----
# Safely get the script's own directory (works even when sourced or piped)
if [[ -n "${BASH_SOURCE[0]}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="$(pwd)"
fi

resolve_compose_dir() {
  local candidate=""

  # Priority 1: explicit argument
  if [[ -n "$1" ]]; then
    candidate="$1"
    if [[ -f "${candidate}/docker-compose.yml" ]]; then
      echo "${candidate}"
      return 0
    fi
    log_warn "Argument path '${candidate}' does not contain docker-compose.yml"
  fi

  # Priority 2: COMPOSE_DIR environment variable
  if [[ -n "${COMPOSE_DIR}" ]]; then
    candidate="${COMPOSE_DIR}"
    if [[ -f "${candidate}/docker-compose.yml" ]]; then
      echo "${candidate}"
      return 0
    fi
    log_warn "COMPOSE_DIR '${candidate}' does not contain docker-compose.yml"
  fi

  # Priority 3: same directory as the script
  candidate="${SCRIPT_DIR}"
  if [[ -f "${candidate}/docker-compose.yml" ]]; then
    echo "${candidate}"
    return 0
  fi

  # Priority 4: one level up from the script (legacy layout)
  candidate="${SCRIPT_DIR}/.."
  if [[ -f "${candidate}/docker-compose.yml" ]]; then
    echo "$(cd "${candidate}" && pwd)"
    return 0
  fi

  # Priority 5: current working directory
  candidate="$(pwd)"
  if [[ -f "${candidate}/docker-compose.yml" ]]; then
    echo "${candidate}"
    return 0
  fi

  return 1
}

COMPOSE_DIR_RESOLVED="$(resolve_compose_dir "${1:-}")" || {
  log_error "Could not find docker-compose.yml in any of the search locations:"
  log_error "  1. Script argument:   ${1:-(not provided)}"
  log_error "  2. \$COMPOSE_DIR env:  ${COMPOSE_DIR:-(not set)}"
  log_error "  3. Script directory:  ${SCRIPT_DIR}"
  log_error "  4. Parent directory:  ${SCRIPT_DIR}/.."
  log_error "  5. Working directory: $(pwd)"
  log_error ""
  log_error "Fix options:"
  log_error "  a) Run from the folder containing docker-compose.yml:"
  log_error "     cd /path/to/phase3 && sudo bash scripts/setup-docker.sh"
  log_error "  b) Pass the compose directory as an argument:"
  log_error "     sudo bash setup-docker.sh /path/to/phase3"
  log_error "  c) Set the COMPOSE_DIR environment variable:"
  log_error "     sudo COMPOSE_DIR=/path/to/phase3 bash setup-docker.sh"
  exit 1
}

log_info "Using docker-compose.yml in: ${COMPOSE_DIR_RESOLVED}"

# ---- Install system dependencies ----
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
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list >/dev/null

  apt-get update -qq
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
  log_info "Docker Engine installed: $(docker --version)"
fi

# ---- Install Docker Compose plugin ----
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

cd "${COMPOSE_DIR_RESOLVED}"

# Pull latest images and bring up containers detached
docker compose pull
docker compose up -d

log_info "Application stack started"

# ---- Verification summary ----
echo ""
echo "=========================================="
echo "  Setup Complete - Verification Summary"
echo "=========================================="
printf "  %-20s %s\n" "Docker:"         "$(docker --version)"
printf "  %-20s %s\n" "Docker Compose:" "$(docker compose version)"
printf "  %-20s %s\n" "Docker on boot:" "$(systemctl is-enabled docker)"
printf "  %-20s %s\n" "Compose dir:"    "${COMPOSE_DIR_RESOLVED}"
echo ""
echo "  Running containers:"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
echo "=========================================="