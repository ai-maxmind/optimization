#!/bin/bash
# modules/security/sec-kernel-hardening.sh
# Module: Kernel security hardening
# Applies security-focused sysctl settings

MOD_ID="security.kernel-hardening"
MOD_DESC="Kernel security hardening"
MOD_STAGE="security"
MOD_RISK="medium"
MOD_DEFAULT_ENABLED="false"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Always available
    return 0
}

mod_apply() {
    ultra_log_module_start "$MOD_ID"
    ultra_log_info "Applying kernel security hardening..."
    
    local profile=$(ultra_get_profile)
    
    ultra_log_info "Security hardening profile: $profile"
    ultra_log_info ""
    ultra_log_info "This module applies security-focused kernel parameters:"
    ultra_log_info "  - ASLR (Address Space Layout Randomization)"
    ultra_log_info "  - Kernel pointer restrictions"
    ultra_log_info "  - Core dump restrictions"
    ultra_log_info "  - Network security (SYN cookies, ICMP redirects)"
    ultra_log_info "  - File system hardening"
    
    if ultra_is_dry_run; then
        ultra_log_info "[DRY-RUN] Would apply security hardening"
        ultra_state_finalize_module "$MOD_ID" "success"
        ultra_log_module_end "$MOD_ID"
        return 0
    fi
    
    # Kernel security settings
    
    # ASLR (Address Space Layout Randomization)
    # 0=disabled, 1=conservative, 2=full (recommended)
    ultra_apply_sysctl "kernel.randomize_va_space" "2" "$MOD_ID"
    
    # Restrict kernel pointer exposure
    # 0=unrestricted, 1=restricted, 2=hidden
    ultra_apply_sysctl "kernel.kptr_restrict" "2" "$MOD_ID"
    
    # Restrict dmesg to root
    ultra_apply_sysctl "kernel.dmesg_restrict" "1" "$MOD_ID"
    
    # Restrict access to kernel logs
    ultra_apply_sysctl "kernel.printk" "3 3 3 3" "$MOD_ID"
    
    # Core dump restrictions
    # Prevent setuid programs from dumping core
    ultra_apply_sysctl "fs.suid_dumpable" "0" "$MOD_ID"
    
    # Restrict ptrace to parent process only
    # 0=classic, 1=restricted, 2=admin-only, 3=no attach
    ultra_apply_sysctl "kernel.yama.ptrace_scope" "1" "$MOD_ID"
    
    # Network security
    
    # Enable SYN cookies (SYN flood protection)
    ultra_apply_sysctl "net.ipv4.tcp_syncookies" "1" "$MOD_ID"
    
    # Ignore ICMP redirects
    ultra_apply_sysctl "net.ipv4.conf.all.accept_redirects" "0" "$MOD_ID"
    ultra_apply_sysctl "net.ipv4.conf.default.accept_redirects" "0" "$MOD_ID"
    ultra_apply_sysctl "net.ipv6.conf.all.accept_redirects" "0" "$MOD_ID"
    ultra_apply_sysctl "net.ipv6.conf.default.accept_redirects" "0" "$MOD_ID"
    
    # Don't send ICMP redirects
    ultra_apply_sysctl "net.ipv4.conf.all.send_redirects" "0" "$MOD_ID"
    ultra_apply_sysctl "net.ipv4.conf.default.send_redirects" "0" "$MOD_ID"
    
    # Ignore ICMP echo requests (ping)
    # Disabled by default for connectivity, enable if paranoid
    # ultra_apply_sysctl "net.ipv4.icmp_echo_ignore_all" "1" "$MOD_ID"
    
    # Ignore broadcast ICMP
    ultra_apply_sysctl "net.ipv4.icmp_echo_ignore_broadcasts" "1" "$MOD_ID"
    
    # Enable source address verification (reverse path filter)
    # 0=no check, 1=strict, 2=loose
    ultra_apply_sysctl "net.ipv4.conf.all.rp_filter" "1" "$MOD_ID"
    ultra_apply_sysctl "net.ipv4.conf.default.rp_filter" "1" "$MOD_ID"
    
    # Log suspicious packets
    ultra_apply_sysctl "net.ipv4.conf.all.log_martians" "1" "$MOD_ID"
    ultra_apply_sysctl "net.ipv4.conf.default.log_martians" "1" "$MOD_ID"
    
    # Disable source routing
    ultra_apply_sysctl "net.ipv4.conf.all.accept_source_route" "0" "$MOD_ID"
    ultra_apply_sysctl "net.ipv4.conf.default.accept_source_route" "0" "$MOD_ID"
    ultra_apply_sysctl "net.ipv6.conf.all.accept_source_route" "0" "$MOD_ID"
    ultra_apply_sysctl "net.ipv6.conf.default.accept_source_route" "0" "$MOD_ID"
    
    # IPv6 privacy extensions
    ultra_apply_sysctl "net.ipv6.conf.all.use_tempaddr" "2" "$MOD_ID"
    ultra_apply_sysctl "net.ipv6.conf.default.use_tempaddr" "2" "$MOD_ID"
    
    # Disable IPv6 router advertisements
    ultra_apply_sysctl "net.ipv6.conf.all.accept_ra" "0" "$MOD_ID"
    ultra_apply_sysctl "net.ipv6.conf.default.accept_ra" "0" "$MOD_ID"
    
    # File system security
    
    # Protect hardlinks/symlinks
    ultra_apply_sysctl "fs.protected_hardlinks" "1" "$MOD_ID"
    ultra_apply_sysctl "fs.protected_symlinks" "1" "$MOD_ID"
    
    # Protect fifos
    if [[ -f /proc/sys/fs/protected_fifos ]]; then
        ultra_apply_sysctl "fs.protected_fifos" "2" "$MOD_ID"
    fi
    
    # Protect regular files
    if [[ -f /proc/sys/fs/protected_regular ]]; then
        ultra_apply_sysctl "fs.protected_regular" "2" "$MOD_ID"
    fi
    
    ultra_state_add_action "$MOD_ID" "sysctl" "Security hardening applied"
    ultra_log_info "✅ Security hardening configured"
    
    ultra_log_info ""
    ultra_log_info "⚠️  Additional security recommendations:"
    ultra_log_info "  1. Enable AppArmor/SELinux"
    ultra_log_info "  2. Configure firewall (ufw/iptables)"
    ultra_log_info "  3. Disable unnecessary services"
    ultra_log_info "  4. Keep system updated (unattended-upgrades)"
    ultra_log_info "  5. Use fail2ban for brute-force protection"
    ultra_log_info "  6. Enable audit logging (auditd)"
    ultra_log_info "  7. Secure SSH (disable password auth, use keys)"
    
    ultra_state_finalize_module "$MOD_ID" "success"
    ultra_log_module_end "$MOD_ID"
}

mod_rollback() {
    local run_id="$1"
    
    ultra_log_info "Rolling back $MOD_DESC..."
    
    # Rollback all security settings
    local settings=(
        "kernel.randomize_va_space"
        "kernel.kptr_restrict"
        "kernel.dmesg_restrict"
        "kernel.printk"
        "fs.suid_dumpable"
        "kernel.yama.ptrace_scope"
        "net.ipv4.tcp_syncookies"
        "net.ipv4.conf.all.accept_redirects"
        "net.ipv4.conf.default.accept_redirects"
        "net.ipv6.conf.all.accept_redirects"
        "net.ipv6.conf.default.accept_redirects"
        "net.ipv4.conf.all.send_redirects"
        "net.ipv4.conf.default.send_redirects"
        "net.ipv4.icmp_echo_ignore_broadcasts"
        "net.ipv4.conf.all.rp_filter"
        "net.ipv4.conf.default.rp_filter"
        "net.ipv4.conf.all.log_martians"
        "net.ipv4.conf.default.log_martians"
        "net.ipv4.conf.all.accept_source_route"
        "net.ipv4.conf.default.accept_source_route"
        "net.ipv6.conf.all.accept_source_route"
        "net.ipv6.conf.default.accept_source_route"
        "net.ipv6.conf.all.use_tempaddr"
        "net.ipv6.conf.default.use_tempaddr"
        "net.ipv6.conf.all.accept_ra"
        "net.ipv6.conf.default.accept_ra"
        "fs.protected_hardlinks"
        "fs.protected_symlinks"
        "fs.protected_fifos"
        "fs.protected_regular"
    )
    
    for setting in "${settings[@]}"; do
        ultra_rollback_sysctl "$setting" "$MOD_ID" "$run_id"
    done
}

mod_verify() {
    ultra_log_info "Security Hardening Configuration:"
    
    ultra_log_info ""
    ultra_log_info "Kernel security:"
    [[ -f /proc/sys/kernel/randomize_va_space ]] && echo "  ASLR: $(cat /proc/sys/kernel/randomize_va_space)"
    [[ -f /proc/sys/kernel/kptr_restrict ]] && echo "  kptr_restrict: $(cat /proc/sys/kernel/kptr_restrict)"
    [[ -f /proc/sys/kernel/dmesg_restrict ]] && echo "  dmesg_restrict: $(cat /proc/sys/kernel/dmesg_restrict)"
    [[ -f /proc/sys/kernel/yama/ptrace_scope ]] && echo "  ptrace_scope: $(cat /proc/sys/kernel/yama/ptrace_scope)"
    
    ultra_log_info ""
    ultra_log_info "Network security:"
    [[ -f /proc/sys/net/ipv4/tcp_syncookies ]] && echo "  SYN cookies: $(cat /proc/sys/net/ipv4/tcp_syncookies)"
    [[ -f /proc/sys/net/ipv4/conf/all/rp_filter ]] && echo "  Reverse path filter: $(cat /proc/sys/net/ipv4/conf/all/rp_filter)"
    [[ -f /proc/sys/net/ipv4/conf/all/accept_redirects ]] && echo "  Accept redirects: $(cat /proc/sys/net/ipv4/conf/all/accept_redirects)"
    [[ -f /proc/sys/net/ipv4/conf/all/log_martians ]] && echo "  Log martians: $(cat /proc/sys/net/ipv4/conf/all/log_martians)"
    
    ultra_log_info ""
    ultra_log_info "File system security:"
    [[ -f /proc/sys/fs/protected_hardlinks ]] && echo "  Protected hardlinks: $(cat /proc/sys/fs/protected_hardlinks)"
    [[ -f /proc/sys/fs/protected_symlinks ]] && echo "  Protected symlinks: $(cat /proc/sys/fs/protected_symlinks)"
    [[ -f /proc/sys/fs/suid_dumpable ]] && echo "  SUID dumpable: $(cat /proc/sys/fs/suid_dumpable)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This module should be run through the orchestrator"
    exit 1
fi
