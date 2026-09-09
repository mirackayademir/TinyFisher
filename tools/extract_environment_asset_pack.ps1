param(
    [switch]$KeepPack
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$PackPath = Join-Path $RepoRoot 'art_sources\environment\tinyfisher_environment_assets_2026-09-09.zip'

if (-not (Test-Path -LiteralPath $PackPath)) {
    throw "Asset pack bulunamadı: $PackPath"
}

Write-Host 'TinyFisher environment asset pack çıkarılıyor...'
Expand-Archive -LiteralPath $PackPath -DestinationPath $RepoRoot -Force

$AssetRoot = Join-Path $RepoRoot 'assets\environment'
$PngCount = (Get-ChildItem -LiteralPath $AssetRoot -Filter '*.png' -Recurse -File).Count

Write-Host "Tamamlandı. assets/environment altında $PngCount PNG bulundu."
Write-Host 'Beklenen checkpoint asset sayısı: 36'

if ($PngCount -lt 36) {
    Write-Warning '36 dosyanın tamamı görünmüyor. Checkpoint MD içindeki listeyi kontrol et.'
}

if (-not $KeepPack) {
    Write-Host 'Kaynak ZIP repoda bırakılıyor; otomatik silme yapılmadı.'
}
