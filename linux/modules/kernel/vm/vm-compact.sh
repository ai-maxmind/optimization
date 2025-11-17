#!/bin/bash
# modules/kernel/vm/vm-compact.sh
# Module: Memory compaction tuning
# Reduces memory fragmentation for better THP allocation

MOD_ID="kernel.vm.compact"
MOD_DESC="Memory compaction"
MOD_STAGE="kernel-vm"
MOD_RISK="low"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Check if compaction controls exist
    if [[ ! -f /proc/sys/vm/compact_unevictable_allowed ]]; then
        ultra_log_debug "Memory compaction not supported by kernel"
        return 1
    fi
    return 0
}

mod_apply() {
    ultra_log_module_start "$MOD_ID"
    ultra_log_info "Applying memory compaction optimization..."
    
    local profile=$(ultra_get_profile)
    local ram_gb=$(ultra_get_total_ram_gb)
    
    # Memory compaction parameters:
    # compact_unevictable_allowed: 0=skip unevictable pages, 1=compact them
    # extfrag_threshold: 0-1000, trigger for external fragmentation
    #   Higher = more aggressive compaction (more CPU usage)
    
    local compact_unevictable=1
    local extfrag_threshold=500
    
    case "$profile" in
        server|db)
            # More aggressive compaction for servers
            compact_unevictable=1
            extfrag_threshold=500
            ;;
        lowlatency)
            # Less aggressive to avoid latency spikes
            compact_unevictable=0
            extfrag_threshold=800
            ;;
        desktop)
            # Moderate compaction
            compact_unevictable=1
            extfrag_threshold=500
            ;;
        *)
            compact_unevictable=1
            extfrag_threshold=500
            ;;
    esac
    
    ultra_log_info "Memory compaction configuration:"
    ultra_log_info "  compact_unevictable_allowed: $compact_unevictable"
    ultra_log_info "  extfrag_threshold: $extfrag_threshold (0-1000)"
    ultra_log_info "  System RAM: ${ram_gb}GB"
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would configure memory compaction"
        ultra_state_finalize_module "$MOD_ID" "success"
        ultra_log_module_end "$MOD_ID"
        return 0
    fi
    
    # Apply sysctl settings
    ultra_apply_sysctl "vm.compact_unevictable_allowed" "$compact_unevictable" "$MOD_ID"
    
    if [[ -f /proc/sys/vm/extfrag_threshold ]]; then
        ultra_apply_sysctl "vm.extfrag_threshold" "$extfrag_threshold" "$MOD_ID"
    fi
    
    ultra_state_add_action "$MOD_ID" "sysctl" "Memory compaction configured"
    
    ultra_log_info ""
    ultra_log_info "Memory fragmentation monitoring:"
    ultra_log_info "  cat /proc/buddyinfo                    # Memory fragmentation info"
    ultra_log_info "  cat /proc/pagetypeinfo                 # Page allocation types"
    ultra_log_info "  echo 1 > /proc/sys/vm/compact_memory   # Manual compaction trigger"
    ultra_log_info "  cat /sys/kernel/debug/extfrag/extfrag_index  # Fragmentation index"
    
    ultra_state_finalize_module "$MOD_ID" "success"
    ultra_log_module_end "$MOD_ID"
}

mod_rollback() {
    local run_id="$1"
    
    ultra_log_info "Rolling back $MOD_DESC..."
    ultra_rollback_sysctl "vm.compact_unevictable_allowed" "$MOD_ID" "$run_id"
    ultra_rollback_sysctl "vm.extfrag_threshold" "$MOD_ID" "$run_id"
}

mod_verify() {
    ultra_log_info "Memory Compaction Configuration:"
    
    if [[ -f /proc/sys/vm/compact_unevictable_allowed ]]; then
        local compact=$(cat /proc/sys/vm/compact_unevictable_allowed)
        ultra_log_info "  compact_unevictable_allowed: $compact"
    fi
    
    if [[ -f /proc/sys/vm/extfrag_threshold ]]; then
        local threshold=$(cat /proc/sys/vm/extfrag_threshold)
        ultra_log_info "  extfrag_threshold: $threshold"
    fi
    
    ultra_log_info ""
    ultra_log_info "Memory fragmentation status (buddy info):"
    if [[ -f /proc/buddyinfo ]]; then
        head -3 /proc/buddyinfo
    fi
    
    ultra_log_info ""
    ultra_log_info "Compaction stats:"
    if [[ -f /proc/vmstat ]]; then
        grep -E "compact_|thp_" /proc/vmstat | head -10
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This module should be run through the orchestrator"
    exit 1
fi
