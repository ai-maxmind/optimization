#!/bin/bash
################################################################################
# PostgreSQL Installation Script for Ubuntu
# Version: 1.0.0
# Supports: PostgreSQL 14, 15, 16
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PG_VERSION="${PG_VERSION:-16}"
PG_DATA_DIR="/var/lib/postgresql/${PG_VERSION}/main"
PG_CONFIG_DIR="/etc/postgresql/${PG_VERSION}/main"
PG_LOG_DIR="/var/log/postgresql"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}PostgreSQL ${PG_VERSION} Installation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    echo "   Please run: sudo $0"
    exit 1
fi

# Check Ubuntu
if [[ ! -f /etc/os-release ]]; then
    echo -e "${RED}❌ Cannot detect OS${NC}"
    exit 1
fi

source /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
    echo -e "${YELLOW}⚠️  Warning: This script is designed for Ubuntu${NC}"
    echo "   Detected: $ID $VERSION_ID"
    read -p "Continue anyway? (yes/no): " continue_anyway
    if [[ "$continue_anyway" != "yes" ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}✅ OS Check: $ID $VERSION_ID${NC}"
echo ""

# Detect system resources
echo -e "${BLUE}📊 System Information:${NC}"
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
CPU_CORES=$(nproc)

echo "   CPU Cores: $CPU_CORES"
echo "   Total RAM: ${TOTAL_RAM_GB}GB"
echo ""

# Check if PostgreSQL is already installed
if command -v psql &>/dev/null; then
    EXISTING_VERSION=$(psql --version | awk '{print $3}' | cut -d. -f1)
    echo -e "${YELLOW}⚠️  PostgreSQL $EXISTING_VERSION is already installed${NC}"
    read -p "Continue with installation? This may upgrade/reinstall (yes/no): " continue_install
    if [[ "$continue_install" != "yes" ]]; then
        echo "Installation aborted"
        exit 0
    fi
fi

# Add PostgreSQL repository
echo -e "${BLUE}📦 Adding PostgreSQL repository...${NC}"
if [[ ! -f /etc/apt/sources.list.d/pgdg.list ]]; then
    # Create the file repository configuration
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    
    # Import the repository signing key
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    
    echo -e "${GREEN}   ✅ Repository added${NC}"
else
    echo -e "${GREEN}   ✅ Repository already exists${NC}"
fi
echo ""

# Update package list
echo -e "${BLUE}🔄 Updating package list...${NC}"
apt-get update -qq
echo -e "${GREEN}   ✅ Package list updated${NC}"
echo ""

# Install PostgreSQL
echo -e "${BLUE}📦 Installing PostgreSQL ${PG_VERSION}...${NC}"
apt-get install -y \
    postgresql-${PG_VERSION} \
    postgresql-contrib-${PG_VERSION} \
    postgresql-client-${PG_VERSION} \
    libpq-dev

echo -e "${GREEN}   ✅ PostgreSQL ${PG_VERSION} installed${NC}"
echo ""

# Install additional tools
echo -e "${BLUE}📦 Installing additional tools...${NC}"
apt-get install -y \
    postgresql-${PG_VERSION}-pg-stat-kcache \
    postgresql-${PG_VERSION}-pgaudit \
    postgresql-${PG_VERSION}-repack \
    pgbackrest \
    pgtop \
    2>/dev/null || echo -e "${YELLOW}   ⚠️  Some extensions not available${NC}"

echo -e "${GREEN}   ✅ Additional tools installed${NC}"
echo ""

# Check PostgreSQL service
echo -e "${BLUE}🔍 Checking PostgreSQL service...${NC}"
if systemctl is-active --quiet postgresql; then
    echo -e "${GREEN}   ✅ PostgreSQL is running${NC}"
else
    echo -e "${YELLOW}   ⚠️  Starting PostgreSQL...${NC}"
    systemctl start postgresql
    systemctl enable postgresql
    echo -e "${GREEN}   ✅ PostgreSQL started${NC}"
fi
echo ""

# Get PostgreSQL version
PG_INSTALLED_VERSION=$(su - postgres -c "psql --version" | awk '{print $3}')
echo -e "${GREEN}   PostgreSQL version: ${PG_INSTALLED_VERSION}${NC}"
echo ""

# Create backup directory
echo -e "${BLUE}📁 Creating directories...${NC}"
mkdir -p /var/lib/postgresql/backups
mkdir -p /var/lib/postgresql/archives
chown -R postgres:postgres /var/lib/postgresql/backups
chown -R postgres:postgres /var/lib/postgresql/archives
echo -e "${GREEN}   ✅ Backup directories created${NC}"
echo ""

# Setup postgres user password (optional)
echo -e "${BLUE}🔐 PostgreSQL User Setup${NC}"
read -p "Set password for postgres user? (yes/no): " set_password
if [[ "$set_password" == "yes" ]]; then
    read -sp "Enter password for postgres user: " POSTGRES_PASSWORD
    echo ""
    su - postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD '$POSTGRES_PASSWORD';\""
    echo -e "${GREEN}   ✅ Password set for postgres user${NC}"
fi
echo ""

# Configure pg_hba.conf for local access
echo -e "${BLUE}🔒 Configuring authentication...${NC}"
PG_HBA_FILE="${PG_CONFIG_DIR}/pg_hba.conf"

# Backup original
cp "${PG_HBA_FILE}" "${PG_HBA_FILE}.backup"

# Add local access rules (if not exists)
if ! grep -q "# Added by install script" "${PG_HBA_FILE}"; then
    cat >> "${PG_HBA_FILE}" <<EOF

# Added by install script
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
EOF
    echo -e "${GREEN}   ✅ Authentication configured${NC}"
else
    echo -e "${GREEN}   ✅ Authentication already configured${NC}"
fi
echo ""

# Reload PostgreSQL
echo -e "${BLUE}🔄 Reloading PostgreSQL...${NC}"
systemctl reload postgresql
echo -e "${GREEN}   ✅ PostgreSQL reloaded${NC}"
echo ""

# Test connection
echo -e "${BLUE}🧪 Testing connection...${NC}"
if su - postgres -c "psql -c 'SELECT version();'" &>/dev/null; then
    echo -e "${GREEN}   ✅ Connection successful${NC}"
else
    echo -e "${RED}   ❌ Connection failed${NC}"
fi
echo ""

# Create test database (optional)
read -p "Create test database 'testdb'? (yes/no): " create_testdb
if [[ "$create_testdb" == "yes" ]]; then
    su - postgres -c "psql -c 'CREATE DATABASE testdb;'" 2>/dev/null || echo -e "${YELLOW}   Database may already exist${NC}"
    echo -e "${GREEN}   ✅ Test database created${NC}"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${BLUE}📊 Installation Summary:${NC}"
echo "   PostgreSQL Version: ${PG_INSTALLED_VERSION}"
echo "   Data Directory: ${PG_DATA_DIR}"
echo "   Config Directory: ${PG_CONFIG_DIR}"
echo "   Log Directory: ${PG_LOG_DIR}"
echo ""
echo -e "${BLUE}🔧 Quick Commands:${NC}"
echo "   # Connect as postgres user"
echo "   sudo -u postgres psql"
echo ""
echo "   # Check status"
echo "   sudo systemctl status postgresql"
echo ""
echo "   # View logs"
echo "   sudo tail -f ${PG_LOG_DIR}/postgresql-${PG_VERSION}-main.log"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "   1. Optimize PostgreSQL:"
echo "      sudo ./optimize.sh"
echo ""
echo "   2. Create your databases and users"
echo ""
echo "   3. Configure backups"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "   • Backup directory: /var/lib/postgresql/backups"
echo "   • Always backup before making changes"
echo "   • Run optimize.sh for production tuning"
echo ""
