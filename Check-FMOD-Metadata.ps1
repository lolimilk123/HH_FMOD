param(
    [string]$Root = ".",
    [string]$MetaSubPath = "Metadata"  # 需要時可改成 "HH_FMOD\Metadata" 等相對路徑
)

$ErrorActionPreference = "SilentlyContinue"
$metaPath = Join-Path $Root $MetaSubPath
if (-not (Test-Path $metaPath)) {
    Write-Host "Metadata folder not found: $metaPath" -ForegroundColor Red
    exit 1
}

$bad = @()
$lfs = @()
$zero = @()

Get-ChildItem -Recurse -Filter *.xml -Path $metaPath | ForEach-Object {
    $p = $_.FullName

    # 0-byte
    if ($_.Length -eq 0) {
        $zero += $p
        return
    }

    # LFS pointer（檔案內容是指標，尚未拉回）
    $head = Get-Content -TotalCount 3 -LiteralPath $p -Encoding Byte -ErrorAction SilentlyContinue
    $text = [System.Text.Encoding]::UTF8.GetString($head)
    if ($text -match "git-lfs\.github\.com/spec/v1") {
        $lfs += $p
        return
    }

    # XML 可否解析
    try {
        [xml]$x = Get-Content -LiteralPath $p -Encoding UTF8
        if (-not $x) { $bad += "$p -> Empty XML object" }
    } catch {
        $bad += "$p -> $($_.Exception.Message)"
    }
}

if ($zero.Count -gt 0) {
    Write-Host "`n[Zero-byte files]" -ForegroundColor Yellow
    $zero | ForEach-Object { Write-Host $_ }
}
if ($lfs.Count -gt 0) {
    Write-Host "`n[LFS pointer files] (run 'git lfs pull' to restore)" -ForegroundColor Yellow
    $lfs | ForEach-Object { Write-Host $_ }
}
if ($bad.Count -gt 0) {
    Write-Host "`n[Invalid XML files]" -ForegroundColor Yellow
    $bad | ForEach-Object { Write-Host $_ }
}

if (($zero.Count + $lfs.Count + $bad.Count) -eq 0) {
    Write-Host "All Metadata XMLs parse OK." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nFound issues: zero=$($zero.Count), lfs=$($lfs.Count), invalidXml=$($bad.Count)" -ForegroundColor Red
    exit 2
}
