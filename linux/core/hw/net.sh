#!/bin/bash
################################################################################
# NETWORK HARDWARE DETECTION - Detect NIC, offload, queues
################################################################################

declare -A ULTRA_NET_INTERFACES
declare -A ULTRA_NET_DRIVERS
declare -A ULTRA_NET_SPEEDS
declare -A ULTRA_NET_RX_QUEUES
declare -A ULTRA_NET_TX_QUEUES
declare -A ULTRA_NET_HAS_RSS
declare -A ULTRA_NET_HAS_TSO
declare -A ULTRA_NET_HAS_GSO

ultra_hw_net_detect() {
    ultra_log_debug "Detecting network interfaces..."
    
    # Find all network interfaces (exclude lo, docker, etc)
    for iface in /sys/class/net/*; do
        if [[ ! -d "$iface" ]]; then
            continue
        fi
        
        local iface_name=$(basename "$iface")
        
        # Skip virtual interfaces
        if [[ "$iface_name" =~ ^(lo|docker|br-|veth|virbr) ]]; then
            continue
        fi
        
        # Check if physical
        if [[ ! -d "$iface/device" ]]; then
            continue
        fi
        
        ULTRA_NET_INTERFACES[$iface_name]=1
        
        # Driver
        if [[ -L "$iface/device/driver" ]]; then
            local driver=$(basename "$(readlink "$iface/device/driver")")
            ULTRA_NET_DRIVERS[$iface_name]="$driver"
        fi
        
        # Speed
        if [[ -f "$iface/speed" ]]; then
            local speed=$(cat "$iface/speed" 2>/dev/null || echo "unknown")
            ULTRA_NET_SPEEDS[$iface_name]="$speed"
        fi
        
        # RX/TX queues
        local rx_queues=$(ls -d "$iface/queues/rx-"* 2>/dev/null | wc -l)
        local tx_queues=$(ls -d "$iface/queues/tx-"* 2>/dev/null | wc -l)
        ULTRA_NET_RX_QUEUES[$iface_name]=$rx_queues
        ULTRA_NET_TX_QUEUES[$iface_name]=$tx_queues
        
        # Offload features (using ethtool if available)
        if command -v ethtool &>/dev/null; then
            # RSS
            if ethtool -k "$iface_name" 2>/dev/null | grep -q "receive-hashing: on"; then
                ULTRA_NET_HAS_RSS[$iface_name]=true
            else
                ULTRA_NET_HAS_RSS[$iface_name]=false
            fi
            
            # TSO
            if ethtool -k "$iface_name" 2>/dev/null | grep "tcp-segmentation-offload" | grep -q "on"; then
                ULTRA_NET_HAS_TSO[$iface_name]=true
            else
                ULTRA_NET_HAS_TSO[$iface_name]=false
            fi
            
            # GSO
            if ethtool -k "$iface_name" 2>/dev/null | grep "generic-segmentation-offload" | grep -q "on"; then
                ULTRA_NET_HAS_GSO[$iface_name]=true
            else
                ULTRA_NET_HAS_GSO[$iface_name]=false
            fi
        fi
        
        ultra_log_debug "Network: $iface_name (driver: ${ULTRA_NET_DRIVERS[$iface_name]}, speed: ${ULTRA_NET_SPEEDS[$iface_name]}Mbps, RX queues: $rx_queues, TX queues: $tx_queues)"
    done
}

ultra_hw_net_get_interfaces() {
    echo "${!ULTRA_NET_INTERFACES[@]}"
}

ultra_hw_net_get_driver() {
    local iface="$1"
    echo "${ULTRA_NET_DRIVERS[$iface]}"
}

ultra_hw_net_get_speed() {
    local iface="$1"
    echo "${ULTRA_NET_SPEEDS[$iface]}"
}

ultra_hw_net_get_rx_queues() {
    local iface="$1"
    echo "${ULTRA_NET_RX_QUEUES[$iface]}"
}

ultra_hw_net_has_multiqueue() {
    local iface="$1"
    local rx_queues=${ULTRA_NET_RX_QUEUES[$iface]}
    [[ $rx_queues -gt 1 ]]
}
