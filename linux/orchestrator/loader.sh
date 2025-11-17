#!/bin/bash
################################################################################
# MODULE LOADER - Load modules based on profile and stage
################################################################################

ULTRA_MODULES_DIR="${ULTRA_MODULES_DIR:-$(dirname "$0")/../modules}"
declare -A ULTRA_LOADED_MODULES

ultra_loader_init() {
    ultra_log_debug "Module loader initialized"
    ultra_log_debug "Modules directory: $ULTRA_MODULES_DIR"
}

ultra_loader_discover_modules() {
    local stage="$1"
    local modules=()
    
    if [[ "$stage" == "all" ]]; then
        # Find all module files
        while IFS= read -r -d '' module_file; do
            modules+=("$module_file")
        done < <(find "$ULTRA_MODULES_DIR" -type f -name "*.sh" -print0 | sort -z)
    else
        # Find modules for specific stage
        while IFS= read -r -d '' module_file; do
            # Source module to get metadata
            source "$module_file"
            if [[ "${MOD_STAGE:-}" == "$stage" ]]; then
                modules+=("$module_file")
            fi
        done < <(find "$ULTRA_MODULES_DIR" -type f -name "*.sh" -print0 | sort -z)
    fi
    
    echo "${modules[@]}"
}

ultra_loader_load_module() {
    local module_file="$1"
    
    if [[ ! -f "$module_file" ]]; then
        ultra_log_error "Module file not found: $module_file"
        return 1
    fi
    
    # Source the module
    source "$module_file"
    
    # Validate required functions
    if ! type mod_id &>/dev/null || ! type mod_apply &>/dev/null; then
        ultra_log_error "Module $module_file missing required functions (mod_id, mod_apply)"
        return 1
    fi
    
    local mod_id=$(mod_id)
    ULTRA_LOADED_MODULES[$mod_id]="$module_file"
    
    ultra_log_debug "Loaded module: $mod_id from $module_file"
    return 0
}

ultra_loader_should_run_module() {
    local module_file="$1"
    
    # Load module if not already loaded
    if ! ultra_loader_load_module "$module_file"; then
        return 1
    fi
    
    local mod_id=$(mod_id)
    local mod_risk="${MOD_RISK:-medium}"
    local mod_enabled="${MOD_DEFAULT_ENABLED:-true}"
    local max_risk=$(ultra_get_max_risk)
    
    # Check if enabled
    if [[ "$mod_enabled" != "true" ]]; then
        ultra_log_debug "Module $mod_id is disabled by default"
        return 1
    fi
    
    # Check risk level
    local risk_value=0
    case "$mod_risk" in
        low) risk_value=1 ;;
        medium) risk_value=2 ;;
        high) risk_value=3 ;;
    esac
    
    local max_risk_value=0
    case "$max_risk" in
        low) max_risk_value=1 ;;
        medium) max_risk_value=2 ;;
        high) max_risk_value=3 ;;
    esac
    
    if (( risk_value > max_risk_value )); then
        ultra_log_debug "Module $mod_id risk ($mod_risk) exceeds max risk ($max_risk)"
        return 1
    fi
    
    # Check mod_can_run
    if type mod_can_run &>/dev/null; then
        if ! mod_can_run; then
            ultra_log_debug "Module $mod_id cannot run (mod_can_run returned false)"
            return 1
        fi
    fi
    
    return 0
}

ultra_loader_get_loaded_modules() {
    echo "${!ULTRA_LOADED_MODULES[@]}"
}
