# Supervised single Godot run. It checks the machine first (GPU load / temperature / free memory), starts the scene through
# tools/run_godot.ps1 (private desktop, memory-capped job object, low priority, frame cap) and watches it every 2 seconds:
# if the run's own Godot process (found by its command line: project path + scene name) exceeds a memory limit, the GPU gets hot or
# busy, or the free virtual memory of the machine drops, ONLY that process is stopped (by PID). Prints the peaks at the end.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\guarded_run.ps1 -Scene res://tools/test_final.tscn -UserArgs "--parts=station,wildlife"
param(
	[Parameter(Mandatory = $true)][string]$Scene,
	[string]$UserArgs = "",
	[string]$Resolution = "640x360",
	[int]$MaxFps = 12,
	[int]$TimeoutSec = 120,
	[int]$MaxMemMB = 3072,
	[int]$AbortPrivateMB = 2200,
	[int]$AbortTempC = 82,
	[int]$AbortUtil = 92,
	[int]$MinFreeVirtualMB = 25000,
	[string]$Log = "scratch\guarded.log",
	[switch]$Headless
)
$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $PSScriptRoot
Set-Location $proj
$null = New-Item -ItemType Directory -Force (Join-Path $proj "scratch")
if (-not (Test-Path (Join-Path $proj "scratch\.gdignore"))) { $null = New-Item -ItemType File (Join-Path $proj "scratch\.gdignore") }
$sceneName = [System.IO.Path]::GetFileName($Scene)

function Get-Gpu {
	try {
		$o = & nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>$null
		$f = ($o | Select-Object -First 1) -split ","
		return [pscustomobject]@{ Util = [int]$f[0]; Temp = [int]$f[1]; MemUsed = [int]$f[2]; MemTotal = [int]$f[3] }
	} catch { return $null }
}
function Get-FreeVirtualMB { return [int]((Get-CimInstance Win32_OperatingSystem).FreeVirtualMemory / 1024) }

# ---- pre-flight
$g = Get-Gpu
$fv = Get-FreeVirtualMB
$big = Get-Process | Where-Object { $_.PrivateMemorySize64 -gt 12GB } | ForEach-Object { "{0} {1} MB" -f $_.ProcessName, [int]($_.PrivateMemorySize64 / 1MB) }
Write-Output ("preflight: GPU util {0}% temp {1} C vram {2}/{3} MB | free virtual {4} MB | processes over 12 GB: {5}" -f $g.Util, $g.Temp, $g.MemUsed, $g.MemTotal, $fv, $(if ($big) { $big -join ", " } else { "none" }))
if ($g -ne $null -and ($g.Util -gt 50 -or $g.Temp -gt 75)) { Write-Output "DEFERRED: the GPU is busy or warm"; exit 2 }
if ($fv -lt 50000 -or $big) { Write-Output "DEFERRED: the machine is short of memory"; exit 2 }

# ---- start the run (a hidden console PowerShell that runs run_godot.ps1)
$argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ("`"" + (Join-Path $proj "tools\run_godot.ps1") + "`""), "-Scene", $Scene, "-TimeoutSec", $TimeoutSec, "-MaxMemMB", $MaxMemMB, "-MaxFps", $MaxFps, "-Resolution", $Resolution, "-Log", $Log)
if ($UserArgs -ne "") { $argList += @("-UserArgs", "`"$UserArgs`"") }
if ($Headless) { $argList += "-Headless" }
$childOut = Join-Path $proj "scratch\guarded_child_out.txt"
$childErr = Join-Path $proj "scratch\guarded_child_err.txt"
$child = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -WindowStyle Hidden -PassThru -RedirectStandardOutput $childOut -RedirectStandardError $childErr
$peakMem = 0
$peakUtil = 0
$peakTemp = 0
$hot = 0
$aborted = ""
$t0 = Get-Date
while (-not $child.HasExited) {
	Start-Sleep -Seconds 2
	$gd = Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine -like "*5. Max Effort*" -and $_.CommandLine -like "*$sceneName*" }
	foreach ($p in $gd) {
		$gp = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
		if ($gp) {
			$mb = [int]($gp.PrivateMemorySize64 / 1MB)
			if ($mb -gt $peakMem) { $peakMem = $mb }
			if ($mb -gt $AbortPrivateMB) { $aborted = "private memory $mb MB"; }
		}
	}
	$g = Get-Gpu
	if ($g -ne $null) {
		if ($g.Util -gt $peakUtil) { $peakUtil = $g.Util }
		if ($g.Temp -gt $peakTemp) { $peakTemp = $g.Temp }
		if ($g.Temp -gt $AbortTempC) { $aborted = "GPU temperature $($g.Temp) C" }
		if ($g.Util -gt $AbortUtil) { $hot++ } else { $hot = 0 }
		if ($hot -ge 3) { $aborted = "GPU utilisation above $AbortUtil% for 6 s" }
	}
	if ((Get-FreeVirtualMB) -lt $MinFreeVirtualMB) { $aborted = "free virtual memory below $MinFreeVirtualMB MB" }
	if ($aborted -ne "") {
		foreach ($p in $gd) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; Write-Output "ABORTED run (PID $($p.ProcessId)): $aborted" }
		break
	}
	if (((Get-Date) - $t0).TotalSeconds -gt ($TimeoutSec + 30)) { $aborted = "watchdog timeout"; break }
}
Start-Sleep -Milliseconds 500
foreach ($cf in @($childOut, $childErr)) { if ((Test-Path $cf) -and (Get-Item $cf).Length -gt 0) { Write-Output ("child output (" + (Split-Path $cf -Leaf) + "): " + ((Get-Content $cf -Raw).Trim() -replace "\s+", " ").Substring(0, [Math]::Min(500, ((Get-Content $cf -Raw).Trim() -replace "\s+", " ").Length))) } }
if ($aborted -ne "") { try { Stop-Process -Id $child.Id -Force -ErrorAction SilentlyContinue } catch { } }
Write-Output ("finished after {0:N0} s | peak Godot private memory {1} MB | peak GPU util {2}% | peak GPU temp {3} C | aborted: {4}" -f ((Get-Date) - $t0).TotalSeconds, $peakMem, $peakUtil, $peakTemp, $(if ($aborted) { $aborted } else { "no" }))
if (Test-Path (Join-Path $proj $Log)) { Get-Content (Join-Path $proj $Log) -Encoding UTF8 | Select-String -Pattern "ERROR|SCRIPT|SHOT|DONE|wildlife|NO STATION|crash" | Select-Object -First 30 | ForEach-Object { $_.Line.Substring(0, [Math]::Min(180, $_.Line.Length)) } }
