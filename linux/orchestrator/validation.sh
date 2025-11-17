#!/bin/bash
# orchestrator/validation.sh
# Live validation and health checks during optimization

ULTRA_VALIDATION_ENABLED="${ULTRA_VALIDATION_ENABLED:-true}"
declare -A ULTRA_BASELINE_METRICS

# Collect baseline metrics before optimization
ultra_validate_baseline() {
    ultra_log_info "Collecting baseline system metrics..."
    
    # CPU metrics
    ULTRA_BASELINE_METRICS["cpu.load_avg"]=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    ULTRA_BASELINE_METRICS["cpu.context_switches"]=$(grep "^ctxt" /proc/stat | awk '{print $2}')
    
    # Memory metrics
    ULTRA_BASELINE_METRICS["mem.available_kb"]=$(grep "^MemAvailable:" /proc/meminfo | awk '{print $2}')
    ULTRA_BASELINE_METRICS["mem.swap_used_kb"]=$(( $(grep "^SwapTotal:" /proc/meminfo | awk '{print $2}') - $(grep "^SwapFree:" /proc/meminfo | awk '{print $2}') ))
    
    # Network metrics
    local total_rx=0
    local total_tx=0
    for iface in /sys/class/net/*/statistics/rx_bytes; do
        [[ "$iface" =~ "lo" ]] && continue
        local rx=$(cat "$iface" 2>/dev/null || echo 0)
        total_rx=$((total_rx + rx))
    done
    for iface in /sys/class/net/*/statistics/tx_bytes; do
        [[ "$iface" =~ "lo" ]] && continue
        local tx=$(cat "$iface" 2>/dev/null || echo 0)
        total_tx=$((total_tx + tx))
    done
    ULTRA_BASELINE_METRICS["net.rx_bytes"]=$total_rx
    ULTRA_BASELINE_METRICS["net.tx_bytes"]=$total_tx
    
    # Disk I/O
    ULTRA_BASELINE_METRICS["disk.reads"]=$(cat /proc/diskstats | awk '{sum+=$4} END {print sum}')
    ULTRA_BASELINE_METRICS["disk.writes"]=$(cat /proc/diskstats | awk '{sum+=$8} END {print sum}')
    
    ultra_log_debug "Baseline metrics collected"
}

# Validate system health after module apply
ultra_validate_health() {
    local module_id="$1"
    
    if [[ "$ULTRA_VALIDATION_ENABLED" != "true" ]]; then
        return 0
    fi
    
    ultra_log_debug "Validating system health after $module_id"
    
    local issues=0
    
    # Check load average spike
    local current_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local baseline_load=${ULTRA_BASELINE_METRICS["cpu.load_avg"]:-1}
    
    if (( $(echo "$current_load > $baseline_load * 3" | bc -l 2>/dev/null || echo 0) )); then
        ultra_log_warn "Load average spiked: $baseline_load → $current_load"
        ((issues++))
    fi
    
    # Check memory pressure
    local mem_available=$(grep "^MemAvailable:" /proc/meminfo | awk '{print $2}')
    local baseline_mem=${ULTRA_BASELINE_METRICS["mem.available_kb"]:-0}
    
    if [[ $mem_available -lt $((baseline_mem / 2)) ]]; then
        ultra_log_warn "Memory pressure detected: $(($mem_available / 1024))MB available (was $(($baseline_mem / 1024))MB)"
        ((issues++))
    fi
    
    # Check OOM killer
    if dmesg | tail -100 | grep -q "Out of memory"; then
        ultra_log_error "OOM killer triggered!"
        ((issues++))
    fi
    
    # Check kernel errors
    local kernel_errors=$(dmesg | tail -50 | grep -ic "error\|failed\|critical")
    if [[ $kernel_errors -gt 5 ]]; then
        ultra_log_warn "Kernel errors detected: $kernel_errors messages"
        ((issues++))
    fi
    
    # Check network connectivity
    if ! ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
        if ! ping -c 1 -W 1 1.1.1.1 &>/dev/null; then
            ultra_log_error "Network connectivity lost!"
            ((issues++))
        fi
    fi
    
    # Check critical services
    local critical_services=("systemd-journald" "dbus")
    for service in "${critical_services[@]}"; do
        if ! systemctl is-active "$service" &>/dev/null; then
            ultra_log_error "Critical service $service is not active!"
            ((issues++))
        fi
    done
    
    if [[ $issues -gt 0 ]]; then
        ultra_log_warn "Validation found $issues potential issues"
        return 1
    fi
    
    ultra_log_debug "System health check passed"
    return 0
}

# Verify specific module changes
ultra_validate_module() {
    local module_id="$1"
    
    ultra_log_debug "Validating module $module_id changes"
    
    # Call module's verify function if available
    if type mod_verify &>/dev/null; then
        if mod_verify; then
            ultra_log_debug "Module verification passed"
            return 0
        else
            ultra_log_warn "Module verification failed"
            return 1
        fi
    fi
    
    return 0
}

# Smart rollback on validation failure
ultra_validate_rollback_on_failure() {
    local module_id="$1"
    local validation_result="$2"
    
    if [[ $validation_result -ne 0 ]]; then
        ultra_log_error "Validation failed for $module_id"
        
        if [[ "${ULTRA_AUTO_ROLLBACK:-true}" == "true" ]]; then
            ultra_log_warn "Auto-rollback enabled, reverting $module_id"
            
            if type mod_rollback &>/dev/null; then
                mod_rollback "$ULTRA_CURRENT_RUN_ID"
                ultra_log_info "Module $module_id rolled back"
            else
                ultra_log_error "Module $module_id has no rollback function"
            fi
            
            return 1
        fi
    fi
    
    return 0
}

# Compare before/after performance
ultra_validate_performance() {
    local metric_type="$1"  # cpu, memory, disk, network
    local threshold="${2:-10}"  # % degradation threshold
    
    ultra_log_info "Comparing $metric_type performance (threshold: ${threshold}% degradation)"
    
    case "$metric_type" in
        cpu)
            local before=${ULTRA_BASELINE_METRICS["cpu.context_switches"]:-0}
            local after=$(grep "^ctxt" /proc/stat | awk '{print $2}')
            local change=$(( (after - before) * 100 / before ))
            
            if [[ $change -gt $threshold ]]; then
                ultra_log_warn "CPU context switches increased by ${change}%"
                return 1
            fi
            ;;
        memory)
            local before=${ULTRA_BASELINE_METRICS["mem.available_kb"]:-0}
            local after=$(grep "^MemAvailable:" /proc/meminfo | awk '{print $2}')
            local change=$(( (before - after) * 100 / before ))
            
            if [[ $change -gt $threshold ]]; then
                ultra_log_warn "Available memory decreased by ${change}%"
                return 1
            fi
            ;;
    esac
    
    ultra_log_info "Performance check passed for $metric_type"
    return 0
}
