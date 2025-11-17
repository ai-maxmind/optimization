#!/bin/bash
################################################################################
# CPU HARDWARE DETECTION - Detect cores, threads, turbo, HT, cache
################################################################################

ULTRA_CPU_VENDOR=""
ULTRA_CPU_MODEL=""
ULTRA_CPU_CORES_PHYSICAL=""
ULTRA_CPU_CORES_LOGICAL=""
ULTRA_CPU_HAS_HT=false
ULTRA_CPU_HAS_TURBO=false
ULTRA_CPU_HAS_AVX=false
ULTRA_CPU_HAS_AVX2=false
ULTRA_CPU_HAS_AVX512=false
ULTRA_CPU_L1_CACHE=""
ULTRA_CPU_L2_CACHE=""
ULTRA_CPU_L3_CACHE=""
ULTRA_CPU_GOVERNOR=""
ULTRA_CPU_MIN_FREQ=""
ULTRA_CPU_MAX_FREQ=""

ultra_hw_cpu_detect() {
    ultra_log_debug "Detecting CPU hardware..."
    
    # Vendor
    if grep -q "GenuineIntel" /proc/cpuinfo; then
        ULTRA_CPU_VENDOR="intel"
    elif grep -q "AuthenticAMD" /proc/cpuinfo; then
        ULTRA_CPU_VENDOR="amd"
    else
        ULTRA_CPU_VENDOR="unknown"
    fi
    
    # Model
    ULTRA_CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    
    # Physical cores (unique core IDs)
    ULTRA_CPU_CORES_PHYSICAL=$(lscpu | grep "^Core(s) per socket:" | awk '{print $NF}')
    local sockets=$(lscpu | grep "^Socket(s):" | awk '{print $NF}')
    ULTRA_CPU_CORES_PHYSICAL=$((ULTRA_CPU_CORES_PHYSICAL * sockets))
    
    # Logical cores (threads)
    ULTRA_CPU_CORES_LOGICAL=$(nproc)
    
    # Hyper-Threading / SMT
    if (( ULTRA_CPU_CORES_LOGICAL > ULTRA_CPU_CORES_PHYSICAL )); then
        ULTRA_CPU_HAS_HT=true
    fi
    
    # Turbo Boost / Turbo Core
    if [[ "$ULTRA_CPU_VENDOR" == "intel" ]]; then
        if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
            local no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)
            [[ "$no_turbo" == "0" ]] && ULTRA_CPU_HAS_TURBO=true
        fi
    elif [[ "$ULTRA_CPU_VENDOR" == "amd" ]]; then
        if [[ -f /sys/devices/system/cpu/cpufreq/boost ]]; then
            local boost=$(cat /sys/devices/system/cpu/cpufreq/boost)
            [[ "$boost" == "1" ]] && ULTRA_CPU_HAS_TURBO=true
        fi
    fi
    
    # AVX support
    if grep -q " avx " /proc/cpuinfo; then
        ULTRA_CPU_HAS_AVX=true
    fi
    if grep -q " avx2 " /proc/cpuinfo; then
        ULTRA_CPU_HAS_AVX2=true
    fi
    if grep -q " avx512" /proc/cpuinfo; then
        ULTRA_CPU_HAS_AVX512=true
    fi
    
    # Cache sizes
    ULTRA_CPU_L1_CACHE=$(lscpu | grep "L1d cache" | awk '{print $NF}')
    ULTRA_CPU_L2_CACHE=$(lscpu | grep "L2 cache" | awk '{print $NF}')
    ULTRA_CPU_L3_CACHE=$(lscpu | grep "L3 cache" | awk '{print $NF}')
    
    # Current governor
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        ULTRA_CPU_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    fi
    
    # Frequency range
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq ]]; then
        ULTRA_CPU_MIN_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq)
        ULTRA_CPU_MAX_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)
        # Convert kHz to MHz
        ULTRA_CPU_MIN_FREQ=$((ULTRA_CPU_MIN_FREQ / 1000))
        ULTRA_CPU_MAX_FREQ=$((ULTRA_CPU_MAX_FREQ / 1000))
    fi
    
    ultra_log_debug "CPU: $ULTRA_CPU_VENDOR $ULTRA_CPU_MODEL"
    ultra_log_debug "Cores: $ULTRA_CPU_CORES_PHYSICAL physical, $ULTRA_CPU_CORES_LOGICAL logical (HT: $ULTRA_CPU_HAS_HT)"
    ultra_log_debug "Turbo: $ULTRA_CPU_HAS_TURBO, AVX: $ULTRA_CPU_HAS_AVX, AVX2: $ULTRA_CPU_HAS_AVX2, AVX512: $ULTRA_CPU_HAS_AVX512"
    ultra_log_debug "Cache: L1=$ULTRA_CPU_L1_CACHE, L2=$ULTRA_CPU_L2_CACHE, L3=$ULTRA_CPU_L3_CACHE"
    ultra_log_debug "Governor: $ULTRA_CPU_GOVERNOR, Freq: ${ULTRA_CPU_MIN_FREQ}MHz - ${ULTRA_CPU_MAX_FREQ}MHz"
}

ultra_hw_cpu_get_vendor() {
    echo "$ULTRA_CPU_VENDOR"
}

ultra_hw_cpu_get_cores_physical() {
    echo "$ULTRA_CPU_CORES_PHYSICAL"
}

ultra_hw_cpu_get_cores_logical() {
    echo "$ULTRA_CPU_CORES_LOGICAL"
}

ultra_hw_cpu_has_ht() {
    [[ "$ULTRA_CPU_HAS_HT" == "true" ]]
}

ultra_hw_cpu_has_turbo() {
    [[ "$ULTRA_CPU_HAS_TURBO" == "true" ]]
}

ultra_hw_cpu_has_avx2() {
    [[ "$ULTRA_CPU_HAS_AVX2" == "true" ]]
}

ultra_hw_cpu_has_avx512() {
    [[ "$ULTRA_CPU_HAS_AVX512" == "true" ]]
}
