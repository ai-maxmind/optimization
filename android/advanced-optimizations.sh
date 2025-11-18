#!/bin/bash

################################################################################
# Advanced System Optimizations for Android Studio
# Kernel, I/O Scheduler, CPU Governor, Memory, and more
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (sudo)"
    exit 1
fi

CPU_CORES=$(nproc)
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')

# ============================================================================
# I/O SCHEDULER OPTIMIZATION
# ============================================================================
optimize_io_scheduler() {
    log_info "Optimizing I/O schedulers..."
    
    for disk in /sys/block/sd?/queue/scheduler /sys/block/nvme?n?/queue/scheduler; do
        if [[ -f "$disk" ]]; then
            device=$(echo "$disk" | sed 's|/sys/block/||;s|/queue/scheduler||')
            
            # Check if NVMe or SSD
            if [[ "$device" =~ nvme ]]; then
                echo "none" > "$disk" 2>/dev/null || echo "mq-deadline" > "$disk" 2>/dev/null || true
                log_success "Set $device to 'none' (NVMe)"
            else
                rota=$(cat /sys/block/$device/queue/rotational 2>/dev/null || echo "1")
                if [[ "$rota" == "0" ]]; then
                    echo "mq-deadline" > "$disk" 2>/dev/null || echo "deadline" > "$disk" 2>/dev/null || true
                    log_success "Set $device to 'mq-deadline' (SSD)"
                else
                    echo "bfq" > "$disk" 2>/dev/null || echo "cfq" > "$disk" 2>/dev/null || true
                    log_success "Set $device to 'bfq' (HDD)"
                fi
            fi
        fi
    done
}

# ============================================================================
# I/O QUEUE DEPTH AND READ-AHEAD
# ============================================================================
optimize_io_queue() {
    log_info "Optimizing I/O queue depth and read-ahead..."
    
    for disk in /sys/block/sd? /sys/block/nvme?n?; do
        if [[ -d "$disk" ]]; then
            device=$(basename "$disk")
            
            # Queue depth
            echo 4096 > "$disk/queue/nr_requests" 2>/dev/null || true
            
            # Read-ahead (KB)
            if [[ "$device" =~ nvme ]]; then
                echo 1024 > "$disk/queue/read_ahead_kb" 2>/dev/null || true
            else
                echo 512 > "$disk/queue/read_ahead_kb" 2>/dev/null || true
            fi
            
            # RQ affinity
            echo 2 > "$disk/queue/rq_affinity" 2>/dev/null || true
            
            # Add random
            echo 0 > "$disk/queue/add_random" 2>/dev/null || true
            
            # Nomerges (for SSD/NVMe)
            rota=$(cat "$disk/queue/rotational" 2>/dev/null || echo "1")
            if [[ "$rota" == "0" ]]; then
                echo 2 > "$disk/queue/nomerges" 2>/dev/null || true
            fi
            
            log_success "Optimized $device queue settings"
        fi
    done
}

# ============================================================================
# CPU GOVERNOR AND FREQUENCY SCALING
# ============================================================================
optimize_cpu_governor() {
    log_info "Optimizing CPU governor for performance..."
    
    # Install cpufrequtils if not present
    if ! command -v cpufreq-set &> /dev/null; then
        apt-get install -y cpufrequtils linux-tools-common linux-tools-generic 2>/dev/null || true
    fi
    
    # Set performance governor
    for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        if [[ -f "$cpu/cpufreq/scaling_governor" ]]; then
            echo "performance" > "$cpu/cpufreq/scaling_governor" 2>/dev/null || true
        fi
    done
    
    # Disable CPU idle states for lower latency (optional, increases power usage)
    # for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpuidle/state[0-9]*/disable; do
    #     echo 1 > "$cpu" 2>/dev/null || true
    # done
    
    # Energy performance preference (Intel)
    for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        if [[ -f "$cpu/cpufreq/energy_performance_preference" ]]; then
            echo "performance" > "$cpu/cpufreq/energy_performance_preference" 2>/dev/null || true
        fi
    done
    
    log_success "CPU governor set to 'performance'"
}

# ============================================================================
# TRANSPARENT HUGE PAGES (THP)
# ============================================================================
optimize_thp() {
    log_info "Optimizing Transparent Huge Pages..."
    
    # Enable THP with madvise (safer than always)
    echo "madvise" > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
    echo "defer+madvise" > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
    
    # KSM (Kernel Same-page Merging) - optional
    if [[ -f /sys/kernel/mm/ksm/run ]]; then
        echo 1 > /sys/kernel/mm/ksm/run 2>/dev/null || true
        echo 1000 > /sys/kernel/mm/ksm/pages_to_scan 2>/dev/null || true
        echo 20 > /sys/kernel/mm/ksm/sleep_millisecs 2>/dev/null || true
    fi
    
    log_success "THP configured to 'madvise'"
}

# ============================================================================
# NUMA OPTIMIZATION
# ============================================================================
optimize_numa() {
    log_info "Checking NUMA configuration..."
    
    if command -v numactl &> /dev/null; then
        numa_nodes=$(numactl --hardware | grep "available:" | awk '{print $2}')
        if [[ "$numa_nodes" -gt 1 ]]; then
            log_info "NUMA detected: $numa_nodes nodes"
            # Enable automatic NUMA balancing
            echo 1 > /proc/sys/kernel/numa_balancing 2>/dev/null || true
            log_success "NUMA balancing enabled"
        else
            log_info "Single NUMA node system"
        fi
    fi
}

# ============================================================================
# VM (VIRTUAL MEMORY) TUNING
# ============================================================================
optimize_vm_advanced() {
    log_info "Applying advanced VM tuning..."
    
    # Swappiness - very low for development workstation
    echo 5 > /proc/sys/vm/swappiness
    
    # Cache pressure
    echo 50 > /proc/sys/vm/vfs_cache_pressure
    
    # Dirty page tuning for better write performance
    echo 10 > /proc/sys/vm/dirty_ratio
    echo 5 > /proc/sys/vm/dirty_background_ratio
    echo 3000 > /proc/sys/vm/dirty_writeback_centisecs
    echo 1500 > /proc/sys/vm/dirty_expire_centisecs
    
    # Memory overcommit (for Java processes)
    echo 1 > /proc/sys/vm/overcommit_memory
    echo 80 > /proc/sys/vm/overcommit_ratio
    
    # Page cluster (reduce swap reads)
    echo 0 > /proc/sys/vm/page-cluster
    
    # Min free kbytes (prevent OOM)
    min_free=$((RAM_MB * 1024 / 100))  # 1% of RAM
    [[ $min_free -lt 65536 ]] && min_free=65536
    [[ $min_free -gt 262144 ]] && min_free=262144
    echo $min_free > /proc/sys/vm/min_free_kbytes
    
    # Zone reclaim mode (disable for better performance)
    echo 0 > /proc/sys/vm/zone_reclaim_mode
    
    # Compact memory
    echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
    
    log_success "Advanced VM settings applied"
}

# ============================================================================
# IRQ AFFINITY (Interrupt Request)
# ============================================================================
optimize_irq_affinity() {
    log_info "Optimizing IRQ affinity..."
    
    # Distribute network IRQs across CPUs
    for irq in $(grep -E "eth|wlan|enp|wlp" /proc/interrupts | cut -d':' -f1 | tr -d ' '); do
        if [[ -f /proc/irq/$irq/smp_affinity ]]; then
            printf "%x" $((2**CPU_CORES - 1)) > /proc/irq/$irq/smp_affinity 2>/dev/null || true
        fi
    done
    
    # Disable irqbalance for manual control (optional)
    # systemctl stop irqbalance 2>/dev/null || true
    # systemctl disable irqbalance 2>/dev/null || true
    
    log_success "IRQ affinity optimized"
}

# ============================================================================
# DISK WRITEBACK CACHE
# ============================================================================
optimize_disk_cache() {
    log_info "Optimizing disk write cache..."
    
    for disk in sd? nvme?n?; do
        if [[ -b /dev/$disk ]]; then
            # Enable write cache
            hdparm -W1 /dev/$disk 2>/dev/null || true
            # Set higher DMA mode
            hdparm -d1 /dev/$disk 2>/dev/null || true
            log_success "Optimized /dev/$disk cache"
        fi
    done
}

# ============================================================================
# FILESYSTEM MOUNT OPTIONS
# ============================================================================
suggest_filesystem_optimization() {
    log_info "Filesystem optimization suggestions:"
    echo ""
    echo "Add these mount options to /etc/fstab for better performance:"
    echo ""
    echo "For ext4:"
    echo "  noatime,nodiratime,commit=60,barrier=0,data=writeback"
    echo ""
    echo "For XFS:"
    echo "  noatime,nodiratime,logbufs=8,logbsize=256k,largeio,inode64,swalloc"
    echo ""
    echo "For Btrfs:"
    echo "  noatime,nodiratime,compress=zstd,space_cache=v2,commit=60"
    echo ""
    echo "Example fstab entry:"
    echo "  UUID=xxx / ext4 noatime,nodiratime,commit=60,barrier=0,errors=remount-ro 0 1"
    echo ""
    log_warning "Manual edit required. Backup /etc/fstab before changes!"
}

# ============================================================================
# KERNEL MODULES
# ============================================================================
optimize_kernel_modules() {
    log_info "Loading performance kernel modules..."
    
    # BBR congestion control
    modprobe tcp_bbr 2>/dev/null || true
    
    # Multiqueue support
    modprobe nvme 2>/dev/null || true
    modprobe nvme-core 2>/dev/null || true
    
    log_success "Performance kernel modules loaded"
}

# ============================================================================
# DISABLE UNNECESSARY SERVICES
# ============================================================================
disable_unnecessary_services() {
    log_info "Suggesting unnecessary services to disable..."
    
    services=(
        "bluetooth"
        "cups"
        "avahi-daemon"
        "ModemManager"
        "whoopsie"
        "apport"
    )
    
    echo ""
    echo "Consider disabling these services if not needed:"
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "  - $service (currently running)"
        fi
    done
    echo ""
    echo "To disable: sudo systemctl disable --now <service-name>"
    echo ""
}

# ============================================================================
# NETWORK TUNING FOR ANDROID EMULATOR
# ============================================================================
optimize_network_emulator() {
    log_info "Optimizing network for Android emulator..."
    
    # Increase local port range
    echo "1024 65535" > /proc/sys/net/ipv4/ip_local_port_range
    
    # TCP orphan settings
    echo 8192 > /proc/sys/net/ipv4/tcp_max_orphans
    
    # Connection tracking timeouts
    echo 300 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established 2>/dev/null || true
    
    log_success "Network optimized for emulator"
}

# ============================================================================
# GRUB OPTIMIZATION
# ============================================================================
suggest_grub_optimization() {
    log_info "GRUB kernel parameters suggestions:"
    echo ""
    echo "Edit /etc/default/grub and add to GRUB_CMDLINE_LINUX:"
    echo ""
    echo "For Intel CPU:"
    echo "  intel_pstate=active intel_idle.max_cstate=0 processor.max_cstate=0 idle=poll"
    echo ""
    echo "For AMD CPU:"
    echo "  amd_pstate=active"
    echo ""
    echo "Universal optimizations:"
    echo "  mitigations=off transparent_hugepage=madvise"
    echo "  nohz=off nosoftlockup tsc=reliable"
    echo ""
    echo "After editing, run: sudo update-grub && sudo reboot"
    echo ""
    log_warning "Disabling mitigations reduces security but increases performance!"
}

# ============================================================================
# JAVA/JVM SYSTEM OPTIMIZATIONS
# ============================================================================
optimize_java_system() {
    log_info "Optimizing system for Java/JVM..."
    
    # Increase max map count (for Java apps)
    echo 262144 > /proc/sys/vm/max_map_count
    
    # Core pattern for Java dumps
    echo "/tmp/core-%e-%p-%t" > /proc/sys/kernel/core_pattern
    
    log_success "Java/JVM system optimizations applied"
}

# ============================================================================
# CREATE SYSTEMD SERVICE FOR PERSISTENCE
# ============================================================================
create_systemd_service() {
    log_info "Creating systemd service for persistent optimizations..."
    
    cat > /etc/systemd/system/android-studio-optimize.service << 'EOF'
[Unit]
Description=Android Studio Performance Optimizations
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/android-studio-optimize-boot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    cat > /usr/local/bin/android-studio-optimize-boot.sh << 'EOF'
#!/bin/bash
# Boot-time optimizations

# I/O Scheduler
for disk in /sys/block/*/queue/scheduler; do
    if [[ -f "$disk" ]]; then
        device=$(echo "$disk" | cut -d'/' -f4)
        if [[ "$device" =~ nvme ]]; then
            echo "none" > "$disk" 2>/dev/null || true
        else
            echo "mq-deadline" > "$disk" 2>/dev/null || true
        fi
    fi
done

# CPU Governor
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" > "$gov" 2>/dev/null || true
done

# VM tuning
echo 5 > /proc/sys/vm/swappiness
echo 50 > /proc/sys/vm/vfs_cache_pressure

exit 0
EOF

    chmod +x /usr/local/bin/android-studio-optimize-boot.sh
    systemctl daemon-reload
    systemctl enable android-studio-optimize.service
    
    log_success "Systemd service created and enabled"
}

# ============================================================================
# GENERATE OPTIMIZATION REPORT
# ============================================================================
generate_advanced_report() {
    local report="/root/android-studio-advanced-optimization-report.txt"
    
    cat > "$report" << EOF
================================================================================
Android Studio Advanced System Optimization Report
Generated: $(date)
================================================================================

System Information:
- RAM: ${RAM_MB} MB
- CPU Cores: ${CPU_CORES}
- Kernel: $(uname -r)
- CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A")

Applied Optimizations:
✓ I/O Schedulers optimized (NVMe: none, SSD: mq-deadline, HDD: bfq)
✓ I/O Queue depth increased to 4096
✓ Read-ahead optimized (NVMe: 1024KB, SSD: 512KB)
✓ CPU Governor set to 'performance'
✓ Transparent Huge Pages set to 'madvise'
✓ VM tuning applied (swappiness=5, dirty_ratio=10)
✓ IRQ affinity optimized
✓ Network stack tuned for Android emulator
✓ Java/JVM system parameters optimized
✓ Systemd service created for boot-time optimizations

I/O Scheduler Status:
$(for disk in /sys/block/*/queue/scheduler; do
    if [[ -f "$disk" ]]; then
        device=$(echo "$disk" | cut -d'/' -f4)
        scheduler=$(cat "$disk")
        echo "  $device: $scheduler"
    fi
done)

Current Kernel Parameters:
  vm.swappiness = $(cat /proc/sys/vm/swappiness)
  vm.vfs_cache_pressure = $(cat /proc/sys/vm/vfs_cache_pressure)
  vm.dirty_ratio = $(cat /proc/sys/vm/dirty_ratio)
  vm.dirty_background_ratio = $(cat /proc/sys/vm/dirty_background_ratio)
  vm.max_map_count = $(cat /proc/sys/vm/max_map_count)

Manual Steps Required:
1. Edit /etc/fstab with optimized mount options (see suggestions above)
2. Edit /etc/default/grub with kernel parameters (see suggestions above)
3. Consider disabling unnecessary services
4. Reboot system to apply all changes

Next Boot:
- Optimizations will be automatically applied via systemd service
- Verify with: systemctl status android-studio-optimize.service

================================================================================
EOF

    cat "$report"
    log_success "Advanced report saved to: $report"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
main() {
    echo "========================================================"
    echo "  Android Studio ADVANCED System Optimization"
    echo "  Kernel, I/O, CPU, Memory, Network Tuning"
    echo "========================================================"
    echo ""
    
    optimize_io_scheduler
    optimize_io_queue
    optimize_cpu_governor
    optimize_thp
    optimize_numa
    optimize_vm_advanced
    optimize_irq_affinity
    optimize_disk_cache
    optimize_kernel_modules
    optimize_network_emulator
    optimize_java_system
    create_systemd_service
    
    echo ""
    suggest_filesystem_optimization
    suggest_grub_optimization
    disable_unnecessary_services
    
    echo ""
    generate_advanced_report
    
    echo ""
    log_success "Advanced optimizations complete!"
    log_warning "REBOOT required for full effect!"
}

main "$@"
