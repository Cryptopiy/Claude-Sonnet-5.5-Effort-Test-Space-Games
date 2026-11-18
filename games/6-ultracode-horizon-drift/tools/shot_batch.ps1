# Take a batch of windowless screenshots of the MAIN project: powershell -NoProfile -File tools/shot_batch.ps1 [-Project <path>] [-Set biomes|space|all]
param([string]$Project = "", [string]$Set = "all", [int]$Wait = 9, [string]$Res = "960x540")
$root = "W:\YouTube\Sonnet 5.5 Effort Test\6. Ultracode Effort"
$p = if ($Project -ne "") { $Project } else { $root }
$jobs = @()
if ($Set -eq "biomes" -or $Set -eq "all") {
    $jobs += @(@("b0_volcanic","air:0:150"),@("b1_lush","air:1:150"),@("b2_barren","air:2:150"),@("b3_desert","air:3:150"),@("b4_frozen","air:4:150"),@("b6_toxic","air:6:150"),@("b7_exotic","air:7:150"))
}
if ($Set -eq "space" -or $Set -eq "all") {
    $jobs += @(@("s_planet","space:1:250"),@("s_star","star:500"),@("s_gas","space:5:500"),@("s_bh","bh:200"),@("s_bh_near","bh:45"),@("s_landed","landed:1"),@("s_foot","foot:1"))
}
foreach ($j in $jobs) {
    $name = $j[0]; $pre = $j[1]
    & "$root\tools\godot.ps1" -Project $p -Mode run -NoImport -TimeoutSec 120 -Tag shot -GodotArgs "--resolution $Res -- --autostart --preset=$pre --shot=.previews/batch_$name.png@$Wait --quit-at=$($Wait+2)" *> $null
    $log = Join-Path $p ".logs\last_shot.log"
    $n = 0; if (Test-Path $log) { $n = @(Get-Content $log | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|ERROR:" }).Count }
    Write-Host ("{0,-14} {1,-14} errors={2}" -f $name, $pre, $n)
}
