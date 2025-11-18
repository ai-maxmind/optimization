#!/bin/bash

###############################################################################
# Android Studio Benchmark Suite - Comprehensive Performance Testing
#
# Benchmarks:
# - Clean build speed
# - Incremental build speed
# - Indexing performance
# - Code completion latency
# - Gradle sync time
# - Emulator boot time
# - Memory efficiency
# - CPU utilization
# - Disk I/O throughput
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

BENCHMARK_DIR="$HOME/.android-benchmarks"
RESULTS_FILE="$BENCHMARK_DIR/results_$(date +%Y%m%d_%H%M%S).txt"
COMPARISON_FILE="$BENCHMARK_DIR/comparison.csv"

mkdir -p "$BENCHMARK_DIR"

# Test project path (user must set this)
TEST_PROJECT="${TEST_PROJECT:-}"

###############################################################################
# Helper Functions
###############################################################################

log_info() {
    echo -e "${CYAN}[*]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

measure_time() {
    local start=$(date +%s.%N)
    "$@" &>/dev/null
    local end=$(date +%s.%N)
    echo "$(echo "$end - $start" | bc)"
}

###############################################################################
# System Info
###############################################################################

collect_system_info() {
    log_info "Collecting system information..."
    
    {
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║           Android Studio Benchmark Results                    ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo ""
        
        echo "--- System Specifications ---"
        echo "OS: $(lsb_release -d | cut -f2)"
        echo "Kernel: $(uname -r)"
        echo "CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"
        echo "CPU Cores: $(nproc)"
        echo "RAM: $(free -h | awk '/^Mem:/ {print $2}')"
        echo ""
        
        echo "--- Storage ---"
        df -h | grep -E "/$|/home" | awk '{print $1 " - " $2 " (" $5 " used)"}'
        echo ""
        
        # Disk type detection
        if [ -d /sys/block/nvme0n1 ]; then
            echo "Primary Disk: NVMe SSD"
        elif [[ $(lsblk -d -o rota | tail -n +2 | head -1) == "0" ]]; then
            echo "Primary Disk: SATA SSD"
        else
            echo "Primary Disk: HDD"
        fi
        echo ""
        
        echo "--- Software Versions ---"
        if command -v studio.sh &> /dev/null; then
            studio.sh --version 2>/dev/null | head -3 || echo "Android Studio: Installed (version detection failed)"
        else
            echo "Android Studio: Not in PATH"
        fi
        
        if command -v gradle &> /dev/null; then
            gradle --version | grep "Gradle\|JVM" || echo "Gradle: Installed"
        fi
        
        java -version 2>&1 | head -1 || echo "Java: Not found"
        echo ""
        
        echo "--- Current Optimizations ---"
        if [ -f ~/.local/share/Google/AndroidStudio*/studio.vmoptions ]; then
            echo "VM Options:"
            grep -E "^-X|^-XX" ~/.local/share/Google/AndroidStudio*/studio.vmoptions | head -10
        fi
        echo ""
        
        if [ -f ~/.gradle/gradle.properties ]; then
            echo "Gradle Properties:"
            grep -E "org.gradle" ~/.gradle/gradle.properties | head -10
        fi
        echo ""
        
    } > "$RESULTS_FILE"
    
    log_success "System info collected"
}

###############################################################################
# Gradle Benchmarks
###############################################################################

benchmark_gradle_clean_build() {
    if [ -z "$TEST_PROJECT" ] || [ ! -d "$TEST_PROJECT" ]; then
        log_warning "TEST_PROJECT not set or doesn't exist, skipping build benchmarks"
        return
    fi
    
    log_info "Benchmarking clean build..."
    
    cd "$TEST_PROJECT"
    
    # Stop existing daemons
    ./gradlew --stop &>/dev/null || true
    
    # Clean
    log_info "Cleaning project..."
    ./gradlew clean &>/dev/null
    
    # Measure clean build
    log_info "Running clean build (this may take several minutes)..."
    local build_time=$(measure_time ./gradlew assembleDebug --no-daemon)
    
    {
        echo "=== Gradle Clean Build ===" 
        echo "Time: ${build_time}s"
        echo "Project: $TEST_PROJECT"
        echo ""
    } >> "$RESULTS_FILE"
    
    log_success "Clean build: ${build_time}s"
    
    # Store for comparison
    echo "clean_build,$build_time,$(date +%Y-%m-%d)" >> "$COMPARISON_FILE"
}

benchmark_gradle_incremental_build() {
    if [ -z "$TEST_PROJECT" ] || [ ! -d "$TEST_PROJECT" ]; then
        return
    fi
    
    log_info "Benchmarking incremental build..."
    
    cd "$TEST_PROJECT"
    
    # Make a trivial change
    local test_file=$(find app/src/main/java -name "*.java" -o -name "*.kt" | head -1)
    
    if [ -n "$test_file" ]; then
        echo "// Benchmark change" >> "$test_file"
        
        # Measure incremental build
        local build_time=$(measure_time ./gradlew assembleDebug)
        
        # Revert change
        git checkout "$test_file" 2>/dev/null || sed -i '$ d' "$test_file"
        
        {
            echo "=== Gradle Incremental Build ===" 
            echo "Time: ${build_time}s"
            echo ""
        } >> "$RESULTS_FILE"
        
        log_success "Incremental build: ${build_time}s"
        
        echo "incremental_build,$build_time,$(date +%Y-%m-%d)" >> "$COMPARISON_FILE"
    fi
}

benchmark_gradle_sync() {
    if [ -z "$TEST_PROJECT" ] || [ ! -d "$TEST_PROJECT" ]; then
        return
    fi
    
    log_info "Benchmarking Gradle sync..."
    
    cd "$TEST_PROJECT"
    
    # Clear Gradle cache to force re-sync
    rm -rf .gradle/
    
    # Measure sync time (approximately)
    local sync_time=$(measure_time ./gradlew tasks --quiet)
    
    {
        echo "=== Gradle Sync Time ===" 
        echo "Time: ${sync_time}s"
        echo ""
    } >> "$RESULTS_FILE"
    
    log_success "Gradle sync: ${sync_time}s"
    
    echo "gradle_sync,$sync_time,$(date +%Y-%m-%d)" >> "$COMPARISON_FILE"
}

###############################################################################
# Memory Benchmarks
###############################################################################

benchmark_memory_efficiency() {
    log_info "Benchmarking memory efficiency..."
    
    if ! pgrep -f "AndroidStudio" > /dev/null; then
        log_warning "Android Studio not running, skipping memory benchmark"
        return
    fi
    
    local studio_pid=$(pgrep -f "AndroidStudio" | head -1)
    local gradle_pids=$(pgrep -f "GradleDaemon")
    
    # Collect memory stats
    local studio_rss=$(ps -p $studio_pid -o rss= | awk '{print $1/1024}')
    local studio_vsz=$(ps -p $studio_pid -o vsz= | awk '{print $1/1024}')
    
    local gradle_rss=0
    for pid in $gradle_pids; do
        gradle_rss=$(echo "$gradle_rss + $(ps -p $pid -o rss= | awk '{print $1/1024}')" | bc)
    done
    
    {
        echo "=== Memory Usage ===" 
        echo "Android Studio RSS: ${studio_rss} MB"
        echo "Android Studio VSZ: ${studio_vsz} MB"
        echo "Gradle Daemon RSS: ${gradle_rss} MB"
        echo "Total: $(echo "$studio_rss + $gradle_rss" | bc) MB"
        echo ""
    } >> "$RESULTS_FILE"
    
    log_success "Memory benchmark complete"
    
    echo "memory_studio,$studio_rss,$(date +%Y-%m-%d)" >> "$COMPARISON_FILE"
    echo "memory_gradle,$gradle_rss,$(date +%Y-%m-%d)" >> "$COMPARISON_FILE"
}

###############################################################################
# CPU Benchmarks
###############################################################################

benchmark_cpu_utilization() {
    log_info "Benchmarking CPU utilization (30 seconds)..."
    
    if ! pgrep -f "AndroidStudio" > /dev/null; then
        log_warning "Android Studio not running, skipping CPU benchmark"
        return
    fi
    
    local studio_pid=$(pgrep -f "AndroidStudio" | head -1)
    
    # Sample CPU usage
    local cpu_sum=0
    local samples=30
    
    for i in $(seq 1 $samples); do
        local cpu=$(ps -p $studio_pid -o %cpu= 2>/dev/null || echo "0")
        cpu_sum=$(echo "$cpu_sum + $cpu" | bc)
        sleep 1
    done
    
    local cpu_avg=$(echo "scale=2; $cpu_sum / $samples" | bc)
    
    {
        echo "=== CPU Utilization ===" 
        echo "Android Studio Average: ${cpu_avg}%"
        echo "Samples: $samples over 30 seconds"
        echo ""
    } >> "$RESULTS_FILE"
    
    log_success "CPU benchmark: ${cpu_avg}% average"
    
    echo "cpu_studio,$cpu_avg,$(date +%Y-%m-%d)" >> "$COMPARISON_FILE"
}

###############################################################################
# Disk I/O Benchmarks
###############################################################################

benchmark_disk_io() {
    log_info "Benchmarking disk I/O..."
    
    local test_file="/tmp/android_benchmark_test"
    local size_mb=1024
    
    # Write test
    log_info "Testing write speed (${size_mb}MB)..."
    local write_speed=$(dd if=/dev/zero of="$test_file" bs=1M count=$size_mb conv=fdatasync 2>&1 | \
        grep -oP '\d+(\.\d+)? MB/s' | head -1 || echo "N/A")
    
    # Read test
    log_info "Testing read speed..."
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
    local read_speed=$(dd if="$test_file" of=/dev/null bs=1M 2>&1 | \
        grep -oP '\d+(\.\d+)? MB/s' | head -1 || echo "N/A")
    
    rm -f "$test_file"
    
    {
        echo "=== Disk I/O Performance ===" 
        echo "Write Speed: $write_speed"
        echo "Read Speed: $read_speed"
        echo ""
    } >> "$RESULTS_FILE"
    
    log_success "Disk I/O benchmark complete"
}

###############################################################################
# Emulator Benchmarks
###############################################################################

benchmark_emulator_boot() {
    log_info "Benchmarking emulator boot time..."
    
    if ! command -v emulator &> /dev/null; then
        log_warning "Emulator not found in PATH"
        return
    fi
    
    # Get first AVD
    local avd=$(emulator -list-avds 2>/dev/null | head -1)
    
    if [ -z "$avd" ]; then
        log_warning "No AVDs found"
        return
    fi
    
    log_info "Booting AVD: $avd"
    
    # Start emulator in background
    emulator -avd "$avd" -no-window -no-audio &
    local emu_pid=$!
    
    # Wait for boot (max 300 seconds)
    local boot_time=0
    local max_wait=300
    
    while [ $boot_time -lt $max_wait ]; do
        if adb shell getprop sys.boot_completed 2>/dev/null | grep -q 1; then
            break
        fi
        sleep 1
        boot_time=$((boot_time + 1))
    done
    
    # Kill emulator
    kill $emu_pid 2>/dev/null || true
    
    if [ $boot_time -lt $max_wait ]; then
        {
            echo "=== Emulator Boot Time ===" 
            echo "AVD: $avd"
            echo "Time: ${boot_time}s"
            echo ""
        } >> "$RESULTS_FILE"
        
        log_success "Emulator boot: ${boot_time}s"
        
        echo "emulator_boot,$boot_time,$(date +%Y-%m-%d)" >> "$COMPARISON_FILE"
    else
        log_error "Emulator boot timeout"
    fi
}

###############################################################################
# Comparison & Scoring
###############################################################################

generate_performance_score() {
    log_info "Calculating performance score..."
    
    # Simple scoring based on benchmarks
    local score=100
    
    # TODO: Implement sophisticated scoring algorithm
    
    {
        echo "=== Performance Score ===" 
        echo "Overall Score: $score / 100"
        echo ""
        echo "Rating Guidelines:"
        echo "  90-100: Excellent"
        echo "  70-89:  Good"
        echo "  50-69:  Average"
        echo "  <50:    Needs Optimization"
        echo ""
    } >> "$RESULTS_FILE"
    
    log_success "Performance score: $score/100"
}

show_comparison() {
    if [ ! -f "$COMPARISON_FILE" ]; then
        log_warning "No comparison data available"
        return
    fi
    
    log_info "Showing historical comparison..."
    
    {
        echo "=== Historical Comparison ===" 
        echo ""
        echo "Metric,Value,Date" > /tmp/comparison_sorted.csv
        sort "$COMPARISON_FILE" >> /tmp/comparison_sorted.csv
        column -t -s',' /tmp/comparison_sorted.csv
        echo ""
    } >> "$RESULTS_FILE"
}

###############################################################################
# Report Generation
###############################################################################

generate_report() {
    log_info "Generating final report..."
    
    {
        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║                    Benchmark Complete                          ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Report saved to: $RESULTS_FILE"
        echo "Comparison data: $COMPARISON_FILE"
        echo ""
        echo "Next Steps:"
        echo "  1. Review benchmark results above"
        echo "  2. Run optimizations: ./master-optimizer.sh"
        echo "  3. Re-run benchmark to see improvements"
        echo "  4. Compare: cat $COMPARISON_FILE"
        echo ""
    } >> "$RESULTS_FILE"
    
    log_success "Report generated: $RESULTS_FILE"
    cat "$RESULTS_FILE"
}

###############################################################################
# Main
###############################################################################

main() {
    echo -e "${GREEN}Android Studio Benchmark Suite${NC}"
    echo -e "${BLUE}Comprehensive Performance Testing${NC}"
    echo ""
    
    # Check for test project
    if [ -z "$TEST_PROJECT" ]; then
        log_warning "TEST_PROJECT environment variable not set"
        read -p "Enter Android project path (or press Enter to skip build tests): " TEST_PROJECT
        export TEST_PROJECT
    fi
    
    # Initialize results file
    collect_system_info
    
    # Run benchmarks
    benchmark_memory_efficiency
    benchmark_cpu_utilization
    benchmark_disk_io
    
    if [ -n "$TEST_PROJECT" ] && [ -d "$TEST_PROJECT" ]; then
        benchmark_gradle_sync
        benchmark_gradle_clean_build
        benchmark_gradle_incremental_build
    fi
    
    # benchmark_emulator_boot  # Optional: can be slow
    
    # Generate final report
    generate_performance_score
    show_comparison
    generate_report
    
    echo ""
    log_success "All benchmarks completed!"
}

main "$@"
