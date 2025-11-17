#!/bin/bash
################################################################################
# MODULE: kernel.vm.overcommit
# Configure memory overcommit based on workload
################################################################################

MOD_ID="kernel.vm.overcommit"
MOD_DESC="Configure memory overcommit strategy"
MOD_STAGE="kernel-vm"
MOD_RISK="medium"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    return 0
}

mod_apply() {
    ultra_log_info "Applying $MOD_DESC"
    
    local profile=$(ultra_get_profile)
    local mem_gb=$(ultra_hw_mem_get_total_gb)
    
    # vm.overcommit_memory modes:
    # 0 = heuristic (default) - kernel guesses
    # 1 = always - never refuse memory allocation
    # 2 = strict - only allow RAM + swap percentage
    
    # vm.overcommit_ratio: percentage of RAM that can be allocated (when mode=2)
    
    local overcommit_memory=0
    local overcommit_ratio=50
    local overcommit_kbytes=0
    
    case "$profile" in
        server)
            # Server: heuristic is usually fine
            overcommit_memory=0
            overcommit_ratio=50
            ;;
        db)
            # Database: strict mode to prevent OOM
            overcommit_memory=2
            overcommit_ratio=80  # Allow 80% of physical RAM
            ;;
        lowlatency)
            # Low latency: strict to ensure predictability
            overcommit_memory=2
            overcommit_ratio=95  # Very conservative
            ;;
        desktop)
            # Desktop: heuristic
            overcommit_memory=0
            ;;
    esac
    
    ultra_log_info "Overcommit strategy: mode=$overcommit_memory, ratio=$overcommit_ratio%"
    
    ultra_sysctl_save_and_set "vm.overcommit_memory" "$overcommit_memory" "$MOD_ID"
    ultra_sysctl_save_and_set "vm.overcommit_ratio" "$overcommit_ratio" "$MOD_ID"
    
    # Related: OOM killer behavior
    # vm.panic_on_oom: 0=let OOM killer work, 1=panic on OOM
    # vm.oom_kill_allocating_task: 0=kill rogue process, 1=kill allocating task
    
    case "$profile" in
        server|db)
            # Let OOM killer work, kill the right process
            ultra_sysctl_save_and_set "vm.panic_on_oom" "0" "$MOD_ID"
            ultra_sysctl_save_and_set "vm.oom_kill_allocating_task" "0" "$MOD_ID"
            ;;
        lowlatency)
            # Panic on OOM to avoid unpredictable behavior
            ultra_sysctl_save_and_set "vm.panic_on_oom" "1" "$MOD_ID"
            ;;
    esac
    
    # vm.min_free_kbytes: minimum free memory
    # Formula: sqrt(RAM_GB) * 1024 * 16, capped at 2GB
    local min_free_kb=$((mem_gb * 16384))
    if (( min_free_kb > 2097152 )); then
        min_free_kb=2097152  # Cap at 2GB
    fi
    if (( min_free_kb < 65536 )); then
        min_free_kb=65536  # Minimum 64MB
    fi
    
    ultra_log_info "Setting min_free_kbytes = $min_free_kb KB"
    ultra_sysctl_save_and_set "vm.min_free_kbytes" "$min_free_kb" "$MOD_ID"
    
    # vm.watermark_scale_factor: how aggressively kswapd reclaims
    # Higher = more aggressive (reclaim earlier)
    # Range: 10-1000, default: 10
    local watermark_scale=10
    if [[ "$profile" == "db" ]] || [[ "$profile" == "server" ]]; then
        watermark_scale=200  # More aggressive reclaim
    fi
    
    ultra_sysctl_save_and_set "vm.watermark_scale_factor" "$watermark_scale" "$MOD_ID"
}

mod_rollback() {
    ultra_log_info "Rolling back $MOD_ID"
    
    local run_id="$1"
    local state_file="$ULTRA_STATE_DIR/$run_id/${MOD_ID}.json"
    
    if [[ -f "$state_file" ]] && command -v jq &>/dev/null; then
        local keys=(
            "vm.overcommit_memory"
            "vm.overcommit_ratio"
            "vm.panic_on_oom"
            "vm.oom_kill_allocating_task"
            "vm.min_free_kbytes"
            "vm.watermark_scale_factor"
        )
        
        for key in "${keys[@]}"; do
            local value=$(jq -r ".before[\"sysctl:$key\"]" "$state_file")
            if [[ "$value" != "null" ]] && [[ -n "$value" ]]; then
                ultra_sysctl_restore "$key" "$value" "$MOD_ID"
            fi
        done
    fi
}

mod_verify() {
    ultra_log_info "Memory overcommit configuration:"
    ultra_log_info "  overcommit_memory: $(ultra_sysctl_get_current vm.overcommit_memory)"
    ultra_log_info "  overcommit_ratio: $(ultra_sysctl_get_current vm.overcommit_ratio)%"
    ultra_log_info "  min_free_kbytes: $(ultra_sysctl_get_current vm.min_free_kbytes) KB"
    ultra_log_info "  watermark_scale_factor: $(ultra_sysctl_get_current vm.watermark_scale_factor)"
    
    # Show current memory stats
    local free_kb=$(grep MemFree /proc/meminfo | awk '{print $2}')
    local available_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    ultra_log_info "Current memory: free=$((free_kb/1024))MB, available=$((available_kb/1024))MB"
}
