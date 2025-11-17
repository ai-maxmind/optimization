#!/bin/bash
# modules/net/net-tcp-backlog.sh
# Module: TCP listen backlog tuning
# Increases connection queue sizes for high-concurrency servers

MOD_ID="net.tcp-backlog"
MOD_DESC="TCP listen backlog tuning"
MOD_STAGE="net"
MOD_RISK="low"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    local profile=$(ultra_get_profile)
    
    # Useful for all server profiles
    if [[ "$profile" == "server" ]] || [[ "$profile" == "db" ]] || [[ "$profile" == "lowlatency" ]]; then
        return 0
    fi
    
    return 1
}

mod_apply() {
    ultra_log_module_start "$MOD_ID"
    ultra_log_info "Applying TCP backlog optimization..."
    
    local profile=$(ultra_get_profile)
    local ram_gb=$(ultra_hw_mem_get_total_gb 2>/dev/null || echo "8")
    
    # Key parameters:
    # 1. net.core.somaxconn: Max listen() backlog (default: 4096)
    # 2. net.core.netdev_max_backlog: Max packets in input queue (default: 1000)
    # 3. net.ipv4.tcp_max_syn_backlog: Max half-open connections (default: varies)
    
    local somaxconn=65536
    local netdev_backlog=16384
    local syn_backlog=8192
    
    case "$profile" in
        server)
            # Web servers need high connection rates
            somaxconn=65536
            netdev_backlog=16384
            syn_backlog=8192
            ;;
        db)
            # Databases benefit from large backlogs
            somaxconn=65536
            netdev_backlog=32768
            syn_backlog=16384
            ;;
        lowlatency)
            # Balance: high enough but not excessive
            somaxconn=32768
            netdev_backlog=8192
            syn_backlog=4096
            ;;
        *)
            somaxconn=16384
            netdev_backlog=5000
            syn_backlog=4096
            ;;
    esac
    
    # Scale with RAM
    if [[ "$ram_gb" -ge 64 ]]; then
        somaxconn=$((somaxconn * 2))
        netdev_backlog=$((netdev_backlog * 2))
        syn_backlog=$((syn_backlog * 2))
    elif [[ "$ram_gb" -ge 32 ]]; then
        somaxconn=$((somaxconn * 3 / 2))
        netdev_backlog=$((netdev_backlog * 3 / 2))
        syn_backlog=$((syn_backlog * 3 / 2))
    fi
    
    ultra_log_info "TCP backlog parameters (RAM: ${ram_gb}GB):"
    ultra_log_info "  net.core.somaxconn: $somaxconn"
    ultra_log_info "  net.core.netdev_max_backlog: $netdev_backlog"
    ultra_log_info "  net.ipv4.tcp_max_syn_backlog: $syn_backlog"
    
    if ! ultra_is_dry_run; then
        ultra_sysctl_save_and_set "net.core.somaxconn" "$somaxconn" "$MOD_ID"
        ultra_sysctl_save_and_set "net.core.netdev_max_backlog" "$netdev_backlog" "$MOD_ID"
        ultra_sysctl_save_and_set "net.ipv4.tcp_max_syn_backlog" "$syn_backlog" "$MOD_ID"
        
        ultra_state_add_action "$MOD_ID" "sysctl" "Set somaxconn=$somaxconn"
        ultra_state_add_action "$MOD_ID" "sysctl" "Set netdev_max_backlog=$netdev_backlog"
        ultra_state_add_action "$MOD_ID" "sysctl" "Set tcp_max_syn_backlog=$syn_backlog"
        
        ultra_log_info "✅ TCP backlog tuning applied"
        ultra_log_info ""
        ultra_log_info "Application notes:"
        ultra_log_info "  - NGINX: Set 'listen 80 backlog=$somaxconn;'"
        ultra_log_info "  - Apache: Set 'ListenBacklog $somaxconn'"
        ultra_log_info "  - Node.js: server.listen(port, { backlog: $somaxconn })"
    else
        ultra_log_info "[DRY-RUN] Would tune TCP backlog"
    fi
    
    ultra_state_finalize_module "$MOD_ID" "success"
    ultra_log_module_end "$MOD_ID"
}

mod_rollback() {
    local run_id="$1"
    local state_file="$ULTRA_STATE_DIR/$run_id/${MOD_ID}.json"
    
    ultra_log_info "Rolling back $MOD_DESC..."
    
    if [[ -f "$state_file" ]] && command -v jq &>/dev/null; then
        local somaxconn=$(jq -r '.before["sysctl:net.core.somaxconn"]' "$state_file" 2>/dev/null)
        local netdev=$(jq -r '.before["sysctl:net.core.netdev_max_backlog"]' "$state_file" 2>/dev/null)
        local syn=$(jq -r '.before["sysctl:net.ipv4.tcp_max_syn_backlog"]' "$state_file" 2>/dev/null)
        
        [[ -n "$somaxconn" ]] && [[ "$somaxconn" != "null" ]] && \
            ultra_sysctl_restore "net.core.somaxconn" "$somaxconn" "$MOD_ID"
        
        [[ -n "$netdev" ]] && [[ "$netdev" != "null" ]] && \
            ultra_sysctl_restore "net.core.netdev_max_backlog" "$netdev" "$MOD_ID"
        
        [[ -n "$syn" ]] && [[ "$syn" != "null" ]] && \
            ultra_sysctl_restore "net.ipv4.tcp_max_syn_backlog" "$syn" "$MOD_ID"
    else
        ultra_log_warn "No state file, restoring to defaults"
        sysctl -w net.core.somaxconn=4096 &>/dev/null
        sysctl -w net.core.netdev_max_backlog=1000 &>/dev/null
    fi
}

mod_verify() {
    ultra_log_info "TCP Backlog Settings:"
    ultra_log_info "  somaxconn: $(ultra_sysctl_get_current net.core.somaxconn)"
    ultra_log_info "  netdev_max_backlog: $(ultra_sysctl_get_current net.core.netdev_max_backlog)"
    ultra_log_info "  tcp_max_syn_backlog: $(ultra_sysctl_get_current net.ipv4.tcp_max_syn_backlog)"
    
    # Show current listen queue overflows
    if [[ -f /proc/net/netstat ]]; then
        local overflows=$(grep "TcpExt:" /proc/net/netstat | tail -1 | awk '{print $22}')
        ultra_log_info "Listen queue overflows: ${overflows:-0}"
        if [[ "${overflows:-0}" -gt 0 ]]; then
            ultra_log_warn "⚠️  Listen queue overflows detected! Consider increasing backlog."
        fi
    fi
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This module should be run through the orchestrator"
    echo "Usage: ./orchestrator/cli.sh --module $MOD_ID"
    exit 1
fi
