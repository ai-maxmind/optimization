#!/bin/bash
################################################################################
# Installation Script for Ubuntu Ultra Optimizer
# Version 1.0.0 - Complete Ubuntu optimization framework
################################################################################

set -euo pipefail

echo "=========================================="
echo "Ubuntu Ultra Optimizer - Installation"
echo "Version 1.0.0"
echo "30 Optimization Modules"
echo "=========================================="
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root"
    echo "   Please run: sudo $0"
    exit 1
fi

# Check Ubuntu
if [[ ! -f /etc/os-release ]]; then
    echo "❌ Cannot detect OS"
    exit 1
fi

source /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
    echo "⚠️  Warning: This tool is designed for Ubuntu"
    echo "   Detected: $ID $VERSION_ID"
    read -p "Continue anyway? (yes/no): " continue_anyway
    if [[ "$continue_anyway" != "yes" ]]; then
        exit 1
    fi
fi

# Check version
VERSION_MAJOR="${VERSION_ID%%.*}"
if (( VERSION_MAJOR < 22 )); then
    echo "❌ Ubuntu 22.04+ required"
    echo "   Detected: $VERSION_ID"
    exit 1
fi

echo "✅ OS Check: $ID $VERSION_ID"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
echo ""

PACKAGES=(
    "cpufrequtils"      # CPU frequency management
    "sysstat"           # System monitoring tools (sar, iostat)
    "ethtool"           # Network card tuning
    "jq"                # JSON processor
    "numactl"           # NUMA control
    "util-linux"        # System utilities
    "linux-tools-common" # Linux tools (perf, etc)
    "fio"               # Disk I/O benchmarking
    "iperf3"            # Network benchmarking
    "sysbench"          # CPU/memory benchmarking
    "gcc"               # Compiler for micro-benchmarks
)

for pkg in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg "; then
        echo "   ✅ $pkg (already installed)"
    else
        echo "   📦 Installing $pkg..."
        if apt-get install -y "$pkg" >/dev/null 2>&1; then
            echo "   ✅ $pkg (installed)"
        else
            echo "   ⚠️  $pkg (failed, continuing...)"
        fi
    fi
done

echo ""

# Create directories
echo "📁 Creating directories..."
mkdir -p /var/lib/ubuntu-ultra-opt/state
mkdir -p /var/lib/ubuntu-ultra-opt/backups
mkdir -p /var/lib/ubuntu-ultra-opt/benchmarks
mkdir -p /var/log/ubuntu-ultra-opt
echo "   ✅ /var/lib/ubuntu-ultra-opt/state"
echo "   ✅ /var/lib/ubuntu-ultra-opt/backups"
echo "   ✅ /var/lib/ubuntu-ultra-opt/benchmarks"
echo "   ✅ /var/log/ubuntu-ultra-opt"
echo ""

# Set permissions
echo "🔐 Setting permissions..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

chmod +x "$SCRIPT_DIR/orchestrator/cli.sh"
chmod +x "$SCRIPT_DIR/orchestrator/rollback.sh"
chmod +x "$SCRIPT_DIR/quick-start.sh"
chmod +x "$SCRIPT_DIR/verify.sh"

# Make all module files executable
find "$SCRIPT_DIR/modules" -type f -name "*.sh" -exec chmod +x {} \;

echo "   ✅ Scripts are now executable"
echo ""

# Optional: Create symlinks
echo "🔗 Creating convenience symlinks (optional)..."
read -p "Create symlinks in /usr/local/bin? (yes/no): " create_symlinks

if [[ "$create_symlinks" == "yes" ]]; then
    ln -sf "$SCRIPT_DIR/orchestrator/cli.sh" /usr/local/bin/ubuntu-ultra-opt
    ln -sf "$SCRIPT_DIR/orchestrator/rollback.sh" /usr/local/bin/ubuntu-ultra-rollback
    ln -sf "$SCRIPT_DIR/verify.sh" /usr/local/bin/ubuntu-ultra-verify
    echo "   ✅ Symlinks created:"
    echo "      ubuntu-ultra-opt"
    echo "      ubuntu-ultra-rollback"
    echo "      ubuntu-ultra-verify"
fi
echo ""

# Test
echo "🧪 Testing installation..."
if "$SCRIPT_DIR/orchestrator/cli.sh" --help >/dev/null 2>&1; then
    echo "   ✅ CLI is working"
else
    echo "   ❌ CLI test failed"
    exit 1
fi
echo ""

echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "📊 Framework Summary:"
echo "   • 30 Optimization modules"
echo "   • 4 Pre-built profiles (server, db, lowlatency, desktop)"
echo "   • Dependency resolution"
echo "   • Parallel execution"
echo "   • Live validation with auto-rollback"
echo "   • Comprehensive benchmarking"
echo ""
echo "📚 Quick Start:"
echo "   # Interactive setup (recommended)"
echo "   sudo $SCRIPT_DIR/quick-start.sh"
echo ""
echo "   # Or apply directly:"
echo "   sudo make server              # Server profile"
echo "   sudo make server-parallel     # With parallel execution"
echo "   sudo make server-validated    # With validation & rollback"
echo ""
echo "📖 Documentation:"
echo "   $SCRIPT_DIR/README.md"
echo "   $SCRIPT_DIR/docs/ARCHITECTURE.md"
echo ""
echo "🔧 Other commands:"
echo "   sudo make verify              # Verify optimizations"
echo "   sudo make benchmark           # Run benchmarks"
echo "   sudo make list-modules        # List all modules"
echo "   sudo make rollback            # Rollback changes"
echo ""

if [[ "$create_symlinks" == "yes" ]]; then
    echo "📎 Global commands available:"
    echo "   sudo ubuntu-ultra-opt --profile server"
    echo "   sudo ubuntu-ultra-opt --profile server --parallel --validate"
    echo "   sudo ubuntu-ultra-verify"
    echo "   sudo ubuntu-ultra-rollback --latest"
echo ""
fi

echo "⚠️  Important:"
echo "   • Always test in non-production first"
echo "   • Backup critical data before applying"
echo "   • Review README.md for detailed usage"
echo ""
    echo ""
fi
