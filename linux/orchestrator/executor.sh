#!/bin/bash
################################################################################
# EXECUTOR - Execute modules with error handling and state tracking
################################################################################

ultra_executor_run_module() {
    local module_file="$1"
    
    # Load module
    if ! ultra_loader_load_module "$module_file"; then
        ultra_log_error "Failed to load module: $module_file"
        return 1
    fi
    
    local mod_id=$(mod_id)
    local mod_desc="${MOD_DESC:-No description}"
    
    ultra_log_module_start "$mod_id" "$mod_desc"
    
    # Check if should run
    if ! ultra_loader_should_run_module "$module_file"; then
        ultra_log_module_end "$mod_id" "skipped"
        ultra_state_finalize_module "$mod_id" "skipped"
        return 0
    fi
    
    # Execute module
    local start_time=$(date +%s)
    local status="success"
    
    if mod_apply; then
        status="success"
        ultra_log_module_end "$mod_id" "success"
    else
        status="failed"
        ultra_log_module_end "$mod_id" "failed"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    ultra_log_debug "Module $mod_id completed in ${duration}s"
    
    # Finalize state
    ultra_state_finalize_module "$mod_id" "$status"
    
    if [[ "$status" == "failed" ]]; then
        return 1
    fi
    
    return 0
}

ultra_executor_run_stage() {
    local stage="$1"
    
    ultra_log_section "Running stage: $stage"
    
    # Discover modules for this stage
    local modules=$(ultra_loader_discover_modules "$stage")
    
    if [[ -z "$modules" ]]; then
        ultra_log_warn "No modules found for stage: $stage"
        return 0
    fi
    
    local total=0
    local success=0
    local failed=0
    local skipped=0
    
    # Execute each module
    for module_file in $modules; do
        ((total++))
        
        if ultra_executor_run_module "$module_file"; then
            ((success++))
        else
            ((failed++))
            
            # Stop on first failure if not forced
            if ! ultra_is_force; then
                ultra_log_error "Module failed, stopping stage execution (use --force to continue)"
                break
            fi
        fi
    done
    
    ultra_log_info "Stage '$stage' summary: $success succeeded, $failed failed, $skipped skipped (total: $total)"
    
    if (( failed > 0 )); then
        return 1
    fi
    
    return 0
}

ultra_executor_run_all_stages() {
    local profile=$(ultra_get_profile)
    local profile_file="$ULTRA_PROFILE_DIR/${profile}.yml"
    
    # Default stage order if no profile
    local stages=(
        "kernel-vm"
        "kernel-sched"
        "kernel-io"
        "net"
        "fs"
        "services"
    )
    
    # TODO: Parse stages from profile YAML when implemented
    
    ultra_log_section "Executing all stages for profile: $profile"
    
    local total_stages=${#stages[@]}
    local completed_stages=0
    
    for stage in "${stages[@]}"; do
        ultra_log_info "Progress: $completed_stages/$total_stages stages completed"
        
        if ultra_executor_run_stage "$stage"; then
            ((completed_stages++))
        else
            ultra_log_error "Stage '$stage' failed"
            
            if ! ultra_is_force; then
                ultra_log_error "Stopping execution (use --force to continue)"
                return 1
            fi
        fi
    done
    
    ultra_log_section "All stages completed: $completed_stages/$total_stages"
    
    return 0
}

ultra_executor_run_single_module() {
    local module_id="$1"
    
    ultra_log_section "Running single module: $module_id"
    
    # Find module file
    local module_file=$(find "$ULTRA_MODULES_DIR" -type f -name "*.sh" -exec grep -l "MOD_ID=\"$module_id\"" {} \;)
    
    if [[ -z "$module_file" ]]; then
        ultra_log_error "Module not found: $module_id"
        return 1
    fi
    
    ultra_executor_run_module "$module_file"
}
