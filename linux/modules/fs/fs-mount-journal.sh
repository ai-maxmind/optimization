#!/bin/bash
# modules/fs/fs-mount-journal.sh
# Module: Journal commit interval tuning
# Optimizes ext4/XFS journal commit frequency for performance

MOD_ID="fs.mount-journal"
MOD_DESC="Journal commit interval tuning"
MOD_STAGE="fs"
MOD_RISK="low"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Check if we have ext4 or XFS filesystems
    if ! mount | grep -E "ext4|xfs" &>/dev/null; then
        ultra_log_debug "No ext4/XFS filesystems found"
        return 1
    fi
    return 0
}

mod_apply() {
    ultra_log_module_start "$MOD_ID"
    ultra_log_info "Applying journal commit interval optimization..."
    
    local profile=$(ultra_get_profile)
    
    # Journal commit interval trade-off:
    # Lower = safer but more I/O overhead
    # Higher = better performance but more data loss risk on crash
    
    # Default ext4: commit=5 (seconds)
    # We'll recommend commit=30 for better performance
    
    local commit_interval=30
    
    case "$profile" in
        server)
            commit_interval=30
            ;;
        db)
            # Databases have their own journaling, can be more aggressive
            commit_interval=60
            ;;
        lowlatency)
            # Reduce journal overhead
            commit_interval=60
            ;;
        desktop)
            # More conservative for desktop
            commit_interval=15
            ;;
    esac
    
    ultra_log_info "Analyzing mounted filesystems..."
    ultra_log_info "Recommended journal commit interval: ${commit_interval}s"
    ultra_log_info ""
    
    # Analyze current mounts
    local found_fs=0
    while read -r line; do
        if [[ "$line" =~ ^/dev ]] || [[ "$line" =~ ^UUID ]]; then
            local device=$(echo "$line" | awk '{print $1}')
            local mount_point=$(echo "$line" | awk '{print $2}')
            local fstype=$(echo "$line" | awk '{print $3}')
            local options=$(echo "$line" | awk '{print $4}')
            
            if [[ "$fstype" == "ext4" ]] || [[ "$fstype" == "xfs" ]]; then
                found_fs=1
                ultra_log_info "Found $fstype: $mount_point"
                
                if [[ "$fstype" == "ext4" ]]; then
                    if echo "$options" | grep -q "commit="; then
                        local current=$(echo "$options" | grep -oP 'commit=\K[0-9]+')
                        ultra_log_info "  Current: commit=$current"
                    else
                        ultra_log_info "  Current: commit=5 (default)"
                    fi
                    ultra_log_info "  Recommend: commit=$commit_interval"
                    
                elif [[ "$fstype" == "xfs" ]]; then
                    if echo "$options" | grep -q "logbufs="; then
                        local logbufs=$(echo "$options" | grep -oP 'logbufs=\K[0-9]+')
                        ultra_log_info "  Current: logbufs=$logbufs"
                    fi
                    ultra_log_info "  Recommend: logbufs=8,logbsize=256k"
                fi
            fi
        fi
    done < /proc/mounts
    
    if [[ "$found_fs" -eq 0 ]]; then
        ultra_log_warn "No ext4/XFS filesystems found in /proc/mounts"
        ultra_state_finalize_module "$MOD_ID" "skipped"
        ultra_log_module_end "$MOD_ID"
        return 0
    fi
    
    ultra_log_info ""
    ultra_log_warn "⚠️  Journal tuning requires /etc/fstab changes and remount"
    ultra_log_info ""
    ultra_log_info "For ext4 filesystems, add 'commit=$commit_interval' to mount options:"
    ultra_log_info "  UUID=xxx / ext4 defaults,noatime,commit=$commit_interval 0 1"
    ultra_log_info ""
    ultra_log_info "For XFS filesystems, add logbufs/logbsize:"
    ultra_log_info "  UUID=xxx /data xfs defaults,noatime,logbufs=8,logbsize=256k 0 0"
    ultra_log_info ""
    ultra_log_info "After editing /etc/fstab:"
    ultra_log_info "  mount -o remount /"
    ultra_log_info "  mount -o remount /data"
    ultra_log_info ""
    ultra_log_warn "Or reboot to apply changes"
    
    # Tune ext4 parameters via sysctl (applies to all ext4)
    if ! ultra_is_dry_run; then
        # These don't exist in all kernels, so don't fail if missing
        ultra_log_info "Setting ext4 global parameters (if available)..."
        
        # Try to tune max_writeback_mb_bump (helps with large writes)
        if [[ -f /proc/sys/fs/ext4/max_writeback_mb_bump ]]; then
            ultra_sysctl_save_and_set "fs.ext4.max_writeback_mb_bump" "256" "$MOD_ID" || true
        fi
        
        ultra_state_add_action "$MOD_ID" "manual" "Review /etc/fstab for journal tuning"
    else
        ultra_log_info "[DRY-RUN] Would suggest journal tuning in /etc/fstab"
    fi
    
    ultra_state_finalize_module "$MOD_ID" "success"
    ultra_log_module_end "$MOD_ID"
}

mod_rollback() {
    local run_id="$1"
    
    ultra_log_info "Rolling back $MOD_DESC..."
    ultra_log_info "Restore original mount options in /etc/fstab if changed"
    ultra_log_info "Remove commit= option from ext4 mounts"
    ultra_log_info "Remove logbufs=/logbsize= from XFS mounts"
}

mod_verify() {
    ultra_log_info "Current journal settings:"
    
    mount | grep -E "ext4|xfs" | while read -r line; do
        local mount_point=$(echo "$line" | awk '{print $3}')
        local fstype=$(echo "$line" | awk '{print $5}')
        local options=$(echo "$line" | grep -oP '\(.*\)' | tr -d '()')
        
        ultra_log_info ""
        ultra_log_info "$mount_point ($fstype):"
        
        if [[ "$fstype" == "ext4" ]]; then
            if echo "$options" | grep -q "commit="; then
                local commit=$(echo "$options" | grep -oP 'commit=\K[0-9]+')
                ultra_log_info "  ✅ commit=$commit"
            else
                ultra_log_info "  ⚠️  commit=5 (default)"
            fi
        elif [[ "$fstype" == "xfs" ]]; then
            if echo "$options" | grep -q "logbufs="; then
                local logbufs=$(echo "$options" | grep -oP 'logbufs=\K[0-9]+')
                ultra_log_info "  ✅ logbufs=$logbufs"
            fi
            if echo "$options" | grep -q "logbsize="; then
                local logbsize=$(echo "$options" | grep -oP 'logbsize=\K[^,]+')
                ultra_log_info "  ✅ logbsize=$logbsize"
            fi
        fi
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This module should be run through the orchestrator"
    exit 1
fi
