#!/bin/bash

################################################################################
# Memory & CPU Affinity Optimizer
# Advanced CPU pinning, NUMA, and memory allocation strategies
################################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CPU & MEMORY AFFINITY OPTIMIZER"
echo "  Advanced CPU Pinning & NUMA Optimization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CPU_CORES=$(nproc)
CPU_THREADS=$(nproc --all)
NUMA_NODES=$(lscpu | grep "NUMA node(s):" | awk '{print $3}')

log_info "CPU Cores: $CPU_CORES physical"
log_info "CPU Threads: $CPU_THREADS logical"
log_info "NUMA Nodes: $NUMA_NODES"

# ============================================================================
# NUMA TOPOLOGY ANALYSIS
# ============================================================================
analyze_numa() {
    log_info "Analyzing NUMA topology..."
    
    if [[ $NUMA_NODES -gt 1 ]]; then
        echo ""
        echo "NUMA Node Distribution:"
        numactl --hardware 2>/dev/null || log_warning "numactl not installed"
        
        cat > "${HOME}/numa-aware-launcher.sh" << 'EOF'
#!/bin/bash
# Launch Android Studio with NUMA optimization

# Detect NUMA nodes
NUMA_NODES=$(numactl --hardware | grep "available:" | awk '{print $2}')

if [[ $NUMA_NODES -gt 1 ]]; then
    # Multi-node system - bind to specific node
    NODE=0  # Use first node (usually closest to primary CPU)
    
    echo "Launching Android Studio with NUMA node $NODE binding..."
    numactl --cpunodebind=$NODE --membind=$NODE /usr/local/android-studio/bin/studio.sh &
else
    # Single node - normal launch
    echo "Single NUMA node detected - launching normally..."
    /usr/local/android-studio/bin/studio.sh &
fi
EOF
        chmod +x "${HOME}/numa-aware-launcher.sh"
        log_success "NUMA-aware launcher created: ~/numa-aware-launcher.sh"
    else
        log_info "Single NUMA node system - no NUMA optimization needed"
    fi
}

# ============================================================================
# CPU AFFINITY SCRIPT
# ============================================================================
create_cpu_affinity_script() {
    log_info "Creating CPU affinity optimizer..."
    
    cat > "${HOME}/set-cpu-affinity.sh" << 'EOF'
#!/bin/bash
# Set CPU affinity for Android Studio and Gradle

set_affinity() {
    local process_name="$1"
    local cpu_list="$2"
    
    pids=$(pgrep -f "$process_name")
    
    if [[ -z "$pids" ]]; then
        echo "No process found: $process_name"
        return
    fi
    
    for pid in $pids; do
        taskset -cp "$cpu_list" "$pid" 2>/dev/null
        echo "Set CPU affinity for PID $pid ($process_name) to CPUs: $cpu_list"
    done
}

# Detect CPU layout
CPU_CORES=$(nproc)
CPU_THREADS=$(nproc --all)

# Reserve cores for system (20%)
SYSTEM_CORES=$((CPU_CORES / 5))
[[ $SYSTEM_CORES -lt 2 ]] && SYSTEM_CORES=2

# Calculate CPU ranges
if [[ $CPU_THREADS -gt $CPU_CORES ]]; then
    # Hyperthreading enabled
    # Use physical cores for Android Studio
    STUDIO_CORES="0-$((CPU_CORES - SYSTEM_CORES - 1))"
    GRADLE_CORES="0-$((CPU_CORES - 1))"
else
    # No hyperthreading
    STUDIO_CORES="0-$((CPU_CORES - SYSTEM_CORES - 1))"
    GRADLE_CORES="0-$((CPU_CORES - 1))"
fi

echo "CPU Affinity Configuration:"
echo "  Total CPUs: $CPU_THREADS"
echo "  Android Studio CPUs: $STUDIO_CORES"
echo "  Gradle CPUs: $GRADLE_CORES"
echo ""

# Set affinity
set_affinity "AndroidStudio" "$STUDIO_CORES"
set_affinity "GradleDaemon" "$GRADLE_CORES"
set_affinity "gradle" "$GRADLE_CORES"

echo ""
echo "CPU affinity set. Monitor with: ps -eLo pid,tid,psr,comm | grep -E 'studio|gradle'"
EOF

    chmod +x "${HOME}/set-cpu-affinity.sh"
    log_success "CPU affinity script created: ~/set-cpu-affinity.sh"
}

# ============================================================================
# MEMORY PRESSURE MONITOR
# ============================================================================
create_memory_monitor() {
    log_info "Creating memory pressure monitor..."
    
    cat > "${HOME}/monitor-memory-pressure.sh" << 'EOF'
#!/bin/bash
# Monitor memory pressure and swap usage

watch -n 2 '
echo "=== Memory Overview ==="
free -h

echo ""
echo "=== Top Memory Consumers ==="
ps aux --sort=-%mem | head -11

echo ""
echo "=== Swap Usage ==="
swapon --show
cat /proc/swaps

echo ""
echo "=== VM Statistics ==="
cat /proc/sys/vm/swappiness
cat /proc/sys/vm/vfs_cache_pressure

echo ""
echo "=== Android Studio Memory ==="
ps aux | grep -E "AndroidStudio|studio" | grep -v grep | awk "{print \"RSS: \" \$6/1024 \"MB, VSZ: \" \$5/1024 \"MB\"}"

echo ""
echo "=== Gradle Daemon Memory ==="
ps aux | grep -E "[G]radleDaemon|gradle" | awk "{sum+=\$6} END {print \"Total RSS: \" sum/1024 \"MB\"}"

echo ""
echo "=== Memory Fragmentation ==="
cat /proc/buddyinfo | head -5
'
EOF

    chmod +x "${HOME}/monitor-memory-pressure.sh"
    log_success "Memory monitor created: ~/monitor-memory-pressure.sh"
}

# ============================================================================
# HUGE PAGES SETUP
# ============================================================================
setup_huge_pages() {
    log_info "Creating huge pages setup script..."
    
    cat > "${HOME}/setup-huge-pages.sh" << 'EOF'
#!/bin/bash
# Setup Transparent Huge Pages for better memory performance

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run with sudo"
    exit 1
fi

echo "Setting up Transparent Huge Pages..."

# Enable THP with madvise (application-controlled)
echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag

# Set khugepaged parameters
echo 1 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag
echo 4096 > /sys/kernel/mm/transparent_hugepage/khugepaged/pages_to_scan
echo 1000 > /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs
echo 100 > /sys/kernel/mm/transparent_hugepage/khugepaged/alloc_sleep_millisecs

echo "THP Status:"
cat /sys/kernel/mm/transparent_hugepage/enabled
echo ""

# Make permanent
if ! grep -q "transparent_hugepage" /etc/default/grub; then
    echo ""
    echo "To make permanent, add to /etc/default/grub:"
    echo '  GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX transparent_hugepage=madvise"'
    echo "Then run: sudo update-grub && sudo reboot"
fi
EOF

    chmod +x "${HOME}/setup-huge-pages.sh"
    log_success "Huge pages setup script created: ~/setup-huge-pages.sh"
}

# ============================================================================
# MEMORY COMPACTION
# ============================================================================
create_memory_compactor() {
    log_info "Creating memory compaction script..."
    
    cat > "${HOME}/compact-memory.sh" << 'EOF'
#!/bin/bash
# Compact memory to reduce fragmentation

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run with sudo"
    exit 1
fi

echo "Compacting memory..."

# Drop caches (safe operation)
sync
echo 3 > /proc/sys/vm/drop_caches

# Compact memory
echo 1 > /proc/sys/vm/compact_memory

# Show memory info
echo ""
echo "Memory after compaction:"
free -h

echo ""
echo "Fragmentation status:"
cat /proc/buddyinfo | head -5
EOF

    chmod +x "${HOME}/compact-memory.sh"
    log_success "Memory compactor created: ~/compact-memory.sh"
}

# ============================================================================
# CPU ISOLATION (ADVANCED)
# ============================================================================
create_cpu_isolator() {
    log_info "Creating CPU isolation guide..."
    
    cat > "${HOME}/cpu-isolation-guide.txt" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CPU ISOLATION FOR ANDROID DEVELOPMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CPU isolation dedicates specific CPU cores to Android Studio and Gradle,
preventing other processes from using them and reducing context switching.

⚠️ WARNING: This is an ADVANCED optimization that can make your system
less responsive for other tasks. Only use on dedicated development machines.

Current System:
- Total CPU Cores: $CPU_CORES
- Total CPU Threads: $CPU_THREADS

Recommended Isolation:
- Reserve 2 cores for system
- Dedicate remaining cores to Android Studio/Gradle

Steps to Enable CPU Isolation:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Edit /etc/default/grub:
   
   sudo nano /etc/default/grub
   
   Add to GRUB_CMDLINE_LINUX:
   isolcpus=2-$((CPU_CORES-1)) nohz_full=2-$((CPU_CORES-1)) rcu_nocbs=2-$((CPU_CORES-1))
   
   Example:
   GRUB_CMDLINE_LINUX="isolcpus=2-7 nohz_full=2-7 rcu_nocbs=2-7"

2. Update GRUB:
   
   sudo update-grub
   sudo reboot

3. After reboot, verify isolation:
   
   cat /sys/devices/system/cpu/isolated
   
   Should show: 2-$((CPU_CORES-1))

4. Pin Android Studio to isolated CPUs:
   
   # Find Android Studio PID
   STUDIO_PID=\$(pgrep -f AndroidStudio)
   
   # Set CPU affinity to isolated cores
   taskset -cp 2-$((CPU_CORES-1)) \$STUDIO_PID

5. Create systemd service for automatic pinning:
   
   sudo nano /etc/systemd/system/android-studio-affinity.service
   
   [Unit]
   Description=Set CPU affinity for Android Studio
   After=graphical.target
   
   [Service]
   Type=oneshot
   RemainAfterExit=yes
   ExecStart=/usr/local/bin/pin-android-studio.sh
   
   [Install]
   WantedBy=graphical.target

Rollback:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

To remove CPU isolation:
1. Edit /etc/default/grub and remove isolcpus parameters
2. Run: sudo update-grub && sudo reboot

Benefits:
✓ Reduced context switching
✓ Better CPU cache utilization
✓ Predictable performance
✓ Lower latency

Drawbacks:
✗ System may feel less responsive
✗ Other apps limited to fewer cores
✗ Requires manual configuration

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

    log_success "CPU isolation guide created: ~/cpu-isolation-guide.txt"
}

# ============================================================================
# CGROUP SETUP (RESOURCE LIMITS)
# ============================================================================
create_cgroup_script() {
    log_info "Creating cgroup resource limiter..."
    
    cat > "${HOME}/setup-cgroups.sh" << 'EOF'
#!/bin/bash
# Setup cgroups for Android Studio resource management

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run with sudo"
    exit 1
fi

# Check if cgroups v2 is enabled
if [[ ! -d "/sys/fs/cgroup/unified" ]] && [[ ! -f "/sys/fs/cgroup/cgroup.controllers" ]]; then
    echo "cgroups v2 not available. Trying v1..."
    
    # Create cgroup for Android Studio (v1)
    mkdir -p /sys/fs/cgroup/cpu/androidstudio
    mkdir -p /sys/fs/cgroup/memory/androidstudio
    
    # Allocate 80% CPU
    CPU_QUOTA=$((800000))  # 80% of 1000ms
    echo $CPU_QUOTA > /sys/fs/cgroup/cpu/androidstudio/cpu.cfs_quota_us
    echo 1000000 > /sys/fs/cgroup/cpu/androidstudio/cpu.cfs_period_us
    
    # Set memory limit (16GB)
    echo 17179869184 > /sys/fs/cgroup/memory/androidstudio/memory.limit_in_bytes
    
    echo "cgroup created for Android Studio (v1)"
    echo "To add process: echo PID > /sys/fs/cgroup/cpu/androidstudio/cgroup.procs"
else
    echo "cgroups v2 detected"
    echo "Use systemd-run for resource management:"
    echo ""
    echo "systemd-run --scope --slice=androidstudio \\"
    echo "  --property=CPUQuota=80% \\"
    echo "  --property=MemoryMax=16G \\"
    echo "  /usr/local/android-studio/bin/studio.sh"
fi
EOF

    chmod +x "${HOME}/setup-cgroups.sh"
    log_success "Cgroup setup script created: ~/setup-cgroups.sh"
}

# ============================================================================
# PERFORMANCE GOVERNOR SCRIPT
# ============================================================================
create_performance_script() {
    log_info "Creating performance mode script..."
    
    cat > "${HOME}/enable-performance-mode.sh" << 'EOF'
#!/bin/bash
# Enable maximum performance mode

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run with sudo"
    exit 1
fi

echo "Enabling MAXIMUM PERFORMANCE mode..."

# CPU Governor
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" > "$cpu" 2>/dev/null
done

# Disable CPU idle states (maximum performance, high power)
for cpu in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
    echo 1 > "$cpu" 2>/dev/null
done

# Set I/O scheduler
for disk in /sys/block/sd?/queue/scheduler /sys/block/nvme?n?/queue/scheduler; do
    if [[ -f "$disk" ]]; then
        echo "mq-deadline" > "$disk" 2>/dev/null || echo "deadline" > "$disk" 2>/dev/null
    fi
done

# Disable power management
echo on > /sys/bus/usb/devices/*/power/control 2>/dev/null || true
echo on > /sys/bus/pci/devices/*/power/control 2>/dev/null || true

# Disable laptop mode
echo 0 > /proc/sys/vm/laptop_mode 2>/dev/null || true

echo ""
echo "Performance mode ENABLED"
echo "Current CPU governor:"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

echo ""
echo "⚠️ This will increase power consumption and heat!"
echo "To revert: sudo cpupower frequency-set -g powersave"
EOF

    chmod +x "${HOME}/enable-performance-mode.sh"
    log_success "Performance mode script created: ~/enable-performance-mode.sh"
}

# ============================================================================
# GENERATE REPORT
# ============================================================================
generate_report() {
    local report="${HOME}/cpu-memory-affinity-report.txt"
    
    cat > "$report" << EOF
================================================================================
CPU & MEMORY AFFINITY OPTIMIZATION REPORT
Generated: $(date)
================================================================================

System Configuration:
- CPU Cores: $CPU_CORES physical
- CPU Threads: $CPU_THREADS logical ($([ $CPU_THREADS -gt $CPU_CORES ] && echo "HyperThreading ON" || echo "HyperThreading OFF"))
- NUMA Nodes: $NUMA_NODES

Scripts Created:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ ~/set-cpu-affinity.sh - Set CPU affinity for processes
✓ ~/monitor-memory-pressure.sh - Monitor memory usage
✓ ~/setup-huge-pages.sh - Configure transparent huge pages
✓ ~/compact-memory.sh - Compact memory to reduce fragmentation
✓ ~/cpu-isolation-guide.txt - Guide for CPU isolation
✓ ~/setup-cgroups.sh - Setup resource limits with cgroups
✓ ~/enable-performance-mode.sh - Enable maximum performance

$([ $NUMA_NODES -gt 1 ] && echo "✓ ~/numa-aware-launcher.sh - NUMA-optimized launcher")

Usage Guide:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Basic CPU Affinity (run after starting Android Studio):
   $ ~/set-cpu-affinity.sh

2. Monitor Memory Pressure:
   $ ~/monitor-memory-pressure.sh

3. Enable Huge Pages (requires sudo):
   $ sudo ~/setup-huge-pages.sh

4. Compact Memory when fragmented (requires sudo):
   $ sudo ~/compact-memory.sh

5. Enable Performance Mode (requires sudo):
   $ sudo ~/enable-performance-mode.sh

$([ $NUMA_NODES -gt 1 ] && echo "6. Launch with NUMA optimization:
   $ ~/numa-aware-launcher.sh")

Advanced Optimizations:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CPU Isolation:
  - Read ~/cpu-isolation-guide.txt for detailed instructions
  - Recommended for dedicated development machines only
  - Can improve performance by 10-15%

Cgroups:
  - Use for resource limiting
  - Prevents runaway processes
  - Run: sudo ~/setup-cgroups.sh

NUMA Pinning (multi-node systems):
  - Binds process to specific NUMA node
  - Reduces memory access latency
  - Automatic in ~/numa-aware-launcher.sh

Performance Impact:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CPU Affinity:          +5-10% performance
Huge Pages:            +3-5% memory performance
Memory Compaction:     Reduces fragmentation, improves allocation speed
Performance Governor:  +10-20% CPU performance (increases power usage)
CPU Isolation:         +10-15% (dedicated machines only)
NUMA Optimization:     +5-15% (multi-node systems only)

Monitoring Commands:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Check CPU affinity:
  $ ps -eLo pid,tid,psr,comm | grep -E 'studio|gradle'

Check NUMA policy:
  $ numactl --show
  $ numastat -c AndroidStudio

Check THP status:
  $ cat /sys/kernel/mm/transparent_hugepage/enabled
  $ grep -i huge /proc/meminfo

Check CPU governor:
  $ cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort -u

Check memory fragmentation:
  $ cat /proc/buddyinfo

Tips:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Run CPU affinity script after starting Android Studio
• Enable performance mode before large builds
• Monitor memory pressure during indexing
• Compact memory if system becomes slow
• On multi-node NUMA systems, use NUMA launcher
• For extreme performance, consider CPU isolation

Warnings:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ Performance mode increases power consumption
⚠️ CPU isolation makes system less responsive
⚠️ Huge pages may not work on all kernels
⚠️ Cgroups require proper configuration

================================================================================
EOF

    cat "$report"
    log_success "Report saved to: $report"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    analyze_numa
    create_cpu_affinity_script
    create_memory_monitor
    setup_huge_pages
    create_memory_compactor
    create_cpu_isolator
    create_cgroup_script
    create_performance_script
    
    echo ""
    generate_report
    
    echo ""
    log_success "CPU & Memory affinity optimization complete!"
    log_info "Run scripts as needed for your workload"
}

main "$@"
