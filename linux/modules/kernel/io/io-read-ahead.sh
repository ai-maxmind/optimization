#!/bin/bash
################################################################################
# MODULE: kernel.io.read-ahead
# Optimize read-ahead based on storage and workload
################################################################################

MOD_ID="kernel.io.read-ahead"
MOD_DESC="Optimize read-ahead for each storage device"
MOD_STAGE="kernel-io"
MOD_RISK="low"
MOD_DEFAULT_ENABLED="true"

mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    local devices=$(ultra_hw_storage_get_devices)
    if [[ -z "$devices" ]]; then
        ultra_log_warn "No storage devices found"
        return 1
    fi
    return 0
}

mod_apply() {
    ultra_log_info "Applying $MOD_DESC"
    
    local profile=$(ultra_get_profile)
    
    # Process each storage device
    for device in $(ultra_hw_storage_get_devices); do
        local device_type=$(ultra_hw_storage_get_type "$device")
        local read_ahead_kb=128
        
        # Base read-ahead on device type
        case "$device_type" in
            nvme)
                # NVMe: moderate read-ahead (fast random access)
                read_ahead_kb=256
                ;;
            ssd)
                # SSD: moderate read-ahead
                read_ahead_kb=256
                ;;
            hdd)
                # HDD: larger read-ahead (sequential reads are cheap)
                read_ahead_kb=512
                ;;
        esac
        
        # Adjust based on profile
        case "$profile" in
            db)
                # Database: larger read-ahead for sequential scans
                if [[ "$device_type" == "hdd" ]]; then
                    read_ahead_kb=1024
                else
                    read_ahead_kb=512
                fi
                ;;
            lowlatency)
                # Low latency: minimal read-ahead
                read_ahead_kb=128
                ;;
            server)
                # Server: balance
                ;;
            desktop)
                # Desktop: moderate
                ;;
        esac
        
        ultra_log_info "Device $device ($device_type): read_ahead = $read_ahead_kb KB"
        
        # Save current
        if [[ -f "/sys/block/$device/queue/read_ahead_kb" ]]; then
            local current=$(cat "/sys/block/$device/queue/read_ahead_kb")
            ultra_state_save_module_before "$MOD_ID" "read_ahead:$device" "$current"
        fi
        
        # Apply
        if ! ultra_is_dry_run; then
            if [[ -f "/sys/block/$device/queue/read_ahead_kb" ]]; then
                echo "$read_ahead_kb" > "/sys/block/$device/queue/read_ahead_kb"
            fi
        else
            ultra_log_dry_run "Set $device read_ahead = $read_ahead_kb KB"
        fi
        
        ultra_state_save_module_after "$MOD_ID" "read_ahead:$device" "$read_ahead_kb"
        ultra_state_add_action "$MOD_ID" "sysfs" "Set $device read_ahead to $read_ahead_kb KB"
    done
    
    # Also tune page-cluster (swap read-ahead)
    # Lower for SSD, higher for HDD
    local has_ssd=false
    for device in $(ultra_hw_storage_get_devices); do
        if ultra_hw_storage_is_ssd "$device"; then
            has_ssd=true
            break
        fi
    done
    
    local page_cluster=3  # default
    if [[ "$has_ssd" == "true" ]]; then
        page_cluster=0  # Disable swap read-ahead on SSD
    else
        page_cluster=3  # 8 pages on HDD
    fi
    
    ultra_sysctl_save_and_set "vm.page-cluster" "$page_cluster" "$MOD_ID"
}

mod_rollback() {
    ultra_log_info "Rolling back $MOD_ID"
    
    local run_id="$1"
    local state_file="$ULTRA_STATE_DIR/$run_id/${MOD_ID}.json"
    
    if [[ -f "$state_file" ]] && command -v jq &>/dev/null; then
        for device in $(ultra_hw_storage_get_devices); do
            local value=$(jq -r ".before[\"read_ahead:$device\"]" "$state_file")
            if [[ "$value" != "null" ]] && [[ -n "$value" ]]; then
                if [[ -f "/sys/block/$device/queue/read_ahead_kb" ]]; then
                    echo "$value" > "/sys/block/$device/queue/read_ahead_kb"
                    ultra_log_info "Restored $device read_ahead to $value KB"
                fi
            fi
        done
        
        # Restore page-cluster
        local pc_value=$(jq -r '.before["sysctl:vm.page-cluster"]' "$state_file")
        if [[ "$pc_value" != "null" ]] && [[ -n "$pc_value" ]]; then
            ultra_sysctl_restore "vm.page-cluster" "$pc_value" "$MOD_ID"
        fi
    fi
}

mod_verify() {
    ultra_log_info "Current read-ahead configuration:"
    
    for device in $(ultra_hw_storage_get_devices); do
        if [[ -f "/sys/block/$device/queue/read_ahead_kb" ]]; then
            local ra=$(cat "/sys/block/$device/queue/read_ahead_kb")
            local type=$(ultra_hw_storage_get_type "$device")
            ultra_log_info "  $device ($type): ${ra} KB"
        fi
    done
    
    ultra_log_info "  vm.page-cluster: $(ultra_sysctl_get_current vm.page-cluster)"
}
