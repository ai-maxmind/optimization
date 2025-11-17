#!/bin/bash
# modules/kernel/vm/vm-cache-pressure.sh
# Module: VFS cache pressure tuning
# Controls the tendency of kernel to reclaim inode/dentry cache vs page cache

MOD_ID="kernel.vm.cache-pressure"
MOD_DESC="VFS cache pressure tuning"
MOD_STAGE="kernel-vm"
MOD_RISK="low"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Always safe to tune cache pressure
    return 0
}

mod_apply() {
    ultra_log_module_start "$MOD_ID"
    ultra_log_info "Applying VFS cache pressure optimization..."
    
    local profile=$(ultra_get_profile)
    local ram_gb=$(ultra_hw_mem_get_total_gb 2>/dev/null || echo "8")
    
    # Determine cache pressure based on profile and RAM
    # Default: 100 (balanced)
    # Lower values = keep dentry/inode cache longer (better for file-heavy workloads)
    # Higher values = reclaim dentry/inode cache more aggressively (free more RAM)
    local cache_pressure=100
    
    case "$profile" in
        server)
            # Servers typically benefit from keeping inode/dentry cache
            # More file operations, less memory pressure
            cache_pressure=50
            ;;
        db)
            # Databases want maximum RAM for data cache
            # Aggressively reclaim filesystem cache
            if [[ "$ram_gb" -ge 32 ]]; then
                cache_pressure=150
            else
                cache_pressure=200
            fi
            ;;
        lowlatency)
            # Balance: keep some cache but not too much
            cache_pressure=75
            ;;
        desktop)
            # Desktop users access many files, keep cache
            cache_pressure=50
            ;;
        *)
            cache_pressure=100
            ;;
    esac
    
    # Adjust based on RAM
    if [[ "$ram_gb" -ge 64 ]]; then
        # With lots of RAM, can afford to keep cache
        cache_pressure=$((cache_pressure - 25))
    elif [[ "$ram_gb" -le 8 ]]; then
        # Low RAM, more aggressive reclaim
        cache_pressure=$((cache_pressure + 25))
    fi
    
    # Clamp to reasonable range (25-250)
    [[ "$cache_pressure" -lt 25 ]] && cache_pressure=25
    [[ "$cache_pressure" -gt 250 ]] && cache_pressure=250
    
    ultra_log_info "Setting vfs_cache_pressure=$cache_pressure (profile=$profile, RAM=${ram_gb}GB)"
    
    if ! ultra_is_dry_run; then
        ultra_sysctl_save_and_set "vm.vfs_cache_pressure" "$cache_pressure" "$MOD_ID"
        ultra_state_add_action "$MOD_ID" "sysctl" "Set vm.vfs_cache_pressure=$cache_pressure"
    else
        ultra_log_info "[DRY-RUN] Would set vm.vfs_cache_pressure=$cache_pressure"
    fi
    
    # Also tune dentry and inode cache parameters if needed
    # These are auto-tuned by kernel but we can suggest ranges
    if [[ "$profile" == "server" ]] || [[ "$profile" == "desktop" ]]; then
        ultra_log_info "For file-heavy workloads, consider these tunings:"
        ultra_log_info "  - Increase fs.inode-max (default: dynamic)"
        ultra_log_info "  - Increase fs.dentry-state thresholds"
        ultra_log_info "Current dentry state: $(cat /proc/sys/fs/dentry-state 2>/dev/null | head -1)"
    fi
    
    ultra_state_finalize_module "$MOD_ID" "success"
    ultra_log_module_end "$MOD_ID"
}

mod_rollback() {
    local run_id="$1"
    local state_file="$ULTRA_STATE_DIR/$run_id/${MOD_ID}.json"
    
    ultra_log_info "Rolling back $MOD_DESC..."
    
    if [[ -f "$state_file" ]] && command -v jq &>/dev/null; then
        local value=$(jq -r '.before["sysctl:vm.vfs_cache_pressure"]' "$state_file" 2>/dev/null)
        if [[ -n "$value" ]] && [[ "$value" != "null" ]]; then
            ultra_log_info "Restoring vm.vfs_cache_pressure=$value"
            ultra_sysctl_restore "vm.vfs_cache_pressure" "$value" "$MOD_ID"
        fi
    else
        ultra_log_warn "No state file found, restoring to default (100)"
        sysctl -w vm.vfs_cache_pressure=100 &>/dev/null
        sed -i '/vfs_cache_pressure/d' /etc/sysctl.d/99-ultra-opt-*.conf 2>/dev/null
    fi
}

mod_verify() {
    local current=$(ultra_sysctl_get_current "vm.vfs_cache_pressure")
    ultra_log_info "Current vm.vfs_cache_pressure: $current"
    
    # Show cache statistics
    if [[ -f /proc/sys/fs/dentry-state ]]; then
        local dentry_stats=$(cat /proc/sys/fs/dentry-state)
        ultra_log_info "Dentry cache stats: $dentry_stats"
    fi
    
    if [[ -f /proc/sys/fs/inode-state ]]; then
        local inode_stats=$(cat /proc/sys/fs/inode-state)
        ultra_log_info "Inode cache stats: $inode_stats"
    fi
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This module should be run through the orchestrator"
    echo "Usage: ./orchestrator/cli.sh --module $MOD_ID"
    exit 1
fi
