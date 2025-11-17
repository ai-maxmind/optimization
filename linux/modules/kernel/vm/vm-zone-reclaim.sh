#!/bin/bash
# modules/kernel/vm/vm-zone-reclaim.sh
# Module: NUMA zone reclaim mode configuration
# Controls whether kernel reclaims memory from remote NUMA nodes

MOD_ID="kernel.vm.zone-reclaim"
MOD_DESC="NUMA zone reclaim mode"
MOD_STAGE="kernel-vm"
MOD_RISK="medium"
MOD_DEFAULT_ENABLED="false"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Check if NUMA is available
    if ! command -v numactl &>/dev/null; then
        ultra_log_debug "numactl not available"
        return 1
    fi
    
    # Check if system has multiple NUMA nodes
    local numa_nodes=$(numactl -H 2>/dev/null | grep "available:" | awk '{print $2}')
    if [[ -z "$numa_nodes" ]] || [[ "$numa_nodes" -lt 2 ]]; then
        ultra_log_debug "Single NUMA node system, zone reclaim not needed"
        return 1
    fi
    
    return 0
}

mod_apply() {
    ultra_log_module_start "$MOD_ID"
    ultra_log_info "Applying NUMA zone reclaim optimization..."
    
    local profile=$(ultra_get_profile)
    
    # Zone reclaim mode values:
    # 0 = Disable zone reclaim (default) - allocate from remote nodes
    # 1 = Enable zone reclaim - reclaim local pages first
    # 2 = Write dirty pages to reclaim
    # 4 = Swap pages to reclaim
    # Combine: 1+2=3, 1+4=5, 1+2+4=7
    
    local reclaim_mode=0
    local zone_description=""
    
    case "$profile" in
        server)
            # Remote allocation is usually faster than reclaim
            reclaim_mode=0
            zone_description="Disabled (prefer remote allocation)"
            ;;
        db)
            # Databases benefit from local memory
            reclaim_mode=1
            zone_description="Basic reclaim (local preferred)"
            ;;
        lowlatency)
            # Low-latency: keep memory local to reduce NUMA latency
            reclaim_mode=1
            zone_description="Basic reclaim (minimize NUMA latency)"
            ;;
        desktop)
            # Desktop: default (disabled)
            reclaim_mode=0
            zone_description="Disabled (default)"
            ;;
        *)
            reclaim_mode=0
            zone_description="Disabled (default)"
            ;;
    esac
    
    # Get NUMA info
    local numa_nodes=$(numactl -H 2>/dev/null | grep "available:" | awk '{print $2}')
    local numa_cpus=$(numactl -H 2>/dev/null | grep "node.*cpus:" | wc -l)
    
    ultra_log_info "NUMA configuration:"
    ultra_log_info "  NUMA nodes: $numa_nodes"
    ultra_log_info "  CPUs per node: ~$(($(nproc) / numa_nodes))"
    
    ultra_log_info ""
    ultra_log_info "Zone reclaim mode: $reclaim_mode"
    ultra_log_info "  Description: $zone_description"
    ultra_log_info "  0 = Allocate from remote nodes (fastest)"
    ultra_log_info "  1 = Reclaim local pages first"
    ultra_log_info "  2 = Write dirty pages during reclaim"
    ultra_log_info "  4 = Swap pages during reclaim"
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would set vm.zone_reclaim_mode=$reclaim_mode"
        ultra_state_finalize_module "$MOD_ID" "success"
        ultra_log_module_end "$MOD_ID"
        return 0
    fi
    
    # Apply sysctl
    ultra_apply_sysctl "vm.zone_reclaim_mode" "$reclaim_mode" "$MOD_ID"
    
    ultra_state_add_action "$MOD_ID" "sysctl" "vm.zone_reclaim_mode=$reclaim_mode"
    
    ultra_log_info ""
    ultra_log_info "NUMA best practices:"
    ultra_log_info "  1. Check NUMA topology: numactl -H"
    ultra_log_info "  2. Monitor NUMA stats: numastat"
    ultra_log_info "  3. Pin processes to NUMA nodes: numactl --cpunodebind=0 --membind=0 <cmd>"
    ultra_log_info "  4. Check NUMA balancing: cat /proc/sys/kernel/numa_balancing"
    ultra_log_info "  5. Monitor remote vs local allocations: cat /sys/devices/system/node/node*/numastat"
    
    ultra_state_finalize_module "$MOD_ID" "success"
    ultra_log_module_end "$MOD_ID"
}

mod_rollback() {
    local run_id="$1"
    
    ultra_log_info "Rolling back $MOD_DESC..."
    ultra_rollback_sysctl "vm.zone_reclaim_mode" "$MOD_ID" "$run_id"
}

mod_verify() {
    ultra_log_info "NUMA Zone Reclaim Configuration:"
    
    if [[ -f /proc/sys/vm/zone_reclaim_mode ]]; then
        local current=$(cat /proc/sys/vm/zone_reclaim_mode)
        ultra_log_info "  Current: $current"
        
        case "$current" in
            0) ultra_log_info "  Mode: Disabled (allocate from remote nodes)" ;;
            1) ultra_log_info "  Mode: Basic reclaim (local preferred)" ;;
            2) ultra_log_info "  Mode: Write dirty pages during reclaim" ;;
            4) ultra_log_info "  Mode: Swap pages during reclaim" ;;
            *) ultra_log_info "  Mode: Combined flags ($current)" ;;
        esac
    fi
    
    ultra_log_info ""
    ultra_log_info "NUMA topology:"
    if command -v numactl &>/dev/null; then
        numactl -H 2>/dev/null | head -10
    fi
    
    ultra_log_info ""
    ultra_log_info "NUMA statistics (first node):"
    if [[ -d /sys/devices/system/node/node0 ]]; then
        cat /sys/devices/system/node/node0/numastat 2>/dev/null | head -5
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This module should be run through the orchestrator"
    exit 1
fi
