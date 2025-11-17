#!/bin/bash
################################################################################
# LOGGING - Logging with levels and timestamps
################################################################################

# Log levels
ULTRA_LOG_LEVEL_DEBUG=0
ULTRA_LOG_LEVEL_INFO=1
ULTRA_LOG_LEVEL_WARN=2
ULTRA_LOG_LEVEL_ERROR=3

# Current log level (default: INFO)
ULTRA_CURRENT_LOG_LEVEL=${ULTRA_LOG_LEVEL_INFO}

# Log file
ULTRA_LOG_FILE="${ULTRA_LOG_FILE:-/var/log/ubuntu-ultra-opt/ubuntu-ultra-opt.log}"

# Colors
ULTRA_COLOR_DEBUG='\033[0;36m'    # Cyan
ULTRA_COLOR_INFO='\033[0;32m'     # Green
ULTRA_COLOR_WARN='\033[1;33m'     # Yellow
ULTRA_COLOR_ERROR='\033[0;31m'    # Red
ULTRA_COLOR_RESET='\033[0m'

ultra_log_init() {
    # Create log directory
    local log_dir=$(dirname "$ULTRA_LOG_FILE")
    mkdir -p "$log_dir"
    
    # Set verbose mode
    if ultra_is_verbose; then
        ULTRA_CURRENT_LOG_LEVEL=$ULTRA_LOG_LEVEL_DEBUG
    fi
    
    # Log session start
    ultra_log_info "=========================================="
    ultra_log_info "Ubuntu Ultra Optimizer - Session Start"
    ultra_log_info "Timestamp: $(date -Iseconds)"
    ultra_log_info "=========================================="
}

ultra_log() {
    local level="$1"
    local level_num="$2"
    local color="$3"
    local message="$4"
    
    # Check if should log this level
    if (( level_num < ULTRA_CURRENT_LOG_LEVEL )); then
        return
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[$timestamp] [$level] $message"
    
    # Write to log file
    echo "$log_line" >> "$ULTRA_LOG_FILE"
    
    # Write to console with color
    if [[ -t 1 ]]; then
        echo -e "${color}[$level]${ULTRA_COLOR_RESET} $message"
    else
        echo "[$level] $message"
    fi
}

ultra_log_debug() {
    ultra_log "DEBUG" "$ULTRA_LOG_LEVEL_DEBUG" "$ULTRA_COLOR_DEBUG" "$1"
}

ultra_log_info() {
    ultra_log "INFO" "$ULTRA_LOG_LEVEL_INFO" "$ULTRA_COLOR_INFO" "$1"
}

ultra_log_warn() {
    ultra_log "WARN" "$ULTRA_LOG_LEVEL_WARN" "$ULTRA_COLOR_WARN" "$1"
}

ultra_log_error() {
    ultra_log "ERROR" "$ULTRA_LOG_LEVEL_ERROR" "$ULTRA_COLOR_ERROR" "$1"
}

ultra_log_section() {
    local section_name="$1"
    ultra_log_info ""
    ultra_log_info "=========================================="
    ultra_log_info "$section_name"
    ultra_log_info "=========================================="
}

ultra_log_module_start() {
    local module_id="$1"
    local module_desc="$2"
    ultra_log_info ""
    ultra_log_info "→ Module: $module_id"
    ultra_log_info "  Description: $module_desc"
}

ultra_log_module_end() {
    local module_id="$1"
    local status="$2"
    
    case "$status" in
        success)
            ultra_log_info "✓ Module $module_id completed successfully"
            ;;
        skipped)
            ultra_log_info "⊘ Module $module_id skipped"
            ;;
        failed)
            ultra_log_error "✗ Module $module_id failed"
            ;;
        *)
            ultra_log_warn "? Module $module_id ended with unknown status: $status"
            ;;
    esac
}

ultra_log_dry_run() {
    local action="$1"
    ultra_log_info "[DRY-RUN] Would execute: $action"
}
