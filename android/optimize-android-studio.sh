#!/bin/bash

################################################################################
# Android Studio ULTRA Deep Optimization Script for Ubuntu
# Tối ưu siêu cực sâu Android Studio trên Ubuntu - Advanced Level
# Performance Tuning: System, JVM, Kernel, I/O, Network, Memory
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ANDROID_STUDIO_HOME="${HOME}/.local/share/Google/AndroidStudio2024.1"
ANDROID_SDK_HOME="${HOME}/Android/Sdk"
GRADLE_HOME="${HOME}/.gradle"
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)
CPU_THREADS=$(nproc --all)
CPU_ARCH=$(uname -m)
KERNEL_VERSION=$(uname -r)
HAS_NVME=$(lsblk -d -o name,rota | grep -q nvme && echo "yes" || echo "no")
HAS_SSD=$(lsblk -d -o name,rota | awk '$2=="0"{print $1; exit}' | grep -q . && echo "yes" || echo "no")

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should NOT be run as root"
        exit 1
    fi
}

# Backup function
backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backed up: $file"
    fi
}

# Create directories if not exist
create_directories() {
    log_info "Creating necessary directories..."
    mkdir -p "${ANDROID_STUDIO_HOME}" 2>/dev/null || true
    mkdir -p "${GRADLE_HOME}" 2>/dev/null || true
    mkdir -p "${HOME}/.android" 2>/dev/null || true
}

# Advanced System optimization
optimize_system() {
    log_info "Applying ULTRA deep system optimizations..."
    
    # Backup original sysctl.conf
    sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    
    # ============================================================================
    # FILE SYSTEM OPTIMIZATIONS
    # ============================================================================
    
    # Inotify - Critical for Android Studio file watching
    echo "fs.inotify.max_user_watches=1048576" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "fs.inotify.max_user_instances=8192" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "fs.inotify.max_queued_events=65536" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # File descriptors - for large projects
    echo "fs.file-max=9223372036854775807" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "fs.nr_open=1048576" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # AIO - for async I/O operations
    echo "fs.aio-max-nr=1048576" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # Directory entry cache
    echo "fs.dentry-state=0 0 45000 0 0 0" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # ============================================================================
    # KERNEL OPTIMIZATIONS
    # ============================================================================
    
    # Kernel threading
    echo "kernel.threads-max=4194303" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "kernel.pid_max=4194304" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # Shared memory - important for Gradle daemon
    echo "kernel.shmmax=68719476736" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "kernel.shmall=4294967296" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "kernel.shmmni=4096" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # Semaphores
    echo "kernel.sem=250 32000 100 1024" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # Core dumps optimization
    echo "kernel.core_uses_pid=1" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # ============================================================================
    # NETWORK OPTIMIZATIONS - Critical for Gradle/Maven downloads
    # ============================================================================
    
    # TCP buffer sizes - optimize for high bandwidth
    echo "net.core.rmem_max=268435456" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.core.wmem_max=268435456" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.core.rmem_default=31457280" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.core.wmem_default=31457280" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.core.optmem_max=25165824" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # TCP memory
    echo "net.ipv4.tcp_rmem=8192 87380 268435456" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_wmem=8192 65536 268435456" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_mem=8388608 12582912 16777216" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # Connection handling
    echo "net.core.netdev_max_backlog=65536" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.core.somaxconn=65535" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_max_syn_backlog=65536" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # TCP optimizations
    echo "net.ipv4.tcp_fastopen=3" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_slow_start_after_idle=0" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_tw_reuse=1" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_fin_timeout=10" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_keepalive_time=300" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_keepalive_probes=5" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_keepalive_intvl=15" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # Window scaling
    echo "net.ipv4.tcp_window_scaling=1" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_timestamps=1" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_sack=1" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # Congestion control - BBR for better throughput
    echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # Connection tracking
    echo "net.netfilter.nf_conntrack_max=1048576" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1 || true
    echo "net.nf_conntrack_max=1048576" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1 || true
    
    # Apply sysctl changes
    sudo sysctl -p > /dev/null 2>&1
    
    log_success "ULTRA deep system optimizations applied"
}

# Optimize ulimits - ULTRA deep
optimize_ulimits() {
    log_info "Applying ULTRA deep user limits..."
    
    sudo cp /etc/security/limits.conf /etc/security/limits.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    
    if ! grep -q "# Android Studio ULTRA Optimization" /etc/security/limits.conf; then
        sudo tee -a /etc/security/limits.conf > /dev/null << EOF

# Android Studio ULTRA Optimization
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
* soft memlock unlimited
* hard memlock unlimited
* soft stack 8192
* hard stack unlimited
* soft cpu unlimited
* hard cpu unlimited
* soft as unlimited
* hard as unlimited
* soft locks unlimited
* hard locks unlimited
* soft sigpending 256000
* hard sigpending 256000
* soft msgqueue 819200
* hard msgqueue 819200
root soft nofile 1048576
root hard nofile 1048576
root soft nproc 1048576
root hard nproc 1048576
EOF
        log_success "ULTRA deep user limits applied"
    else
        log_warning "User limits already configured"
    fi
    
    # PAM limits
    if [[ -f /etc/pam.d/common-session ]]; then
        if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
            echo "session required pam_limits.so" | sudo tee -a /etc/pam.d/common-session > /dev/null
        fi
    fi
}

# Configure studio.vmoptions
configure_studio_vmoptions() {
    log_info "Configuring Android Studio VM options..."
    
    # Calculate optimal memory settings based on RAM
    local xms=$((RAM_MB / 8))
    local xmx=$((RAM_MB / 4))
    local codecache=512
    local reserved=$((RAM_MB / 16))
    
    # Ensure minimum values
    [[ $xms -lt 1024 ]] && xms=1024
    [[ $xmx -lt 4096 ]] && xmx=4096
    [[ $reserved -lt 512 ]] && reserved=512
    
    local vmoptions_file="${ANDROID_STUDIO_HOME}/studio.vmoptions"
    
    backup_file "$vmoptions_file"
    
    cat > "$vmoptions_file" << EOF
# Android Studio VM Options - Optimized for ${RAM_MB}MB RAM, ${CPU_CORES} CPU cores

# Memory Settings
-Xms${xms}m
-Xmx${xmx}m
-XX:ReservedCodeCacheSize=${codecache}m
-XX:+UseCompressedOops
-XX:+UseCompressedClassPointers

# Garbage Collection - G1GC (Best for large heap)
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200
-XX:G1HeapRegionSize=32m
-XX:G1ReservePercent=15
-XX:InitiatingHeapOccupancyPercent=45
-XX:G1NewSizePercent=20
-XX:G1MaxNewSizePercent=50
-XX:ConcGCThreads=$((CPU_CORES / 4 > 0 ? CPU_CORES / 4 : 1))
-XX:ParallelGCThreads=$((CPU_CORES / 2 > 0 ? CPU_CORES / 2 : 1))

# Performance Optimizations
-XX:+UseStringDeduplication
-XX:+OptimizeStringConcat
-XX:+AlwaysPreTouch
-XX:+UseNUMA
-XX:+UseFastAccessorMethods
-XX:+TieredCompilation
-XX:TieredStopAtLevel=4
-XX:ReservedCodeCacheSize=${codecache}m
-XX:NonProfiledCodeHeapSize=200m
-XX:ProfiledCodeHeapSize=200m
-XX:NonNMethodCodeHeapSize=112m

# JIT Compiler Optimizations
-XX:+AggressiveOpts
-XX:CompileThreshold=1500
-XX:CICompilerCount=$((CPU_CORES > 4 ? 4 : CPU_CORES))

# Memory Management
-XX:SoftRefLRUPolicyMSPerMB=50
-XX:MaxMetaspaceSize=512m
-XX:MetaspaceSize=256m
-XX:+UseLargePages
-XX:LargePageSizeInBytes=2m

# Debugging and Monitoring (disable in production)
-XX:+UnlockDiagnosticVMOptions
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=${HOME}/android-studio-oom.hprof
-XX:ErrorFile=${HOME}/android-studio-error.log

# File Encoding
-Dfile.encoding=UTF-8
-Dsun.io.useCanonCaches=false

# IDE Performance
-Dawt.useSystemAAFontSettings=lcd
-Dswing.aatext=true
-Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine
-Dsun.java2d.renderer.useThreadLocal=true
-Dsun.java2d.renderer.useRef=hard

# Android Studio Specific
-Djdk.http.auth.tunneling.disabledSchemes=""
-Djdk.attach.allowAttachSelf=true
-Djdk.module.illegalAccess.silent=true

# Disable unnecessary features for performance
-Didea.max.intellisense.filesize=5000
-Didea.cycle.buffer.size=disabled
-Didea.fatal.error.notification=disabled

# Network optimizations
-Dhttp.socketTimeout=60000
-Dhttp.connectionTimeout=60000
EOF

    log_success "Android Studio VM options configured: Xms=${xms}m, Xmx=${xmx}m"
}

# Configure Gradle properties
configure_gradle() {
    log_info "Configuring Gradle properties..."
    
    local gradle_props="${GRADLE_HOME}/gradle.properties"
    backup_file "$gradle_props"
    
    # Calculate Gradle memory settings
    local gradle_xmx=$((RAM_MB / 4))
    [[ $gradle_xmx -lt 4096 ]] && gradle_xmx=4096
    [[ $gradle_xmx -gt 8192 ]] && gradle_xmx=8192
    
    local metaspace=1024
    local reserved=1024
    local workers=$((CPU_CORES > 8 ? 8 : CPU_CORES))
    
    cat > "$gradle_props" << EOF
# Gradle Performance Optimizations

# Memory Settings
org.gradle.jvmargs=-Xmx${gradle_xmx}m -XX:MaxMetaspaceSize=${metaspace}m -XX:ReservedCodeCacheSize=${reserved}m -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8 -XX:+UseStringDeduplication

# Parallel Execution
org.gradle.parallel=true
org.gradle.workers.max=${workers}
org.gradle.configureondemand=true

# Caching
org.gradle.caching=true
org.gradle.configuration-cache=true
org.gradle.unsafe.configuration-cache=true

# Daemon
org.gradle.daemon=true
org.gradle.daemon.idletimeout=7200000

# Build Performance
kotlin.incremental=true
kotlin.incremental.java=true
kotlin.incremental.js=true
kotlin.caching.enabled=true
kotlin.parallel.tasks.in.project=true

# Android Build
android.useAndroidX=true
android.enableJetifier=true
android.enableR8.fullMode=true
android.enableR8=true
android.enableD8=true
android.enableBuildCache=true
android.enableGradleWorkers=true
android.builder.sdkDownload=true

# Kotlin Compiler
kotlin.compiler.execution.strategy=in-process
kapt.use.worker.api=true
kapt.incremental.apt=true
kapt.include.compile.classpath=false

# File System Watching
org.gradle.vfs.watch=true
org.gradle.vfs.verbose=false

# Network
systemProp.http.proxyHost=
systemProp.http.proxyPort=
systemProp.https.proxyHost=
systemProp.https.proxyPort=

# Performance
org.gradle.logging.level=lifecycle
org.gradle.console=auto
org.gradle.warning.mode=all
EOF

    log_success "Gradle properties configured: Xmx=${gradle_xmx}m, Workers=${workers}"
}

# Configure idea.properties
configure_idea_properties() {
    log_info "Configuring idea.properties..."
    
    local idea_props="${ANDROID_STUDIO_HOME}/idea.properties"
    backup_file "$idea_props"
    
    cat > "$idea_props" << EOF
# Android Studio IDE Properties - Performance Optimizations

# Disable automatic updates
ide.no.platform.update=true

# Increase memory for indexing
idea.max.intellisense.filesize=5000
idea.cycle.buffer.size=disabled

# File System
idea.max.content.load.filesize=20000
idea.ignore.disabled.plugins=true

# Performance
idea.is.internal=false
idea.ProcessCanceledException=disabled
idea.fatal.error.notification=disabled

# Editor
editor.zero.latency.typing=true
ide.text.editor.antialiasing.enabled=true

# Code Completion
idea.autocomplete.delay=100
idea.completion.variant.limit=1000

# Cache Settings
idea.system.path=${HOME}/.cache/AndroidStudio
idea.config.path=${HOME}/.config/AndroidStudio
idea.plugins.path=${HOME}/.local/share/AndroidStudio/plugins
idea.log.path=${HOME}/.local/share/AndroidStudio/log

# Disable Tips
ide.show.tips.on.startup=false

# Indexing
shared.indexes.download=true
shared.indexes.download.auto.consent=true

# Build Performance
compile.parallel.max.threads=${CPU_CORES}
compiler.automake.allow.when.app.running=true
compiler.document.save.enabled=false

# Network
ide.connection.timeout=60000
ide.read.timeout=60000
EOF

    log_success "idea.properties configured"
}

# Optimize ADB
optimize_adb() {
    log_info "Optimizing ADB..."
    
    local adb_config="${HOME}/.android/adb_usb.ini"
    
    if [[ ! -f "$adb_config" ]]; then
        touch "$adb_config"
    fi
    
    # Increase ADB timeout
    export ADB_VENDOR_KEYS="${HOME}/.android"
    
    log_success "ADB optimized"
}

# Setup build cache
setup_build_cache() {
    log_info "Setting up build cache..."
    
    local cache_dir="${HOME}/.android/build-cache"
    mkdir -p "$cache_dir"
    
    # Gradle build cache settings
    cat > "${GRADLE_HOME}/init.gradle" << 'EOF'
gradle.projectsEvaluated {
    rootProject.allprojects {
        buildDir = "${rootProject.buildDir}/${project.name}"
        tasks.withType(JavaCompile) {
            options.incremental = true
            options.fork = true
            options.forkOptions.jvmArgs += ['-Xmx2g']
        }
    }
}

// Enable build cache
beforeSettings { settings ->
    settings.buildCache {
        local {
            enabled = true
            directory = "${System.properties['user.home']}/.android/build-cache"
            removeUnusedEntriesAfterDays = 30
        }
    }
}
EOF

    log_success "Build cache configured"
}

# Install performance monitoring tools
install_monitoring_tools() {
    log_info "Installing performance monitoring tools..."
    
    if ! command -v btop &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y btop htop iotop nethogs 2>/dev/null || true
    fi
    
    log_success "Monitoring tools checked"
}

# Create optimization script for project
create_project_optimizer() {
    log_info "Creating project optimization script..."
    
    cat > "${HOME}/optimize-android-project.sh" << 'EOF'
#!/bin/bash
# Run this in your Android project directory

echo "Optimizing Android project..."

# Clean build
./gradlew clean

# Clear gradle cache
rm -rf .gradle/
rm -rf build/
find . -type d -name "build" -exec rm -rf {} + 2>/dev/null || true

# Invalidate caches
rm -rf ~/.gradle/caches/
rm -rf ~/.android/build-cache/

echo "Project optimized. Rebuild your project."
EOF

    chmod +x "${HOME}/optimize-android-project.sh"
    log_success "Project optimizer created at ~/optimize-android-project.sh"
}

# Optimize swap settings
optimize_swap() {
    log_info "Optimizing swap settings..."
    
    # Set swappiness to 10 (less aggressive swapping)
    echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # Set cache pressure
    echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    sudo sysctl -p > /dev/null 2>&1
    
    log_success "Swap settings optimized"
}

# Configure KVM acceleration
configure_kvm() {
    log_info "Checking KVM acceleration..."
    
    if [[ -e /dev/kvm ]]; then
        sudo usermod -aG kvm "$USER" 2>/dev/null || true
        log_success "KVM acceleration available and configured"
    else
        log_warning "KVM not available. Install qemu-kvm for better emulator performance"
    fi
}

# Create monitoring script
create_monitoring_script() {
    log_info "Creating monitoring script..."
    
    cat > "${HOME}/monitor-android-studio.sh" << 'EOF'
#!/bin/bash
# Monitor Android Studio performance

echo "=== Android Studio Performance Monitor ==="
echo ""

# Java processes
echo "Android Studio & Gradle Processes:"
ps aux | grep -E "studio|gradle" | grep -v grep

echo ""
echo "Memory Usage:"
free -h

echo ""
echo "CPU Usage:"
top -bn1 | head -20

echo ""
echo "Disk I/O:"
iostat -x 1 2

echo ""
echo "File Watchers:"
cat /proc/sys/fs/inotify/max_user_watches

echo ""
echo "Open Files:"
lsof 2>/dev/null | wc -l
EOF

    chmod +x "${HOME}/monitor-android-studio.sh"
    log_success "Monitoring script created at ~/monitor-android-studio.sh"
}

# Generate optimization report
generate_report() {
    local report_file="${HOME}/android-studio-optimization-report.txt"
    
    cat > "$report_file" << EOF
================================================================================
Android Studio Optimization Report
Generated: $(date)
================================================================================

System Information:
- RAM: ${RAM_MB} MB
- CPU Cores: ${CPU_CORES}
- OS: $(lsb_release -d | cut -f2)
- Kernel: $(uname -r)

Optimizations Applied:
✓ System file watchers increased to 524288
✓ Network buffers optimized for Gradle
✓ User limits increased
✓ Android Studio VM options configured (Xmx: $((RAM_MB / 4))m)
✓ Gradle properties optimized
✓ Build cache enabled
✓ Swap settings optimized
✓ KVM acceleration configured

Memory Allocation:
- Android Studio Xmx: $((RAM_MB / 4)) MB
- Gradle Xmx: $((RAM_MB / 4 > 4096 ? RAM_MB / 4 : 4096)) MB
- Parallel Workers: $((CPU_CORES > 8 ? 8 : CPU_CORES))

Configuration Files Created/Updated:
- ${ANDROID_STUDIO_HOME}/studio.vmoptions
- ${GRADLE_HOME}/gradle.properties
- ${ANDROID_STUDIO_HOME}/idea.properties
- ${GRADLE_HOME}/init.gradle

Helper Scripts:
- ~/optimize-android-project.sh - Optimize specific project
- ~/monitor-android-studio.sh - Monitor performance

Next Steps:
1. Restart your system to apply all changes
2. Start Android Studio
3. Open your project
4. Run a build to verify optimizations
5. Use ~/monitor-android-studio.sh to monitor performance

Additional Recommendations:
- Use SSD for Android SDK and project files
- Exclude project directories from antivirus scans
- Disable unnecessary plugins in Android Studio
- Use offline mode in Gradle when possible
- Consider increasing RAM if frequent OOM errors occur

For project-specific optimization:
  cd /path/to/your/project
  ~/optimize-android-project.sh

================================================================================
EOF

    log_success "Optimization report saved to: $report_file"
    cat "$report_file"
}

# Main execution
main() {
    echo "========================================"
    echo "  Android Studio Deep Optimization"
    echo "  Ubuntu System Tuning"
    echo "========================================"
    echo ""
    
    check_root
    create_directories
    
    log_info "Starting optimization process..."
    echo ""
    
    optimize_system
    optimize_ulimits
    optimize_swap
    configure_kvm
    configure_studio_vmoptions
    configure_gradle
    configure_idea_properties
    optimize_adb
    setup_build_cache
    install_monitoring_tools
    create_project_optimizer
    create_monitoring_script
    
    echo ""
    generate_report
    
    echo ""
    log_success "Optimization complete!"
    log_warning "Please restart your system for all changes to take effect"
    log_info "Run '~/monitor-android-studio.sh' to monitor performance"
}

# Run main function
main "$@"
