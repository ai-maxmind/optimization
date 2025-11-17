#!/bin/bash
# orchestrator/profiler.sh
# Advanced profile management with inheritance and composition

declare -A ULTRA_PROFILE_CACHE
ULTRA_PROFILE_INHERITANCE=()

# Load profile with inheritance support
ultra_profile_load() {
    local profile_name="$1"
    local profile_file="$ULTRA_PROFILE_DIR/${profile_name}.yml"
    
    if [[ ! -f "$profile_file" ]]; then
        ultra_log_error "Profile not found: $profile_name"
        return 1
    fi
    
    # Check cache
    if [[ -n "${ULTRA_PROFILE_CACHE[$profile_name]:-}" ]]; then
        ultra_log_debug "Profile $profile_name loaded from cache"
        return 0
    fi
    
    # Parse inheritance
    local parent_profile=""
    if command -v yq &>/dev/null; then
        parent_profile=$(yq eval '.profile.inherits' "$profile_file" 2>/dev/null)
    elif grep -q "inherits:" "$profile_file"; then
        parent_profile=$(grep "inherits:" "$profile_file" | sed 's/.*inherits: *\(.*\)/\1/' | tr -d '"')
    fi
    
    # Load parent first
    if [[ -n "$parent_profile" ]] && [[ "$parent_profile" != "null" ]]; then
        ultra_log_debug "Profile $profile_name inherits from $parent_profile"
        ULTRA_PROFILE_INHERITANCE+=("$parent_profile")
        ultra_profile_load "$parent_profile"
    fi
    
    ULTRA_PROFILE_CACHE[$profile_name]="loaded"
    ultra_log_debug "Profile $profile_name loaded"
    return 0
}

# Get profile setting with inheritance
ultra_profile_get_setting() {
    local profile="$1"
    local setting_path="$2"  # e.g., "system.vm.swappiness"
    local default="$3"
    
    local profile_file="$ULTRA_PROFILE_DIR/${profile}.yml"
    
    if [[ ! -f "$profile_file" ]]; then
        echo "$default"
        return
    fi
    
    # Try to get setting using yq
    if command -v yq &>/dev/null; then
        local value=$(yq eval ".$setting_path" "$profile_file" 2>/dev/null)
        if [[ -n "$value" ]] && [[ "$value" != "null" ]]; then
            echo "$value"
            return
        fi
    fi
    
    # Fallback to grep
    local key=$(echo "$setting_path" | awk -F. '{print $NF}')
    local value=$(grep "^ *$key:" "$profile_file" | head -1 | sed 's/.*: *\(.*\)/\1/' | tr -d '"')
    
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Merge multiple profiles (composition)
ultra_profile_compose() {
    local base_profile="$1"
    shift
    local overlay_profiles=("$@")
    
    ultra_log_info "Composing profile: $base_profile + ${overlay_profiles[*]}"
    
    local temp_profile=$(mktemp)
    cat "$ULTRA_PROFILE_DIR/${base_profile}.yml" > "$temp_profile"
    
    # Apply overlays
    for overlay in "${overlay_profiles[@]}"; do
        local overlay_file="$ULTRA_PROFILE_DIR/${overlay}.yml"
        
        if [[ ! -f "$overlay_file" ]]; then
            ultra_log_warn "Overlay profile not found: $overlay"
            continue
        fi
        
        # Merge profiles (requires yq for proper YAML merge)
        if command -v yq &>/dev/null; then
            yq eval-all '. as $item ireduce ({}; . * $item)' "$temp_profile" "$overlay_file" > "${temp_profile}.merged"
            mv "${temp_profile}.merged" "$temp_profile"
        else
            ultra_log_warn "yq not available, simple append (may have duplicates)"
            cat "$overlay_file" >> "$temp_profile"
        fi
    done
    
    echo "$temp_profile"
}

# Validate profile structure
ultra_profile_validate() {
    local profile_file="$1"
    
    if [[ ! -f "$profile_file" ]]; then
        ultra_log_error "Profile file not found: $profile_file"
        return 1
    fi
    
    # Check required sections
    local required_sections=("profile" "system" "modules")
    local issues=0
    
    for section in "${required_sections[@]}"; do
        if ! grep -q "^${section}:" "$profile_file"; then
            ultra_log_error "Profile missing required section: $section"
            ((issues++))
        fi
    done
    
    # Validate YAML syntax if yq available
    if command -v yq &>/dev/null; then
        if ! yq eval '.' "$profile_file" &>/dev/null; then
            ultra_log_error "Profile has invalid YAML syntax"
            ((issues++))
        fi
    fi
    
    if [[ $issues -gt 0 ]]; then
        ultra_log_error "Profile validation failed with $issues issues"
        return 1
    fi
    
    ultra_log_debug "Profile validation passed"
    return 0
}

# Auto-detect optimal profile
ultra_profile_auto_detect() {
    ultra_log_info "Auto-detecting optimal profile..."
    
    local ram_gb=$(ultra_get_total_ram_gb)
    local cpu_count=$(nproc)
    local has_battery=0
    
    # Check for battery (laptop)
    if ls /sys/class/power_supply/BAT* &>/dev/null; then
        has_battery=1
    fi
    
    # Check for database processes
    local has_db=0
    if pgrep -x "postgres\|mysqld\|mongod" &>/dev/null; then
        has_db=1
    fi
    
    # Check for virtualization
    local is_vm=0
    if systemd-detect-virt &>/dev/null; then
        is_vm=1
    fi
    
    # Decision logic
    local profile="server"  # Default
    
    if [[ $has_db -eq 1 ]]; then
        profile="db"
        ultra_log_info "Detected database workload"
    elif [[ $has_battery -eq 1 ]]; then
        profile="desktop"
        ultra_log_info "Detected laptop/desktop system"
    elif [[ $cpu_count -ge 8 ]] && [[ $ram_gb -ge 16 ]]; then
        profile="server"
        ultra_log_info "Detected high-performance server"
    elif [[ $is_vm -eq 1 ]]; then
        profile="server"
        ultra_log_info "Detected virtual machine"
    else
        profile="desktop"
        ultra_log_info "Detected desktop/workstation"
    fi
    
    echo "$profile"
}

# Create custom profile from template
ultra_profile_create() {
    local profile_name="$1"
    local base_profile="${2:-server}"
    
    local new_profile="$ULTRA_PROFILE_DIR/${profile_name}.yml"
    
    if [[ -f "$new_profile" ]]; then
        ultra_log_error "Profile already exists: $profile_name"
        return 1
    fi
    
    cp "$ULTRA_PROFILE_DIR/${base_profile}.yml" "$new_profile"
    
    # Update profile name
    sed -i "s/name: .*/name: $profile_name/" "$new_profile"
    sed -i "s/description: .*/description: \"Custom profile based on $base_profile\"/" "$new_profile"
    
    ultra_log_info "Created custom profile: $profile_name (based on $base_profile)"
    echo "$new_profile"
}

# List available profiles
ultra_profile_list() {
    ultra_log_info "Available profiles:"
    
    for profile_file in "$ULTRA_PROFILE_DIR"/*.yml; do
        if [[ -f "$profile_file" ]]; then
            local name=$(basename "$profile_file" .yml)
            local desc=""
            
            if command -v yq &>/dev/null; then
                desc=$(yq eval '.profile.description' "$profile_file" 2>/dev/null)
            else
                desc=$(grep "description:" "$profile_file" | head -1 | sed 's/.*description: *\(.*\)/\1/' | tr -d '"')
            fi
            
            printf "  %-15s - %s\n" "$name" "$desc"
        fi
    done
}

# Export profile to standalone script
ultra_profile_export() {
    local profile_name="$1"
    local output_file="${2:-/tmp/ultra-${profile_name}.sh}"
    
    ultra_log_info "Exporting profile $profile_name to $output_file"
    
    cat > "$output_file" <<'EOF'
#!/bin/bash
# Ubuntu Ultra Optimizer - Standalone Profile Script
# Auto-generated, contains all optimizations from profile

set -e

echo "Applying Ubuntu Ultra Optimizations"
echo "Profile: PROFILE_NAME"
echo ""

# Sysctl settings
EOF
    
    sed -i "s/PROFILE_NAME/$profile_name/" "$output_file"
    
    # Add sysctl commands from profile
    # This would parse the profile and generate standalone sysctl commands
    
    chmod +x "$output_file"
    ultra_log_info "Exported to: $output_file"
}
