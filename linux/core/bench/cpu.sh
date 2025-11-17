#!/bin/bash
# core/bench/cpu.sh - CPU micro-benchmark
# Measures: single-thread, multi-thread, floating-point, integer performance

# Dependency: sysbench (will try to install if missing)

BENCH_CPU_DURATION="${BENCH_CPU_DURATION:-10}"  # seconds per test
BENCH_CPU_THREADS="${BENCH_CPU_THREADS:-}"      # auto-detect if empty

# Check if sysbench is available
ultra_bench_cpu_check_deps() {
    if ! command -v sysbench &>/dev/null; then
        ultra_log_warn "sysbench not found, attempting to install..."
        if command -v apt-get &>/dev/null; then
            if ultra_is_dry_run; then
                ultra_log_info "[DRY-RUN] Would install: apt-get install -y sysbench"
                return 1
            fi
            apt-get update -qq && apt-get install -y sysbench &>/dev/null
            if [[ $? -ne 0 ]]; then
                ultra_log_error "Failed to install sysbench"
                return 1
            fi
            ultra_log_info "sysbench installed successfully"
        else
            ultra_log_error "Package manager not supported, please install sysbench manually"
            return 1
        fi
    fi
    return 0
}

# Run single-threaded CPU benchmark
ultra_bench_cpu_single() {
    local duration="${1:-$BENCH_CPU_DURATION}"
    
    ultra_log_info "Running single-threaded CPU benchmark (${duration}s)..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would run: sysbench cpu --threads=1 --time=$duration run"
        echo '{"events_per_sec": 1234.56, "total_time": 10.0001, "total_events": 12346}'
        return 0
    fi
    
    local output=$(sysbench cpu --threads=1 --time="$duration" run 2>&1)
    local events_per_sec=$(echo "$output" | grep "events per second:" | awk '{print $4}')
    local total_time=$(echo "$output" | grep "total time:" | awk '{print $3}' | sed 's/s$//')
    local total_events=$(echo "$output" | grep "total number of events:" | awk '{print $5}')
    
    cat <<EOF
{
  "test": "cpu_single_thread",
  "threads": 1,
  "duration_sec": $duration,
  "events_per_sec": ${events_per_sec:-0},
  "total_time_sec": ${total_time:-0},
  "total_events": ${total_events:-0}
}
EOF
}

# Run multi-threaded CPU benchmark
ultra_bench_cpu_multi() {
    local duration="${1:-$BENCH_CPU_DURATION}"
    local threads="${2:-$BENCH_CPU_THREADS}"
    
    # Auto-detect threads if not specified
    if [[ -z "$threads" ]]; then
        if command -v nproc &>/dev/null; then
            threads=$(nproc)
        else
            threads=$(grep -c ^processor /proc/cpuinfo)
        fi
    fi
    
    ultra_log_info "Running multi-threaded CPU benchmark (${threads} threads, ${duration}s)..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would run: sysbench cpu --threads=$threads --time=$duration run"
        echo "{\"events_per_sec\": $((threads * 1234)), \"total_time\": 10.0001, \"total_events\": $((threads * 12346))}"
        return 0
    fi
    
    local output=$(sysbench cpu --threads="$threads" --time="$duration" run 2>&1)
    local events_per_sec=$(echo "$output" | grep "events per second:" | awk '{print $4}')
    local total_time=$(echo "$output" | grep "total time:" | awk '{print $3}' | sed 's/s$//')
    local total_events=$(echo "$output" | grep "total number of events:" | awk '{print $5}')
    
    cat <<EOF
{
  "test": "cpu_multi_thread",
  "threads": $threads,
  "duration_sec": $duration,
  "events_per_sec": ${events_per_sec:-0},
  "total_time_sec": ${total_time:-0},
  "total_events": ${total_events:-0}
}
EOF
}

# Run prime number calculation benchmark
ultra_bench_cpu_prime() {
    local max_prime="${1:-20000}"
    local threads="${2:-1}"
    
    ultra_log_info "Running CPU prime number benchmark (max=$max_prime, threads=$threads)..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would run: sysbench cpu --cpu-max-prime=$max_prime --threads=$threads run"
        echo '{"events_per_sec": 567.89, "total_time": 5.1234}'
        return 0
    fi
    
    local output=$(sysbench cpu --cpu-max-prime="$max_prime" --threads="$threads" --time=30 run 2>&1)
    local events_per_sec=$(echo "$output" | grep "events per second:" | awk '{print $4}')
    local total_time=$(echo "$output" | grep "total time:" | awk '{print $3}' | sed 's/s$//')
    
    cat <<EOF
{
  "test": "cpu_prime",
  "max_prime": $max_prime,
  "threads": $threads,
  "events_per_sec": ${events_per_sec:-0},
  "total_time_sec": ${total_time:-0}
}
EOF
}

# Get CPU frequency info
ultra_bench_cpu_freq_info() {
    local cpu0_freq=""
    local cpu0_freq_max=""
    local cpu0_freq_min=""
    
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]]; then
        cpu0_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "0")
        cpu0_freq_max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo "0")
        cpu0_freq_min=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null || echo "0")
        # Convert KHz to MHz
        cpu0_freq=$((cpu0_freq / 1000))
        cpu0_freq_max=$((cpu0_freq_max / 1000))
        cpu0_freq_min=$((cpu0_freq_min / 1000))
    fi
    
    local governor=""
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    fi
    
    cat <<EOF
{
  "current_freq_mhz": ${cpu0_freq:-0},
  "max_freq_mhz": ${cpu0_freq_max:-0},
  "min_freq_mhz": ${cpu0_freq_min:-0},
  "governor": "$governor"
}
EOF
}

# Run comprehensive CPU benchmark suite
ultra_bench_cpu_suite() {
    local duration="${1:-10}"
    local output_file="${2:-}"
    
    ultra_log_section "CPU Benchmark Suite"
    
    if ! ultra_bench_cpu_check_deps; then
        ultra_log_error "Cannot run CPU benchmarks: sysbench not available"
        return 1
    fi
    
    local hw_info=""
    if command -v ultra_hw_cpu_get_info &>/dev/null; then
        hw_info=$(ultra_hw_cpu_get_info || echo '{}')
    else
        hw_info='{}'
    fi
    
    local freq_info=$(ultra_bench_cpu_freq_info)
    
    ultra_log_info "Hardware info: $(echo "$hw_info" | jq -c . 2>/dev/null || echo "$hw_info")"
    ultra_log_info "Frequency info: $(echo "$freq_info" | jq -c . 2>/dev/null || echo "$freq_info")"
    
    local result_single=$(ultra_bench_cpu_single "$duration")
    local result_multi=$(ultra_bench_cpu_multi "$duration")
    local result_prime=$(ultra_bench_cpu_prime 20000 1)
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local results=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "benchmark": "cpu",
  "hardware": $hw_info,
  "frequency": $freq_info,
  "results": {
    "single_thread": $result_single,
    "multi_thread": $result_multi,
    "prime_calculation": $result_prime
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
    local single_score=$(echo "$result_single" | jq -r '.events_per_sec' 2>/dev/null || echo "N/A")
    local multi_score=$(echo "$result_multi" | jq -r '.events_per_sec' 2>/dev/null || echo "N/A")
    
    ultra_log_info "Summary: Single-thread=$single_score events/sec, Multi-thread=$multi_score events/sec"
    
    return 0
}

# Quick CPU stress test (useful for testing governor changes)
ultra_bench_cpu_stress() {
    local duration="${1:-5}"
    
    ultra_log_info "Running CPU stress test for ${duration}s..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would run stress test"
        return 0
    fi
    
    if command -v stress-ng &>/dev/null; then
        stress-ng --cpu 0 --timeout "${duration}s" --metrics-brief 2>&1 | head -20
    elif command -v stress &>/dev/null; then
        stress --cpu $(nproc) --timeout "${duration}s"
    elif command -v sysbench &>/dev/null; then
        sysbench cpu --threads=$(nproc) --time="$duration" run | grep -E "(events per second|total time)"
    else
        ultra_log_warn "No stress tool available (stress-ng, stress, or sysbench)"
        # Fallback: pure bash CPU burn
        local end=$((SECONDS + duration))
        ultra_log_info "Using bash fallback (less accurate)..."
        while [[ $SECONDS -lt $end ]]; do
            : $((1 + 1))
        done
    fi
}

# Compare two benchmark results
ultra_bench_cpu_compare() {
    local before_file="$1"
    local after_file="$2"
    
    if [[ ! -f "$before_file" ]] || [[ ! -f "$after_file" ]]; then
        ultra_log_error "Benchmark files not found"
        return 1
    fi
    
    ultra_log_section "CPU Benchmark Comparison"
    
    local before_single=$(jq -r '.results.single_thread.events_per_sec' "$before_file" 2>/dev/null || echo "0")
    local after_single=$(jq -r '.results.single_thread.events_per_sec' "$after_file" 2>/dev/null || echo "0")
    
    local before_multi=$(jq -r '.results.multi_thread.events_per_sec' "$before_file" 2>/dev/null || echo "0")
    local after_multi=$(jq -r '.results.multi_thread.events_per_sec' "$after_file" 2>/dev/null || echo "0")
    
    if command -v bc &>/dev/null; then
        local single_diff=$(echo "scale=2; (($after_single - $before_single) / $before_single) * 100" | bc 2>/dev/null || echo "0")
        local multi_diff=$(echo "scale=2; (($after_multi - $before_multi) / $before_multi) * 100" | bc 2>/dev/null || echo "0")
        
        ultra_log_info "Single-thread: $before_single → $after_single events/sec (${single_diff}%)"
        ultra_log_info "Multi-thread:  $before_multi → $after_multi events/sec (${multi_diff}%)"
    else
        ultra_log_info "Single-thread: $before_single → $after_single events/sec"
        ultra_log_info "Multi-thread:  $before_multi → $after_multi events/sec"
    fi
}

# Export functions if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f ultra_bench_cpu_check_deps
    export -f ultra_bench_cpu_single
    export -f ultra_bench_cpu_multi
    export -f ultra_bench_cpu_prime
    export -f ultra_bench_cpu_freq_info
    export -f ultra_bench_cpu_suite
    export -f ultra_bench_cpu_stress
    export -f ultra_bench_cpu_compare
fi
