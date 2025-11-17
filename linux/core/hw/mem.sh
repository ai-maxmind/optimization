#!/bin/bash
################################################################################
# MEMORY HARDWARE DETECTION - Detect RAM and NUMA
################################################################################

ULTRA_MEM_TOTAL_GB=0
ULTRA_MEM_TOTAL_KB=0
ULTRA_MEM_HAS_NUMA=false
ULTRA_MEM_NUMA_NODES=0
ULTRA_MEM_HAS_HUGEPAGES=false
ULTRA_MEM_HUGEPAGE_SIZE=""

ultra_hw_mem_detect() {
    ultra_log_debug "Detecting memory hardware..."
    
    # Total memory
    ULTRA_MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    ULTRA_MEM_TOTAL_GB=$((ULTRA_MEM_TOTAL_KB / 1024 / 1024))
    
    # NUMA detection
    if [[ -d /sys/devices/system/node ]] && ls /sys/devices/system/node/node* >/dev/null 2>&1; then
        ULTRA_MEM_HAS_NUMA=true
        ULTRA_MEM_NUMA_NODES=$(ls -d /sys/devices/system/node/node* 2>/dev/null | wc -l)
    fi
    
    # Hugepages support
    if grep -q "Hugepagesize" /proc/meminfo; then
        ULTRA_MEM_HAS_HUGEPAGES=true
        ULTRA_MEM_HUGEPAGE_SIZE=$(grep "Hugepagesize" /proc/meminfo | awk '{print $2}')
    fi
    
    ultra_log_debug "Memory: ${ULTRA_MEM_TOTAL_GB}GB (${ULTRA_MEM_TOTAL_KB}KB)"
    ultra_log_debug "NUMA: $ULTRA_MEM_HAS_NUMA (nodes: $ULTRA_MEM_NUMA_NODES)"
    ultra_log_debug "Hugepages: $ULTRA_MEM_HAS_HUGEPAGES (size: ${ULTRA_MEM_HUGEPAGE_SIZE}KB)"
}

ultra_hw_mem_get_total_gb() {
    echo "$ULTRA_MEM_TOTAL_GB"
}

ultra_hw_mem_get_total_kb() {
    echo "$ULTRA_MEM_TOTAL_KB"
}

ultra_hw_mem_has_numa() {
    [[ "$ULTRA_MEM_HAS_NUMA" == "true" ]]
}

ultra_hw_mem_get_numa_nodes() {
    echo "$ULTRA_MEM_NUMA_NODES"
}

ultra_hw_mem_has_hugepages() {
    [[ "$ULTRA_MEM_HAS_HUGEPAGES" == "true" ]]
}
