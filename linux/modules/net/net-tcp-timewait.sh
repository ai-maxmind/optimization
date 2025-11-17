#!/bin/bash
# modules/net/net-tcp-timewait.sh
# Module: TCP TIME_WAIT optimization
# Reduces TIME_WAIT socket overhead for high-connection servers

MOD_ID="net.tcp-timewait"
MOD_DESC="TCP TIME_WAIT optimization"
MOD_STAGE="net"
MOD_RISK="medium"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    local profile=$(ultra_get_profile)
    
    # Most useful for server profiles with high connection rates
    if [[ "$profile" == "server" ]] || [[ "$profile" == "db" ]] || [[ "$profile" == "lowlatency" ]]; then
        return 0
    fi
    
    # Desktop doesn't need this
    return 1
}

mod_apply() {
    ultra_log_module_start "$MOD_ID"
    ultra_log_info "Applying TCP TIME_WAIT optimization..."
    
    local profile=$(ultra_get_profile)
    
    # TCP TIME_WAIT optimization parameters:
    # 1. tcp_fin_timeout: How long to wait for final FIN (default: 60s)
    # 2. tcp_max_tw_buckets: Max TIME_WAIT sockets (default: varies)
    # 3. tcp_tw_reuse: Reuse TIME_WAIT sockets for new connections (safe)
    
    # Note: tcp_tw_recycle is REMOVED in kernel 4.12+ (not safe with NAT)
    # We use tcp_tw_reuse instead which is safe
    
    local fin_timeout=30
    local max_tw_buckets=2000000
    local tw_reuse=1
    
    case "$profile" in
        server)
            # Web servers benefit from faster TIME_WAIT cleanup
            fin_timeout=30
            max_tw_buckets=2000000
            tw_reuse=1
            ;;
        db)
            # Databases may have persistent connections
            # Still reduce TIME_WAIT but less aggressive
            fin_timeout=35
            max_tw_buckets=1000000
            tw_reuse=1
            ;;
        lowlatency)
            # Fastest cleanup for low-latency workloads
            fin_timeout=20
            max_tw_buckets=3000000
            tw_reuse=1
            ;;
        *)
            fin_timeout=30
            max_tw_buckets=1000000
            tw_reuse=1
            ;;
    esac
    
    ultra_log_info "TCP TIME_WAIT parameters:"
    ultra_log_info "  tcp_fin_timeout: $fin_timeout seconds"
    ultra_log_info "  tcp_max_tw_buckets: $max_tw_buckets"
    ultra_log_info "  tcp_tw_reuse: $tw_reuse (enable)"
    
    if ! ultra_is_dry_run; then
        ultra_sysctl_save_and_set "net.ipv4.tcp_fin_timeout" "$fin_timeout" "$MOD_ID"
        ultra_sysctl_save_and_set "net.ipv4.tcp_max_tw_buckets" "$max_tw_buckets" "$MOD_ID"
        ultra_sysctl_save_and_set "net.ipv4.tcp_tw_reuse" "$tw_reuse" "$MOD_ID"
        
        ultra_state_add_action "$MOD_ID" "sysctl" "Set tcp_fin_timeout=$fin_timeout"
        ultra_state_add_action "$MOD_ID" "sysctl" "Set tcp_max_tw_buckets=$max_tw_buckets"
        ultra_state_add_action "$MOD_ID" "sysctl" "Set tcp_tw_reuse=$tw_reuse"
        
        ultra_log_info "✅ TCP TIME_WAIT optimization applied"
    else
        ultra_log_info "[DRY-RUN] Would optimize TCP TIME_WAIT"
    fi
    
    # Warn about tcp_tw_recycle (removed in modern kernels)
    if [[ -f /proc/sys/net/ipv4/tcp_tw_recycle ]] 2>/dev/null; then
        ultra_log_warn "⚠️  tcp_tw_recycle exists but should NOT be used (unsafe with NAT)"
        ultra_log_warn "Using tcp_tw_reuse instead which is safe"
    fi
    
    ultra_state_finalize_module "$MOD_ID" "success"
    ultra_log_module_end "$MOD_ID"
}

mod_rollback() {
    local run_id="$1"
    local state_file="$ULTRA_STATE_DIR/$run_id/${MOD_ID}.json"
    
    ultra_log_info "Rolling back $MOD_DESC..."
    
    if [[ -f "$state_file" ]] && command -v jq &>/dev/null; then
        local fin_timeout=$(jq -r '.before["sysctl:net.ipv4.tcp_fin_timeout"]' "$state_file" 2>/dev/null)
        local max_tw=$(jq -r '.before["sysctl:net.ipv4.tcp_max_tw_buckets"]' "$state_file" 2>/dev/null)
        local tw_reuse=$(jq -r '.before["sysctl:net.ipv4.tcp_tw_reuse"]' "$state_file" 2>/dev/null)
        
        [[ -n "$fin_timeout" ]] && [[ "$fin_timeout" != "null" ]] && \
            ultra_sysctl_restore "net.ipv4.tcp_fin_timeout" "$fin_timeout" "$MOD_ID"
        
        [[ -n "$max_tw" ]] && [[ "$max_tw" != "null" ]] && \
            ultra_sysctl_restore "net.ipv4.tcp_max_tw_buckets" "$max_tw" "$MOD_ID"
        
        [[ -n "$tw_reuse" ]] && [[ "$tw_reuse" != "null" ]] && \
            ultra_sysctl_restore "net.ipv4.tcp_tw_reuse" "$tw_reuse" "$MOD_ID"
    else
        ultra_log_warn "No state file, restoring to defaults"
        sysctl -w net.ipv4.tcp_fin_timeout=60 &>/dev/null
        sysctl -w net.ipv4.tcp_tw_reuse=2 &>/dev/null  # default in newer kernels
    fi
}

mod_verify() {
    ultra_log_info "TCP TIME_WAIT Settings:"
    ultra_log_info "  tcp_fin_timeout: $(ultra_sysctl_get_current net.ipv4.tcp_fin_timeout)"
    ultra_log_info "  tcp_max_tw_buckets: $(ultra_sysctl_get_current net.ipv4.tcp_max_tw_buckets)"
    ultra_log_info "  tcp_tw_reuse: $(ultra_sysctl_get_current net.ipv4.tcp_tw_reuse)"
    
    # Show current TIME_WAIT count
    if command -v ss &>/dev/null; then
        local tw_count=$(ss -tan | grep TIME-WAIT | wc -l)
        ultra_log_info "Current TIME_WAIT sockets: $tw_count"
    elif command -v netstat &>/dev/null; then
        local tw_count=$(netstat -tan | grep TIME_WAIT | wc -l)
        ultra_log_info "Current TIME_WAIT sockets: $tw_count"
    fi
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This module should be run through the orchestrator"
    echo "Usage: ./orchestrator/cli.sh --module $MOD_ID"
    exit 1
fi
