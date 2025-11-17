#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Intelligent Profiling System for Windows 11 Optimization
    
.DESCRIPTION
    Advanced system profiling and AI-driven optimization profile selection.
    Detects hardware, workload patterns, and system characteristics to 
    recommend optimal optimization profiles.
    
.EXAMPLE
    .\IntelligentProfiler.ps1 -Analyze
    .\IntelligentProfiler.ps1 -GenerateProfile -OutputPath "C:\OptimizeW11\profiles"
#>

[CmdletBinding()]
param(
    [switch]$Analyze,
    [switch]$GenerateProfile,
    [string]$OutputPath = "C:\OptimizeW11\profiles",
    [switch]$EnableTelemetry,
    [string]$ProfileHistoryPath = "C:\OptimizeW11\profiles\history",
    [string]$RunId,
    [switch]$ApplyChanges,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($PSBoundParameters.ContainsKey('Verbose')) { 'Continue' } else { 'SilentlyContinue' }

class HardwareProfile {
    # CPU basics
    [string]$CPUModel
    [string]$CPUArchitecture   # e.g. Intel/AMD/Unknown
    [string]$Manufacturer
    [string]$Arch              # alias used by Get-CPUProfile
    [int]$CoreCount
    [int]$Cores                # some logic expects Cores
    [int]$LogicalProcessors
    [bool]$HasHyperThreading
    [bool]$HasSMT
    [int]$MaxClockMHz
    # Feature maps
    [hashtable]$CPUFeatures    # expected by Get-FullSystemProfile & summary
    [hashtable]$Features       # legacy/alternate name
    # GPU
    [string]$GPUVendor
    [string]$GPUModel
    [int]$VRAM
    # Storage counts / flags
    [int]$TotalDrives
    [int]$SSDCount
    [int]$HDDCount
    [int]$NVMeCount
    [bool]$HasNVMe
    [bool]$HasDedicatedSSD
    # System characteristics
    [bool]$IsLaptop
    [bool]$IsVM
    [bool]$IsServer
    [bool]$HasTPM20
    # Memory
    [int]$SystemRAM            # GB
}

class SystemProfile {
    # Identity / meta
    [string]$ProfileName
    [datetime]$Timestamp
    [string]$RunId
    # Core components
    [HardwareProfile]$Hardware
    [hashtable]$Thermals
    [hashtable]$PowerState
    # Workload characterization (two aliases for backward compatibility)
    [hashtable]$WorkloadCharacterization
    [hashtable]$WorkloadPattern
    # Performance metrics / scoring
    [hashtable]$Performance
    [double]$ConfidenceScore
    [string]$ConfidenceLabel
    # Recommendation outputs
    [string]$RecommendedPreset
    [string]$RecommendedProfile   # was hashtable; actual assignment uses string like 'Workstation'
    [string]$RecommendedRole
    [string[]]$Recommendations
    [hashtable]$Recommendation  # legacy single-object form (retain for backward compatibility)
    [int]$PerformanceScore      # optional: expose final numeric performance classification
}

function Get-CPUProfile {
    <#
    .SYNOPSIS
        Detect CPU model, manufacturer, core counts and capabilities.
    .OUTPUTS
        [HardwareProfile] (partial) - populated with CPU-related properties & feature maps.
    #>
    Write-Verbose "Detecting CPU profile..."
    $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cpu) { throw "Unable to query Win32_Processor" }

    $hp = [HardwareProfile]::new()
    $hp.CPUModel = $cpu.Name
    $hp.Manufacturer = $cpu.Manufacturer
    $hp.Cores = $cpu.NumberOfCores
    $hp.CoreCount = $cpu.NumberOfCores
    $hp.LogicalProcessors = $cpu.NumberOfLogicalProcessors
    $hp.MaxClockMHz = $cpu.MaxClockSpeed
    
    if ($hp.Manufacturer -match 'Intel') {
        $hp.Arch = 'Intel'
        $hp.CPUArchitecture = 'Intel'
    }
    elseif ($hp.Manufacturer -match 'AMD') {
        $hp.Arch = 'AMD'
        $hp.CPUArchitecture = 'AMD'
    }
    else {
        $hp.Arch = 'Unknown'
        $hp.CPUArchitecture = 'Unknown'
    }
    
    $hp.HasHyperThreading = $hp.LogicalProcessors -gt $hp.Cores
    $hp.HasSMT = $hp.HasHyperThreading
    $hp.CPUFeatures = Get-CPUFeatures
    $hp.Features = $hp.CPUFeatures  # keep alias for legacy references
    Write-Verbose "CPU: $($hp.CPUModel) | Cores: $($hp.Cores) | Logical: $($hp.LogicalProcessors)"
    return $hp
}

function Get-CPUFeatures {
    <#
    .SYNOPSIS
        Detect CPU instruction set features (AVX, AVX2, AVX512, etc.)
    #>
    Write-Verbose "Detecting CPU features..."
    
    $features = @{
        AVX = $false
        AVX2 = $false
        AVX512 = $false
        SSE42 = $false
        AES = $false
        HT = $false
        VT = $false
        SMT = $false
    }
    
    try {
        $wmiProc = Get-WmiObject Win32_Processor
        $characteristics = $wmiProc.Characteristics
        if ($characteristics) {
            if ($characteristics -band 64) {
                $features.HT = $true
            }
        }
    } catch {
        Write-Verbose "Could not detect detailed CPU features via WMI"
    }

    try {
        $cpuKey = Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -ErrorAction SilentlyContinue
        if ($cpuKey.VendorIdentifier -match 'GenuineIntel|AuthenticAMD') {
            $features.AVX = $true
            $features.AVX2 = $true
        }
    } catch {
        Write-Verbose "Could not detect CPU features via registry"
    }
    
    return $features
}

function Get-GPUProfile {
    <#
    .SYNOPSIS
        Detect GPU model and VRAM
    #>
    Write-Verbose "Detecting GPU profile..."
    
    $gpus = @()
    
    try {
        $nvidia = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'NVIDIA|GeForce|Quadro|RTX|GTX' }
        
        if ($nvidia) {
            foreach ($gpu in $nvidia) {
                $gpus += @{
                    Vendor = 'NVIDIA'
                    Model = $gpu.Name
                    VRAM = $gpu.AdapterRAM
                }
            }
        }
    } catch {
        Write-Verbose "Could not detect NVIDIA GPU"
    }
    
    try {
        $amd = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'AMD|Radeon|Ryzen' }
        
        if ($amd) {
            foreach ($gpu in $amd) {
                $gpus += @{
                    Vendor = 'AMD'
                    Model = $gpu.Name
                    VRAM = $gpu.AdapterRAM
                }
            }
        }
    } catch {
        Write-Verbose "Could not detect AMD GPU"
    }
    
    try {
        $intel = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'Intel' }
        
        if ($intel) {
            foreach ($gpu in $intel) {
                $gpus += @{
                    Vendor = 'Intel'
                    Model = $gpu.Name
                    VRAM = $gpu.AdapterRAM
                }
            }
        }
    } catch {
        Write-Verbose "Could not detect Intel GPU"
    }
    
    if ($gpus.Count -eq 0) {
        Write-Verbose "No discrete GPU detected"
    }
    
    return $gpus
}

function Get-StorageProfile {
    <#
    .SYNOPSIS
        Detect storage configuration (SSD, NVMe, HDD, etc.)
    #>
    Write-Verbose "Detecting storage profile..."
    
    $storage = @{
        TotalDrives = 0
        SSDCount = 0
        HDDCount = 0
        NVMeCount = 0
        Drives = @()
    }
    
    try {
        $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
        
        foreach ($disk in $disks) {
            $storage.TotalDrives++
            
            $drive = @{
                Number = $disk.DeviceId
                FriendlyName = $disk.FriendlyName
                MediaType = $disk.MediaType
                Size = $disk.Size
                SizeGB = [math]::Round($disk.Size / 1GB, 2)
                BusType = $disk.BusType
            }
            
            switch ($disk.MediaType) {
                'SSD' { 
                    $storage.SSDCount++
                    $drive.Type = 'SSD'
                }
                'HDD' { 
                    $storage.HDDCount++
                    $drive.Type = 'HDD'
                }
                default { 
                    $drive.Type = 'Unknown'
                }
            }
            
            if ($disk.BusType -match 'NVMe|NVME') {
                $storage.NVMeCount++
                $drive.IsNVMe = $true
            }
            
            $storage.Drives += $drive
        }
    } catch {
        Write-Verbose "Could not detect storage configuration: $_"
    }
    
    return $storage
}

function Get-SystemCharacterization {
    <#
    .SYNOPSIS
        Detect system type (Laptop, Desktop, VM, Server)
    #>
    Write-Verbose "Characterizing system type..."
    
    $characts = @{
        IsLaptop = $false
        IsVM = $false
        IsServer = $false
        IsMobileWorkstation = $false
        SystemType = 'Unknown'
    }
    
    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            $characts.IsLaptop = $true
            $characts.SystemType = 'Laptop'
        }
    } catch {}
    
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($cs.Model -match 'Virtual|VMware|KVM|VirtualBox|Hyper-V|Xen|QEMU') {
            $characts.IsVM = $true
            $characts.SystemType = 'VM'
        }
        elseif ($cs.PCSystemType -eq 2) {
            $characts.IsMobileWorkstation = $true
            if (-not $characts.IsLaptop) {
                $characts.SystemType = 'MobileWorkstation'
            }
        }
    } catch {}
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os.ProductType -in @(2, 3)) {  
            $characts.IsServer = $true
            $characts.SystemType = 'Server'
        }
    } catch {}
    
    try {
        if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) {
            $characts.IsDomainMember = $true
        }
    } catch {}
    
    Write-Verbose "System Type: $($characts.SystemType)"
    return $characts
}

function Get-ThermalProfile {
    <#
    .SYNOPSIS
        Detect thermal capabilities and current state
    #>
    Write-Verbose "Analyzing thermal profile..."
    
    $thermal = @{
        CurrentTempC = $null
        ThermalDesignPower = $null
        CoolingCapability = 'Unknown'
        CanUndervolt = $null
        CanOC = $null
    }
    
    try {
        $temps = Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction SilentlyContinue
        
        if ($temps) {
            $currentTempKelvin = $temps.CurrentTemperature / 10
            $thermal.CurrentTempC = [math]::Round($currentTempKelvin - 273.15, 1)
        }
    } catch {
        Write-Verbose "Could not read thermal information: $_"
    }
    
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
        if ($cpu.L2CacheSize) {
            $thermal.CoolingCapability = 'Standard'
        }
    } catch {}
    
    return $thermal
}

function Get-PowerProfile {
    <#
    .SYNOPSIS
        Analyze current power scheme and capabilities
    #>
    Write-Verbose "Analyzing power profile..."
    
    $power = @{
        CurrentScheme = $null
        AvailableSchemes = @()
        BatteryStatus = $null
        ACPower = $null
    }
    
    try {
        $activePower = powercfg -getactivescheme 2>$null
        if ($activePower) {
            $power.CurrentScheme = ($activePower -split '\s+')[3]
        }
    } catch {}
    
    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            $power.BatteryStatus = @{
                ChargePercentage = $battery.EstimatedChargeRemaining
                Status = $battery.Status
            }
        }
    } catch {}
    
    return $power
}

function Get-WorkloadPattern {
    <#
    .SYNOPSIS
        Analyze system usage patterns to determine workload type
    #>
    Write-Verbose "Analyzing workload patterns..."
    
    $workload = @{
        Type = 'General'
        GamingScore = 0
        ProductivityScore = 0
        DevelopmentScore = 0
        ContentCreationScore = 0
        DataScience = 0
        Indicators = @()
    }
    
    try {
       
        $software = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
            Select-Object DisplayName
        
        $gameIndicators = @('Steam', 'Epic', 'Game', 'Unity', 'Unreal', 'Blender', 'OBS', 'XSplit')
        $devIndicators = @('Visual Studio', 'VSCode', 'Git', 'Docker', 'Node', 'Python', 'Java', 'Rider')
        $creatorIndicators = @('Adobe', 'Premiere', 'After Effects', 'DaVinci', 'Blender', 'Maya')
        $scienceIndicators = @('MATLAB', 'Anaconda', 'Jupyter', 'TensorFlow', 'PyTorch', 'R Studio')
        
        # Pre-compile regex patterns outside the loop
        $gamePattern = $gameIndicators -join '|'
        $devPattern = $devIndicators -join '|'
        $creatorPattern = $creatorIndicators -join '|'
        $sciencePattern = $scienceIndicators -join '|'
        
        foreach ($app in $software.DisplayName) {
            if ($app -match $gamePattern) {
                $workload.GamingScore += 20
                $workload.Indicators += $app
            }
            if ($app -match $devPattern) {
                $workload.DevelopmentScore += 15
                $workload.Indicators += $app
            }
            if ($app -match $creatorPattern) {
                $workload.ContentCreationScore += 20
                $workload.Indicators += $app
            }
            if ($app -match $sciencePattern) {
                $workload.DataScience += 15
                $workload.Indicators += $app
            }
        }
        
        $scores = @{
            Gaming = $workload.GamingScore
            Development = $workload.DevelopmentScore
            ContentCreation = $workload.ContentCreationScore
            DataScience = $workload.DataScience
        }
        
        $topWorkload = $scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
        if ($topWorkload.Value -gt 0) {
            $workload.Type = $topWorkload.Name
        }
    } catch {
        Write-Verbose "Could not characterize workload: $_"
    }
    
    return $workload
}


function Get-RecommendedProfile {
    <#
    .SYNOPSIS
        AI-driven profile recommendation based on hardware and workload
    #>
    param(
        [Parameter(Mandatory)][HardwareProfile]$Hardware,
        [Parameter(Mandatory)][hashtable]$Characterization,
        [Parameter(Mandatory)][hashtable]$Workload
    )
    
    Write-Verbose "Generating profile recommendation..."
    
    $recommendation = @{
        Preset = 'Recommended'
        Profile = 'Default'
        Role = 'Desktop'
        Confidence = 0.5
        Reasoning = @()
    }

    if ($Characterization.IsLaptop) {
        $recommendation.Role = 'Laptop'
        $recommendation.Reasoning += "Detected laptop (battery present)"
    }
    elseif ($Characterization.IsVM) {
        $recommendation.Role = 'VM'
        $recommendation.Reasoning += "Detected virtual machine"
    }
    elseif ($Characterization.IsServer) {
        $recommendation.Role = 'Server'
        $recommendation.Reasoning += "Detected server OS"
    }
    else {
        $recommendation.Role = 'Desktop'
    }
    
    switch ($Workload.Type) {
        'Gaming' {
            $recommendation.Profile = 'eSports'
            $recommendation.Reasoning += "Gaming software detected - eSports profile recommended"
            $recommendation.Confidence += 0.2
        }
        'Development' {
            $recommendation.Profile = 'Workstation'
            $recommendation.Reasoning += "Development tools detected - Workstation profile recommended"
            $recommendation.Confidence += 0.2
        }
        'ContentCreation' {
            $recommendation.Profile = 'Creator'
            $recommendation.Reasoning += "Content creation software detected - Creator profile recommended"
            $recommendation.Confidence += 0.2
        }
        'DataScience' {
            $recommendation.Profile = 'Workstation'
            $recommendation.Reasoning += "Data science tools detected - Workstation profile recommended"
            $recommendation.Confidence += 0.2
        }
    }
    
    $performanceScore = 0
    if ($Hardware.CoreCount -ge 16) { $performanceScore += 20 }
    elseif ($Hardware.CoreCount -ge 12) { $performanceScore += 15 }
    elseif ($Hardware.CoreCount -ge 8) { $performanceScore += 10 }
    elseif ($Hardware.CoreCount -ge 4) { $performanceScore += 5 }
    
    if ($Hardware.SystemRAM -ge 64) { $performanceScore += 20 }
    elseif ($Hardware.SystemRAM -ge 32) { $performanceScore += 15 }
    elseif ($Hardware.SystemRAM -ge 16) { $performanceScore += 10 }
    elseif ($Hardware.SystemRAM -ge 8) { $performanceScore += 5 }
    
    if ($Hardware.HasNVMe) { $performanceScore += 10 }
    if ($Hardware.SSDCount -ge 2) { $performanceScore += 5 }
    
    if ($Hardware.GPUModel -match 'RTX 3090|RTX 4090|A100|MI250') { $performanceScore += 15 }
    elseif ($Hardware.GPUModel -match 'RTX 3080|RTX 4080|A6000') { $performanceScore += 12 }
    elseif ($Hardware.VRAM -ge 8192) { $performanceScore += 8 }
    
    if ($Hardware.HasTPM20) { $performanceScore += 5 }
    
    if ($performanceScore -ge 80) {
        $recommendation.Preset = 'UltraInfinity'
    }
    elseif ($performanceScore -ge 70) {
        $recommendation.Preset = 'UltraX'
    }
    elseif ($performanceScore -ge 60) {
        $recommendation.Preset = 'Ultra'
    }
    elseif ($performanceScore -ge 45) {
        $recommendation.Preset = 'Max'
    }
    elseif ($performanceScore -ge 25) {
        $recommendation.Preset = 'Recommended'
    }
    else {
        $recommendation.Preset = 'Lite'
    }
    
    $recommendation.PerformanceScore = $performanceScore
    $recommendation.Confidence = [math]::Min(1.0, $recommendation.Confidence + 0.3)
    
    return $recommendation
}


function Get-FullSystemProfile {
    <#
    .SYNOPSIS
        Generate comprehensive system profile
    #>
    Write-Host ("=" * 70)
    Write-Host "INTELLIGENT PROFILER - Windows 11 Optimization System"
    Write-Host ("=" * 70)
    Write-Host ""
    
    Write-Host "Collecting system information..." -ForegroundColor Yellow
    
    # Capture CPU once (avoid repeated WMI/CIM queries)
    $cpuProfile = Get-CPUProfile

    $profile = [SystemProfile]::new()
    $profile.ProfileName = "SystemProfile-$(Get-Random)"
    $profile.Timestamp = Get-Date
    $profile.RunId = $RunId
    # Initialize hardware object and copy CPU details
    $profile.Hardware = [HardwareProfile]::new()
    $profile.Hardware.CPUModel = $cpuProfile.CPUModel
    $profile.Hardware.Manufacturer = $cpuProfile.Manufacturer
    $profile.Hardware.Cores = $cpuProfile.Cores
    $profile.Hardware.CoreCount = $cpuProfile.CoreCount
    $profile.Hardware.LogicalProcessors = $cpuProfile.LogicalProcessors
    $profile.Hardware.MaxClockMHz = $cpuProfile.MaxClockMHz
    $profile.Hardware.Arch = $cpuProfile.Arch
    $profile.Hardware.CPUArchitecture = $cpuProfile.CPUArchitecture
    $profile.Hardware.HasSMT = $cpuProfile.HasSMT
    $profile.Hardware.HasHyperThreading = $cpuProfile.HasHyperThreading
    $profile.Hardware.CPUFeatures = $cpuProfile.CPUFeatures
    $profile.Hardware.Features = $cpuProfile.Features

    $profile.Thermals = Get-ThermalProfile
    $profile.PowerState = Get-PowerProfile
    $profile.Performance = @{}
    $profile.WorkloadCharacterization = Get-WorkloadPattern
    $profile.WorkloadPattern = $profile.WorkloadCharacterization
    
    $gpus = Get-GPUProfile
    if ($gpus.Count -gt 0) {
        $profile.Hardware.GPUModel = $gpus[0].Model
        $profile.Hardware.GPUVendor = $gpus[0].Vendor
        $profile.Hardware.VRAM = $gpus[0].VRAM / 1MB
    }
    
    $storage = Get-StorageProfile
    $profile.Hardware.TotalDrives = $storage.TotalDrives
    $profile.Hardware.SSDCount = $storage.SSDCount
    $profile.Hardware.HDDCount = $storage.HDDCount
    $profile.Hardware.HasNVMe = $storage.NVMeCount -gt 0
    $profile.Hardware.HasDedicatedSSD = $storage.SSDCount -gt 0
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $profile.Hardware.SystemRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 0)
    } catch {}

    $characts = Get-SystemCharacterization
    $profile.Hardware.IsLaptop = $characts.IsLaptop
    $profile.Hardware.IsVM = $characts.IsVM
    $profile.Hardware.IsServer = $characts.IsServer
    
    try {
        $tpm = Get-CimInstance -ClassName Win32_Tpm -ErrorAction SilentlyContinue
        $profile.Hardware.HasTPM20 = $tpm.SpecVersion -match '2\.0'
    } catch {}
    
    $rec = Get-RecommendedProfile -Hardware $profile.Hardware -Characterization $characts -Workload $profile.WorkloadCharacterization
    $profile.RecommendedPreset = $rec.Preset
    $profile.RecommendedProfile = $rec.Profile
    $profile.RecommendedRole = $rec.Role
    $profile.ConfidenceScore = $rec.Confidence
    $profile.Recommendations = $rec.Reasoning
    if ($profile.ConfidenceScore -ge 0.75) {
        $profile.ConfidenceLabel = 'High'
    } elseif ($profile.ConfidenceScore -ge 0.5) {
        $profile.ConfidenceLabel = 'Medium'
    } else {
        $profile.ConfidenceLabel = 'Low'
    }
    
    return $profile
}

function Show-ProfileSummary {
    <#
    .SYNOPSIS
        Display profiling results in human-readable format
    #>
    param(
        [Parameter(Mandatory)][SystemProfile]$Profile
    )
    
    Write-Host ""
    Write-Host ("=" * 70)
    Write-Host "SYSTEM PROFILE ANALYSIS"
    Write-Host ("=" * 70)
    
    Write-Host ""
    Write-Host "CPU INFORMATION:" -ForegroundColor Cyan
    Write-Host "  Model: $($Profile.Hardware.CPUModel)"
    Write-Host "  Cores: $($Profile.Hardware.CoreCount) | Logical: $($Profile.Hardware.LogicalProcessors)"
    Write-Host "  Architecture: $($Profile.Hardware.CPUArchitecture)"
    $htStatus = if ($Profile.Hardware.HasHyperThreading) { 'Yes' } else { 'No' }
    Write-Host "  Hyperthreading: $htStatus"
    Write-Host "  CPU Features: $(($Profile.Hardware.CPUFeatures.Keys | Where-Object { $Profile.Hardware.CPUFeatures[$_] }) -join ', ')"
    
    Write-Host ""
    Write-Host "GPU INFORMATION:" -ForegroundColor Cyan
    if ($Profile.Hardware.GPUModel) {
        Write-Host "  Vendor: $($Profile.Hardware.GPUVendor)"
        Write-Host "  Model: $($Profile.Hardware.GPUModel)"
        Write-Host "  VRAM: $($Profile.Hardware.VRAM) MB"
    } else {
        Write-Host "  No dedicated GPU detected (using integrated graphics)"
    }
    
    Write-Host ""
    Write-Host "MEMORY & STORAGE:" -ForegroundColor Cyan
    Write-Host "  System RAM: $($Profile.Hardware.SystemRAM) GB"
    Write-Host "  Total Drives: $($Profile.Hardware.TotalDrives)"
    Write-Host "  SSDs: $($Profile.Hardware.SSDCount) | HDDs: $($Profile.Hardware.HDDCount)"
    $nvmeStatus = if ($Profile.Hardware.HasNVMe) { 'Yes' } else { 'No' }
    Write-Host "  NVMe: $nvmeStatus"
    
    Write-Host ""
    Write-Host "SYSTEM CHARACTERISTICS:" -ForegroundColor Cyan
    $laptopStatus = if ($Profile.Hardware.IsLaptop) { 'Yes' } else { 'No' }
    Write-Host "  Laptop: $laptopStatus"
    $vmStatus = if ($Profile.Hardware.IsVM) { 'Yes' } else { 'No' }
    Write-Host "  Virtual Machine: $vmStatus"
    $serverStatus = if ($Profile.Hardware.IsServer) { 'Yes' } else { 'No' }
    Write-Host "  Server: $serverStatus"
    $tpmStatus = if ($Profile.Hardware.HasTPM20) { 'Yes' } else { 'No' }
    Write-Host "  TPM 2.0: $tpmStatus"
    
    Write-Host ""
    Write-Host "THERMAL & POWER:" -ForegroundColor Cyan
    if ($Profile.Thermals.CurrentTempC) {
        Write-Host "  Current CPU Temp: $($Profile.Thermals.CurrentTempC)°C"
    }
    Write-Host "  Current Power Scheme: $($Profile.PowerState.CurrentScheme)"
    if ($Profile.PowerState.BatteryStatus) {
        Write-Host "  Battery: $($Profile.PowerState.BatteryStatus.ChargePercentage)%"
    }
    
    Write-Host ""
    Write-Host "WORKLOAD ANALYSIS:" -ForegroundColor Cyan
    Write-Host "  Detected Type: $($Profile.WorkloadCharacterization.Type)"
    if ($Profile.WorkloadCharacterization.Indicators.Count -gt 0) {
        Write-Host "  Software Indicators: $($Profile.WorkloadCharacterization.Indicators -join ', ')"
    }
    
    Write-Host ""
    Write-Host ("=" * 70)
    Write-Host "RECOMMENDATIONS" -ForegroundColor Green
    Write-Host ("=" * 70)
    Write-Host ""
    Write-Host "Recommended Settings:" -ForegroundColor Yellow
    Write-Host "  Preset: $($Profile.RecommendedPreset)" -ForegroundColor Green
    Write-Host "  Profile: $($Profile.RecommendedProfile)" -ForegroundColor Green
    Write-Host "  Role: $($Profile.RecommendedRole)" -ForegroundColor Green
    Write-Host "  Confidence: $([math]::Round($Profile.ConfidenceScore * 100, 1))%"
    
    Write-Host ""
    Write-Host "Reasoning:" -ForegroundColor Yellow
    foreach ($reason in $Profile.Recommendations) {
        Write-Host "  • $reason"
    }
    
    Write-Host ""
    Write-Host ("=" * 70)
}

function Export-ProfileJSON {
    <#
    .SYNOPSIS
        Export profile to JSON format
    #>
    param(
        [Parameter(Mandatory)][SystemProfile]$Profile,
        [Parameter(Mandatory)][string]$OutputPath
    )
    
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    $filename = "profile-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $outputFile = Join-Path $OutputPath $filename
    
    $exportObj = @{
        ProfileName = $Profile.ProfileName
        Timestamp = $Profile.Timestamp
        Hardware = @{
            CPUModel = $Profile.Hardware.CPUModel
            CoreCount = $Profile.Hardware.CoreCount
            LogicalProcessors = $Profile.Hardware.LogicalProcessors
            Architecture = $Profile.Hardware.CPUArchitecture
            GPUModel = $Profile.Hardware.GPUModel
            GPUVendor = $Profile.Hardware.GPUVendor
            GPUVRAM = $Profile.Hardware.VRAM
            SystemRAM = $Profile.Hardware.SystemRAM
            TotalDrives = $Profile.Hardware.TotalDrives
            SSDCount = $Profile.Hardware.SSDCount
            HDDCount = $Profile.Hardware.HDDCount
            HasNVMe = $Profile.Hardware.HasNVMe
            IsLaptop = $Profile.Hardware.IsLaptop
            IsVM = $Profile.Hardware.IsVM
            IsServer = $Profile.Hardware.IsServer
            HasTPM20 = $Profile.Hardware.HasTPM20
        }
        Workload = @{
            Type = $Profile.WorkloadCharacterization.Type
            GamingScore = $Profile.WorkloadCharacterization.GamingScore
            DevelopmentScore = $Profile.WorkloadCharacterization.DevelopmentScore
            CreationScore = $Profile.WorkloadCharacterization.ContentCreationScore
        }
        Recommendations = @{
            Preset = $Profile.RecommendedPreset
            Profile = $Profile.RecommendedProfile
            Role = $Profile.RecommendedRole
            Confidence = $Profile.ConfidenceScore
            Reasoning = $Profile.Recommendations
        }
    }
    
    $exportObj | ConvertTo-Json -Depth 10 | Set-Content -Path $outputFile -Encoding UTF8
    Write-Host "Profile exported to: $outputFile" -ForegroundColor Green
    
    return $outputFile
}


function New-RunId {
    <#
    .SYNOPSIS
        Generate a short unique run identifier for profiling runs
    #>
    return ([guid]::NewGuid().ToString())
}


function Write-ProfilerLog {
    <#
    .SYNOPSIS
        Append a structured log entry for profiler runs
    #>
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Level = 'INFO',
        [string]$LogPath,
        [string]$Run
    )

    try {
        if (-not $LogPath) {
            $outPath = $script:OutputPath
            if ($outPath) {
                $LogPath = Join-Path $outPath "profiler.log"
            } else {
                $LogPath = "C:\OptimizeW11\profiles\profiler.log"
            }
        }
        if (-not $Run) {
            $Run = $script:RunId
            if (-not $Run) { $Run = "unknown" }
        }
        
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $entry = "[$timestamp] [$Level] [Run:$Run] $Message"
        Add-Content -Path $LogPath -Value $entry -ErrorAction SilentlyContinue
        Write-Verbose "Logged: $entry"
    } catch {
        # Silently ignore logging errors
    }
}


function Save-ProfileHistory {
    <#
    .SYNOPSIS
        Save a profile JSON into a history folder for later analysis
    #>
    param(
        [Parameter(Mandatory)][SystemProfile]$Profile,
        [string]$HistoryPath
    )

    try {
        if (-not $HistoryPath) { $HistoryPath = $script:ProfileHistoryPath }
        
        if (-not (Test-Path $HistoryPath)) { New-Item -ItemType Directory -Path $HistoryPath -Force | Out-Null }
        if ($script:RunId) {
            $rid = $script:RunId
        } else {
            $rid = [guid]::NewGuid().ToString()
        }
        $filename = "profile-$($Profile.Timestamp -replace '[: ]','-')-$rid.json"
        $out = Join-Path $HistoryPath $filename
        $Profile | ConvertTo-Json -Depth 10 | Set-Content -Path $out -Encoding UTF8
        Write-Verbose "Saved profile history: $out"
        Write-ProfilerLog -Message "Saved profile history to $out" -Level 'INFO'
        return $out
    } catch {
        Write-Verbose "Failed to save profile history: $_"
        Write-ProfilerLog -Message "Failed to save profile history: $_" -Level 'ERROR'
        return $null
    }
}


function Invoke-LocalModelScore {
    <#
    .SYNOPSIS
        Local ML-scoring stub: adjusts confidence/performance prediction using a small heuristic
        This is a placeholder for an actual ML model; it is deterministic and safe.
    #>
    param(
        [Parameter(Mandatory)][SystemProfile]$Profile
    )

    $adjust = 0.0
    if ($Profile.Hardware.HasNVMe) { $adjust += 0.03 }
    if ($Profile.Hardware.SystemRAM -ge 16) { $adjust += 0.02 }
    if ($Profile.Hardware.VRAM -ge 8192) { $adjust += 0.02 }

    $Profile.ConfidenceScore = [math]::Min(1.0, $Profile.ConfidenceScore + $adjust)
    Write-Verbose "Local model adjusted confidence by $adjust -> $($Profile.ConfidenceScore)"
    Write-ProfilerLog -Message "Local model adjusted confidence by $adjust" -Level 'DEBUG'

    return $Profile
}


function Load-ProfilerPlugins {
    <#
    .SYNOPSIS
        Load optional profiler extension scripts from a plugins folder.
    .DESCRIPTION
        Looks for `.ps1` files in `C:\OptimizeW11\plugins` (or $env:OPTIMIZER_PLUGINS)
        and dot-sources them. Plugins can register functions or hooks.
    #>
    param(
        [string]$PluginsPath
    )
    
    if (-not $PluginsPath) {
        if ($env:OPTIMIZER_PLUGINS) {
            $PluginsPath = $env:OPTIMIZER_PLUGINS
        } else {
            $PluginsPath = 'C:\OptimizeW11\plugins'
        }
    }

    $loaded = @()
    try {
        if (-not (Test-Path $PluginsPath)) {
            Write-Verbose "Plugins path does not exist: $PluginsPath"
            return $loaded
        }

        $files = Get-ChildItem -Path $PluginsPath -Filter '*.ps1' -File -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            try {
                Write-Verbose "Loading plugin: $($f.FullName)"
                . $f.FullName
                $loaded += $f.Name
                Write-ProfilerLog -Message "Loaded plugin $($f.Name)" -Level 'INFO'
            } catch {
                Write-Verbose "Failed to load plugin $($f.FullName): $_"
                Write-ProfilerLog -Message "Plugin load failed: $($f.FullName) - $_" -Level 'ERROR'
            }
        }
    } catch {
        Write-Verbose "Error enumerating plugins: $_"
    }

    return $loaded
}


function Run-SyntheticBenchmark {
    <#
    .SYNOPSIS
        Lightweight synthetic micro-benchmark for CPU and storage.
    .DESCRIPTION
        Runs short CPU-bound workload and a small disk write test to provide
        relative metrics for comparisons. Designed to be safe and fast.
    #>
    param(
        [int]$CpuSeconds = 3,
        [int]$DiskMB = 32,
        [string]$TempPath
    )

    $result = @{ CPU = $null; Disk = $null }
    try {
        if (-not $TempPath) { $TempPath = "$($script:OutputPath)\bench" }
        
        if (-not (Test-Path $TempPath)) { New-Item -ItemType Directory -Path $TempPath -Force | Out-Null }

        $sw = [diagnostics.stopwatch]::StartNew()
        $iterations = 0
        while ($sw.Elapsed.TotalSeconds -lt $CpuSeconds) {
            for ($i = 0; $i -lt 1000; $i++) { [math]::Sqrt($i) * [math]::Pow($i+1, 0.5) | Out-Null }
            $iterations += 1000
        }
        $sw.Stop()
        $ips = [math]::Round($iterations / $sw.Elapsed.TotalSeconds)
        $result.CPU = @{ Iterations = $iterations; Seconds = [math]::Round($sw.Elapsed.TotalSeconds,2); IterationsPerSec = $ips }
        Write-Verbose "Synthetic CPU: $($result.CPU.IterationsPerSec) it/s"
        Write-ProfilerLog -Message "Synthetic CPU: $($result.CPU.IterationsPerSec) iterations/sec" -Level 'INFO'

        $file = Join-Path $TempPath "bench-$(Get-Random).bin"
        $bytes = [byte[]](0..255) * 1024  # 256 KB block
        $blocks = [math]::Ceiling(($DiskMB * 1MB) / $bytes.Length)

        $sw = [diagnostics.stopwatch]::StartNew()
        $fs = [System.IO.File]::Open($file, [System.IO.FileMode]::Create)
        for ($b = 0; $b -lt $blocks; $b++) { $fs.Write($bytes, 0, $bytes.Length) }
        $fs.Flush(); $fs.Close()
        $sw.Stop()

        $sizeWrittenMB = [math]::Round((Get-Item $file).Length / 1MB,2)
        $writeSpeed = [math]::Round($sizeWrittenMB / $sw.Elapsed.TotalSeconds,2)
        $result.Disk = @{ File = $file; MB = $sizeWrittenMB; Seconds = [math]::Round($sw.Elapsed.TotalSeconds,2); MBps = $writeSpeed }
        Write-Verbose "Synthetic Disk: $($result.Disk.MBps) MB/s"
        Write-ProfilerLog -Message "Synthetic Disk: $($result.Disk.MBps) MB/s" -Level 'INFO'

    } catch {
        Write-Verbose "Synthetic benchmark failed: $_"
        Write-ProfilerLog -Message "Synthetic benchmark failed: $_" -Level 'ERROR'
    }

    return $result
}


function Apply-AdaptivePowerPlan {
    <#
    .SYNOPSIS
        Suggest or apply an adaptive power plan based on hardware and thermals.
    .DESCRIPTION
        Determines a recommended power scheme. By default only suggests (DryRun).
        If -ApplyChanges is provided, the function will attempt to set the power plan
        via `powercfg` after writing logs and performing safety checks.
    #>
    param(
        [Parameter(Mandatory)][SystemProfile]$Profile
    )

    $recommendation = @{ Scheme = 'Balanced'; Reason = @() }

    try {
        if ($Profile.Hardware.IsLaptop -or $Profile.PowerState.BatteryStatus) {
            $recommendation.Scheme = 'PowerEfficient'
            $recommendation.Reason += 'Laptop or battery detected - favoring power-efficient plan'
        }

        if ($Profile.Hardware.CoreCount -ge 12 -and $Profile.Hardware.VRAM -ge 8192) {
            $recommendation.Scheme = 'HighPerformance'
            $recommendation.Reason += 'High core count and VRAM detected - favoring high-performance plan'
        }
        if ($Profile.Thermals.CurrentTempC -and $Profile.Thermals.CurrentTempC -gt 85) {
            $recommendation.Scheme = 'Balanced'
            $recommendation.Reason += 'High temperature detected - using Balanced for safety'
        }

        Write-Host "Adaptive power recommendation: $($recommendation.Scheme)" -ForegroundColor Cyan
        foreach ($r in $recommendation.Reason) { Write-Host "  - $r" }
        Write-ProfilerLog -Message "Adaptive power recommendation: $($recommendation.Scheme) - $($recommendation.Reason -join '; ')" -Level 'INFO'

        if ($ApplyChanges -and -not $DryRun) {
            Write-Host "Applying power scheme: $($recommendation.Scheme)" -ForegroundColor Yellow
            Write-ProfilerLog -Message "Applying power scheme: $($recommendation.Scheme)" -Level 'INFO'
            try {
                switch ($recommendation.Scheme) {
                    'PowerEfficient' { powercfg -setactive SCHEME_POWER_SAVER 2>$null }
                    'HighPerformance' { powercfg -setactive SCHEME_MIN 2>$null }
                    default { powercfg -setactive SCHEME_BALANCED 2>$null }
                }
            } catch {
                Write-Verbose "Failed to set power scheme: $_"
                Write-ProfilerLog -Message "Failed to set power scheme: $_" -Level 'ERROR'
            }
        } else {
            Write-Host "Dry run: no changes were applied. Use -ApplyChanges to apply." -ForegroundColor Yellow
        }

    } catch {
        Write-Verbose "Adaptive power plan error: $_"
        Write-ProfilerLog -Message "Adaptive power plan error: $_" -Level 'ERROR'
    }

    return $recommendation
}


try {
    if (-not $RunId) { $RunId = [guid]::NewGuid().ToString() }
    # Initialize script-scope variables for helper functions
    $script:RunId = $RunId
    $script:OutputPath = $OutputPath
    $script:ProfileHistoryPath = $ProfileHistoryPath
    
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    Write-Verbose "Starting profiler run with RunId: $RunId"
    
    if ($Analyze) {
        Write-Host "Starting comprehensive system analysis..." -ForegroundColor Yellow
        $systemProfile = Get-FullSystemProfile
        Show-ProfileSummary -Profile $systemProfile
        $plugins = Load-ProfilerPlugins
        if ($plugins.Count -gt 0) { Write-Host "Loaded plugins: $($plugins -join ', ')" -ForegroundColor Green }
        $bench = Run-SyntheticBenchmark -CpuSeconds 3 -DiskMB 32
        if ($bench.CPU -and $bench.Disk) {
            Write-ProfilerLog -Message "Benchmark results: CPU it/s=$($bench.CPU.IterationsPerSec); Disk MBps=$($bench.Disk.MBps)" -Level 'INFO'
        } else {
            Write-ProfilerLog -Message "Benchmark results incomplete or failed" -Level 'WARN'
        }
        $systemProfile = Invoke-LocalModelScore -Profile $systemProfile
        $historyFile = Save-ProfileHistory -Profile $systemProfile
        $powerRec = Apply-AdaptivePowerPlan -Profile $systemProfile

        if ($GenerateProfile) {
            Export-ProfileJSON -Profile $systemProfile -OutputPath $OutputPath
        }
    }
    elseif ($GenerateProfile) {
        Write-Host "Generating system profile..." -ForegroundColor Yellow
        $systemProfile = Get-FullSystemProfile
        Export-ProfileJSON -Profile $systemProfile -OutputPath $OutputPath
        Show-ProfileSummary -Profile $systemProfile
    }
    else {
        Write-Host "Quick system analysis..." -ForegroundColor Yellow
        Write-Host ""
        
        $cpu = Get-CPUProfile
        Write-Host "CPU: $($cpu.Model)" -ForegroundColor Cyan
        
        $gpu = Get-GPUProfile
        if ($gpu) {
            Write-Host "GPU: $($gpu[0].Vendor) - $($gpu[0].Model)" -ForegroundColor Cyan
        }
        
        $storage = Get-StorageProfile
        Write-Host "Storage: $($storage.SSDCount) SSD(s), $($storage.HDDCount) HDD(s), $($storage.NVMeCount) NVMe" -ForegroundColor Cyan
        
        $characts = Get-SystemCharacterization
        Write-Host "System Type: $($characts.SystemType)" -ForegroundColor Cyan
        
        Write-Host ""
        Write-Host "Use -Analyze for detailed profiling or -GenerateProfile to export data"
    }
}
catch {
    $errMsg = $_.Exception.Message
    $errType = $_.Exception.GetType().FullName
    Write-Error "Fatal error during profiling: $errMsg"
    Write-Host "Exception Type: $errType" -ForegroundColor Red
    
    if ($_.InvocationInfo) {
        $lineNum = $_.InvocationInfo.ScriptLineNumber
        $lineText = $_.InvocationInfo.Line
        Write-Host "Script Line: $lineNum" -ForegroundColor Red
        Write-Host "Line Text: $lineText" -ForegroundColor DarkRed
    }
    
    Write-Host "Stack Trace:" -ForegroundColor Red
    $stackTrace = $_.Exception.StackTrace
    Write-Host $stackTrace
    exit 1
}
