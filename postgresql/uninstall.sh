#!/bin/bash
################################################################################
# PostgreSQL Uninstall Script for Ubuntu
# Version: 1.0.0
# Completely removes PostgreSQL and optionally data
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}========================================${NC}"
echo -e "${RED}PostgreSQL Uninstallation${NC}"
echo -e "${RED}========================================${NC}"
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    echo "   Please run: sudo $0"
    exit 1
fi

# Check if PostgreSQL is installed
if ! command -v psql &>/dev/null; then
    echo -e "${YELLOW}⚠️  PostgreSQL is not installed${NC}"
    exit 0
fi

# Get installed version
PG_VERSION=$(psql --version | awk '{print $3}' | cut -d. -f1)
echo -e "${BLUE}📊 Detected PostgreSQL version: ${PG_VERSION}${NC}"
echo ""

# Warning
echo -e "${RED}⚠️  WARNING ⚠️${NC}"
echo -e "${RED}This will completely remove PostgreSQL!${NC}"
echo ""
echo "Options:"
echo "  1) Remove PostgreSQL but keep data (can reinstall later)"
echo "  2) Remove PostgreSQL AND delete all data (DESTRUCTIVE)"
echo "  3) Cancel"
echo ""

read -p "Select option (1-3): " uninstall_option

case "$uninstall_option" in
    1)
        REMOVE_DATA=false
        echo -e "${YELLOW}Will keep data directories${NC}"
        ;;
    2)
        REMOVE_DATA=true
        echo -e "${RED}Will DELETE all data${NC}"
        echo ""
        read -p "Type 'DELETE ALL DATA' to confirm: " confirm
        if [[ "$confirm" != "DELETE ALL DATA" ]]; then
            echo "Uninstallation cancelled"
            exit 0
        fi
        ;;
    3)
        echo "Uninstallation cancelled"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
read -p "Continue with uninstallation? (yes/no): " final_confirm
if [[ "$final_confirm" != "yes" ]]; then
    echo "Uninstallation cancelled"
    exit 0
fi

echo ""

# Create backup before removal (if keeping data)
if [[ "$REMOVE_DATA" == false ]]; then
    echo -e "${BLUE}📦 Creating backup before removal...${NC}"
    BACKUP_DIR="/tmp/postgresql-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup databases list
    if systemctl is-active --quiet postgresql; then
        su - postgres -c "psql -l" > "$BACKUP_DIR/databases.txt" 2>/dev/null || true
        echo -e "${GREEN}   ✅ Database list saved to $BACKUP_DIR${NC}"
    fi
    echo ""
fi

# Stop PostgreSQL
echo -e "${BLUE}🛑 Stopping PostgreSQL...${NC}"
systemctl stop postgresql 2>/dev/null || true
systemctl disable postgresql 2>/dev/null || true
echo -e "${GREEN}   ✅ PostgreSQL stopped${NC}"
echo ""

# Remove PostgreSQL packages
echo -e "${BLUE}📦 Removing PostgreSQL packages...${NC}"

# Remove specific version
apt-get remove -y postgresql-${PG_VERSION} \
    postgresql-client-${PG_VERSION} \
    postgresql-contrib-${PG_VERSION} \
    2>/dev/null || true

# Remove all PostgreSQL packages
apt-get remove -y postgresql postgresql-client postgresql-contrib 2>/dev/null || true

# Remove extensions
apt-get remove -y postgresql-*-pg-stat-kcache \
    postgresql-*-pgaudit \
    postgresql-*-repack \
    pgbackrest \
    pgtop \
    2>/dev/null || true

# Purge packages
apt-get purge -y postgresql* 2>/dev/null || true

# Auto-remove dependencies
apt-get autoremove -y

echo -e "${GREEN}   ✅ Packages removed${NC}"
echo ""

# Remove data directories (if requested)
if [[ "$REMOVE_DATA" == true ]]; then
    echo -e "${RED}🗑️  Removing data directories...${NC}"
    
    # Remove data directory
    if [[ -d /var/lib/postgresql ]]; then
        rm -rf /var/lib/postgresql
        echo -e "${GREEN}   ✅ Data directory removed${NC}"
    fi
    
    # Remove config directory
    if [[ -d /etc/postgresql ]]; then
        rm -rf /etc/postgresql
        echo -e "${GREEN}   ✅ Config directory removed${NC}"
    fi
    
    # Remove log directory
    if [[ -d /var/log/postgresql ]]; then
        rm -rf /var/log/postgresql
        echo -e "${GREEN}   ✅ Log directory removed${NC}"
    fi
    
    # Remove postgres user
    if id "postgres" &>/dev/null; then
        userdel -r postgres 2>/dev/null || true
        echo -e "${GREEN}   ✅ Postgres user removed${NC}"
    fi
    
    echo ""
else
    echo -e "${YELLOW}ℹ️  Data directories preserved:${NC}"
    echo "   • /var/lib/postgresql"
    echo "   • /etc/postgresql"
    echo "   • /var/log/postgresql"
    echo ""
fi

# Remove PostgreSQL repository
echo -e "${BLUE}📦 Removing PostgreSQL repository...${NC}"
if [[ -f /etc/apt/sources.list.d/pgdg.list ]]; then
    rm -f /etc/apt/sources.list.d/pgdg.list
    echo -e "${GREEN}   ✅ Repository removed${NC}"
fi
echo ""

# Update package list
echo -e "${BLUE}🔄 Updating package list...${NC}"
apt-get update -qq
echo -e "${GREEN}   ✅ Package list updated${NC}"
echo ""

# Verify removal
echo -e "${BLUE}🔍 Verifying removal...${NC}"
if command -v psql &>/dev/null; then
    echo -e "${RED}   ⚠️  PostgreSQL binaries still found${NC}"
else
    echo -e "${GREEN}   ✅ PostgreSQL completely removed${NC}"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Uninstallation Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [[ "$REMOVE_DATA" == false ]]; then
    echo -e "${YELLOW}📊 Data Preserved:${NC}"
    echo "   • Configuration: /etc/postgresql"
    echo "   • Data: /var/lib/postgresql"
    echo "   • Backup info: $BACKUP_DIR"
    echo ""
    echo -e "${BLUE}To reinstall with existing data:${NC}"
    echo "   sudo ./install.sh"
    echo ""
else
    echo -e "${GREEN}✅ PostgreSQL and all data removed${NC}"
    echo ""
fi

echo -e "${BLUE}Remaining files (if any):${NC}"
find /etc /var/lib /var/log -name "*postgres*" 2>/dev/null | head -10 || echo "   None found"
echo ""
