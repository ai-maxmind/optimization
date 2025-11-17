#!/bin/bash
################################################################################
# MODULE: net.core.tcp-buffers
# Optimize TCP buffer sizes for high throughput
################################################################################

MOD_ID="net.core.tcp-buffers"
MOD_DESC="Optimize TCP buffer sizes based on network speed and RAM"
MOD_STAGE="net"
MOD_RISK="low"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    return 0
}

mod_apply() {
    ultra_log_info "Applying $MOD_DESC"
    
    local mem_gb=$(ultra_hw_mem_get_total_gb)
    local profile=$(ultra_get_profile)
    
    # Buffer sizes in bytes: min default max
    # Formula: based on bandwidth-delay product (BDP)
    # For 10Gbps with 100ms RTT: BDP = 10Gbps * 100ms = 125MB
    
    local rmem_min=4096
    local rmem_default=131072      # 128KB
    local rmem_max=134217728       # 128MB
    
    local wmem_min=4096
    local wmem_default=131072      # 128KB
    local wmem_max=134217728       # 128MB
    
    local netdev_max_backlog=5000
    local somaxconn=4096
    
    # Adjust based on RAM
    if (( mem_gb >= 32 )); then
        rmem_max=268435456  # 256MB
        wmem_max=268435456  # 256MB
        netdev_max_backlog=10000
        somaxconn=8192
    elif (( mem_gb >= 16 )); then
        rmem_max=134217728  # 128MB
        wmem_max=134217728  # 128MB
        netdev_max_backlog=5000
        somaxconn=4096
    else
        rmem_max=67108864   # 64MB
        wmem_max=67108864   # 64MB
        netdev_max_backlog=2500
        somaxconn=2048
    fi
    
    # Profile-specific tuning
    case "$profile" in
        server|db)
            # Server needs large buffers for throughput
            ;;
        lowlatency)
            # Low latency might prefer smaller buffers
            rmem_default=65536   # 64KB
            wmem_default=65536   # 64KB
            ;;
        desktop)
            # Desktop: balance
            rmem_max=$((rmem_max / 2))
            wmem_max=$((wmem_max / 2))
            ;;
    esac
    
    ultra_log_info "TCP buffer configuration (RAM: ${mem_gb}GB):"
    ultra_log_info "  rmem: min=$rmem_min, default=$rmem_default, max=$rmem_max"
    ultra_log_info "  wmem: min=$wmem_min, default=$wmem_default, max=$wmem_max"
    
    # TCP read buffer (receive)
    ultra_sysctl_save_and_set "net.ipv4.tcp_rmem" "$rmem_min $rmem_default $rmem_max" "$MOD_ID"
    
    # TCP write buffer (send)
    ultra_sysctl_save_and_set "net.ipv4.tcp_wmem" "$wmem_min $wmem_default $wmem_max" "$MOD_ID"
    
    # Core socket buffers
    ultra_sysctl_save_and_set "net.core.rmem_max" "$rmem_max" "$MOD_ID"
    ultra_sysctl_save_and_set "net.core.wmem_max" "$wmem_max" "$MOD_ID"
    ultra_sysctl_save_and_set "net.core.rmem_default" "$rmem_default" "$MOD_ID"
    ultra_sysctl_save_and_set "net.core.wmem_default" "$wmem_default" "$MOD_ID"
    
    # Netdev backlog (packets queued on input side)
    ultra_sysctl_save_and_set "net.core.netdev_max_backlog" "$netdev_max_backlog" "$MOD_ID"
    
    # Max pending connections
    ultra_sysctl_save_and_set "net.core.somaxconn" "$somaxconn" "$MOD_ID"
    
    # TCP memory limits (pages)
    # Formula: tcp_mem = (min, pressure, max) in pages (4KB)
    local page_size=4096
    local tcp_mem_min=$((mem_gb * 1024 * 1024 * 1024 / page_size / 32))    # ~3% of RAM
    local tcp_mem_pressure=$((mem_gb * 1024 * 1024 * 1024 / page_size / 16)) # ~6% of RAM
    local tcp_mem_max=$((mem_gb * 1024 * 1024 * 1024 / page_size / 8))      # ~12% of RAM
    
    ultra_sysctl_save_and_set "net.ipv4.tcp_mem" "$tcp_mem_min $tcp_mem_pressure $tcp_mem_max" "$MOD_ID"
    
    # TCP window scaling (enable for high-bandwidth networks)
    ultra_sysctl_save_and_set "net.ipv4.tcp_window_scaling" "1" "$MOD_ID"
    
    # TCP timestamps (helps with RTT estimation)
    ultra_sysctl_save_and_set "net.ipv4.tcp_timestamps" "1" "$MOD_ID"
    
    # TCP SACK (Selective Acknowledgment)
    ultra_sysctl_save_and_set "net.ipv4.tcp_sack" "1" "$MOD_ID"
    
    # TCP Fast Open
    ultra_sysctl_save_and_set "net.ipv4.tcp_fastopen" "3" "$MOD_ID"  # Enable for client+server
    
    # TCP congestion control: BBR (if available)
    if lsmod | grep -q tcp_bbr || modprobe tcp_bbr 2>/dev/null; then
        ultra_sysctl_save_and_set "net.ipv4.tcp_congestion_control" "bbr" "$MOD_ID"
        ultra_sysctl_save_and_set "net.core.default_qdisc" "fq" "$MOD_ID"  # Fair Queue for BBR
        ultra_log_info "Enabled TCP BBR congestion control"
    else
        ultra_log_warn "TCP BBR not available, using default congestion control"
    fi
}

mod_rollback() {
    ultra_log_info "Rolling back $MOD_ID"
    
    local run_id="$1"
    local state_file="$ULTRA_STATE_DIR/$run_id/${MOD_ID}.json"
    
    if [[ -f "$state_file" ]] && command -v jq &>/dev/null; then
        local keys=(
            "net.ipv4.tcp_rmem"
            "net.ipv4.tcp_wmem"
            "net.core.rmem_max"
            "net.core.wmem_max"
            "net.core.rmem_default"
            "net.core.wmem_default"
            "net.core.netdev_max_backlog"
            "net.core.somaxconn"
            "net.ipv4.tcp_mem"
            "net.ipv4.tcp_window_scaling"
            "net.ipv4.tcp_timestamps"
            "net.ipv4.tcp_sack"
            "net.ipv4.tcp_fastopen"
            "net.ipv4.tcp_congestion_control"
            "net.core.default_qdisc"
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
    ultra_log_info "Current TCP buffer configuration:"
    ultra_log_info "  tcp_rmem: $(ultra_sysctl_get_current net.ipv4.tcp_rmem)"
    ultra_log_info "  tcp_wmem: $(ultra_sysctl_get_current net.ipv4.tcp_wmem)"
    ultra_log_info "  rmem_max: $(ultra_sysctl_get_current net.core.rmem_max)"
    ultra_log_info "  wmem_max: $(ultra_sysctl_get_current net.core.wmem_max)"
    ultra_log_info "  netdev_max_backlog: $(ultra_sysctl_get_current net.core.netdev_max_backlog)"
    ultra_log_info "  somaxconn: $(ultra_sysctl_get_current net.core.somaxconn)"
    ultra_log_info "  congestion_control: $(ultra_sysctl_get_current net.ipv4.tcp_congestion_control)"
}
