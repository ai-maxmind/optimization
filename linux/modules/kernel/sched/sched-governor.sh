#!/bin/bash
################################################################################
# MODULE: kernel.sched.cpu-governor
# Set CPU frequency governor based on profile
################################################################################

MOD_ID="kernel.sched.cpu-governor"
MOD_DESC="Configure CPU frequency governor for optimal performance"
MOD_STAGE="kernel-sched"
MOD_RISK="low"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Check if cpufreq is available
    if [[ ! -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        ultra_log_warn "CPU frequency scaling not available"
        return 1
    fi
    return 0
}

mod_apply() {
    ultra_log_info "Applying $MOD_DESC"
    
    local profile=$(ultra_get_profile)
    local cpu_vendor=$(ultra_hw_cpu_get_vendor)
    local target_governor="performance"
    
    # Governor selection based on profile
    case "$profile" in
        server|db|lowlatency)
            target_governor="performance"
            ;;
        desktop)
            # Desktop can use ondemand or schedutil for power saving
            # But for optimization, still prefer performance
            if grep -q "schedutil" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
                target_governor="schedutil"
            else
                target_governor="performance"
            fi
            ;;
        *)
            target_governor="performance"
            ;;
    esac
    
    # Check if target governor is available
    local available_governors=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || echo "")
    if [[ ! "$available_governors" =~ $target_governor ]]; then
        ultra_log_warn "Governor '$target_governor' not available. Available: $available_governors"
        # Fallback to first available
        target_governor=$(echo "$available_governors" | awk '{print $1}')
        ultra_log_info "Using fallback governor: $target_governor"
    fi
    
    # Install cpufrequtils if not present
    if ! command -v cpufreq-set &>/dev/null; then
        ultra_log_info "Installing cpufrequtils..."
        if ! ultra_is_dry_run; then
            apt-get install -y cpufrequtils >/dev/null 2>&1 || true
        fi
    fi
    
    # Save current governor
    local current_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    ultra_state_save_module_before "$MOD_ID" "cpu_governor" "$current_governor"
    
    # Apply to all CPUs
    local cpu_count=$(ultra_hw_cpu_get_cores_logical)
    ultra_log_info "Setting governor '$target_governor' on $cpu_count CPUs"
    
    if ! ultra_is_dry_run; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            if [[ -f "$cpu" ]]; then
                echo "$target_governor" > "$cpu" 2>/dev/null || true
            fi
        done
    else
        ultra_log_dry_run "Set governor $target_governor on all CPUs"
    fi
    
    # Make persistent via systemd service
    if ultra_has_systemd && ! ultra_is_dry_run; then
        local service_file="/etc/systemd/system/cpu-governor.service"
        
        cat > "$service_file" << EOF
[Unit]
Description=Set CPU Governor to $target_governor
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -f "\$cpu" ] && echo "$target_governor" > "\$cpu"; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable cpu-governor.service >/dev/null 2>&1
        ultra_log_info "Created systemd service for CPU governor persistence"
    fi
    
    ultra_state_save_module_after "$MOD_ID" "cpu_governor" "$target_governor"
    ultra_state_add_action "$MOD_ID" "sysctl" "Set CPU governor to $target_governor"
    
    # Intel-specific: P-State driver tuning
    if [[ "$cpu_vendor" == "intel" ]] && [[ -d /sys/devices/system/cpu/intel_pstate ]]; then
        ultra_log_info "Configuring Intel P-State driver"
        
        # Disable turbo for consistency (only if lowlatency profile)
        if [[ "$profile" == "lowlatency" ]]; then
            if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
                local no_turbo_before=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)
                ultra_state_save_module_before "$MOD_ID" "intel_no_turbo" "$no_turbo_before"
                
                if ! ultra_is_dry_run; then
                    echo "1" > /sys/devices/system/cpu/intel_pstate/no_turbo
                    ultra_log_info "Disabled Intel Turbo Boost for latency consistency"
                fi
            fi
        fi
        
        # Set min_perf_pct and max_perf_pct
        if [[ -f /sys/devices/system/cpu/intel_pstate/min_perf_pct ]]; then
            ultra_state_save_module_before "$MOD_ID" "intel_min_perf" "$(cat /sys/devices/system/cpu/intel_pstate/min_perf_pct)"
            if ! ultra_is_dry_run; then
                echo "100" > /sys/devices/system/cpu/intel_pstate/min_perf_pct
                ultra_log_info "Set Intel min_perf_pct to 100%"
            fi
        fi
    fi
    
    # AMD-specific: P-State driver tuning
    if [[ "$cpu_vendor" == "amd" ]] && [[ -d /sys/devices/system/cpu/amd_pstate ]]; then
        ultra_log_info "Configuring AMD P-State driver"
        # AMD P-State tuning can be added here
    fi
}

mod_rollback() {
    ultra_log_info "Rolling back $MOD_ID"
    
    local run_id="$1"
    local state_file="$ULTRA_STATE_DIR/$run_id/${MOD_ID}.json"
    
    if [[ -f "$state_file" ]] && command -v jq &>/dev/null; then
        local governor_before=$(jq -r '.before["cpu_governor"]' "$state_file")
        
        if [[ "$governor_before" != "null" ]] && [[ -n "$governor_before" ]]; then
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                if [[ -f "$cpu" ]]; then
                    echo "$governor_before" > "$cpu" 2>/dev/null || true
                fi
            done
            ultra_log_info "Restored CPU governor to $governor_before"
        fi
        
        # Restore Intel settings
        local no_turbo_before=$(jq -r '.before["intel_no_turbo"]' "$state_file")
        if [[ "$no_turbo_before" != "null" ]] && [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
            echo "$no_turbo_before" > /sys/devices/system/cpu/intel_pstate/no_turbo
        fi
    fi
    
    # Remove systemd service
    if [[ -f /etc/systemd/system/cpu-governor.service ]]; then
        systemctl disable cpu-governor.service >/dev/null 2>&1
        rm -f /etc/systemd/system/cpu-governor.service
        systemctl daemon-reload
    fi
}

mod_verify() {
    local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    ultra_log_info "Current CPU governor: $governor"
    
    # Check all CPUs
    local inconsistent=false
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f "$cpu" ]]; then
            local cpu_gov=$(cat "$cpu")
            if [[ "$cpu_gov" != "$governor" ]]; then
                inconsistent=true
                ultra_log_warn "Inconsistent governor on $(basename $(dirname $(dirname "$cpu"))): $cpu_gov"
            fi
        fi
    done
    
    if [[ "$inconsistent" == "false" ]]; then
        ultra_log_info "All CPUs using same governor ✓"
    fi
}
