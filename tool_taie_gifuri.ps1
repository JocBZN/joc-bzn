# Taie GIF-urile de animație în cadre PNG (Godot nu poate încărca GIF-uri).
#
# Rulare (din Git Bash sau PowerShell):
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool_taie_gifuri.ps1 `
#       -Src "C:\...\joc-bzn\homeless directii\Nether Enemies" -Prefix run
#
# Scrie în subfolderul `frames` al sursei: <prefix>_<directie>_<nr>.png, unde direcția se
# ia din COADA numelui fișierului (…_north-east.gif → north_east) — exact convenția pe care
# o așteaptă `tool_frames_nether.gd` și `enemy_frames.tres`.
#
# De ce PowerShell: pe mașina asta nu există ImageMagick, ffmpeg sau Python; System.Drawing
# din .NET citește cadrele unui GIF (FrameDimension.Time) și le salvează deja compuse.
# Godot NU importă PNG-urile noi singur — după ce rulezi asta, dă și:
#   godot --headless --path <proj> --import

param(
    [Parameter(Mandatory = $true)][string]$Src,
    [string]$Prefix = "run"
)

Add-Type -AssemblyName System.Drawing
$dst = Join-Path $Src "frames"
if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }
Get-ChildItem -LiteralPath $Src -Filter *.gif | ForEach-Object {
    $nume = $_.BaseName
    $dir = ($nume -split "_")[-1] -replace "-", "_"
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    $dim = New-Object System.Drawing.Imaging.FrameDimension $img.FrameDimensionsList[0]
    $n = $img.GetFrameCount($dim)
    Write-Output ("{0} -> {1} : {2} cadre, {3}x{4}" -f $nume, $dir, $n, $img.Width, $img.Height)
    for ($i = 0; $i -lt $n; $i++) {
        $img.SelectActiveFrame($dim, $i) | Out-Null
        # desenăm cadrul pe o pânză goală: GIF-urile pot avea cadre parțiale, iar Bitmap-ul
        # nou + Clear(Transparent) ne dă imaginea COMPUSĂ, nu diferența față de cadrul anterior
        $bmp = New-Object System.Drawing.Bitmap $img.Width, $img.Height
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.DrawImage($img, 0, 0, $img.Width, $img.Height)
        $g.Dispose()
        $bmp.Save((Join-Path $dst ("{0}_{1}_{2}.png" -f $Prefix, $dir, $i)), [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
    }
    $img.Dispose()
}
