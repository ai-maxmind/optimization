# Ubuntu Ultra Optimizer - Architecture Documentation

## Kiến trúc tổng quan

Framework sử dụng kiến trúc modular với các thành phần độc lập:

```
┌─────────────────────────────────────────────────────────────┐
│                        CLI (cli.sh)                         │
│  - Parse arguments                                          │
│  - Initialize environment                                   │
│  - Coordinate execution                                     │
└──────────────────┬──────────────────────────────────────────┘
                   │
          ┌────────┴────────┐
          │                 │
    ┌─────▼─────┐    ┌─────▼─────┐
    │  Loader   │    │ Executor  │
    │  - Discover│    │ - Run     │
    │  - Load   │    │ - Track   │
    │  - Filter │    │ - Handle  │
    └─────┬─────┘    └─────┬─────┘
          │                │
          └────────┬───────┘
                   │
         ┌─────────▼──────────┐
         │      Modules       │
         │  - vm-swappiness   │
         │  - io-scheduler    │
         │  - tcp-buffers     │
         │  - ...             │
         └─────────┬──────────┘
                   │
      ┌────────────┼────────────┐
      │            │            │
  ┌───▼───┐   ┌───▼───┐   ┌───▼───┐
  │ Core  │   │  HW   │   │  FS   │
  │Runtime│   │Detect │   │ Ops   │
  └───────┘   └───────┘   └───────┘
```

## Core Components

### 1. Runtime Layer (`core/runtime/`)

#### args.sh - Argument Parser
- Parse command-line arguments
- Validate inputs
- Store in global variables
- Functions:
  - `ultra_parse_args()`: Parse all arguments
  - `ultra_get_*()`: Getters for arguments
  - `ultra_is_*()`: Boolean flags

#### env.sh - Environment Detection
- Detect OS, kernel, systemd
- Check cgroup version
- Detect virtualization (VM, container)
- Functions:
  - `ultra_detect_env()`: Main detection
  - `ultra_check_root()`: Verify root privileges
  - `ultra_has_systemd()`: Check systemd availability

#### state.sh - State Management
- Generate unique RUN_ID
- Save before/after states
- Track all changes
- Enable rollback
- Functions:
  - `ultra_state_init()`: Initialize run
  - `ultra_state_save_module_before()`: Save before state
  - `ultra_state_save_module_after()`: Save after state
  - `ultra_state_add_action()`: Log action
  - `ultra_state_finalize_module()`: Mark module complete

### 2. Hardware Detection (`core/hw/`)

#### cpu.sh - CPU Detection
- Vendor (Intel/AMD)
- Physical/logical cores
- Hyper-Threading/SMT
- Turbo Boost support
- AVX/AVX2/AVX512 flags
- Cache sizes
- Current governor and frequencies

#### mem.sh - Memory Detection
- Total RAM (GB/KB)
- NUMA nodes detection
- Hugepage support
- Functions:
  - `ultra_hw_mem_detect()`: Main detection
  - `ultra_hw_mem_has_numa()`: Check NUMA
  - `ultra_hw_mem_get_total_gb()`: Get RAM in GB

#### storage.sh - Storage Detection
- Device type (NVMe/SSD/HDD)
- Rotational detection
- Current I/O scheduler
- Queue depth
- Per-device characteristics

#### net.sh - Network Detection
- Physical interfaces
- Driver name
- Link speed
- RX/TX queues (multi-queue)
- Hardware offload features (RSS, TSO, GSO)

### 3. Filesystem Operations (`core/fs/`)

#### backup.sh - Backup Management
- Backup files before modification
- Versioning with timestamps
- Per-run backup directory
- Functions:
  - `ultra_backup_file()`: Backup single file
  - `ultra_backup_restore_file()`: Restore from backup

#### file_edit.sh - Safe File Editing
- Atomic file operations
- Automatic backups
- Dry-run support
- Functions:
  - `ultra_edit_file_with_sed()`: Sed-based editing
  - `ultra_edit_file_append_line()`: Append line
  - `ultra_edit_grub_add_param()`: Modify GRUB config

#### sysctl_io.sh - Sysctl Operations
- Read current values
- Save before state
- Apply new values (runtime + persistent)
- Rollback support
- Functions:
  - `ultra_sysctl_save_and_set()`: Main function
  - `ultra_sysctl_restore()`: Restore value
  - `ultra_sysctl_get_current()`: Read current value

### 4. Logging (`core/log/`)

#### log.sh - Logging System
- Multiple log levels (DEBUG, INFO, WARN, ERROR)
- Colored console output
- File logging
- Timestamps
- Functions:
  - `ultra_log_debug()`: Debug messages
  - `ultra_log_info()`: Info messages
  - `ultra_log_warn()`: Warnings
  - `ultra_log_error()`: Errors
  - `ultra_log_section()`: Section headers

## Module Architecture

### Module Interface

Every module must implement:

```bash
# Required metadata
MOD_ID="kernel.vm.swappiness"
MOD_DESC="Tune vm.swappiness based on profile + RAM"
MOD_STAGE="kernel-vm"
MOD_RISK="low|medium|high"
MOD_DEFAULT_ENABLED="true|false"

# Required functions
mod_id() {
    echo "$MOD_ID"
}

mod_can_run() {
    # Return 0 if should run, 1 if skip
    # Check hardware, profile, etc.
    return 0
}

mod_apply() {
    # Apply optimization
    # Use core functions:
    #   ultra_sysctl_save_and_set
    #   ultra_edit_file_with_sed
    #   ultra_backup_file
}

# Optional functions
mod_rollback() {
    # Rollback changes
    local run_id="$1"
    # Read state and restore
}

mod_verify() {
    # Verify current state
    # Log current values
}

mod_benchmark() {
    # Benchmark before/after (optional)
}
```

### Module Categories

#### Kernel - VM (Virtual Memory)
- `vm-swappiness.sh`: Swap behavior
- `vm-dirty-writeback.sh`: Dirty page flushing
- `vm-thp-hugepage.sh`: Transparent Huge Pages
- `vm-overcommit.sh`: Memory overcommit

#### Kernel - Scheduler
- `sched-governor.sh`: CPU frequency governor
- `sched-numa-balance.sh`: NUMA balancing
- `sched-cpu-isolation.sh`: CPU isolation (TODO)

#### Kernel - I/O
- `io-scheduler.sh`: I/O schedulers per device
- `io-read-ahead.sh`: Read-ahead tuning

#### Network
- `net-core-buffers.sh`: TCP buffers, BBR
- `net-tcp-timewait.sh`: TIME_WAIT recycling (TODO)
- `net-ethtool-offload.sh`: Hardware offload (TODO)

## Orchestration

### Loader (`orchestrator/loader.sh`)

Responsibilities:
- Discover modules (by stage or all)
- Load module files
- Check if module should run:
  - Enabled in profile
  - Risk level acceptable
  - `mod_can_run()` returns true
- Cache loaded modules

Functions:
- `ultra_loader_discover_modules(stage)`: Find modules
- `ultra_loader_load_module(file)`: Load and validate
- `ultra_loader_should_run_module(file)`: Filter

### Executor (`orchestrator/executor.sh`)

Responsibilities:
- Execute modules
- Handle errors
- Track state
- Report status

Functions:
- `ultra_executor_run_module(file)`: Run single module
- `ultra_executor_run_stage(stage)`: Run stage
- `ultra_executor_run_all_stages()`: Run all stages
- `ultra_executor_run_single_module(id)`: Run by ID

Execution flow:
1. Load module
2. Check if should run
3. Call `mod_apply()`
4. Handle errors
5. Finalize state (success/failed/skipped)

### Rollback (`orchestrator/rollback.sh`)

Responsibilities:
- List previous runs
- Rollback entire run
- Rollback single module
- Restore from state

Functions:
- `ultra_rollback_run(run_id)`: Rollback run
- `ultra_rollback_module(run_id, module_id)`: Rollback module

Process:
1. Read state file
2. Find module file
3. Call `mod_rollback(run_id)`
4. Module reads before state
5. Module restores values

## Data Flow

### Apply Flow

```
User → CLI → Loader → Executor → Module
                                    ↓
                          State ← Core Functions
                            ↓
                         Backup
                            ↓
                       sysctl/files
```

### State Tracking

```json
{
  "module_id": "kernel.vm.swappiness",
  "timestamp_start": "2024-11-17T12:00:00Z",
  "before": {
    "sysctl:vm.swappiness": "60",
    "sysctl:vm.vfs_cache_pressure": "100"
  },
  "after": {
    "sysctl:vm.swappiness": "10",
    "sysctl:vm.vfs_cache_pressure": "50"
  },
  "actions": [
    {
      "type": "sysctl",
      "description": "Set vm.swappiness=10 (was: 60)",
      "timestamp": "2024-11-17T12:00:01Z"
    }
  ],
  "status": "success",
  "timestamp_end": "2024-11-17T12:00:02Z"
}
```

### Rollback Flow

```
User → Rollback Script → State Files
                             ↓
                          Modules
                             ↓
                       mod_rollback()
                             ↓
                     Restore sysctl/files
```

## Profile System

### Profile Structure (YAML)

```yaml
profile:
  name: server
  description: "High-performance server"

safety:
  max_risk_level: medium
  require_backup: true
  dry_run_default: false

stages:
  - kernel-vm
  - kernel-sched
  - kernel-io
  - net

modules:
  kernel.vm.swappiness:
    enabled: true
    override_value: 10
    notes: "Low swappiness"
```

### Profile Loading (TODO)

Currently profiles are YAML documentation only. Full YAML parsing to be implemented with:
- `yq` or Python yaml parser
- Load profile settings
- Override module defaults
- Filter stages and modules

## Safety Mechanisms

### 1. Dry-Run Mode
- `--dry-run` flag
- No changes applied
- Shows what would change
- Safe preview

### 2. Risk Levels
- Modules tagged: low/medium/high
- Filter with `--max-risk`
- Default: medium
- Prevents dangerous changes

### 3. Backups
- Auto-backup before file edits
- Per-run backup directory
- Timestamped versions
- Easy restore

### 4. State Tracking
- Before/after values
- Action log
- Per-module granularity
- Enables precise rollback

### 5. Idempotency
- Check current value before set
- Skip if already correct
- Safe to re-run
- No config corruption

### 6. Confirmation
- Prompt before apply
- Show profile and risk
- Skip with `--force`
- Prevent accidents

## Extension Guide

### Adding New Module

1. Choose category and stage
2. Create file: `modules/<category>/<name>.sh`
3. Implement interface:
   - MOD_ID, MOD_DESC, MOD_STAGE, MOD_RISK
   - mod_id(), mod_can_run(), mod_apply()
   - Optional: mod_rollback(), mod_verify()
4. Use core functions for all operations
5. Test in dry-run mode

### Adding New Core Function

1. Choose appropriate core file
2. Implement with consistent naming: `ultra_*`
3. Support dry-run mode
4. Add error handling
5. Document in comments

### Adding New Profile

1. Create `profiles/<name>.yml`
2. Define profile metadata
3. List stages
4. Configure modules
5. Document use case

## Performance Considerations

### Module Execution
- Modules run sequentially (safe, predictable)
- Each module is independent
- Failures don't cascade (with `--force`)

### Hardware Detection
- Cached after first detection
- Minimal overhead
- No redundant checks

### State Storage
- JSON for structured data
- Simple format fallback (no jq)
- Minimal I/O

### Logging
- Buffered file writes
- Conditional console output
- Log level filtering

## Future Enhancements

### Planned Features
1. YAML profile parsing
2. Parallel module execution (optional)
3. Benchmarking framework
4. Web UI for management
5. Ansible/Puppet integration
6. Cloud-init integration
7. Metrics collection
8. A/B testing support

### Additional Modules Planned
- CPU isolation
- IRQ affinity
- Network card RSS/RPS/RFS
- Filesystem mount options
- Systemd service optimization
- Security hardening
- Desktop environment tuning

## Troubleshooting

### Module Not Running
- Check `mod_can_run()` logic
- Verify hardware detection
- Check risk level vs `--max-risk`
- Look for error in logs

### Rollback Not Working
- Verify state file exists
- Check module has `mod_rollback()`
- Ensure backup files present
- Try manual restore from backup

### Changes Not Persistent
- Check sysctl files in `/etc/sysctl.d/`
- Verify systemd services enabled
- Check GRUB updated
- May need reboot

## Security Considerations

### Root Required
- All operations need root
- Check at start: `ultra_check_root()`
- No privilege escalation

### File Permissions
- State dir: 0700 (root only)
- Backup dir: 0700 (root only)
- Log files: 0600 (root only)

### Input Validation
- Validate sysctl keys
- Sanitize file paths
- Check profile names
- Prevent injection

### Audit Trail
- Complete action log
- Timestamps on all changes
- Before/after values
- Rollback capability
