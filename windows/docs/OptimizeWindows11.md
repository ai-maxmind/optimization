# Windows 11 Optimizer

A PowerShell script for optimizing Windows 11 performance, privacy, and user experience.

## 🚀 Quick Start

Before running the script:
1. Open PowerShell as Administrator
2. Navigate to script directory
3. Run one of these commands:

```powershell
# Run with default settings (requires Administrator)
.\OptimizeWindows11.ps1

# Preview changes without applying (safer option)
.\OptimizeWindows11.ps1 -DryRun -Verbose

# Generate report only (no changes)
.\OptimizeWindows11.ps1 -ReportOnly
```

> ⚠️ **Important**: Always run as Administrator. The script will automatically request elevation if needed.

## ⚡ Key Features

- Multiple optimization presets (from basic to extreme)
- Role-based optimization (Desktop, Laptop, VM, Server)
- Gaming, Workstation, and Creator profiles
- Automatic system role detection
- System restore point creation
- Registry backups
- Before/After HTML reports

## 📋 Usage

```powershell
.\OptimizeWindows11.ps1 [[-Preset] <String>] [[-Profile] <String>] [[-Role] <String>] [-DryRun] [-NoReboot] [-ReportOnly] [-Undo]
```

### Optimization Levels (Preset)

| Preset | Description |
|--------|-------------|
| `Lite` | Basic optimizations, safe for all systems |
| `Recommended` | Balanced optimizations (Default) |
| `Max` | Aggressive optimizations |
| `Ultra` | Maximum performance optimizations |
| `UltraX` | Extreme optimizations |
| `UltraInfinity` | Most aggressive optimizations |

### Usage Profiles

| Profile | Best For |
|---------|-----------|
| `Default` | General purpose use |
| `eSports` | Competitive gaming, lowest latency |
| `Workstation` | Professional workloads, balanced |
| `Creator` | Content creation, stability |

### System Roles

| Role | Optimizations |
|------|--------------|
| `Auto` | Automatic detection (Default) |
| `Desktop` | Desktop-specific optimizations |
| `Laptop` | Battery and performance balance |
| `VM` | Virtual machine optimizations |
| `Server` | Server workload optimizations |

### Options

| Switch | Function |
|--------|----------|
| `-DryRun` | Preview changes without applying |
| `-NoReboot` | Skip automatic reboot |
| `-ReportOnly` | Generate system reports only |
| `-Undo` | Revert previous optimizations |

## 💻 Common Use Cases

### Gaming Setup
```powershell
.\OptimizeWindows11.ps1 -Preset Ultra -Profile eSports
```

### Content Creator Setup
```powershell
.\OptimizeWindows11.ps1 -Preset Recommended -Profile Creator
```

### Safe Testing
```powershell
.\OptimizeWindows11.ps1 -DryRun
```

### System Analysis
```powershell
.\OptimizeWindows11.ps1 -ReportOnly
```

## 🔧 Optimizations Applied

### Performance
- Ultimate Performance power plan
- CPU power management
- Storage optimization
- Search indexing optimization
- Long path support

### Privacy & UI
- Visual effects optimization
- Transparency effects control
- File extension visibility
- Privacy settings
- Advertisement ID control

### Network
- TCP optimization
- Network protocol hardening
- Gaming network settings
- WPAD/LLMNR security

### Maintenance
- Storage Sense configuration
- Temporary file cleanup
- System component cleanup
- Scheduled maintenance tasks

### Services & Tasks
- Service optimization
- Task scheduling
- Background process control
- Gaming-related services

## 📁 File Structure

```
C:\OptimizeW11\
├── logs\         # Operation logs
├── backup\       # Registry backups
├── reports\      # Before/After reports
└── state\        # System state info
```

## ⚠️ Requirements

- Windows 11
- PowerShell 5.1+
- Administrator privileges
- System restore enabled (recommended)

## 🔒 Safety Measures

1. **Before Running:**
   - Use `-DryRun` or `-WhatIf` to preview changes
   - Save all work and close applications
   - Create manual backup if needed
   - Check system restore point status
   - Ensure running as Administrator
   - Review `keeplist.txt` if preserving apps

2. **During Operation:**
   - Automatic registry backup
   - System restore point creation
   - Detailed logging of all changes
   - State preservation
   - Error handling and rollback
   - Access rights verification

3. **After Running:**
   - Review change reports
   - Check system stability
   - Monitor performance
   - Keep backup files
   - Test modified features
   - Check Event Viewer for any issues

4. **Error Prevention:**
   - Run with `-Verbose` for detailed logging
   - Use `-DryRun` first
   - Check permissions
   - Verify antivirus exceptions
   - Ensure stable power supply
   - Close conflicting applications

## 🛟 Troubleshooting

1. **Access Denied Errors**
   - Verify running as Administrator
   - Check antivirus blocking
   - Run with `-Verbose` for detailed error messages
   - Check Event Viewer for additional details
   - Verify registry permissions
   - Use `-WhatIf` to test specific operations

2. **Check Logs**
   - Location: `C:\OptimizeW11\logs\`
   - Format: `infinite-[Preset]-[Profile]-[Role]-[Timestamp].log`
   - Look for "WARNING" or "ERROR" messages
   - Check operation timestamps
   - Review failed operations
   - Verify elevation status

3. **Review Reports**
   - Before/After comparisons
   - System state changes
   - Service modifications
   - Task adjustments
   - Registry modifications
   - Permission changes

4. **Recovery Options**
   - Use `-Undo` for quick reversion
   - Restore registry backups
   - Use System Restore
   - Manual service restoration
   - Boot in Safe Mode if needed
   - Use Last Known Good Configuration

5. **Common Issues**
   - Elevation problems: Run as Administrator
   - Registry access: Check permissions
   - Service errors: Check dependencies
   - UWP removal errors: Use keeplist.txt
   - Network issues: Check firewall
   - Performance: Monitor resource usage

## 🛡️ Best Practices

1. **Testing**
   - Always run `-DryRun` first
   - Test in a controlled environment
   - Document current settings
   - Plan recovery strategy

2. **Optimization**
   - Choose appropriate preset
   - Match profile to usage
   - Verify role detection
   - Monitor results

3. **Maintenance**
   - Keep backups
   - Monitor system performance
   - Update regularly
   - Document changes

## 📝 Notes

- Backup important data before running
- Some changes require restart
- Certain optimizations are role-specific
- Keep logs for troubleshooting