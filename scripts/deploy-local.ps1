<#
CD local. Despliega la aplicacion con Docker Compose.

  # Imagen construida por GitHub Actions (artifact "app-image" descargado):
  .\scripts\deploy-local.ps1 -ImageArtifact "$HOME\Downloads\app-image.zip"

  # Imagen construida en la maquina local:
  .\scripts\deploy-local.ps1 -Build
#>
param(
    [string]$ImageArtifact,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

if ($ImageArtifact) {
    $tar = $ImageArtifact
    if ($ImageArtifact -like '*.zip') {
        $dest = Join-Path $env:TEMP 'app-image'
        Expand-Archive -Path $ImageArtifact -DestinationPath $dest -Force
        $tar = Join-Path $dest 'app-image.tar.gz'
    }
    $loaded = docker load -i $tar
    if ($LASTEXITCODE -ne 0) { throw 'docker load fallo' }
    $env:APP_IMAGE = ($loaded | Select-String 'Loaded image: (.+)$').Matches[0].Groups[1].Value
} elseif ($Build) {
    $env:APP_IMAGE = 'springboot-devsecops-lab:local'
    docker build -t $env:APP_IMAGE .
    if ($LASTEXITCODE -ne 0) { throw 'docker build fallo' }
} else {
    throw 'Indicar -ImageArtifact <ruta> o -Build'
}

Write-Host "Desplegando $env:APP_IMAGE"
docker compose up -d --force-recreate
if ($LASTEXITCODE -ne 0) { throw 'docker compose up fallo' }

foreach ($i in 1..30) {
    try {
        $health = Invoke-RestMethod http://localhost:8080/actuator/health -TimeoutSec 3
        if ($health.status -eq 'UP') {
            Write-Host "Aplicacion disponible en http://localhost:8080 (health: UP)"
            docker inspect --format 'Imagen desplegada: {{.Config.Image}} ({{.Image}})' springboot-devsecops-lab
            exit 0
        }
    } catch { Start-Sleep -Seconds 2 }
}
docker compose logs --tail 50
throw 'La aplicacion no respondio en /actuator/health'
