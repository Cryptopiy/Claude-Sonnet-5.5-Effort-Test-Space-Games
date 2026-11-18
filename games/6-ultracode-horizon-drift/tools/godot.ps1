<#
Safe Godot runner for this project (Godot 4.7.2).  Usage (PowerShell tool - NOT bash, bash mangles the path quoting):

  -Project <path>   run against a sandbox copy (see tools/sandbox.py) instead of the main project. ALWAYS use your sandbox path while developing.
  & tools\godot.ps1 -Mode import                       # (re)import assets + refresh class_name cache (serialized with a lock)
  & tools\godot.ps1 -Mode run -TimeoutSec 40 -GodotArgs "--resolution 1280x720 -- --preset=landed:1 --shot=out/a.png@6 --quit-at=8"
  & tools\godot.ps1 -Mode run -Script res://tools/model_viewer.gd -GodotArgs "-- models=ship_player.glb"
  & tools\godot.ps1 -Mode run -Scene res://tests/foo.tscn ...
  & tools\godot.ps1 -Mode check                        # headless parse check: loads the main scene for 2s, prints script errors

Notes
 * Runs are ALWAYS windowless (--no-window): no window ever appears on the user's screen. Do not try to show one.
 * GPU SAFETY (the user's PC hard-froze 3 times from GPU-driver hangs): rendering runs are DISABLED unless the env var HD_ALLOW_RENDER=1 is set (only the architect sets it).
   Everyone else must use -Headless (dummy renderer, no GPU; logic, scripts, signals, telemetry all work, screenshots do not). Render runs are capped at 20 fps,
   <= 1024x576, ONE at a time machine-wide, with a GPU temperature guard and an 8 s cool-down between runs.
 * Everything after `--` in -GodotArgs is a *user arg* (see autoload/debug_cli.gd), everything before is an engine arg.
 * Output (stdout+stderr) is printed AND written to .logs/last_<Tag>.log.  Look for "SCRIPT ERROR" / "ERROR:" lines.
 * The process is killed BY PID after -TimeoutSec if it did not exit.  Never kill Godot by name: other agents run Godot too.
 * An import runs automatically before `run` (cheap when nothing changed) so new class_name scripts / new .glb files are known.
#>
param(
    [string]$Mode = "run",
    [string]$GodotArgs = "",
    [string]$Script = "",
    [string]$Scene = "",
    [int]$TimeoutSec = 60,
    [string]$Tag = "run",
    [string]$Project = "",
    [switch]$NoImport,
    [switch]$Headless
)
$ErrorActionPreference = "Continue"
$exe = "W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
$mainRoot = "W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort"
$proj = $mainRoot
if ($Project -ne "") { $proj = $Project }
$logDir = Join-Path $proj ".logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$lock = Join-Path $logDir "import.lock"
# machine-wide GPU slots (shared by every sandbox): at most $GpuSlots render processes at once
$GpuSlots = 1
$gpuDir = Join-Path $mainRoot "tools\.gpu"
New-Item -ItemType Directory -Force -Path $gpuDir | Out-Null

function Get-GpuSlot {
    $t0 = Get-Date
    while ($true) {
        for ($i = 0; $i -lt $GpuSlots; $i++) {
            try {
                return [System.IO.File]::Open((Join-Path $gpuDir ("slot$i.lock")), 'OpenOrCreate', 'ReadWrite', 'None')
            } catch { }
        }
        if (((Get-Date) - $t0).TotalMinutes -gt 40) { Write-Host "[godot.ps1] GPU queue wait > 40 min, running anyway"; return $null }
        Start-Sleep -Milliseconds (600 + (Get-Random -Maximum 700))
    }
}

function Invoke-WithTimeout([string[]]$argList, [int]$timeout, [string]$logFile) {
    $out = Join-Path $logDir ("proc_" + [guid]::NewGuid().ToString("N") + ".out")
    $err = Join-Path $logDir ("proc_" + [guid]::NewGuid().ToString("N") + ".err")
    $quoted = $argList | ForEach-Object { if ($_ -match '\s' -and $_ -notmatch '^".*"$') { '"' + $_ + '"' } else { $_ } }
    $p = Start-Process -FilePath $exe -ArgumentList $quoted -PassThru -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError $err
    $done = $p.WaitForExit($timeout * 1000)
    if (-not $done) {
        Write-Host "[godot.ps1] timeout after ${timeout}s -> stopping PID $($p.Id)"
        try { Stop-Process -Id $p.Id -Force } catch {}
    }
    Start-Sleep -Milliseconds 300
    $text = ""
    if (Test-Path $out) { $text += (Get-Content $out -Raw) }
    if (Test-Path $err) { $text += (Get-Content $err -Raw) }
    Set-Content -Path $logFile -Value $text -Encoding utf8
    Remove-Item $out, $err -ErrorAction SilentlyContinue
    return $text
}

function Do-Import {
    $t0 = Get-Date
    while ($true) {
        try {
            $fs = [System.IO.File]::Open($lock, 'OpenOrCreate', 'ReadWrite', 'None')
            break
        } catch {
            if (((Get-Date) - $t0).TotalSeconds -gt 300) { Write-Host "[godot.ps1] import lock timeout"; return }
            Start-Sleep -Milliseconds 400
        }
    }
    try {
        $text = Invoke-WithTimeout @("--headless", "--path", $proj, "--import", "--quit") 180 (Join-Path $logDir "last_import.log")
        $errs = ($text -split "`n") | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|ERROR:" }
        if ($errs) { Write-Host "[import] problems:"; $errs | Select-Object -First 40 | ForEach-Object { Write-Host $_ } }
    } finally {
        $fs.Close()
    }
}

if ($Mode -eq "import") { Do-Import; Write-Host "[godot.ps1] import done"; exit 0 }

if (-not $NoImport) { Do-Import }

if ($Mode -eq "check") {
    $args2 = @("--headless", "--path", $proj, "--quit-after", "120")
    $text = Invoke-WithTimeout $args2 60 (Join-Path $logDir "last_check.log")
    Write-Host $text
    exit 0
}

$argList = @("--path", $proj)
if ($Headless) { $argList += "--headless" }
# The user may be screen-recording: NEVER show a game window. `--no-window` renders fully (screenshots + input injection work) without creating any window.
# Without a window there is no vsync, so cap the frame rate hard (an uncapped run keeps the GPU at 100%).
$argList += @("--no-window", "--max-fps", "20")
if ($Script -ne "") { $argList += @("--script", $Script) }
elseif ($Scene -ne "") { $argList += $Scene }
$hasRes = $false
if ($GodotArgs -ne "") {
    # split respecting simple quotes
    $tokens = [regex]::Matches($GodotArgs, '("[^"]*"|\S+)') | ForEach-Object { $_.Value.Trim('"') }
    $skipNext = $false
    $filtered = @()
    $seenDashes = $false
    $prev = ""
    foreach ($t in $tokens) {
        if ($skipNext) { $skipNext = $false; continue }
        if ($t -eq "--") { $seenDashes = $true }
        if (-not $seenDashes) {
            if ($t -eq "--position" -or $t -eq "--max-fps") { $skipNext = $true; continue }
            if ($t -eq "--fullscreen" -or $t -eq "--maximized" -or $t -eq "-f" -or $t -eq "-m") { continue }
        }
        if (-not $seenDashes -and $prev -eq "--resolution" -and $t -match '^(\d+)x(\d+)$') {
            $w = [int]$Matches[1]; $h = [int]$Matches[2]
            $capW = 1024
            if ($env:HD_HIRES -eq "1") { $capW = 1280 }
            if ($w -gt $capW) { $h = [int]($h * $capW / $w); $w = $capW }
            $t = "${w}x${h}"
        }
        if ($t -eq "--resolution") { $hasRes = $true }
        $filtered += $t
        $prev = $t
    }
    $argList += $filtered
}
if (-not $Headless -and $env:HD_ALLOW_RENDER -ne "1") {
    Write-Host "[godot.ps1] REFUSED: GPU rendering is disabled for this session (the user's GPU driver hung 3 times). Use -Headless (dummy renderer, no GPU) for tests. Only the architect may render."
    exit 3
}
if ($Headless) {
    $slot = $null
} else {
    $slot = Get-GpuSlot
    # temperature guard: do not start a render while the GPU is warm
    for ($i = 0; $i -lt 60; $i++) {
        $t = 0
        try { $t = [int](& nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null | Select-Object -First 1) } catch { }
        if ($t -le 68) { break }
        Write-Host "[godot.ps1] GPU at ${t}C, waiting to cool down..."
        Start-Sleep -Seconds 10
    }
}
try {
    $text = Invoke-WithTimeout $argList $TimeoutSec (Join-Path $logDir ("last_" + $Tag + ".log"))
    if (-not $Headless) { Start-Sleep -Seconds 8 }   # cool-down gap between renders, slot still held
} finally {
    if ($slot -ne $null) { $slot.Close() }
}
Write-Host $text
