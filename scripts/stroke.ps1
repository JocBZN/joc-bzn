# Adauga un contur negru de N px in jurul desenului opac din fiecare PNG.
# Pixelii originali NU se ating: negrul se pune doar acolo unde era transparent
# si exista un pixel opac la distanta <= N (disc, nu patrat -> colturi rotunjite).
param(
    [Parameter(Mandatory=$true)][string]$Dir,
    [int]$Radius = 2,
    [int]$AlphaThreshold = 8
)

Add-Type -AssemblyName System.Drawing

# offseturile discului de raza $Radius, calculate o singura data
$off = New-Object System.Collections.Generic.List[int[]]
for ($dy = -$Radius; $dy -le $Radius; $dy++) {
    for ($dx = -$Radius; $dx -le $Radius; $dx++) {
        if (($dx * $dx + $dy * $dy) -le ($Radius * $Radius) -and -not ($dx -eq 0 -and $dy -eq 0)) {
            $off.Add(@($dx, $dy))
        }
    }
}

$files = Get-ChildItem -LiteralPath $Dir -Filter *.png | Sort-Object Name
foreach ($f in $files) {
    $bmp = [System.Drawing.Bitmap]::FromFile($f.FullName)
    $w = $bmp.Width; $h = $bmp.Height
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb

    # citim toti pixelii dintr-o data (GetPixel pe fiecare ar fi mult prea lent)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
    $px = New-Object int[] ($w * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $px, 0, $px.Length)
    $bmp.UnlockBits($data)

    # masca de opacitate a desenului ORIGINAL (conturul creste doar din ea,
    # altfel negrul proaspat ar genera si mai mult negru)
    $opac = New-Object bool[] ($w * $h)
    for ($i = 0; $i -lt $px.Length; $i++) {
        $opac[$i] = ((($px[$i] -shr 24) -band 0xFF) -gt $AlphaThreshold)
    }

    $black = [int]0xFF000000
    $added = 0
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $i = $y * $w + $x
            if ($opac[$i]) { continue }          # pixel desenat -> nu-l atingem
            foreach ($o in $off) {
                $nx = $x + $o[0]; $ny = $y + $o[1]
                if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $w -or $ny -ge $h) { continue }
                if ($opac[$ny * $w + $nx]) { $px[$i] = $black; $added++; break }
            }
        }
    }

    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $fmt)
    [System.Runtime.InteropServices.Marshal]::Copy($px, 0, $data.Scan0, $px.Length)
    $bmp.UnlockBits($data)

    $tmp = $f.FullName + ".tmp"
    $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Move-Item -LiteralPath $tmp -Destination $f.FullName -Force
    "{0}: +{1} px de contur" -f $f.Name, $added
}
