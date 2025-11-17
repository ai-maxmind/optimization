#!/bin/bash
################################################################################
# MODULE: kernel.vm.swappiness
# Tune vm.swappiness based on profile + RAM
################################################################################

MOD_ID="kernel.vm.swappiness"
MOD_DESC="Tune vm.swappiness based on profile and available RAM"
MOD_STAGE="kernel-vm"
MOD_RISK="low"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Always can run on any system
    return 0
}

mod_apply() {
    ultra_log_info "Applying $MOD_DESC"
    
    local profile=$(ultra_get_profile)
    local mem_gb=$(ultra_hw_mem_get_total_gb)
    local swappiness=10
    
    # Calculate optimal swappiness based on RAM and profile
    # More RAM = less swappiness needed
    # Server profiles = less swappiness
    # Desktop = more swappiness for responsiveness
    
    case "$profile" in
        server|db)
            if (( mem_gb >= 64 )); then
                swappiness=1
            elif (( mem_gb >= 32 )); then
                swappiness=5
            elif (( mem_gb >= 16 )); then
                swappiness=10
            else
                swappiness=20
            fi
            ;;
        lowlatency)
            # Ultra-low swappiness for latency-sensitive workloads
            swappiness=1
            ;;
        desktop)
            # Desktop needs some swap for hibernation and responsiveness
            if (( mem_gb >= 16 )); then
                swappiness=10
            else
                swappiness=30
            fi
            ;;
        *)
            swappiness=10
            ;;
    esac
    
    ultra_log_info "Setting vm.swappiness = $swappiness (RAM: ${mem_gb}GB, Profile: $profile)"
    ultra_sysctl_save_and_set "vm.swappiness" "$swappiness" "$MOD_ID"
    
    # Related: vfs_cache_pressure
    # Lower value = kernel prefers to retain dentry and inode caches
    local cache_pressure=50
    if [[ "$profile" == "db" ]] || [[ "$profile" == "server" ]]; then
        cache_pressure=50
    elif [[ "$profile" == "lowlatency" ]]; then
        cache_pressure=30
    else
        cache_pressure=100  # default
    fi
    
    ultra_log_info "Setting vm.vfs_cache_pressure = $cache_pressure"
    ultra_sysctl_save_and_set "vm.vfs_cache_pressure" "$cache_pressure" "$MOD_ID"
}

mod_rollback() {
    ultra_log_info "Rolling back $MOD_ID"
    
    # Read before state and restore
    local run_id="$1"
    local state_file="$ULTRA_STATE_DIR/$run_id/${MOD_ID}.json"
    
    if [[ -f "$state_file" ]] && command -v jq &>/dev/null; then
        local swappiness_before=$(jq -r '.before["sysctl:vm.swappiness"]' "$state_file")
        local cache_pressure_before=$(jq -r '.before["sysctl:vm.vfs_cache_pressure"]' "$state_file")
        
        if [[ "$swappiness_before" != "null" ]] && [[ -n "$swappiness_before" ]]; then
            ultra_sysctl_restore "vm.swappiness" "$swappiness_before" "$MOD_ID"
        fi
        
        if [[ "$cache_pressure_before" != "null" ]] && [[ -n "$cache_pressure_before" ]]; then
            ultra_sysctl_restore "vm.vfs_cache_pressure" "$cache_pressure_before" "$MOD_ID"
        fi
    fi
}

mod_verify() {
    local swappiness=$(ultra_sysctl_get_current "vm.swappiness")
    local cache_pressure=$(ultra_sysctl_get_current "vm.vfs_cache_pressure")
    
    ultra_log_info "Current vm.swappiness: $swappiness"
    ultra_log_info "Current vm.vfs_cache_pressure: $cache_pressure"
}
