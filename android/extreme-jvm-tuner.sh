#!/bin/bash

################################################################################
# Extreme JVM Performance Tuner for Android Studio
# Advanced GC algorithms, profiling, and JIT optimizations
################################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)
CPU_THREADS=$(nproc --all)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  EXTREME JVM PERFORMANCE TUNER"
echo "  Advanced Garbage Collection & JIT Optimization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Detect Java version
JAVA_VERSION=""
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
    if [[ "$JAVA_VERSION" == "1" ]]; then
        JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f2)
    fi
    log_info "Detected Java version: $JAVA_VERSION"
else
    log_warning "Java not found, will generate generic configs"
fi

# ============================================================================
# ZGC CONFIGURATION (Java 15+)
# ============================================================================
generate_zgc_config() {
    log_info "Generating ZGC (Z Garbage Collector) configuration..."
    
    local xmx=$((RAM_MB / 4))
    [[ $xmx -lt 4096 ]] && xmx=4096
    
    cat > "${HOME}/.local/share/Google/AndroidStudio/studio-zgc.vmoptions" << EOF
# Android Studio with ZGC - Ultra Low Latency
# Java 15+ required

# Memory Settings
-Xms$((xmx / 2))m
-Xmx${xmx}m
-XX:ReservedCodeCacheSize=1024m
-XX:+UseCompressedOops
-XX:+UseCompressedClassPointers

# ZGC Garbage Collector - Lowest Latency
-XX:+UseZGC
-XX:+ZGenerational
-XX:ZCollectionInterval=5
-XX:ZAllocationSpikeTolerance=5
-XX:ConcGCThreads=$((CPU_CORES / 4 > 0 ? CPU_CORES / 4 : 1))
-XX:ParallelGCThreads=$((CPU_CORES / 2 > 0 ? CPU_CORES / 2 : 2))

# JIT Compiler Optimizations
-XX:+TieredCompilation
-XX:TieredStopAtLevel=4
-XX:CICompilerCount=$((CPU_CORES > 4 ? 4 : CPU_CORES))
-XX:CompileThreshold=1000
-XX:+UseInlineCaches
-XX:+UseFastAccessorMethods
-XX:+UseFastEmptyMethods
-XX:+OptimizeStringConcat
-XX:+UseStringDeduplication

# Advanced Optimizations
-XX:+AlwaysPreTouch
-XX:+UseNUMA
-XX:+AggressiveOpts
-XX:AutoBoxCacheMax=20000
-XX:BiasedLockingStartupDelay=0

# Code Cache
-XX:InitialCodeCacheSize=512m
-XX:ReservedCodeCacheSize=1024m
-XX:NonNMethodCodeHeapSize=128m
-XX:ProfiledCodeHeapSize=512m
-XX:NonProfiledCodeHeapSize=384m

# Metaspace
-XX:MetaspaceSize=512m
-XX:MaxMetaspaceSize=2048m

# Performance
-XX:SoftRefLRUPolicyMSPerMB=50
-XX:+UnlockExperimentalVMOptions
-XX:+UnlockDiagnosticVMOptions

# Monitoring
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=${HOME}/android-studio-oom-zgc.hprof
-XX:ErrorFile=${HOME}/android-studio-error-zgc.log

# System Properties
-Dfile.encoding=UTF-8
-Dsun.io.useCanonCaches=false
-Djava.net.preferIPv4Stack=true

# IDE Optimizations
-Didea.max.intellisense.filesize=10000
-Didea.cycle.buffer.size=disabled
-Didea.ProcessCanceledException=disabled
-Dawt.useSystemAAFontSettings=lcd
-Dswing.aatext=true

# Disable unnecessary features
-Djdk.attach.allowAttachSelf=true
-Djdk.module.illegalAccess.silent=true
EOF

    log_success "ZGC configuration created: studio-zgc.vmoptions"
}

# ============================================================================
# SHENANDOAH GC CONFIGURATION (Java 12+)
# ============================================================================
generate_shenandoah_config() {
    log_info "Generating Shenandoah GC configuration..."
    
    local xmx=$((RAM_MB / 4))
    [[ $xmx -lt 4096 ]] && xmx=4096
    
    cat > "${HOME}/.local/share/Google/AndroidStudio/studio-shenandoah.vmoptions" << EOF
# Android Studio with Shenandoah GC - Low Pause Time
# OpenJDK required (not available in Oracle JDK)

# Memory Settings
-Xms$((xmx / 2))m
-Xmx${xmx}m
-XX:ReservedCodeCacheSize=1024m
-XX:+UseCompressedOops
-XX:+UseCompressedClassPointers

# Shenandoah Garbage Collector
-XX:+UseShenandoahGC
-XX:ShenandoahGCMode=iu
-XX:ShenandoahGuaranteedGCInterval=20000
-XX:ShenandoahUncommitDelay=60000
-XX:ConcGCThreads=$((CPU_CORES / 4 > 0 ? CPU_CORES / 4 : 1))
-XX:ParallelGCThreads=$((CPU_CORES / 2 > 0 ? CPU_CORES / 2 : 2))

# JIT Compiler Optimizations
-XX:+TieredCompilation
-XX:TieredStopAtLevel=4
-XX:CICompilerCount=$((CPU_CORES > 4 ? 4 : CPU_CORES))
-XX:CompileThreshold=1000
-XX:+UseInlineCaches

# Advanced Optimizations
-XX:+AlwaysPreTouch
-XX:+UseNUMA
-XX:+AggressiveOpts
-XX:+OptimizeStringConcat
-XX:+UseStringDeduplication
-XX:+UseFastAccessorMethods

# Code Cache
-XX:InitialCodeCacheSize=512m
-XX:ReservedCodeCacheSize=1024m

# Metaspace
-XX:MetaspaceSize=512m
-XX:MaxMetaspaceSize=2048m

# Performance
-XX:SoftRefLRUPolicyMSPerMB=50

# Monitoring
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=${HOME}/android-studio-oom-shenandoah.hprof
-XX:ErrorFile=${HOME}/android-studio-error-shenandoah.log

# System Properties
-Dfile.encoding=UTF-8
-Dsun.io.useCanonCaches=false

# IDE Optimizations
-Didea.max.intellisense.filesize=10000
-Didea.cycle.buffer.size=disabled
EOF

    log_success "Shenandoah configuration created: studio-shenandoah.vmoptions"
}

# ============================================================================
# PARALLEL GC CONFIGURATION (High Throughput)
# ============================================================================
generate_parallel_gc_config() {
    log_info "Generating Parallel GC configuration..."
    
    local xmx=$((RAM_MB / 4))
    [[ $xmx -lt 4096 ]] && xmx=4096
    
    cat > "${HOME}/.local/share/Google/AndroidStudio/studio-parallel.vmoptions" << EOF
# Android Studio with Parallel GC - Maximum Throughput
# Best for batch builds and large heap sizes

# Memory Settings
-Xms$((xmx / 2))m
-Xmx${xmx}m
-XX:ReservedCodeCacheSize=1024m
-XX:+UseCompressedOops
-XX:+UseCompressedClassPointers

# Parallel Garbage Collector
-XX:+UseParallelGC
-XX:ParallelGCThreads=$((CPU_CORES / 2 > 0 ? CPU_CORES / 2 : 2))
-XX:MaxGCPauseMillis=500
-XX:GCTimeRatio=19
-XX:AdaptiveSizePolicyWeight=90
-XX:+UseAdaptiveSizePolicy

# Young Generation
-XX:NewRatio=2
-XX:SurvivorRatio=8
-XX:MaxTenuringThreshold=15

# JIT Compiler Optimizations
-XX:+TieredCompilation
-XX:TieredStopAtLevel=4
-XX:CICompilerCount=$((CPU_CORES > 4 ? 4 : CPU_CORES))
-XX:CompileThreshold=1000
-XX:+AggressiveOpts

# Advanced Optimizations
-XX:+AlwaysPreTouch
-XX:+UseNUMA
-XX:+OptimizeStringConcat
-XX:+UseStringDeduplication
-XX:+UseFastAccessorMethods

# Code Cache
-XX:InitialCodeCacheSize=512m
-XX:ReservedCodeCacheSize=1024m

# Metaspace
-XX:MetaspaceSize=512m
-XX:MaxMetaspaceSize=2048m

# Performance
-XX:SoftRefLRUPolicyMSPerMB=50

# Monitoring
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=${HOME}/android-studio-oom-parallel.hprof
-XX:ErrorFile=${HOME}/android-studio-error-parallel.log

# System Properties
-Dfile.encoding=UTF-8
-Dsun.io.useCanonCaches=false

# IDE Optimizations
-Didea.max.intellisense.filesize=10000
-Didea.cycle.buffer.size=disabled
EOF

    log_success "Parallel GC configuration created: studio-parallel.vmoptions"
}

# ============================================================================
# JVM PROFILING SETUP
# ============================================================================
create_jvm_profiler() {
    log_info "Creating JVM profiling script..."
    
    cat > "${HOME}/profile-android-studio-jvm.sh" << 'EOF'
#!/bin/bash
# Profile Android Studio JVM performance

echo "JVM Profiling for Android Studio"
echo "================================="
echo ""

# Find Android Studio process
STUDIO_PID=$(ps aux | grep "AndroidStudio" | grep -v grep | awk '{print $2}' | head -1)

if [[ -z "$STUDIO_PID" ]]; then
    echo "Android Studio is not running"
    exit 1
fi

echo "Android Studio PID: $STUDIO_PID"
echo ""

# JVM Info
echo "JVM Information:"
jinfo $STUDIO_PID 2>/dev/null | head -20

echo ""
echo "Heap Usage:"
jstat -gc $STUDIO_PID 1000 5

echo ""
echo "GC Statistics:"
jstat -gcutil $STUDIO_PID 1000 5

echo ""
echo "Memory Pools:"
jstat -gcnew $STUDIO_PID
jstat -gcold $STUDIO_PID

echo ""
echo "Thread Dump saved to: studio-threads.txt"
jstack $STUDIO_PID > studio-threads.txt 2>/dev/null

echo ""
echo "Heap Dump (this may take time)..."
jmap -dump:format=b,file=studio-heap.hprof $STUDIO_PID 2>/dev/null

echo ""
echo "Done! Analyze with:"
echo "  - VisualVM"
echo "  - JProfiler"
echo "  - Eclipse MAT (for heap dump)"
EOF

    chmod +x "${HOME}/profile-android-studio-jvm.sh"
    log_success "JVM profiler created: ~/profile-android-studio-jvm.sh"
}

# ============================================================================
# GC LOG ANALYZER
# ============================================================================
create_gc_analyzer() {
    log_info "Creating GC log analyzer..."
    
    cat > "${HOME}/analyze-gc-logs.sh" << 'EOF'
#!/bin/bash
# Analyze GC logs for performance issues

LOG_FILE="$1"

if [[ -z "$LOG_FILE" ]] || [[ ! -f "$LOG_FILE" ]]; then
    echo "Usage: $0 <gc-log-file>"
    exit 1
fi

echo "Analyzing GC Log: $LOG_FILE"
echo "================================="
echo ""

# Total GC time
echo "GC Time Statistics:"
grep -E "Total time|real=" "$LOG_FILE" | awk '{sum+=$NF; count++} END {print "Average GC time:", sum/count "ms"}'

# GC frequency
echo ""
echo "GC Frequency:"
grep -c "GC pause" "$LOG_FILE" | xargs echo "Total GC pauses:"

# Long pauses
echo ""
echo "Long Pauses (>100ms):"
grep "GC pause" "$LOG_FILE" | awk '{if ($NF > 100) print}'

# Memory after GC
echo ""
echo "Heap After GC:"
grep -E "Heap after|Eden|Survivor|Old Gen" "$LOG_FILE" | tail -20

echo ""
echo "Recommendations:"
if grep -q "Full GC" "$LOG_FILE"; then
    echo "  ⚠ Full GCs detected - consider increasing heap size"
fi

echo "  • Review long pauses above"
echo "  • Check heap occupancy trends"
echo "  • Consider alternative GC algorithm if pauses are high"
EOF

    chmod +x "${HOME}/analyze-gc-logs.sh"
    log_success "GC analyzer created: ~/analyze-gc-logs.sh"
}

# ============================================================================
# JFR (Java Flight Recorder) SETUP
# ============================================================================
create_jfr_recorder() {
    log_info "Creating JFR recording script..."
    
    cat > "${HOME}/record-jfr.sh" << 'EOF'
#!/bin/bash
# Record Java Flight Recorder data

DURATION="${1:-60}"
OUTPUT="android-studio-$(date +%Y%m%d_%H%M%S).jfr"

echo "Starting JFR recording for ${DURATION} seconds..."

STUDIO_PID=$(ps aux | grep "AndroidStudio" | grep -v grep | awk '{print $2}' | head -1)

if [[ -z "$STUDIO_PID" ]]; then
    echo "Android Studio is not running"
    exit 1
fi

jcmd $STUDIO_PID JFR.start name=studio duration=${DURATION}s filename=$OUTPUT settings=profile

echo ""
echo "Recording in progress..."
echo "Will save to: $OUTPUT"
echo ""
echo "After recording completes, analyze with:"
echo "  jmc $OUTPUT"
echo "  or upload to https://overhead.jfr.com/"

sleep $DURATION

echo ""
echo "Recording complete: $OUTPUT"
EOF

    chmod +x "${HOME}/record-jfr.sh"
    log_success "JFR recorder created: ~/record-jfr.sh"
}

# ============================================================================
# GENERATE COMPARISON REPORT
# ============================================================================
generate_report() {
    local report="${HOME}/extreme-jvm-tuning-report.txt"
    
    cat > "$report" << EOF
================================================================================
EXTREME JVM TUNING FOR ANDROID STUDIO
Generated: $(date)
================================================================================

System Configuration:
- RAM: ${RAM_MB}MB
- CPU Cores: ${CPU_CORES}
- CPU Threads: ${CPU_THREADS}
- Java Version: ${JAVA_VERSION:-Not detected}

Generated VM Options Files:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. studio-zgc.vmoptions (Java 15+)
   ✓ Z Garbage Collector - Ultra Low Latency
   ✓ Best for: Real-time responsiveness
   ✓ Pause times: <10ms
   ✓ Memory overhead: Medium

2. studio-shenandoah.vmoptions (Java 12+, OpenJDK)
   ✓ Shenandoah GC - Low Pause Time
   ✓ Best for: Balanced performance
   ✓ Pause times: <50ms
   ✓ Memory overhead: Low

3. studio-parallel.vmoptions
   ✓ Parallel GC - Maximum Throughput
   ✓ Best for: Batch builds, large projects
   ✓ Pause times: 100-500ms
   ✓ Memory overhead: Lowest

Profiling Tools Created:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ ~/profile-android-studio-jvm.sh - JVM profiling
✓ ~/analyze-gc-logs.sh - GC log analysis
✓ ~/record-jfr.sh - Java Flight Recorder

How to Use:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Choose a GC configuration based on your needs:
   
   For LOWEST LATENCY (recommended for IDE):
   $ cp ~/.local/share/Google/AndroidStudio/studio-zgc.vmoptions \\
        ~/.local/share/Google/AndroidStudio/studio.vmoptions
   
   For BALANCED PERFORMANCE:
   $ cp ~/.local/share/Google/AndroidStudio/studio-shenandoah.vmoptions \\
        ~/.local/share/Google/AndroidStudio/studio.vmoptions
   
   For MAXIMUM THROUGHPUT (large builds):
   $ cp ~/.local/share/Google/AndroidStudio/studio-parallel.vmoptions \\
        ~/.local/share/Google/AndroidStudio/studio.vmoptions

2. Restart Android Studio

3. Monitor Performance:
   $ ~/profile-android-studio-jvm.sh

4. Record detailed profiling:
   $ ~/record-jfr.sh 120  # 120 second recording

GC Comparison:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
╔══════════════╦═════════════╦═══════════╦══════════════╦════════════════╗
║ GC Algorithm ║ Pause Time  ║ Throughput║ Memory       ║ Best For       ║
╠══════════════╬═════════════╬═══════════╬══════════════╬════════════════╣
║ ZGC          ║ <10ms       ║ Good      ║ Medium       ║ IDE, Real-time ║
║ Shenandoah   ║ <50ms       ║ Good      ║ Low          ║ Balanced       ║
║ G1GC         ║ 50-200ms    ║ Very Good ║ Low          ║ Default        ║
║ Parallel     ║ 100-500ms   ║ Excellent ║ Lowest       ║ Batch builds   ║
╚══════════════╩═════════════╩═══════════╩══════════════╩════════════════╝

Recommendations:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Start with ZGC for best IDE responsiveness (Java 15+ required)
• Use Shenandoah if ZGC is not available
• Keep G1GC for general use (default in main script)
• Switch to Parallel GC only for CI/CD builds

• Monitor GC logs to verify performance
• Profile with JFR for detailed analysis
• Adjust heap size based on project size

Troubleshooting:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
If OOM errors occur:
  - Increase -Xmx value
  - Check heap dump: studio-oom-*.hprof
  - Analyze with Eclipse MAT

If IDE is slow:
  - Check GC pause times with profiler
  - Try different GC algorithm
  - Increase -XX:ReservedCodeCacheSize

If high CPU usage:
  - Reduce -XX:CICompilerCount
  - Check background tasks in IDE
  - Profile with JFR

Advanced Tuning:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Add to vmoptions for extreme debugging:

-XX:+PrintGCDetails
-XX:+PrintGCDateStamps
-Xlog:gc*:file=gc.log:time,uptime:filecount=5,filesize=100m
-XX:+PrintCompilation
-XX:+PrintInlining
-XX:+TraceClassLoading

External Tools:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• VisualVM - Free JVM monitoring
• JProfiler - Commercial profiler
• YourKit - Commercial profiler
• Eclipse MAT - Memory analysis
• GCeasy.io - Online GC log analyzer

================================================================================
EOF

    cat "$report"
    log_success "Report saved to: $report"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    generate_zgc_config
    generate_shenandoah_config
    generate_parallel_gc_config
    create_jvm_profiler
    create_gc_analyzer
    create_jfr_recorder
    
    echo ""
    generate_report
    
    echo ""
    log_success "Extreme JVM tuning complete!"
    log_info "Choose a GC algorithm and copy to studio.vmoptions"
    log_warning "Requires Java 12+ for Shenandoah, Java 15+ for ZGC"
}

main "$@"
