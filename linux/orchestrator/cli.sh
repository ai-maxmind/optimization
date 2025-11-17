#!/bin/bash
################################################################################
# Ubuntu Ultra Optimizer - Main CLI Entry Point
# Version 1.0.0 - Enterprise-grade Ubuntu optimization framework
# 30 modules | Dependency resolution | Parallel execution | Auto-validation
################################################################################

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Set global paths
export ULTRA_ROOT_DIR="$PARENT_DIR"
export ULTRA_MODULES_DIR="$PARENT_DIR/modules"
export ULTRA_PROFILE_DIR="$PARENT_DIR/profiles"
export ULTRA_CORE_DIR="$PARENT_DIR/core"
export ULTRA_STATE_DIR="/var/lib/ubuntu-ultra-opt/state"
export ULTRA_BACKUP_DIR="/var/lib/ubuntu-ultra-opt/backups"
export ULTRA_BENCHMARK_DIR="/var/lib/ubuntu-ultra-opt/benchmarks"
export ULTRA_LOG_FILE="/var/log/ubuntu-ultra-opt/ubuntu-ultra-opt.log"

# Advanced features flags (can be set via args)
export ULTRA_ENABLE_PARALLEL="${ULTRA_ENABLE_PARALLEL:-false}"
export ULTRA_ENABLE_VALIDATION="${ULTRA_ENABLE_VALIDATION:-false}"
export ULTRA_AUTO_ROLLBACK="${ULTRA_AUTO_ROLLBACK:-false}"
export ULTRA_PARALLEL_MAX_JOBS="${ULTRA_PARALLEL_MAX_JOBS:-4}"

# Source core libraries
source "$ULTRA_CORE_DIR/runtime/args.sh"
source "$ULTRA_CORE_DIR/runtime/env.sh"
source "$ULTRA_CORE_DIR/runtime/state.sh"
source "$ULTRA_CORE_DIR/log/log.sh"
source "$ULTRA_CORE_DIR/fs/backup.sh"
source "$ULTRA_CORE_DIR/fs/sysctl_io.sh"
source "$ULTRA_CORE_DIR/fs/file_edit.sh"
source "$ULTRA_CORE_DIR/hw/cpu.sh"
source "$ULTRA_CORE_DIR/hw/mem.sh"
source "$ULTRA_CORE_DIR/hw/storage.sh"
source "$ULTRA_CORE_DIR/hw/net.sh"

# Source orchestrator components
source "$SCRIPT_DIR/loader.sh"
source "$SCRIPT_DIR/executor.sh"

# Source advanced orchestrator features (if enabled)
if [[ "$ULTRA_ENABLE_PARALLEL" == "true" ]] || [[ -f "$SCRIPT_DIR/dependency.sh" ]]; then
    [[ -f "$SCRIPT_DIR/dependency.sh" ]] && source "$SCRIPT_DIR/dependency.sh"
    [[ -f "$SCRIPT_DIR/parallel.sh" ]] && source "$SCRIPT_DIR/parallel.sh"
fi

if [[ "$ULTRA_ENABLE_VALIDATION" == "true" ]] || [[ -f "$SCRIPT_DIR/validation.sh" ]]; then
    [[ -f "$SCRIPT_DIR/validation.sh" ]] && source "$SCRIPT_DIR/validation.sh"
fi

[[ -f "$SCRIPT_DIR/profiler.sh" ]] && source "$SCRIPT_DIR/profiler.sh"
[[ -f "$SCRIPT_DIR/benchmark.sh" ]] && source "$SCRIPT_DIR/benchmark.sh"

main() {
    # Parse arguments
    ultra_parse_args "$@"
    
    # Initialize logging
    ultra_log_init
    
    ultra_log_section "Ubuntu Ultra Optimizer v1.0.0"
    ultra_log_info "Profile: $(ultra_get_profile)"
    ultra_log_info "Stage: $(ultra_get_stage)"
    ultra_log_info "Max Risk: $(ultra_get_max_risk)"
    
    # Show advanced features status
    if [[ "$ULTRA_ENABLE_PARALLEL" == "true" ]]; then
        ultra_log_info "Parallel Execution: ENABLED (max jobs: $ULTRA_PARALLEL_MAX_JOBS)"
    fi
    
    if [[ "$ULTRA_ENABLE_VALIDATION" == "true" ]]; then
        ultra_log_info "Live Validation: ENABLED"
        if [[ "$ULTRA_AUTO_ROLLBACK" == "true" ]]; then
            ultra_log_info "Auto-Rollback: ENABLED"
        fi
    fi
    
    if ultra_is_dry_run; then
        ultra_log_warn "DRY-RUN MODE: No changes will be made"
    fi
    
    # Check root
    if ! ultra_check_root; then
        exit 1
    fi
    
    # Detect environment
    ultra_log_section "Environment Detection"
    if ! ultra_detect_env; then
        ultra_log_error "Environment detection failed"
        exit 1
    fi
    
    ultra_log_info "Distribution: $(ultra_get_distro) $(ultra_get_distro_version)"
    ultra_log_info "Kernel: $(ultra_get_kernel_version)"
    ultra_log_info "Cgroup: $(ultra_get_cgroup_version)"
    ultra_log_info "Systemd: $(ultra_has_systemd && echo "yes" || echo "no")"
    ultra_log_info "Container: $(ultra_is_container && echo "yes" || echo "no")"
    ultra_log_info "VM: $(ultra_is_vm && echo "yes" || echo "no")"
    
    # Detect hardware
    ultra_log_section "Hardware Detection"
    ultra_hw_cpu_detect
    ultra_hw_mem_detect
    ultra_hw_storage_detect
    ultra_hw_net_detect
    
    ultra_log_info "CPU: $(ultra_hw_cpu_get_vendor) $(ultra_hw_cpu_get_cores_physical)C/$(ultra_hw_cpu_get_cores_logical)T"
    ultra_log_info "Memory: $(ultra_hw_mem_get_total_gb)GB"
    ultra_log_info "Storage devices: $(ultra_hw_storage_get_devices | wc -w)"
    ultra_log_info "Network interfaces: $(ultra_hw_net_get_interfaces | wc -w)"
    
    # Initialize state
    if ! ultra_is_dry_run; then
        ultra_state_init
        ultra_backup_init
        ultra_log_info "Run ID: $(ultra_state_get_run_id)"
        export ULTRA_CURRENT_RUN_ID="$(ultra_state_get_run_id)"
    fi
    
    # Collect baseline metrics if validation enabled
    if [[ "$ULTRA_ENABLE_VALIDATION" == "true" ]] && ! ultra_is_dry_run; then
        ultra_log_info "Collecting baseline metrics..."
        if declare -f ultra_validate_baseline &>/dev/null; then
            ultra_validate_baseline
        fi
    fi
    
    # Confirmation prompt
    if ! ultra_is_force && ! ultra_is_dry_run; then
        ultra_log_warn ""
        ultra_log_warn "⚠️  WARNING: This will modify system configuration"
        ultra_log_warn "   - Profile: $(ultra_get_profile)"
        ultra_log_warn "   - Max Risk: $(ultra_get_max_risk)"
        ultra_log_warn "   - Modules: 30 available"
        if [[ "$ULTRA_ENABLE_PARALLEL" == "true" ]]; then
            ultra_log_warn "   - Parallel execution: YES ($ULTRA_PARALLEL_MAX_JOBS jobs)"
        fi
        if [[ "$ULTRA_ENABLE_VALIDATION" == "true" ]]; then
            ultra_log_warn "   - Live validation: YES"
        fi
        ultra_log_warn "   - Backup: $ULTRA_BACKUP_DIR"
        ultra_log_warn "   - State: $ULTRA_STATE_DIR"
        ultra_log_warn ""
        
        read -p "Continue? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            ultra_log_info "Aborted by user"
            exit 0
        fi
    fi
    
    # Initialize module loader
    ultra_loader_init
    
    # Execute based on parameters
    local stage=$(ultra_get_stage)
    local module_filter=$(ultra_get_module_filter)
    
    if [[ -n "$module_filter" ]]; then
        # Run single module
        ultra_executor_run_single_module "$module_filter"
    elif [[ "$stage" == "all" ]]; then
        # Run all stages
        ultra_executor_run_all_stages
    else
        # Run specific stage
        ultra_executor_run_stage "$stage"
    fi
    
    local exit_code=$?
    
    # Post-optimization validation
    if [[ "$ULTRA_ENABLE_VALIDATION" == "true" ]] && ! ultra_is_dry_run && [[ $exit_code -eq 0 ]]; then
        ultra_log_info "Running post-optimization validation..."
        if declare -f ultra_validate_health &>/dev/null; then
            if ! ultra_validate_health; then
                ultra_log_warn "Validation detected issues"
                if [[ "$ULTRA_AUTO_ROLLBACK" == "true" ]]; then
                    ultra_log_warn "Auto-rollback triggered"
                    if declare -f ultra_validate_rollback_on_failure &>/dev/null; then
                        ultra_validate_rollback_on_failure
                    fi
                fi
            fi
        fi
    fi
    
    # Summary
    ultra_log_section "Optimization Complete"
    
    if [[ $exit_code -eq 0 ]]; then
        ultra_log_info "✓ All optimizations applied successfully"
        
        if ! ultra_is_dry_run; then
            ultra_log_info ""
            ultra_log_info "📊 Summary:"
            ultra_log_info "   Run ID: $(ultra_state_get_run_id)"
            ultra_log_info "   State: $(ultra_state_get_run_dir)"
            ultra_log_info "   Backup: $ULTRA_BACKUP_DIR/$(ultra_state_get_run_id)"
            
            if [[ "$ULTRA_ENABLE_PARALLEL" == "true" ]]; then
                ultra_log_info "   Parallel: Enabled"
            fi
            
            if [[ "$ULTRA_ENABLE_VALIDATION" == "true" ]]; then
                ultra_log_info "   Validation: Passed"
            fi
            
            ultra_log_info ""
            ultra_log_warn "⚠️  REBOOT RECOMMENDED for all changes to take effect"
            ultra_log_info ""
            ultra_log_info "📝 Next steps:"
            ultra_log_info "   • Verify: ./verify.sh"
            ultra_log_info "   • Benchmark: make benchmark"
            ultra_log_info "   • Rollback: ./orchestrator/rollback.sh $(ultra_state_get_run_id)"
        fi
    else
        ultra_log_error "✗ Some optimizations failed"
        if ! ultra_is_dry_run; then
            ultra_log_info ""
            ultra_log_info "Check logs: $ULTRA_LOG_FILE"
            ultra_log_info "Rollback if needed: ./orchestrator/rollback.sh $(ultra_state_get_run_id)"
        fi
        exit 1
    fi
}

# Trap errors
trap 'ultra_log_error "Script failed at line $LINENO"' ERR

# Run main
main "$@"
