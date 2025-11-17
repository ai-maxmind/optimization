#!/bin/bash
# orchestrator/benchmark.sh
# Automated benchmark comparison before/after optimization

ULTRA_BENCHMARK_DIR="${ULTRA_BENCHMARK_DIR:-/var/lib/ubuntu-ultra-opt/benchmarks}"

# Run comprehensive benchmark suite
ultra_bench_run_suite() {
    local label="${1:-default}"
    local output_dir="$ULTRA_BENCHMARK_DIR/$label"
    
    mkdir -p "$output_dir"
    
    ultra_log_info "Running benchmark suite: $label"
    
    # CPU benchmark
    if [[ -f "$ULTRA_CORE_DIR/bench/cpu.sh" ]]; then
        source "$ULTRA_CORE_DIR/bench/cpu.sh"
        ultra_bench_cpu > "$output_dir/cpu.json" 2>&1
        ultra_log_info "✓ CPU benchmark completed"
    fi
    
    # Disk benchmark
    if [[ -f "$ULTRA_CORE_DIR/bench/disk.sh" ]]; then
        source "$ULTRA_CORE_DIR/bench/disk.sh"
        ultra_bench_disk > "$output_dir/disk.json" 2>&1
        ultra_log_info "✓ Disk benchmark completed"
    fi
    
    # Network benchmark
    if [[ -f "$ULTRA_CORE_DIR/bench/net.sh" ]]; then
        source "$ULTRA_CORE_DIR/bench/net.sh"
        ultra_bench_net > "$output_dir/net.json" 2>&1
        ultra_log_info "✓ Network benchmark completed"
    fi
    
    # Memory latency test
    ultra_bench_memory_latency > "$output_dir/memory.json" 2>&1
    ultra_log_info "✓ Memory benchmark completed"
    
    # Context switch test
    ultra_bench_context_switch > "$output_dir/context_switch.json" 2>&1
    ultra_log_info "✓ Context switch benchmark completed"
    
    ultra_log_info "Benchmark suite completed: $output_dir"
}

# Memory latency benchmark
ultra_bench_memory_latency() {
    local iterations=1000000
    
    cat > /tmp/mem_lat_test.c <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

#define SIZE (64 * 1024 * 1024)  // 64MB

int main() {
    char *mem = malloc(SIZE);
    memset(mem, 0, SIZE);
    
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    
    volatile int sum = 0;
    for (int i = 0; i < 10000000; i++) {
        sum += mem[i % SIZE];
    }
    
    clock_gettime(CLOCK_MONOTONIC, &end);
    
    long ns = (end.tv_sec - start.tv_sec) * 1000000000L + (end.tv_nsec - start.tv_nsec);
    printf("{\"latency_ns\": %ld, \"throughput_mb\": %.2f}\n", 
           ns / 10000000, (10000000.0 / (ns / 1000000000.0)) / (1024*1024));
    
    free(mem);
    return 0;
}
EOF
    
    gcc -O2 /tmp/mem_lat_test.c -o /tmp/mem_lat_test 2>/dev/null
    /tmp/mem_lat_test
    rm -f /tmp/mem_lat_test.c /tmp/mem_lat_test
}

# Context switch benchmark
ultra_bench_context_switch() {
    local iterations=100000
    
    cat > /tmp/ctx_switch_test.c <<'EOF'
#include <stdio.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/wait.h>

int main() {
    int pipe1[2], pipe2[2];
    pipe(pipe1);
    pipe(pipe2);
    
    if (fork() == 0) {
        char c;
        for (int i = 0; i < 100000; i++) {
            read(pipe1[0], &c, 1);
            write(pipe2[1], &c, 1);
        }
        return 0;
    }
    
    struct timeval start, end;
    gettimeofday(&start, NULL);
    
    char c = 'x';
    for (int i = 0; i < 100000; i++) {
        write(pipe1[1], &c, 1);
        read(pipe2[0], &c, 1);
    }
    
    gettimeofday(&end, NULL);
    
    long us = (end.tv_sec - start.tv_sec) * 1000000 + (end.tv_usec - start.tv_usec);
    printf("{\"total_us\": %ld, \"per_switch_ns\": %ld}\n", us, (us * 1000) / 200000);
    
    wait(NULL);
    return 0;
}
EOF
    
    gcc -O2 /tmp/ctx_switch_test.c -o /tmp/ctx_switch_test 2>/dev/null
    /tmp/ctx_switch_test
    rm -f /tmp/ctx_switch_test.c /tmp/ctx_switch_test
}

# Compare benchmark results
ultra_bench_compare() {
    local before_dir="$1"
    local after_dir="$2"
    local output_file="${3:-/tmp/benchmark-comparison.txt}"
    
    ultra_log_info "Comparing benchmarks: before vs after"
    
    {
        echo "=========================================="
        echo "Ubuntu Ultra Optimizer - Benchmark Comparison"
        echo "=========================================="
        echo ""
        echo "Before: $before_dir"
        echo "After:  $after_dir"
        echo ""
        
        # CPU comparison
        if [[ -f "$before_dir/cpu.json" ]] && [[ -f "$after_dir/cpu.json" ]]; then
            echo "CPU Performance:"
            
            local cpu_before=$(jq -r '.single_thread.events_per_second // 0' "$before_dir/cpu.json" 2>/dev/null || echo 0)
            local cpu_after=$(jq -r '.single_thread.events_per_second // 0' "$after_dir/cpu.json" 2>/dev/null || echo 0)
            
            if [[ $cpu_before -gt 0 ]] && [[ $cpu_after -gt 0 ]]; then
                local cpu_change=$(( (cpu_after - cpu_before) * 100 / cpu_before ))
                echo "  Single-thread: $cpu_before → $cpu_after events/s (${cpu_change:+$cpu_change}%)"
            fi
        fi
        
        # Memory comparison
        if [[ -f "$before_dir/memory.json" ]] && [[ -f "$after_dir/memory.json" ]]; then
            echo ""
            echo "Memory Performance:"
            
            local mem_before=$(jq -r '.latency_ns // 0' "$before_dir/memory.json" 2>/dev/null || echo 0)
            local mem_after=$(jq -r '.latency_ns // 0' "$after_dir/memory.json" 2>/dev/null || echo 0)
            
            if [[ $mem_before -gt 0 ]] && [[ $mem_after -gt 0 ]]; then
                local mem_change=$(( (mem_before - mem_after) * 100 / mem_before ))
                echo "  Latency: ${mem_before}ns → ${mem_after}ns (improved ${mem_change:+$mem_change}%)"
            fi
        fi
        
        # Context switch comparison
        if [[ -f "$before_dir/context_switch.json" ]] && [[ -f "$after_dir/context_switch.json" ]]; then
            echo ""
            echo "Context Switch Performance:"
            
            local ctx_before=$(jq -r '.per_switch_ns // 0' "$before_dir/context_switch.json" 2>/dev/null || echo 0)
            local ctx_after=$(jq -r '.per_switch_ns // 0' "$after_dir/context_switch.json" 2>/dev/null || echo 0)
            
            if [[ $ctx_before -gt 0 ]] && [[ $ctx_after -gt 0 ]]; then
                local ctx_change=$(( (ctx_before - ctx_after) * 100 / ctx_before ))
                echo "  Per switch: ${ctx_before}ns → ${ctx_after}ns (improved ${ctx_change:+$ctx_change}%)"
            fi
        fi
        
        # Disk comparison
        if [[ -f "$before_dir/disk.json" ]] && [[ -f "$after_dir/disk.json" ]]; then
            echo ""
            echo "Disk Performance:"
            
            local disk_before=$(jq -r '.sequential_read.throughput_mb // 0' "$before_dir/disk.json" 2>/dev/null || echo 0)
            local disk_after=$(jq -r '.sequential_read.throughput_mb // 0' "$after_dir/disk.json" 2>/dev/null || echo 0)
            
            if [[ $disk_before -gt 0 ]] && [[ $disk_after -gt 0 ]]; then
                local disk_change=$(( (disk_after - disk_before) * 100 / disk_before ))
                echo "  Sequential Read: ${disk_before}MB/s → ${disk_after}MB/s (${disk_change:+$disk_change}%)"
            fi
        fi
        
        echo ""
        echo "=========================================="
        echo ""
        echo "Performance Summary:"
        echo "  → Use these results to validate optimization effectiveness"
        echo "  → Negative changes may indicate issues or workload differences"
        echo "  → Run multiple times for statistically significant results"
        echo ""
    } | tee "$output_file"
    
    ultra_log_info "Comparison saved: $output_file"
}

# Auto-benchmark before/after optimization
ultra_bench_auto() {
    local run_id="${1:-$ULTRA_CURRENT_RUN_ID}"
    
    if [[ -z "$run_id" ]]; then
        ultra_log_error "No RUN_ID provided"
        return 1
    fi
    
    local before_dir="$ULTRA_BENCHMARK_DIR/${run_id}-before"
    local after_dir="$ULTRA_BENCHMARK_DIR/${run_id}-after"
    
    # Check if before benchmark exists
    if [[ ! -d "$before_dir" ]]; then
        ultra_log_info "Running baseline benchmark..."
        ultra_bench_run_suite "${run_id}-before"
    fi
    
    # Run after benchmark
    ultra_log_info "Running post-optimization benchmark..."
    ultra_bench_run_suite "${run_id}-after"
    
    # Compare results
    ultra_bench_compare "$before_dir" "$after_dir"
}
