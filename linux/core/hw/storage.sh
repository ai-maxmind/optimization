#!/bin/bash
################################################################################
# STORAGE HARDWARE DETECTION - Detect NVMe/SSD/HDD, queue, scheduler
################################################################################

declare -A ULTRA_STORAGE_DEVICES
declare -A ULTRA_STORAGE_TYPES     # nvme, ssd, hdd
declare -A ULTRA_STORAGE_ROTATIONAL
declare -A ULTRA_STORAGE_SCHEDULERS
declare -A ULTRA_STORAGE_QUEUE_DEPTH

ultra_hw_storage_detect() {
    ultra_log_debug "Detecting storage devices..."
    
    # Find all block devices
    for device in /sys/block/sd* /sys/block/nvme* /sys/block/vd*; do
        if [[ ! -d "$device" ]]; then
            continue
        fi
        
        local dev_name=$(basename "$device")
        
        # Skip if not a real device
        if [[ ! -b "/dev/$dev_name" ]]; then
            continue
        fi
        
        # Detect type
        local is_rotational=0
        if [[ -f "$device/queue/rotational" ]]; then
            is_rotational=$(cat "$device/queue/rotational")
        fi
        
        ULTRA_STORAGE_ROTATIONAL[$dev_name]=$is_rotational
        
        if [[ "$dev_name" == nvme* ]]; then
            ULTRA_STORAGE_TYPES[$dev_name]="nvme"
        elif [[ $is_rotational -eq 0 ]]; then
            ULTRA_STORAGE_TYPES[$dev_name]="ssd"
        else
            ULTRA_STORAGE_TYPES[$dev_name]="hdd"
        fi
        
        # Current scheduler
        if [[ -f "$device/queue/scheduler" ]]; then
            local sched=$(cat "$device/queue/scheduler" | grep -oP '\[\K[^\]]+')
            ULTRA_STORAGE_SCHEDULERS[$dev_name]="$sched"
        fi
        
        # Queue depth
        if [[ -f "$device/queue/nr_requests" ]]; then
            ULTRA_STORAGE_QUEUE_DEPTH[$dev_name]=$(cat "$device/queue/nr_requests")
        fi
        
        ULTRA_STORAGE_DEVICES[$dev_name]=1
        
        ultra_log_debug "Storage: $dev_name = ${ULTRA_STORAGE_TYPES[$dev_name]} (scheduler: ${ULTRA_STORAGE_SCHEDULERS[$dev_name]}, queue: ${ULTRA_STORAGE_QUEUE_DEPTH[$dev_name]})"
    done
}

ultra_hw_storage_get_devices() {
    echo "${!ULTRA_STORAGE_DEVICES[@]}"
}

ultra_hw_storage_get_type() {
    local device="$1"
    echo "${ULTRA_STORAGE_TYPES[$device]}"
}

ultra_hw_storage_is_nvme() {
    local device="$1"
    [[ "${ULTRA_STORAGE_TYPES[$device]}" == "nvme" ]]
}

ultra_hw_storage_is_ssd() {
    local device="$1"
    local type="${ULTRA_STORAGE_TYPES[$device]}"
    [[ "$type" == "ssd" ]] || [[ "$type" == "nvme" ]]
}

ultra_hw_storage_is_rotational() {
    local device="$1"
    [[ "${ULTRA_STORAGE_ROTATIONAL[$device]}" == "1" ]]
}
