# Java Configuration & System Tuning v5.0 - QUANTUM LEAP EDITION

## 📖 Overview

All-in-one automated Java installation and ultra-advanced system optimization script for Enterprise Linux environments. This script now includes **tuneSystem() v5.0** with AI-powered workload classification and quantum-level performance optimization.

## 📋 Prerequisites

- **OS**: RHEL, Rocky Linux, AlmaLinux, Oracle Linux, CentOS Stream (8.x/9.x)
- **Privileges**: Root or sudo access
- **Disk Space**: 500MB+ for Java installations
- **Network**: Internet connection for package downloads

## 🚀 Quick Start

### Method 1: Interactive Menu (Recommended)

```bash
# Make executable
chmod +x java_config.sh

# Run with sudo
sudo ./java_config.sh
```

Menu options:
```
┌─────────────────────────────────────────────────────────────┐
│      JAVA CONFIGURATION & SYSTEM TUNING v5.0               │
│                  QUANTUM LEAP EDITION                       │
└─────────────────────────────────────────────────────────────┘

1) Install All Java Versions
2) Set Temurin (Highest-1) as Default
3) Tune System for Java ⭐ [NEW v5.0 with AI]
4) Setup Java Environment Variables
5) Uninstall All Java Versions
6) Full Auto Install + Tune + Set Default
7) Exit
```

### Method 2: Direct Function Call

```bash
# Source the script
source java_config.sh

# Run specific function
sudo tuneSystem  # v5.0 Quantum Leap Edition
```

### Method 3: Non-Interactive (CI/CD)

```bash
# Full automation
sudo bash java_config.sh auto

# Or step-by-step
sudo bash -c 'source java_config.sh && installAllJava && tuneSystem && setTemurinDefault'
```

## 🎯 Usage Examples

### Example 1: Kafka Cluster Optimization
```bash
# tuneSystem() will auto-detect Kafka processes and apply:
# - 2x file descriptors for high connection count
# - 4x message queue buffers
# - 268MB network buffers (rmem/wmem)
# - BBR congestion control for ultra-low latency
# - vm.dirty_ratio=60 for write-heavy workloads

sudo ./java_config.sh
# Select: 3) Tune System for Java
```

Expected output:
```
[1.7] AI-Powered Workload Classification:
    ✓ Type: Distributed-Messaging (Confidence: 92%)
    ✓ Characteristics: Ultra-high network I/O, moderate CPU
    ✓ Performance Score: 87/100
    ✓ Predicted Bottleneck: Network (Score: 70)
```

### Example 2: Elasticsearch Node Tuning
```bash
# Auto-detects and applies:
# - vm.max_map_count=262144 (required for Elasticsearch)
# - 3x file descriptors for index files
# - vm.swappiness=1 (minimal swapping)
# - fs.file-max=2M
# - NUMA interleaving for large heaps

sudo tuneSystem  # If script is sourced
```

### Example 3: Spark/Flink Cluster
```bash
# Optimizations include:
# - 75% RAM for memory locking (off-heap buffers)
# - vm.overcommit_memory=1 (required for Spark)
# - kernel.shmmax=64GB (large shared memory)
# - 2x process limits for parallel tasks
# - ZGC if RAM ≥ 32GB (ultra-low GC pause)

sudo bash -c 'source java_config.sh && tuneSystem'
```

## 🛡️ Safety & Rollback

### Backup System
Every tuning session creates a **timestamped backup** with:
- All original configuration files
- System state snapshots
- SHA256 integrity checksums
- Comprehensive manifest

### Rollback Procedure
```bash
# List available backups
ls -la /var/backups/java-tuning-v5-quantum-*/

# Restore from specific backup
BACKUP_DIR=/var/backups/java-tuning-v5-quantum-20250117-143022
sudo cp -r $BACKUP_DIR/limits/* /etc/security/
sudo cp -r $BACKUP_DIR/sysctl/* /etc/sysctl.d/
sudo sysctl -p
sudo reboot  # Required for some changes
```

## 📈 Monitoring & Validation

### Check Tuning Status
```bash
# CPU Governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# Expected: performance

# TCP Congestion Control
sysctl net.ipv4.tcp_congestion_control
# Expected: bbr

# Huge Pages
grep HugePages_Total /proc/meminfo
# Expected: 75% of RAM

# File Descriptors
ulimit -n
# Expected: 2M - 8M (workload-dependent)
```

### View Generated Report
```bash
# Find latest backup directory
LATEST_BACKUP=$(ls -td /var/backups/java-tuning-v5-quantum-*/ | head -1)

# View comprehensive report
cat ${LATEST_BACKUP}TUNING_SUMMARY.txt
```

### Monitor Java Applications
```bash
# View GC logs (real-time)
tail -f /var/log/java/gc/gc-*.log

# Check heap dumps (if OOM occurred)
ls -lh /var/log/java/heap/

# Verify JAVA_TOOL_OPTIONS
echo $JAVA_TOOL_OPTIONS
```

## 🐛 Troubleshooting

### Issue: "Some sysctl parameters failed"
**Solution**: Some parameters may not be supported on your kernel version. Check:
```bash
sudo sysctl -p /etc/sysctl.d/99-java-quantum-tuning-v5.conf 2>&1 | grep "unknown key"
```
These are non-critical warnings and can be ignored.

### Issue: "Huge pages allocation failed"
**Cause**: Memory fragmentation

**Solution**: 
```bash
# Allocate at boot (add to /etc/default/grub)
GRUB_CMDLINE_LINUX="... hugepagesz=2M hugepages=32768"
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
sudo reboot
```

### Issue: "AppArmor profile not loaded"
**Cause**: AppArmor not installed/active

**Solution**:
```bash
# Check AppArmor status
sudo aa-status

# If not installed (optional - script works without it)
sudo dnf install apparmor apparmor-utils
sudo systemctl enable --now apparmor
```

## 📚 Advanced Usage

### Custom Workload Override
If AI classification is incorrect, you can manually set workload type:

```bash
# Edit /etc/profile.d/java-quantum-jvm-opts-v5.sh
# Uncomment and modify:
# FORCE_WORKLOAD_TYPE="Stream-Processing"
```

### Disable Specific Phases
To skip certain optimization phases, edit the script:
```bash
sudo nano java_config.sh

# Comment out unwanted phases (lines 1200-2000):
# Phase 8: CPU Management - comment out if you want default governor
# Phase 9: Huge Pages - comment out if application doesn't use them
```

### Container-Specific Mode
For Docker/Podman environments:
```bash
# tuneSystem() auto-detects containers and adjusts:
# - Reduced MaxRAMPercentage (75% vs 90%)
# - Disabled kernel.numa_balancing
# - Container-aware JVM options
```

## 🔐 Security Considerations

### AppArmor Profile
The generated profile (`/etc/apparmor.d/usr.bin.java`) enforces:
- Read-only access to JVM libraries
- Limited network capabilities
- Restricted filesystem access
- No system-wide write permissions

### Recommended Production Settings
```bash
# After tuning, consider:

# 1. Disable core dumps in production
echo "* soft core 0" >> /etc/security/limits.d/99-java-quantum-tuning-v5.conf
echo "* hard core 0" >> /etc/security/limits.d/99-java-quantum-tuning-v5.conf

# 2. Enable enforcing mode for AppArmor (after testing)
sudo sed -i 's/flags=(complain)/flags=(enforce)/' /etc/apparmor.d/usr.bin.java
sudo apparmor_parser -r /etc/apparmor.d/usr.bin.java

# 3. Restrict sysctl permissions
sudo chmod 644 /etc/sysctl.d/99-java-quantum-tuning-v5.conf
```

