# Headless (NO GPU) smoke test of every module sandbox: starts the game, runs 6 s, counts error lines.
param([string[]]$Modules = @("m1_terrain","m2_sky","m3_ship","m4_player","m5_blackhole","m6_ui","m7a_content","m7b_life","m8_audio"))
$root = "W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort"
foreach ($m in $Modules) {
    $sb = Join-Path $root "_sandbox\$m"
    & "$root\tools\godot.ps1" -Project $sb -Mode run -Headless -TimeoutSec 120 -Tag hchk -GodotArgs "-- --autostart --preset=air:1:300 --quit-at=7" *> $null
    $log = Join-Path $sb ".logs\last_hchk.log"
    $errs = @(); if (Test-Path $log) { $errs = @(Get-Content $log | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|ERROR:|WARNING:" }) }
    Write-Host ("== {0}: errorlines={1}" -f $m, $errs.Count)
    $errs | Group-Object | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object { Write-Host ("     {0}x {1}" -f $_.Count, $_.Name) }
}
