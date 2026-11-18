# Smoke-test every module sandbox (windowless): starts the game on Verdant at 300 m, takes a screenshot, counts error lines.
#   powershell -NoProfile -File tools/check_sandboxes.ps1 [-Modules m1_terrain,m3_ship] [-Preset air:1:300]
param([string[]]$Modules = @("m1_terrain","m2_sky","m3_ship","m4_player","m5_blackhole","m6_ui","m7a_content","m7b_life","m8_audio"),
      [string]$Preset = "air:1:300", [int]$Quit = 9)
$root = "W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort"
foreach ($m in $Modules) {
    $sb = Join-Path $root "_sandbox\$m"
    if (-not (Test-Path $sb)) { Write-Host "== $m : no sandbox"; continue }
    & "$root\tools\godot.ps1" -Project $sb -Mode run -TimeoutSec 150 -Tag chk -GodotArgs "--resolution 640x360 -- --autostart --preset=$Preset --shot=.previews/chk_$m.png@$($Quit-3) --quit-at=$Quit" *> $null
    $log = Join-Path $sb ".logs\last_chk.log"
    $errs = @()
    if (Test-Path $log) { $errs = @(Get-Content $log | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|ERROR:|WARNING:" }) }
    $shot = Test-Path (Join-Path $sb ".previews\chk_$m.png")
    Write-Host ("== {0}: errorlines={1} shot={2}" -f $m, $errs.Count, $shot)
    $errs | Group-Object | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object { Write-Host ("     {0}x {1}" -f $_.Count, $_.Name) }
}
