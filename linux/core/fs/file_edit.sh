#!/bin/bash
################################################################################
# FILE EDIT - Safe, atomic file editing with patch support
################################################################################

ultra_edit_file_with_sed() {
    local file_path="$1"
    local sed_pattern="$2"
    local module_id="$3"
    
    # Backup first
    if ! ultra_should_skip_backup; then
        if ! ultra_backup_file "$file_path" "$module_id"; then
            ultra_log_error "Backup failed, aborting edit of $file_path"
            return 1
        fi
    fi
    
    # Dry-run check
    if ultra_is_dry_run; then
        ultra_log_dry_run "Edit file with sed: $file_path (pattern: $sed_pattern)"
        return 0
    fi
    
    # Create temp file for atomic operation
    local temp_file=$(mktemp)
    
    # Apply sed pattern
    if sed "$sed_pattern" "$file_path" > "$temp_file"; then
        # Verify temp file is not empty
        if [[ ! -s "$temp_file" ]]; then
            ultra_log_error "Sed resulted in empty file, aborting"
            rm -f "$temp_file"
            return 1
        fi
        
        # Atomic move
        if mv "$temp_file" "$file_path"; then
            ultra_log_info "Edited file: $file_path"
            ultra_state_add_action "$module_id" "file_edit" "Edited $file_path with sed"
            return 0
        else
            ultra_log_error "Failed to move edited file to $file_path"
            rm -f "$temp_file"
            return 1
        fi
    else
        ultra_log_error "Sed command failed on $file_path"
        rm -f "$temp_file"
        return 1
    fi
}

ultra_edit_file_append_line() {
    local file_path="$1"
    local line="$2"
    local module_id="$3"
    local unique="${4:-false}"  # If true, check if line already exists
    
    # Check if line already exists (if unique mode)
    if [[ "$unique" == "true" ]]; then
        if grep -Fxq "$line" "$file_path" 2>/dev/null; then
            ultra_log_debug "Line already exists in $file_path, skipping"
            return 0
        fi
    fi
    
    # Backup first
    if [[ -f "$file_path" ]] && ! ultra_should_skip_backup; then
        ultra_backup_file "$file_path" "$module_id"
    fi
    
    # Dry-run check
    if ultra_is_dry_run; then
        ultra_log_dry_run "Append to file: $file_path (line: $line)"
        return 0
    fi
    
    # Append line
    if echo "$line" >> "$file_path"; then
        ultra_log_debug "Appended line to $file_path"
        ultra_state_add_action "$module_id" "file_edit" "Appended line to $file_path"
        return 0
    else
        ultra_log_error "Failed to append to $file_path"
        return 1
    fi
}

ultra_edit_file_replace_line() {
    local file_path="$1"
    local search_pattern="$2"
    local replacement="$3"
    local module_id="$4"
    
    # Use sed to replace
    ultra_edit_file_with_sed "$file_path" "s|$search_pattern|$replacement|g" "$module_id"
}

ultra_edit_grub_add_param() {
    local param="$1"
    local module_id="$2"
    local grub_file="/etc/default/grub"
    
    # Backup
    if ! ultra_should_skip_backup; then
        ultra_backup_file "$grub_file" "$module_id"
    fi
    
    # Check if param already exists
    if grep "GRUB_CMDLINE_LINUX_DEFAULT" "$grub_file" | grep -q "$param"; then
        ultra_log_debug "GRUB param already exists: $param"
        return 0
    fi
    
    # Dry-run check
    if ultra_is_dry_run; then
        ultra_log_dry_run "Add GRUB param: $param"
        return 0
    fi
    
    # Add parameter
    if sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\\(.*\\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\\1 $param\"/" "$grub_file"; then
        ultra_log_info "Added GRUB param: $param"
        ultra_state_add_action "$module_id" "file_edit" "Added GRUB param: $param"
        
        # Update GRUB
        if command -v update-grub &>/dev/null; then
            ultra_log_info "Updating GRUB configuration..."
            update-grub >/dev/null 2>&1
            ultra_log_warn "Reboot required for GRUB changes to take effect"
        fi
        
        return 0
    else
        ultra_log_error "Failed to add GRUB param: $param"
        return 1
    fi
}
