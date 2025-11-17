#!/bin/bash
################################################################################
# BACKUP - Backup and versioning for config files
################################################################################

ULTRA_BACKUP_DIR="${ULTRA_BACKUP_DIR:-/var/lib/ubuntu-ultra-opt/backups}"

ultra_backup_init() {
    mkdir -p "$ULTRA_BACKUP_DIR"
}

ultra_backup_file() {
    local file_path="$1"
    local module_id="$2"
    
    if [[ ! -f "$file_path" ]]; then
        ultra_log_debug "File does not exist, no backup needed: $file_path"
        return 0
    fi
    
    # Create backup directory structure
    local backup_subdir="$ULTRA_BACKUP_DIR/$(ultra_state_get_run_id)/$module_id"
    mkdir -p "$backup_subdir"
    
    # Generate backup filename with timestamp
    local filename=$(basename "$file_path")
    local backup_path="$backup_subdir/${filename}.$(date +%Y%m%d-%H%M%S).bak"
    
    # Dry-run check
    if ultra_is_dry_run; then
        ultra_log_dry_run "Backup: $file_path -> $backup_path"
        return 0
    fi
    
    # Create backup
    if cp -a "$file_path" "$backup_path"; then
        ultra_log_debug "Backed up: $file_path -> $backup_path"
        ultra_state_add_action "$module_id" "file_backup" "Backed up $file_path"
        
        # Save backup path to state
        ultra_state_save_module_before "$module_id" "file:$file_path:backup" "$backup_path"
        
        return 0
    else
        ultra_log_error "Failed to backup: $file_path"
        return 1
    fi
}

ultra_backup_restore_file() {
    local backup_path="$1"
    local original_path="$2"
    
    if [[ ! -f "$backup_path" ]]; then
        ultra_log_error "Backup file not found: $backup_path"
        return 1
    fi
    
    if ultra_is_dry_run; then
        ultra_log_dry_run "Restore: $backup_path -> $original_path"
        return 0
    fi
    
    if cp -a "$backup_path" "$original_path"; then
        ultra_log_info "Restored: $original_path from backup"
        return 0
    else
        ultra_log_error "Failed to restore: $original_path"
        return 1
    fi
}

ultra_backup_list_for_run() {
    local run_id="$1"
    local backup_dir="$ULTRA_BACKUP_DIR/$run_id"
    
    if [[ -d "$backup_dir" ]]; then
        find "$backup_dir" -type f -name "*.bak"
    else
        ultra_log_warn "No backups found for run: $run_id"
    fi
}
