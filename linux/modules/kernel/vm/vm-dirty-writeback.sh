#!/bin/bash
################################################################################
# MODULE: kernel.vm.dirty-writeback
# Optimize dirty page writeback for performance
################################################################################

MOD_ID="kernel.vm.dirty-writeback"
MOD_DESC="Optimize dirty page writeback based on storage type and profile"
MOD_STAGE="kernel-vm"
MOD_RISK="medium"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Always can run
    return 0
}

mod_apply() {
    ultra_log_info "Applying $MOD_DESC"
    
    local profile=$(ultra_get_profile)
    local has_ssd=false
    
    # Check if any SSD exists
    for device in $(ultra_hw_storage_get_devices); do
        if ultra_hw_storage_is_ssd "$device"; then
            has_ssd=true
            break
        fi
    done
    
    # Dirty page parameters:
    # - dirty_ratio: % of RAM that can be filled with dirty pages before blocking writes
    # - dirty_background_ratio: % when background writeback starts
    # - dirty_writeback_centisecs: interval between writeback wakeups (centiseconds)
    # - dirty_expire_centisecs: how old data must be before flushed
    
    local dirty_ratio=15
    local dirty_background_ratio=5
    local dirty_writeback_centisecs=500   # 5 seconds
    local dirty_expire_centisecs=3000     # 30 seconds
    
    if [[ "$has_ssd" == "true" ]]; then
        # SSD: More aggressive writeback (faster writes)
        case "$profile" in
            server|db)
                dirty_ratio=10
                dirty_background_ratio=3
                dirty_writeback_centisecs=300   # 3 seconds
                dirty_expire_centisecs=1500     # 15 seconds
                ;;
            lowlatency)
                # Ultra-aggressive: keep dirty pages minimal
                dirty_ratio=5
                dirty_background_ratio=2
                dirty_writeback_centisecs=100   # 1 second
                dirty_expire_centisecs=500      # 5 seconds
                ;;
            desktop)
                dirty_ratio=15
                dirty_background_ratio=5
                dirty_writeback_centisecs=500
                dirty_expire_centisecs=3000
                ;;
        esac
    else
        # HDD: Less aggressive (avoid excessive seeking)
        dirty_ratio=20
        dirty_background_ratio=10
        dirty_writeback_centisecs=1500   # 15 seconds
        dirty_expire_centisecs=6000      # 60 seconds
    fi
    
    ultra_log_info "Storage type: $([ "$has_ssd" == "true" ] && echo "SSD" || echo "HDD")"
    
    ultra_sysctl_save_and_set "vm.dirty_ratio" "$dirty_ratio" "$MOD_ID"
    ultra_sysctl_save_and_set "vm.dirty_background_ratio" "$dirty_background_ratio" "$MOD_ID"
    ultra_sysctl_save_and_set "vm.dirty_writeback_centisecs" "$dirty_writeback_centisecs" "$MOD_ID"
    ultra_sysctl_save_and_set "vm.dirty_expire_centisecs" "$dirty_expire_centisecs" "$MOD_ID"
    
    # Related: dirty_bytes and dirty_background_bytes (absolute limits)
    # For systems with lots of RAM, percentage-based limits can be too large
    local mem_gb=$(ultra_hw_mem_get_total_gb)
    if (( mem_gb >= 64 )); then
        # Cap dirty memory at reasonable absolute values
        # dirty_bytes: 4GB max
        # dirty_background_bytes: 1GB max
        ultra_sysctl_save_and_set "vm.dirty_bytes" "4294967296" "$MOD_ID"
        ultra_sysctl_save_and_set "vm.dirty_background_bytes" "1073741824" "$MOD_ID"
        ultra_log_info "Large RAM detected (${mem_gb}GB), using absolute dirty limits"
    fi
}

mod_rollback() {
    ultra_log_info "Rolling back $MOD_ID"
    
    local run_id="$1"
    local state_file="$ULTRA_STATE_DIR/$run_id/${MOD_ID}.json"
    
    if [[ -f "$state_file" ]] && command -v jq &>/dev/null; then
        for key in "vm.dirty_ratio" "vm.dirty_background_ratio" "vm.dirty_writeback_centisecs" "vm.dirty_expire_centisecs" "vm.dirty_bytes" "vm.dirty_background_bytes"; do
            local value=$(jq -r ".before[\"sysctl:$key\"]" "$state_file")
            if [[ "$value" != "null" ]] && [[ -n "$value" ]]; then
                ultra_sysctl_restore "$key" "$value" "$MOD_ID"
            fi
        done
    fi
}

mod_verify() {
    ultra_log_info "Dirty page writeback configuration:"
    ultra_log_info "  dirty_ratio: $(ultra_sysctl_get_current vm.dirty_ratio)%"
    ultra_log_info "  dirty_background_ratio: $(ultra_sysctl_get_current vm.dirty_background_ratio)%"
    ultra_log_info "  dirty_writeback_centisecs: $(ultra_sysctl_get_current vm.dirty_writeback_centisecs)"
    ultra_log_info "  dirty_expire_centisecs: $(ultra_sysctl_get_current vm.dirty_expire_centisecs)"
    
    local dirty_bytes=$(ultra_sysctl_get_current vm.dirty_bytes)
    if [[ -n "$dirty_bytes" ]] && [[ "$dirty_bytes" != "0" ]]; then
        ultra_log_info "  dirty_bytes: $((dirty_bytes / 1024 / 1024))MB"
    fi
}
