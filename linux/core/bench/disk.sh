#!/bin/bash
# core/bench/disk.sh - Disk I/O micro-benchmark
# Measures: sequential read/write, random read/write, latency, IOPS

# Dependency: fio (will try to install if missing)

BENCH_DISK_SIZE="${BENCH_DISK_SIZE:-1G}"           # Test file size
BENCH_DISK_DURATION="${BENCH_DISK_DURATION:-30}"   # seconds per test
BENCH_DISK_RUNTIME="${BENCH_DISK_RUNTIME:-30}"     # runtime for fio
BENCH_DISK_DIR="${BENCH_DISK_DIR:-/tmp}"           # Test directory
BENCH_DISK_JOBS="${BENCH_DISK_JOBS:-4}"            # Number of parallel jobs

# Check if fio is available
ultra_bench_disk_check_deps() {
    if ! command -v fio &>/dev/null; then
        ultra_log_warn "fio not found, attempting to install..."
        if command -v apt-get &>/dev/null; then
            if ultra_is_dry_run; then
                ultra_log_info "[DRY-RUN] Would install: apt-get install -y fio"
                return 1
            fi
            apt-get update -qq && apt-get install -y fio &>/dev/null
            if [[ $? -ne 0 ]]; then
                ultra_log_error "Failed to install fio"
                return 1
            fi
            ultra_log_info "fio installed successfully"
        else
            ultra_log_error "Package manager not supported, please install fio manually"
            return 1
        fi
    fi
    return 0
}

# Sequential read benchmark
ultra_bench_disk_seq_read() {
    local test_dir="${1:-$BENCH_DISK_DIR}"
    local size="${2:-$BENCH_DISK_SIZE}"
    local runtime="${3:-$BENCH_DISK_RUNTIME}"
    
    ultra_log_info "Running sequential read benchmark..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would run: fio --name=seq_read --directory=$test_dir --size=$size"
        echo '{"read_bw_mb": 1234.56, "read_iops": 308, "read_lat_ms": 3.25}'
        return 0
    fi
    
    local output=$(fio --name=seq_read \
        --directory="$test_dir" \
        --size="$size" \
        --runtime="$runtime" \
        --time_based \
        --ioengine=libaio \
        --direct=1 \
        --bs=1M \
        --iodepth=32 \
        --rw=read \
        --numjobs=1 \
        --group_reporting \
        --output-format=json 2>/dev/null)
    
    local read_bw=$(echo "$output" | jq -r '.jobs[0].read.bw / 1024' 2>/dev/null || echo "0")
    local read_iops=$(echo "$output" | jq -r '.jobs[0].read.iops' 2>/dev/null || echo "0")
    local read_lat=$(echo "$output" | jq -r '.jobs[0].read.lat_ns.mean / 1000000' 2>/dev/null || echo "0")
    
    cat <<EOF
{
  "read_bw_mb": $read_bw,
  "read_iops": ${read_iops%.*},
  "read_lat_ms": $read_lat
}
EOF
}

# Sequential write benchmark
ultra_bench_disk_seq_write() {
    local test_dir="${1:-$BENCH_DISK_DIR}"
    local size="${2:-$BENCH_DISK_SIZE}"
    local runtime="${3:-$BENCH_DISK_RUNTIME}"
    
    ultra_log_info "Running sequential write benchmark..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would run: fio --name=seq_write --directory=$test_dir --size=$size"
        echo '{"write_bw_mb": 987.65, "write_iops": 246, "write_lat_ms": 4.05}'
        return 0
    fi
    
    local output=$(fio --name=seq_write \
        --directory="$test_dir" \
        --size="$size" \
        --runtime="$runtime" \
        --time_based \
        --ioengine=libaio \
        --direct=1 \
        --bs=1M \
        --iodepth=32 \
        --rw=write \
        --numjobs=1 \
        --group_reporting \
        --output-format=json 2>/dev/null)
    
    local write_bw=$(echo "$output" | jq -r '.jobs[0].write.bw / 1024' 2>/dev/null || echo "0")
    local write_iops=$(echo "$output" | jq -r '.jobs[0].write.iops' 2>/dev/null || echo "0")
    local write_lat=$(echo "$output" | jq -r '.jobs[0].write.lat_ns.mean / 1000000' 2>/dev/null || echo "0")
    
    cat <<EOF
{
  "write_bw_mb": $write_bw,
  "write_iops": ${write_iops%.*},
  "write_lat_ms": $write_lat
}
EOF
}

# Random read benchmark (4K IOPS)
ultra_bench_disk_rand_read() {
    local test_dir="${1:-$BENCH_DISK_DIR}"
    local size="${2:-$BENCH_DISK_SIZE}"
    local runtime="${3:-$BENCH_DISK_RUNTIME}"
    local jobs="${4:-$BENCH_DISK_JOBS}"
    
    ultra_log_info "Running random read benchmark (4K, ${jobs} jobs)..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would run: fio --name=rand_read --bs=4k --rw=randread"
        echo '{"read_iops": 45678, "read_bw_mb": 178.43, "read_lat_us": 175.2}'
        return 0
    fi
    
    local output=$(fio --name=rand_read \
        --directory="$test_dir" \
        --size="$size" \
        --runtime="$runtime" \
        --time_based \
        --ioengine=libaio \
        --direct=1 \
        --bs=4k \
        --iodepth=32 \
        --rw=randread \
        --numjobs="$jobs" \
        --group_reporting \
        --output-format=json 2>/dev/null)
    
    local read_iops=$(echo "$output" | jq -r '.jobs[0].read.iops' 2>/dev/null || echo "0")
    local read_bw=$(echo "$output" | jq -r '.jobs[0].read.bw / 1024' 2>/dev/null || echo "0")
    local read_lat=$(echo "$output" | jq -r '.jobs[0].read.lat_ns.mean / 1000' 2>/dev/null || echo "0")
    
    cat <<EOF
{
  "read_iops": ${read_iops%.*},
  "read_bw_mb": $read_bw,
  "read_lat_us": $read_lat
}
EOF
}

# Random write benchmark (4K IOPS)
ultra_bench_disk_rand_write() {
    local test_dir="${1:-$BENCH_DISK_DIR}"
    local size="${2:-$BENCH_DISK_SIZE}"
    local runtime="${3:-$BENCH_DISK_RUNTIME}"
    local jobs="${4:-$BENCH_DISK_JOBS}"
    
    ultra_log_info "Running random write benchmark (4K, ${jobs} jobs)..."
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would run: fio --name=rand_write --bs=4k --rw=randwrite"
        echo '{"write_iops": 32456, "write_bw_mb": 126.78, "write_lat_us": 245.6}'
        return 0
    fi
    
    local output=$(fio --name=rand_write \
        --directory="$test_dir" \
        --size="$size" \
        --runtime="$runtime" \
        --time_based \
        --ioengine=libaio \
        --direct=1 \
        --bs=4k \
        --iodepth=32 \
        --rw=randwrite \
        --numjobs="$jobs" \
        --group_reporting \
        --output-format=json 2>/dev/null)
    
    local write_iops=$(echo "$output" | jq -r '.jobs[0].write.iops' 2>/dev/null || echo "0")
    local write_bw=$(echo "$output" | jq -r '.jobs[0].write.bw / 1024' 2>/dev/null || echo "0")
    local write_lat=$(echo "$output" | jq -r '.jobs[0].write.lat_ns.mean / 1000' 2>/dev/null || echo "0")
    
    cat <<EOF
{
  "write_iops": ${write_iops%.*},
  "write_bw_mb": $write_bw,
  "write_lat_us": $write_lat
}
EOF
}

# Get disk info
ultra_bench_disk_get_info() {
    local test_dir="${1:-$BENCH_DISK_DIR}"
    
    local mount_point=$(df "$test_dir" 2>/dev/null | tail -1 | awk '{print $6}')
    local device=$(df "$test_dir" 2>/dev/null | tail -1 | awk '{print $1}')
    local fs_type=$(df -T "$test_dir" 2>/dev/null | tail -1 | awk '{print $2}')
    
    # Get device name without partition number
    local base_device=$(echo "$device" | sed 's/[0-9]*$//' | sed 's|/dev/||')
    
    local scheduler="unknown"
    if [[ -f "/sys/block/$base_device/queue/scheduler" ]]; then
        scheduler=$(cat "/sys/block/$base_device/queue/scheduler" 2>/dev/null | grep -oP '\[\K[^\]]+' || echo "unknown")
    fi
    
    local rotational="unknown"
    if [[ -f "/sys/block/$base_device/queue/rotational" ]]; then
        local rot=$(cat "/sys/block/$base_device/queue/rotational" 2>/dev/null)
        [[ "$rot" == "0" ]] && rotational="ssd" || rotational="hdd"
    fi
    
    local read_ahead="unknown"
    if [[ -f "/sys/block/$base_device/queue/read_ahead_kb" ]]; then
        read_ahead=$(cat "/sys/block/$base_device/queue/read_ahead_kb" 2>/dev/null || echo "unknown")
    fi
    
    cat <<EOF
{
  "mount_point": "$mount_point",
  "device": "$device",
  "fs_type": "$fs_type",
  "scheduler": "$scheduler",
  "type": "$rotational",
  "read_ahead_kb": "$read_ahead"
}
EOF
}

# Run comprehensive disk benchmark suite
ultra_bench_disk_suite() {
    local test_dir="${1:-$BENCH_DISK_DIR}"
    local size="${2:-$BENCH_DISK_SIZE}"
    local output_file="${3:-}"
    
    ultra_log_section "Disk I/O Benchmark Suite"
    
    if ! ultra_bench_disk_check_deps; then
        ultra_log_error "Cannot run disk benchmarks: fio not available"
        return 1
    fi
    
    # Check if test directory exists and is writable
    if [[ ! -d "$test_dir" ]]; then
        ultra_log_error "Test directory does not exist: $test_dir"
        return 1
    fi
    
    if [[ ! -w "$test_dir" ]]; then
        ultra_log_error "Test directory is not writable: $test_dir"
        return 1
    fi
    
    local disk_info=$(ultra_bench_disk_get_info "$test_dir")
    ultra_log_info "Disk info: $(echo "$disk_info" | jq -c . 2>/dev/null || echo "$disk_info")"
    
    local runtime=30
    local result_seq_read=$(ultra_bench_disk_seq_read "$test_dir" "$size" "$runtime")
    local result_seq_write=$(ultra_bench_disk_seq_write "$test_dir" "$size" "$runtime")
    local result_rand_read=$(ultra_bench_disk_rand_read "$test_dir" "$size" "$runtime" 4)
    local result_rand_write=$(ultra_bench_disk_rand_write "$test_dir" "$size" "$runtime" 4)
    
    # Cleanup test files
    rm -f "$test_dir"/seq_read.* "$test_dir"/seq_write.* "$test_dir"/rand_read.* "$test_dir"/rand_write.* 2>/dev/null
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local results=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "benchmark": "disk",
  "test_directory": "$test_dir",
  "test_size": "$size",
  "disk_info": $disk_info,
  "results": {
    "sequential_read": $result_seq_read,
    "sequential_write": $result_seq_write,
    "random_read_4k": $result_rand_read,
    "random_write_4k": $result_rand_write
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
    local seq_read_bw=$(echo "$result_seq_read" | jq -r '.read_bw_mb' 2>/dev/null || echo "N/A")
    local seq_write_bw=$(echo "$result_seq_write" | jq -r '.write_bw_mb' 2>/dev/null || echo "N/A")
    local rand_read_iops=$(echo "$result_rand_read" | jq -r '.read_iops' 2>/dev/null || echo "N/A")
    local rand_write_iops=$(echo "$result_rand_write" | jq -r '.write_iops' 2>/dev/null || echo "N/A")
    
    ultra_log_info "Summary: Seq Read=${seq_read_bw}MB/s, Seq Write=${seq_write_bw}MB/s, Rand Read=${rand_read_iops} IOPS, Rand Write=${rand_write_iops} IOPS"
    
    return 0
}

# Compare two benchmark results
ultra_bench_disk_compare() {
    local before_file="$1"
    local after_file="$2"
    
    if [[ ! -f "$before_file" ]] || [[ ! -f "$after_file" ]]; then
        ultra_log_error "Benchmark files not found"
        return 1
    fi
    
    ultra_log_section "Disk I/O Benchmark Comparison"
    
    local before_seq_r=$(jq -r '.results.sequential_read.read_bw_mb' "$before_file" 2>/dev/null || echo "0")
    local after_seq_r=$(jq -r '.results.sequential_read.read_bw_mb' "$after_file" 2>/dev/null || echo "0")
    
    local before_seq_w=$(jq -r '.results.sequential_write.write_bw_mb' "$before_file" 2>/dev/null || echo "0")
    local after_seq_w=$(jq -r '.results.sequential_write.write_bw_mb' "$after_file" 2>/dev/null || echo "0")
    
    local before_rand_r=$(jq -r '.results.random_read_4k.read_iops' "$before_file" 2>/dev/null || echo "0")
    local after_rand_r=$(jq -r '.results.random_read_4k.read_iops' "$after_file" 2>/dev/null || echo "0")
    
    local before_rand_w=$(jq -r '.results.random_write_4k.write_iops' "$before_file" 2>/dev/null || echo "0")
    local after_rand_w=$(jq -r '.results.random_write_4k.write_iops' "$after_file" 2>/dev/null || echo "0")
    
    if command -v bc &>/dev/null; then
        local seq_r_diff=$(echo "scale=2; (($after_seq_r - $before_seq_r) / $before_seq_r) * 100" | bc 2>/dev/null || echo "0")
        local seq_w_diff=$(echo "scale=2; (($after_seq_w - $before_seq_w) / $before_seq_w) * 100" | bc 2>/dev/null || echo "0")
        local rand_r_diff=$(echo "scale=2; (($after_rand_r - $before_rand_r) / $before_rand_r) * 100" | bc 2>/dev/null || echo "0")
        local rand_w_diff=$(echo "scale=2; (($after_rand_w - $before_rand_w) / $before_rand_w) * 100" | bc 2>/dev/null || echo "0")
        
        ultra_log_info "Sequential Read:  $before_seq_r → $after_seq_r MB/s (${seq_r_diff}%)"
        ultra_log_info "Sequential Write: $before_seq_w → $after_seq_w MB/s (${seq_w_diff}%)"
        ultra_log_info "Random Read 4K:   $before_rand_r → $after_rand_r IOPS (${rand_r_diff}%)"
        ultra_log_info "Random Write 4K:  $before_rand_w → $after_rand_w IOPS (${rand_w_diff}%)"
    else
        ultra_log_info "Sequential Read:  $before_seq_r → $after_seq_r MB/s"
        ultra_log_info "Sequential Write: $before_seq_w → $after_seq_w MB/s"
        ultra_log_info "Random Read 4K:   $before_rand_r → $after_rand_r IOPS"
        ultra_log_info "Random Write 4K:  $before_rand_w → $after_rand_w IOPS"
    fi
}

# Export functions if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f ultra_bench_disk_check_deps
    export -f ultra_bench_disk_seq_read
    export -f ultra_bench_disk_seq_write
    export -f ultra_bench_disk_rand_read
    export -f ultra_bench_disk_rand_write
    export -f ultra_bench_disk_get_info
    export -f ultra_bench_disk_suite
    export -f ultra_bench_disk_compare
fi
