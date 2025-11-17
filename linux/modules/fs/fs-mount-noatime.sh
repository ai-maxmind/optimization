#!/bin/bash
# modules/fs/fs-mount-noatime.sh
# Module: Filesystem mount options (noatime, nodiratime)
# Reduces disk writes by not updating access times

MOD_ID="fs.mount-noatime"
MOD_DESC="Mount options optimization (noatime)"
MOD_STAGE="fs"
MOD_RISK="low"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Safe for all profiles
    return 0
}

mod_apply() {
    ultra_log_module_start "$MOD_ID"
    ultra_log_info "Applying filesystem mount options optimization..."
    
    ultra_log_warn "⚠️  This module requires editing /etc/fstab and remounting filesystems"
    ultra_log_warn "Recommendation: Apply this manually or during maintenance window"
    
    # Backup /etc/fstab
    if ! ultra_is_dry_run; then
        ultra_backup_file "/etc/fstab" "$MOD_ID"
    fi
    
    # Analyze current mounts
    ultra_log_info "Current mount options:"
    while read -r line; do
        if [[ "$line" =~ ^/dev ]] || [[ "$line" =~ ^UUID ]]; then
            local mount_point=$(echo "$line" | awk '{print $2}')
            local options=$(echo "$line" | awk '{print $4}')
            
            if [[ "$mount_point" == "/" ]] || [[ "$mount_point" == "/home" ]] || [[ "$mount_point" =~ ^/var ]]; then
                ultra_log_info "  $mount_point: $options"
                
                if echo "$options" | grep -q "noatime"; then
                    ultra_log_info "    ✅ noatime already set"
                else
                    ultra_log_warn "    ❌ noatime NOT set - consider adding"
                fi
            fi
        fi
    done < /etc/fstab
    
    ultra_log_info ""
    ultra_log_info "Recommended /etc/fstab changes:"
    ultra_log_info "  1. Add 'noatime' or 'relatime' to mount options"
    ultra_log_info "  2. 'noatime' = never update access time (fastest)"
    ultra_log_info "  3. 'relatime' = update only if older than mtime (safer default)"
    ultra_log_info ""
    ultra_log_info "Example:"
    ultra_log_info "  UUID=xxx / ext4 defaults,noatime 0 1"
    ultra_log_info "  UUID=yyy /home ext4 defaults,noatime 0 1"
    ultra_log_info ""
    ultra_log_info "After editing /etc/fstab, remount:"
    ultra_log_info "  mount -o remount /"
    ultra_log_info "  mount -o remount /home"
    ultra_log_info ""
    ultra_log_warn "Or reboot for changes to take effect"
    
    if ! ultra_is_dry_run; then
        ultra_state_add_action "$MOD_ID" "manual" "Review and update /etc/fstab with noatime"
        ultra_state_add_action "$MOD_ID" "backup" "Backed up /etc/fstab"
    else
        ultra_log_info "[DRY-RUN] Would suggest /etc/fstab changes"
    fi
    
    ultra_state_finalize_module "$MOD_ID" "success"
    ultra_log_module_end "$MOD_ID"
}

mod_rollback() {
    local run_id="$1"
    
    ultra_log_info "Rolling back $MOD_DESC..."
    ultra_log_info "Restore /etc/fstab from backup if changes were made"
    ultra_log_info "Backup location: /var/lib/ubuntu-ultra-opt/backups/$run_id/$MOD_ID/"
}

mod_verify() {
    ultra_log_info "Current mount options:"
    mount | grep -E "^/dev|^UUID" | grep -E "ext4|xfs|btrfs" | while read -r line; do
        echo "  $line"
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This module should be run through the orchestrator"
    exit 1
fi
