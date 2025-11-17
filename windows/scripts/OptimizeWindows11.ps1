[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Lite','Recommended','Max','Ultra','UltraX','UltraInfinity','Auto','UltraMaxPower','HighFrequency','LowLatency','PowerEfficient','Balanced+','ServerOptimal')]
    [string]$Preset = 'Recommended',
    [ValidateSet('Default','eSports','Workstation','Creator','Auto')]
    [string]$Profile = 'Default',
    [ValidateSet('Auto','Laptop','Desktop','VM','Server')]
    [string]$Role = 'Auto',
    [switch]$DryRun,
    [switch]$NoReboot,
    [switch]$ReportOnly,
    [switch]$Undo,
    [switch]$AutoProfile,
    [switch]$Analyze,
    [string]$ProfilerPath = $null
)

$ErrorActionPreference = 'Stop'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Admin {
    if (-not (Test-Admin)) {
        throw "Please run PowerShell as Administrator."
    }
}

function Start-ElevatedSession {
    Write-Host "Checking elevation status..." -ForegroundColor Yellow
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    
    if ($p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Already running as Administrator" -ForegroundColor Green
        return $true
    }
    
    Write-Warning "Not running as Administrator. Preparing to relaunch elevated..."
    
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = "powershell.exe"
        $startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            if ($param.Value -is [bool]) {
                if ($param.Value) {
                    $startInfo.Arguments += " -$($param.Key)"
                }
            }
            else {
                $startInfo.Arguments += " -$($param.Key) `"$($param.Value)`""
            }
        }
        
        $startInfo.UseShellExecute = $true
        $startInfo.WorkingDirectory = $PWD.Path
        $startInfo.Verb = "runas"
        
        Write-Host "Launching elevated PowerShell..." -ForegroundColor Yellow
        $process = [System.Diagnostics.Process]::Start($startInfo)
        
        if ($null -eq $process) {
            throw "Failed to start elevated process"
        }
        
        $process.WaitForExit()
        exit $process.ExitCode
    }
    catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}

if (-not (Test-Admin)) {
    Start-ElevatedSession
}

# ============================================================================
# INTELLIGENT PROFILER INTEGRATION
# ============================================================================

function Invoke-IntelligentProfiler {
    <#
    .SYNOPSIS
        Run the Intelligent Profiler and apply recommendations
    #>
    Write-Host "Initializing Intelligent Profiler System..." -ForegroundColor Cyan
    
    # Locate profiler script
    $profilerScript = $ProfilerPath
    if (-not $profilerScript) {
        $possiblePaths = @(
            (Join-Path (Split-Path $PSCommandPath) 'IntelligentProfiler.ps1'),
            (Join-Path $RootDir 'IntelligentProfiler.ps1'),
            'C:\OptimizeW11\IntelligentProfiler.ps1',
            "$env:USERPROFILE\Downloads\IntelligentProfiler.ps1"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $profilerScript = $path
                break
            }
        }
    }
    
    if (-not $profilerScript -or -not (Test-Path $profilerScript)) {
        Write-Warning "Intelligent Profiler script not found. Using manual detection instead."
        return $null
    }
    
    try {
        Write-Host "Running Intelligent Profiler..." -ForegroundColor Yellow
        
        # Execute profiler in current session for data collection
        $profilerOutput = & $profilerScript -Analyze -ErrorAction SilentlyContinue
        
        # Parse and return results (simplified parsing)
        return @{
            Success = $true
            Profiler = $profilerScript
        }
    }
    catch {
        Write-Warning "Intelligent Profiler execution failed: $_"
        return $null
    }
}

function Apply-IntelligentPreset {
    <#
    .SYNOPSIS
        Apply AI-recommended optimization based on profiling
    #>
    param(
        [string]$RecommendedPreset,
        [string]$RecommendedProfile,
        [string]$RecommendedRole
    )
    
    if ([string]::IsNullOrEmpty($RecommendedPreset)) {
        return
    }
    
    Write-Host "Applying Intelligent Profile Recommendations:" -ForegroundColor Yellow
    
    if ($Preset -eq 'Auto') {
        $Preset = $RecommendedPreset
        Write-Host "  Preset: $Preset" -ForegroundColor Green
    }
    
    if ($Profile -eq 'Auto') {
        $Profile = $RecommendedProfile
        Write-Host "  Profile: $Profile" -ForegroundColor Green
    }
    
    if ($Role -eq 'Auto') {
        $Role = $RecommendedRole
        Write-Host "  Role: $Role" -ForegroundColor Green
    }
}

# Apply intelligent profiling if requested
if ($AutoProfile -or $Preset -eq 'Auto' -or $Profile -eq 'Auto') {
    $profilerResult = Invoke-IntelligentProfiler
    if ($profilerResult -and $profilerResult.Success) {
        # Recommendations would be extracted from profiler output
        # For now, apply safe defaults based on GetRoleAuto
        Apply-IntelligentPreset -RecommendedPreset 'Recommended' -RecommendedProfile 'Default' -RecommendedRole (GetRoleAuto)
    }
}

if ($Analyze) {
    Write-Host "Running system analysis and profiling..." -ForegroundColor Yellow
    $profilerResult = Invoke-IntelligentProfiler
    
    if ($profilerResult -and $profilerResult.Success) {
        Write-Host "Analysis complete. Review recommendations above." -ForegroundColor Green
    } else {
        Write-Host "Analysis complete via built-in detection." -ForegroundColor Cyan
    }
    
    Stop-Transcript | Out-Null
    exit 0
}


$RootDir   = 'C:\OptimizeW11'
$LogDir    = Join-Path $RootDir 'logs'
$BackupDir = Join-Path $RootDir 'backup'
$ReportDir = Join-Path $RootDir 'reports'
$StateDir  = Join-Path $RootDir 'state'
$Now       = Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -Force -ItemType Directory -Path $RootDir,$LogDir,$BackupDir,$ReportDir,$StateDir | Out-Null
$LogFile   = Join-Path $LogDir "infinite-$Preset-$Profile-$Role-$Now.log"
Start-Transcript -Path $LogFile -Force | Out-Null
$WhatIf = $false
if ($PSBoundParameters.ContainsKey('DryRun')) { $WhatIf = $true }
function Set-RegistryValueWithFallback {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]
        [ValidateSet('String','DWord','QWord','Binary','MultiString','ExpandString')]
        $Type,
        [Parameter(Mandatory)]$Value,
        [string]$FallbackPath
    )

    $success = $false
    $error = $null

    $primaryPath = $Path -replace '^(HKLM|HKCU)\\', '$1:\'
    if ($FallbackPath) {
        $FallbackPath = $FallbackPath -replace '^(HKLM|HKCU)\\', '$1:\'
    }

    try {
        if (-not (Test-Path -Path $primaryPath)) {
            New-Item -Force -Path $primaryPath -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -Path $primaryPath -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        $success = $true
    }
    catch {
        $error = $_
        Write-Verbose "Primary path failed: $($_.Exception.Message)"
        
        if ($FallbackPath) {
            try {
                if (-not (Test-Path -Path $FallbackPath)) {
                    New-Item -Force -Path $FallbackPath -ErrorAction Stop | Out-Null
                }
                Set-ItemProperty -Path $FallbackPath -Name $Name -Value $Value -Type $Type -ErrorAction Stop
                $success = $true
                $error = $null
            }
            catch {
                $error = $_
                Write-Verbose "Fallback path failed: $($_.Exception.Message)"
            }
        }

        if (-not $success) {
            try {
                $regPath = $primaryPath -replace ':\\', '\'
                $regArgs = @(
                    'add',
                    $regPath,
                    '/v', $Name,
                    '/t', "REG_$($Type.ToUpper())",
                    '/d', $Value,
                    '/f'
                )
                $null = & reg.exe @regArgs 2>&1
                $success = $true
            }
            catch {
                $error = $_
                Write-Verbose "Reg.exe fallback failed: $($_.Exception.Message)"
            }
        }
    }

    if (-not $success -and $error) {
        throw $error
    }
    return $success
}


function Safe-Run {
  param([Parameter(Mandatory)][string]$FilePath,[string[]]$Arguments)
  if ($PSCmdlet.ShouldProcess($FilePath,"Run $($Arguments -join ' ')")) { & $FilePath @Arguments }
}
function Preflight {
  Write-Host "Preflight checks..." -ForegroundColor Yellow
  Assert-Admin
  $isLaptop = (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) -ne $null
  if ($isLaptop) {
    try {
      $bat = (Get-CimInstance Win32_Battery).EstimatedChargeRemaining
      if ($bat -lt 30) { Write-Warning "Battery under 30 percent. Plug in before optimizing." }
    } catch {}
  }
  $sysDrive = Get-PSDrive -Name C
  if ($sysDrive.Free -lt 5GB) { Write-Warning "System drive free space is less than 5 GB. Consider cleanup first." }
  if (-not (Get-Service -Name wuauserv -ErrorAction SilentlyContinue)) { Write-Warning "Windows Update service missing?" }
  if (-not (Get-Service -Name WinDefend -ErrorAction SilentlyContinue)) { Write-Warning "Microsoft Defender missing. Defender steps will be skipped." }
}
function EnableSystemRestore { try { Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue } catch {} }
function NewRestorePointSafe {
  Write-Host "Creating System Restore Point..." -ForegroundColor Yellow
  try { EnableSystemRestore; Checkpoint-Computer -Description "Infinite-$Preset-$Profile-$Role-$Now" -RestorePointType "MODIFY_SETTINGS" }
  catch { Write-Warning "Failed to create Restore Point: $_" }
}
function BackupRegistry {
  Write-Host "Exporting registry backups..." -ForegroundColor Yellow
  $exports = @(
    @{Path='HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name="HKCU_Explorer_Advanced-$Now.reg"},
    @{Path='HKCU\Software\Microsoft\Windows\CurrentVersion\Search'; Name="HKCU_Search-$Now.reg"},
    @{Path='HKLM\SOFTWARE\Policies\Microsoft\Windows'; Name="HKLM_Policies_Windows-$Now.reg"},
    @{Path='HKLM\SYSTEM\CurrentControlSet\Control\FileSystem'; Name="HKLM_FileSystem-$Now.reg"},
    @{Path='HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'; Name="HKLM_LanmanWorkstation-$Now.reg"},
    @{Path='HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'; Name="HKLM_GraphicsDrivers-$Now.reg"}
  )
  foreach ($e in $exports) {
    try { reg export $e.Path (Join-Path $BackupDir $e.Name) /y | Out-Null } catch { Write-Warning $_ }
  }
}
function GetRoleAuto {
  if ($Role -ne 'Auto') { return $Role }
  try {
    $vm = (Get-CimInstance Win32_ComputerSystem).Model -match 'Virtual|VMware|KVM|VirtualBox|Hyper-V'
    if ($vm) { return 'VM' }
    $hasBattery = (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) -ne $null
    if ($hasBattery) { return 'Laptop' }
    $cs = Get-CimInstance Win32_ComputerSystem
    $upNics = (Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq 'Up'}).Count
    if ($cs.PartOfDomain -and $upNics -ge 2) { return 'Server' }
    return 'Desktop'
  } catch { return 'Desktop' }
}
function GetDriveInfo {
  Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    [pscustomobject]@{
      Name=$_.Name; Root=$_.Root;
      UsedGB=[math]::Round(($_.Used/1GB),2);
      FreeGB=[math]::Round(($_.Free/1GB),2);
      TotalGB=[math]::Round(($_.Used+$_.Free)/1GB,2)
    }
  }
}
function GetStartupApps {
  $paths=@(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
  )
  foreach($p in $paths){
    if(Test-Path $p){ Get-ItemProperty $p | Select-Object PSPath,* -ExcludeProperty PS* }
  }
}
function GetServicesState { Get-Service | Select-Object Name,Status,StartType }
function GetTasksState  { Get-ScheduledTask | Select-Object TaskPath,TaskName,State,Enabled }
function GetNetworkState {
  $nics = Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object InterfaceAlias,InterfaceIndex,InterfaceMetric,Dhcp
  $nbt  = Get-WmiObject Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object {$_.IPEnabled} | Select-Object Description,TcpipNetbiosOptions
  [pscustomobject]@{Nics=$nics; NetBIOS=$nbt}
}
function NewReport {
  param([string]$Phase,[hashtable]$Data,[hashtable]$Diff)
  $file = Join-Path $ReportDir "infinite-$Phase-$Preset-$Profile-$Role-$Now.html"
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("<html><head><meta charset='utf-8'><title>Infinite $Phase</title><style>body{font-family:Segoe UI,Arial;margin:20px}table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:6px}h2{margin-top:0}</style></head><body>")
  [void]$sb.AppendLine("<h2>Optimize Infinite - $Phase</h2><p><b>Preset:</b> $Preset | <b>Profile:</b> $Profile | <b>Role:</b> $Role | <b>Time:</b> $Now</p>")
  foreach($k in $Data.Keys){
    $v = $Data[$k]
    [void]$sb.AppendLine("<h3>$k</h3>")
    if ($v -is [System.Collections.IEnumerable] -and -not ($v -is [string])) {
      $first = $v | Select-Object -First 1
      if ($null -ne $first) {
        [void]$sb.AppendLine("<table><tr>")
        foreach($p in $first.PSObject.Properties.Name){ [void]$sb.AppendLine("<th>$p</th>") }
        [void]$sb.AppendLine("</tr>")
        foreach($row in $v){
          [void]$sb.AppendLine("<tr>")
          foreach($p in $row.PSObject.Properties.Name){ [void]$sb.AppendLine("<td>$($row.$p)</td>") }
          [void]$sb.AppendLine("</tr>")
        }
        [void]$sb.AppendLine("</table>")
      } else { [void]$sb.AppendLine("<i>(empty)</i>") }
    } else { [void]$sb.AppendLine("<pre>$($v | Out-String)</pre>") }
  }
  if ($Diff) { [void]$sb.AppendLine("<h3>Diff</h3><pre>$($Diff['Text'])</pre>") }
  [void]$sb.AppendLine("</body></html>")
  Set-Content -Path $file -Value $sb.ToString() -Encoding UTF8
  return $file
}
function MakeDiffText {
  param($Before,$After)
  $t = New-Object System.Text.StringBuilder
  $b = ($Before | Out-String).Trim().Split("`n")
  $a = ($After  | Out-String).Trim().Split("`n")
  $max = [math]::Max($b.Count,$a.Count)
  for($i=0;$i -lt $max;$i++){
    $l = if ($i -lt $b.Count -and $b[$i] -ne $null) { ($b[$i]).TrimEnd() } else { "" }
    $r = if ($i -lt $a.Count -and $a[$i] -ne $null) { ($a[$i]).TrimEnd() } else { "" }
    if ($l -ne $r) { [void]$t.AppendLine("[-] $l"); [void]$t.AppendLine("[+] $r"); [void]$t.AppendLine("") }
  }
  return $t.ToString()
}
function Set-RegistryKey {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('String','DWord','QWord','Binary','MultiString','ExpandString')]$Type,
        [Parameter(Mandatory)]$Value,
        [string]$FallbackPath
    )
    
    try {
        if ($WhatIf) {
            Write-Verbose "WhatIf: Would set $Path\$Name = $Value (Type: $Type)"
            return $true
        }

        Set-RegistryValueWithFallback -Path $Path -Name $Name -Type $Type -Value $Value -FallbackPath $FallbackPath
        return $true
    }
    catch {
        $msg = $_.Exception.Message
        if ($_.Exception.HResult) {
            $msg += " (0x$($_.Exception.HResult.ToString('X8')))"
        }
        Write-Warning "Registry write failed at ${Path}\${Name}: $msg"
        return $false
    }
}


function UIPrivacy {
  Write-Host "Applying UI and Privacy tweaks..." -ForegroundColor Green
  
  $success = $true
  $failedKeys = @()

  function ApplyRegistryChange {
    param($Path, $Name, $Type, $Value, $Description)
    $result = Set-RegistryKey -Path $Path -Name $Name -Type $Type -Value $Value
    if (-not $result) {
      $success = $false
      $failedKeys += "$Description ($Path\$Name)"
    }
    return $result
  }

  Write-Host "  Applying visual effects settings..." -ForegroundColor Yellow
  ApplyRegistryChange -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
    -Name "VisualFXSetting" -Type DWord -Value 2 -Description "Visual Effects"
  
  Write-Host "  Applying transparency settings..." -ForegroundColor Yellow
  ApplyRegistryChange -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
    -Name "EnableTransparency" -Type DWord -Value 0 -Description "Transparency Effects"
  
  Write-Host "  Applying taskbar settings..." -ForegroundColor Yellow
  
  $taskbarSettings = @(
    @{ 
      Name = "TaskbarAnimations"; 
      Value = 0; 
      Description = "Taskbar Animations";
      Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    },
    @{ 
      Name = "HideFileExt"; 
      Value = 0; 
      Description = "File Extensions";
      Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    },
    @{ 
      Name = "LaunchTo"; 
      Value = 1; 
      Description = "Explorer Launch Path";
      Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    },
    @{ 
      Name = "TaskbarDa"; 
      Value = 0; 
      Description = "Taskbar DA";
      Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";
      FallbackPath = "HKCU:\Software\Microsoft\Windows\Current\Explorer\Advanced";
      AlternativePaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TaskbarDa"
      )
    },
    @{ 
      Name = "TaskbarMn"; 
      Value = 0; 
      Description = "Taskbar MN";
      Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    }
  )

  foreach ($setting in $taskbarSettings) {
    Write-Host "    Setting $($setting.Description)..." -ForegroundColor Yellow -NoNewline
    
    try {
      $success = $false
      try {
        Set-RegistryValueWithFallback -Path $setting.Path -Name $setting.Name -Type DWord -Value $setting.Value
        $success = $true
      }
      catch {
        Write-Verbose "Primary path failed: $($_.Exception.Message)"
        if ($setting.ContainsKey('AlternativePaths')) {
          foreach ($altPath in $setting.AlternativePaths) {
            try {
              Write-Verbose "Trying alternative path: $altPath"
              Set-RegistryValueWithFallback -Path $altPath -Name $setting.Name -Type DWord -Value $setting.Value
              $success = $true
              break
            }
            catch {
              Write-Verbose "Alternative path failed: $($_.Exception.Message)"
              continue
            }
          }
        }
      }
      
      if ($success) {
        Write-Host " OK" -ForegroundColor Green
      }
      else {
        if ($WhatIf) {
          Write-Host " (WhatIf)" -ForegroundColor Yellow
        }
        else {
          Write-Host " Failed" -ForegroundColor Red
          Write-Warning "Could not set $($setting.Description) in any available location"
        }
      }
    }
    catch {
      Write-Host " Error" -ForegroundColor Red
      Write-Warning "Failed to set $($setting.Description): $($_.Exception.Message)"
      if ($_.Exception.HResult) {
        Write-Warning "Error code: 0x$($_.Exception.HResult.ToString('X8'))"
      }
    }
  }
  
  Write-Host "  Applying privacy settings..." -ForegroundColor Yellow
  ApplyRegistryChange -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" `
    -Name "Enabled" -Type DWord -Value 0 -Description "Advertising ID"
  ApplyRegistryChange -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" `
    -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Type DWord -Value 0 -Description "Diagnostic Data"
  $policyOk = $false
  try {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Force | Out-Null
    $policyOk = Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Type DWord -Value 0
    $policyOk = $policyOk -and (Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DOUploadMode" -Type DWord -Value 0)
  } catch {
    Write-Warning "Policy path for Delivery Optimization is locked. Falling back to non-policy settings."
    $policyOk = $false
  }

  if (-not $policyOk) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" -Force | Out-Null
    Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" -Name "DownloadMode" -Type DWord -Value 0 | Out-Null
    Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" -Name "DOMaxUploadBandwidth" -Type DWord -Value 0 | Out-Null
    Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" -Name "DOMaxUploadBandwidthDays" -Type DWord -Value 0 | Out-Null
  }
}


function PowerUltimate {
  Write-Host "Setting Ultimate Performance plan and CPU micro tuning..." -ForegroundColor Green
  try{
    $ult = (powercfg -list) 2>$null | Select-String "Ultimate Performance"
    if (-not $ult) { Safe-Run -FilePath "powercfg.exe" -Arguments @("/duplicatescheme","e9a42b02-d5df-448d-aa00-03f14749eb61") }
    $scheme = (powercfg -list) | Select-String "Ultimate Performance" | ForEach-Object { ($_ -split '\s+')[3].Trim('()') } | Select-Object -First 1
    if ($scheme) {
      Safe-Run -FilePath "powercfg.exe" -Arguments @("/setactive",$scheme)
      switch ($Profile) {
        'eSports' {
          powercfg -setacvalueindex $scheme SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
          powercfg -setacvalueindex $scheme SUB_PROCESSOR IDLEDISABLE 1 | Out-Null
          powercfg -setacvalueindex $scheme SUB_PROCESSOR PERFBOOSTMODE 2 | Out-Null
        }
        'Workstation' {
          powercfg -setacvalueindex $scheme SUB_PROCESSOR PROCTHROTTLEMIN 5 | Out-Null
          powercfg -setacvalueindex $scheme SUB_PROCESSOR IDLEDISABLE 0 | Out-Null
          powercfg -setacvalueindex $scheme SUB_PROCESSOR PERFBOOSTMODE 1 | Out-Null
        }
        'Creator' {
          powercfg -setacvalueindex $scheme SUB_PROCESSOR PROCTHROTTLEMIN 20 | Out-Null
          powercfg -setacvalueindex $scheme SUB_PROCESSOR PERFBOOSTMODE 2 | Out-Null
        }
        Default { }
      }
      powercfg -setacvalueindex $scheme SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
      powercfg -S $scheme | Out-Null
    }
  } catch { Write-Warning $_ }
}
function ServicesTune {
  Write-Host "Tuning services..." -ForegroundColor Green
  (Get-Service | Select-Object Name,Status,StartType) | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $StateDir "services-before-$Now.json") -Encoding UTF8
  $common=@("XblAuthManager","XblGameSave","XboxNetApiSvc","RetailDemo","RemoteRegistry")
  foreach($svc in $common){
    try {
      if($PSCmdlet.ShouldProcess($svc,"Set-Service Manual")){ Set-Service -Name $svc -StartupType Manual }
    } catch {}
  }
  if ($Role -in @('Desktop','Laptop')) {
    try {
      $ssd = (Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object {$_.MediaType -eq 'SSD'}).Count -gt 0
      if ($ssd) { $mode = 'Automatic' } else { $mode = 'Manual' }
      if ($PSCmdlet.ShouldProcess("SysMain","Set-Service $mode")) { Set-Service -Name "SysMain" -StartupType $mode }
    } catch {}
  }
  if ($Role -eq 'VM') {
    foreach($svc in @("bthserv","Spooler")){ try { Set-Service -Name $svc -StartupType Manual } catch {} }
  }
}
function TasksTune {
  Write-Host "Tuning scheduled tasks..." -ForegroundColor Green
  Get-ScheduledTask | Select-Object TaskPath,TaskName,State,Enabled | Export-Csv (Join-Path $StateDir "tasks-before-$Now.csv") -NoTypeInformation -Encoding UTF8
  $tasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
  )
  foreach($t in $tasks){
    try{
      if ($PSCmdlet.ShouldProcess($t,"Disable-ScheduledTask")) {
        $task = Get-ScheduledTask -TaskPath ($t.Substring(0,$t.LastIndexOf('\')+1)) -TaskName ($t.Split('\')[-1]) -ErrorAction SilentlyContinue
        if ($task) { Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath | Out-Null }
      }
    } catch {}
  }
}
function StorageTune {
  Write-Host "Storage Sense, temp cleanup, Delivery Optimization cache, LongPaths..." -ForegroundColor Green
  Set-RegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "01" -Type DWord -Value 1
  Set-RegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "StoragePolicyEnabled" -Type DWord -Value 1
  try {
    if ($PSCmdlet.ShouldProcess("DeliveryOptimization","Clear cache")) { Clear-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue }
  } catch {}
  foreach($t in @($env:TEMP,$env:TMP,"C:\Windows\Temp")){
  if (Test-Path $t) {
    if ($PSCmdlet.ShouldProcess($t,"clear temp")) {
      Get-ChildItem -Path $t -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }
  }
}
  Set-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Type DWord -Value 1
}
function SearchIndexTune {
  Write-Host "Search Index excludes..." -ForegroundColor Green
  $exclude=@("C:\Build","C:\Dev","D:\Build","D:\Dev","C:\Games","D:\Games") | Where-Object { Test-Path $_ }
  if ($exclude) {
    Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "PreventIndexingCertainPaths" -Type DWord -Value 1
    $exclude | Set-Content (Join-Path $LogDir "SearchIndex-Excludes-$Now.txt") -Encoding UTF8
  }
}
function DefenderExclusions {
  Write-Host "Defender exclusions (dev and build paths)..." -ForegroundColor Green
  $hasMpCmdlets = Get-Command Add-MpPreference -ErrorAction SilentlyContinue
  if (-not $hasMpCmdlets) {
    Write-Warning "Defender cmdlets not available on this system. Skipping exclusions."
    return
  }
  $svc = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
  if (-not $svc) {
    Write-Warning "Windows Defender service not found. Skipping exclusions."
    return
  }
  if ($svc.Status -ne 'Running') {
    try {
      if ($svc.StartType -eq 'Disabled') {
        try { Set-Service -Name WinDefend -StartupType Manual -ErrorAction Stop } catch {}
      }
      Start-Service -Name WinDefend -ErrorAction Stop
    } catch {
      Write-Warning "Windows Defender is not running and could not be started (possibly disabled by policy or another AV). Skipping exclusions. $($_.Exception.Message)"
      return
    }
  }
  $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
  if ($mp) {
    if (-not $mp.AntispywareEnabled -or -not $mp.RealTimeProtectionEnabled) {
      Write-Warning "Defender real-time protection is disabled (policy/other AV). Skipping exclusions."
      return
    }
  }
  $dirs = @("$env:USERPROFILE\source","$env:USERPROFILE\projects","C:\Build","C:\Dev","D:\Build","D:\Dev") | Where-Object { Test-Path $_ }
  if (-not $dirs -or $dirs.Count -eq 0) {
    Write-Host "No dev/build directories found to exclude."
    return
  }
  foreach ($d in $dirs) {
    try {
      Add-MpPreference -ExclusionPath $d -ErrorAction Stop
      Write-Host "Added Defender exclusion: $d"
    } catch {
      Write-Warning ("Failed exclusion for {0}: {1}" -f $d, $_.Exception.Message)
    }
  }
}
function NetworkHardening {
  Write-Host "Network hardening and low-latency TCP..." -ForegroundColor Green
  try {
    [pscustomobject]@{
      Nics      = (Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue)
      TcpGlobal = (netsh int tcp show global)
    } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $StateDir "net-before-$Now.json") -Encoding UTF8
  } catch { }
  try {
    Ensure-RegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
    Set-RegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name 'EnableMulticast' -Type DWord -Value 0
  } catch {
    Write-Warning "LLMNR policy change skipped (policy-locked or no permission): $($_.Exception.Message)"
  }
  try {
    Get-WmiObject Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue |
      Where-Object { $_.IPEnabled } |
      ForEach-Object {
        try { $_.SetTcpipNetbios(2) | Out-Null } catch { }
      }
  } catch {
    Write-Warning "NetBIOS setting could not be changed on some adapters."
  }
  try {
    Ensure-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    Set-RegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name 'AutoDetect' -Type DWord -Value 0
  } catch {
    Write-Warning "WPAD AutoDetect tweak skipped: $($_.Exception.Message)"
  }
  foreach ($cmd in @(
    'netsh int tcp set global ecncapability=disabled',
    'netsh int tcp set global timestamps=disabled',
    'netsh int tcp set global rss=enabled',
    'netsh int tcp set global rsc=enabled',
    'netsh int tcp set global autotuninglevel=normal'
  )) {
    try { iex $cmd | Out-Null } catch { Write-Warning "TCP tweak skipped: $cmd" }
  }
  if ($Profile -eq 'eSports') {
    try {
      Ensure-RegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
      Set-RegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Type DWord -Value 0
      Ensure-RegistryKey -Path 'HKCU:\System\GameConfigStore'
      Set-RegistryKey -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Type DWord -Value 0
    } catch {
      Write-Warning "GameDVR policy tweak skipped: $($_.Exception.Message)"
    }
  }
}
function GamingGraphics {
  Write-Host "Game Mode and HAGS..." -ForegroundColor Green
  Set-RegistryKey -Path "HKCU\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Type DWord -Value 1
  Set-RegistryKey -Path "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Type DWord -Value 2
}
function OptionalFeatures {
  Write-Host "Disabling optional features (safe)..." -ForegroundColor Green
  $toDisable=@("FaxServicesClientPackage","WorkFolders-Client","XPSViewer")
  foreach($f in $toDisable){
    try { Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction SilentlyContinue | Out-Null } catch {}
  }
}
function RemoveBloat {
    param([string]$Level)
    Write-Host "Removing UWP bloat ($Level) with keep-list..." -ForegroundColor Green
    
    $keep = @()
    $keepFile = Join-Path $RootDir "keeplist.txt"
    if (Test-Path $keepFile) {
        $keep = Get-Content $keepFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        Write-Verbose "Loaded $(($keep | Measure-Object).Count) entries from keeplist"
    }
    
    $common = @(
        "Microsoft.BingNews",
        "Microsoft.BingWeather",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.People",
        "Microsoft.Todos",
        "Microsoft.WindowsAlarms",
        "Microsoft.WindowsMaps",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo"
    )
    
    $extra = @(
        "Microsoft.Microsoft3DViewer",
        "Microsoft.Paint3D",
        "Microsoft.MicrosoftStickyNotes",
        "Microsoft.MixedReality.Portal",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.YourPhone",
        "Microsoft.549981C3F5F10"
    )
    
    $ultra = @("Microsoft.News")
    
    $pkgs = switch ($Level) {
        'Lite' { $common }
        'Recommended' { $common + $extra }
        'Max' { $common + $extra + $ultra }
        'Ultra' { $common + $extra + $ultra }
        'UltraX' { $common + $extra + $ultra }
        'UltraInfinity' { $common + $extra + $ultra }
    }
    
    foreach ($id in $pkgs) {
        if ($keep -contains $id) {
            Write-Host "  Keeping per keeplist: $id" -ForegroundColor Yellow
            continue
        }
        
        Write-Host "  Processing $id..." -ForegroundColor Cyan -NoNewline
        
        try {
            if ($PSCmdlet.ShouldProcess($id, "Remove UWP package")) {
                $prov = Get-AppxProvisionedPackage -Online -ErrorAction Stop | 
                    Where-Object { $_.DisplayName -eq $id }
                
                if ($prov) {
                    Write-Verbose "  Removing provisioned package: $($prov.PackageName)"
                    Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null
                }
                
                $pkgs = Get-AppxPackage -Name $id -AllUsers -ErrorAction Stop
                if ($pkgs) {
                    foreach ($pkg in $pkgs) {
                        Write-Verbose "  Removing package: $($pkg.PackageFullName)"
                        $pkg | Remove-AppxPackage -AllUsers -ErrorAction Stop
                    }
                }
                
                if (Get-Command winget -ErrorAction SilentlyContinue) {
                    winget uninstall --id $id --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
                }
                
                Write-Host " OK" -ForegroundColor Green
            }
            else {
                Write-Host " Skipped (WhatIf)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host " Failed" -ForegroundColor Red
            Write-Warning "Failed to remove $id : $($_.Exception.Message)"
            if ($_.Exception.HResult) {
                Write-Warning "Error code: 0x$($_.Exception.HResult.ToString('X8'))"
            }
        }
  }
  if ($Level -in @('UltraX','UltraInfinity')) {
    try{
      if ($PSCmdlet.ShouldProcess("OneDrive","Uninstall")) {
        $od = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
        if (-not (Test-Path $od)) { $od = "$env:SystemRoot\System32\OneDriveSetup.exe" }
        if (Get-Process OneDrive -ErrorAction SilentlyContinue) { Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue }
        if (Test-Path $od) { & $od /uninstall | Out-Null }
      }
    } catch { Write-Warning "OneDrive uninstall failed: $($_)" }
  }
}
function DismCleanup {
  Write-Host "DISM component cleanup..." -ForegroundColor Green
  try{
    if ($PSCmdlet.ShouldProcess("DISM","/StartComponentCleanup")) { Dism.exe /Online /Cleanup-Image /StartComponentCleanup | Out-Null }
    if ($Preset -in @('Ultra','UltraX','UltraInfinity')) {
      if ($PSCmdlet.ShouldProcess("DISM","/ResetBase")) { Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null }
    }
  } catch { Write-Warning $_ }
}
function ScheduleTrim {
  Write-Host "Scheduling SSD TRIM..." -ForegroundColor Green
  try{
    $action=New-ScheduledTaskAction -Execute 'defrag.exe' -Argument 'C: /L'
    $trigger=New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 03:30
    $principal=New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "SSD-Weekly-Retrim" -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
  } catch {}
}
function ScheduleMonthly {
  Write-Host "Scheduling monthly maintenance..." -ForegroundColor Green
  try{
    $action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -Command "Dism.exe /Online /Cleanup-Image /StartComponentCleanup; Clear-DeliveryOptimizationCache -Force"'
    $trigger=New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At 03:00
    $principal=New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "Monthly-Maintenance-Infinite" -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
  } catch {}
}
function RoleProfileTweaks {
  Write-Host "Applying role and profile tweaks..." -ForegroundColor Green
  if ($Role -eq 'Server' -or $Role -eq 'VM') { Set-RegistryKey -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Type DWord -Value 0 }
  if ($Role -eq 'Laptop') { Set-RegistryKey -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Type DWord -Value 1 }
  switch ($Profile) {
    'eSports' {
      New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Force | Out-Null
      Set-RegistryKey -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Type DWord -Value 1
    }
    'Workstation' { }
    'Creator' {
      Set-RegistryKey -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Type DWord -Value 0
    }
    Default { }
  }
}
function PagefileSystemManaged {
  Write-Host "Setting pagefile to System Managed..." -ForegroundColor Green
  try {
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $computerSystem | Set-CimInstance -Property @{AutomaticManagedPagefile = $true} -ErrorAction Stop
    Write-Host "  Pagefile setting applied successfully" -ForegroundColor Green
  }
  catch {
    Write-Warning "Failed to set system-managed pagefile: $($_.Exception.Message)"
  }
}
function OptionalSafeOff { OptionalFeatures }
function UndoLight {
  Write-Host "UNDO (lightweight)..." -ForegroundColor Yellow
  Get-ChildItem $BackupDir -Filter "*.reg" | Sort-Object LastWriteTime | ForEach-Object {
    try { if ($PSCmdlet.ShouldProcess($_.FullName,"reg import")) { reg import "$($_.FullName)" | Out-Null } } catch { Write-Warning $_ }
  }
  $lastSvc = Get-ChildItem $StateDir -Filter "services-before-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($lastSvc) {
    try {
      $svcs = Get-Content $lastSvc.FullName | ConvertFrom-Json
      foreach($s in $svcs){
        try {
          if ($PSCmdlet.ShouldProcess($s.Name,"Set-Service $($s.StartType)")) {
            Set-Service -Name $s.Name -StartupType $s.StartType -ErrorAction SilentlyContinue
          }
        } catch {}
      }
    } catch {}
  }
  $lastTasks = Get-ChildItem $StateDir -Filter "tasks-before-*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($lastTasks) {
    try{
      $rows = Import-Csv $lastTasks.FullName
      foreach($r in $rows){
        try {
          if ($r.Enabled -eq 'True') {
  if ($PSCmdlet.ShouldProcess("$($r.TaskPath)$($r.TaskName)","Enable-ScheduledTask")) {
    Enable-ScheduledTask -TaskName $r.TaskName -TaskPath $r.TaskPath | Out-Null
  }
}
        } catch {}
      }
    } catch {}
  }
  Write-Host "UNDO completed. Removed UWP apps must be reinstalled from Microsoft Store if needed."
}
try {
  $DetectedRole = GetRoleAuto
  if ($Role -eq 'Auto') { $Role = $DetectedRole }
  if ($Undo) { UndoLight; Stop-Transcript | Out-Null; return }
  Preflight
  $Before = @{
    Drives      = GetDriveInfo
    StartupApps = GetStartupApps
    Services    = GetServicesState
    Tasks       = GetTasksState
    PowerPlan   = (powercfg -getactivescheme) 2>$null
    NetState    = GetNetworkState
    AppxProv    = (Get-AppxProvisionedPackage -Online | Select-Object PackageName,DisplayName)
  }
  $ReportBefore = NewReport -Phase 'Before' -Data $Before -Diff $null
  Write-Host "BEFORE REPORT: $ReportBefore" -ForegroundColor Cyan
  if (-not $ReportOnly) {
    if (-not $WhatIf) { NewRestorePointSafe; BackupRegistry } else { Write-Host "[DryRun] Skipping Restore Point and backups." }
    UIPrivacy
    PowerUltimate
    ServicesTune
    TasksTune
    StorageTune
    SearchIndexTune
    DefenderExclusions
    OptionalSafeOff
    NetworkHardening
    GamingGraphics
    PagefileSystemManaged
    RoleProfileTweaks
    RemoveBloat -Level $Preset
    DismCleanup
    ScheduleTrim
    ScheduleMonthly
  } else {
    Write-Host "ReportOnly - no changes will be applied." -ForegroundColor Yellow
  }
  $After = @{
    Drives      = GetDriveInfo
    StartupApps = GetStartupApps
    Services    = GetServicesState
    Tasks       = GetTasksState
    PowerPlan   = (powercfg -getactivescheme) 2>$null
    NetState    = GetNetworkState
    AppxProv    = (Get-AppxProvisionedPackage -Online | Select-Object PackageName,DisplayName)
  }
  $diffText  = MakeDiffText -Before ($Before.Services | Format-Table -AutoSize | Out-String) -After ($After.Services | Format-Table -AutoSize | Out-String)
  $diffText += "`n---- TASKS ----`n"
  $diffText += MakeDiffText -Before ($Before.Tasks | Format-Table -AutoSize | Out-String) -After ($After.Tasks | Format-Table -AutoSize | Out-String)
  $Diff = @{ Text = $diffText }
  $ReportAfter = NewReport -Phase 'After' -Data $After -Diff $Diff
  Write-Host "`nDONE. AFTER REPORT: $ReportAfter" -ForegroundColor Cyan
  Write-Host "Log:    $LogFile"
  Write-Host "Backup: $BackupDir"
  Write-Host "State:  $StateDir"
} catch {
  Write-Error "Error: $_"
} finally {
  Stop-Transcript | Out-Null
}
if (-not $NoReboot -and -not $ReportOnly) {
  Write-Host "`nReboot recommended. Auto-rebooting in 20 seconds... (use -NoReboot to skip)"
  for ($i=20;$i -gt 0;$i--){ Write-Host -NoNewline "$i "; Start-Sleep 1 }
  if (-not $WhatIf) { Restart-Computer }
} else {
  Write-Host "You selected -NoReboot or -ReportOnly. Reboot when convenient."
}
