#!/bin/bash
# core/log/metrics.sh
# Metrics collection and comparison for before/after optimization

# Collect system metrics snapshot
ultra_metrics_collect() {
    local snapshot_name="${1:-default}"
    local output_file="${2:-/tmp/ultra-metrics-${snapshot_name}.json}"
    
    ultra_log_debug "Collecting metrics snapshot: $snapshot_name"
    
    # Initialize metrics JSON
    cat > "$output_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "snapshot": "$snapshot_name",
  "system": {
EOF
    
    # System info
    echo '    "hostname": "'$(hostname)'",
    "kernel": "'$(uname -r)'",
    "uptime_seconds": '$(awk '{print int($1)}' /proc/uptime)',
    "load_average": "'$(uptime | grep -oP 'load average: \K.*')'",
    "cpu_count": '$(nproc)',
    "total_memory_gb": '$(ultra_get_total_ram_gb) >> "$output_file"
    
    # CPU metrics
    echo '  },
  "cpu": {
    "model": "'$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)'",
    "governor": "'$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")'",
    "current_mhz": '$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{print int($4)}')',
    "context_switches": '$(grep "^ctxt" /proc/stat | awk '{print $2}')' >> "$output_file"
    
    # Memory metrics
    local mem_total=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')
    local mem_free=$(grep "^MemFree:" /proc/meminfo | awk '{print $2}')
    local mem_available=$(grep "^MemAvailable:" /proc/meminfo | awk '{print $2}')
    local mem_cached=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
    local swap_total=$(grep "^SwapTotal:" /proc/meminfo | awk '{print $2}')
    local swap_free=$(grep "^SwapFree:" /proc/meminfo | awk '{print $2}')
    
    echo '  },
  "memory": {
    "total_kb": '$mem_total',
    "free_kb": '$mem_free',
    "available_kb": '$mem_available',
    "cached_kb": '$mem_cached',
    "swap_total_kb": '$swap_total',
    "swap_free_kb": '$swap_free',
    "swap_used_kb": '$(($swap_total - $swap_free))' >> "$output_file"
    
    # Disk I/O metrics
    echo '  },
  "disk": {' >> "$output_file"
    
    local first_disk=1
    for dev in $(lsblk -d -n -o NAME 2>/dev/null | grep -v "loop\|ram" | head -3); do
        [[ $first_disk -eq 0 ]] && echo ',' >> "$output_file"
        first_disk=0
        
        local reads=$(cat /sys/block/$dev/stat | awk '{print $1}')
        local writes=$(cat /sys/block/$dev/stat | awk '{print $5}')
        
        echo "    \"$dev\": {
      \"reads\": $reads,
      \"writes\": $writes
    }" >> "$output_file"
    done
    
    # Network metrics
    echo '  },
  "network": {' >> "$output_file"
    
    local first_net=1
    for iface in $(ip link show | grep -E '^[0-9]+: ' | grep -v 'lo:' | awk -F': ' '{print $2}' | head -3); do
        [[ $first_net -eq 0 ]] && echo ',' >> "$output_file"
        first_net=0
        
        local rx_bytes=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
        local tx_bytes=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
        local rx_packets=$(cat /sys/class/net/$iface/statistics/rx_packets 2>/dev/null || echo 0)
        local tx_packets=$(cat /sys/class/net/$iface/statistics/tx_packets 2>/dev/null || echo 0)
        
        echo "    \"$iface\": {
      \"rx_bytes\": $rx_bytes,
      \"tx_bytes\": $tx_bytes,
      \"rx_packets\": $rx_packets,
      \"tx_packets\": $tx_packets
    }" >> "$output_file"
    done
    
    # VM stats
    echo '  },
  "vm": {
    "swappiness": '$(cat /proc/sys/vm/swappiness)',
    "dirty_ratio": '$(cat /proc/sys/vm/dirty_ratio)',
    "dirty_background_ratio": '$(cat /proc/sys/vm/dirty_background_ratio)',
    "vfs_cache_pressure": '$(cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null || echo 100)',
    "nr_hugepages": '$(cat /proc/sys/vm/nr_hugepages 2>/dev/null || echo 0)',
    "overcommit_memory": '$(cat /proc/sys/vm/overcommit_memory)' >> "$output_file"
    
    # TCP stats
    echo '  },
  "tcp": {
    "active_connections": '$(ss -ant | grep -c ESTAB)',
    "time_wait": '$(ss -ant | grep -c TIME-WAIT)',
    "rmem": "'$(cat /proc/sys/net/ipv4/tcp_rmem)'",
    "wmem": "'$(cat /proc/sys/net/ipv4/tcp_wmem)'",
    "congestion_control": "'$(cat /proc/sys/net/ipv4/tcp_congestion_control)'"' >> "$output_file"
    
    # Close JSON
    echo '  }
}' >> "$output_file"
    
    ultra_log_info "Metrics collected: $output_file"
    echo "$output_file"
}

# Compare two metric snapshots
ultra_metrics_compare() {
    local before_file="$1"
    local after_file="$2"
    local output_file="${3:-/tmp/ultra-metrics-comparison.txt}"
    
    if [[ ! -f "$before_file" ]] || [[ ! -f "$after_file" ]]; then
        ultra_log_error "Metrics files not found"
        return 1
    fi
    
    ultra_log_info "Comparing metrics: before vs after"
    
    {
        echo "=========================================="
        echo "Ubuntu Ultra Optimizer - Metrics Comparison"
        echo "=========================================="
        echo ""
        echo "Before: $(jq -r '.timestamp // "unknown"' "$before_file" 2>/dev/null || echo "unknown")"
        echo "After:  $(jq -r '.timestamp // "unknown"' "$after_file" 2>/dev/null || echo "unknown")"
        echo ""
        
        # Memory comparison
        echo "Memory:"
        local mem_before=$(jq -r '.memory.available_kb // 0' "$before_file" 2>/dev/null || echo 0)
        local mem_after=$(jq -r '.memory.available_kb // 0' "$after_file" 2>/dev/null || echo 0)
        echo "  Available: $(($mem_before / 1024))MB → $(($mem_after / 1024))MB"
        
        local swap_before=$(jq -r '.memory.swap_used_kb // 0' "$before_file" 2>/dev/null || echo 0)
        local swap_after=$(jq -r '.memory.swap_used_kb // 0' "$after_file" 2>/dev/null || echo 0)
        echo "  Swap Used: $(($swap_before / 1024))MB → $(($swap_after / 1024))MB"
        
        # VM settings
        echo ""
        echo "VM Settings:"
        echo "  Swappiness: $(jq -r '.vm.swappiness // 0' "$before_file") → $(jq -r '.vm.swappiness // 0' "$after_file")"
        echo "  Dirty Ratio: $(jq -r '.vm.dirty_ratio // 0' "$before_file") → $(jq -r '.vm.dirty_ratio // 0' "$after_file")"
        echo "  VFS Cache Pressure: $(jq -r '.vm.vfs_cache_pressure // 0' "$before_file") → $(jq -r '.vm.vfs_cache_pressure // 0' "$after_file")"
        
        # CPU
        echo ""
        echo "CPU:"
        echo "  Governor: $(jq -r '.cpu.governor // "unknown"' "$before_file") → $(jq -r '.cpu.governor // "unknown"' "$after_file")"
        
        # TCP
        echo ""
        echo "TCP:"
        echo "  Active Connections: $(jq -r '.tcp.active_connections // 0' "$before_file") → $(jq -r '.tcp.active_connections // 0' "$after_file")"
        echo "  TIME_WAIT: $(jq -r '.tcp.time_wait // 0' "$before_file") → $(jq -r '.tcp.time_wait // 0' "$after_file")"
        echo "  Congestion Control: $(jq -r '.tcp.congestion_control // "unknown"' "$before_file") → $(jq -r '.tcp.congestion_control // "unknown"' "$after_file")"
        
        echo ""
        echo "=========================================="
    } > "$output_file"
    
    cat "$output_file"
    ultra_log_info "Comparison saved: $output_file"
}

# Display metrics summary
ultra_metrics_show() {
    local metrics_file="$1"
    
    if [[ ! -f "$metrics_file" ]]; then
        ultra_log_error "Metrics file not found: $metrics_file"
        return 1
    fi
    
    if ! command -v jq &>/dev/null; then
        ultra_log_warn "jq not installed, showing raw JSON"
        cat "$metrics_file"
        return 0
    fi
    
    echo "System Metrics Snapshot"
    echo "======================="
    echo ""
    echo "Timestamp: $(jq -r '.timestamp' "$metrics_file")"
    echo "Hostname: $(jq -r '.system.hostname' "$metrics_file")"
    echo "Kernel: $(jq -r '.system.kernel' "$metrics_file")"
    echo ""
    echo "CPU:"
    echo "  Model: $(jq -r '.cpu.model' "$metrics_file")"
    echo "  Count: $(jq -r '.system.cpu_count' "$metrics_file")"
    echo "  Governor: $(jq -r '.cpu.governor' "$metrics_file")"
    echo ""
    echo "Memory:"
    echo "  Total: $(jq -r '.system.total_memory_gb' "$metrics_file")GB"
    echo "  Available: $(jq -r '.memory.available_kb / 1024 | floor' "$metrics_file")MB"
    echo "  Cached: $(jq -r '.memory.cached_kb / 1024 | floor' "$metrics_file")MB"
    echo "  Swap Used: $(jq -r '.memory.swap_used_kb / 1024 | floor' "$metrics_file")MB"
    echo ""
    echo "VM:"
    echo "  Swappiness: $(jq -r '.vm.swappiness' "$metrics_file")"
    echo "  Dirty Ratio: $(jq -r '.vm.dirty_ratio' "$metrics_file")"
    echo "  VFS Cache Pressure: $(jq -r '.vm.vfs_cache_pressure' "$metrics_file")"
    echo ""
    echo "TCP:"
    echo "  Active: $(jq -r '.tcp.active_connections' "$metrics_file")"
    echo "  TIME_WAIT: $(jq -r '.tcp.time_wait' "$metrics_file")"
    echo "  CC Algorithm: $(jq -r '.tcp.congestion_control' "$metrics_file")"
}

# Save metrics to state directory
ultra_metrics_save_to_state() {
    local snapshot_name="$1"
    local run_id="${2:-$ULTRA_RUN_ID}"
    
    if [[ -z "$run_id" ]]; then
        ultra_log_error "No RUN_ID provided"
        return 1
    fi
    
    local state_dir="/var/lib/ubuntu-ultra-opt/state/$run_id"
    local metrics_file="$state_dir/metrics-${snapshot_name}.json"
    
    mkdir -p "$state_dir"
    ultra_metrics_collect "$snapshot_name" "$metrics_file"
    
    ultra_log_info "Metrics saved to state: $metrics_file"
}

# Load and compare metrics from state
ultra_metrics_compare_from_state() {
    local run_id="${1:-$ULTRA_RUN_ID}"
    
    if [[ -z "$run_id" ]]; then
        ultra_log_error "No RUN_ID provided"
        return 1
    fi
    
    local state_dir="/var/lib/ubuntu-ultra-opt/state/$run_id"
    local before_file="$state_dir/metrics-before.json"
    local after_file="$state_dir/metrics-after.json"
    local comparison_file="$state_dir/metrics-comparison.txt"
    
    if [[ -f "$before_file" ]] && [[ -f "$after_file" ]]; then
        ultra_metrics_compare "$before_file" "$after_file" "$comparison_file"
    else
        ultra_log_warn "Before/after metrics not found in state"
        return 1
    fi
}
