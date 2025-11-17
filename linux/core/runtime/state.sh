#!/bin/bash
################################################################################
# STATE MANAGEMENT - Manage RUN_ID, state, rollback
################################################################################

ULTRA_STATE_DIR="${ULTRA_STATE_DIR:-/var/lib/ubuntu-ultra-opt/state}"
ULTRA_CURRENT_RUN_ID=""
ULTRA_CURRENT_RUN_STATE_DIR=""

ultra_state_init() {
    # Create state directory
    mkdir -p "$ULTRA_STATE_DIR"
    
    # Generate RUN_ID: timestamp-random
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local random=$(head -c 8 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 6)
    ULTRA_CURRENT_RUN_ID="${timestamp}-${random}"
    
    # Create run state directory
    ULTRA_CURRENT_RUN_STATE_DIR="$ULTRA_STATE_DIR/$ULTRA_CURRENT_RUN_ID"
    mkdir -p "$ULTRA_CURRENT_RUN_STATE_DIR"
    
    # Save run metadata
    cat > "$ULTRA_CURRENT_RUN_STATE_DIR/run.json" << EOF
{
  "run_id": "$ULTRA_CURRENT_RUN_ID",
  "timestamp": "$(date -Iseconds)",
  "profile": "$(ultra_get_profile)",
  "stage": "$(ultra_get_stage)",
  "max_risk": "$(ultra_get_max_risk)",
  "dry_run": $(ultra_is_dry_run && echo "true" || echo "false"),
  "hostname": "$(hostname)",
  "kernel": "$(uname -r)",
  "distro": "$(ultra_get_distro) $(ultra_get_distro_version)"
}
EOF
    
    ultra_log_info "Initialized run: $ULTRA_CURRENT_RUN_ID"
}

ultra_state_get_run_id() {
    echo "$ULTRA_CURRENT_RUN_ID"
}

ultra_state_get_run_dir() {
    echo "$ULTRA_CURRENT_RUN_STATE_DIR"
}

ultra_state_save_module_before() {
    local module_id="$1"
    local key="$2"
    local value="$3"
    
    local state_file="$ULTRA_CURRENT_RUN_STATE_DIR/${module_id}.json"
    
    # Initialize state file if not exists
    if [[ ! -f "$state_file" ]]; then
        cat > "$state_file" << EOF
{
  "module_id": "$module_id",
  "timestamp_start": "$(date -Iseconds)",
  "before": {},
  "after": {},
  "actions": []
}
EOF
    fi
    
    # Add to before state using jq (if available) or fallback
    if command -v jq &>/dev/null; then
        local tmp=$(mktemp)
        jq --arg key "$key" --arg val "$value" '.before[$key] = $val' "$state_file" > "$tmp"
        mv "$tmp" "$state_file"
    else
        # Fallback: simple append (less safe but works without jq)
        ultra_log_debug "jq not available, using simple state format"
        echo "BEFORE:$key=$value" >> "$state_file.simple"
    fi
}

ultra_state_save_module_after() {
    local module_id="$1"
    local key="$2"
    local value="$3"
    
    local state_file="$ULTRA_CURRENT_RUN_STATE_DIR/${module_id}.json"
    
    if command -v jq &>/dev/null; then
        local tmp=$(mktemp)
        jq --arg key "$key" --arg val "$value" '.after[$key] = $val' "$state_file" > "$tmp"
        mv "$tmp" "$state_file"
    else
        echo "AFTER:$key=$value" >> "$state_file.simple"
    fi
}

ultra_state_add_action() {
    local module_id="$1"
    local action_type="$2"  # sysctl, file_edit, file_backup, command
    local description="$3"
    
    local state_file="$ULTRA_CURRENT_RUN_STATE_DIR/${module_id}.json"
    
    if command -v jq &>/dev/null; then
        local tmp=$(mktemp)
        jq --arg type "$action_type" --arg desc "$description" --arg ts "$(date -Iseconds)" \
           '.actions += [{"type": $type, "description": $desc, "timestamp": $ts}]' \
           "$state_file" > "$tmp"
        mv "$tmp" "$state_file"
    else
        echo "ACTION:$action_type:$description" >> "$state_file.simple"
    fi
}

ultra_state_finalize_module() {
    local module_id="$1"
    local status="$2"  # success, failed, skipped
    
    local state_file="$ULTRA_CURRENT_RUN_STATE_DIR/${module_id}.json"
    
    if command -v jq &>/dev/null; then
        local tmp=$(mktemp)
        jq --arg status "$status" --arg ts "$(date -Iseconds)" \
           '.status = $status | .timestamp_end = $ts' \
           "$state_file" > "$tmp"
        mv "$tmp" "$state_file"
    else
        echo "STATUS:$status" >> "$state_file.simple"
        echo "TIMESTAMP_END:$(date -Iseconds)" >> "$state_file.simple"
    fi
}

ultra_state_list_runs() {
    if [[ -d "$ULTRA_STATE_DIR" ]]; then
        find "$ULTRA_STATE_DIR" -maxdepth 1 -type d -name "*-*" | sort -r | head -20
    fi
}

ultra_state_get_run_info() {
    local run_id="$1"
    local run_file="$ULTRA_STATE_DIR/$run_id/run.json"
    
    if [[ -f "$run_file" ]]; then
        if command -v jq &>/dev/null; then
            jq '.' "$run_file"
        else
            cat "$run_file"
        fi
    else
        ultra_log_error "Run not found: $run_id"
        return 1
    fi
}

ultra_state_get_module_state() {
    local run_id="$1"
    local module_id="$2"
    local state_file="$ULTRA_STATE_DIR/$run_id/${module_id}.json"
    
    if [[ -f "$state_file" ]]; then
        if command -v jq &>/dev/null; then
            jq '.' "$state_file"
        else
            cat "$state_file"
        fi
    else
        ultra_log_error "Module state not found: $module_id in run $run_id"
        return 1
    fi
}
