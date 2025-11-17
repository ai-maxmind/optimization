#!/bin/bash
################################################################################
# MODULE: kernel.sched.numa-balance
# Configure NUMA balancing for multi-socket systems
################################################################################

MOD_ID="kernel.sched.numa-balance"
MOD_DESC="Configure NUMA balancing and memory policies"
MOD_STAGE="kernel-sched"
MOD_RISK="low"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Check if NUMA is available
    if ! ultra_hw_mem_has_numa; then
        ultra_log_debug "NUMA not detected, skipping"
        return 1
    fi
    
    local numa_nodes=$(ultra_hw_mem_get_numa_nodes)
    if (( numa_nodes < 2 )); then
        ultra_log_debug "Single NUMA node, skipping"
        return 1
    fi
    
    return 0
}

mod_apply() {
    ultra_log_info "Applying $MOD_DESC"
    
    local numa_nodes=$(ultra_hw_mem_get_numa_nodes)
    local profile=$(ultra_get_profile)
    
    ultra_log_info "NUMA configuration: $numa_nodes nodes detected"
    
    # NUMA balancing modes:
    # 0 = disabled
    # 1 = enabled (automatic page migration)
    
    local numa_balancing=1
    local numa_scan_delay_ms=1000
    local numa_scan_period_min_ms=1000
    local numa_scan_period_max_ms=60000
    local numa_scan_size_mb=256
    
    case "$profile" in
        server|db)
            # Enable NUMA balancing for multi-socket servers
            numa_balancing=1
            numa_scan_delay_ms=1000
            numa_scan_period_min_ms=1000
            numa_scan_period_max_ms=60000
            numa_scan_size_mb=256
            ;;
        lowlatency)
            # Disable NUMA balancing to avoid migration overhead
            numa_balancing=0
            ultra_log_info "Disabling NUMA balancing for consistent latency"
            ;;
        desktop)
            # Enable with conservative settings
            numa_balancing=1
            numa_scan_delay_ms=2000
            numa_scan_period_min_ms=2000
            numa_scan_period_max_ms=120000
            ;;
    esac
    
    # kernel.numa_balancing
    ultra_sysctl_save_and_set "kernel.numa_balancing" "$numa_balancing" "$MOD_ID"
    
    if [[ "$numa_balancing" == "1" ]]; then
        # Fine-tune NUMA balancing parameters
        ultra_sysctl_save_and_set "kernel.numa_balancing_scan_delay_ms" "$numa_scan_delay_ms" "$MOD_ID"
        ultra_sysctl_save_and_set "kernel.numa_balancing_scan_period_min_ms" "$numa_scan_period_min_ms" "$MOD_ID"
        ultra_sysctl_save_and_set "kernel.numa_balancing_scan_period_max_ms" "$numa_scan_period_max_ms" "$MOD_ID"
        ultra_sysctl_save_and_set "kernel.numa_balancing_scan_size_mb" "$numa_scan_size_mb" "$MOD_ID"
        
        ultra_log_info "NUMA balancing enabled with scan period ${numa_scan_period_min_ms}-${numa_scan_period_max_ms}ms"
    fi
    
    # zone_reclaim_mode: control when to reclaim from remote nodes
    # 0 = always allocate from remote nodes if local full
    # 1 = reclaim local before going remote (can cause latency)
    local zone_reclaim_mode=0
    if [[ "$profile" == "db" ]]; then
        # Database might benefit from local reclaim to avoid remote access
        zone_reclaim_mode=0  # Actually, usually 0 is better even for DB
    fi
    
    ultra_sysctl_save_and_set "vm.zone_reclaim_mode" "$zone_reclaim_mode" "$MOD_ID"
    
    # Show NUMA topology
    ultra_log_info "NUMA Topology:"
    if command -v numactl &>/dev/null; then
        numactl --hardware | while IFS= read -r line; do
            ultra_log_info "  $line"
        done
    else
        ultra_log_info "  (install numactl for detailed topology)"
        for node in /sys/devices/system/node/node*; do
            if [[ -d "$node" ]]; then
                local node_num=$(basename "$node" | sed 's/node//')
                local node_mem=$(cat "$node/meminfo" | grep MemTotal | awk '{print $4}')
                ultra_log_info "  Node $node_num: ${node_mem}KB"
            fi
        done
    fi
}

mod_rollback() {
    ultra_log_info "Rolling back $MOD_ID"
    
    local run_id="$1"
    local state_file="$ULTRA_STATE_DIR/$run_id/${MOD_ID}.json"
    
    if [[ -f "$state_file" ]] && command -v jq &>/dev/null; then
        local keys=(
            "kernel.numa_balancing"
            "kernel.numa_balancing_scan_delay_ms"
            "kernel.numa_balancing_scan_period_min_ms"
            "kernel.numa_balancing_scan_period_max_ms"
            "kernel.numa_balancing_scan_size_mb"
            "vm.zone_reclaim_mode"
        )
        
        for key in "${keys[@]}"; do
            local value=$(jq -r ".before[\"sysctl:$key\"]" "$state_file")
            if [[ "$value" != "null" ]] && [[ -n "$value" ]]; then
                ultra_sysctl_restore "$key" "$value" "$MOD_ID"
            fi
        done
    fi
}

mod_verify() {
    ultra_log_info "NUMA configuration:"
    ultra_log_info "  numa_balancing: $(ultra_sysctl_get_current kernel.numa_balancing)"
    ultra_log_info "  zone_reclaim_mode: $(ultra_sysctl_get_current vm.zone_reclaim_mode)"
    
    local numa_balancing=$(ultra_sysctl_get_current kernel.numa_balancing)
    if [[ "$numa_balancing" == "1" ]]; then
        ultra_log_info "  scan_delay_ms: $(ultra_sysctl_get_current kernel.numa_balancing_scan_delay_ms)"
        ultra_log_info "  scan_period_min_ms: $(ultra_sysctl_get_current kernel.numa_balancing_scan_period_min_ms)"
        ultra_log_info "  scan_period_max_ms: $(ultra_sysctl_get_current kernel.numa_balancing_scan_period_max_ms)"
    fi
    
    # Show NUMA stats
    if [[ -f /proc/vmstat ]]; then
        ultra_log_info "NUMA statistics:"
        grep "numa_" /proc/vmstat | head -10 | while IFS= read -r line; do
            ultra_log_info "  $line"
        done
    fi
}
