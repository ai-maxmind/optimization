#!/bin/bash
# orchestrator/dependency.sh
# Module dependency management and execution ordering

declare -A ULTRA_MODULE_DEPS
declare -A ULTRA_MODULE_STATUS

# Define module dependencies
ultra_deps_init() {
    # VM dependencies
    ULTRA_MODULE_DEPS["kernel.vm.thp-hugepage"]="kernel.vm.compact"
    ULTRA_MODULE_DEPS["kernel.vm.swappiness"]="kernel.vm.overcommit"
    
    # Scheduler dependencies
    ULTRA_MODULE_DEPS["kernel.sched.cpu-isolation"]="kernel.sched.governor"
    
    # Network dependencies
    ULTRA_MODULE_DEPS["net.rps-rfs"]="net.core-buffers"
    ULTRA_MODULE_DEPS["net.irq-pinning"]="net.ethtool-offload"
    
    # Filesystem dependencies
    ULTRA_MODULE_DEPS["fs.swap-zram"]="kernel.vm.swappiness"
    ULTRA_MODULE_DEPS["fs.mount-journal"]="fs.mount-noatime"
    
    ultra_log_debug "Module dependencies initialized"
}

# Get dependencies for a module
ultra_deps_get() {
    local module_id="$1"
    echo "${ULTRA_MODULE_DEPS[$module_id]:-}"
}

# Check if all dependencies are satisfied
ultra_deps_check() {
    local module_id="$1"
    local deps=$(ultra_deps_get "$module_id")
    
    if [[ -z "$deps" ]]; then
        return 0  # No dependencies
    fi
    
    # Check each dependency
    for dep in $deps; do
        local dep_status="${ULTRA_MODULE_STATUS[$dep]:-}"
        
        if [[ "$dep_status" != "success" ]]; then
            ultra_log_warn "Module $module_id depends on $dep (status: ${dep_status:-not run})"
            return 1
        fi
    done
    
    return 0
}

# Mark module status
ultra_deps_set_status() {
    local module_id="$1"
    local status="$2"
    
    ULTRA_MODULE_STATUS[$module_id]="$status"
}

# Build execution order using topological sort
ultra_deps_build_order() {
    local modules=("$@")
    local ordered=()
    local -A visited
    local -A in_progress
    
    # DFS to detect cycles and build order
    _visit_module() {
        local mod="$1"
        
        # Check for cycle
        if [[ "${in_progress[$mod]:-}" == "1" ]]; then
            ultra_log_error "Circular dependency detected involving $mod"
            return 1
        fi
        
        # Already visited
        if [[ "${visited[$mod]:-}" == "1" ]]; then
            return 0
        fi
        
        in_progress[$mod]=1
        
        # Visit dependencies first
        local deps=$(ultra_deps_get "$mod")
        for dep in $deps; do
            if ! _visit_module "$dep"; then
                return 1
            fi
        done
        
        in_progress[$mod]=0
        visited[$mod]=1
        ordered+=("$mod")
    }
    
    # Visit all modules
    for mod in "${modules[@]}"; do
        if ! _visit_module "$mod"; then
            return 1
        fi
    done
    
    echo "${ordered[@]}"
}

# Get modules that can run in parallel (no dependencies between them)
ultra_deps_get_parallel_batch() {
    local modules=("$@")
    local batch=()
    
    for mod in "${modules[@]}"; do
        # Check if dependencies are satisfied
        if ultra_deps_check "$mod"; then
            # Check if no other module in batch depends on this one
            local can_parallel=1
            for other in "${batch[@]}"; do
                local other_deps=$(ultra_deps_get "$other")
                if [[ " $other_deps " =~ " $mod " ]]; then
                    can_parallel=0
                    break
                fi
                
                local mod_deps=$(ultra_deps_get "$mod")
                if [[ " $mod_deps " =~ " $other " ]]; then
                    can_parallel=0
                    break
                fi
            done
            
            if [[ $can_parallel -eq 1 ]]; then
                batch+=("$mod")
            fi
        fi
    done
    
    echo "${batch[@]}"
}
