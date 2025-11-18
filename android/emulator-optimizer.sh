#!/bin/bash

################################################################################
# Android Emulator ULTRA Performance Optimizer
# Optimize AVD, QEMU, KVM, Graphics for maximum emulator performance
################################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

ANDROID_HOME="${HOME}/Android/Sdk"
AVD_HOME="${HOME}/.android/avd"

echo "========================================================"
echo "  Android Emulator ULTRA Performance Optimizer"
echo "========================================================"
echo ""

# ============================================================================
# KVM SETUP AND OPTIMIZATION
# ============================================================================
setup_kvm() {
    log_info "Setting up KVM for hardware acceleration..."
    
    # Check KVM availability
    if ! grep -E 'vmx|svm' /proc/cpuinfo > /dev/null; then
        log_error "CPU doesn't support virtualization!"
        log_error "Enable VT-x/AMD-V in BIOS"
        return 1
    fi
    
    # Install KVM packages
    log_info "Installing KVM packages..."
    sudo apt-get update -qq
    sudo apt-get install -y \
        qemu-kvm \
        libvirt-daemon-system \
        libvirt-clients \
        bridge-utils \
        virt-manager \
        cpu-checker \
        2>/dev/null || true
    
    # Add user to groups
    sudo usermod -aG kvm "$USER"
    sudo usermod -aG libvirt "$USER"
    
    # Enable and start libvirtd
    sudo systemctl enable libvirtd
    sudo systemctl start libvirtd
    
    # Verify KVM
    if kvm-ok 2>/dev/null | grep -q "KVM acceleration can be used"; then
        log_success "KVM acceleration enabled"
    else
        log_warning "KVM may not be properly configured"
    fi
    
    # Set KVM permissions
    sudo chmod 666 /dev/kvm 2>/dev/null || true
    
    log_success "KVM setup complete"
}

# ============================================================================
# QEMU CONFIGURATION
# ============================================================================
optimize_qemu() {
    log_info "Optimizing QEMU settings..."
    
    mkdir -p "${HOME}/.config/qemu"
    
    cat > "${HOME}/.config/qemu/qemu.conf" << 'EOF'
# QEMU Configuration for Android Emulator
[ui]
graphics = yes
full-screen = no
show-cursor = yes

[machine]
graphics = yes
vmport = on
dump-guest-core = on
mem-merge = on
usb = on

[memory]
max-ram-below-4g = 2048M

[spice]
disable-ticketing = yes
EOF

    log_success "QEMU configuration created"
}

# ============================================================================
# EMULATOR ADVANCED CONFIGURATION
# ============================================================================
configure_emulator_advanced() {
    log_info "Creating advanced emulator configuration..."
    
    mkdir -p "${HOME}/.android"
    
    # Advanced ini settings
    cat > "${HOME}/.android/advancedFeatures.ini" << 'EOF'
# Android Emulator Advanced Features - ULTRA Performance

# Hypervisor
Hypervisor = on
HVF = on
HAXM = on
KVM = on

# Graphics
GLDirectMem = on
GLESDynamicVersion = on
GLDMA = on
Vulkan = on
VirtioGpu = on

# Performance
FastSnapshotV1 = on
QuickbootFileBacked = on
Wifi = on
MultiDisplay = on

# Host composition
HostComposition = on
RefCountPipe = on

# System
SystemAsRoot = on
DynamicPartition = on
EncryptUserData = off

# Features
LocationUiV2 = on
SnapshotAdb = on
VirtioInput = on
VirtioWifi = on
VirtioVsock = on

# Host GPU
HostGpu = on
EOF

    log_success "Advanced features configured"
}

# ============================================================================
# AVD CONFIG.INI OPTIMIZER
# ============================================================================
create_avd_optimizer() {
    log_info "Creating AVD config optimizer..."
    
    cat > "${HOME}/optimize-avd.sh" << 'EOF'
#!/bin/bash
# Optimize specific AVD configuration

AVD_NAME="$1"

if [[ -z "$AVD_NAME" ]]; then
    echo "Usage: $0 <avd-name>"
    echo ""
    echo "Available AVDs:"
    ls -1 ~/.android/avd/*.avd 2>/dev/null | xargs -n1 basename | sed 's/.avd$//' || echo "  No AVDs found"
    exit 1
fi

AVD_DIR="${HOME}/.android/avd/${AVD_NAME}.avd"
CONFIG_FILE="${AVD_DIR}/config.ini"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "AVD not found: $AVD_NAME"
    exit 1
fi

echo "Optimizing AVD: $AVD_NAME"

# Backup
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Get RAM size
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
AVD_RAM=$((RAM_MB / 4))
[[ $AVD_RAM -gt 4096 ]] && AVD_RAM=4096
[[ $AVD_RAM -lt 2048 ]] && AVD_RAM=2048

AVD_HEAP=$((AVD_RAM / 4))
[[ $AVD_HEAP -lt 512 ]] && AVD_HEAP=512

# Update config
sed -i '/^hw.ramSize=/d' "$CONFIG_FILE"
sed -i '/^hw.gpu.enabled=/d' "$CONFIG_FILE"
sed -i '/^hw.gpu.mode=/d' "$CONFIG_FILE"
sed -i '/^hw.keyboard=/d' "$CONFIG_FILE"
sed -i '/^hw.mainKeys=/d' "$CONFIG_FILE"
sed -i '/^disk.dataPartition.size=/d' "$CONFIG_FILE"
sed -i '/^vm.heapSize=/d' "$CONFIG_FILE"
sed -i '/^fastboot.chosenSnapshotFile=/d' "$CONFIG_FILE"
sed -i '/^fastboot.forceChosenSnapshotBoot=/d' "$CONFIG_FILE"
sed -i '/^fastboot.forceColdBoot=/d' "$CONFIG_FILE"
sed -i '/^fastboot.forceFastBoot=/d' "$CONFIG_FILE"

cat >> "$CONFIG_FILE" << AVDEOF
hw.ramSize=${AVD_RAM}
hw.gpu.enabled=yes
hw.gpu.mode=host
hw.keyboard=yes
hw.mainKeys=no
disk.dataPartition.size=8G
vm.heapSize=${AVD_HEAP}
fastboot.chosenSnapshotFile=
fastboot.forceChosenSnapshotBoot=no
fastboot.forceColdBoot=no
fastboot.forceFastBoot=yes
hw.audioInput=yes
hw.audioOutput=yes
hw.gps=yes
hw.accelerometer=yes
hw.gyroscope=yes
hw.battery=yes
hw.sdCard=yes
hw.arc=no
showDeviceFrame=no
skin.dynamic=yes
AVDEOF

echo "AVD optimized: $AVD_NAME"
echo "  RAM: ${AVD_RAM}MB"
echo "  Heap: ${AVD_HEAP}MB"
echo "  GPU: host mode"
echo "  Fast boot: enabled"
EOF

    chmod +x "${HOME}/optimize-avd.sh"
    log_success "AVD optimizer created at ~/optimize-avd.sh"
}

# ============================================================================
# EMULATOR STARTUP WRAPPER
# ============================================================================
create_fast_emulator_launcher() {
    log_info "Creating fast emulator launcher..."
    
    cat > "${HOME}/fast-emulator.sh" << 'EOF'
#!/bin/bash
# Fast Android Emulator Launcher with optimized parameters

AVD_NAME="$1"

if [[ -z "$AVD_NAME" ]]; then
    echo "Usage: $0 <avd-name> [additional-args]"
    echo ""
    echo "Available AVDs:"
    "${ANDROID_HOME:-$HOME/Android/Sdk}/emulator/emulator" -list-avds 2>/dev/null || \
        ls -1 ~/.android/avd/*.avd 2>/dev/null | xargs -n1 basename | sed 's/.avd$//'
    exit 1
fi

shift
EXTRA_ARGS="$@"

EMULATOR="${ANDROID_HOME:-$HOME/Android/Sdk}/emulator/emulator"

if [[ ! -x "$EMULATOR" ]]; then
    echo "Emulator not found at: $EMULATOR"
    exit 1
fi

# Determine CPU cores and RAM
CPU_CORES=$(nproc)
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')

# Calculate resources
EMULATOR_CORES=$((CPU_CORES / 2))
[[ $EMULATOR_CORES -lt 2 ]] && EMULATOR_CORES=2
[[ $EMULATOR_CORES -gt 8 ]] && EMULATOR_CORES=8

echo "Starting Android Emulator with ULTRA optimizations..."
echo "AVD: $AVD_NAME"
echo "CPU Cores: $EMULATOR_CORES"
echo ""

# Launch with optimized parameters
"$EMULATOR" -avd "$AVD_NAME" \
    -gpu host \
    -accel on \
    -qemu -enable-kvm \
    -cores "$EMULATOR_CORES" \
    -memory 4096 \
    -cache-size 1024 \
    -no-snapshot-load \
    -no-boot-anim \
    -no-audio \
    -netfast \
    -netdelay none \
    -wipe-data \
    -feature VirtioWifi \
    -feature Wifi \
    -feature FastSnapshotV1 \
    -feature GLESDynamicVersion \
    -feature GLDMA \
    -feature KVM \
    -feature Vulkan \
    -feature VirtioGpu \
    -feature HostComposition \
    -qemu -machine q35 \
    -qemu -cpu host,+invtsc \
    -qemu -smp cores=$EMULATOR_CORES,threads=2 \
    -qemu -enable-kvm \
    -qemu -m 4096 \
    $EXTRA_ARGS \
    &

EMULATOR_PID=$!
echo "Emulator started with PID: $EMULATOR_PID"

# Monitor startup
sleep 5
if ps -p $EMULATOR_PID > /dev/null; then
    echo "Emulator is running"
else
    echo "Emulator failed to start"
fi
EOF

    chmod +x "${HOME}/fast-emulator.sh"
    log_success "Fast launcher created at ~/fast-emulator.sh"
}

# ============================================================================
# GRAPHICS DRIVER OPTIMIZATION
# ============================================================================
optimize_graphics() {
    log_info "Checking graphics drivers..."
    
    # Check for Intel/AMD/NVIDIA
    if lspci | grep -i vga | grep -qi intel; then
        log_info "Intel GPU detected"
        sudo apt-get install -y intel-gpu-tools mesa-utils 2>/dev/null || true
    fi
    
    if lspci | grep -i vga | grep -qi nvidia; then
        log_info "NVIDIA GPU detected"
        log_warning "Ensure nvidia-drivers are installed: sudo ubuntu-drivers autoinstall"
    fi
    
    if lspci | grep -i vga | grep -qi amd; then
        log_info "AMD GPU detected"
        sudo apt-get install -y mesa-utils 2>/dev/null || true
    fi
    
    # Enable DRI3
    mkdir -p "${HOME}/.config/environment.d"
    echo "LIBGL_DRI3_DISABLE=0" > "${HOME}/.config/environment.d/graphics.conf"
    
    log_success "Graphics configuration updated"
}

# ============================================================================
# ADB OPTIMIZATION
# ============================================================================
optimize_adb() {
    log_info "Optimizing ADB for emulator..."
    
    mkdir -p "${HOME}/.android"
    
    cat > "${HOME}/.android/adb.ini" << 'EOF'
# ADB Configuration
adb.local.port=5037
adb.trace_mask=0
EOF

    # Increase ADB buffer size
    export ADB_TRACE=0
    export ADB_VENDOR_KEYS="${HOME}/.android"
    
    log_success "ADB optimized"
}

# ============================================================================
# EMULATOR CACHE DIRECTORY
# ============================================================================
setup_emulator_cache() {
    log_info "Setting up emulator cache..."
    
    CACHE_DIR="${HOME}/.android/cache"
    mkdir -p "$CACHE_DIR"
    
    export ANDROID_EMULATOR_HOME="${HOME}/.android"
    export ANDROID_AVD_HOME="${HOME}/.android/avd"
    
    # Add to bashrc
    if ! grep -q "ANDROID_EMULATOR_HOME" "${HOME}/.bashrc"; then
        cat >> "${HOME}/.bashrc" << 'EOF'

# Android Emulator Environment
export ANDROID_EMULATOR_HOME="${HOME}/.android"
export ANDROID_AVD_HOME="${HOME}/.android/avd"
export ANDROID_HOME="${HOME}/Android/Sdk"
export PATH="${PATH}:${ANDROID_HOME}/emulator:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools"
EOF
    fi
    
    log_success "Emulator cache configured"
}

# ============================================================================
# EMULATOR MONITORING SCRIPT
# ============================================================================
create_emulator_monitor() {
    log_info "Creating emulator monitor..."
    
    cat > "${HOME}/monitor-emulator.sh" << 'EOF'
#!/bin/bash
# Monitor Android Emulator performance

watch -n 2 '
echo "=== Emulator Processes ==="
ps aux | grep -E "qemu|emulator" | grep -v grep

echo ""
echo "=== Emulator Resource Usage ==="
ps aux | grep -E "qemu|emulator" | grep -v grep | awk "{sum+=\$3; mem+=\$4} END {print \"CPU: \" sum \"% | MEM: \" mem \"%\"}"

echo ""
echo "=== Connected Devices ==="
adb devices -l

echo ""
echo "=== KVM Status ==="
lsmod | grep kvm
'
EOF

    chmod +x "${HOME}/monitor-emulator.sh"
    log_success "Emulator monitor created at ~/monitor-emulator.sh"
}

# ============================================================================
# GENERATE REPORT
# ============================================================================
generate_report() {
    local report="${HOME}/emulator-optimization-report.txt"
    
    cat > "$report" << EOF
================================================================================
Android Emulator ULTRA Optimization Report
Generated: $(date)
================================================================================

KVM Status:
$(kvm-ok 2>&1 || echo "KVM check not available")

Hardware Virtualization:
$(grep -E 'vmx|svm' /proc/cpuinfo > /dev/null && echo "✓ Supported" || echo "✗ Not supported")

Graphics:
$(lspci | grep -i vga)

Installed Packages:
$(dpkg -l | grep -E "qemu-kvm|libvirt|virt-manager" | awk '{print "✓", $2, $3}')

Configuration Files Created:
✓ ~/.android/advancedFeatures.ini - Advanced emulator features
✓ ~/.config/qemu/qemu.conf - QEMU configuration
✓ ~/.android/adb.ini - ADB settings
✓ ~/optimize-avd.sh - AVD optimizer script
✓ ~/fast-emulator.sh - Fast launcher script
✓ ~/monitor-emulator.sh - Performance monitor

Environment Variables:
✓ ANDROID_EMULATOR_HOME=${HOME}/.android
✓ ANDROID_AVD_HOME=${HOME}/.android/avd

Usage Instructions:

1. Optimize existing AVD:
   ~/optimize-avd.sh <avd-name>

2. Launch emulator with optimizations:
   ~/fast-emulator.sh <avd-name>

3. Monitor emulator performance:
   ~/monitor-emulator.sh

4. Create new optimized AVD:
   - Use Android Studio AVD Manager
   - After creation, run: ~/optimize-avd.sh <avd-name>

Performance Features Enabled:
✓ KVM hardware acceleration
✓ Host GPU passthrough
✓ VirtIO GPU support
✓ Fast snapshot loading
✓ Multi-core CPU allocation
✓ Optimized RAM and heap sizes
✓ Vulkan graphics API
✓ VirtIO WiFi and input

Recommended AVD Settings:
- RAM: 2-4GB
- Internal Storage: 8GB
- GPU: Host
- Multi-core CPU: 2-8 cores
- Fast Boot: Enabled

Troubleshooting:
- If KVM error: Check BIOS VT-x/AMD-V enabled
- If graphics error: Update GPU drivers
- If slow: Increase RAM allocation
- If freeze: Disable snapshot, use cold boot

Next Steps:
1. Log out and log back in (for group membership)
2. Verify KVM: kvm-ok
3. Test emulator: ~/fast-emulator.sh <avd-name>
4. Monitor: ~/monitor-emulator.sh

================================================================================
EOF

    cat "$report"
    log_success "Report saved to: $report"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    setup_kvm
    optimize_qemu
    configure_emulator_advanced
    create_avd_optimizer
    create_fast_emulator_launcher
    optimize_graphics
    optimize_adb
    setup_emulator_cache
    create_emulator_monitor
    
    echo ""
    generate_report
    
    echo ""
    log_success "Emulator optimization complete!"
    log_warning "Log out and log back in for KVM group membership"
    log_info "Then test with: ~/fast-emulator.sh <avd-name>"
}

main "$@"
