<#
Carga los reportes del pipeline en DefectDojo mediante la API v2 (import-scan).
Crea Product y Engagement si no existen (auto_create_context).

  $env:DD_URL   = 'http://localhost:8081'      # URL de la instancia propia
  $env:DD_TOKEN = '<API v2 Key>'               # no guardar en el repositorio
  .\scripts\defectdojo-import.ps1 -ReportsDir "$HOME\Downloads\devsecops-reports" -Engagement "CI run 12 - abc1234"

Conftest no tiene parser en DefectDojo: su reporte no se importa, se adjunta al informe.
#>
param(
    [Parameter(Mandatory)] [string]$ReportsDir,
    [Parameter(Mandatory)] [string]$Engagement,
    [string]$Product = 'spring-boot-webapi-secure',
    [string]$ProductType = 'Research and Development'
)

$ErrorActionPreference = 'Stop'
if (-not $env:DD_URL -or -not $env:DD_TOKEN) { throw 'Definir DD_URL y DD_TOKEN' }

# archivo -> parser (scan_type) y nombre del Test
$imports = @(
    @{ File = 'semgrep-report.json';   ScanType = 'Semgrep JSON Report'; Test = 'SAST - Semgrep' },
    @{ File = 'trivy-report.json';     ScanType = 'Trivy Scan';          Test = 'Imagen - Trivy' },
    @{ File = 'trivy-sca-report.json'; ScanType = 'Trivy Scan';          Test = 'SCA - Trivy SBOM' }
)

foreach ($i in $imports) {
    $path = Join-Path $ReportsDir $i.File
    if (-not (Test-Path $path)) { Write-Warning "No existe $path, se omite"; continue }

    $response = curl.exe -sS -X POST "$env:DD_URL/api/v2/import-scan/" `
        -H "Authorization: Token $env:DD_TOKEN" `
        -F "scan_type=$($i.ScanType)" `
        -F "test_title=$($i.Test)" `
        -F "product_type_name=$ProductType" `
        -F "product_name=$Product" `
        -F "engagement_name=$Engagement" `
        -F "auto_create_context=true" `
        -F "active=true" `
        -F "verified=false" `
        -F "close_old_findings=false" `
        -F "file=@$path"
    if ($LASTEXITCODE -ne 0) { throw "Fallo la carga de $($i.File)" }

    $json = $response | ConvertFrom-Json
    if (-not $json.test) { throw "DefectDojo rechazo $($i.File): $response" }
    Write-Host "$($i.Test): test $($json.test) en engagement $($json.engagement_id)"
}
