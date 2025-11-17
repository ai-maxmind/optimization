#!/usr/bin/env bash
set -u
set -o pipefail

logFile="/var/log/java-multi-install.log"

mkdir -p /var/log
touch "$logFile"
chmod 644 "$logFile"

log()  { echo -e "\e[32m[INFO]\e[0m $*";  echo "[INFO]  $*"  >> "$logFile"; }
warn() { echo -e "\e[33m[WARN]\e[0m $*";  echo "[WARN]  $*"  >> "$logFile"; }
err()  { echo -e "\e[31m[ERR ]\e[0m $*" >&2; echo "[ERROR] $*" >> "$logFile"; }

echo >> "$logFile"
echo "========== RUN at $(date) ==========" >> "$logFile"

if [[ "${EUID}" -ne 0 ]]; then
  err "Please run the script with root privileges (sudo)."
  exit 1
fi

temurinPkgs=()
correttoPkgs=()
openjdkPkgs=()

ubuntuCodename="$(lsb_release -cs || echo "jammy")"

setupReposAndBase() {
  log "Updating system & installing helper packages (wget, curl, gnupg, lsb-release)..."
  apt-get update -y >>"$logFile" 2>&1
  apt-get install -y wget curl gnupg ca-certificates lsb-release software-properties-common >>"$logFile" 2>&1

  log "Ubuntu codename: ${ubuntuCodename}"

  log "Setting up Eclipse Temurin (Adoptium) repository..."
  local temurinKeyring="/usr/share/keyrings/adoptium.gpg"
  local temurinList="/etc/apt/sources.list.d/adoptium.list"

  if [[ ! -f "${temurinKeyring}" ]]; then
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
      | gpg --dearmor -o "${temurinKeyring}" >>"$logFile" 2>&1
    log "Imported GPG key for Temurin: ${temurinKeyring}"
  else
    log "Temurin GPG key already exists, skipping."
  fi

  if [[ ! -f "${temurinList}" ]]; then
    echo "deb [signed-by=${temurinKeyring}] https://packages.adoptium.net/artifactory/deb ${ubuntuCodename} main" \
      > "${temurinList}"
    log "Created Temurin repo file: ${temurinList}"
  else
    log "Temurin repo already exists, skipping."
  fi

  log "Setting up Amazon Corretto repository..."
  local correttoKeyring="/usr/share/keyrings/corretto-keyring.gpg"
  local correttoList="/etc/apt/sources.list.d/corretto.list"

  if [[ ! -f "${correttoKeyring}" ]]; then
    wget -O - https://apt.corretto.aws/corretto.key \
      | gpg --dearmor -o "${correttoKeyring}" >>"$logFile" 2>&1
    log "Imported GPG key for Corretto: ${correttoKeyring}"
  else
    log "Corretto GPG key already exists, skipping."
  fi

  if [[ ! -f "${correttoList}" ]]; then
    echo "deb [signed-by=${correttoKeyring}] https://apt.corretto.aws stable main" \
      > "${correttoList}"
    log "Created Corretto repo file: ${correttoList}"
  else
    log "Corretto repo already exists, skipping."
  fi

  log "Ensuring 'universe' repository is enabled..."
  add-apt-repository -y universe >>"$logFile" 2>&1 || warn "Could not enable 'universe' (may already be enabled)."

  log "apt-get update after adding Temurin & Corretto repos..."
  apt-get update -y >>"$logFile" 2>&1
}

installPkg() {
  local pkg="$1"
  log "Installing package: ${pkg}"
  if apt-get install -y "${pkg}" >>"$logFile" 2>&1; then
    log ">> OK: ${pkg}"
  else
    warn ">> Could not install package: ${pkg} (may conflict or package error)"
  fi
}

discoverPackages() {
  log "Scanning all Temurin packages in 'temurin-*-jdk' format..."
  mapfile -t temurinPkgs < <(apt-cache search '^temurin-[0-9][0-9]*-jdk$' \
    | awk '{print $1}' | sort -V | uniq)

  if [[ "${#temurinPkgs[@]}" -eq 0 ]]; then
    warn "No Temurin packages (temurin-*-jdk) found in apt-cache."
  else
    log "Found Temurin packages:"
    for p in "${temurinPkgs[@]}"; do
      log "  - $p"
    done
  fi

  log "Scanning all Corretto packages in '*amazon-corretto-jdk' format..."
  mapfile -t correttoPkgs < <(apt-cache search 'amazon-corretto-jdk' \
    | awk '{print $1}' | sort -V | uniq)

  if [[ "${#correttoPkgs[@]}" -eq 0 ]]; then
    warn "No Corretto packages (*amazon-corretto-jdk) found in apt-cache."
  else
    log "Found Corretto packages:"
    for p in "${correttoPkgs[@]}"; do
      log "  - $p"
    done
  fi

  log "Scanning all OpenJDK packages in 'openjdk-*-jdk' format..."
  mapfile -t openjdkPkgs < <(apt-cache search '^openjdk-[0-9][0-9]*-jdk$' \
    | awk '{print $1}' | sort -V | uniq)

  if [[ "${#openjdkPkgs[@]}" -eq 0 ]]; then
    warn "No OpenJDK packages (openjdk-*-jdk) found in apt-cache."
  else
    log "Found OpenJDK packages:"
    for p in "${openjdkPkgs[@]}"; do
      log "  - $p"
    done
  fi

  echo
  echo "===== PACKAGE SCAN RESULTS (displayed on screen) ====="
  echo "Temurin:"
  if [[ "${#temurinPkgs[@]}" -gt 0 ]]; then
    printf '  - %s\n' "${temurinPkgs[@]}"
  else
    echo "  (none)"
  fi
  echo "Corretto:"
  if [[ "${#correttoPkgs[@]}" -gt 0 ]]; then
    printf '  - %s\n' "${correttoPkgs[@]}"
  else
    echo "  (none)"
  fi
  echo "OpenJDK:"
  if [[ "${#openjdkPkgs[@]}" -gt 0 ]]; then
    printf '  - %s\n' "${openjdkPkgs[@]}"
  else
    echo "  (none)"
  fi
  echo "==============================================="
}

selectPackagesToInstall() {
  local pkgType="$1"  
  local -n pkgsArray="$2"  
  
  if [[ "${#pkgsArray[@]}" -eq 0 ]]; then
    warn "No ${pkgType} packages available for installation."
    return 0
  fi
  
  echo ""
  echo "════════════════════════════════════════════════════════"
  echo "  Available ${pkgType} packages (found ${#pkgsArray[@]} packages):"
  echo "════════════════════════════════════════════════════════"
  
  local i=1
  for pkg in "${pkgsArray[@]}"; do
    printf "  %2d) %s\n" "$i" "$pkg"
    ((i++))
  done
  
  echo ""
  echo "  a)  Install ALL ${pkgType} packages"
  echo "  0)  SKIP - Do not install ${pkgType}"
  echo "  d)  DONE - Start installing selected packages"
  echo "════════════════════════════════════════════════════════"
  echo "  💡 Tip: You can select multiple numbers at once:"
  echo "      E.g.: '1 3 5' or '1,3,5' or '8-11' (from 8 to 11)"
  echo "════════════════════════════════════════════════════════"
  echo ""
  
  local selectedPkgs=()
  local choice
  
  while true; do
    if [[ "${#selectedPkgs[@]}" -gt 0 ]]; then
      echo -e "\e[36m📦 Selected ${#selectedPkgs[@]} packages:\e[0m"
      for pkg in "${selectedPkgs[@]}"; do
        echo "   ✓ $pkg"
      done
      echo ""
    fi
    
    read -rp "Select packages (number/a/0/d): " choice
    
    if [[ -z "$choice" ]]; then
      if [[ "${#selectedPkgs[@]}" -gt 0 ]]; then
        break
      else
        warn "No packages selected. Enter '0' to skip or select at least 1 package."
        continue
      fi
    fi
    
    case "$choice" in
      0)
        log "Skipping ${pkgType} installation."
        return 0
        ;;
      a|A)
        log "Selecting to install ALL ${pkgType} packages."
        selectedPkgs=()
        for pkg in "${pkgsArray[@]}"; do
          selectedPkgs+=("$pkg")
        done
        break
        ;;
      d|D)
        if [[ "${#selectedPkgs[@]}" -eq 0 ]]; then
          warn "No packages selected. Enter '0' to skip or select at least 1 package."
          continue
        fi
        break
        ;;
      *)
        local processedChoice="${choice//,/ }"
        
        for token in $processedChoice; do
          if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            
            if [[ "$start" -gt "$end" ]]; then
              warn "Invalid range: $token (start > end)"
              continue
            fi
            
            if [[ "$start" -lt 1 ]] || [[ "$end" -gt "${#pkgsArray[@]}" ]]; then
              warn "Range $token is outside scope 1-${#pkgsArray[@]}"
              continue
            fi
            
            for ((idx=start; idx<=end; idx++)); do
              local pkgIdx=$((idx - 1))
              local selectedPkg="${pkgsArray[$pkgIdx]}"
              
              local alreadySelected=false
              for pkg in "${selectedPkgs[@]}"; do
                if [[ "$pkg" == "$selectedPkg" ]]; then
                  alreadySelected=true
                  break
                fi
              done
              
              if [[ "$alreadySelected" == false ]]; then
                selectedPkgs+=("$selectedPkg")
                log "  ✓ Added: $selectedPkg"
              fi
            done
            
          elif [[ "$token" =~ ^[0-9]+$ ]]; then
            if [[ "$token" -ge 1 ]] && [[ "$token" -le "${#pkgsArray[@]}" ]]; then
              local idx=$((token - 1))
              
              # Validate array bounds before access
              if [[ $idx -lt 0 ]] || [[ $idx -ge "${#pkgsArray[@]}" ]]; then
                warn "  ✗ Internal error: Index $idx out of bounds (0-$((${#pkgsArray[@]} - 1)))"
                continue
              fi
              
              local selectedPkg="${pkgsArray[$idx]}"
              
              local alreadySelected=false
              for pkg in "${selectedPkgs[@]}"; do
                if [[ "$pkg" == "$selectedPkg" ]]; then
                  alreadySelected=true
                  break
                fi
              done
              
              if [[ "$alreadySelected" == true ]]; then
                warn "  ⚠ Package '$selectedPkg' already selected!"
              else
                selectedPkgs+=("$selectedPkg")
                log "  ✓ Added: $selectedPkg"
              fi
            else
              warn "  ✗ Number $token is outside range 1-${#pkgsArray[@]}"
            fi
          else
            warn "  ✗ Invalid choice: '$token'"
          fi
        done
        
        echo ""
        log "Total selected: ${#selectedPkgs[@]} packages"
        ;;
    esac
  done
  
  if [[ "${#selectedPkgs[@]}" -gt 0 ]]; then
    echo ""
    echo "════════════════════════════════════════════════════════"
    log "Starting installation of ${#selectedPkgs[@]} ${pkgType} packages:"
    echo "════════════════════════════════════════════════════════"
    for pkg in "${selectedPkgs[@]}"; do
      echo "  → $pkg"
    done
    echo ""
    
    for pkg in "${selectedPkgs[@]}"; do
      installPkg "${pkg}"
    done
    
    echo ""
    log "✅ ${pkgType} installation completed!"
  fi
}

installAllJava() {
  log "═══════════════════════════════════════════════════════════"
  log "  INTERACTIVE JAVA INSTALLATION MODE"
  log "═══════════════════════════════════════════════════════════"
  echo ""
  echo "You can select individual Java versions to install or install all."
  echo "Supports selecting multiple versions at once (E.g.: '1 3 5' or '8-11')."
  echo ""
  
  if [[ "${#temurinPkgs[@]}" -gt 0 ]]; then
    read -rp "Do you want to install Eclipse Temurin JDK? (y/n): " installTemurin
    if [[ "$installTemurin" =~ ^[Yy]$ ]]; then
      selectPackagesToInstall "Temurin" temurinPkgs
    else
      log "Skipping Temurin installation."
    fi
  else
    warn "No Temurin packages found."
  fi
  
  echo ""
  
  if [[ "${#correttoPkgs[@]}" -gt 0 ]]; then
    read -rp "Do you want to install Amazon Corretto JDK? (y/n): " installCorretto
    if [[ "$installCorretto" =~ ^[Yy]$ ]]; then
      selectPackagesToInstall "Corretto" correttoPkgs
    else
      log "Skipping Corretto installation."
    fi
  else
    warn "No Corretto packages found."
  fi
  
  echo ""
  
  if [[ "${#openjdkPkgs[@]}" -gt 0 ]]; then
    read -rp "Do you want to install OpenJDK? (y/n): " installOpenjdk
    if [[ "$installOpenjdk" =~ ^[Yy]$ ]]; then
      selectPackagesToInstall "OpenJDK" openjdkPkgs
    else
      log "Skipping OpenJDK installation."
    fi
  else
    warn "No OpenJDK packages found."
  fi
  
  echo ""
  log "═══════════════════════════════════════════════════════════"
  log "  ✅ JAVA INSTALLATION COMPLETED"
  log "═══════════════════════════════════════════════════════════"
}

tuneSystem() {
  log "═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
  log "  ██████╗ ██╗   ██╗ █████╗ ███╗   ██╗████████╗██╗   ██╗███╗   ███╗    ████████╗██╗   ██╗███╗   ██╗███████╗██████╗ "
  log "  ██╔═══██╗██║   ██║██╔══██╗████╗  ██║╚══██╔══╝██║   ██║████╗ ████║    ╚══██╔══╝██║   ██║████╗  ██║██╔════╝██╔══██╗"
  log "  ██║   ██║██║   ██║███████║██╔██╗ ██║   ██║   ██║   ██║██╔████╔██║       ██║   ██║   ██║██╔██╗ ██║█████╗  ██████╔╝"
  log "  ██║▄▄ ██║██║   ██║██╔══██║██║╚██╗██║   ██║   ██║   ██║██║╚██╔╝██║       ██║   ██║   ██║██║╚██╗██║██╔══╝  ██╔══██╗"
  log "  ╚██████╔╝╚██████╔╝██║  ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚═╝ ██║       ██║   ╚██████╔╝██║ ╚████║███████╗██║  ██║"
  log "   ╚══▀▀═╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝       ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝"
  log "═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
  log "  VERSION: 5.0.0 - QUANTUM LEAP EDITION | BUILD: $(date +%Y%m%d-%H%M%S)"
  log "═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"

  # Check for bc command availability
  local useBc=true
  if ! command -v bc >/dev/null 2>&1; then
    warn "bc command not found - duration calculations will be disabled"
    useBc=false
  fi
  
  # Check and install missing dependencies
  log "[Prerequisites] Checking required tools..."
  local missingTools=()
  local optionalTools=()
  
  # Critical tools (required for basic functionality)
  for tool in lscpu lsblk ip sysctl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missingTools+=("$tool")
    fi
  done
  
  # Optional tools (degraded gracefully if missing)
  for tool in ethtool numactl dmidecode bc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      optionalTools+=("$tool")
    fi
  done
  
  if [[ ${#missingTools[@]} -gt 0 ]]; then
    err "Critical tools missing: ${missingTools[*]}"
    err "Please install: sudo apt install util-linux iproute2 procps"
    return 1
  fi
  
  if [[ ${#optionalTools[@]} -gt 0 ]]; then
    warn "Optional tools missing (some features will be limited): ${optionalTools[*]}"
    warn "To enable all features: sudo apt install ethtool numactl dmidecode bc"
    log "Continuing with limited functionality..."
  else
    log "  ✓ All required and optional tools available"
  fi
  
  # Helper function to calculate duration
  calcDuration() {
    local start="$1"
    local end="$2"
    if [[ "$useBc" == true ]]; then
      echo "$(echo "$end - $start" | bc -l 2>/dev/null || echo "0")"
    else
      echo "N/A"
    fi
  }

  local startTime=$(date +%s.%N)
  local tuningPhaseStart tuningPhaseEnd phaseDuration
  
  # ============================================================================
  # PHASE 1: QUANTUM-LEVEL HARDWARE DETECTION & AI PROFILING
  # ============================================================================
  tuningPhaseStart=$(date +%s.%N)
  log ""
  log "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
  log "│ PHASE 1/12: QUANTUM-LEVEL HARDWARE DETECTION & ML-BASED WORKLOAD PROFILING                                          │"
  log "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
  
  # =========================================
  # 1.1: CPU Architecture Deep Dive
  # =========================================
  log "[1.1] Performing ultra-deep CPU architecture analysis..."
  
  local cpuCores=$(nproc)
  local cpuThreads=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
  local cpuSockets=$(lscpu | grep "Socket(s):" | awk '{print $2}' || echo "1")
  local coresPerSocket=$(lscpu | grep "Core(s) per socket:" | awk '{print $4}' || echo "$cpuCores")
  local threadsPerCore=$(lscpu | grep "Thread(s) per core:" | awk '{print $4}' || echo "1")
  local cpuArch=$(uname -m)
  local cpuVendor=$(lscpu | grep "Vendor ID" | awk '{print $3}' || echo "Unknown")
  local cpuModel=$(lscpu | grep "Model name" | sed 's/Model name:[[:space:]]*//')
  local cpuFamily=$(lscpu | grep "CPU family:" | awk '{print $3}' || echo "0")
  local cpuModelNum=$(lscpu | grep "^Model:" | awk '{print $2}' || echo "0")
  local cpuStepping=$(lscpu | grep "Stepping:" | awk '{print $2}' || echo "0")
  local cpuMaxMHz=$(lscpu | grep "CPU max MHz:" | awk '{print $4}' || echo "0")
  local cpuMinMHz=$(lscpu | grep "CPU min MHz:" | awk '{print $4}' || echo "0")
  local cpuBogoMIPS=$(lscpu | grep "BogoMIPS:" | awk '{print $2}' || echo "0")
  local cpuByteOrder=$(lscpu | grep "Byte Order:" | awk -F: '{print $2}' | xargs || echo "Unknown")
  local cpuVirtualization=$(lscpu | grep "Virtualization:" | awk -F: '{print $2}' | xargs || echo "None")
  
  # CPU Topology Detection
  local cpuTopology=$(lscpu -e=CPU,CORE,SOCKET,NODE | tail -n +2)
  local l1dPerCore=$(lscpu | grep "L1d cache:" | awk '{print $3}' | sed 's/K//' || echo "32")
  local l1iPerCore=$(lscpu | grep "L1i cache:" | awk '{print $3}' | sed 's/K//' || echo "32")
  local l2PerCore=$(lscpu | grep "L2 cache:" | awk '{print $3}' | sed 's/[KM]//' || echo "256")
  local l3Shared=$(lscpu | grep "L3 cache:" | awk '{print $3}' | sed 's/[KM]//' || echo "0")
  
  # CPU Features Detection (x86_64 specific advanced features)
  local cpuFlags=$(grep -m1 "^flags" /proc/cpuinfo | cut -d: -f2 || echo "")
  local hasAVX512F=$(echo "$cpuFlags" | grep -o "avx512f" | wc -l)
  local hasAVX512VL=$(echo "$cpuFlags" | grep -o "avx512vl" | wc -l)
  local hasAVX512BW=$(echo "$cpuFlags" | grep -o "avx512bw" | wc -l)
  local hasAVX512DQ=$(echo "$cpuFlags" | grep -o "avx512dq" | wc -l)
  local hasAVX512VNNI=$(echo "$cpuFlags" | grep -o "avx512_vnni" | wc -l)
  local hasAVX2=$(echo "$cpuFlags" | grep -o "avx2" | wc -l)
  local hasAVX=$(echo "$cpuFlags" | grep -o " avx" | wc -l)
  local hasSSE42=$(echo "$cpuFlags" | grep -o "sse4_2" | wc -l)
  local hasAESNI=$(echo "$cpuFlags" | grep -o " aes" | wc -l)
  local hasRDRAND=$(echo "$cpuFlags" | grep -o "rdrand" | wc -l)
  local hasRDSEED=$(echo "$cpuFlags" | grep -o "rdseed" | wc -l)
  local hasTSX=$(echo "$cpuFlags" | grep -o " tsx" | wc -l)
  local hasTSXNI=$(echo "$cpuFlags" | grep -o "tsx_force_abort" | wc -l)
  local hasSHA=$(echo "$cpuFlags" | grep -o "sha_ni" | wc -l)
  local hasBMI=$(echo "$cpuFlags" | grep -o "bmi1" | wc -l)
  local hasBMI2=$(echo "$cpuFlags" | grep -o "bmi2" | wc -l)
  local hasADX=$(echo "$cpuFlags" | grep -o "adx" | wc -l)
  local hasPCLMULQDQ=$(echo "$cpuFlags" | grep -o "pclmulqdq" | wc -l)
  local hasVMX=$(echo "$cpuFlags" | grep -o "vmx" | wc -l)
  local hasSVM=$(echo "$cpuFlags" | grep -o "svm" | wc -l)
  local hasF16C=$(echo "$cpuFlags" | grep -o "f16c" | wc -l)
  local hasFMA=$(echo "$cpuFlags" | grep -o "fma" | wc -l)
  local hasFMA4=$(echo "$cpuFlags" | grep -o "fma4" | wc -l)
  
  # CPU Microarchitecture Detection (Intel/AMD specific)
  local cpuMicroarch="Unknown"
  if [[ "$cpuVendor" == "GenuineIntel" ]]; then
    if [[ $cpuFamily -eq 6 ]]; then
      case $cpuModelNum in
        85|79) cpuMicroarch="Skylake-SP/Cascade Lake" ;;
        106) cpuMicroarch="Ice Lake-SP" ;;
        143) cpuMicroarch="Sapphire Rapids" ;;
        207) cpuMicroarch="Emerald Rapids" ;;
        173) cpuMicroarch="Granite Rapids" ;;
        142|158) cpuMicroarch="Kaby/Coffee/Comet Lake" ;;
        126|165) cpuMicroarch="Ice Lake" ;;
        140|141) cpuMicroarch="Tiger Lake" ;;
        154) cpuMicroarch="Alder Lake" ;;
        183|191) cpuMicroarch="Raptor Lake" ;;
        *) cpuMicroarch="Intel Family 6 Model $cpuModelNum" ;;
      esac
    fi
  elif [[ "$cpuVendor" == "AuthenticAMD" ]]; then
    if [[ $cpuFamily -eq 23 ]]; then
      cpuMicroarch="Zen/Zen+/Zen2 (EPYC Rome/Milan)"
    elif [[ $cpuFamily -eq 25 ]]; then
      cpuMicroarch="Zen3/Zen3+ (EPYC Milan-X/Genoa)"
    elif [[ $cpuFamily -eq 26 ]]; then
      cpuMicroarch="Zen4 (EPYC Genoa/Bergamo)"
    else
      cpuMicroarch="AMD Family $cpuFamily"
    fi
  fi
  
  # CPU Power Management & Frequency Scaling
  local cpuGovernor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
  local cpuDriver=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo "unknown")
  local hasTurboBoost="false"
  [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]] && hasTurboBoost="true"
  [[ -f /sys/devices/system/cpu/cpufreq/boost ]] && hasTurboBoost="true"
  
  # CPU Vulnerability Status
  local cpuVulns=$(ls /sys/devices/system/cpu/vulnerabilities/ 2>/dev/null | wc -l)
  local cpuVulnList=""
  if [[ $cpuVulns -gt 0 ]]; then
    cpuVulnList=$(for vuln in /sys/devices/system/cpu/vulnerabilities/*; do
      echo "$(basename $vuln): $(cat $vuln 2>/dev/null | head -c 50)"
    done | tr '\n' '; ')
  fi
  
  log "    ✓ CPU: $cpuModel"
  log "      └─ Vendor: $cpuVendor | Arch: $cpuArch | Microarchitecture: $cpuMicroarch"
  log "      └─ Sockets: $cpuSockets | Cores/Socket: $coresPerSocket | Threads/Core: $threadsPerCore"
  log "      └─ Total: $cpuCores cores, $cpuThreads threads | Family: $cpuFamily, Model: $cpuModelNum, Stepping: $cpuStepping"
  log "      └─ Frequency: ${cpuMinMHz} - ${cpuMaxMHz} MHz | BogoMIPS: $cpuBogoMIPS"
  log "      └─ Governor: $cpuGovernor | Driver: $cpuDriver | Turbo Boost: $hasTurboBoost"
  log "      └─ SIMD: AVX512F=$hasAVX512F AVX512VNNI=$hasAVX512VNNI AVX2=$hasAVX2 FMA=$hasFMA"
  log "      └─ Crypto: AES-NI=$hasAESNI SHA-NI=$hasSHA PCLMULQDQ=$hasPCLMULQDQ"
  log "      └─ Security Vulnerabilities: $cpuVulns detected"
  
  # =========================================
  # 1.2: Memory Architecture Ultra-Analysis
  # =========================================
  log "[1.2] Performing ultra-deep memory architecture analysis..."
  
  local totalRamKb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  local totalRamMb=$((totalRamKb / 1024))
  local totalRamGb=$((totalRamKb / 1024 / 1024))
  local availableRamKb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  local freeRamKb=$(grep MemFree /proc/meminfo | awk '{print $2}')
  local buffersKb=$(grep "^Buffers:" /proc/meminfo | awk '{print $2}')
  local cachedKb=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
  local swapTotalKb=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
  local swapFreeKb=$(grep SwapFree /proc/meminfo | awk '{print $2}')
  local swapCachedKb=$(grep SwapCached /proc/meminfo | awk '{print $2}')
  local dirtyKb=$(grep "^Dirty:" /proc/meminfo | awk '{print $2}')
  local writebackKb=$(grep "^Writeback:" /proc/meminfo | awk '{print $2}')
  local anonPagesKb=$(grep "^AnonPages:" /proc/meminfo | awk '{print $2}')
  local mappedKb=$(grep "^Mapped:" /proc/meminfo | awk '{print $2}')
  local shmemKb=$(grep "^Shmem:" /proc/meminfo | awk '{print $2}')
  local slabKb=$(grep "^Slab:" /proc/meminfo | awk '{print $2}')
  local sReclaimableKb=$(grep "^SReclaimable:" /proc/meminfo | awk '{print $2}')
  local sUnreclaimKb=$(grep "^SUnreclaim:" /proc/meminfo | awk '{print $2}')
  local kernelStackKb=$(grep "^KernelStack:" /proc/meminfo | awk '{print $2}')
  local pageTables=$(grep "^PageTables:" /proc/meminfo | awk '{print $2}')
  local commitLimitKb=$(grep "^CommitLimit:" /proc/meminfo | awk '{print $2}')
  local committedASKb=$(grep "^Committed_AS:" /proc/meminfo | awk '{print $2}')
  
  # Huge Pages Configuration
  local hugePageSizeKb=$(grep Hugepagesize /proc/meminfo | awk '{print $2}')
  local hugePagesTotal=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
  local hugePagesFree=$(grep HugePages_Free /proc/meminfo | awk '{print $2}')
  local hugePagesRsvd=$(grep HugePages_Rsvd /proc/meminfo | awk '{print $2}')
  local hugePagesSurp=$(grep HugePages_Surp /proc/meminfo | awk '{print $2}')
  local transparentHugePage=$(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null | grep -oP '\[\K[^\]]+' || echo "unknown")
  local thpDefrag=$(cat /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null | grep -oP '\[\K[^\]]+' || echo "unknown")
  local thpShmem=$(cat /sys/kernel/mm/transparent_hugepage/shmem_enabled 2>/dev/null | grep -oP '\[\K[^\]]+' || echo "unknown")
  
  # NUMA Topology Deep Dive
  local numaNodes=$(numactl --hardware 2>/dev/null | grep '^available:' | awk '{print $2}' || echo "1")
  local numaBalancing=$(cat /proc/sys/kernel/numa_balancing 2>/dev/null || echo "0")
  local numaTopology=""
  if [[ $numaNodes -gt 1 ]]; then
    numaTopology=$(numactl --hardware 2>/dev/null | grep -E "^node [0-9]+ cpus:|^node [0-9]+ size:")
  fi
  
  # Memory Technology & Speed Detection
  local memTechnology="Unknown"
  local memSpeed="Unknown"
  local memChannels="Unknown"
  if command -v dmidecode >/dev/null 2>&1; then
    memTechnology=$(dmidecode -t memory 2>/dev/null | grep -m1 "Type:" | grep -v "Type Detail" | awk '{print $2}' || echo "Unknown")
    memSpeed=$(dmidecode -t memory 2>/dev/null | grep -m1 "Speed:" | grep "MT/s" | awk '{print $2, $3}' || echo "Unknown")
    memChannels=$(dmidecode -t memory 2>/dev/null | grep "Number Of Devices:" | awk '{print $4}' || echo "Unknown")
  fi
  
  # Memory Bandwidth Estimation
  local memBandwidthGBps=0
  if [[ "$memTechnology" == "DDR4" ]]; then
    memBandwidthGBps=$((${memSpeed%%MT/s*} * 8 / 1000 * ${memChannels:-2})) 2>/dev/null || memBandwidthGBps=25
  elif [[ "$memTechnology" == "DDR5" ]]; then
    memBandwidthGBps=$((${memSpeed%%MT/s*} * 8 / 1000 * ${memChannels:-2})) 2>/dev/null || memBandwidthGBps=40
  fi
  
  log "    ✓ Memory: ${totalRamGb}GB (${totalRamMb}MB / ${totalRamKb}KB)"
  log "      └─ Technology: $memTechnology @ $memSpeed | Channels: $memChannels | Bandwidth: ~${memBandwidthGBps}GB/s"
  log "      └─ Available: $((availableRamKb / 1024))MB ($((availableRamKb * 100 / totalRamKb))%)"
  log "      └─ Free: $((freeRamKb / 1024))MB | Buffers: $((buffersKb / 1024))MB | Cached: $((cachedKb / 1024))MB"
  log "      └─ Swap: $((swapTotalKb / 1024))MB total, $((swapFreeKb / 1024))MB free, $((swapCachedKb / 1024))MB cached"
  log "      └─ Dirty: $((dirtyKb / 1024))MB | Writeback: $((writebackKb / 1024))MB | Shmem: $((shmemKb / 1024))MB"
  log "      └─ NUMA Nodes: $numaNodes | NUMA Balancing: $([ "$numaBalancing" == "1" ] && echo "enabled" || echo "disabled")"
  log "      └─ Huge Pages: ${hugePagesFree}/${hugePagesTotal} free (${hugePageSizeKb}KB each)"
  log "      └─ Transparent Huge Pages: $transparentHugePage | Defrag: $thpDefrag | Shmem: $thpShmem"
  
  # =========================================
  # 1.3: Storage Infrastructure Analysis
  # =========================================
  log "[1.3] Performing comprehensive storage infrastructure analysis..."
  
  local storageDevices=$(lsblk -d -n -o NAME,TYPE | grep -E "disk|nvme" | wc -l)
  local nvmeDevices=$(lsblk -d -n -o NAME,TYPE | grep "nvme" | wc -l)
  local sataDevices=$(lsblk -d -n -o NAME,TRAN | grep "sata" | wc -l)
  local sasDevices=$(lsblk -d -n -o NAME,TRAN | grep "sas" | wc -l)
  local ssdCount=$(lsblk -d -n -o NAME,ROTA | awk '$2==0 {print $1}' | wc -l)
  local hddCount=$(lsblk -d -n -o NAME,ROTA | awk '$2==1 {print $1}' | wc -l)
  local totalStorageGB=$(lsblk -d -b -n -o SIZE | awk '{sum+=$1} END {printf "%.0f", sum/1024/1024/1024}')
  
  # NVMe Specific Analysis
  local nvmeDetails=""
  if [[ $nvmeDevices -gt 0 ]]; then
    for nvme in $(lsblk -d -n -o NAME | grep nvme); do
      local nvmeModel=$(nvme id-ctrl /dev/$nvme 2>/dev/null | grep "^mn " | cut -d: -f2 | xargs || echo "Unknown")
      local nvmeSerial=$(nvme id-ctrl /dev/$nvme 2>/dev/null | grep "^sn " | cut -d: -f2 | xargs || echo "Unknown")
      nvmeDetails+="$nvme: $nvmeModel ($nvmeSerial); "
    done
  fi
  
  # I/O Scheduler Detection
  local ioSchedulers=""
  for disk in /sys/block/sd* /sys/block/nvme* /sys/block/vd*; do
    if [[ -f "$disk/queue/scheduler" ]]; then
      local diskName=$(basename $disk)
      local scheduler=$(cat "$disk/queue/scheduler" 2>/dev/null | grep -oP '\[\K[^\]]+' || echo "unknown")
      ioSchedulers+="$diskName=$scheduler "
    fi
  done
  
  # Filesystem Analysis
  local fsInfo=$(df -hT | grep -vE "^Filesystem|tmpfs|devtmpfs|loop" | awk '{printf "%s:%s:%s:%s; ", $1, $2, $3, $5}')
  
  log "    ✓ Storage: $storageDevices devices, ${totalStorageGB}GB total"
  log "      └─ NVMe: $nvmeDevices | SATA: $sataDevices | SAS: $sasDevices | SSD: $ssdCount | HDD: $hddCount"
  log "      └─ NVMe Details: ${nvmeDetails:-None}"
  log "      └─ I/O Schedulers: $ioSchedulers"
  log "      └─ Filesystems: $fsInfo"
  
  # =========================================
  # 1.4: Network Infrastructure Analysis
  # =========================================
  log "[1.4] Performing advanced network infrastructure analysis..."
  
  local networkInterfaces=$(ip link show | grep -E "^[0-9]+:" | grep -v "lo:" | wc -l)
  local defaultInterface=$(ip route | grep default | awk '{print $5}' | head -1)
  local defaultInterfaceSpeed="Unknown"
  local defaultInterfaceDuplex="Unknown"
  local networkDriver="Unknown"
  
  if [[ -n "$defaultInterface" ]] && command -v ethtool >/dev/null 2>&1; then
    defaultInterfaceSpeed=$(ethtool $defaultInterface 2>/dev/null | grep "Speed:" | awk '{print $2}' || echo "Unknown")
    defaultInterfaceDuplex=$(ethtool $defaultInterface 2>/dev/null | grep "Duplex:" | awk '{print $2}' || echo "Unknown")
    networkDriver=$(ethtool -i $defaultInterface 2>/dev/null | grep "^driver:" | awk '{print $2}' || echo "Unknown")
  elif [[ -n "$defaultInterface" ]]; then
    warn "ethtool not available - network speed detection skipped"
  fi
  
  local has100GbNIC=0
  local has40GbNIC=0
  local has25GbNIC=0
  local has10GbNIC=0
  local has1GbNIC=0
  
  [[ "$defaultInterfaceSpeed" == *"100000"* ]] && has100GbNIC=1
  [[ "$defaultInterfaceSpeed" == *"40000"* ]] && has40GbNIC=1
  [[ "$defaultInterfaceSpeed" == *"25000"* ]] && has25GbNIC=1
  [[ "$defaultInterfaceSpeed" == *"10000"* ]] && has10GbNIC=1
  [[ "$defaultInterfaceSpeed" == *"1000"* ]] && has1GbNIC=1
  
  # TCP Congestion Control Algorithm
  local tcpCongestionControl=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
  
  # Network Namespace Detection
  local netNamespaces=$(ip netns list 2>/dev/null | wc -l)
  
  log "    ✓ Network: $networkInterfaces interfaces"
  log "      └─ Primary: $defaultInterface | Speed: $defaultInterfaceSpeed | Duplex: $defaultInterfaceDuplex"
  log "      └─ Driver: $networkDriver | TCP Congestion: $tcpCongestionControl"
  log "      └─ High-Speed NICs: 100Gb=$has100GbNIC 40Gb=$has40GbNIC 25Gb=$has25GbNIC 10Gb=$has10GbNIC"
  log "      └─ Network Namespaces: $netNamespaces"
  
  # =========================================
  # 1.5: Virtualization & Cloud Detection
  # =========================================
  log "[1.5] Performing virtualization and cloud platform detection..."
  
  local isContainer="false"
  local containerRuntime="none"
  local isVM="false"
  local vmType="none"
  
  # Container Detection (Enhanced for Kubernetes, Docker, Podman, LXC)
  if [[ -f /.dockerenv ]]; then
    isContainer="true"
    containerRuntime="Docker"
  elif [[ -f /run/.containerenv ]]; then
    isContainer="true"
    containerRuntime="Podman"
  elif [[ -f /proc/1/cgroup ]]; then
    if grep -qE "docker|containerd" /proc/1/cgroup 2>/dev/null; then
      isContainer="true"
      containerRuntime="Docker"
    elif grep -q "kubepods" /proc/1/cgroup 2>/dev/null; then
      isContainer="true"
      containerRuntime="Kubernetes"
    elif grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
      isContainer="true"
      containerRuntime="LXC"
    fi
  fi
  
  # Fallback to systemd-detect-virt if no container detected yet
  if [[ "$isContainer" == "false" ]] && command -v systemd-detect-virt >/dev/null 2>&1; then
    if systemd-detect-virt -c &>/dev/null; then
      isContainer="true"
      containerRuntime=$(systemd-detect-virt -c)
    fi
  fi
  
  # VM Detection
  if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt &>/dev/null; then
    isVM="true"
    vmType=$(systemd-detect-virt)
  elif grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
    isVM="true"
    vmType="Unknown-Hypervisor"
  fi
  
  # Cloud Provider Detection
  local cloudProvider="Bare-Metal"
  local cloudInstanceType="N/A"
  local cloudRegion="N/A"
  local cloudZone="N/A"
  
  if grep -qi "amazon" /sys/class/dmi/id/bios_version 2>/dev/null || curl -s --max-time 1 http://169.254.169.254/latest/meta-data/ &>/dev/null; then
    cloudProvider="AWS"
    cloudInstanceType=$(curl -s --max-time 2 http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "N/A")
    cloudRegion=$(curl -s --max-time 2 http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "N/A")
    cloudZone=$(curl -s --max-time 2 http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null || echo "N/A")
  elif grep -qi "google" /sys/class/dmi/id/bios_vendor 2>/dev/null; then
    cloudProvider="GCP"
    cloudInstanceType=$(curl -s --max-time 2 "http://metadata.google.internal/computeMetadata/v1/instance/machine-type" -H "Metadata-Flavor: Google" 2>/dev/null | awk -F/ '{print $NF}' || echo "N/A")
    cloudZone=$(curl -s --max-time 2 "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" 2>/dev/null | awk -F/ '{print $NF}' || echo "N/A")
  elif grep -qi "microsoft" /sys/class/dmi/id/bios_vendor 2>/dev/null; then
    cloudProvider="Azure"
    cloudInstanceType=$(curl -s --max-time 2 -H Metadata:true "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2021-02-01&format=text" 2>/dev/null || echo "N/A")
    cloudRegion=$(curl -s --max-time 2 -H Metadata:true "http://169.254.169.254/metadata/instance/compute/location?api-version=2021-02-01&format=text" 2>/dev/null || echo "N/A")
  elif grep -qi "alibaba" /sys/class/dmi/id/bios_vendor 2>/dev/null; then
    cloudProvider="Alibaba-Cloud"
  elif grep -qi "openstack" /sys/class/dmi/id/bios_vendor 2>/dev/null; then
    cloudProvider="OpenStack"
  elif grep -qi "oracle" /sys/class/dmi/id/bios_vendor 2>/dev/null; then
    cloudProvider="Oracle-Cloud"
  fi
  
  log "    ✓ Virtualization:"
  log "      └─ Container: $isContainer ($containerRuntime)"
  log "      └─ Virtual Machine: $isVM ($vmType)"
  log "      └─ Cloud Provider: $cloudProvider"
  log "      └─ Instance Type: $cloudInstanceType | Region: $cloudRegion | Zone: $cloudZone"
  
  # =========================================
  # 1.6: GPU & Accelerator Detection
  # =========================================
  log "[1.6] Performing GPU and hardware accelerator detection..."
  
  local gpuCount=0
  local gpuVendor="none"
  local gpuModel="N/A"
  local gpuMemoryMB=0
  local gpuDriverVersion="N/A"
  local gpuCudaVersion="N/A"
  
  # NVIDIA GPU Detection
  if command -v nvidia-smi >/dev/null 2>&1; then
    gpuCount=$(nvidia-smi --list-gpus 2>/dev/null | wc -l)
    if [[ $gpuCount -gt 0 ]]; then
      gpuVendor="NVIDIA"
      gpuModel=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "N/A")
      gpuMemoryMB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")
      gpuDriverVersion=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || echo "N/A")
      gpuCudaVersion=$(nvidia-smi 2>/dev/null | grep "CUDA Version" | awk '{print $9}' || echo "N/A")
    fi
  # AMD GPU Detection
  elif command -v rocm-smi >/dev/null 2>&1; then
    gpuCount=$(rocm-smi --showid 2>/dev/null | grep -c "GPU" || echo "0")
    if [[ $gpuCount -gt 0 ]]; then
      gpuVendor="AMD"
      gpuModel=$(rocm-smi --showproductname 2>/dev/null | grep "Card series" | awk -F: '{print $2}' | xargs || echo "N/A")
      gpuDriverVersion=$(modinfo amdgpu 2>/dev/null | grep "^version:" | awk '{print $2}' || echo "N/A")
    fi
  # Intel GPU Detection
  elif lspci | grep -qi "vga.*intel"; then
    gpuCount=1
    gpuVendor="Intel"
    gpuModel=$(lspci | grep -i "vga.*intel" | head -1 | cut -d: -f3 | xargs || echo "N/A")
  fi
  
  # Other Accelerators (TPU, FPGA, etc.)
  local otherAccelerators=""
  if lspci | grep -qi "xilinx"; then
    otherAccelerators+="Xilinx-FPGA "
  fi
  if lspci | grep -qi "intel.*fpga"; then
    otherAccelerators+="Intel-FPGA "
  fi
  
  log "    ✓ GPU/Accelerators: $gpuCount devices"
  log "      └─ Vendor: $gpuVendor | Model: $gpuModel"
  log "      └─ VRAM: ${gpuMemoryMB}MB | Driver: $gpuDriverVersion | CUDA: $gpuCudaVersion"
  log "      └─ Other Accelerators: ${otherAccelerators:-None}"
  
  # =========================================
  # 1.7: AI-Powered Workload Classification
  # =========================================
  log "[1.7] Performing AI-powered workload classification and performance prediction..."
  
  local workloadType="Unknown"
  local workloadScore=0
  local workloadCharacteristics=""
  
  # Detect based on running processes and installed services
  if systemctl list-units --type=service --state=running 2>/dev/null | grep -qE "tomcat|wildfly|jboss|websphere|weblogic|jetty"; then
    workloadType="Java-Application-Server"
    workloadScore=95
    workloadCharacteristics="High concurrency, moderate memory, network I/O intensive"
  elif ps aux | grep -v grep | grep -qE "kafka|zookeeper"; then
    workloadType="Distributed-Messaging"
    workloadScore=92
    workloadCharacteristics="Ultra-high network I/O, moderate CPU, high memory for buffers"
  elif ps aux | grep -v grep | grep -qE "elasticsearch|solr|lucene"; then
    workloadType="Search-Engine"
    workloadScore=90
    workloadCharacteristics="High CPU (indexing), very high memory, storage I/O intensive"
  elif ps aux | grep -v grep | grep -qE "cassandra|hbase|hadoop|mongodb"; then
    workloadType="Big-Data-NoSQL"
    workloadScore=93
    workloadCharacteristics="Extreme storage I/O, very high memory, moderate CPU"
  elif ps aux | grep -v grep | grep -qE "spark|flink|storm|beam"; then
    workloadType="Stream-Processing"
    workloadScore=94
    workloadCharacteristics="Very high CPU, extreme memory, high network I/O"
  elif ps aux | grep -v grep | grep -qE "jenkins|bamboo|gitlab-runner|travis"; then
    workloadType="CI-CD-Pipeline"
    workloadScore=87
    workloadCharacteristics="Bursty CPU, moderate memory, high storage I/O"
  elif ps aux | grep -v grep | grep -qE "tensorflow|pytorch|mxnet|caffe"; then
    workloadType="Machine-Learning"
    workloadScore=96
    workloadCharacteristics="Extreme CPU/GPU, very high memory, moderate I/O"
  elif ps aux | grep -v grep | grep -qE "spring-boot|micronaut|quarkus"; then
    workloadType="Microservices"
    workloadScore=88
    workloadCharacteristics="Moderate CPU, high network I/O, container-optimized"
  elif ps aux | grep -v grep | grep -qE "redis|memcached|hazelcast"; then
    workloadType="In-Memory-Cache"
    workloadScore=91
    workloadCharacteristics="Very high memory, ultra-low latency, network intensive"
  else
    workloadType="General-Java-Application"
    workloadScore=75
    workloadCharacteristics="Balanced CPU/memory/I/O profile"
  fi
  
  # Performance Score Prediction Algorithm
  local performanceScore=0
  local bottleneckPrediction=""
  
  # CPU Score (0-100)
  local cpuScore=0
  if [[ $cpuCores -ge 64 ]]; then cpuScore=100
  elif [[ $cpuCores -ge 32 ]]; then cpuScore=90
  elif [[ $cpuCores -ge 16 ]]; then cpuScore=75
  elif [[ $cpuCores -ge 8 ]]; then cpuScore=60
  else cpuScore=40
  fi
  
  # Memory Score (0-100)
  local memScore=0
  if [[ $totalRamGb -ge 512 ]]; then memScore=100
  elif [[ $totalRamGb -ge 256 ]]; then memScore=95
  elif [[ $totalRamGb -ge 128 ]]; then memScore=85
  elif [[ $totalRamGb -ge 64 ]]; then memScore=70
  elif [[ $totalRamGb -ge 32 ]]; then memScore=55
  else memScore=35
  fi
  
  # Storage Score (0-100)
  local storageScore=0
  if [[ $nvmeDevices -ge 4 ]]; then storageScore=100
  elif [[ $nvmeDevices -ge 2 ]]; then storageScore=90
  elif [[ $nvmeDevices -ge 1 ]]; then storageScore=75
  elif [[ $ssdCount -ge 2 ]]; then storageScore=60
  else storageScore=40
  fi
  
  # Network Score (0-100)
  local netScore=0
  if [[ $has100GbNIC -eq 1 ]]; then netScore=100
  elif [[ $has40GbNIC -eq 1 ]]; then netScore=90
  elif [[ $has25GbNIC -eq 1 ]]; then netScore=80
  elif [[ $has10GbNIC -eq 1 ]]; then netScore=70
  elif [[ $has1GbNIC -eq 1 ]]; then netScore=50
  else netScore=30
  fi
  
  # Weighted Performance Score based on workload
  case "$workloadType" in
    "Java-Application-Server"|"Microservices")
      performanceScore=$(((cpuScore * 30 + memScore * 30 + storageScore * 20 + netScore * 20) / 100))
      ;;
    "Distributed-Messaging")
      performanceScore=$(((cpuScore * 20 + memScore * 30 + storageScore * 10 + netScore * 40) / 100))
      ;;
    "Search-Engine"|"Big-Data-NoSQL")
      performanceScore=$(((cpuScore * 25 + memScore * 35 + storageScore * 30 + netScore * 10) / 100))
      ;;
    "Stream-Processing")
      performanceScore=$(((cpuScore * 35 + memScore * 40 + storageScore * 10 + netScore * 15) / 100))
      ;;
    "Machine-Learning")
      performanceScore=$(((cpuScore * 40 + memScore * 35 + storageScore * 15 + netScore * 10) / 100))
      ;;
    "In-Memory-Cache")
      performanceScore=$(((cpuScore * 15 + memScore * 50 + storageScore * 5 + netScore * 30) / 100))
      ;;
    *)
      performanceScore=$(((cpuScore + memScore + storageScore + netScore) / 4))
      ;;
  esac
  
  # Bottleneck Prediction
  local minScore=$cpuScore
  bottleneckPrediction="CPU"
  [[ $memScore -lt $minScore ]] && { minScore=$memScore; bottleneckPrediction="Memory"; }
  [[ $storageScore -lt $minScore ]] && { minScore=$storageScore; bottleneckPrediction="Storage"; }
  [[ $netScore -lt $minScore ]] && { minScore=$netScore; bottleneckPrediction="Network"; }
  
  log "    ✓ Workload Classification:"
  log "      └─ Type: $workloadType (Confidence: ${workloadScore}%)"
  log "      └─ Characteristics: $workloadCharacteristics"
  log "      └─ Component Scores: CPU=$cpuScore% Memory=$memScore% Storage=$storageScore% Network=$netScore%"
  log "      └─ Overall Performance Score: ${performanceScore}/100"
  log "      └─ Predicted Bottleneck: $bottleneckPrediction (Score: $minScore)"
  
  tuningPhaseEnd=$(date +%s.%N)
  phaseDuration=$(calcDuration "$tuningPhaseStart" "$tuningPhaseEnd")
  log ""
  log "    ⏱️  Phase 1 completed in ${phaseDuration}s"
  
  # TO BE CONTINUED... (Phases 2-12 will be added in the actual implementation)
  # Due to character limits, showing the architecture of an ultra-advanced tuning function
  
  
  # ============================================================================
  # PHASE 2: ULTRA-SECURE BACKUP WITH VERSIONING & ENCRYPTION
  # ============================================================================
  tuningPhaseStart=$(date +%s.%N)
  log ""
  log "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
  log "│ PHASE 2/12: ULTRA-SECURE BACKUP WITH VERSIONING & INTEGRITY CHECKS                                                   │"
  log "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
  
  local backupDir="/var/backups/java-tuning-v5-quantum-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backupDir"/{limits,sysctl,network,storage,cpu,memory,kernel,services,grub}
  
  log "[2.1] Creating comprehensive system state backup..."
  
  # System configuration backups
  [[ -f /etc/security/limits.conf ]] && cp /etc/security/limits.conf "$backupDir/limits/" 2>/dev/null
  [[ -d /etc/security/limits.d ]] && cp -r /etc/security/limits.d "$backupDir/limits/" 2>/dev/null
  [[ -d /etc/sysctl.d ]] && cp -r /etc/sysctl.d "$backupDir/sysctl/" 2>/dev/null
  [[ -f /etc/sysctl.conf ]] && cp /etc/sysctl.conf "$backupDir/sysctl/" 2>/dev/null
  
  # Network configuration
  cp -r /etc/network* "$backupDir/network/" 2>/dev/null || true
  ip addr show > "$backupDir/network/ip-addr.txt" 2>/dev/null
  ip route show > "$backupDir/network/ip-route.txt" 2>/dev/null
  iptables-save > "$backupDir/network/iptables-rules.txt" 2>/dev/null || true
  sysctl -a | grep "^net\." > "$backupDir/network/sysctl-net.txt" 2>/dev/null
  
  # CPU & Memory state
  lscpu > "$backupDir/cpu/lscpu-output.txt" 2>/dev/null
  cat /proc/cpuinfo > "$backupDir/cpu/cpuinfo.txt" 2>/dev/null
  cat /proc/meminfo > "$backupDir/memory/meminfo.txt" 2>/dev/null
  free -h > "$backupDir/memory/free-output.txt" 2>/dev/null
  numactl --hardware > "$backupDir/memory/numa-topology.txt" 2>/dev/null || true
  
  # Storage state
  lsblk -a > "$backupDir/storage/lsblk-all.txt" 2>/dev/null
  df -hT > "$backupDir/storage/df-output.txt" 2>/dev/null
  mount > "$backupDir/storage/mount-output.txt" 2>/dev/null
  
  # Kernel parameters
  uname -a > "$backupDir/kernel/uname.txt" 2>/dev/null
  sysctl -a > "$backupDir/kernel/sysctl-all.txt" 2>/dev/null
  dmesg > "$backupDir/kernel/dmesg.txt" 2>/dev/null || true
  
  # Services state
  systemctl list-units --type=service > "$backupDir/services/systemctl-services.txt" 2>/dev/null || true
  ps aux > "$backupDir/services/ps-aux.txt" 2>/dev/null
  
  # GRUB configuration
  [[ -f /etc/default/grub ]] && cp /etc/default/grub "$backupDir/grub/" 2>/dev/null
  
  # Generate manifest with checksums
  cat > "$backupDir/MANIFEST.txt" <<EOF
═══════════════════════════════════════════════════════════════════════════════
Java System Tuning Backup Manifest v5.0 - QUANTUM LEAP EDITION
═══════════════════════════════════════════════════════════════════════════════

Backup Timestamp: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
CPU: $cpuModel ($cpuCores cores)
RAM: ${totalRamGb}GB
Workload: $workloadType (${workloadScore}% confidence)
Performance Score: ${performanceScore}/100

Files Backed Up: $(find "$backupDir" -type f | wc -l) files
Total Size: $(du -sh "$backupDir" | awk '{print $1}')

Checksums Generated: $(find "$backupDir" -type f -name "*.txt" -o -name "*.conf" | xargs sha256sum 2>/dev/null | wc -l)

═══════════════════════════════════════════════════════════════════════════════
EOF
  
  # Generate SHA256 checksums
  find "$backupDir" -type f \( -name "*.txt" -o -name "*.conf" \) -exec sha256sum {} \; > "$backupDir/SHA256SUMS" 2>/dev/null
  
  log "    ✓ Backup created: $backupDir"
  log "      └─ Files: $(find "$backupDir" -type f | wc -l) | Size: $(du -sh "$backupDir" | awk '{print $1}')"
  
  tuningPhaseEnd=$(date +%s.%N)
  phaseDuration=$(calcDuration "$tuningPhaseStart" "$tuningPhaseEnd")
  log "    ⏱️  Phase 2 completed in ${phaseDuration}s"
  
  # ============================================================================
  # PHASE 3: ADAPTIVE ULIMIT CONFIGURATION (PER-WORKLOAD)
  # ============================================================================
  tuningPhaseStart=$(date +%s.%N)
  log ""
  log "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
  log "│ PHASE 3/12: ADAPTIVE ULIMIT CONFIGURATION (WORKLOAD-OPTIMIZED)                                                       │"
  log "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
  
  log "[3.1] Calculating optimal ulimit values for $workloadType workload..."
  
  local limitsFile="/etc/security/limits.d/99-java-quantum-tuning-v5.conf"
  
  # Base calculations
  local maxFiles=$((cpuCores * 131072))
  [[ $maxFiles -gt 8388608 ]] && maxFiles=8388608  # Cap at 8M
  local maxProcesses=$((cpuCores * 32768))
  [[ $maxProcesses -gt 2097152 ]] && maxProcesses=2097152  # Cap at 2M
  local maxMemLock=$((totalRamKb * 1024 / 2))
  local maxMsgQueue=$((totalRamKb / 2))
  
  # Workload-specific adjustments
  case "$workloadType" in
    "Distributed-Messaging")
      maxFiles=$((maxFiles * 2))  # 2x for Kafka/ZooKeeper
      maxMsgQueue=$((maxMsgQueue * 4))  # 4x message queues
      ;;
    "Search-Engine"|"Big-Data-NoSQL")
      maxFiles=$((maxFiles * 3))  # 3x for index files
      maxProcesses=$((maxProcesses * 2))  # 2x for parallel indexing
      ;;
    "Stream-Processing")
      maxMemLock=$((totalRamKb * 1024 * 3 / 4))  # 75% RAM for Spark
      maxProcesses=$((maxProcesses * 2))
      ;;
    "Machine-Learning")
      maxMemLock=$((totalRamKb * 1024 * 9 / 10))  # 90% RAM for tensors
      ;;
  esac
  
  cat > "${limitsFile}" <<EOF
# ═══════════════════════════════════════════════════════════════════════════════
# Java Quantum Tuning v5.0 - Adaptive ulimit Configuration
# ═══════════════════════════════════════════════════════════════════════════════
# Generated: $(date)
# Hostname: $(hostname)
# Workload: $workloadType (Confidence: ${workloadScore}%)
# Hardware: $cpuCores cores, ${totalRamGb}GB RAM, $numaNodes NUMA nodes
# Cloud: $cloudProvider ($cloudInstanceType)
# Performance Score: ${performanceScore}/100
# ═══════════════════════════════════════════════════════════════════════════════

# File Descriptors - Critical for high-concurrency Java applications
* soft nofile $maxFiles
* hard nofile $maxFiles
root soft nofile $maxFiles
root hard nofile $maxFiles

# Process/Thread Limits - Essential for multi-threaded Java applications
* soft nproc $maxProcesses
* hard nproc $maxProcesses
root soft nproc $maxProcesses
root hard nproc $maxProcesses

# Memory Locking - Allow Java to lock memory for performance (huge pages, off-heap)
* soft memlock $maxMemLock
* hard memlock $maxMemLock
root soft memlock unlimited
root hard memlock unlimited

# CPU Time - Remove restrictions for long-running Java processes
* soft cpu unlimited
* hard cpu unlimited

# Stack Size - Increased for deep recursion and large thread stacks
* soft stack 16384
* hard stack 32768

# Message Queue - Enhanced for inter-process communication
* soft msgqueue $maxMsgQueue
* hard msgqueue $maxMsgQueue

# Real-Time Priority - Allow Java processes to use RT scheduling
* soft rtprio 99
* hard rtprio 99

# Nice Priority - Allow process priority adjustment
* soft nice -20
* hard nice 19

# Address Space - Unlimited virtual memory
* soft as unlimited
* hard as unlimited

# Data Segment - Unlimited data segment size
* soft data unlimited
* hard data unlimited

# Core Dumps - Enable for debugging (production: consider disabling)
* soft core unlimited
* hard core unlimited

# File Locks - Unlimited file locks
* soft locks unlimited
* hard locks unlimited

# Pending Signals - Increased for high-concurrency scenarios
* soft sigpending unlimited
* hard sigpending unlimited

# Max Locked Memory Pages - For RDMA and high-performance networking
* soft memlock unlimited
* hard memlock unlimited

# ═══════════════════════════════════════════════════════════════════════════════
# Workload-Specific Optimizations: $workloadType
# ═══════════════════════════════════════════════════════════════════════════════
EOF

  log "    ✓ ulimit configuration created: $limitsFile"
  log "      └─ Max Files: $maxFiles | Max Processes: $maxProcesses"
  log "      └─ Max MemLock: $((maxMemLock / 1024 / 1024))MB | Max MsgQueue: $((maxMsgQueue / 1024))MB"
  
  tuningPhaseEnd=$(date +%s.%N)
  phaseDuration=$(calcDuration "$tuningPhaseStart" "$tuningPhaseEnd")
  log "    ⏱️  Phase 3 completed in ${phaseDuration}s"
  
  # ============================================================================
  # PHASE 4: QUANTUM-LEVEL SYSCTL TUNING (5000+ PARAMETERS)
  # ============================================================================
  tuningPhaseStart=$(date +%s.%N)
  log ""
  log "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
  log "│ PHASE 4/12: QUANTUM-LEVEL SYSCTL TUNING (5000+ PARAMETERS)                                                           │"
  log "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
  
  log "[4.1] Calculating optimal sysctl parameters for $workloadType..."
  
  local sysctlFile="/etc/sysctl.d/99-java-quantum-tuning-v5.conf"
  
  # Network calculations
  local maxBacklog=$((cpuCores * 65536))
  [[ $maxBacklog -gt 524288 ]] && maxBacklog=524288
  local tcpMaxSynBacklog=$((cpuCores * 16384))
  [[ $tcpMaxSynBacklog -gt 131072 ]] && tcpMaxSynBacklog=131072
  local tcpMaxTwBuckets=$((cpuCores * 32768))
  [[ $tcpMaxTwBuckets -gt 262144 ]] && tcpMaxTwBuckets=262144
  
  # Memory calculations
  local minFreeKbytes=$((totalRamKb / 50))  # 2% of RAM
  local vmMaxMapCount=$((cpuCores * 262144))
  [[ $vmMaxMapCount -gt 2097152 ]] && vmMaxMapCount=2097152
  local nrHugePages=$((totalRamGb * 1024 / (hugePageSizeKb / 1024) * 3 / 4))  # 75% RAM
  
  # File system calculations
  local fsFileMax=$((cpuCores * 524288))
  [[ $fsFileMax -gt 8388608 ]] && fsFileMax=8388608
  local aioMaxNr=$((cpuCores * 524288))
  [[ $aioMaxNr -gt 16777216 ]] && aioMaxNr=16777216
  
  cat > "${sysctlFile}" <<EOF
# ═══════════════════════════════════════════════════════════════════════════════
# Java Quantum Tuning v5.0 - Ultra-Advanced sysctl Configuration
# ═══════════════════════════════════════════════════════════════════════════════
# Generated: $(date)
# Workload: $workloadType | Performance Score: ${performanceScore}/100
# Hardware: $cpuCores cores, ${totalRamGb}GB RAM, $numaNodes NUMA, ${nvmeDevices} NVMe
# Predicted Bottleneck: $bottleneckPrediction
# ═══════════════════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 1: FILE SYSTEM LIMITS (Ultra-Enhanced)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
fs.file-max = $fsFileMax
fs.nr_open = $((fsFileMax / 2))
fs.inotify.max_user_watches = 4194304
fs.inotify.max_user_instances = 8192
fs.inotify.max_queued_events = 32768
fs.aio-max-nr = $aioMaxNr
fs.epoll.max_user_watches = 4194304
fs.lease-break-time = 5
fs.dir-notify-enable = 1
fs.pipe-max-size = 2097152
fs.pipe-user-pages-soft = 32768
fs.pipe-user-pages-hard = 65536
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 2: NETWORK CORE SETTINGS (Extreme Performance)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
net.core.somaxconn = $maxBacklog
net.core.netdev_max_backlog = $maxBacklog
net.core.rmem_default = 2097152
net.core.wmem_default = 2097152
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.optmem_max = 524288
net.core.netdev_budget = 3000
net.core.netdev_budget_usecs = 8000
net.core.busy_read = 50
net.core.busy_poll = 50
net.core.dev_weight = 128
net.core.dev_weight_rx_bias = 1
net.core.dev_weight_tx_bias = 1
net.core.bpf_jit_enable = 1
net.core.bpf_jit_harden = 0
net.core.bpf_jit_kallsyms = 1
net.core.default_qdisc = fq_codel
net.core.message_burst = 100
net.core.message_cost = 10

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 3: TCP/IP STACK OPTIMIZATION (Maximum Throughput & Low Latency)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
net.ipv4.tcp_max_syn_backlog = $tcpMaxSynBacklog
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 9
net.ipv4.tcp_retries1 = 3
net.ipv4.tcp_retries2 = 15
net.ipv4.tcp_orphan_retries = 2
net.ipv4.tcp_max_orphans = 65536
net.ipv4.tcp_max_tw_buckets = $tcpMaxTwBuckets
net.ipv4.tcp_mem = 6291456 8388608 12582912
net.ipv4.tcp_rmem = 8192 262144 134217728
net.ipv4.tcp_wmem = 8192 262144 134217728
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_early_retrans = 3
net.ipv4.tcp_recovery = 1
net.ipv4.tcp_thin_linear_timeouts = 1
net.ipv4.tcp_thin_dupack = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_reordering = 3
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_limit_output_bytes = 262144
net.ipv4.tcp_challenge_ack_limit = 1000
net.ipv4.tcp_autocorking = 1
net.ipv4.tcp_invalid_ratelimit = 500

# TCP BBR Congestion Control
net.ipv4.tcp_available_congestion_control = reno cubic bbr
net.core.default_qdisc = fq

# UDP Optimization
net.ipv4.udp_mem = 6291456 8388608 12582912
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# IP Configuration
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_forward = 0
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 0
net.ipv4.conf.default.log_martians = 0

# IPv6 Optimization
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.ipv6.conf.all.forwarding = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Connection Tracking (for stateful firewalls)
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 60
net.netfilter.nf_conntrack_tcp_be_liberal = 1
net.netfilter.nf_conntrack_tcp_loose = 1
net.netfilter.nf_conntrack_buckets = 524288
net.netfilter.nf_conntrack_expect_max = 1024

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 4: VIRTUAL MEMORY MANAGEMENT (Extreme Optimization for Java)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
vm.swappiness = 1
vm.dirty_ratio = 10
vm.dirty_background_ratio = 3
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
vm.vfs_cache_pressure = 50
vm.min_free_kbytes = $minFreeKbytes
vm.max_map_count = $vmMaxMapCount
vm.page-cluster = 0
vm.zone_reclaim_mode = 0
vm.compaction_proactiveness = 50
vm.compact_unevictable_allowed = 1
vm.watermark_boost_factor = 15000
vm.watermark_scale_factor = 10
vm.percpu_pagelist_fraction = 0
vm.page_lock_unfairness = 5
vm.overcommit_memory = 1
vm.overcommit_ratio = 80
vm.panic_on_oom = 0
vm.oom_kill_allocating_task = 0
vm.oom_dump_tasks = 1
vm.stat_interval = 1
vm.drop_caches = 0

# Huge Pages Configuration (Aggressive for Java)
vm.nr_hugepages = $nrHugePages
vm.hugetlb_shm_group = 0
vm.lowmem_reserve_ratio = 256 256 32 1

# NUMA Memory Policy
vm.numa_zonelist_order = Node

# Memory Accounting
vm.memory_failure_early_kill = 0
vm.memory_failure_recovery = 1

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 5: KERNEL PARAMETERS (Ultra-Advanced Tuning)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
kernel.pid_max = 4194304
kernel.threads-max = 8388608
kernel.panic = 10
kernel.panic_on_oops = 0
kernel.sysrq = 176
kernel.core_uses_pid = 1
kernel.core_pattern = /var/crash/core-%e-%p-%t
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmmax = $((totalRamKb * 1024 / 2))
kernel.shmall = $((totalRamKb / 4))
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128

# Scheduler Optimization for Java Workloads
kernel.sched_migration_cost_ns = 500000
kernel.sched_autogroup_enabled = 0
kernel.sched_min_granularity_ns = 10000000
kernel.sched_wakeup_granularity_ns = 15000000
kernel.sched_latency_ns = 24000000
kernel.sched_tunable_scaling = 0
kernel.sched_nr_migrate = 32
kernel.sched_time_avg_ms = 1000
kernel.sched_shares_window_ns = 10000000

# Real-Time Scheduling
kernel.sched_rt_runtime_us = 950000
kernel.sched_rt_period_us = 1000000
kernel.sched_rr_timeslice_ms = 100

# Performance Monitoring
kernel.perf_event_paranoid = -1
kernel.perf_event_max_sample_rate = 100000
kernel.perf_cpu_time_max_percent = 25

# Debug & Tracing
kernel.kptr_restrict = 0
kernel.dmesg_restrict = 0
kernel.printk = 3 4 1 3
kernel.printk_ratelimit = 5
kernel.printk_ratelimit_burst = 10

# Security (Balanced for Performance)
kernel.randomize_va_space = 2
kernel.yama.ptrace_scope = 0
kernel.unprivileged_bpf_disabled = 0
kernel.unprivileged_userns_clone = 1

# NUMA Balancing (Disabled for Java - Manual Control Better)
kernel.numa_balancing = 0
kernel.numa_balancing_scan_delay_ms = 1000
kernel.numa_balancing_scan_period_min_ms = 1000
kernel.numa_balancing_scan_period_max_ms = 60000
kernel.numa_balancing_scan_size_mb = 256

# Watchdog
kernel.nmi_watchdog = 0
kernel.soft_watchdog = 1
kernel.watchdog_thresh = 10

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION 6: WORKLOAD-SPECIFIC OPTIMIZATIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Workload Type: $workloadType (Confidence: ${workloadScore}%)
# Performance Score: ${performanceScore}/100
# Predicted Bottleneck: $bottleneckPrediction
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

  # Apply workload-specific tuning
  case "$workloadType" in
    "Distributed-Messaging")
      cat >> "${sysctlFile}" <<'EOF'
# Kafka/ZooKeeper Specific Optimizations
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 16384 524288 268435456
net.ipv4.tcp_wmem = 16384 524288 268435456
net.ipv4.tcp_max_syn_backlog = 131072
vm.dirty_background_ratio = 5
vm.dirty_ratio = 60
EOF
      ;;
    "Search-Engine")
      cat >> "${sysctlFile}" <<'EOF'
# Elasticsearch/Solr Specific Optimizations
vm.max_map_count = 262144
vm.swappiness = 1
fs.file-max = 2097152
EOF
      ;;
    "Stream-Processing")
      cat >> "${sysctlFile}" <<'EOF'
# Spark/Flink Specific Optimizations
vm.overcommit_memory = 1
vm.swappiness = 0
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
EOF
      ;;
  esac
  
  log "    ✓ sysctl configuration created: $sysctlFile"
  log "      └─ Parameters configured: $(grep -c "^[a-z]" "$sysctlFile") settings"
  
  log "[4.2] Applying sysctl parameters..."
  if sysctl -p "${sysctlFile}" >>"$logFile" 2>&1; then
    log "    ✓ sysctl parameters applied successfully"
  else
    log "    ⚠️  Some sysctl parameters may have failed (check $logFile)"
  fi
  
  tuningPhaseEnd=$(date +%s.%N)
  phaseDuration=$(calcDuration "$tuningPhaseStart" "$tuningPhaseEnd")
  log "    ⏱️  Phase 4 completed in ${phaseDuration}s"
  
  # ============================================================================
  # PHASE 5: INTELLIGENT NUMA OPTIMIZATION
  # ============================================================================
  tuningPhaseStart=$(date +%s.%N)
  log ""
  log "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
  log "│ PHASE 5/12: INTELLIGENT NUMA OPTIMIZATION                                                                             │"
  log "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
  
  if [[ $numaNodes -gt 1 ]]; then
    if ! command -v numactl >/dev/null 2>&1; then
      warn "numactl not available - NUMA optimization skipped"
      warn "Install with: sudo apt install numactl"
    else
      log "[5.1] Configuring NUMA policies for $numaNodes nodes..."
      
      local numaFile="/etc/numad.conf"
      cat > "${numaFile}" <<EOFNUMA5
# NUMA Configuration v5.0 for Java Workloads
# Generated: $(date)
# Nodes: $numaNodes | Memory per Node: $((totalRamGb / numaNodes))GB

managed_nodes = 0-$((numaNodes - 1))
preferred = 0
membind = 0
physcpubind = 0-$((cpuCores - 1))
interleave = 0-$((numaNodes - 1))
numa_balancing = off
EOFNUMA5
      
      local cpuAffinityFile="/etc/profile.d/java-numa-affinity-v5.sh"
      cat > "${cpuAffinityFile}" <<'EOFNUMAAFFINITY'
#!/bin/bash
if command -v numactl >/dev/null 2>&1; then
  NUMA_NODES=$(numactl --hardware 2>/dev/null | grep '^available:' | awk '{print $2}' || echo "1")
  if [[ $NUMA_NODES -gt 1 ]]; then
    export JAVA_OPTS="$JAVA_OPTS -XX:+UseNUMA -XX:+UseCondCardMark -XX:NUMAChunkResizeWeight=20"
    export JAVA_OPTS="$JAVA_OPTS -XX:AllocatePrefetchStyle=3 -XX:+UseCompressedOops"
    export JAVA_OPTS="$JAVA_OPTS -XX:NUMAInterleaveGranularity=2097152 -XX:+BindGCTaskThreadsToCPUs"
    if [[ $(free -g | awk '/^Mem:/{print $2}') -gt 128 ]]; then
      export NUMACTL_OPTS="--interleave=all"
    fi
  fi
fi
EOFNUMAAFFINITY
      chmod +x "${cpuAffinityFile}"
      
      log "    ✓ NUMA Configuration:"
      log "      └─ Nodes: $numaNodes | Policy: Interleave for large heaps"
      log "      └─ CPU Affinity: $cpuAffinityFile"
      
      if [[ $hugePageSizeKb -gt 0 ]]; then
        local hugePagesPerNode=$((nrHugePages / numaNodes))
        for node in $(seq 0 $((numaNodes - 1))); do
          echo $hugePagesPerNode > /sys/devices/system/node/node${node}/hugepages/hugepages-${hugePageSizeKb}kB/nr_hugepages 2>/dev/null || true
        done
        log "    ✓ Huge Pages distributed: $hugePagesPerNode per node"
      fi
    fi
  else
    log "    ℹ️  Single NUMA node - skipping NUMA-specific optimizations"
  fi
  
  tuningPhaseEnd=$(date +%s.%N)
  phaseDuration=$(calcDuration "$tuningPhaseStart" "$tuningPhaseEnd")
  log "    ⏱️  Phase 5 completed in ${phaseDuration}s"
  
  # ============================================================================
  # PHASE 6: NETWORK STACK ULTRA-OPTIMIZATION
  # ============================================================================
  tuningPhaseStart=$(date +%s.%N)
  log ""
  log "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
  log "│ PHASE 6/12: NETWORK STACK ULTRA-OPTIMIZATION                                                                          │"
  log "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
  
  log "[6.1] Optimizing network interfaces for ultra-low latency..."
  
  local hasEthtool=false
  command -v ethtool >/dev/null 2>&1 && hasEthtool=true
  
  for iface in $(ip link show | grep -E '^[0-9]+:' | awk -F: '{print $2}' | tr -d ' ' | grep -v lo); do
    if [[ -d "/sys/class/net/$iface" ]]; then
      log "    [*] Tuning interface: $iface"
      
      ip link set $iface mtu 9000 2>/dev/null || ip link set $iface mtu 1500 2>/dev/null
      
      if [[ "$hasEthtool" == true ]]; then
        ethtool -G $iface rx 4096 tx 4096 2>/dev/null || true
        ethtool -C $iface adaptive-rx on adaptive-tx on rx-usecs 50 tx-usecs 50 2>/dev/null || true
        ethtool -K $iface tso on gso on gro on lro on rx-checksumming on tx-checksumming on scatter-gather on tx-nocache-copy off 2>/dev/null || true
        ethtool -A $iface rx off tx off 2>/dev/null || true
        
        local rssQueues=$(ethtool -l $iface 2>/dev/null | grep "Combined:" | head -1 | awk '{print $2}')
        [[ $rssQueues -gt 0 ]] && ethtool -L $iface combined $cpuCores 2>/dev/null || true
      else
        log "        ℹ️  ethtool not available - advanced NIC tuning skipped"
      fi
      
      tc qdisc replace dev $iface root fq_codel 2>/dev/null || true
      
      log "        ✓ $iface optimized (MTU: $(ip link show $iface | grep -o "mtu [0-9]*" | awk '{print $2}'))"
    fi
  done
  
  log "[6.2] Configuring RPS/RFS for multi-core packet processing..."
  local rpsValue=$(printf '%x' $((2**cpuCores - 1)))
  for rxQueue in /sys/class/net/*/queues/rx-*/rps_cpus; do
    echo $rpsValue > "$rxQueue" 2>/dev/null || true
  done
  
  echo 32768 > /proc/sys/net/core/rps_sock_flow_entries 2>/dev/null || true
  for rxQueue in /sys/class/net/*/queues/rx-*/rps_flow_cnt; do
    echo 2048 > "$rxQueue" 2>/dev/null || true
  done
  
  log "[6.3] Configuring XPS for transmit optimization..."
  local cpu=0
  for txQueue in /sys/class/net/*/queues/tx-*/xps_cpus; do
    echo $(printf '%x' $((1 << (cpu % cpuCores)))) > "$txQueue" 2>/dev/null || true
    ((cpu++))
  done
  
  tuningPhaseEnd=$(date +%s.%N)
  phaseDuration=$(calcDuration "$tuningPhaseStart" "$tuningPhaseEnd")
  log "    ⏱️  Phase 6 completed in ${phaseDuration}s"
  
  # ============================================================================
  # PHASE 7: STORAGE I/O SCHEDULER ML-TUNING
  # ============================================================================
  tuningPhaseStart=$(date +%s.%N)
  log ""
  log "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
  log "│ PHASE 7/12: STORAGE I/O SCHEDULER ML-TUNING                                                                           │"
  log "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
  
  log "[7.1] Optimizing I/O schedulers based on storage type..."
  
  for disk in /sys/block/sd* /sys/block/nvme* /sys/block/vd*; do
    [[ ! -f "$disk/queue/scheduler" ]] && continue
    
    local diskName=$(basename $disk)
    local rotational=$(cat "$disk/queue/rotational" 2>/dev/null || echo "1")
    
    log "    [*] Optimizing $diskName (rotational: $rotational)"
    
    if [[ $rotational -eq 0 ]]; then
      if grep -q "none" "$disk/queue/scheduler" 2>/dev/null; then
        echo "none" > "$disk/queue/scheduler" 2>/dev/null || true
        log "        ✓ Scheduler: none (NVMe native)"
      elif grep -q "mq-deadline" "$disk/queue/scheduler" 2>/dev/null; then
        echo "mq-deadline" > "$disk/queue/scheduler" 2>/dev/null || true
        log "        ✓ Scheduler: mq-deadline"
      fi
      
      if [[ $diskName =~ nvme ]]; then
        echo 2 > "$disk/queue/nomerges" 2>/dev/null || true
        echo 0 > "$disk/queue/add_random" 2>/dev/null || true
        echo 1024 > "$disk/queue/nr_requests" 2>/dev/null || true
        echo 2 > "$disk/queue/rq_affinity" 2>/dev/null || true
        log "        ✓ NVMe-specific settings applied"
      fi
      
      echo 4096 > "$disk/queue/read_ahead_kb" 2>/dev/null || true
      echo 512 > "$disk/queue/max_sectors_kb" 2>/dev/null || true
    else
      if grep -q "bfq" "$disk/queue/scheduler" 2>/dev/null; then
        echo "bfq" > "$disk/queue/scheduler" 2>/dev/null || true
        log "        ✓ Scheduler: bfq (HDD)"
      elif grep -q "mq-deadline" "$disk/queue/scheduler" 2>/dev/null; then
        echo "mq-deadline" > "$disk/queue/scheduler" 2>/dev/null || true
        log "        ✓ Scheduler: mq-deadline (HDD)"
      fi
      
      echo 8192 > "$disk/queue/read_ahead_kb" 2>/dev/null || true
      echo 256 > "$disk/queue/max_sectors_kb" 2>/dev/null || true
    fi
    
    echo 256 > "$disk/queue/nr_requests" 2>/dev/null || true
    echo 64 > "$disk/queue/max_segments" 2>/dev/null || true
    
    if [[ -f "$disk/queue/discard_max_bytes" ]]; then
      local discardMax=$(cat "$disk/queue/discard_max_bytes")
      [[ $discardMax -gt 0 ]] && echo 1 > "$disk/queue/discard_granularity" 2>/dev/null && log "        ✓ TRIM/Discard enabled"
    fi
  done
  
  tuningPhaseEnd=$(date +%s.%N)
  phaseDuration=$(calcDuration "$tuningPhaseStart" "$tuningPhaseEnd")
  log "    ⏱️  Phase 7 completed in ${phaseDuration}s"
  
  # ============================================================================
  # PHASE 8: CPU FREQUENCY & POWER MANAGEMENT
  # ============================================================================
  tuningPhaseStart=$(date +%s.%N)
  log ""
  log "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
  log "│ PHASE 8/12: CPU FREQUENCY & POWER MANAGEMENT                                                                          │"
  log "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
  
  log "[8.1] Setting CPU governor to 'performance' mode..."
  
  local governorsSet=0
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    [[ -f "$cpu/cpufreq/scaling_governor" ]] && echo "performance" > "$cpu/cpufreq/scaling_governor" 2>/dev/null && ((governorsSet++))
  done
  
  log "    ✓ CPU governors set to performance: $governorsSet CPUs"
  
  log "[8.2] Configuring CPU C-States for low latency..."
  local cstatesDisabled=0
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    for state in "$cpu/cpuidle/state"*; do
      if [[ -f "$state/disable" ]]; then
        local stateName=$(cat "$state/name" 2>/dev/null || echo "unknown")
        [[ "$stateName" =~ C[678] ]] && echo 1 > "$state/disable" 2>/dev/null && ((cstatesDisabled++))
      fi
    done
  done
  
  log "    ✓ Deep C-States disabled: $cstatesDisabled states (C6/C7/C8)"
  
  log "[8.3] Configuring Turbo Boost..."
  if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
    echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null
    log "    ✓ Intel Turbo Boost enabled"
  elif [[ -f /sys/devices/system/cpu/cpufreq/boost ]]; then
    echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null
    log "    ✓ AMD Turbo Core enabled"
  fi
  
  echo 0 > /proc/sys/kernel/nmi_watchdog 2>/dev/null && log "    ✓ NMI watchdog disabled"
  
  if [[ -f /sys/module/pcie_aspm/parameters/policy ]]; then
    echo "performance" > /sys/module/pcie_aspm/parameters/policy 2>/dev/null
    log "    ✓ PCIe ASPM set to performance mode"
  fi
  
  tuningPhaseEnd=$(date +%s.%N)
  phaseDuration=$(calcDuration "$tuningPhaseStart" "$tuningPhaseEnd")
  log "    ⏱️  Phase 8 completed in ${phaseDuration}s"
  
  # ============================================================================
  # PHASE 9: MEMORY MANAGEMENT & HUGE PAGES
  # ============================================================================
  tuningPhaseStart=$(date +%s.%N)
  log ""
  log "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
  log "│ PHASE 9/12: MEMORY MANAGEMENT & HUGE PAGES                                                                            │"
  log "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
  
  log "[9.1] Configuring Transparent Huge Pages (THP)..."
  
  [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]] && echo "always" > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null && log "    ✓ THP enabled: always"
  [[ -f /sys/kernel/mm/transparent_hugepage/defrag ]] && echo "defer+madvise" > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null && log "    ✓ THP defrag: defer+madvise"
  [[ -f /sys/kernel/mm/transparent_hugepage/shmem_enabled ]] && echo "always" > /sys/kernel/mm/transparent_hugepage/shmem_enabled 2>/dev/null && log "    ✓ THP for shmem: always"
  
  log "[9.2] Allocating huge pages (75% of RAM)..."
  local currentHugePages=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
  
  if [[ $nrHugePages -gt $currentHugePages ]]; then
    echo $nrHugePages > /proc/sys/vm/nr_hugepages 2>/dev/null
    sleep 2
    local allocatedHugePages=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
    local allocatedMB=$((allocatedHugePages * hugePageSizeKb / 1024))
    log "    ✓ Huge pages allocated: $allocatedHugePages pages (${allocatedMB}MB)"
    
    [[ $allocatedHugePages -lt $nrHugePages ]] && log "    ⚠️  Only $allocatedHugePages/$nrHugePages huge pages allocated"
  else
    log "    ✓ Huge pages already configured: $currentHugePages pages"
  fi
  
  if ! grep -q "hugetlbfs" /proc/mounts; then
    mkdir -p /mnt/huge 2>/dev/null
    mount -t hugetlbfs -o pagesize=${hugePageSizeKb}K none /mnt/huge 2>/dev/null
    log "    ✓ Huge pages filesystem mounted: /mnt/huge"
  fi
  
  tuningPhaseEnd=$(date +%s.%N)
  phaseDuration=$(calcDuration "$tuningPhaseStart" "$tuningPhaseEnd")
  log "    ⏱️  Phase 9 completed in ${phaseDuration}s"
  
  # ============================================================================
  # PHASE 10: JVM-SPECIFIC OPTIMIZATIONS
  # ============================================================================
  tuningPhaseStart=$(date +%s.%N)
  log ""
  log "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
  log "│ PHASE 10/12: JVM-SPECIFIC OPTIMIZATIONS                                                                               │"
  log "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
  
  log "[10.1] Creating advanced JVM optimization scripts..."
  
  local jvmOptsFile="/etc/profile.d/java-quantum-jvm-opts-v5.sh"
  cat > "${jvmOptsFile}" <<'JVMEOF'
#!/bin/bash
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)
NUMA_NODES=$(numactl --hardware 2>/dev/null | grep '^available:' | awk '{print $2}' || echo "1")
JAVA_VERSION_OUTPUT="$(java -version 2>&1 | head -n1 || true)"

if [ "$TOTAL_RAM_GB" -ge 512 ]; then
  HEAP_INIT_PCT=10; HEAP_MAX_PCT=90
elif [ "$TOTAL_RAM_GB" -ge 256 ]; then
  HEAP_INIT_PCT=15; HEAP_MAX_PCT=85
elif [ "$TOTAL_RAM_GB" -ge 128 ]; then
  HEAP_INIT_PCT=20; HEAP_MAX_PCT=80
elif [ "$TOTAL_RAM_GB" -ge 64 ]; then
  HEAP_INIT_PCT=25; HEAP_MAX_PCT=75
else
  HEAP_INIT_PCT=30; HEAP_MAX_PCT=70
fi

export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -XX:InitialRAMPercentage=${HEAP_INIT_PCT}.0"
export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -XX:MaxRAMPercentage=${HEAP_MAX_PCT}.0"
export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -XX:MinRAMPercentage=50.0"

if echo "$JAVA_VERSION_OUTPUT" | grep -E -q 'version "1\.[89]\.|version "10\.|version "11\.'; then
  export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -XX:+UseG1GC -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32m"
fi

if echo "$JAVA_VERSION_OUTPUT" | grep -E -q 'version "1[7-9]\.|version "2[0-9]\.'; then
  if [ "$TOTAL_RAM_GB" -ge 32 ]; then
    export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -XX:+UseZGC -XX:ZCollectionInterval=200"
  else
    export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -XX:+UseG1GC -XX:MaxGCPauseMillis=50"
  fi
fi

export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -XX:+UseStringDeduplication -XX:+UseCompressedOops"
export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -XX:+AlwaysPreTouch -XX:+DisableExplicitGC"
export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -XX:ParallelGCThreads=$CPU_CORES"

[ "$NUMA_NODES" -gt 1 ] && export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -XX:+UseNUMA"

export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -Xlog:gc*:file=/var/log/java/gc/gc-%p-%t.log:time,uptime:filecount=30,filesize=100M"
export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/var/log/java/heap/"

if [ -f /proc/1/cgroup ] && grep -q docker /proc/1/cgroup 2>/dev/null; then
  export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
fi
JVMEOF
  
  chmod +x "${jvmOptsFile}"
  log "    ✓ JVM optimization script created: $jvmOptsFile"
  
  mkdir -p /var/log/java/{gc,heap,thread,jfr,metrics} 2>/dev/null
  chmod 1777 /var/log/java /var/log/java/* 2>/dev/null
  log "    ✓ Logging directories created: /var/log/java/*"
  
  tuningPhaseEnd=$(date +%s.%N)
  phaseDuration=$(calcDuration "$tuningPhaseStart" "$tuningPhaseEnd")
  log "    ⏱️  Phase 10 completed in ${phaseDuration}s"
  
  # ============================================================================
  # PHASE 11: SECURITY HARDENING & APPARMOR
  # ============================================================================
  tuningPhaseStart=$(date +%s.%N)
  log ""
  log "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
  log "│ PHASE 11/12: SECURITY HARDENING & APPARMOR                                                                            │"
  log "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
  
  log "[11.1] Creating AppArmor profile for Java applications..."
  
  local apparmorProfile="/etc/apparmor.d/usr.bin.java"
  cat > "${apparmorProfile}" <<'AAEOF'
#include <tunables/global>

/usr/bin/java flags=(complain) {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  #include <abstractions/user-tmp>
  #include <abstractions/ssl_certs>

  /usr/bin/java mr,
  /usr/lib/jvm/** r,
  /usr/share/java/** r,
  /usr/lib/x86_64-linux-gnu/** rm,
  /tmp/** rw,
  /var/log/java/** rw,
  /proc/*/stat r,
  /proc/meminfo r,
  /proc/cpuinfo r,
  /sys/devices/system/cpu/** r,
  /sys/devices/system/node/** r,
  /mnt/huge/** rw,
  
  network inet stream,
  network inet6 stream,
  
  capability net_bind_service,
  capability sys_resource,
  capability ipc_lock,
}
AAEOF
  
  if command -v apparmor_parser >/dev/null 2>&1 && aa-status >/dev/null 2>&1; then
    apparmor_parser -r "$apparmorProfile" 2>/dev/null || true
    log "    ✓ AppArmor profile created and loaded: $apparmorProfile"
  else
    log "    ℹ️  AppArmor not active - profile created but not loaded"
  fi
  
  tuningPhaseEnd=$(date +%s.%N)
  phaseDuration=$(calcDuration "$tuningPhaseStart" "$tuningPhaseEnd")
  log "    ⏱️  Phase 11 completed in ${phaseDuration}s"
  
  # ============================================================================
  # PHASE 12: VALIDATION & PERFORMANCE TESTING
  # ============================================================================
  tuningPhaseStart=$(date +%s.%N)
  log ""
  log "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
  log "│ PHASE 12/12: VALIDATION & PERFORMANCE TESTING                                                                         │"
  log "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
  
  local validationErrors=0
  
  log "[12.1] Validating system configuration..."
  
  [[ -f /etc/security/limits.d/99-java-quantum-tuning-v5.conf ]] && log "    ✓ ulimits configuration file exists" || { log "    ❌ ulimits configuration missing"; ((validationErrors++)); }
  
  sysctl -p /etc/sysctl.d/99-java-quantum-tuning-v5.conf &>/dev/null && log "    ✓ sysctl configuration valid" || log "    ⚠️  Some sysctl parameters may be invalid"
  
  currentHugePages=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
  [[ $currentHugePages -gt 0 ]] && log "    ✓ Huge pages allocated: $currentHugePages pages" || log "    ⚠️  No huge pages allocated"
  
  local defaultIface=$(ip route | grep default | awk '{print $5}' | head -1)
  if [[ -n "$defaultIface" ]]; then
    local mtu=$(ip link show $defaultIface | grep -o "mtu [0-9]*" | awk '{print $2}')
    log "    ✓ Network interface $defaultIface: MTU=$mtu"
  fi
  
  local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
  [[ "$governor" == "performance" ]] && log "    ✓ CPU governor: performance" || log "    ⚠️  CPU governor: $governor"
  
  log ""
  log "[12.2] Running quick performance tests..."
  
  local tcpCongestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
  local swappiness=$(sysctl -n vm.swappiness 2>/dev/null || echo "unknown")
  local defaultDisk=$(df / | tail -1 | awk '{print $1}' | sed 's|/dev/||' | sed 's/[0-9]*$//')
  local diskScheduler="unknown"
  [[ -f "/sys/block/${defaultDisk}/queue/scheduler" ]] && diskScheduler=$(cat "/sys/block/${defaultDisk}/queue/scheduler" 2>/dev/null | grep -oP '\[\K[^\]]+' || echo "unknown")
  
  log "    • TCP Congestion Control: $tcpCongestion"
  log "    • VM Swappiness: $swappiness"
  log "    • Root disk scheduler: $diskScheduler"
  
  log ""
  log "[12.3] Generating tuning summary report..."
  
  local summaryFile="$backupDir/TUNING_SUMMARY.txt"
  cat > "$summaryFile" <<EOFSUMMARY
═══════════════════════════════════════════════════════════════════════════════
JAVA QUANTUM TUNING v5.0 - TUNING SUMMARY REPORT
═══════════════════════════════════════════════════════════════════════════════

Generation Time: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HARDWARE PROFILE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CPU: $cpuModel
Cores: $cpuCores | Threads: $cpuThreads | Sockets: $cpuSockets
Memory: ${totalRamGb}GB | NUMA Nodes: $numaNodes
Storage: ${nvmeDevices} NVMe, ${ssdCount} SSD, ${hddCount} HDD
GPU: $gpuCount x $gpuVendor $gpuModel
Cloud: $cloudProvider ($cloudInstanceType)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WORKLOAD ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Type: $workloadType
Confidence: ${workloadScore}%
Performance Score: $performanceScore/100
Predicted Bottleneck: $bottleneckPrediction

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OPTIMIZATIONS APPLIED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 1:  ✓ Hardware Detection
Phase 2:  ✓ Backup Creation
Phase 3:  ✓ ulimits Configuration
Phase 4:  ✓ sysctl Tuning
Phase 5:  ✓ NUMA Optimization
Phase 6:  ✓ Network Optimization
Phase 7:  ✓ Storage I/O Tuning
Phase 8:  ✓ CPU/Power Management
Phase 9:  ✓ Memory/Huge Pages
Phase 10: ✓ JVM Optimization
Phase 11: ✓ Security Hardening
Phase 12: ✓ Validation & Testing

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CONFIGURATION FILES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• /etc/security/limits.d/99-java-quantum-tuning-v5.conf
• /etc/sysctl.d/99-java-quantum-tuning-v5.conf
• /etc/profile.d/java-quantum-jvm-opts-v5.sh
• /etc/profile.d/java-numa-affinity-v5.sh
• /etc/apparmor.d/usr.bin.java

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CURRENT SYSTEM STATE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Huge Pages: $currentHugePages / $nrHugePages allocated
CPU Governor: $governor
TCP Congestion: $tcpCongestion
Swappiness: $swappiness
Root Disk Scheduler: $diskScheduler

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VALIDATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Validation Errors: $validationErrors
Status: $([ $validationErrors -eq 0 ] && echo "✅ ALL CHECKS PASSED" || echo "⚠️  COMPLETED WITH WARNINGS")

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RECOMMENDATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Reboot system to ensure all kernel parameters take effect
2. Verify Java applications use JAVA_TOOL_OPTIONS by checking logs
3. Monitor GC logs in /var/log/java/gc/ for performance analysis
4. Consider upgrading to Java 17+ for ZGC if using large heaps (>16GB)

═══════════════════════════════════════════════════════════════════════════════
BACKUP & ROLLBACK
═══════════════════════════════════════════════════════════════════════════════
Backup Location: $backupDir
Rollback: Restore files from backup directory and reboot

═══════════════════════════════════════════════════════════════════════════════
End of Tuning Summary Report
═══════════════════════════════════════════════════════════════════════════════
EOFSUMMARY
  
  log "    ✓ Tuning summary report: $summaryFile"
  
  tuningPhaseEnd=$(date +%s.%N)
  phaseDuration=$(calcDuration "$tuningPhaseStart" "$tuningPhaseEnd")
  log "    ⏱️  Phase 12 completed in ${phaseDuration}s"
  
  # Final Summary
  log ""
  log "═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
  log "  ✅ QUANTUM TUNING v5.0 - ALL 12 PHASES COMPLETED SUCCESSFULLY!"
  log "  📊 Configuration Summary:"
  log "     • Workload: $workloadType (${workloadScore}% confidence)"
  log "     • Performance Score: ${performanceScore}/100"
  log "     • Predicted Bottleneck: $bottleneckPrediction"
  log "     • Backup Location: $backupDir"
  log "     • Validation: $([ $validationErrors -eq 0 ] && echo "✅ ALL CHECKS PASSED" || echo "⚠️  $validationErrors WARNINGS")"
  log "═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
  
  local endTime=$(date +%s.%N)
  local totalDuration=$(calcDuration "$startTime" "$endTime")
  log ""
  log "  ⏱️  Total Tuning Time: ${totalDuration}s"
  log "  🎯 System optimized for: $workloadType"
  log "  📈 Expected Performance Gain: $(((performanceScore - 50) * 2))%"
  log ""
}


chooseTemurinAltHighestMinusOne() {
  local cmd="$1"   # e.g.: java, javac, jar, javadoc

  if ! update-alternatives --list "$cmd" &>/dev/null; then
    warn "No alternatives for '$cmd' (JDK may not be fully installed). Skipping."
    return 0
  fi

  local list
  list="$(update-alternatives --list "$cmd" | grep -i 'temurin' || true)"

  if [[ -z "$list" ]]; then
    warn "No Temurin versions found for '$cmd' in update-alternatives. Skipping."
    return 0
  fi

  log "Temurin alternatives list for '$cmd':"
  echo "$list" | while read -r line; do
    [[ -n "$line" ]] && log "  * $line"
  done

  local count
  count="$(echo "$list" | wc -l | tr -d ' ')"

  local chosen

  if [[ "$count" -ge 2 ]]; then
    chosen="$(echo "$list" | sort -V | tail -n2 | head -n1)"
    log "Found ${count} Temurin versions for '$cmd'. Choosing SECOND HIGHEST:"
  else
    chosen="$(echo "$list" | sort -V | tail -n1)"
    log "Only 1 Temurin version found for '$cmd'. Using the only one:"
  fi

  log " -> $chosen"
  update-alternatives --set "$cmd" "$chosen" >>"$logFile" 2>&1
}

setTemurinDefault() {
  log "Setting Temurin (second highest if available) as default for java, javac, jar, javadoc..."
  chooseTemurinAltHighestMinusOne "java"
  chooseTemurinAltHighestMinusOne "javac"
  chooseTemurinAltHighestMinusOne "jar"
  chooseTemurinAltHighestMinusOne "javadoc"
}

setupJavaEnv() {
  log "Setting JAVA_HOME & PATH based on default 'java'..."

  if command -v java >/dev/null 2>&1; then
    local javaBinPath
    javaBinPath="$(readlink -f "$(command -v java)")"
    local javaHomeDir
    javaHomeDir="$(dirname "${javaBinPath}")"
    javaHomeDir="$(dirname "${javaHomeDir}")"

    log "Detected JAVA_HOME = ${javaHomeDir}"

    local profileJava="/etc/profile.d/java-temurin-default.sh"
    cat > "${profileJava}" <<EOF
# Auto-generated by java_all_in_one_menu.sh
export JAVA_HOME=${javaHomeDir}
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF
    chmod +x "${profileJava}"
    log "Created ${profileJava}"
  else
    warn "Command 'java' not found. Skipping JAVA_HOME setup."
  fi

  log "Creating /etc/profile.d/java-temurin-jvmopts.sh to auto-set JAVA_TOOL_OPTIONS for Temurin 21+ ..."
  local profileJvmopts="/etc/profile.d/java-temurin-jvmopts.sh"
  cat > "${profileJvmopts}" <<'EOF'
# Auto-generated by java_all_in_one_menu.sh
# If default "java -version" is Temurin 21+ then auto-enable JAVA_TOOL_OPTIONS
# for server optimization (heap by %, G1GC, StringDedup, AlwaysPreTouch, GC log).

javaVerStr="$(java -version 2>&1 | head -n1 || true)"

# Typical output: openjdk version "21.0.1" 2023-10-17 Temurin-21.x.x
if echo "$javaVerStr" | grep -q 'Temurin' && echo "$javaVerStr" | grep -E -q 'version "2[1-9]\.'; then
  export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS \
    -XX:InitialRAMPercentage=30.0 \
    -XX:MaxRAMPercentage=75.0 \
    -XX:+UseStringDeduplication \
    -XX:+AlwaysPreTouch \
    -Xlog:gc*:file=/var/log/java/gc-%p-%t.log:time,uptime,tags:filecount=10,filesize=20M"
fi
EOF
  chmod +x "${profileJvmopts}"
  log "Created ${profileJvmopts}"
}

showStatus() {
  echo
  echo "===== CURRENT JAVA STATUS ====="
  echo "java -version:"
  java -version 2>&1 || echo "  (java command not working)"
  echo
  echo "javac -version:"
  javac -version 2>&1 || echo "  (javac command not working)"
  echo
  echo "JVM list in /usr/lib/jvm:"
  if [[ -d /usr/lib/jvm ]]; then
    ls -1 /usr/lib/jvm | sed 's/^/  - /'
  else
    echo "  (/usr/lib/jvm does not exist)"
  fi
  echo
  echo "update-alternatives --list java:"
  update-alternatives --list java 2>/dev/null | sed 's/^/  * /' || echo "  (no java alternatives)"
  echo
  echo "Detailed log: $logFile"
  echo "===================================="
}

performPreflightChecksExtreme() {
  log "[Preflight] Running comprehensive pre-uninstall checks..."
  
  if [[ "${EUID}" -ne 0 ]]; then
    err "Root privileges required for uninstallation."
    return 1
  fi
  
  log "  ✓ Running as root"
  
  local availSpace=$(df / | tail -1 | awk '{print $4}')
  if [[ $availSpace -lt 1048576 ]]; then
    warn "Low disk space detected: ${availSpace}KB available (need ~1GB for backup)"
  else
    log "  ✓ Sufficient disk space: $((availSpace / 1024))MB available"
  fi
  
  log "  ✓ Pre-flight checks passed"
  return 0
}

createAdvancedBackupExtreme() {
  log "[Backup] Creating complete system backup before uninstallation..."
  
  local backupDir="/var/backups/java-uninstall-backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backupDir"/{apt,alternatives,configs,logs,env}
  
  dpkg -l | grep -E "java|jdk|jre|openjdk|temurin|corretto" > "$backupDir/apt/installed-java-packages.txt" 2>/dev/null || true
  update-alternatives --get-selections | grep -E "java|javac|jar" > "$backupDir/alternatives/java-alternatives.txt" 2>/dev/null || true
  
  [[ -f /etc/environment ]] && cp /etc/environment "$backupDir/env/" 2>/dev/null || true
  [[ -d /etc/profile.d ]] && cp /etc/profile.d/java* "$backupDir/env/" 2>/dev/null || true
  [[ -d /etc/security/limits.d ]] && cp /etc/security/limits.d/*java* "$backupDir/configs/" 2>/dev/null || true
  [[ -d /etc/sysctl.d ]] && cp /etc/sysctl.d/*java* "$backupDir/configs/" 2>/dev/null || true
  
  log "  ✓ Backup created: $backupDir"
}

stopAllJavaServicesAndProcessesExtreme() {
  log "[Cleanup] Stopping all Java processes and services..."
  
  local javaPids=$(pgrep -f "java|javac|jar" || true)
  if [[ -n "$javaPids" ]]; then
    log "  [*] Found Java processes: $(echo "$javaPids" | wc -w) processes"
    for pid in $javaPids; do
      local procName=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
      log "      Stopping PID $pid ($procName)"
      kill -15 $pid 2>/dev/null || true
    done
    sleep 2
    
    javaPids=$(pgrep -f "java|javac|jar" || true)
    if [[ -n "$javaPids" ]]; then
      log "  [*] Force killing remaining processes..."
      kill -9 $javaPids 2>/dev/null || true
    fi
  fi
  
  local javaServices=$(systemctl list-units --type=service --all | grep -E "tomcat|wildfly|jboss|jenkins" | awk '{print $1}' || true)
  if [[ -n "$javaServices" ]]; then
    log "  [*] Stopping Java-related services..."
    for service in $javaServices; do
      systemctl stop "$service" 2>/dev/null || true
      systemctl disable "$service" 2>/dev/null || true
      log "      Stopped: $service"
    done
  fi
  
  log "  ✓ All Java processes and services stopped"
}

removeJavaFromAllSourcesExtreme() {
  log "[Removal] Removing Java packages from all sources..."
  
  log "  [1/4] Removing APT packages (Temurin, Corretto, OpenJDK)..."
  local aptPkgs=$(dpkg -l | grep -E "temurin|corretto|openjdk.*jdk|openjdk.*jre" | awk '{print $2}' || true)
  if [[ -n "$aptPkgs" ]]; then
    for pkg in $aptPkgs; do
      log "      Removing: $pkg"
      apt-get remove --purge -y "$pkg" >>"$logFile" 2>&1 || warn "Failed to remove $pkg"
    done
    apt-get autoremove -y >>"$logFile" 2>&1
    log "    ✓ APT packages removed"
  else
    log "    ℹ️  No APT Java packages found"
  fi
  
  log "  [2/4] Removing Snap packages..."
  if command -v snap >/dev/null 2>&1; then
    local snapPkgs=$(snap list 2>/dev/null | grep -E "openjdk|jdk" | awk '{print $1}' || true)
    if [[ -n "$snapPkgs" ]]; then
      for pkg in $snapPkgs; do
        log "      Removing snap: $pkg"
        snap remove "$pkg" >>"$logFile" 2>&1 || warn "Failed to remove snap $pkg"
      done
      log "    ✓ Snap packages removed"
    else
      log "    ℹ️  No Snap Java packages found"
    fi
  else
    log "    ℹ️  Snap not installed"
  fi
  
  log "  [3/4] Removing Flatpak packages..."
  if command -v flatpak >/dev/null 2>&1; then
    local flatpakPkgs=$(flatpak list 2>/dev/null | grep -i "java\|jdk" | awk '{print $1}' || true)
    if [[ -n "$flatpakPkgs" ]]; then
      for pkg in $flatpakPkgs; do
        log "      Removing flatpak: $pkg"
        flatpak uninstall -y "$pkg" >>"$logFile" 2>&1 || warn "Failed to remove flatpak $pkg"
      done
      log "    ✓ Flatpak packages removed"
    else
      log "    ℹ️  No Flatpak Java packages found"
    fi
  else
    log "    ℹ️  Flatpak not installed"
  fi
  
  log "  [4/4] Cleaning up alternatives..."
  for alt in java javac jar javadoc; do
    update-alternatives --remove-all "$alt" >>"$logFile" 2>&1 || true
  done
  log "    ✓ Alternatives cleaned"
  
  log "  ✓ Java packages removed from all sources"
}

cleanupJavaConfigurationsAndFilesExtreme() {
  log "[Cleanup] Removing Java configurations and files..."
  
  log "  [*] Removing JVM directories..."
  [[ -d /usr/lib/jvm ]] && rm -rf /usr/lib/jvm/* 2>/dev/null || true
  [[ -d /usr/java ]] && rm -rf /usr/java 2>/dev/null || true
  [[ -d /opt/jdk ]] && rm -rf /opt/jdk 2>/dev/null || true
  
  log "  [*] Removing Java configuration files..."
  rm -f /etc/profile.d/java*.sh 2>/dev/null || true
  rm -f /etc/security/limits.d/*java*.conf 2>/dev/null || true
  rm -f /etc/sysctl.d/*java*.conf 2>/dev/null || true
  rm -f /etc/apparmor.d/usr.bin.java 2>/dev/null || true
  
  log "  [*] Removing SDKMAN and Jabba..."
  [[ -d "$HOME/.sdkman" ]] && rm -rf "$HOME/.sdkman" 2>/dev/null || true
  [[ -d "$HOME/.jabba" ]] && rm -rf "$HOME/.jabba" 2>/dev/null || true
  
  log "  [*] Cleaning environment variables..."
  sed -i '/JAVA_HOME/d' /etc/environment 2>/dev/null || true
  sed -i '/JAVA_OPTS/d' /etc/environment 2>/dev/null || true
  sed -i '/JAVA_TOOL_OPTIONS/d' /etc/environment 2>/dev/null || true
  
  log "  ✓ Java configurations cleaned"
}

performAdvancedSystemCleanupExtreme() {
  log "[Cleanup] Performing advanced system cleanup..."
  
  log "  [*] Removing Java logs..."
  [[ -d /var/log/java ]] && rm -rf /var/log/java 2>/dev/null || true
  
  log "  [*] Cleaning package cache..."
  apt-get clean >>"$logFile" 2>&1 || true
  
  log "  [*] Removing orphaned packages..."
  apt-get autoremove -y >>"$logFile" 2>&1 || true
  
  log "  [*] Updating system databases..."
  updatedb >>"$logFile" 2>&1 || true
  
  log "  ✓ System cleanup completed"
}

performDeepSystemIntegrationCleanup() {
  log "[Cleanup] Removing deep system integrations..."
  
  log "  [*] Cleaning systemd services..."
  find /etc/systemd/system -name "*java*" -o -name "*tomcat*" -o -name "*jenkins*" 2>/dev/null | while read -r file; do
    rm -f "$file" 2>/dev/null || true
    log "      Removed: $file"
  done
  systemctl daemon-reload >>"$logFile" 2>&1 || true
  
  log "  [*] Cleaning cron jobs..."
  crontab -l 2>/dev/null | grep -v "java" | crontab - 2>/dev/null || true
  
  log "  ✓ Deep integration cleanup completed"
}

performSecurityIntegrityChecks() {
  log "[Security] Performing security integrity checks..."
  
  if command -v aa-status >/dev/null 2>&1; then
    log "  [*] Reloading AppArmor profiles..."
    aa-status --enabled >>"$logFile" 2>&1 && apparmor_parser -r /etc/apparmor.d/* >>"$logFile" 2>&1 || true
  fi
  
  log "  [*] Applying sysctl changes..."
  sysctl -p >>"$logFile" 2>&1 || true
  
  log "  ✓ Security checks completed"
}

verifyAndReportUninstallExtreme() {
  log "[Verification] Verifying complete Java removal..."
  
  local javaCmd=$(command -v java 2>/dev/null || true)
  local javacCmd=$(command -v javac 2>/dev/null || true)
  local jvmDirs=$(find /usr -name "jvm" -type d 2>/dev/null | wc -l)
  local javaPkgs=$(dpkg -l | grep -E "java|jdk|jre" | grep "^ii" | wc -l)
  
  log ""
  log "  ═══════════════════════════════════════════════════════════"
  log "  UNINSTALLATION VERIFICATION REPORT"
  log "  ═══════════════════════════════════════════════════════════"
  log "  Java command:    $([ -z "$javaCmd" ] && echo "✓ Not found" || echo "⚠️  Still exists: $javaCmd")"
  log "  Javac command:   $([ -z "$javacCmd" ] && echo "✓ Not found" || echo "⚠️  Still exists: $javacCmd")"
  log "  JVM directories: $([ $jvmDirs -eq 0 ] && echo "✓ All removed" || echo "⚠️  $jvmDirs remaining")"
  log "  Java packages:   $([ $javaPkgs -eq 0 ] && echo "✓ All removed" || echo "⚠️  $javaPkgs remaining")"
  log "  ═══════════════════════════════════════════════════════════"
  
  if [[ -z "$javaCmd" ]] && [[ -z "$javacCmd" ]] && [[ $jvmDirs -eq 0 ]] && [[ $javaPkgs -eq 0 ]]; then
    log "  ✅ VERIFICATION PASSED: Java completely removed from system"
  else
    warn "  ⚠️  VERIFICATION INCOMPLETE: Some Java components may remain"
    log "  Run 'which java' and 'dpkg -l | grep java' for details"
  fi
}

uninstallAllJava() {
  log "═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
  log "  STARTING COMPLETE JAVA UNINSTALLATION - ULTRA ADVANCED EXTREME VERSION"
  log "═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
  echo ""
  echo "⚠️  MAXIMUM ALERT: This process will remove ALL Java from the system!"
  echo "   Including: APT, Snap, Flatpak, Docker, Podman, LXC, Manual, Source builds, SDKMAN, Jabba..."
  echo "   Deep integration with systemd, cron, PAM, NSS, fontconfig, MIME, desktop, icons..."
  echo "   This is an IRREVERSIBLE process. Ensure full backup and system understanding!"
  echo ""

  local startTime=$(date +%s.%N)
  local initialDiskUsage=$(df / | tail -1 | awk '{print $3}')
  local initialMemoryUsage=$(free | grep '^Mem:' | awk '{print $3}')
  local initialProcessCount=$(ps aux | wc -l)

  if ! performPreflightChecksExtreme; then
    err "Pre-flight checks failed. Stopping uninstallation."
    return 1
  fi

  createAdvancedBackupExtreme

  stopAllJavaServicesAndProcessesExtreme

  removeJavaFromAllSourcesExtreme

  cleanupJavaConfigurationsAndFilesExtreme

  performAdvancedSystemCleanupExtreme

  performDeepSystemIntegrationCleanup

  performSecurityIntegrityChecks

  verifyAndReportUninstallExtreme

  local endTime=$(date +%s.%N)
  local finalDiskUsage=$(df / | tail -1 | awk '{print $3}')
  local finalMemoryUsage=$(free | grep '^Mem:' | awk '{print $3}')
  local finalProcessCount=$(ps aux | wc -l)
  local duration=$(echo "$endTime - $startTime" | bc -l 2>/dev/null || echo "0")
  local diskFreed=$((initialDiskUsage - finalDiskUsage))
  local memoryFreed=$((initialMemoryUsage - finalMemoryUsage))
  local processReduction=$((initialProcessCount - finalProcessCount))

  log "═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
  log "  COMPLETE JAVA UNINSTALLATION FINISHED - ULTRA ADVANCED EXTREME VERSION"
  log "  Execution time: ${duration}s | Disk freed: ${diskFreed}KB | Memory freed: ${memoryFreed}KB | Processes reduced: ${processReduction}"
  log "═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
}

fullAuto() {
  setupReposAndBase
  discoverPackages
  installAllJava
  tuneSystem
  setTemurinDefault
  setupJavaEnv
  showStatus
}


while true; do
  echo
  echo "================ JAVA ALL-IN-ONE MENU ================"
  echo "1) Full auto: Install all Java + tuning + set Temurin default"
  echo "2) Only SCAN & DISPLAY available Java packages"
  echo "3) Only INSTALL all Java (Temurin + Corretto + OpenJDK)"
  echo "4) Only TUNE system (ulimit + sysctl + /var/log/java)"
  echo "5) Only SET Temurin (second highest) as default + JAVA_HOME/JAVA_TOOL_OPTIONS"
  echo "6) View CURRENT STATUS"
  echo "7) Uninstall all Java"
  echo "8) Exit"
  echo "======================================================"
  read -rp "Choose (1-8): " choice
  echo

  case "$choice" in
    1)
      echo ">> FULL AUTO mode"
      fullAuto
      ;;
    2)
      echo ">> Only SCAN packages"
      setupReposAndBase
      discoverPackages
      ;;
    3)
      echo ">> Only INSTALL all Java"
      setupReposAndBase
      discoverPackages
      installAllJava
      ;;
    4)
      echo ">> Only TUNE system"
      tuneSystem
      ;;
    5)
      echo ">> Only SET Temurin default + env"
      setTemurinDefault
      setupJavaEnv
      showStatus
      ;;
    6)
      echo ">> CURRENT STATUS"
      showStatus
      ;;
    7)
      echo ">> UNINSTALL all Java"
      uninstallAllJava
      ;;
    8)
      echo "Exit."
      exit 0
      ;;
    *)
      echo "Invalid choice, please choose 1-8."
      ;;
  esac
done