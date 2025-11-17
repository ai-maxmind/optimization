#!/bin/bash
################################################################################
# Verify Optimizations - Check if optimizations are active
# Version 1.0.0
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core/log/log.sh" 2>/dev/null || true

echo "=========================================="
echo "Ubuntu Ultra Optimizer - Verification"
echo "Version 1.0.0"
echo "=========================================="
echo ""

# Check if any runs exist
STATE_DIR="/var/lib/ubuntu-ultra-opt/state"
if [[ ! -d "$STATE_DIR" ]] || [[ -z "$(ls -A "$STATE_DIR" 2>/dev/null)" ]]; then
    echo "⚠️  No optimization runs found"
    echo ""
    echo "   Have you run the optimizer yet?"
    echo ""
    echo "   Quick start: sudo ./quick-start.sh"
    echo "   Or directly: sudo make server"
    echo ""
    exit 1
fi

# Get latest run
LATEST_RUN=$(ls -t "$STATE_DIR" | head -1)
TOTAL_RUNS=$(ls "$STATE_DIR" | wc -l)

echo "📊 Status:"
echo "   Latest Run: $LATEST_RUN"
echo "   Total Runs: $TOTAL_RUNS"
echo ""

# Show run info
if [[ -f "$STATE_DIR/$LATEST_RUN/run.json" ]]; then
    echo "📋 Run Information:"
    if command -v jq &>/dev/null; then
        echo "   Profile: $(jq -r '.profile // "unknown"' "$STATE_DIR/$LATEST_RUN/run.json")"
        echo "   Timestamp: $(jq -r '.timestamp // "unknown"' "$STATE_DIR/$LATEST_RUN/run.json")"
        echo "   Status: $(jq -r '.status // "unknown"' "$STATE_DIR/$LATEST_RUN/run.json")"
    fi
    echo ""
fi

echo "=========================================="
echo "🔍 Checking Key Optimizations"
echo "=========================================="
echo ""

# CPU Governor
echo "🖥️  CPU Governor:"
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    echo "   Current: $governor"
    
    # Check consistency
    inconsistent=0
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f "$cpu" ]]; then
            cpu_gov=$(cat "$cpu")
            if [[ "$cpu_gov" != "$governor" ]]; then
                inconsistent=1
                echo "   ⚠️  $(basename $(dirname $(dirname "$cpu"))): $cpu_gov (inconsistent)"
            fi
        fi
    done
    
    if [[ $inconsistent -eq 0 ]]; then
        echo "   ✅ All CPUs using same governor"
    fi
else
    echo "   ⚠️  CPU frequency scaling not available"
fi
echo ""

# Memory
echo "💾 Memory Configuration:"
echo "   vm.swappiness: $(sysctl -n vm.swappiness 2>/dev/null || echo 'N/A')"
echo "   vm.dirty_ratio: $(sysctl -n vm.dirty_ratio 2>/dev/null || echo 'N/A')"
echo "   vm.dirty_background_ratio: $(sysctl -n vm.dirty_background_ratio 2>/dev/null || echo 'N/A')"
echo "   vm.overcommit_memory: $(sysctl -n vm.overcommit_memory 2>/dev/null || echo 'N/A')"

if [[ -d /sys/kernel/mm/transparent_hugepage ]]; then
    thp_enabled=$(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null | grep -oP '\[\K[^\]]+')
    thp_defrag=$(cat /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null | grep -oP '\[\K[^\]]+')
    echo "   THP enabled: $thp_enabled"
    echo "   THP defrag: $thp_defrag"
fi
echo ""

# I/O Schedulers
echo "💿 I/O Schedulers:"
for device in /sys/block/sd* /sys/block/nvme*; do
    if [[ -d "$device" ]] && [[ -f "$device/queue/scheduler" ]]; then
        dev_name=$(basename "$device")
        scheduler=$(cat "$device/queue/scheduler" | grep -oP '\[\K[^\]]+')
        read_ahead=$(cat "$device/queue/read_ahead_kb" 2>/dev/null || echo "N/A")
        rotational=$(cat "$device/queue/rotational" 2>/dev/null || echo "N/A")
        
        dev_type="HDD"
        [[ "$rotational" == "0" ]] && dev_type="SSD/NVMe"
        
        echo "   $dev_name ($dev_type): scheduler=$scheduler, read_ahead=${read_ahead}KB"
    fi
done
echo ""

# Network
echo "🌐 Network Configuration:"
echo "   TCP congestion control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'N/A')"
echo "   TCP Fast Open: $(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null || echo 'N/A')"
echo "   net.core.rmem_max: $(sysctl -n net.core.rmem_max 2>/dev/null || echo 'N/A')"
echo "   net.core.wmem_max: $(sysctl -n net.core.wmem_max 2>/dev/null || echo 'N/A')"
echo "   net.core.somaxconn: $(sysctl -n net.core.somaxconn 2>/dev/null || echo 'N/A')"
echo "   net.core.netdev_max_backlog: $(sysctl -n net.core.netdev_max_backlog 2>/dev/null || echo 'N/A')"
echo ""

# Show module statuses
echo "=========================================="
echo "📦 Module Status"
echo "=========================================="
echo ""

success_count=0
failed_count=0
skipped_count=0

for state_file in "$STATE_DIR/$LATEST_RUN"/*.json; do
    if [[ ! -f "$state_file" ]] || [[ "$(basename "$state_file")" == "run.json" ]]; then
        continue
    fi
    
    module_id=$(basename "$state_file" .json)
    
    if command -v jq &>/dev/null; then
        status=$(jq -r '.status' "$state_file" 2>/dev/null || echo "unknown")
    else
        status=$(grep '"status"' "$state_file" | cut -d'"' -f4)
    fi
    
    case "$status" in
        success)
            echo "   ✅ $module_id"
            ((success_count++))
            ;;
        failed)
            echo "   ❌ $module_id"
            ((failed_count++))
            ;;
        skipped)
            echo "   ⊘  $module_id"
            ((skipped_count++))
            ;;
        *)
            echo "   ❓ $module_id (status: $status)"
            ;;
    esac
done

echo ""
echo "📊 Summary:"
echo "   ✅ Success: $success_count"
echo "   ❌ Failed: $failed_count"
echo "   ⊘  Skipped: $skipped_count"
echo ""

# Check if reboot needed
echo "=========================================="
echo "🔄 Reboot Status"
echo "=========================================="
echo ""

# Check if reboot required
if [[ -f /var/run/reboot-required ]]; then
    echo "   ⚠️  REBOOT REQUIRED"
    echo "   Some changes require a reboot to take full effect."
    echo ""
    echo "   Reboot now: sudo reboot"
else
    # Check last reboot time vs optimization time
    if command -v jq &>/dev/null; then
        opt_time=$(jq -r '.timestamp' "$STATE_DIR/$LATEST_RUN/run.json" 2>/dev/null)
        boot_time=$(who -b | awk '{print $3" "$4}')
        
        echo "   Last boot: $boot_time"
        echo "   Last optimization: $opt_time"
        echo ""
        echo "   ℹ️  A reboot is RECOMMENDED to ensure all changes take effect"
    fi
fi

echo ""
echo "=========================================="
echo "📝 Additional Commands"
echo "=========================================="
echo ""
echo "   Benchmark performance:"
echo "      sudo make benchmark"
echo ""
echo "   Rollback changes:"
echo "      sudo make rollback"
echo ""
echo "   View logs:"
echo "      tail -100 /var/log/ubuntu-ultra-opt/ubuntu-ultra-opt.log"
echo ""
echo "   Re-apply optimizations:"
echo "      sudo make server          # Or db, lowlatency, desktop"
echo ""

echo ""
echo "=========================================="
echo "✅ Verification Complete"
echo "=========================================="
