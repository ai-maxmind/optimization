@echo off
set "POWERSHELL_UTF8=powershell -NoProfile -ExecutionPolicy Bypass -Command"
%POWERSHELL_UTF8% "[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new()" >nul
setlocal EnableExtensions EnableDelayedExpansion
title Windows 11 Deep Cleanup v2 (ultra)
color 0a

set "TRACE_LOG=%TEMP%\CleanWindows11_trace.txt"
(
  echo --- TRACE %DATE% %TIME% ---
  echo CWD=%CD%
  echo ARG0=%~0
  echo ARGS=%*
  echo PROMPT=%PROMPT%
)>>"%TRACE_LOG%" 2>nul

set "DEEP=0" & set "OMEGA=0" & set "SAFE=0"
set "FORCE=0" & set "DRYRUN=0" & set "ANALYZE=0" & set "QUIET=0"
set "NO_RP=0" & set "EXCLUDE_LIST="
set "LOGS_RETENTION=0"

set "CLEANPREFETCH=0" & set "DISABLEHIBER=0" & set "CLEANBROWSERS=1"
set "RESETBASE=0" & set "COMPACTOS=0" & set "REBUILDINDEX=0" & set "CLEAR_EVT=0"
set "PURGE_SHADOW=0" & set "PURGE_PROFILES=0" & set "PURGE_DAYS=30"
set "DRIVER_PURGE=0" & set "WU_RESET=0" & set "RESTOREHEALTH=0" & set "SFC_SCAN=0"
set "RECYCLEBIN_REPAIR=0" & set "REBUILD_ICON_FONT=0" & set "TRIM_ALL=0"
set "DNS_NET_RESET=0" & set "DEV_CACHES=0" & set "ALL_DRIVES_TMP=0" & set "DUMPS=0"
set "SPOOL_CLEAR=0" & set "SLEEPSTUDY_CLEAR=0" & set "PANTHER_CLEAR=0"
set "UPGRADE_LEFTOVERS=0" & set "WSL_COMPACT=0" & set "DOCKER_COMPACT=0" & set "HYPERV_COMPACT=0"
set "USN_RESET=0" & set "SRU_CLEAR=0" & set "WMI_SALVAGE=0" & set "WSRESET=0"
set "SILENTCLEANUP=0" & set "CLEANMGR=0" & set "RDP_CACHE=0" & set "MSIX_DELETED=0"
set "SYSTEMPROFILE_TEMP=0" & set "MOSETUP_LOGS=0" & set "WU_LOGS=0" & set "DISM_LOGS=0"
set "READYBOOT=0" & set "PS_CACHES=0" & set "DEV_CACHES_X=0"

set "VS_PCACHE=0"
set "COMPACT_HOTSPOT=0"

if "%~1"=="" goto :SHOW_HELP

for %%A in (%*) do (
  if /I "%%~A"=="/help"     goto :SHOW_HELP
  if /I "%%~A"=="-h"        goto :SHOW_HELP
  if /I "%%~A"=="/deep"               set "DEEP=1"
  if /I "%%~A"=="/omega"              set "OMEGA=1"
  if /I "%%~A"=="/safe"               set "SAFE=1"
  if /I "%%~A"=="/force"              set "FORCE=1"
  if /I "%%~A"=="/dry-run"            set "DRYRUN=1"
  if /I "%%~A"=="/analyze"            set "ANALYZE=1" & set "DRYRUN=1"
  if /I "%%~A"=="/quiet"              set "QUIET=1"
  if /I "%%~A"=="/no-restorepoint"    set "NO_RP=1"

  if /I "%%~A"=="/prefetch"           set "CLEANPREFETCH=1"
  if /I "%%~A"=="/disable-hibernate"  set "DISABLEHIBER=1"
  if /I "%%~A"=="/no-browsers"        set "CLEANBROWSERS=0"
  if /I "%%~A"=="/resetbase"          set "RESETBASE=1"
  if /I "%%~A"=="/compactos"          set "COMPACTOS=1"
  if /I "%%~A"=="/rebuild-index"      set "REBUILDINDEX=1"
  if /I "%%~A"=="/cleareventlogs"     set "CLEAR_EVT=1"
  if /I "%%~A"=="/purge-shadow"       set "PURGE_SHADOW=1"
  if /I "%%~A"=="/driver-purge"       set "DRIVER_PURGE=1"
  if /I "%%~A"=="/wu-reset"           set "WU_RESET=1"
  if /I "%%~A"=="/restorehealth"      set "RESTOREHEALTH=1"
  if /I "%%~A"=="/sfc"                set "SFC_SCAN=1"
  if /I "%%~A"=="/recyclebin-repair"  set "RECYCLEBIN_REPAIR=1"
  if /I "%%~A"=="/rebuild-icon-font"  set "REBUILD_ICON_FONT=1"
  if /I "%%~A"=="/trim"               set "TRIM_ALL=1"
  if /I "%%~A"=="/dns-net-reset"      set "DNS_NET_RESET=1"
  if /I "%%~A"=="/devcaches"          set "DEV_CACHES=1"
  if /I "%%~A"=="/devcaches-x"        set "DEV_CACHES_X=1"
  if /I "%%~A"=="/all-drives-tmp"     set "ALL_DRIVES_TMP=1"
  if /I "%%~A"=="/dumps"              set "DUMPS=1"
  if /I "%%~A"=="/spool-clear"        set "SPOOL_CLEAR=1"
  if /I "%%~A"=="/sleepstudy-clear"   set "SLEEPSTUDY_CLEAR=1"
  if /I "%%~A"=="/panther-clear"      set "PANTHER_CLEAR=1"
  if /I "%%~A"=="/upgrade-leftovers"  set "UPGRADE_LEFTOVERS=1"
  if /I "%%~A"=="/wsl-compact"        set "WSL_COMPACT=1"
  if /I "%%~A"=="/docker-compact"     set "DOCKER_COMPACT=1"
  if /I "%%~A"=="/hyperv-compact"     set "HYPERV_COMPACT=1"
  if /I "%%~A"=="/usn-reset"          set "USN_RESET=1"
  if /I "%%~A"=="/sru-clear"          set "SRU_CLEAR=1"
  if /I "%%~A"=="/wmi-salvage"        set "WMI_SALVAGE=1"
  if /I "%%~A"=="/wsreset"            set "WSRESET=1"
  if /I "%%~A"=="/silentcleanup"      set "SILENTCLEANUP=1"
  if /I "%%~A"=="/cleanmgr"           set "CLEANMGR=1"
  if /I "%%~A"=="/rdp-cache"          set "RDP_CACHE=1"
  if /I "%%~A"=="/msix-deleted"       set "MSIX_DELETED=1"
  if /I "%%~A"=="/systemprofile-temp" set "SYSTEMPROFILE_TEMP=1"
  if /I "%%~A"=="/mosetup-logs"       set "MOSETUP_LOGS=1"
  if /I "%%~A"=="/wu-logs"            set "WU_LOGS=1"
  if /I "%%~A"=="/dism-logs"          set "DISM_LOGS=1"
  if /I "%%~A"=="/readyboot"          set "READYBOOT=1"
  if /I "%%~A"=="/ps-caches"          set "PS_CACHES=1"
  if /I "%%~A"=="/vs-pcache"          set "VS_PCACHE=1"
  if /I "%%~A"=="/compact-hotspot"    set "COMPACT_HOTSPOT=1"
)

for %%A in (%*) do (
  echo %%~A| findstr /I /R "^/purge-profiles:[0-9][0-9]*$" >nul && (
    for /f "tokens=2 delims=:" %%X in ("%%~A") do ( set "PURGE_PROFILES=1" & set "PURGE_DAYS=%%~X" )
  )
  echo %%~A| findstr /I /R "^/exclude:.*$" >nul && (
    for /f "tokens=2,* delims=:" %%X in ("%%~A") do set "EXCLUDE_LIST=%%~Y"
  )
  echo %%~A| findstr /I /R "^/logs-days:[0-9][0-9]*$" >nul && (
    for /f "tokens=2 delims=:" %%X in ("%%~A") do set "LOGS_RETENTION=%%~X"
  )
)

if "%SAFE%"=="1" (
  set "DEEP=1"
  set "CLEAR_EVT=0" & set "PURGE_SHADOW=0" & set "USN_RESET=0" & set "SRU_CLEAR=0" & set "WMI_SALVAGE=0" & set "RESETBASE=0"
)

if "%OMEGA%"=="1" (
  set "DEEP=1"
  set "RESETBASE=1" & set "COMPACTOS=1" & set "REBUILDINDEX=1" & set "CLEAR_EVT=1" & set "PURGE_SHADOW=1"
  set "DRIVER_PURGE=1" & set "CLEANPREFETCH=1" & set "DISABLEHIBER=1" & set "WU_RESET=1" & set "RESTOREHEALTH=1" & set "SFC_SCAN=1"
  set "RECYCLEBIN_REPAIR=1" & set "REBUILD_ICON_FONT=1" & set "TRIM_ALL=1" & set "DNS_NET_RESET=1" & set "DEV_CACHES=1" & set "ALL_DRIVES_TMP=1"
  set "DUMPS=1" & set "SPOOL_CLEAR=1" & set "SLEEPSTUDY_CLEAR=1" & set "PANTHER_CLEAR=1" & set "UPGRADE_LEFTOVERS=1" & set "WSL_COMPACT=1" & set "DOCKER_COMPACT=1" & set "HYPERV_COMPACT=1"
  set "USN_RESET=1" & set "SRU_CLEAR=1" & set "WMI_SALVAGE=1" & set "WSRESET=1" & set "SILENTCLEANUP=1" & set "CLEANMGR=1" & set "RDP_CACHE=1" & set "MSIX_DELETED=1"
  set "SYSTEMPROFILE_TEMP=1" & set "MOSETUP_LOGS=1" & set "WU_LOGS=1" & set "DISM_LOGS=1" & set "READYBOOT=1" & set "PS_CACHES=1" & set "DEV_CACHES_X=1" & set "VS_PCACHE=1" & set "COMPACT_HOTSPOT=1"
  if "%PURGE_PROFILES%"=="0" set "PURGE_PROFILES=1" & set "PURGE_DAYS=45"
)

set "SCRIPT_PATH=%~0"
call :RequireAdmin || goto :eof

for /f "tokens=2 delims==" %%I in ('wmic os get LocalDateTime /value ^| find "="') do set "ldt=%%I"
set "ts=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
set "LOGDIR=%SystemDrive%\CleanupLogs"
if not exist "%LOGDIR%" md "%LOGDIR%" >nul 2>&1
set "LOG=%LOGDIR%\singularity-%ts%.log"
set "CSV=%LOGDIR%\singularity-%ts%.csv"
set "JSON=%LOGDIR%\singularity-%ts%.json"
echo Module,ModuleId,Path,BytesBefore,Action>"%CSV%"

:: progress counter
set "_STEP_COUNTER=0"
set "_STEP_TOTAL=0"

call :log "===== START %DATE% %TIME% ====="
call :log "Flags: OMEGA=%OMEGA% SAFE=%SAFE% DEEP=%DEEP% DRYRUN=%DRYRUN% ANALYZE=%ANALYZE% FORCE=%FORCE% QUIET=%QUIET%"
if defined EXCLUDE_LIST call :log "Exclude=%EXCLUDE_LIST%"

reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1 && (
  call :warn "Detected RebootPending. Một số thao tác có thể bị trì hoãn."
)

set "IsSSD=1"
for /f %%F in ('powershell -NoProfile -Command "(Get-PhysicalDisk | ? {$_.MediaType -ne $null} | Sort Size -Descending | Select -First 1).MediaType"') do (
  echo %%F| find /I "HDD" >nul && set "IsSSD=0"
)
call :log "IsSSD=%IsSSD%"

rem
for /f %%A in ('powershell -NoProfile -Command "(Get-PSDrive -Name %SystemDrive:~0,1%).Free"') do set "FreeBefore=%%A"
call :log "FreeBefore=%FreeBefore%"

if "%NO_RP%"=="0" if "%DRYRUN%"=="0" (
  call :log "Create RestorePoint..."
  powershell -NoProfile -Command "try{Enable-ComputerRestore -Drive '%SystemDrive%';Checkpoint-Computer -Description 'Pre-SINGULARITY %ts%' -RestorePointType MODIFY_SETTINGS}catch{}" >>"%LOG%" 2>&1
)

if "%OMEGA%"=="1" if "%FORCE%"=="0" if "%DRYRUN%"=="0" (
  if "%QUIET%"=="0" (
    echo [OMEGA] Thao tác cực sâu ^(ResetBase/USN/SRU/WMI/EventLogs/Shadow/...^).
    set /p "OK=Gõ GO để tiếp tục (Ctrl+C huỷ): "
    if /I not "%OK%"=="GO" ( echo Hủy. & goto :FINALIZE )
  )
)

for %%S in (bits wuauserv dosvc sysmain wsearch) do net stop %%S /y >>"%LOG%" 2>&1

if "%DISABLEHIBER%"=="1" ( call :log powercfg -h off & if "%DRYRUN%"=="0" powercfg -h off >>"%LOG%" 2>&1 )

call :step "Starting main cleanup"

call :step "System temps"
call :ZClean "%TEMP%" "SystemTemp" "core"
call :ZClean "%TMP%"  "SystemTemp" "core"
call :ZClean "%windir%\Temp" "SystemTemp" "core"
call :ZClean "%ProgramData%\Microsoft\Windows\WER\Temp" "WER" "core"
call :ZClean "%ProgramData%\Microsoft\Windows\WER\ReportQueue" "WER" "core"

rem  
call :step "Per-user cleanup"
for /d %%U in ("%SystemDrive%\Users\*") do (
  set "U=%%~fU"
  if exist "!U!\NTUSER.DAT" if /I not "%%~nxU"=="Public" if /I not "%%~nxU"=="Default" if /I not "%%~nxU"=="Default User" (
    call :ZClean "!U!\AppData\Local\Temp" "UserTemp" "user"
    call :ZClean "!U!\AppData\Local\CrashDumps" "CrashDumps" "user"
    call :ZClean "!U!\AppData\Local\D3DSCache" "D3DCache" "user"
    call :ZClean "!U!\AppData\Roaming\Microsoft\Windows\Recent" "Recent" "user"
    del /q "!U!\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db" >>"%LOG%" 2>&1

    if "%CLEANBROWSERS%"=="1" (
      for /d %%P in ("!U!\AppData\Local\Microsoft\Edge\User Data\*") do (
        call :ZClean "%%~fP\Cache" "EdgeCache" "browser"
        call :ZClean "%%~fP\Code Cache" "EdgeCache" "browser"
        call :ZClean "%%~fP\GPUCache" "EdgeCache" "browser"
        call :ZClean "%%~fP\Crashpad\reports" "EdgeCrashpad" "browser"
      )
      for /d %%P in ("!U!\AppData\Local\Google\Chrome\User Data\*") do (
        call :ZClean "%%~fP\Cache" "ChromeCache" "browser"
        call :ZClean "%%~fP\Code Cache" "ChromeCache" "browser"
        call :ZClean "%%~fP\GPUCache" "ChromeCache" "browser"
        call :ZClean "%%~fP\Crashpad\reports" "ChromeCrashpad" "browser"
      )
      for /d %%P in ("!U!\AppData\Local\BraveSoftware\Brave-Browser\User Data\*") do (
        call :ZClean "%%~fP\Cache" "BraveCache" "browser"
        call :ZClean "%%~fP\Code Cache" "BraveCache" "browser"
        call :ZClean "%%~fP\GPUCache" "BraveCache" "browser"
      )
      for /d %%P in ("!U!\AppData\Local\Mozilla\Firefox\Profiles\*") do (
        call :ZClean "%%~fP\cache2" "FirefoxCache" "browser"
        call :ZClean "%%~fP\jumpListCache" "FirefoxCache" "browser"
      )
      call :ZClean "!U!\AppData\Local\Microsoft\EdgeWebView" "EdgeWebView" "browser"
    )

    for /d %%P in ("!U!\AppData\Local\Packages\*") do (
      call :ZClean "%%~fP\LocalCache" "UWP-LocalCache" "uwp"
      call :ZClean "%%~fP\TempState"  "UWP-TempState"  "uwp"
      call :ZClean "%%~fP\AC\Temp"    "UWP-Temp"       "uwp"
    )
    call :ZClean "!U!\AppData\Local\Microsoft\Office\16.0\OfficeFileCache" "OfficeFileCache" "office"
    call :ZClean "!U!\AppData\Roaming\Microsoft\Teams\Cache" "Teams" "teams"
    call :ZClean "!U!\AppData\Roaming\Microsoft\Teams\blob_storage" "Teams" "teams"
    call :ZClean "!U!\AppData\Roaming\Microsoft\Teams\databases" "Teams" "teams"
    call :ZClean "!U!\AppData\Roaming\Microsoft\Teams\GPUCache" "Teams" "teams"
    call :ZClean "!U!\AppData\Local\Microsoft\OneDrive\logs" "OneDriveLogs" "onedrive"

    if "%RDP_CACHE%"=="1" ( call :ZClean "!U!\AppData\Local\Microsoft\Terminal Server Client\Cache" "RDP-BitmapCache" "rdp" )
    if "%PS_CACHES%"=="1" (
      call :ZClean "!U!\AppData\Local\Microsoft\Windows\PowerShell\CommandAnalysis" "PS-CommandAnalysis" "ps"
      call :ZClean "!U!\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" "PS-History" "ps"
    )
    if "%DEV_CACHES_X%"=="1" (
      call :ZClean "!U!\AppData\Local\pip\Cache" "pip-cache" "dev"
      call :ZClean "!U!\AppData\Local\pnpm-store" "pnpm-store" "dev"
      call :ZClean "!U!\.nuget\packages" "nuget-packages" "dev"
      call :ZClean "!U!\go\pkg\mod\cache" "go-mod-cache" "dev"
      call :ZClean "!U!\.cargo\registry\cache" "cargo-registry-cache" "dev"
      call :ZClean "!U!\.rustup\tmp" "rustup-tmp" "dev"
      call :ZClean "!U!\AppData\Local\pypoetry\Cache" "poetry-cache" "dev"
      call :ZClean "!U!\AppData\Roaming\Code\Cache" "vscode-cache" "dev"
      call :ZClean "!U!\AppData\Roaming\Code\CachedData" "vscode-cacheddata" "dev"
      call :ZClean "!U!\AppData\Roaming\Code\GPUCache" "vscode-gpucache" "dev"
      call :ZClean "!U!\AppData\Roaming\JetBrains\*" "jetbrains-caches" "dev"
      call :ZClean "!U!\.m2\repository\*.lastUpdated" "maven-lastUpdated" "dev"
      call :PruneOld "!U!\.gradle" "*.lock" 7 "GradleLock"
      call :PruneOld "!U!\.gradle" "*.tmp"  7 "GradleTmp"
      call :ZClean "!U!\AppData\Local\node-gyp\Cache" "node-gyp-cache" "dev"
      call :ZClean "!U!\AppData\Local\Microsoft\MSBuild\Cache" "msbuild-cache" "dev"
      call :ZClean "!U!\AppData\Local\NVIDIA\DXCache" "nvidia-dxcache" "dev"
      call :ZClean "!U!\AppData\Local\NVIDIA\GLCache" "nvidia-glcache" "dev"
      call :ZClean "!U!\AppData\Local\AMD\DxCache"    "amd-dxcache"    "dev"
    )
  )
)

if "%SYSTEMPROFILE_TEMP%"=="1" (
  call :ZClean "%SystemRoot%\System32\config\systemprofile\AppData\Local\Temp" "systemprofile-Temp" "system"
  call :ZClean "%SystemRoot%\SysWOW64\config\systemprofile\AppData\Local\Temp" "systemprofile-Temp" "system"
)

call :step "Windows Update files"
call :ZClean "%LocalAppData%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\TempState" "Winget-TempState" "winget"

call :ZClean "%windir%\SoftwareDistribution\Download" "WU-Download" "wu"
call :ZClean "%ProgramData%\Microsoft\Windows\DeliveryOptimization\Cache" "DeliveryOpt" "wu"
if "%WU_RESET%"=="1" (
  if "%DRYRUN%"=="1" ( echo WU-Reset,wu,"%windir%\SoftwareDistribution|%windir%\System32\catroot2",0,WouldReset>>"%CSV%" ) else (
    net stop usosvc /y >>"%LOG%" 2>&1 & net stop cryptsvc /y >>"%LOG%" 2>&1
    ren "%windir%\SoftwareDistribution" "SoftwareDistribution.old-%ts%" >>"%LOG%" 2>&1
    ren "%windir%\System32\catroot2"    "catroot2.old-%ts%"             >>"%LOG%" 2>&1
  )
)

call :PruneOld "%windir%\Logs" "*.log" 14 "SystemLogs"
call :PruneOld "%windir%\Logs" "*.etl" 14 "SystemLogs"
call :PruneOld "%windir%\Logs\CBS" "*.cab" 7 "CBS-Cab"
if "%MOSETUP_LOGS%"=="1" call :PruneOld "%windir%\Logs\MoSetup" "*.log" 30 "MoSetup"
if "%WU_LOGS%"=="1"      call :PruneOld "%windir%\Logs\WindowsUpdate" "*.log" 30 "WU-Logs"
if "%DISM_LOGS%"=="1"    call :PruneOld "%windir%\Logs\DISM" "*.log" 30 "DISM-Logs"

if "%CLEANPREFETCH%"=="1" call :ZClean "%windir%\Prefetch" "Prefetch" "prefetch"
if "%READYBOOT%"=="1"     call :ZClean "%windir%\Prefetch\ReadyBoot" "ReadyBoot" "prefetch"

if "%RECYCLEBIN_REPAIR%"=="1" (
  for /f "skip=1 tokens=1" %%D in ('wmic logicaldisk where "drivetype=3" get deviceid') do if not "%%D"=="" ( if "%DRYRUN%"=="1" ( echo RecycleBin,core,%%D\$Recycle.Bin,0,WouldRepair>>"%CSV%" ) else rd /s /q "%%D\$Recycle.Bin" 2>>"%LOG%" )
) else (
  if "%DRYRUN%"=="1" ( echo RecycleBin,core,All,0,WouldClear>>"%CSV%" ) else powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >>"%LOG%" 2>&1
)

DISM /Online /Cleanup-Image /AnalyzeComponentStore >>"%LOG%" 2>&1
if "%DRYRUN%"=="0" DISM /Online /Cleanup-Image /StartComponentCleanup /Quiet >>"%LOG%" 2>&1
if "%RESETBASE%"=="1" if "%DRYRUN%"=="0" DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase /Quiet >>"%LOG%" 2>&1
if exist "%SystemDrive%\Windows.old" call :ZClean "%SystemDrive%\Windows.old" "Windows.old" "os"
if "%RESTOREHEALTH%"=="1" if "%DRYRUN%"=="0" DISM /Online /Cleanup-Image /RestoreHealth >>"%LOG%" 2>&1
if "%SFC_SCAN%"=="1"       if "%DRYRUN%"=="0" sfc /scannow >>"%LOG%" 2>&1

if "%REBUILDINDEX%"=="1" (
  if "%DRYRUN%"=="1" ( echo SearchIndex,search,"%ProgramData%\Microsoft\Search\Data\Applications\Windows\Windows.edb",0,WouldDelete>>"%CSV%" ) else (
    net stop WSearch >>"%LOG%" 2>&1
    del /f /q "%ProgramData%\Microsoft\Search\Data\Applications\Windows\Windows.edb" >>"%LOG%" 2>&1
    rmdir /s /q "%ProgramData%\Microsoft\Search\Data\Temp" 2>>"%LOG%"
    net start WSearch >>"%LOG%" 2>&1
  )
)
if "%REBUILD_ICON_FONT%"=="1" (
  if "%DRYRUN%"=="1" ( echo IconFont,ux,"%LocalAppData%\IconCache/FontCache",0,WouldRebuild>>"%CSV%" ) else (
    taskkill /f /im explorer.exe >>"%LOG%" 2>&1
    net stop "Windows Font Cache Service" >>"%LOG%" 2>&1
    del /f /q "%LocalAppData%\IconCache.db" 2>>"%LOG%"
    del /f /q "%LocalAppData%\Microsoft\Windows\Explorer\iconcache*" 2>>"%LOG%"
    del /f /q "%windir%\ServiceProfiles\LocalService\AppData\Local\FontCache*" 2>>"%LOG%"
    net start "Windows Font Cache Service" >>"%LOG%" 2>&1
    start explorer.exe
  )
)

if "%PURGE_SHADOW%"=="1" ( if "%DRYRUN%"=="1" ( echo ShadowCopies,system,All,0,WouldDelete>>"%CSV%" ) else ( vssadmin Delete Shadows /All /Quiet >>"%LOG%" 2>&1 ) )
if "%CLEAR_EVT%"=="1" (
  if "%FORCE%"=="0" if "%DRYRUN%"=="0" ( if "%QUIET%"=="0" ( echo [!] Xoá TẤT CẢ Event Logs. Gõ YES để tiếp tục: & set /p EVT=& if /I not "!EVT!"=="YES" (goto :SKIP_EVT) ) )
  if "%DRYRUN%"=="1" ( echo EventLogs,system,All,0,WouldClear>>"%CSV%" ) else ( for /f "tokens=*" %%G in ('wevtutil el') do wevtutil cl "%%G" >>"%LOG%" 2>&1 )
)
:SKIP_EVT

if "%DUMPS%"=="1" ( call :PruneOld "%windir%" "MEMORY.DMP" 0 "MemoryDump" & call :PruneOld "%windir%\Minidump" "*.dmp" 7 "MiniDump" )
if "%SPOOL_CLEAR%"=="1" (
  if "%DRYRUN%"=="1" ( echo Spooler,print,"%windir%\System32\spool\PRINTERS",0,WouldClear>>"%CSV%" ) else ( net stop spooler >>"%LOG%" 2>&1 & del /f /q "%windir%\System32\spool\PRINTERS\*.*" >>"%LOG%" 2>&1 & net start spooler >>"%LOG%" 2>&1 )
)
if "%SLEEPSTUDY_CLEAR%"=="1" call :ZClean "%windir%\System32\SleepStudy" "SleepStudy" "power"
if "%PANTHER_CLEAR%"=="1" ( call :PruneOld "%windir%\Panther" "*.log" 30 "PantherLogs" & call :ZClean "%windir%\Panther\UnattendGC" "Panther-UnattendGC" "setup" )
if "%UPGRADE_LEFTOVERS%"=="1" ( call :ZClean "%SystemDrive%\$Windows.~BT" "UpgradeLeftover" "setup" & call :ZClean "%SystemDrive%\$Windows.~WS" "UpgradeLeftover" "setup" )

if "%MSIX_DELETED%"=="1" (
  set "WA=%ProgramFiles%\WindowsApps\Deleted"
  if exist "%WA%" (
    if "%DRYRUN%"=="1" ( echo WindowsApps-Deleted,uwp,"%WA%",0,WouldDelete>>"%CSV%" ) else (
      takeown /f "%WA%" /r /d y >>"%LOG%" 2>&1
      icacls "%WA%" /grant *S-1-5-32-544:F /t /c >>"%LOG%" 2>&1
      rmdir /s /q "%WA%" >>"%LOG%" 2>&1
    )
  )
)

if "%DEV_CACHES%"=="1" (
  where dotnet  >nul 2>&1 && ( if "%DRYRUN%"=="1" ( echo DevCache,dev,dotnet,0,WouldClear>>"%CSV%" ) else ( dotnet nuget locals all --clear >>"%LOG%" 2>&1 ) )
  where npm     >nul 2>&1 && ( if "%DRYRUN%"=="1" ( echo DevCache,dev,npm,0,WouldClear>>"%CSV%" )    else ( npm cache clean --force       >>"%LOG%" 2>&1 ) )
  where yarn    >nul 2>&1 && ( if "%DRYRUN%"=="1" ( echo DevCache,dev,yarn,0,WouldClear>>"%CSV%" )   else ( yarn cache clean              >>"%LOG%" 2>&1 ) )
  where gradle  >nul 2>&1 && ( if "%DRYRUN%"=="1" ( echo DevCache,dev,gradle,0,WouldClear>>"%CSV%" ) else ( gradle --stop >nul 2>&1 & call :PruneOld "%USERPROFILE%\.gradle" "*.lock" 7 "Gradle" & call :PruneOld "%USERPROFILE%\.gradle" "*.tmp" 7 "Gradle" ) )
  where nuget   >nul 2>&1 && ( if "%DRYRUN%"=="1" ( echo DevCache,dev,nuget,0,WouldClear>>"%CSV%" )  else ( nuget locals all -clear       >>"%LOG%" 2>&1 ) )
)

if "%VS_PCACHE%"=="1" (
  call :ZClean "%ProgramData%\Package Cache" "VS-PackageCache" "vs"
)

if "%ALL_DRIVES_TMP%"=="1" (
  for /f "skip=1 tokens=1" %%D in ('wmic logicaldisk where "drivetype=3" get deviceid') do if not "%%D"=="" call :SweepPatterns "%%D\" "*.tmp|*.bak|*.old|*.dmp" 7
)

if "%TRIM_ALL%"=="1" (
  if "%DRYRUN%"=="1" ( echo TRIM,fs,AllFixed,0,WouldRun>>"%CSV%" ) else (
    for /f "skip=1 tokens=1" %%D in ('wmic logicaldisk where "drivetype=3" get deviceid') do if not "%%D"=="" (
      if "%IsSSD%"=="1" ( defrag %%D /L /O >>"%LOG%" 2>&1 ) else ( defrag %%D /U /V >>"%LOG%" 2>&1 )
    )
  )
)

if "%DNS_NET_RESET%"=="1" (
  if "%DRYRUN%"=="1" ( echo NetReset,net,Stack,0,WouldReset>>"%CSV%" ) else ( netsh winsock reset >>"%LOG%" 2>&1 & netsh int ip reset >>"%LOG%" 2>&1 & ipconfig /flushdns >>"%LOG%" 2>&1 )
)

if "%WSRESET%"=="1" ( if "%DRYRUN%"=="1" ( echo Store,store,WSReset,0,WouldRun>>"%CSV%" ) else ( wsreset.exe -i >>"%LOG%" 2>&1 ) )
if "%SILENTCLEANUP%"=="1" ( if "%DRYRUN%"=="1" ( echo DiskCleanup,sys,SilentCleanup,0,WouldRun>>"%CSV%" ) else ( schtasks /Run /TN "\Microsoft\Windows\DiskCleanup\SilentCleanup" >>"%LOG%" 2>&1 ) )
if "%CLEANMGR%"=="1" ( if "%DRYRUN%"=="1" ( echo CleanMgr,sys,VeryLowDisk,0,WouldRun>>"%CSV%" ) else ( cleanmgr.exe /verylowdisk >>"%LOG%" 2>&1 ) )

if "%WSL_COMPACT%"=="1" (
  call :step "Compact virtual disks (WSL)"
  if "%DRYRUN%"=="1" ( echo WSL,virt,all-vhdx,0,WouldCompact>>"%CSV%" ) else ( wsl --shutdown >nul 2>&1 & for /r "%LocalAppData%\Packages" %%F in (ext4.vhdx) do call :CompactVHDX "%%~fF" )
)
if "%DOCKER_COMPACT%"=="1" (
  call :step "Compact virtual disks (Docker)"
  if "%DRYRUN%"=="1" ( echo Docker,virt,ext4.vhdx,0,WouldCompact>>"%CSV%" ) else ( if exist "%LocalAppData%\Docker\wsl\data\ext4.vhdx" call :CompactVHDX "%LocalAppData%\Docker\wsl\data\ext4.vhdx" )
)
if "%HYPERV_COMPACT%"=="1" (
  call :step "Compact virtual disks (Hyper-V)"
  if "%DRYRUN%"=="1" ( echo HyperV,virt,*.vhdx,0,WouldCompact>>"%CSV%" ) else ( for /r "%Public%\Documents\Hyper-V\Virtual Hard Disks" %%F in (*.vhd *.vhdx) do call :CompactVHDX "%%~fF" )
)

if "%SRU_CLEAR%"=="1" (
  set "SRU=%windir%\System32\sru"
  if "%DRYRUN%"=="1" ( echo SRU,sys,"%SRU%",0,WouldClear>>"%CSV%" ) else (
    net stop DPS >>"%LOG%" 2>&1
    takeown /f "%SRU%" /r /d y >>"%LOG%" 2>&1
    icacls "%SRU%" /grant *S-1-5-32-544:F /t /c >>"%LOG%" 2>&1
    del /f /q "%SRU%\SRUDB.dat" >>"%LOG%" 2>&1
    net start DPS >>"%LOG%" 2>&1
  )
)
if "%WMI_SALVAGE%"=="1" (
  if "%DRYRUN%"=="1" ( echo WMI,sys,SalvageRepository,0,WouldRun>>"%CSV%" ) else ( net stop winmgmt >>"%LOG%" 2>&1 & winmgmt /salvagerepository >>"%LOG%" 2>&1 & net start winmgmt >>"%LOG%" 2>&1 )
)
if "%USN_RESET%"=="1" (
  for /f "skip=1 tokens=1" %%D in ('wmic logicaldisk where "drivetype=3" get deviceid') do (
    if not "%%D"=="" (
      if "%DRYRUN%"=="1" ( echo USN,fs,%%D,0,WouldReset>>"%CSV%" ) else ( fsutil usn deletejournal /D %%D >>"%LOG%" 2>&1 )
    )
  )
)

if "%COMPACT_HOTSPOT%"=="1" (
  call :CompactFolderLZX "%ProgramData%\Package Cache"
  call :CompactFolderLZX "%ProgramData%\Microsoft\Windows\WER\ReportQueue"
  call :CompactFolderLZX "%ProgramData%\Microsoft\Windows\DeliveryOptimization\Cache"
  call :CompactFolderLZX "%ProgramData%\chocolatey\lib-bad"
  call :CompactFolderLZX "%LocalAppData%\Microsoft\Windows\WebCache"
)

for %%S in (wsearch sysmain dosvc bits wuauserv) do net start %%S >>"%LOG%" 2>&1
if "%WU_RESET%"=="1" ( net start cryptsvc >>"%LOG%" 2>&1 )

powershell -NoProfile -Command "Import-Csv -LiteralPath '%CSV%' | ConvertTo-Json -Depth 3 | Out-File -LiteralPath '%JSON%' -Encoding UTF8" >nul 2>&1

:FINALIZE
if not "%LOGS_RETENTION%"=="0" (
  call :PruneOld "%LOGDIR%" "*.log" %LOGS_RETENTION% "CleanupLogs"
  call :PruneOld "%LOGDIR%" "*.csv" %LOGS_RETENTION% "CleanupLogs"
  call :PruneOld "%LOGDIR%" "*.json" %LOGS_RETENTION% "CleanupLogs"
)

echo.
if "%QUIET%"=="0" (
  echo =============== DONE ===============
  echo Log   : "%LOG%"
  echo Report: "%JSON%"
)

rem 
for /f %%A in ('powershell -NoProfile -Command "(Get-PSDrive -Name %SystemDrive:~0,1%).Free"') do set "FreeNow=%%A"

powershell -NoProfile -Command "$b=0;$a=0;[void][double]::TryParse($env:FreeBefore,[ref]$b);[void][double]::TryParse($env:FreeNow,[ref]$a);Write-Host ('Da giai phong: {0:N2} GB' -f (([math]::Max(0,$a-$b))/1GB));Write-Host ('Con trong:    {0:N2} GB' -f ($a/1GB));"

echo ===================================
goto :eof

:SHOW_HELP
  echo.
  echo Windows 11 Deep Cleanup v2
  echo.
  echo Usage: %~n0 ^<options^>
  echo   /safe                Preset an toan (khuyen dung)
  echo   /deep                Dọn sâu tiêu chuẩn
  echo   /omega               Dọn CUC SÂU (rất rủi ro) - se hoi xac nhan
  echo   /analyze             Phan tich, uoc luong dung luong giai phong (DRY-RUN)
  echo   /dry-run             Chay thu, khong xoa
  echo   /quiet               It thong bao
  echo   /exclude:"p1;p2"     Bo qua nhung duong dan khi quet/xoa
  echo   /logs-days:n         Tu xoa log/report cu > n ngay
  echo   --
  echo   /devcaches, /devcaches-x, /vs-pcache, /compact-hotspot ... (tuy chon mo rong)
  echo   /help, -h            Xem huong dan
  echo.
  exit /b 0

:warn
  if "%QUIET%"=="0" echo [!] %*
  call :log WARN %*
  exit /b 0

:RequireAdmin
  >nul 2>&1 net session && ( exit /b 0 )
  echo [!] Can quyen Administrator. Dang nang quyen...
  powershell -NoProfile -ExecutionPolicy Bypass "Start-Process -FilePath '%SCRIPT_PATH%' -Verb RunAs"
  exit /b 1

:log
  rem Write to logfile and to console (unless QUIET)
  set "msg=%*"
  setlocal EnableDelayedExpansion
  set "msg=!msg:"=!"
  endlocal
  >>"%LOG%" echo([%DATE% %TIME%] %msg%
  if "%QUIET%"=="0" (
    echo [%DATE% %TIME%] %msg%
  )
  exit /b 0

:step
  if not defined _STEP_COUNTER set "_STEP_COUNTER=0"
  set /a _STEP_COUNTER+=1 >nul 2>&1
  set "_STEP_NAME=%~1"
  >>"%LOG%" echo([%DATE% %TIME%] STEP %_STEP_COUNTER% %_STEP_NAME%
  if "%QUIET%"=="0" (
    <nul set /p ="[Step %_STEP_COUNTER%] %_STEP_NAME%... "
    echo
  )
  exit /b 0

:Excluded
  set "pp=%~1"
  if not defined EXCLUDE_LIST exit /b 1
  for %%E in (%EXCLUDE_LIST%) do (
    echo "%pp%" | find /I "%%~E" >nul && exit /b 0
  )
  exit /b 1

:ZClean
  set "P=%~1" & set "M=%~2" & set "ID=%~3"
  if not defined P exit /b 0
  call :Excluded "%P%" && ( >>"%CSV%" echo(%M%,%ID%,"%P%",0,SkipExcluded & exit /b 0 )

  rem 
  dir /a:l "%P%" >nul 2>&1
  if not errorlevel 1 (
    call :log ReparsePoint "%P%" [%M%]
    if "%DRYRUN%"=="1" ( echo %M%,%ID%,"%P%",0,WouldDeleteReparse>>"%CSV%" ) else ( rmdir /q "%P%" >>"%LOG%" 2>&1 )
    exit /b 0
  )

  for /f %%S in ('powershell -NoProfile -Command "$p='%~1'; if(Test-Path -LiteralPath $p){(Get-ChildItem -LiteralPath $p -Force -Recurse -ErrorAction SilentlyContinue ^| Measure-Object -Sum Length).Sum}else{0}"') do set "BYTES=%%S"
  if not defined BYTES set "BYTES=0"
  if exist "%P%" (
    call :log Clean "%P%" [%M%] size=%BYTES%
    if "%DRYRUN%"=="1" ( echo %M%,%ID%,"%P%",%BYTES%,WouldDelete>>"%CSV%" ) else ( rd /s /q "%P%" >>"%LOG%" 2>&1 & md "%P%" >nul 2>&1 & echo %M%,%ID%,"%P%",%BYTES%,Deleted>>"%CSV%" )
  ) else ( echo %M%,%ID%,"%P%",0,SkipNotFound>>"%CSV%" )
  exit /b 0

:PruneOld
  set "D=%~1" & set "PAT=%~2" & set "N=%~3" & set "M=%~4"
  if not exist "%D%" ( >>"%CSV%" echo(%M%,prune,"%D%",0,SkipNotFound & exit /b 0 )
  if "%DRYRUN%"=="1" (
    >>"%CSV%" echo(%M%,prune,"%D%\%PAT%",0,WouldDelete_olderThan_%N%days
  ) else (
    forfiles /p "%D%" /s /m %PAT% /d -%N% /c "cmd /c del /q @path" >>"%LOG%" 2>&1
    >>"%CSV%" echo(%M%,prune,"%D%\%PAT%",0,Pruned_olderThan_%N%days
  )
  exit /b 0

:SweepPatterns
  setlocal & set "ROOT=%~1" & set "LIST=%~2" & set "N=%~3"
  for %%p in (%LIST%) do (
    if "%DRYRUN%"=="1" (
      >>"%CSV%" echo(Sweep,fs,"%ROOT%%%p",0,WouldDelete_olderThan_%N%days
    ) else (
      forfiles /p "%ROOT%" /s /m %%p /d -%N% /c "cmd /c echo @path| find /I '%windir%' >nul || echo @path| find /I '%ProgramFiles%' >nul || echo @path| find /I '%ProgramFiles(x86)%' >nul || del /q @path" >>"%LOG%" 2>&1
    )
  )
  endlocal & exit /b 0

:CompactVHDX
  set "V=%~1"
  if not exist "%V%" exit /b 0
  call :log Compact VHDX "%V%"
  if "%DRYRUN%"=="1" ( echo VHDX,virt,"%V%",0,WouldCompact>>"%CSV%" & exit /b 0 )
  powershell -NoProfile -Command "$ok=Get-Command Optimize-VHD -ErrorAction SilentlyContinue; if($ok){Optimize-VHD -Path '%V%' -Mode Full -ErrorAction SilentlyContinue | Out-Null; exit 0}else{exit 1}" >nul 2>&1
  if errorlevel 1 (
    set "_dps=%TEMP%\_compactvhdx.txt"
    >"%_dps%" echo select vdisk file="%V%"
    >>"%_dps%" echo attach vdisk readonly
    >>"%_dps%" echo compact vdisk
    >>"%_dps%" echo detach vdisk
    diskpart /s "%_dps%" >>"%LOG%" 2>&1
    del "%_dps%" >nul 2>&1
  )
  echo VHDX,virt,"%V%",0,Compacted>>"%CSV%"
  exit /b 0

:CompactFolderLZX
  set "CF=%~1"
  if not exist "%CF%" exit /b 0
  call :Excluded "%CF%" && ( >>"%CSV%" echo(Compact,LZX,"%CF%",0,SkipExcluded & exit /b 0 )
  if "%DRYRUN%"=="1" ( >>"%CSV%" echo(Compact,LZX,"%CF%",0,WouldCompactLZX & exit /b 0 )
  call :log Compact(LZX) "%CF%"
  compact.exe /c /s:"%CF%" /i /q /exe:lzx >>"%LOG%" 2>&1
  >>"%CSV%" echo(Compact,LZX,"%CF%",0,CompactedLZX
  exit /b 0
