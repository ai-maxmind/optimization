#!/bin/bash
################################################################################
# ARGS PARSER - Parse command line arguments and flags
################################################################################

# Global variables for parsed arguments
ULTRA_PROFILE="${ULTRA_PROFILE:-server}"
ULTRA_DRY_RUN="${ULTRA_DRY_RUN:-false}"
ULTRA_VERBOSE="${ULTRA_VERBOSE:-false}"
ULTRA_FORCE="${ULTRA_FORCE:-false}"
ULTRA_STAGE="${ULTRA_STAGE:-all}"
ULTRA_MODULE_FILTER="${ULTRA_MODULE_FILTER:-}"
ULTRA_SKIP_BACKUP="${ULTRA_SKIP_BACKUP:-false}"
ULTRA_MAX_RISK="${ULTRA_MAX_RISK:-medium}"
ULTRA_BENCHMARK="${ULTRA_BENCHMARK:-false}"

ultra_parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--profile)
                ULTRA_PROFILE="$2"
                shift 2
                ;;
            -s|--stage)
                ULTRA_STAGE="$2"
                shift 2
                ;;
            -m|--module)
                ULTRA_MODULE_FILTER="$2"
                shift 2
                ;;
            --dry-run)
                ULTRA_DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                ULTRA_VERBOSE=true
                shift
                ;;
            -f|--force)
                ULTRA_FORCE=true
                shift
                ;;
            --skip-backup)
                ULTRA_SKIP_BACKUP=true
                shift
                ;;
            --max-risk)
                ULTRA_MAX_RISK="$2"
                shift 2
                ;;
            --benchmark)
                ULTRA_BENCHMARK=true
                shift
                ;;
            -h|--help)
                ultra_show_help
                exit 0
                ;;
            *)
                ultra_log_error "Unknown argument: $1"
                ultra_show_help
                exit 1
                ;;
        esac
    done
    
    # Validate max risk level
    case "$ULTRA_MAX_RISK" in
        low|medium|high)
            ;;
        *)
            ultra_log_error "Invalid max-risk: $ULTRA_MAX_RISK (must be: low, medium, high)"
            exit 1
            ;;
    esac
}

ultra_show_help() {
    cat << 'EOF'
Ubuntu Ultra Optimizer - Siêu tối ưu hóa vi mô

Usage: ./cli.sh [OPTIONS]

Options:
  -p, --profile PROFILE     Profile to use (default: server)
                            Available: desktop, server, db, lowlatency
  
  -s, --stage STAGE         Run specific stage only (default: all)
                            Examples: kernel-vm, kernel-sched, fs, net
  
  -m, --module MODULE       Run specific module only
                            Example: kernel.vm.swappiness
  
  --dry-run                 Don't make changes, only show what would be done
  
  -v, --verbose             Verbose output
  
  -f, --force               Skip confirmation prompts
  
  --skip-backup             Skip backup (dangerous!)
  
  --max-risk LEVEL          Maximum risk level (low/medium/high)
                            Default: medium
  
  --benchmark               Run benchmarks before and after
  
  -h, --help                Show this help message

Examples:
  # Apply server profile with dry-run
  ./cli.sh --profile server --dry-run

  # Apply only kernel-vm stage
  ./cli.sh --stage kernel-vm

  # Run specific module
  ./cli.sh --module kernel.vm.swappiness

  # High-risk optimizations
  ./cli.sh --profile lowlatency --max-risk high

Rollback:
  ./rollback.sh <RUN_ID>              # Rollback entire run
  ./rollback.sh <RUN_ID> <MODULE_ID>  # Rollback specific module

EOF
}

ultra_get_profile() {
    echo "$ULTRA_PROFILE"
}

ultra_is_dry_run() {
    [[ "$ULTRA_DRY_RUN" == "true" ]]
}

ultra_is_verbose() {
    [[ "$ULTRA_VERBOSE" == "true" ]]
}

ultra_is_force() {
    [[ "$ULTRA_FORCE" == "true" ]]
}

ultra_get_stage() {
    echo "$ULTRA_STAGE"
}

ultra_get_module_filter() {
    echo "$ULTRA_MODULE_FILTER"
}

ultra_should_skip_backup() {
    [[ "$ULTRA_SKIP_BACKUP" == "true" ]]
}

ultra_get_max_risk() {
    echo "$ULTRA_MAX_RISK"
}

ultra_should_benchmark() {
    [[ "$ULTRA_BENCHMARK" == "true" ]]
}
