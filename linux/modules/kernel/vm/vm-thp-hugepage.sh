#!/bin/bash
################################################################################
# MODULE: kernel.vm.thp-hugepage
# Configure Transparent Huge Pages (THP) for optimal performance
################################################################################

MOD_ID="kernel.vm.thp-hugepage"
MOD_DESC="Configure Transparent Huge Pages based on workload"
MOD_STAGE="kernel-vm"
MOD_RISK="medium"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Check if THP is supported
    if [[ ! -d /sys/kernel/mm/transparent_hugepage ]]; then
        ultra_log_warn "Transparent Huge Pages not supported on this kernel"
        return 1
    fi
    return 0
}

mod_apply() {
    ultra_log_info "Applying $MOD_DESC"
    
    local profile=$(ultra_get_profile)
    local thp_enabled="madvise"
    local thp_defrag="defer+madvise"
    local thp_khugepaged_scan_sleep_ms=10000
    local thp_khugepaged_alloc_sleep_ms=60000
    
    # THP modes:
    # - always: Always use THP (can cause latency spikes)
    # - madvise: Only for madvise() regions (safe, opt-in)
    # - never: Disable THP
    
    case "$profile" in
        server|db)
            # Database workloads: madvise is safer
            # Some databases (like MongoDB, Redis) benefit from THP
            # Others (PostgreSQL) may prefer it disabled
            thp_enabled="madvise"
            thp_defrag="defer+madvise"  # Async defrag
            thp_khugepaged_scan_sleep_ms=10000
            ;;
        lowlatency)
            # Low latency: disable or use madvise only
            # THP compaction can cause latency spikes
            thp_enabled="madvise"
            thp_defrag="never"  # No defrag to avoid latency
            thp_khugepaged_scan_sleep_ms=60000  # Scan less frequently
            ;;
        desktop)
            # Desktop: madvise for compatibility
            thp_enabled="madvise"
            thp_defrag="madvise"
            thp_khugepaged_scan_sleep_ms=10000
            ;;
        *)
            thp_enabled="madvise"
            thp_defrag="madvise"
            ;;
    esac
    
    # Save current state
    if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
        local current_enabled=$(cat /sys/kernel/mm/transparent_hugepage/enabled | grep -oP '\[\K[^\]]+')
        ultra_state_save_module_before "$MOD_ID" "thp_enabled" "$current_enabled"
    fi
    
    if [[ -f /sys/kernel/mm/transparent_hugepage/defrag ]]; then
        local current_defrag=$(cat /sys/kernel/mm/transparent_hugepage/defrag | grep -oP '\[\K[^\]]+')
        ultra_state_save_module_before "$MOD_ID" "thp_defrag" "$current_defrag"
    fi
    
    # Apply settings
    if ! ultra_is_dry_run; then
        echo "$thp_enabled" > /sys/kernel/mm/transparent_hugepage/enabled
        echo "$thp_defrag" > /sys/kernel/mm/transparent_hugepage/defrag
        
        if [[ -f /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs ]]; then
            echo "$thp_khugepaged_scan_sleep_ms" > /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs
        fi
        
        if [[ -f /sys/kernel/mm/transparent_hugepage/khugepaged/alloc_sleep_millisecs ]]; then
            echo "$thp_khugepaged_alloc_sleep_ms" > /sys/kernel/mm/transparent_hugepage/khugepaged/alloc_sleep_millisecs
        fi
    else
        ultra_log_dry_run "Set THP enabled=$thp_enabled defrag=$thp_defrag"
    fi
    
    ultra_log_info "THP enabled: $thp_enabled"
    ultra_log_info "THP defrag: $thp_defrag"
    
    ultra_state_save_module_after "$MOD_ID" "thp_enabled" "$thp_enabled"
    ultra_state_save_module_after "$MOD_ID" "thp_defrag" "$thp_defrag"
    ultra_state_add_action "$MOD_ID" "sysctl" "Configured THP: enabled=$thp_enabled, defrag=$thp_defrag"
    
    # Configure related VM parameters
    ultra_sysctl_save_and_set "vm.compact_unevictable_allowed" "1" "$MOD_ID"
    ultra_sysctl_save_and_set "vm.compaction_proactiveness" "20" "$MOD_ID"
}

mod_rollback() {
    ultra_log_info "Rolling back $MOD_ID"
    
    local run_id="$1"
    local state_file="$ULTRA_STATE_DIR/$run_id/${MOD_ID}.json"
    
    if [[ -f "$state_file" ]] && command -v jq &>/dev/null; then
        local enabled_before=$(jq -r '.before["thp_enabled"]' "$state_file")
        local defrag_before=$(jq -r '.before["thp_defrag"]' "$state_file")
        
        if [[ "$enabled_before" != "null" ]] && [[ -n "$enabled_before" ]]; then
            echo "$enabled_before" > /sys/kernel/mm/transparent_hugepage/enabled
        fi
        
        if [[ "$defrag_before" != "null" ]] && [[ -n "$defrag_before" ]]; then
            echo "$defrag_before" > /sys/kernel/mm/transparent_hugepage/defrag
        fi
    fi
}

mod_verify() {
    if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
        local enabled=$(cat /sys/kernel/mm/transparent_hugepage/enabled)
        ultra_log_info "THP enabled: $enabled"
    fi
    
    if [[ -f /sys/kernel/mm/transparent_hugepage/defrag ]]; then
        local defrag=$(cat /sys/kernel/mm/transparent_hugepage/defrag)
        ultra_log_info "THP defrag: $defrag"
    fi
    
    # Show THP statistics
    if [[ -d /sys/kernel/mm/transparent_hugepage ]]; then
        ultra_log_info "THP statistics:"
        grep -r . /sys/kernel/mm/transparent_hugepage/*.pages 2>/dev/null | while IFS=: read -r file value; do
            ultra_log_info "  $(basename "$file"): $value"
        done
    fi
}
