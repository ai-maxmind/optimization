#!/bin/bash
################################################################################
# ROLLBACK - Rollback changes by RUN_ID or specific module
################################################################################

ULTRA_STATE_DIR="${ULTRA_STATE_DIR:-/var/lib/ubuntu-ultra-opt/state}"

source "$(dirname "$0")/core/log/log.sh"
source "$(dirname "$0")/core/runtime/state.sh"
source "$(dirname "$0")/core/fs/sysctl_io.sh"
source "$(dirname "$0")/core/fs/backup.sh"
source "$(dirname "$0")/orchestrator/loader.sh"

ultra_rollback_run() {
    local run_id="$1"
    
    local run_dir="$ULTRA_STATE_DIR/$run_id"
    
    if [[ ! -d "$run_dir" ]]; then
        ultra_log_error "Run not found: $run_id"
        return 1
    fi
    
    ultra_log_section "Rolling back run: $run_id"
    
    # Get all module states
    local module_states=()
    while IFS= read -r -d '' state_file; do
        module_states+=("$state_file")
    done < <(find "$run_dir" -type f -name "*.json" ! -name "run.json" -print0 | sort -z)
    
    if [[ ${#module_states[@]} -eq 0 ]]; then
        ultra_log_warn "No module states found for run: $run_id"
        return 0
    fi
    
    ultra_log_info "Found ${#module_states[@]} modules to rollback"
    
    # Rollback in reverse order
    local total=${#module_states[@]}
    local count=0
    
    for (( i=${#module_states[@]}-1; i>=0; i-- )); do
        local state_file="${module_states[$i]}"
        local module_id=$(basename "$state_file" .json)
        
        ((count++))
        ultra_log_info "[$count/$total] Rolling back module: $module_id"
        
        # Find and load module
        local module_file=$(find "$ULTRA_MODULES_DIR" -type f -name "*.sh" -exec grep -l "MOD_ID=\"$module_id\"" {} \;)
        
        if [[ -z "$module_file" ]]; then
            ultra_log_warn "Module file not found for $module_id, skipping"
            continue
        fi
        
        source "$module_file"
        
        # Call mod_rollback if exists
        if type mod_rollback &>/dev/null; then
            if mod_rollback "$run_id"; then
                ultra_log_info "✓ Rolled back $module_id"
            else
                ultra_log_error "✗ Failed to rollback $module_id"
            fi
        else
            ultra_log_warn "Module $module_id does not have rollback function"
        fi
    done
    
    ultra_log_section "Rollback completed for run: $run_id"
    ultra_log_info "Run state preserved in: $run_dir"
    ultra_log_warn "Reboot recommended to ensure all changes are reverted"
}

ultra_rollback_module() {
    local run_id="$1"
    local module_id="$2"
    
    ultra_log_section "Rolling back module: $module_id (run: $run_id)"
    
    local state_file="$ULTRA_STATE_DIR/$run_id/${module_id}.json"
    
    if [[ ! -f "$state_file" ]]; then
        ultra_log_error "Module state not found: $module_id in run $run_id"
        return 1
    fi
    
    # Find and load module
    local module_file=$(find "$ULTRA_MODULES_DIR" -type f -name "*.sh" -exec grep -l "MOD_ID=\"$module_id\"" {} \;)
    
    if [[ -z "$module_file" ]]; then
        ultra_log_error "Module file not found for $module_id"
        return 1
    fi
    
    source "$module_file"
    
    # Call mod_rollback
    if type mod_rollback &>/dev/null; then
        if mod_rollback "$run_id"; then
            ultra_log_info "✓ Successfully rolled back $module_id"
        else
            ultra_log_error "✗ Failed to rollback $module_id"
            return 1
        fi
    else
        ultra_log_error "Module $module_id does not have rollback function"
        return 1
    fi
    
    ultra_log_warn "Reboot recommended to ensure changes are fully reverted"
}

# Main
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <RUN_ID> [MODULE_ID]"
        echo ""
        echo "Rollback entire run:"
        echo "  $0 20241117-120000-abc123"
        echo ""
        echo "Rollback specific module:"
        echo "  $0 20241117-120000-abc123 kernel.vm.swappiness"
        echo ""
        echo "List recent runs:"
        echo "  ls -t /var/lib/ubuntu-ultra-opt/state/ | head -10"
        exit 1
    fi
    
    ultra_log_init
    
    local run_id="$1"
    local module_id="${2:-}"
    
    if [[ -n "$module_id" ]]; then
        ultra_rollback_module "$run_id" "$module_id"
    else
        ultra_rollback_run "$run_id"
    fi
}

# Only run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
