# THE ONLY way tests start Godot (the user records videos: nothing may ever appear on their screen).
# The process runs on a private Windows desktop object (see gd_hidden.ps1): its windows cannot show up on the
# visible desktop, cannot take focus and have no taskbar button. Output goes to a log file which is printed afterwards.
#
# Examples (from the project folder):
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_godot.ps1 -Script res://tools/shot_test.gd -UserArgs "--out=res://scratch/a.png"
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_godot.ps1 -Headless -Script res://tools/inspect_glb.gd -UserArgs "res://assets/models/x.glb"
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_godot.ps1 -Import
param(
	[string]$Script = "",
	[string]$Scene = "",
	[string]$EngineArgs = "",
	[string]$UserArgs = "",
	[int]$TimeoutSec = 90,
	[int]$MaxFps = 30,
	[int]$MaxMemMB = 6144,
	[string]$Resolution = "1280x720",
	[string]$Log = "scratch\godot_run.log",
	[switch]$Headless,
	[switch]$Import
)
$ErrorActionPreference = "Stop"
$exe = "W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
$proj = "W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort"
Set-Location $proj
$logOut = Join-Path $proj $Log
if (Test-Path $logOut) { Remove-Item $logOut -Force }

# auto-import when new class_name scripts or new GLB models exist (global class cache / import files are stale)
if (-not $Import) {
	$cacheFile = Join-Path $proj ".godot\global_script_class_cache.cfg"
	$cacheTxt = ""
	if (Test-Path $cacheFile) { $cacheTxt = Get-Content $cacheFile -Raw }
	$need = $false
	$gdFiles = Get-ChildItem -Path "$proj\scripts", "$proj\tools" -Filter *.gd -Recurse -ErrorAction SilentlyContinue
	foreach ($f in $gdFiles) {
		$m = Select-String -Path $f.FullName -Pattern '^class_name\s+(\w+)' | Select-Object -First 1
		if ($m -ne $null) {
			$cn = $m.Matches[0].Groups[1].Value
			if ($cacheTxt -notmatch ('"class": &"' + $cn + '"')) { $need = $true; break }
		}
	}
	if (-not $need) {
		foreach ($g in (Get-ChildItem -Path "$proj\assets\models" -Filter *.glb -ErrorAction SilentlyContinue)) {
			if (-not (Test-Path ($g.FullName + ".import"))) { $need = $true; break }
		}
	}
	if ($need) {
		Write-Output "[run_godot] importing (new classes / assets) ..."
		$impLog = Join-Path $proj "scratch\auto_import.log"
		$null = & "$proj\tools\gd_hidden.ps1" -Exe $exe -ArgLine "--path `"$proj`" --headless --import" -WorkDir $proj -LogPath $impLog -TimeoutSec 180 -MaxMemMB $MaxMemMB
		$errs = Select-String -Path $impLog -Pattern "SCRIPT ERROR|Parse Error|ERROR:" -ErrorAction SilentlyContinue | Where-Object { $_.Line -notmatch "main.tscn|Failed loading resource|resource_loader" }
		foreach ($e in $errs) { Write-Output ("[import] " + $e.Line) }
	}
}

$a = "--path `"$proj`""
if ($Import) { $a += " --headless --import" }
elseif ($Headless) { $a += " --headless" }
else { $a += " --windowed --resolution $Resolution --audio-driver Dummy" }
if ($EngineArgs -ne "") { $a += " $EngineArgs" }
if ($Script -ne "") { $a += " --script $Script" }
if ($Scene -ne "") { $a += " $Scene" }
if ($UserArgs -ne "") { $a += " -- $UserArgs" }

# throttle windowed test runs (read by the Game autoload): the GPU is shared with other work and the user's screen recording
$env:WAYFARER_MAX_FPS = "$MaxFps"
$res = & "$proj\tools\gd_hidden.ps1" -Exe $exe -ArgLine $a -WorkDir $proj -LogPath $logOut -TimeoutSec $TimeoutSec -MaxMemMB $MaxMemMB
if (Test-Path $logOut) { Get-Content $logOut -Encoding UTF8 }
Write-Output $res
