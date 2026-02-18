#!/usr/bin/env bash
set -e
set -o pipefail

# Phase 1 bootstrap script for Ubuntu.
# Installs all dependencies and libraries needed for the Node.js application.

STEP=0
TOTAL_STEPS=10
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

try_install() {
  local pkg="$1"
  if apt-get install -y "${pkg}" >/dev/null 2>&1; then
    log_info "Installed package: ${pkg}"
    return 0
  fi
  log_warn "Package not available or failed to install: ${pkg}"
  return 1
}

# Resolve repo path so dependency install can target the app source directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---- Basic guardrails ----
log_step "Preflight checks"
if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: please run as root (example: sudo bash phase1/scripts/setup.sh)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID}" != "ubuntu" ]]; then
    log_warn "This script is designed for Ubuntu. Detected: ${ID}"
  fi
fi

# ---- Configurable paths ----
APP_SOURCE_DIR="${APP_SOURCE_DIR:-${REPO_ROOT}/phase1}"
INSTALL_APP_DEPS="${INSTALL_APP_DEPS:-1}"
INSTALL_PHASE2_LIBS="${INSTALL_PHASE2_LIBS:-1}"

echo "Using APP_SOURCE_DIR=${APP_SOURCE_DIR}"
echo "Using INSTALL_APP_DEPS=${INSTALL_APP_DEPS}"
echo "Using INSTALL_PHASE2_LIBS=${INSTALL_PHASE2_LIBS}"

# ---- Install OS packages needed to build/run Node.js apps ----
log_step "Package index refresh"
apt-get update -qq

log_step "Installing system build tools and libraries"
# Essential build tools for native Node modules (mongoose, multer, etc.)
apt-get install -y \
  curl \
  ca-certificates \
  gnupg \
  git \
  build-essential \
  python3 \
  python3-pip \
  make \
  g++ \
  libssl-dev \
  libffi-dev \
  wget \
  software-properties-common \
  apt-transport-https

log_info "System build tools installed successfully"

# ---- Install Node.js (prefer NodeSource 20.x; fallback to Ubuntu repo) ----
log_step "Installing Node.js LTS"
NODEJS_STATUS="not-installed"
if curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1; then
  apt-get install -y nodejs
  NODEJS_STATUS="installed from NodeSource (20.x)"
  log_info "Node.js installed from NodeSource"
else
  log_warn "NodeSource unreachable; falling back to Ubuntu repository."
  apt-get install -y nodejs npm
  NODEJS_STATUS="installed from Ubuntu repo fallback"
fi

# Verify Node.js installation
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  log_info "Node.js $(node --version) and npm $(npm --version) are ready"
else
  log_error "Node.js or npm installation failed"
  exit 1
fi

# ---- Install MongoDB Community Edition ----
log_step "Installing MongoDB Community Edition"
MONGODB_STATUS="skipped"
if [[ "${INSTALL_PHASE2_LIBS}" == "1" ]]; then
  # Check if MongoDB is already installed
  if command -v mongod >/dev/null 2>&1; then
    log_info "MongoDB is already installed"
    MONGODB_STATUS="already installed"
  else
    # Install MongoDB Community Edition from official repository
    if curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor >/dev/null 2>&1; then
      echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list >/dev/null
      apt-get update -qq
      if apt-get install -y mongodb-org >/dev/null 2>&1; then
        # Enable and start MongoDB service
        systemctl enable mongod >/dev/null 2>&1 || true
        systemctl start mongod >/dev/null 2>&1 || log_warn "Could not start MongoDB service (may need manual start)"
        MONGODB_STATUS="installed and service enabled"
        log_info "MongoDB Community Edition installed successfully"
      else
        log_warn "MongoDB installation failed. You may need to install manually or use a managed MongoDB service."
        MONGODB_STATUS="installation failed"
      fi
    else
      log_warn "Could not add MongoDB GPG key. Skipping MongoDB installation."
      log_warn "You can install MongoDB manually or use a managed MongoDB service (e.g., MongoDB Atlas)."
      MONGODB_STATUS="skipped (GPG key failed)"
    fi
  fi
else
  log_info "Skipping MongoDB installation (INSTALL_PHASE2_LIBS=0)"
  MONGODB_STATUS="skipped"
fi

# ---- Install Phase 2 dependencies (Nginx, Certbot, UFW, PM2) ----
log_step "Installing Phase 2 deployment tools"
PHASE2_STATUS="skipped"
if [[ "${INSTALL_PHASE2_LIBS}" == "1" ]]; then
  # Install web server, SSL, firewall, and process manager
  apt-get install -y \
    nginx \
    certbot \
    python3-certbot-nginx \
    ufw

  # Install PM2 globally for process management
  if npm install -g pm2 >/dev/null 2>&1; then
    log_info "PM2 installed globally"
  else
    log_warn "PM2 installation failed"
  fi

  PHASE2_STATUS="installed (nginx/certbot/ufw/pm2)"
  log_info "Phase 2 deployment tools installed"
else
  log_info "Skipping Phase 2 package dependencies."
fi

# ---- Create application directories ----
log_step "Creating application directories"
if [[ -d "${APP_SOURCE_DIR}" ]]; then
  mkdir -p "${APP_SOURCE_DIR}/public/uploads"
  mkdir -p "${APP_SOURCE_DIR}/logs"
  mkdir -p "${APP_SOURCE_DIR}/data"
  log_info "Created directories: public/uploads, logs, data"
else
  log_warn "APP_SOURCE_DIR ${APP_SOURCE_DIR} does not exist yet"
fi

# ---- Install Node.js application dependencies ----
log_step "Installing Node.js application dependencies"
APP_DEPS_STATUS="skipped"
if [[ "${INSTALL_APP_DEPS}" == "1" ]]; then
  if [[ -d "${APP_SOURCE_DIR}" && -f "${APP_SOURCE_DIR}/package.json" ]]; then
    log_info "Installing npm packages in ${APP_SOURCE_DIR}"
    cd "${APP_SOURCE_DIR}"
    
    # Use npm ci for production (requires package-lock.json) or npm install
    if [[ -f "${APP_SOURCE_DIR}/package-lock.json" ]]; then
      if npm ci --production=false >/dev/null 2>&1; then
        APP_DEPS_STATUS="installed via npm ci in ${APP_SOURCE_DIR}"
        log_info "Dependencies installed successfully using npm ci"
      else
        log_warn "npm ci failed, trying npm install"
        npm install >/dev/null 2>&1 && APP_DEPS_STATUS="installed via npm install in ${APP_SOURCE_DIR}" || APP_DEPS_STATUS="failed"
      fi
    else
      if npm install >/dev/null 2>&1; then
        APP_DEPS_STATUS="installed via npm install in ${APP_SOURCE_DIR}"
        log_info "Dependencies installed successfully"
      else
        APP_DEPS_STATUS="installation failed"
        log_error "Failed to install npm dependencies"
      fi
    fi
    
    cd - >/dev/null
  else
    APP_DEPS_STATUS="skipped (APP_SOURCE_DIR missing or no package.json)"
    log_warn "Cannot install app dependencies: ${APP_SOURCE_DIR}/package.json not found"
  fi
else
  log_info "Skipping app dependencies installation (INSTALL_APP_DEPS=0)"
fi

# ---- Print quick verification info ----
log_step "Verification summary"
echo ""
echo "=========================================="
echo "Setup Complete - Verification Summary"
echo "=========================================="
echo "Node.js: $(node --version 2>/dev/null || echo 'not found')"
echo "NPM: $(npm --version 2>/dev/null || echo 'not found')"
echo "Node.js source: ${NODEJS_STATUS}"
echo ""
echo "MongoDB: ${MONGODB_STATUS}"
if command -v mongod >/dev/null 2>&1; then
  echo "MongoDB version: $(mongod --version 2>/dev/null | head -n1 || echo 'unknown')"
fi
echo ""
echo "Phase 2 tools: ${PHASE2_STATUS}"
if command -v nginx >/dev/null 2>&1; then
  echo "Nginx version: $(nginx -v 2>&1 || echo 'unknown')"
fi
if command -v pm2 >/dev/null 2>&1; then
  echo "PM2 version: $(pm2 --version 2>/dev/null || echo 'unknown')"
fi
echo ""
echo "App dependencies: ${APP_DEPS_STATUS}"
if [[ -d "${APP_SOURCE_DIR}/node_modules" ]]; then
  echo "Node modules directory: exists"
fi
echo ""

