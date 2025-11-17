#!/bin/bash
################################################################################
# ENVIRONMENT DETECTION - Detect distro, version, cgroup, systemd
################################################################################

# Global environment variables
ULTRA_DISTRO=""
ULTRA_DISTRO_VERSION=""
ULTRA_KERNEL_VERSION=""
ULTRA_CGROUP_VERSION=""
ULTRA_HAS_SYSTEMD=false
ULTRA_IS_CONTAINER=false
ULTRA_IS_VM=false

ultra_detect_env() {
    ultra_detect_distro
    ultra_detect_kernel
    ultra_detect_cgroup
    ultra_detect_systemd
    ultra_detect_virtualization
}

ultra_detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        ULTRA_DISTRO="${ID}"
        ULTRA_DISTRO_VERSION="${VERSION_ID}"
        
        # Validate Ubuntu
        if [[ "$ULTRA_DISTRO" != "ubuntu" ]]; then
            ultra_log_warn "This framework is designed for Ubuntu. Detected: $ULTRA_DISTRO"
            ultra_log_warn "Some features may not work correctly."
        fi
        
        # Check minimum version (22.04)
        if [[ "$ULTRA_DISTRO" == "ubuntu" ]]; then
            local version_major="${ULTRA_DISTRO_VERSION%%.*}"
            if (( version_major < 22 )); then
                ultra_log_error "Ubuntu 22.04+ required. Detected: $ULTRA_DISTRO_VERSION"
                return 1
            fi
        fi
        
        ultra_log_debug "Distro: $ULTRA_DISTRO $ULTRA_DISTRO_VERSION"
    else
        ultra_log_error "Cannot detect distribution (no /etc/os-release)"
        return 1
    fi
}

ultra_detect_kernel() {
    ULTRA_KERNEL_VERSION=$(uname -r)
    ultra_log_debug "Kernel: $ULTRA_KERNEL_VERSION"
    
    # Parse kernel version for comparison
    local kernel_major=$(echo "$ULTRA_KERNEL_VERSION" | cut -d. -f1)
    local kernel_minor=$(echo "$ULTRA_KERNEL_VERSION" | cut -d. -f2)
    
    # Warn if kernel is too old (< 5.15)
    if (( kernel_major < 5 )) || (( kernel_major == 5 && kernel_minor < 15 )); then
        ultra_log_warn "Kernel 5.15+ recommended. Detected: $ULTRA_KERNEL_VERSION"
    fi
}

ultra_detect_cgroup() {
    if [[ -f /proc/cgroups ]]; then
        if grep -q "cgroup2" /proc/filesystems 2>/dev/null; then
            if mountpoint -q /sys/fs/cgroup 2>/dev/null; then
                if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
                    ULTRA_CGROUP_VERSION="v2"
                else
                    ULTRA_CGROUP_VERSION="hybrid"
                fi
            else
                ULTRA_CGROUP_VERSION="v1"
            fi
        else
            ULTRA_CGROUP_VERSION="v1"
        fi
        
        ultra_log_debug "Cgroup: $ULTRA_CGROUP_VERSION"
    else
        ULTRA_CGROUP_VERSION="none"
        ultra_log_warn "No cgroup support detected"
    fi
}

ultra_detect_systemd() {
    if command -v systemctl &>/dev/null && [[ -d /run/systemd/system ]]; then
        ULTRA_HAS_SYSTEMD=true
        local systemd_version=$(systemctl --version | head -1 | awk '{print $2}')
        ultra_log_debug "Systemd: version $systemd_version"
    else
        ULTRA_HAS_SYSTEMD=false
        ultra_log_warn "Systemd not detected"
    fi
}

ultra_detect_virtualization() {
    # Check if running in container
    if [[ -f /.dockerenv ]] || grep -q "docker\|lxc" /proc/1/cgroup 2>/dev/null; then
        ULTRA_IS_CONTAINER=true
        ultra_log_debug "Environment: Container"
    fi
    
    # Check if running in VM
    if command -v systemd-detect-virt &>/dev/null; then
        local virt_type=$(systemd-detect-virt)
        if [[ "$virt_type" != "none" ]]; then
            ULTRA_IS_VM=true
            ultra_log_debug "Environment: VM ($virt_type)"
        fi
    elif lscpu | grep -q "Hypervisor vendor"; then
        ULTRA_IS_VM=true
        ultra_log_debug "Environment: VM (detected via lscpu)"
    fi
    
    if [[ "$ULTRA_IS_CONTAINER" == "false" ]] && [[ "$ULTRA_IS_VM" == "false" ]]; then
        ultra_log_debug "Environment: Bare metal"
    fi
}

ultra_get_distro() {
    echo "$ULTRA_DISTRO"
}

ultra_get_distro_version() {
    echo "$ULTRA_DISTRO_VERSION"
}

ultra_get_kernel_version() {
    echo "$ULTRA_KERNEL_VERSION"
}

ultra_has_systemd() {
    [[ "$ULTRA_HAS_SYSTEMD" == "true" ]]
}

ultra_is_container() {
    [[ "$ULTRA_IS_CONTAINER" == "true" ]]
}

ultra_is_vm() {
    [[ "$ULTRA_IS_VM" == "true"  ]]
}

ultra_get_cgroup_version() {
    echo "$ULTRA_CGROUP_VERSION"
}

ultra_check_root() {
    if [[ $EUID -ne 0 ]]; then
        ultra_log_error "This script must be run as root"
        return 1
    fi
}
