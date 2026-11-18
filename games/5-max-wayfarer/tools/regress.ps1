# Headless regression suite (no GPU, memory-capped, low priority): asset import, logic smoke over generated systems, memory soak,
# the full gameplay flow and the black-hole flow. Prints PASS / FAIL per test; "ERROR" or crash lines in a log make it fail.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\regress.ps1
param([int]$MaxMemMB = 4096)
$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $PSScriptRoot
Set-Location $proj
$null = New-Item -ItemType Directory -Force (Join-Path $proj "scratch")
if (-not (Test-Path (Join-Path $proj "scratch\.gdignore"))) { $null = New-Item -ItemType File (Join-Path $proj "scratch\.gdignore") }
$runner = Join-Path $proj "tools\run_godot.ps1"
$results = @()

function Test-Log([string]$name, [string]$log, [string]$doneMarker) {
	$txt = if (Test-Path $log) { Get-Content $log -Raw -Encoding UTF8 } else { "" }
	$bad = @()
	foreach ($l in ($txt -split "`r?`n")) {
		if ($l -match "^(ERROR|SCRIPT ERROR|Parse Error)" -or $l -match "CrashHandler") { $bad += $l }
	}
	$done = $txt.Contains($doneMarker)
	$ok = $done -and ($bad.Count -eq 0)
	$line = "{0,-8} {1}" -f ($(if ($ok) { "PASS" } else { "FAIL" })), $name
	if (-not $done) { $line += "  (marker '$doneMarker' missing)" }
	if ($bad.Count -gt 0) { $line += "  ($($bad.Count) error lines, first: " + $bad[0].Substring(0, [Math]::Min(120, $bad[0].Length)) + ")" }
	Write-Host $line
	return $ok
}

function Run-Headless([string]$name, [string]$scene, [string]$userArgs, [int]$timeout, [string]$marker) {
	$log = "scratch\regress_$name.log"
	$extra = @()
	if ($userArgs -ne "") { $extra = @("-UserArgs", $userArgs) }
	$null = & powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Headless -Scene $scene @extra -TimeoutSec $timeout -MaxMemMB $MaxMemMB -Log $log
	return (Test-Log $name $log $marker)
}

# 1. import (new / changed assets and classes)
$null = & powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Import -TimeoutSec 240 -MaxMemMB $MaxMemMB -Log "scratch\regress_import.log"
$imp = Test-Path (Join-Path $proj ".godot\global_script_class_cache.cfg")
Write-Output ("{0,-8} import (class cache present: {1})" -f ($(if ($imp) { "PASS" } else { "FAIL" })), $imp)

$all = $true
$all = (Run-Headless "smoke" "res://tools/test_smoke.tscn" "--systems=1,94,333,1288,1777" 120 "SMOKE DONE") -and $all
$all = (Run-Headless "soak" "res://tools/test_soak.tscn" "--flight=20" 240 "SOAK DONE") -and $all
$all = (Run-Headless "game" "res://tools/test_game.tscn" "" 240 "GAME TEST DONE") -and $all
$all = (Run-Headless "blackhole" "res://tools/test_bh.tscn" "" 200 "BH TEST DONE") -and $all
$all = (Run-Headless "final_dry" "res://tools/test_final.tscn" "" 150 "FINAL TEST DONE") -and $all
if ($all) { Write-Output "ALL PASS" } else { Write-Output "SOME TESTS FAILED" }
