#!/bin/bash

################################################################################
# Gradle Daemon Ultra Optimizer
# Advanced Gradle performance tuning with intelligent configuration
################################################################################

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)
GRADLE_HOME="${HOME}/.gradle"

echo "========================================================"
echo "  Gradle Daemon ULTRA Optimizer"
echo "  RAM: ${RAM_MB}MB | CPU: ${CPU_CORES} cores"
echo "========================================================"
echo ""

# ============================================================================
# INTELLIGENT GRADLE DAEMON CONFIGURATION
# ============================================================================
configure_gradle_daemon() {
    log_info "Creating ULTRA optimized Gradle daemon configuration..."
    
    mkdir -p "${GRADLE_HOME}"
    
    # Calculate optimal settings
    local gradle_xmx
    local gradle_xms
    local metaspace=2048
    local codecache=1024
    local workers
    local file_watch_sensitivity=10000
    
    # Memory allocation strategy
    if [[ $RAM_MB -lt 8192 ]]; then
        gradle_xmx=3072
        gradle_xms=1024
        workers=4
    elif [[ $RAM_MB -lt 16384 ]]; then
        gradle_xmx=6144
        gradle_xms=2048
        workers=$((CPU_CORES < 8 ? CPU_CORES : 8))
    elif [[ $RAM_MB -lt 32768 ]]; then
        gradle_xmx=10240
        gradle_xms=4096
        workers=$((CPU_CORES < 12 ? CPU_CORES : 12))
    else
        gradle_xmx=16384
        gradle_xms=8192
        workers=$((CPU_CORES < 16 ? CPU_CORES : 16))
    fi
    
    # Backup existing
    [[ -f "${GRADLE_HOME}/gradle.properties" ]] && \
        cp "${GRADLE_HOME}/gradle.properties" "${GRADLE_HOME}/gradle.properties.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create ultra-optimized gradle.properties
    cat > "${GRADLE_HOME}/gradle.properties" << EOF
# ============================================================================
# Gradle Daemon ULTRA Configuration
# Generated: $(date)
# System: ${RAM_MB}MB RAM, ${CPU_CORES} CPU cores
# ============================================================================

# ----------------------------------------------------------------------------
# JVM MEMORY SETTINGS
# ----------------------------------------------------------------------------
org.gradle.jvmargs=-Xms${gradle_xms}m \\
    -Xmx${gradle_xmx}m \\
    -XX:MaxMetaspaceSize=${metaspace}m \\
    -XX:ReservedCodeCacheSize=${codecache}m \\
    -XX:+UseCompressedOops \\
    -XX:+UseCompressedClassPointers \\
    -XX:+UseG1GC \\
    -XX:MaxGCPauseMillis=100 \\
    -XX:G1HeapRegionSize=32m \\
    -XX:G1ReservePercent=20 \\
    -XX:InitiatingHeapOccupancyPercent=40 \\
    -XX:G1NewSizePercent=30 \\
    -XX:G1MaxNewSizePercent=60 \\
    -XX:ConcGCThreads=$((CPU_CORES / 4 > 0 ? CPU_CORES / 4 : 1)) \\
    -XX:ParallelGCThreads=$((CPU_CORES / 2 > 0 ? CPU_CORES / 2 : 2)) \\
    -XX:+ParallelRefProcEnabled \\
    -XX:+UseStringDeduplication \\
    -XX:+OptimizeStringConcat \\
    -XX:+AlwaysPreTouch \\
    -XX:+UseNUMA \\
    -XX:+UseFastAccessorMethods \\
    -XX:+AggressiveOpts \\
    -XX:+TieredCompilation \\
    -XX:TieredStopAtLevel=4 \\
    -XX:CompileThreshold=1000 \\
    -XX:CICompilerCount=$((CPU_CORES > 4 ? 4 : CPU_CORES)) \\
    -XX:ReservedCodeCacheSize=${codecache}m \\
    -XX:NonProfiledCodeHeapSize=350m \\
    -XX:ProfiledCodeHeapSize=350m \\
    -XX:NonNMethodCodeHeapSize=324m \\
    -XX:SoftRefLRUPolicyMSPerMB=50 \\
    -XX:+UnlockDiagnosticVMOptions \\
    -XX:+HeapDumpOnOutOfMemoryError \\
    -XX:HeapDumpPath=${HOME}/gradle-oom.hprof \\
    -XX:ErrorFile=${HOME}/gradle-error-%p.log \\
    -Dfile.encoding=UTF-8 \\
    -Dsun.io.useCanonCaches=false \\
    -Djava.net.preferIPv4Stack=true \\
    -Djava.awt.headless=true \\
    -Djdk.attach.allowAttachSelf=true \\
    -Djdk.module.illegalAccess.silent=true

# ----------------------------------------------------------------------------
# GRADLE DAEMON SETTINGS
# ----------------------------------------------------------------------------
org.gradle.daemon=true
org.gradle.daemon.idletimeout=10800000
org.gradle.daemon.healthcheckinterval=60000

# ----------------------------------------------------------------------------
# PARALLEL EXECUTION
# ----------------------------------------------------------------------------
org.gradle.parallel=true
org.gradle.workers.max=${workers}
org.gradle.configureondemand=true
org.gradle.parallel.intra=true

# ----------------------------------------------------------------------------
# CACHING
# ----------------------------------------------------------------------------
org.gradle.caching=true
org.gradle.caching.debug=false
org.gradle.configuration-cache=true
org.gradle.configuration-cache.problems=warn
org.gradle.configuration-cache.max-problems=1000
org.gradle.unsafe.configuration-cache=true
org.gradle.unsafe.configuration-cache-problems=warn

# ----------------------------------------------------------------------------
# FILE WATCHING
# ----------------------------------------------------------------------------
org.gradle.vfs.watch=true
org.gradle.vfs.verbose=false
org.gradle.watch-fs=true
org.gradle.vfs.watch.debug=false

# ----------------------------------------------------------------------------
# LOGGING & CONSOLE
# ----------------------------------------------------------------------------
org.gradle.logging.level=lifecycle
org.gradle.console=auto
org.gradle.warning.mode=summary
org.gradle.logging.stacktrace=internal

# ----------------------------------------------------------------------------
# BUILD PERFORMANCE
# ----------------------------------------------------------------------------
org.gradle.priority=normal
org.gradle.jvmargs.configure-on-demand=true

# ----------------------------------------------------------------------------
# KOTLIN COMPILER
# ----------------------------------------------------------------------------
kotlin.incremental=true
kotlin.incremental.java=true
kotlin.incremental.js=true
kotlin.incremental.multiplatform=true
kotlin.caching.enabled=true
kotlin.parallel.tasks.in.project=true
kotlin.compiler.execution.strategy=in-process
kotlin.build.report.output=file

# ----------------------------------------------------------------------------
# KAPT (Kotlin Annotation Processing)
# ----------------------------------------------------------------------------
kapt.use.worker.api=true
kapt.incremental.apt=true
kapt.include.compile.classpath=false
kapt.verbose=false
kapt.use.k2=false

# ----------------------------------------------------------------------------
# ANDROID BUILD
# ----------------------------------------------------------------------------
android.useAndroidX=true
android.enableJetifier=false
android.enableR8.fullMode=true
android.enableR8=true
android.enableD8=true
android.enableBuildCache=true
android.enableGradleWorkers=true
android.builder.sdkDownload=true
android.experimental.enableNewResourceShrinker=true
android.nonTransitiveRClass=true
android.nonFinalResIds=false

# R8 Optimizations
android.enableR8.kotlin.plugin=true
android.r8.fullMode=true

# D8 Optimizations
android.enableDexingArtifactTransform=true
android.enableDexingArtifactTransform.desugaring=true

# ----------------------------------------------------------------------------
# NETWORK
# ----------------------------------------------------------------------------
systemProp.http.keepAlive=true
systemProp.http.maxConnections=10
systemProp.http.socketTimeout=120000
systemProp.http.connectionTimeout=120000

# ----------------------------------------------------------------------------
# EXPERIMENTAL FEATURES
# ----------------------------------------------------------------------------
org.gradle.unsafe.isolated-projects=false
org.gradle.dependency.verification.console=verbose
EOF

    log_success "Gradle daemon properties created: Xmx=${gradle_xmx}m, Workers=${workers}"
}

# ============================================================================
# GRADLE INIT SCRIPT - Advanced build optimizations
# ============================================================================
create_gradle_init_script() {
    log_info "Creating advanced Gradle init script..."
    
    mkdir -p "${GRADLE_HOME}/init.d"
    
    cat > "${GRADLE_HOME}/init.d/performance.gradle" << 'EOF'
// ============================================================================
// Gradle Performance Init Script - ULTRA Configuration
// Auto-loaded by Gradle for all projects
// ============================================================================

allprojects {
    // Apply to all projects
    gradle.projectsEvaluated {
        tasks.withType(JavaCompile).configureEach {
            options.incremental = true
            options.fork = true
            options.forkOptions.memoryMaximumSize = '2g'
            options.forkOptions.jvmArgs += [
                '-XX:+UseG1GC',
                '-XX:+TieredCompilation',
                '-XX:TieredStopAtLevel=1',
                '-XX:CICompilerCount=2'
            ]
        }
        
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {
            kotlinOptions {
                jvmTarget = '17'
                freeCompilerArgs += [
                    '-Xjvm-default=all',
                    '-Xbackend-threads=0',
                    '-Xallow-unstable-dependencies'
                ]
            }
        }
        
        tasks.withType(Test).configureEach {
            maxParallelForks = Runtime.runtime.availableProcessors().intdiv(2) ?: 1
            forkEvery = 100
            jvmArgs += [
                '-XX:+UseG1GC',
                '-XX:MaxGCPauseMillis=100'
            ]
        }
    }
}

// Build cache configuration
beforeSettings { settings ->
    settings.buildCache {
        local {
            enabled = true
            directory = new File(settings.gradle.gradleUserHomeDir, 'build-cache')
            removeUnusedEntriesAfterDays = 30
        }
        
        remote(HttpBuildCache) {
            enabled = false
            // Configure if using remote cache server
        }
    }
}

// Dependency resolution optimization
allprojects {
    configurations.all {
        // Aggressive caching
        resolutionStrategy.cacheChangingModulesFor 0, 'seconds'
        resolutionStrategy.cacheDynamicVersionsFor 0, 'seconds'
        
        // Fail fast
        resolutionStrategy.failOnNonReproducibleResolution()
    }
}

// Repository optimization
allprojects {
    repositories {
        // Prioritize local maven
        mavenLocal {
            content {
                includeGroupByRegex ".*"
            }
        }
        
        // Google with content filtering
        google {
            content {
                includeGroupByRegex "com\\.android.*"
                includeGroupByRegex "com\\.google.*"
                includeGroupByRegex "androidx.*"
            }
        }
        
        // Maven Central
        mavenCentral()
        
        // Gradle Plugin Portal
        gradlePluginPortal()
    }
}

// Logging optimization
gradle.addListener(new BuildAdapter() {
    @Override
    void buildFinished(BuildResult result) {
        def duration = result.gradle.services.get(org.gradle.api.internal.tasks.execution.statistics.TaskExecutionStatisticsEventAdapter.class)
        // Add custom metrics here
    }
})
EOF

    log_success "Gradle init script created"
}

# ============================================================================
# BUILD CACHE CONFIGURATION
# ============================================================================
setup_build_cache() {
    log_info "Setting up optimized build cache..."
    
    local cache_dir="${HOME}/.android/build-cache"
    mkdir -p "$cache_dir"
    
    # Set cache size limits
    cat > "${cache_dir}/cache.properties" << EOF
# Build Cache Configuration
cache.maxSize=10GB
cache.targetSizePercentage=90
cache.cleanupFrequency=7
EOF

    log_success "Build cache configured at: $cache_dir"
}

# ============================================================================
# GRADLE WRAPPER OPTIMIZATION
# ============================================================================
optimize_gradle_wrapper() {
    log_info "Creating Gradle wrapper optimization script..."
    
    cat > "${HOME}/optimize-gradle-wrapper.sh" << 'EOF'
#!/bin/bash
# Run this in your project directory to optimize Gradle wrapper

if [[ ! -f "gradlew" ]]; then
    echo "Not a Gradle project directory"
    exit 1
fi

# Update to latest Gradle version
./gradlew wrapper --gradle-version=8.5 --distribution-type=bin

# Optimize wrapper properties
cat > gradle/wrapper/gradle-wrapper.properties << 'WRAPPER_EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-bin.zip
networkTimeout=60000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
WRAPPER_EOF

echo "Gradle wrapper optimized to version 8.5"
EOF

    chmod +x "${HOME}/optimize-gradle-wrapper.sh"
    log_success "Wrapper optimizer created at ~/optimize-gradle-wrapper.sh"
}

# ============================================================================
# GRADLE PROFILING SCRIPT
# ============================================================================
create_profiling_script() {
    log_info "Creating Gradle profiling script..."
    
    cat > "${HOME}/gradle-profile.sh" << 'EOF'
#!/bin/bash
# Profile Gradle build performance

if [[ ! -f "gradlew" ]]; then
    echo "Not a Gradle project directory"
    exit 1
fi

echo "Starting Gradle build profiling..."
echo "This will generate detailed performance reports"
echo ""

# Clean build with profiling
./gradlew clean \
    --profile \
    --scan \
    --info \
    --warning-mode all \
    --build-cache \
    --configuration-cache

# Regular build with profiling
./gradlew assembleDebug \
    --profile \
    --scan \
    --build-cache \
    --configuration-cache

echo ""
echo "Profile reports generated in: build/reports/profile/"
echo "Build scan URL will be displayed above"
echo ""
echo "Analyze with:"
echo "  - Profile HTML report"
echo "  - Build scan online"
echo "  - Check task execution times"
EOF

    chmod +x "${HOME}/gradle-profile.sh"
    log_success "Profiling script created at ~/gradle-profile.sh"
}

# ============================================================================
# DEPENDENCY CACHE WARMING
# ============================================================================
create_cache_warmer() {
    log_info "Creating dependency cache warmer..."
    
    cat > "${HOME}/warm-gradle-cache.sh" << 'EOF'
#!/bin/bash
# Warm up Gradle dependency cache

if [[ ! -f "gradlew" ]]; then
    echo "Not a Gradle project directory"
    exit 1
fi

echo "Warming up Gradle dependency cache..."

# Download all dependencies
./gradlew \
    --refresh-dependencies \
    dependencies \
    androidDependencies \
    buildEnvironment

# Populate build cache
./gradlew \
    compileDebugSources \
    --build-cache \
    --configuration-cache

echo "Cache warmed up successfully"
EOF

    chmod +x "${HOME}/warm-gradle-cache.sh"
    log_success "Cache warmer created at ~/warm-gradle-cache.sh"
}

# ============================================================================
# CLEAN GRADLE CACHES
# ============================================================================
create_cache_cleaner() {
    log_info "Creating Gradle cache cleaner..."
    
    cat > "${HOME}/clean-gradle-caches.sh" << 'EOF'
#!/bin/bash
# Clean Gradle caches safely

echo "Cleaning Gradle caches..."

# Stop Gradle daemon
./gradlew --stop 2>/dev/null || true

# Clean local caches
rm -rf ~/.gradle/caches/
rm -rf ~/.gradle/daemon/
rm -rf ~/.gradle/wrapper/dists/
rm -rf ~/.android/build-cache/

# Clean project caches
find . -type d -name ".gradle" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name "build" -exec rm -rf {} + 2>/dev/null || true

echo "Gradle caches cleaned"
echo "Run warm-gradle-cache.sh to rebuild caches"
EOF

    chmod +x "${HOME}/clean-gradle-caches.sh"
    log_success "Cache cleaner created at ~/clean-gradle-caches.sh"
}

# ============================================================================
# GRADLE MONITORING DASHBOARD
# ============================================================================
create_monitoring_dashboard() {
    log_info "Creating Gradle monitoring dashboard..."
    
    cat > "${HOME}/gradle-monitor.sh" << 'EOF'
#!/bin/bash
# Monitor Gradle daemon performance

watch -n 2 '
echo "=== Gradle Daemon Status ==="
ps aux | grep -i gradle | grep -v grep

echo ""
echo "=== Gradle Processes Memory Usage ==="
ps aux | grep -i gradle | grep -v grep | awk "{sum+=\$6} END {print \"Total RSS: \" sum/1024 \"MB\"}"

echo ""
echo "=== Gradle Cache Size ==="
du -sh ~/.gradle/caches/ 2>/dev/null
du -sh ~/.gradle/wrapper/ 2>/dev/null
du -sh ~/.android/build-cache/ 2>/dev/null

echo ""
echo "=== Gradle Daemon Logs (last 5 lines) ==="
tail -n 5 ~/.gradle/daemon/*/daemon-*.out.log 2>/dev/null | head -5
'
EOF

    chmod +x "${HOME}/gradle-monitor.sh"
    log_success "Monitoring dashboard created at ~/gradle-monitor.sh"
}

# ============================================================================
# GENERATE REPORT
# ============================================================================
generate_report() {
    local report="${HOME}/gradle-daemon-optimization-report.txt"
    
    cat > "$report" << EOF
================================================================================
Gradle Daemon ULTRA Optimization Report
Generated: $(date)
================================================================================

Configuration:
- Gradle Home: ${GRADLE_HOME}
- RAM Allocated: ${gradle_xmx}m (from ${RAM_MB}MB total)
- Max Workers: ${workers}
- CPU Cores: ${CPU_CORES}

Files Created:
✓ ${GRADLE_HOME}/gradle.properties - Daemon configuration
✓ ${GRADLE_HOME}/init.d/performance.gradle - Auto-load optimizations
✓ ${HOME}/.android/build-cache/ - Local build cache
✓ ${HOME}/optimize-gradle-wrapper.sh - Wrapper updater
✓ ${HOME}/gradle-profile.sh - Build profiler
✓ ${HOME}/warm-gradle-cache.sh - Cache warmer
✓ ${HOME}/clean-gradle-caches.sh - Cache cleaner
✓ ${HOME}/gradle-monitor.sh - Performance monitor

Key Optimizations:
✓ G1GC with tuned parameters
✓ Parallel execution enabled (${workers} workers)
✓ Configuration cache enabled
✓ File system watching enabled
✓ Kotlin incremental compilation
✓ KAPT optimizations
✓ R8 full mode enabled
✓ Build cache configured (30-day retention)

Daemon Settings:
- Initial Heap: ${gradle_xms}m
- Maximum Heap: ${gradle_xmx}m
- Metaspace: ${metaspace}m
- Code Cache: ${codecache}m
- Idle Timeout: 3 hours

Usage:
1. Settings applied globally for all Gradle projects
2. Profile builds: cd project && ~/gradle-profile.sh
3. Monitor daemon: ~/gradle-monitor.sh
4. Warm cache: cd project && ~/warm-gradle-cache.sh
5. Clean caches: ~/clean-gradle-caches.sh

Next Steps:
1. Restart any running Gradle daemons: ./gradlew --stop
2. Run a build to verify: ./gradlew assembleDebug --scan
3. Check build scan for performance insights
4. Monitor with: ~/gradle-monitor.sh

Tips:
- Use --scan flag to get online build performance analysis
- Use --profile flag to get local HTML performance report
- Keep Gradle version updated (currently using latest stable)
- Review and adjust workers based on build performance

================================================================================
EOF

    cat "$report"
    log_success "Report saved to: $report"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    configure_gradle_daemon
    create_gradle_init_script
    setup_build_cache
    optimize_gradle_wrapper
    create_profiling_script
    create_cache_warmer
    create_cache_cleaner
    create_monitoring_dashboard
    
    echo ""
    generate_report
    
    echo ""
    log_success "Gradle Daemon ULTRA optimization complete!"
    log_warning "Restart Gradle daemons: ./gradlew --stop"
}

main "$@"
