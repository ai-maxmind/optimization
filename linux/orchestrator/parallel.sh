#!/bin/bash
# orchestrator/parallel.sh
# Parallel module execution for independent modules

ULTRA_PARALLEL_MAX_JOBS="${ULTRA_PARALLEL_MAX_JOBS:-4}"
declare -a ULTRA_PARALLEL_PIDS
declare -A ULTRA_PARALLEL_RESULTS

# Execute module in background
ultra_parallel_exec_module() {
    local module_file="$1"
    local result_file="$2"
    
    {
        if ultra_executor_run_module "$module_file"; then
            echo "success" > "$result_file"
            exit 0
        else
            echo "failed" > "$result_file"
            exit 1
        fi
    } &
    
    local pid=$!
    ULTRA_PARALLEL_PIDS+=($pid)
    echo "$pid"
}

# Wait for all parallel jobs to complete
ultra_parallel_wait_all() {
    local success=0
    local failed=0
    
    for pid in "${ULTRA_PARALLEL_PIDS[@]}"; do
        if wait "$pid"; then
            ((success++))
        else
            ((failed++))
        fi
    done
    
    ULTRA_PARALLEL_PIDS=()
    
    ultra_log_info "Parallel batch completed: $success succeeded, $failed failed"
    
    if [[ $failed -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Execute modules in parallel batches
ultra_parallel_exec_batch() {
    local modules=("$@")
    
    if [[ ${#modules[@]} -eq 0 ]]; then
        return 0
    fi
    
    ultra_log_info "Executing ${#modules[@]} modules in parallel (max $ULTRA_PARALLEL_MAX_JOBS concurrent)"
    
    local temp_dir=$(mktemp -d)
    local running=0
    local module_idx=0
    local total=${#modules[@]}
    
    while [[ $module_idx -lt $total ]] || [[ $running -gt 0 ]]; do
        # Start new jobs if slots available
        while [[ $running -lt $ULTRA_PARALLEL_MAX_JOBS ]] && [[ $module_idx -lt $total ]]; do
            local module="${modules[$module_idx]}"
            local result_file="$temp_dir/result_${module_idx}"
            
            ultra_log_debug "Starting module $module (slot $running/$ULTRA_PARALLEL_MAX_JOBS)"
            ultra_parallel_exec_module "$module" "$result_file"
            
            ((module_idx++))
            ((running++))
        done
        
        # Wait for any job to complete
        if [[ $running -gt 0 ]]; then
            wait -n
            ((running--))
        fi
        
        sleep 0.1
    done
    
    # Wait for all remaining jobs
    ultra_parallel_wait_all
    local exit_code=$?
    
    rm -rf "$temp_dir"
    return $exit_code
}

# Check if parallel execution is enabled
ultra_parallel_enabled() {
    [[ "${ULTRA_ENABLE_PARALLEL:-true}" == "true" ]]
}

# Get optimal number of parallel jobs
ultra_parallel_get_max_jobs() {
    local cpu_count=$(nproc)
    local max_jobs=${ULTRA_PARALLEL_MAX_JOBS:-4}
    
    # Limit to half of CPU cores
    local optimal=$((cpu_count / 2))
    [[ $optimal -lt 2 ]] && optimal=2
    [[ $optimal -gt $max_jobs ]] && optimal=$max_jobs
    
    echo "$optimal"
}
