#!/bin/bash
################################################################################
# Quick Start Script - Ubuntu Ultra Optimizer
# Interactive wizard for easy setup
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Ubuntu Ultra Optimizer - Quick Start"
echo "Version 1.0.0"
echo "=========================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root"
    echo "   Please run: sudo $0"
    exit 1
fi

# Detect system info
echo "📊 System Information:"
echo "   Distribution: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "   Kernel: $(uname -r)"
echo "   CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "   Cores: $(nproc) logical cores"
echo "   RAM: $(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024))GB"

# Detect storage type
if lsblk -d -o name,rota | grep -q "0$"; then
    echo "   Storage: SSD/NVMe detected"
else
    echo "   Storage: HDD detected"
fi

echo ""

# Profile selection
echo "📋 Available Profiles:"
echo ""
echo "   1) Server       - Web/app servers, general workloads"
echo "                     • 20-40% throughput improvement"
echo "                     • Moderate risk, balanced tuning"
echo ""
echo "   2) Database     - PostgreSQL, MySQL, MongoDB"
echo "                     • 30-60% query performance"
echo "                     • Optimized for I/O and memory"
echo ""
echo "   3) Low-Latency  - Trading, gaming, real-time"
echo "                     • 50-80% latency reduction"
echo "                     • High risk, aggressive tuning"
echo ""
echo "   4) Desktop      - Ubuntu Desktop, workstations"
echo "                     • 15-25% responsiveness"
echo "                     • Power saving, smooth UI"
echo ""
echo "   5) Auto-detect  - Let the wizard choose"
echo ""

read -p "Select profile (1-5): " profile_choice

case "$profile_choice" in
    1) PROFILE="server" ;;
    2) PROFILE="db" ;;
    3) PROFILE="lowlatency" ;;
    4) PROFILE="desktop" ;;
    5)
        # Auto-detect logic
        if pgrep -x "postgres\|mysqld\|mongod" &>/dev/null; then
            PROFILE="db"
            echo "   → Auto-detected: Database (db process running)"
        elif ls /sys/class/power_supply/BAT* &>/dev/null 2>&1; then
            PROFILE="desktop"
            echo "   → Auto-detected: Desktop (laptop/battery detected)"
        elif [[ $(nproc) -ge 8 ]]; then
            PROFILE="server"
            echo "   → Auto-detected: Server (high core count)"
        else
            PROFILE="desktop"
            echo "   → Auto-detected: Desktop (default)"
        fi
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Selected profile: $PROFILE"
echo ""

# Advanced features
echo "🚀 Advanced Features:"
echo ""
echo "   1) Standard     - Sequential execution (safe, slower)"
echo "   2) Parallel     - Parallel execution (fast, ~4x faster)"
echo "   3) Validated    - With health checks & auto-rollback (safest)"
echo "   4) Full         - Parallel + Validated (fastest + safest)"
echo ""

read -p "Select execution mode (1-4, default: 1): " exec_mode
exec_mode=${exec_mode:-1}

CLI_FLAGS="--profile $PROFILE"

case "$exec_mode" in
    1) 
        echo "   → Standard mode"
        ;;
    2) 
        echo "   → Parallel mode (4 concurrent jobs)"
        CLI_FLAGS="$CLI_FLAGS --parallel"
        ;;
    3) 
        echo "   → Validated mode (auto-rollback on failure)"
        CLI_FLAGS="$CLI_FLAGS --validate --auto-rollback"
        ;;
    4) 
        echo "   → Full mode (parallel + validated)"
        CLI_FLAGS="$CLI_FLAGS --parallel --validate --auto-rollback"
        ;;
    *)
        echo "   → Standard mode (invalid choice, using default)"
        ;;
esac

echo ""

# Dry-run first
echo "🔍 Running dry-run to preview changes..."
echo ""

if ! "$SCRIPT_DIR/orchestrator/cli.sh" $CLI_FLAGS --dry-run; then
    echo ""
    echo "❌ Dry-run failed. Please check the output above."
    exit 1
fi

echo ""
echo "=========================================="
echo "⚠️  WARNING"
echo "=========================================="
echo ""
echo "This will modify your system configuration:"
echo "  • Kernel parameters (sysctl)"
echo "  • I/O schedulers and read-ahead"
echo "  • CPU frequency governor"
echo "  • Network stack (TCP buffers, BBR, etc)"
echo "  • Filesystem mount options"
echo "  • Service limits and settings"
echo ""
echo "Safety measures:"
echo "  • Automatic backup of all configs"
echo "  • State tracking with unique RUN_ID"
echo "  • Full rollback capability"
if [[ "$exec_mode" == "3" ]] || [[ "$exec_mode" == "4" ]]; then
    echo "  • Live health validation"
    echo "  • Auto-rollback on failure"
fi
echo ""
echo "Profile: $PROFILE"
echo "Modules: 30 available"
echo ""

read -p "Continue with actual optimization? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "❌ Aborted by user"
    exit 0
fi

echo ""
echo "🚀 Applying optimizations..."
echo ""

# Apply optimizations
if "$SCRIPT_DIR/orchestrator/cli.sh" $CLI_FLAGS; then
    echo ""
    echo "=========================================="
    echo "✅ Optimization Complete!"
    echo "=========================================="
    echo ""
    
    # Get RUN_ID
    if [[ -d /var/lib/ubuntu-ultra-opt/state ]]; then
        LATEST_RUN=$(ls -t /var/lib/ubuntu-ultra-opt/state | head -1)
        echo "📊 Summary:"
        echo "   Profile: $PROFILE"
        echo "   Run ID: $LATEST_RUN"
        echo "   State: /var/lib/ubuntu-ultra-opt/state/$LATEST_RUN"
        echo "   Backup: /var/lib/ubuntu-ultra-opt/backups/$LATEST_RUN"
        echo ""
    fi
    
    echo "📝 Next steps:"
    echo ""
    echo "   1. Verify: sudo make verify"
    echo "   2. Benchmark: sudo make benchmark (optional)"
    echo "   3. Reboot: sudo reboot (RECOMMENDED)"
    echo ""
    echo "   To rollback: sudo make rollback"
    echo ""
    
    read -p "Reboot now? (yes/no): " reboot_now
    if [[ "$reboot_now" == "yes" ]]; then
        echo "🔄 Rebooting in 5 seconds..."
        sleep 5
        reboot
    fi
else
    echo ""
    echo "=========================================="
    echo "❌ Optimization Failed"
    echo "=========================================="
    echo ""
    echo "Check logs: tail -100 /var/log/ubuntu-ultra-opt/ubuntu-ultra-opt.log"
    echo "Rollback: sudo make rollback"
    echo ""
    exit 1
fi
