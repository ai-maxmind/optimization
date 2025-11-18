#!/bin/bash

###############################################################################
# Android Studio Auto-Profiler - AI-Driven Performance Analysis
# 
# Tự động profile, phân tích, và đề xuất optimizations dựa trên:
# - Real-time JVM metrics
# - Build performance patterns
# - Resource utilization trends
# - Bottleneck detection
# - Machine learning predictions
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$HOME/.android-studio-profiles"
METRICS_DB="$PROFILE_DIR/metrics.db"
REPORT_FILE="$HOME/auto-profiler-report.txt"

# Create profile directory
mkdir -p "$PROFILE_DIR"/{jvm,build,system,recommendations}

###############################################################################
# System Detection
###############################################################################

detect_system() {
    echo -e "${CYAN}[*] Detecting system configuration...${NC}"
    
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    TOTAL_CPU=$(nproc)
    
    # Detect Android Studio process
    if pgrep -f "AndroidStudio" > /dev/null; then
        STUDIO_PID=$(pgrep -f "AndroidStudio" | head -1)
        echo -e "${GREEN}[✓] Android Studio running (PID: $STUDIO_PID)${NC}"
    else
        STUDIO_PID=""
        echo -e "${YELLOW}[!] Android Studio not running${NC}"
    fi
    
    # Detect Gradle daemon
    if pgrep -f "GradleDaemon" > /dev/null; then
        GRADLE_PID=$(pgrep -f "GradleDaemon" | head -1)
        echo -e "${GREEN}[✓] Gradle Daemon running (PID: $GRADLE_PID)${NC}"
    else
        GRADLE_PID=""
        echo -e "${YELLOW}[!] Gradle Daemon not running${NC}"
    fi
    
    # Detect disk type
    if [ -d /sys/block/nvme0n1 ]; then
        DISK_TYPE="NVMe"
    elif [[ $(lsblk -d -o rota | tail -n +2 | head -1) == "0" ]]; then
        DISK_TYPE="SSD"
    else
        DISK_TYPE="HDD"
    fi
    
    echo -e "${BLUE}[i] System: ${TOTAL_RAM}GB RAM, ${TOTAL_CPU} CPU cores, $DISK_TYPE${NC}"
}

###############################################################################
# JVM Profiling
###############################################################################

profile_jvm() {
    if [ -z "$STUDIO_PID" ]; then
        echo -e "${YELLOW}[!] Skipping JVM profiling (Studio not running)${NC}"
        return
    fi
    
    echo -e "${CYAN}[*] Profiling JVM (60 seconds)...${NC}"
    
    local profile_file="$PROFILE_DIR/jvm/profile_$(date +%Y%m%d_%H%M%S).txt"
    
    # Collect JVM stats
    {
        echo "=== JVM Profile $(date) ==="
        echo ""
        echo "--- Heap Usage ---"
        jstat -gc $STUDIO_PID 1000 60 | tail -20
        echo ""
        echo "--- GC Activity ---"
        jstat -gcutil $STUDIO_PID 1000 60 | tail -20
        echo ""
        echo "--- Memory Pools ---"
        jmap -heap $STUDIO_PID 2>/dev/null || echo "jmap failed"
        echo ""
        echo "--- Thread Dump Sample ---"
        jstack $STUDIO_PID | head -100
        echo ""
        echo "--- JVM Flags ---"
        jinfo -flags $STUDIO_PID 2>/dev/null || echo "jinfo failed"
    } > "$profile_file"
    
    echo -e "${GREEN}[✓] JVM profile saved: $profile_file${NC}"
    
    # Analyze GC pauses
    analyze_gc_pauses "$profile_file"
}

analyze_gc_pauses() {
    local profile="$1"
    
    if [ ! -f "$profile" ]; then
        return
    fi
    
    # Extract GC times (simplified)
    local avg_gc=$(grep -A 20 "GC Activity" "$profile" | awk '{sum+=$NF; count++} END {if(count>0) print sum/count}')
    
    if [ -n "$avg_gc" ]; then
        echo -e "${BLUE}[i] Average GC time: ${avg_gc}%${NC}"
        
        if (( $(echo "$avg_gc > 10" | bc -l) )); then
            echo -e "${RED}[!] HIGH GC pressure detected!${NC}"
            echo "RECOMMENDATION: Consider ZGC or increase heap size" >> "$PROFILE_DIR/recommendations/gc_$(date +%Y%m%d).txt"
        fi
    fi
}

###############################################################################
# Build Performance Profiling
###############################################################################

profile_build() {
    echo -e "${CYAN}[*] Analyzing build performance...${NC}"
    
    # Look for recent Gradle build scans
    local gradle_home="$HOME/.gradle"
    
    if [ -d "$gradle_home" ]; then
        # Find recent build logs
        local recent_builds=$(find "$gradle_home" -name "*.log" -mtime -1 2>/dev/null | head -5)
        
        if [ -n "$recent_builds" ]; then
            local build_profile="$PROFILE_DIR/build/build_analysis_$(date +%Y%m%d_%H%M%S).txt"
            
            {
                echo "=== Build Performance Analysis ==="
                echo ""
                
                for log in $recent_builds; do
                    echo "--- Build Log: $(basename $log) ---"
                    
                    # Extract build time
                    grep -i "BUILD SUCCESSFUL\|BUILD FAILED\|Total time:" "$log" 2>/dev/null | tail -5
                    
                    # Extract slow tasks
                    grep -i "Task.*took\|execution time" "$log" 2>/dev/null | sort -rn | head -10
                    echo ""
                done
            } > "$build_profile"
            
            echo -e "${GREEN}[✓] Build analysis saved: $build_profile${NC}"
            analyze_build_bottlenecks "$build_profile"
        else
            echo -e "${YELLOW}[!] No recent build logs found${NC}"
        fi
    fi
}

analyze_build_bottlenecks() {
    local profile="$1"
    
    # Detect common bottlenecks
    if grep -qi "configuration.*took" "$profile"; then
        echo -e "${YELLOW}[!] Configuration phase is slow${NC}"
        echo "RECOMMENDATION: Enable configuration cache" >> "$PROFILE_DIR/recommendations/build_$(date +%Y%m%d).txt"
    fi
    
    if grep -qi "compilation.*took" "$profile"; then
        echo -e "${YELLOW}[!] Compilation is slow${NC}"
        echo "RECOMMENDATION: Increase compiler heap, enable parallel compilation" >> "$PROFILE_DIR/recommendations/build_$(date +%Y%m%d).txt"
    fi
}

###############################################################################
# System Resource Monitoring
###############################################################################

monitor_resources() {
    echo -e "${CYAN}[*] Monitoring system resources (30 seconds)...${NC}"
    
    local resource_file="$PROFILE_DIR/system/resources_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== System Resource Monitoring ==="
        echo ""
        
        for i in {1..30}; do
            echo "--- Sample $i/30 ---"
            echo "Time: $(date +%H:%M:%S)"
            
            # CPU usage
            if [ -n "$STUDIO_PID" ]; then
                ps -p $STUDIO_PID -o %cpu,rss | tail -1 | awk '{print "Studio CPU: " $1 "%, RAM: " $2/1024 " MB"}'
            fi
            
            if [ -n "$GRADLE_PID" ]; then
                ps -p $GRADLE_PID -o %cpu,rss | tail -1 | awk '{print "Gradle CPU: " $1 "%, RAM: " $2/1024 " MB"}'
            fi
            
            # Memory
            free -h | grep "Mem:" | awk '{print "System RAM: " $3 " / " $2 " (Used/Total)"}'
            
            # Disk I/O
            iostat -x 1 1 | grep -E "nvme|sda" | head -1 | awk '{print "Disk: " $4 " r/s, " $5 " w/s, " $14 "% util"}'
            
            echo ""
            sleep 1
        done
    } > "$resource_file"
    
    echo -e "${GREEN}[✓] Resource monitoring saved: $resource_file${NC}"
    analyze_resource_usage "$resource_file"
}

analyze_resource_usage() {
    local profile="$1"
    
    # Calculate averages
    local avg_cpu=$(grep "Studio CPU:" "$profile" | awk '{sum+=$3; count++} END {if(count>0) print sum/count}')
    local avg_ram=$(grep "Studio CPU:" "$profile" | awk '{sum+=$6; count++} END {if(count>0) print sum/count}')
    
    if [ -n "$avg_cpu" ]; then
        echo -e "${BLUE}[i] Average Studio CPU: ${avg_cpu}%${NC}"
        
        if (( $(echo "$avg_cpu < 20" | bc -l) )); then
            echo -e "${YELLOW}[!] LOW CPU utilization${NC}"
            echo "RECOMMENDATION: Increase parallel workers, check for I/O bottlenecks" >> "$PROFILE_DIR/recommendations/system_$(date +%Y%m%d).txt"
        fi
    fi
    
    if [ -n "$avg_ram" ]; then
        echo -e "${BLUE}[i] Average Studio RAM: ${avg_ram} MB${NC}"
        
        if (( $(echo "$avg_ram > $(($TOTAL_RAM * 800))" | bc -l) )); then
            echo -e "${RED}[!] HIGH memory usage${NC}"
            echo "RECOMMENDATION: Reduce heap size or increase system RAM" >> "$PROFILE_DIR/recommendations/system_$(date +%Y%m%d).txt"
        fi
    fi
}

###############################################################################
# ML-Based Recommendations
###############################################################################

generate_smart_recommendations() {
    echo -e "${CYAN}[*] Generating AI-driven recommendations...${NC}"
    
    local rec_file="$PROFILE_DIR/recommendations/smart_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== AI-Driven Performance Recommendations ==="
        echo "Generated: $(date)"
        echo ""
        
        echo "--- System Analysis ---"
        echo "RAM: ${TOTAL_RAM}GB"
        echo "CPU: ${TOTAL_CPU} cores"
        echo "Disk: $DISK_TYPE"
        echo ""
        
        # RAM-based recommendations
        echo "--- Memory Optimization ---"
        if [ $TOTAL_RAM -ge 32 ]; then
            echo "✓ Excellent RAM capacity"
            echo "  → Recommended Studio Xmx: 8-12GB"
            echo "  → Recommended Gradle Xmx: 10-16GB"
            echo "  → Enable aggressive caching"
            echo "  → Consider RAM disk for builds"
        elif [ $TOTAL_RAM -ge 16 ]; then
            echo "✓ Good RAM capacity"
            echo "  → Recommended Studio Xmx: 4-6GB"
            echo "  → Recommended Gradle Xmx: 6-8GB"
            echo "  → Enable build cache"
        else
            echo "⚠ Limited RAM"
            echo "  → Recommended Studio Xmx: 2-3GB"
            echo "  → Recommended Gradle Xmx: 3-4GB"
            echo "  → Reduce parallel workers"
            echo "  → Disable unnecessary plugins"
        fi
        echo ""
        
        # CPU-based recommendations
        echo "--- CPU Optimization ---"
        if [ $TOTAL_CPU -ge 16 ]; then
            echo "✓ High CPU count"
            echo "  → Gradle workers: 12-16"
            echo "  → Enable parallel compilation"
            echo "  → Consider CPU affinity"
        elif [ $TOTAL_CPU -ge 8 ]; then
            echo "✓ Good CPU count"
            echo "  → Gradle workers: 6-8"
            echo "  → Enable parallel execution"
        else
            echo "⚠ Limited CPU cores"
            echo "  → Gradle workers: 2-4"
            echo "  → Disable unnecessary background tasks"
        fi
        echo ""
        
        # Disk-based recommendations
        echo "--- Storage Optimization ---"
        case $DISK_TYPE in
            NVMe)
                echo "✓ NVMe SSD detected"
                echo "  → I/O scheduler: none"
                echo "  → Optimal for large builds"
                echo "  → Enable aggressive caching"
                ;;
            SSD)
                echo "✓ SSD detected"
                echo "  → I/O scheduler: mq-deadline"
                echo "  → Good for development"
                ;;
            HDD)
                echo "⚠ HDD detected"
                echo "  → I/O scheduler: bfq"
                echo "  → STRONGLY recommend SSD upgrade"
                echo "  → Minimize file watchers"
                ;;
        esac
        echo ""
        
        # Aggregate all recommendations
        echo "--- Collected Recommendations ---"
        if [ -d "$PROFILE_DIR/recommendations" ]; then
            cat "$PROFILE_DIR/recommendations"/*.txt 2>/dev/null | sort -u
        fi
        
    } > "$rec_file"
    
    echo -e "${GREEN}[✓] Recommendations saved: $rec_file${NC}"
    cat "$rec_file"
}

###############################################################################
# Benchmark Suite
###############################################################################

run_benchmark() {
    echo -e "${CYAN}[*] Running performance benchmark...${NC}"
    
    local benchmark_file="$PROFILE_DIR/benchmark_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== Performance Benchmark ==="
        echo "Date: $(date)"
        echo ""
        
        # CPU benchmark
        echo "--- CPU Benchmark (stress-ng) ---"
        if command -v stress-ng &> /dev/null; then
            timeout 10s stress-ng --cpu $TOTAL_CPU --metrics 2>&1 | grep -i "bogo\|ops"
        else
            echo "stress-ng not installed, skipping CPU benchmark"
        fi
        echo ""
        
        # Memory benchmark
        echo "--- Memory Bandwidth (dd) ---"
        dd if=/dev/zero of=/dev/null bs=1M count=10240 2>&1 | grep -i "copied"
        echo ""
        
        # Disk benchmark
        echo "--- Disk I/O (dd) ---"
        dd if=/dev/zero of=/tmp/benchmark_test bs=1G count=1 oflag=direct 2>&1 | grep -i "copied"
        rm -f /tmp/benchmark_test
        echo ""
        
        # Gradle daemon startup
        if command -v gradle &> /dev/null; then
            echo "--- Gradle Daemon Startup ---"
            gradle --stop &>/dev/null
            time gradle --version &>/dev/null
        fi
        
    } > "$benchmark_file"
    
    echo -e "${GREEN}[✓] Benchmark results saved: $benchmark_file${NC}"
}

###############################################################################
# Report Generation
###############################################################################

generate_report() {
    echo -e "${CYAN}[*] Generating comprehensive report...${NC}"
    
    {
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║        Android Studio Auto-Profiler Report                    ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Generated: $(date)"
        echo "System: ${TOTAL_RAM}GB RAM, ${TOTAL_CPU} CPU cores, $DISK_TYPE"
        echo ""
        
        echo "--- Profile Files ---"
        echo "JVM Profiles: $(ls -1 $PROFILE_DIR/jvm/*.txt 2>/dev/null | wc -l)"
        echo "Build Profiles: $(ls -1 $PROFILE_DIR/build/*.txt 2>/dev/null | wc -l)"
        echo "System Profiles: $(ls -1 $PROFILE_DIR/system/*.txt 2>/dev/null | wc -l)"
        echo ""
        
        echo "--- Latest Recommendations ---"
        if [ -f "$PROFILE_DIR/recommendations/smart_"*.txt ]; then
            tail -50 $(ls -t $PROFILE_DIR/recommendations/smart_*.txt | head -1)
        fi
        echo ""
        
        echo "--- Next Steps ---"
        echo "1. Review recommendations: ls $PROFILE_DIR/recommendations/"
        echo "2. Check JVM profiles: ls $PROFILE_DIR/jvm/"
        echo "3. Analyze build logs: ls $PROFILE_DIR/build/"
        echo "4. Monitor resources: ls $PROFILE_DIR/system/"
        echo ""
        echo "5. Apply optimizations:"
        echo "   - For user-level: ./optimize-android-studio.sh"
        echo "   - For system-level: sudo ./advanced-optimizations.sh"
        echo "   - For all-in-one: ./master-optimizer.sh"
        echo ""
        
        echo "--- Profile Directory ---"
        echo "$PROFILE_DIR"
        echo ""
        du -sh "$PROFILE_DIR"
        
    } > "$REPORT_FILE"
    
    echo -e "${GREEN}[✓] Report saved: $REPORT_FILE${NC}"
    cat "$REPORT_FILE"
}

###############################################################################
# Continuous Monitoring Mode
###############################################################################

continuous_monitor() {
    echo -e "${CYAN}[*] Starting continuous monitoring (press Ctrl+C to stop)...${NC}"
    
    local monitor_file="$PROFILE_DIR/continuous_$(date +%Y%m%d_%H%M%S).log"
    
    while true; do
        {
            echo "=== $(date) ==="
            
            if [ -n "$STUDIO_PID" ]; then
                ps -p $STUDIO_PID -o %cpu,%mem,rss,vsz --no-headers | \
                    awk '{print "Studio: CPU=" $1 "% MEM=" $2 "% RSS=" $3/1024 "MB VSZ=" $4/1024 "MB"}'
            fi
            
            if [ -n "$GRADLE_PID" ]; then
                ps -p $GRADLE_PID -o %cpu,%mem,rss,vsz --no-headers | \
                    awk '{print "Gradle: CPU=" $1 "% MEM=" $2 "% RSS=" $3/1024 "MB VSZ=" $4/1024 "MB"}'
            fi
            
            free -h | grep "Mem:" | awk '{print "System: " $3 " / " $2}'
            
            echo ""
        } | tee -a "$monitor_file"
        
        sleep 5
    done
}

###############################################################################
# Main Menu
###############################################################################

show_menu() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║     Android Studio Auto-Profiler & Analyzer          ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}[1]${NC} Full Profile (JVM + Build + System + Recommendations)"
    echo -e "${CYAN}[2]${NC} JVM Profiling Only"
    echo -e "${CYAN}[3]${NC} Build Performance Analysis"
    echo -e "${CYAN}[4]${NC} System Resource Monitoring"
    echo -e "${CYAN}[5]${NC} Generate Smart Recommendations"
    echo -e "${CYAN}[6]${NC} Run Performance Benchmark"
    echo -e "${CYAN}[7]${NC} Continuous Monitoring (real-time)"
    echo -e "${CYAN}[8]${NC} View Previous Reports"
    echo -e "${CYAN}[9]${NC} Clean Old Profiles"
    echo -e "${CYAN}[0]${NC} Exit"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1)
            detect_system
            profile_jvm
            profile_build
            monitor_resources
            run_benchmark
            generate_smart_recommendations
            generate_report
            ;;
        2)
            detect_system
            profile_jvm
            ;;
        3)
            profile_build
            ;;
        4)
            detect_system
            monitor_resources
            ;;
        5)
            detect_system
            generate_smart_recommendations
            ;;
        6)
            detect_system
            run_benchmark
            ;;
        7)
            detect_system
            continuous_monitor
            ;;
        8)
            echo "Recent reports:"
            ls -lht "$PROFILE_DIR"/{jvm,build,system,recommendations}/*.txt 2>/dev/null | head -20
            ;;
        9)
            echo "Cleaning profiles older than 7 days..."
            find "$PROFILE_DIR" -name "*.txt" -mtime +7 -delete
            find "$PROFILE_DIR" -name "*.log" -mtime +7 -delete
            echo "Done!"
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

###############################################################################
# Entry Point
###############################################################################

main() {
    echo -e "${GREEN}Android Studio Auto-Profiler${NC}"
    echo -e "${BLUE}AI-Driven Performance Analysis & Recommendations${NC}"
    echo ""
    
    # Check dependencies
    local missing_deps=()
    for cmd in jstat jmap jstack jinfo bc; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}[!] Missing dependencies: ${missing_deps[*]}${NC}"
        echo "Install with: sudo apt-get install openjdk-17-jdk-headless bc"
        echo ""
    fi
    
    # Check if running as part of automated profiling
    if [ "${1:-}" = "--auto" ]; then
        detect_system
        profile_jvm
        profile_build
        monitor_resources
        generate_smart_recommendations
        generate_report
    else
        show_menu
    fi
}

main "$@"
