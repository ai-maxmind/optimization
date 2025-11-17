# CleanWindows11 
`CleanWindows11.cmd` is a batch script that helps clean and optimize Windows 11 by removing temporary files, browser caches, system logs, compacting VHD/VHDX images, running DISM/SFC repairs, resetting Windows Update components, cleaning developer caches, and more.

Key points:
- Use `/dry-run` to preview changes without deleting anything.
- The script writes detailed logs and outputs CSV/JSON reports to `C:\CleanupLogs\`.
- Many modules can be enabled or disabled with command-line flags.

⚠️ Always run the script with Administrator privileges when performing actions (not required for `/dry-run`).

## Requirements

- Windows 11
- Administrator privileges (Run as administrator)
- Close browsers, IDEs and other apps to minimize "file in use" errors
- (Optional) Create a System Restore point before risky operations

## Basic usage

- Preview (no deletions):

```bat
CleanWindows11.cmd /dry-run /deep
```

- Run the default deep cleanup:

```bat
CleanWindows11.cmd /deep
```

- Run maximum cleanup (aggressive) and skip confirmations:

```bat
CleanWindows11.cmd /omega /force
```

If you invoke from PowerShell, use:

```powershell
& 'H:\AI\optimization\windows\CleanWindows11.cmd' /dry-run /deep
```

## Important flags (short)

- `/dry-run` — Analyze only, do not delete. Always test first.
- `/deep` — Default deep cleanup preset.
- `/omega` — Enable most heavy modules (high risk); use with `/force` to skip confirmations.
- `/force` — Bypass confirmations.
- `/wu-reset` — Reset Windows Update components (SoftwareDistribution + Catroot2).
- `/restorehealth` — Run `DISM /Online /Cleanup-Image /RestoreHealth`.
- `/sfc` — Run `sfc /scannow`.
- `/purge-shadow` — Delete all Shadow Copies / Restore Points (irreversible).
- `/purge-profiles:N` — Remove user profiles older than N days (with internal safeguards).

Other flags: `/prefetch`, `/devcaches`, `/devcaches-x`, `/wsl-compact`, `/docker-compact`, `/hyperv-compact`, `/trim`, `/dns-net-reset`, `/rebuild-index`, `/rebuild-icon-font`.

## Common examples

- First-time analysis (recommended):

```bat
CleanWindows11.cmd /dry-run /deep
```

- Routine weekly cleanup:

```bat
CleanWindows11.cmd /deep
```

- Aggressive cleanup + repairs:

```bat
CleanWindows11.cmd /omega /restorehealth /sfc /compactos /force
```

- Clean developer caches on a developer workstation:

```bat
CleanWindows11.cmd /deep /devcaches /devcaches-x /rebuild-index
```

## Output & logs

- All logs and reports are written to `C:\CleanupLogs\` (log, csv, json) with timestamps in filenames.
- The console prints total freed space and per-step status.

Quick PowerShell example (total GB from CSV):

```powershell
$csv = 'C:\CleanupLogs\singularity-YYYY-MM-DD_HH-MM-SS.csv'
(Import-Csv $csv | Measure-Object BytesBefore -Sum).Sum / 1GB
```

## Safety notes & irreversible actions

- `/resetbase`: cleans the component store and may prevent uninstalling certain updates.
- `/purge-shadow`: deletes all Shadow Copies / Restore Points — NOT recoverable.
- `/cleareventlogs`: permanently clears Event Log history.

Before running risky flags: back up important data and create a restore point if available.

## Troubleshooting & common errors

- "Access is denied" / "File in use": close the application holding the file or reboot.
- "Operation requires elevation": run the script as Administrator.
- DISM/SFC failures: retry with internet access and a working Windows Update service.
- VHDX/WSL/Docker compact failures: stop VMs/containers before compacting.
- Logs not created: verify write permissions for `C:\CleanupLogs\`.

If you see the error ". was unexpected at this time." or other syntax errors, collect the script output and trace files and share them for diagnosis:

```bat
cmd /c "H:\AI\optimization\windows\CleanWindows11.cmd /dry-run /deep > %TEMP%\CleanWindows11_out.txt 2>&1"
type %TEMP%\CleanWindows11_out.txt
type %TEMP%\CleanWindows11_trace.txt
```

## Scheduling (Task Scheduler)

To schedule weekly at 02:00 AM with highest privileges:

1. Open Task Scheduler → Create Task.
2. General: enter name, check "Run with highest privileges".
3. Trigger: Weekly → choose day/time.
4. Action: Program = `C:\Windows\System32\cmd.exe`, Arguments = `/c "H:\AI\optimization\windows\CleanWindows11.cmd /deep"`.