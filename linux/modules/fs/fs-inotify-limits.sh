#!/bin/bash
# modules/fs/fs-inotify-limits.sh
# Module: Inotify limits tuning
# Increases inotify watch limits for applications that monitor many files

MOD_ID="fs.inotify-limits"
MOD_DESC="Inotify limits"
MOD_STAGE="fs"
MOD_RISK="low"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Check if inotify is available
    if [[ ! -f /proc/sys/fs/inotify/max_user_watches ]]; then
        ultra_log_debug "inotify not available"
        return 1
    fi
    return 0
}

mod_apply() {
    ultra_log_module_start "$MOD_ID"
    ultra_log_info "Applying inotify limits optimization..."
    
    local profile=$(ultra_get_profile)
    local ram_gb=$(ultra_get_total_ram_gb)
    
    # Inotify limits:
    # max_user_watches: max file watches per user (default: 8192-524288)
    # max_user_instances: max inotify instances per user (default: 128)
    # max_queued_events: max events in queue (default: 16384)
    
    # Each watch consumes ~1KB of kernel memory
    # 1M watches = ~1GB RAM
    
    local max_watches=524288   # Default: moderate
    local max_instances=1024
    local max_events=32768
    
    case "$profile" in
        server)
            # Servers may run monitoring tools, CI/CD
            if [[ $ram_gb -ge 16 ]]; then
                max_watches=1048576  # 1M watches (~1GB RAM)
            else
                max_watches=524288
            fi
            max_instances=1024
            max_events=32768
            ;;
        db)
            # Databases don't need many watches
            max_watches=524288
            max_instances=512
            max_events=16384
            ;;
        lowlatency)
            # Keep moderate to save memory
            max_watches=524288
            max_instances=512
            max_events=16384
            ;;
        desktop)
            # Desktop apps (IDEs, file managers) need many watches
            if [[ $ram_gb -ge 8 ]]; then
                max_watches=1048576  # 1M watches
            else
                max_watches=524288
            fi
            max_instances=1024
            max_events=32768
            ;;
        *)
            max_watches=524288
            max_instances=512
            max_events=16384
            ;;
    esac
    
    ultra_log_info "Inotify configuration:"
    ultra_log_info "  max_user_watches: $max_watches (default: 8192-524288)"
    ultra_log_info "  max_user_instances: $max_instances (default: 128)"
    ultra_log_info "  max_queued_events: $max_events (default: 16384)"
    ultra_log_info "  System RAM: ${ram_gb}GB"
    ultra_log_info "  Memory usage: ~$((max_watches / 1024))MB"
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would configure inotify limits"
        ultra_state_finalize_module "$MOD_ID" "success"
        ultra_log_module_end "$MOD_ID"
        return 0
    fi
    
    # Apply sysctl settings
    ultra_apply_sysctl "fs.inotify.max_user_watches" "$max_watches" "$MOD_ID"
    ultra_apply_sysctl "fs.inotify.max_user_instances" "$max_instances" "$MOD_ID"
    ultra_apply_sysctl "fs.inotify.max_queued_events" "$max_events" "$MOD_ID"
    
    ultra_state_add_action "$MOD_ID" "sysctl" "Inotify limits configured"
    
    ultra_log_info ""
    ultra_log_info "Applications that use inotify:"
    ultra_log_info "  - File managers (Nautilus, Dolphin)"
    ultra_log_info "  - IDEs (VS Code, IntelliJ, Eclipse)"
    ultra_log_info "  - Build tools (webpack, nodemon, gulp)"
    ultra_log_info "  - Cloud sync (Dropbox, Nextcloud)"
    ultra_log_info "  - Monitoring tools (watchman, fswatch)"
    
    ultra_log_info ""
    ultra_log_info "Check current usage:"
    ultra_log_info "  find /proc/*/fd -lname 'anon_inode:inotify' 2>/dev/null | wc -l"
    ultra_log_info "  cat /proc/sys/fs/inotify/max_user_watches"
    
    ultra_state_finalize_module "$MOD_ID" "success"
    ultra_log_module_end "$MOD_ID"
}

mod_rollback() {
    local run_id="$1"
    
    ultra_log_info "Rolling back $MOD_DESC..."
    ultra_rollback_sysctl "fs.inotify.max_user_watches" "$MOD_ID" "$run_id"
    ultra_rollback_sysctl "fs.inotify.max_user_instances" "$MOD_ID" "$run_id"
    ultra_rollback_sysctl "fs.inotify.max_queued_events" "$MOD_ID" "$run_id"
}

mod_verify() {
    ultra_log_info "Inotify Configuration:"
    
    if [[ -f /proc/sys/fs/inotify/max_user_watches ]]; then
        local watches=$(cat /proc/sys/fs/inotify/max_user_watches)
        ultra_log_info "  max_user_watches: $watches"
    fi
    
    if [[ -f /proc/sys/fs/inotify/max_user_instances ]]; then
        local instances=$(cat /proc/sys/fs/inotify/max_user_instances)
        ultra_log_info "  max_user_instances: $instances"
    fi
    
    if [[ -f /proc/sys/fs/inotify/max_queued_events ]]; then
        local events=$(cat /proc/sys/fs/inotify/max_queued_events)
        ultra_log_info "  max_queued_events: $events"
    fi
    
    ultra_log_info ""
    ultra_log_info "Current inotify usage:"
    local in_use=$(find /proc/*/fd -lname 'anon_inode:inotify' 2>/dev/null | wc -l)
    ultra_log_info "  Active inotify instances: $in_use"
    
    if [[ $in_use -gt 0 ]]; then
        ultra_log_info ""
        ultra_log_info "Top processes using inotify:"
        for pid in $(find /proc/*/fd -lname 'anon_inode:inotify' 2>/dev/null | cut -d/ -f3 | sort -u | head -5); do
            if [[ -f /proc/$pid/cmdline ]]; then
                local cmd=$(tr '\0' ' ' < /proc/$pid/cmdline | head -c 80)
                echo "    PID $pid: $cmd"
            fi
        done
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This module should be run through the orchestrator"
    exit 1
fi
