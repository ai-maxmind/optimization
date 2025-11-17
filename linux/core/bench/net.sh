#!/bin/bash
# core/bench/net.sh - Network micro-benchmark
# Measures: throughput, latency, packet loss, TCP performance

# Dependency: iperf3, ping (will try to install if missing)

BENCH_NET_DURATION="${BENCH_NET_DURATION:-10}"     # seconds per test
BENCH_NET_SERVER="${BENCH_NET_SERVER:-}"           # iperf3 server (required for client mode)
BENCH_NET_PORT="${BENCH_NET_PORT:-5201}"           # iperf3 port
BENCH_NET_PARALLEL="${BENCH_NET_PARALLEL:-4}"      # parallel streams

# Check if iperf3 is available
ultra_bench_net_check_deps() {
    if ! command -v iperf3 &>/dev/null; then
        ultra_log_warn "iperf3 not found, attempting to install..."
        if command -v apt-get &>/dev/null; then
            if ultra_is_dry_run; then
                ultra_log_info "[DRY-RUN] Would install: apt-get install -y iperf3"
                return 1
            fi
            apt-get update -qq && apt-get install -y iperf3 &>/dev/null
            if [[ $? -ne 0 ]]; then
                ultra_log_error "Failed to install iperf3"
                return 1
            fi
            ultra_log_info "iperf3 installed successfully"
        else
            ultra_log_error "Package manager not supported, please install iperf3 manually"
            return 1
        fi
    fi
    return 0
}

# Start iperf3 server
ultra_bench_net_start_server() {
    local port="${1:-$BENCH_NET_PORT}"
    
    ultra_log_info "Starting iperf3 server on port $port..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would run: iperf3 -s -p $port -D"
        return 0
    fi
    
    # Check if server is already running
    if pgrep -f "iperf3.*-s.*-p.*$port" &>/dev/null; then
        ultra_log_warn "iperf3 server already running on port $port"
        return 0
    fi
    
    iperf3 -s -p "$port" -D &>/dev/null
    sleep 1
    
    if pgrep -f "iperf3.*-s.*-p.*$port" &>/dev/null; then
        ultra_log_info "iperf3 server started successfully"
        return 0
    else
        ultra_log_error "Failed to start iperf3 server"
        return 1
    fi
}

# Stop iperf3 server
ultra_bench_net_stop_server() {
    ultra_log_info "Stopping iperf3 server..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would kill iperf3 server"
        return 0
    fi
    
    pkill -f "iperf3.*-s" 2>/dev/null
    sleep 1
    
    if ! pgrep -f "iperf3.*-s" &>/dev/null; then
        ultra_log_info "iperf3 server stopped"
        return 0
    else
        ultra_log_warn "Failed to stop iperf3 server"
        return 1
    fi
}

# TCP throughput test
ultra_bench_net_tcp_throughput() {
    local server="${1:-$BENCH_NET_SERVER}"
    local duration="${2:-$BENCH_NET_DURATION}"
    local port="${3:-$BENCH_NET_PORT}"
    local parallel="${4:-$BENCH_NET_PARALLEL}"
    
    if [[ -z "$server" ]]; then
        ultra_log_error "Server address required for throughput test"
        return 1
    fi
    
    ultra_log_info "Running TCP throughput test to $server (${parallel} streams, ${duration}s)..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would run: iperf3 -c $server -p $port -P $parallel -t $duration"
        echo '{"throughput_gbps": 9.45, "retransmits": 12, "sender_cpu": 35, "receiver_cpu": 42}'
        return 0
    fi
    
    local output=$(iperf3 -c "$server" -p "$port" -P "$parallel" -t "$duration" -J 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$output" ]]; then
        ultra_log_error "iperf3 test failed"
        return 1
    fi
    
    local throughput=$(echo "$output" | jq -r '.end.sum_received.bits_per_second / 1000000000' 2>/dev/null || echo "0")
    local retransmits=$(echo "$output" | jq -r '.end.sum_sent.retransmits // 0' 2>/dev/null || echo "0")
    local sender_cpu=$(echo "$output" | jq -r '.end.cpu_utilization_percent.host_total // 0' 2>/dev/null || echo "0")
    local receiver_cpu=$(echo "$output" | jq -r '.end.cpu_utilization_percent.remote_total // 0' 2>/dev/null || echo "0")
    
    cat <<EOF
{
  "throughput_gbps": $throughput,
  "retransmits": $retransmits,
  "sender_cpu_percent": $sender_cpu,
  "receiver_cpu_percent": $receiver_cpu
}
EOF
}

# UDP throughput and packet loss test
ultra_bench_net_udp_throughput() {
    local server="${1:-$BENCH_NET_SERVER}"
    local duration="${2:-$BENCH_NET_DURATION}"
    local port="${3:-$BENCH_NET_PORT}"
    local bandwidth="${4:-10G}"  # Target bandwidth
    
    if [[ -z "$server" ]]; then
        ultra_log_error "Server address required for UDP test"
        return 1
    fi
    
    ultra_log_info "Running UDP throughput test to $server (target: $bandwidth, ${duration}s)..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would run: iperf3 -c $server -u -b $bandwidth -t $duration"
        echo '{"throughput_gbps": 8.95, "jitter_ms": 0.045, "lost_percent": 0.12}'
        return 0
    fi
    
    local output=$(iperf3 -c "$server" -p "$port" -u -b "$bandwidth" -t "$duration" -J 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$output" ]]; then
        ultra_log_error "iperf3 UDP test failed"
        return 1
    fi
    
    local throughput=$(echo "$output" | jq -r '.end.sum.bits_per_second / 1000000000' 2>/dev/null || echo "0")
    local jitter=$(echo "$output" | jq -r '.end.sum.jitter_ms // 0' 2>/dev/null || echo "0")
    local lost_percent=$(echo "$output" | jq -r '.end.sum.lost_percent // 0' 2>/dev/null || echo "0")
    
    cat <<EOF
{
  "throughput_gbps": $throughput,
  "jitter_ms": $jitter,
  "lost_percent": $lost_percent
}
EOF
}

# Ping latency test
ultra_bench_net_ping_latency() {
    local target="${1:-$BENCH_NET_SERVER}"
    local count="${2:-100}"
    
    if [[ -z "$target" ]]; then
        ultra_log_error "Target address required for ping test"
        return 1
    fi
    
    ultra_log_info "Running ping latency test to $target ($count packets)..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would run: ping -c $count $target"
        echo '{"min_ms": 0.123, "avg_ms": 0.456, "max_ms": 2.345, "stddev_ms": 0.234, "loss_percent": 0}'
        return 0
    fi
    
    local output=$(ping -c "$count" -q "$target" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        ultra_log_error "ping test failed"
        return 1
    fi
    
    local min=$(echo "$output" | grep "rtt min" | awk -F'/' '{print $4}')
    local avg=$(echo "$output" | grep "rtt min" | awk -F'/' '{print $5}')
    local max=$(echo "$output" | grep "rtt min" | awk -F'/' '{print $6}')
    local stddev=$(echo "$output" | grep "rtt min" | awk -F'/' '{print $7}' | awk '{print $1}')
    local loss=$(echo "$output" | grep "packet loss" | awk '{print $6}' | sed 's/%//')
    
    cat <<EOF
{
  "min_ms": ${min:-0},
  "avg_ms": ${avg:-0},
  "max_ms": ${max:-0},
  "stddev_ms": ${stddev:-0},
  "loss_percent": ${loss:-0}
}
EOF
}

# Get network interface info
ultra_bench_net_get_info() {
    local iface="${1:-}"
    
    # Auto-detect primary interface if not specified
    if [[ -z "$iface" ]]; then
        iface=$(ip route | grep default | head -1 | awk '{print $5}')
    fi
    
    if [[ -z "$iface" ]]; then
        echo '{"error": "No network interface found"}'
        return 1
    fi
    
    local speed="unknown"
    if [[ -f "/sys/class/net/$iface/speed" ]]; then
        speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null || echo "unknown")
    fi
    
    local mtu="unknown"
    if command -v ip &>/dev/null; then
        mtu=$(ip link show "$iface" 2>/dev/null | grep mtu | awk '{print $5}')
    fi
    
    local driver="unknown"
    if [[ -L "/sys/class/net/$iface/device/driver" ]]; then
        driver=$(basename $(readlink "/sys/class/net/$iface/device/driver") 2>/dev/null || echo "unknown")
    fi
    
    local queues="unknown"
    if command -v ethtool &>/dev/null; then
        queues=$(ethtool -l "$iface" 2>/dev/null | grep "Combined:" | tail -1 | awk '{print $2}')
    fi
    
    cat <<EOF
{
  "interface": "$iface",
  "speed_mbps": "$speed",
  "mtu": "$mtu",
  "driver": "$driver",
  "queues": "${queues:-unknown}"
}
EOF
}

# Loopback test (localhost performance)
ultra_bench_net_loopback() {
    local duration="${1:-10}"
    local port="${2:-$BENCH_NET_PORT}"
    
    ultra_log_info "Running loopback test on localhost..."
    
    # Start server in background
    ultra_bench_net_start_server "$port"
    sleep 2
    
    local result=$(ultra_bench_net_tcp_throughput "127.0.0.1" "$duration" "$port" 1)
    
    # Stop server
    ultra_bench_net_stop_server
    
    echo "$result"
}

# Run comprehensive network benchmark suite
ultra_bench_net_suite() {
    local server="${1:-}"
    local output_file="${2:-}"
    
    ultra_log_section "Network Benchmark Suite"
    
    if ! ultra_bench_net_check_deps; then
        ultra_log_error "Cannot run network benchmarks: iperf3 not available"
        return 1
    fi
    
    local net_info=$(ultra_bench_net_get_info)
    ultra_log_info "Network info: $(echo "$net_info" | jq -c . 2>/dev/null || echo "$net_info")"
    
    local result_loopback=""
    local result_tcp=""
    local result_udp=""
    local result_ping=""
    
    # Always run loopback test
    ultra_log_info "Testing loopback performance..."
    result_loopback=$(ultra_bench_net_loopback 10)
    
    # If server specified, run remote tests
    if [[ -n "$server" ]]; then
        ultra_log_info "Testing remote server: $server"
        
        result_tcp=$(ultra_bench_net_tcp_throughput "$server" 30 "$BENCH_NET_PORT" 4)
        result_udp=$(ultra_bench_net_udp_throughput "$server" 30 "$BENCH_NET_PORT" "10G")
        result_ping=$(ultra_bench_net_ping_latency "$server" 100)
    else
        ultra_log_warn "No remote server specified, skipping remote tests"
        ultra_log_info "To test remote performance: ultra_bench_net_suite <server_ip>"
        result_tcp='{}'
        result_udp='{}'
        result_ping='{}'
    fi
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local results=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "benchmark": "network",
  "server": "${server:-localhost}",
  "network_info": $net_info,
  "results": {
    "loopback": $result_loopback,
    "tcp_throughput": $result_tcp,
    "udp_throughput": $result_udp,
    "ping_latency": $result_ping
  }
}
EOF
)
    
    if [[ -n "$output_file" ]]; then
        echo "$results" | jq '.' > "$output_file" 2>/dev/null || echo "$results" > "$output_file"
        ultra_log_info "Results saved to: $output_file"
    else
        echo "$results" | jq '.' 2>/dev/null || echo "$results"
    fi
    
    # Log summary
    local loopback_gbps=$(echo "$result_loopback" | jq -r '.throughput_gbps' 2>/dev/null || echo "N/A")
    ultra_log_info "Summary: Loopback=${loopback_gbps}Gbps"
    
    if [[ -n "$server" ]]; then
        local tcp_gbps=$(echo "$result_tcp" | jq -r '.throughput_gbps' 2>/dev/null || echo "N/A")
        local ping_avg=$(echo "$result_ping" | jq -r '.avg_ms' 2>/dev/null || echo "N/A")
        ultra_log_info "Remote: TCP=${tcp_gbps}Gbps, Ping=${ping_avg}ms"
    fi
    
    return 0
}

# Compare two benchmark results
ultra_bench_net_compare() {
    local before_file="$1"
    local after_file="$2"
    
    if [[ ! -f "$before_file" ]] || [[ ! -f "$after_file" ]]; then
        ultra_log_error "Benchmark files not found"
        return 1
    fi
    
    ultra_log_section "Network Benchmark Comparison"
    
    local before_loopback=$(jq -r '.results.loopback.throughput_gbps' "$before_file" 2>/dev/null || echo "0")
    local after_loopback=$(jq -r '.results.loopback.throughput_gbps' "$after_file" 2>/dev/null || echo "0")
    
    local before_tcp=$(jq -r '.results.tcp_throughput.throughput_gbps' "$before_file" 2>/dev/null || echo "0")
    local after_tcp=$(jq -r '.results.tcp_throughput.throughput_gbps' "$after_file" 2>/dev/null || echo "0")
    
    local before_ping=$(jq -r '.results.ping_latency.avg_ms' "$before_file" 2>/dev/null || echo "0")
    local after_ping=$(jq -r '.results.ping_latency.avg_ms' "$after_file" 2>/dev/null || echo "0")
    
    if command -v bc &>/dev/null; then
        local loopback_diff=$(echo "scale=2; (($after_loopback - $before_loopback) / $before_loopback) * 100" | bc 2>/dev/null || echo "0")
        local tcp_diff=$(echo "scale=2; (($after_tcp - $before_tcp) / $before_tcp) * 100" | bc 2>/dev/null || echo "0")
        local ping_diff=$(echo "scale=2; (($after_ping - $before_ping) / $before_ping) * 100" | bc 2>/dev/null || echo "0")
        
        ultra_log_info "Loopback: $before_loopback → $after_loopback Gbps (${loopback_diff}%)"
        [[ "$before_tcp" != "0" ]] && ultra_log_info "TCP:      $before_tcp → $after_tcp Gbps (${tcp_diff}%)"
        [[ "$before_ping" != "0" ]] && ultra_log_info "Ping:     $before_ping → $after_ping ms (${ping_diff}%)"
    else
        ultra_log_info "Loopback: $before_loopback → $after_loopback Gbps"
        [[ "$before_tcp" != "0" ]] && ultra_log_info "TCP:      $before_tcp → $after_tcp Gbps"
        [[ "$before_ping" != "0" ]] && ultra_log_info "Ping:     $before_ping → $after_ping ms"
    fi
}

# Export functions if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f ultra_bench_net_check_deps
    export -f ultra_bench_net_start_server
    export -f ultra_bench_net_stop_server
    export -f ultra_bench_net_tcp_throughput
    export -f ultra_bench_net_udp_throughput
    export -f ultra_bench_net_ping_latency
    export -f ultra_bench_net_get_info
    export -f ultra_bench_net_loopback
    export -f ultra_bench_net_suite
    export -f ultra_bench_net_compare
fi
