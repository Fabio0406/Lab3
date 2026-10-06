# Spring Boot DevSecOps Lab

Aplicacion deliberadamente vulnerable para prácticas controladas de SAST, SCA,
secret scanning, análisis de contenedores y DAST.

> **Advertencia:** ejecutar únicamente en `localhost` o en una red de laboratorio
> aislada. No desplegar en Internet ni reutilizar credenciales reales.

## Requisitos

- JDK 21
- Maven 3.9+
- Docker, opcional
- Semgrep, para el análisis local

## Iniciar la aplicación

```bash
mvn clean verify
mvn spring-boot:run
```

La aplicación estará disponible en `http://localhost:8080`.

## Endpoints del laboratorio

```text
GET  /api/products/search?name=Laptop
POST /api/comments/preview
GET  /api/admin/users/1
POST /api/auth/login
```

Ejemplo para la vista previa:

```bash
curl -X POST http://localhost:8080/api/comments/preview \
  -H "Content-Type: application/json" \
  -d '{"comment":"Comentario de prueba"}'
```

Ejemplo de autenticación:

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"usuario","password":"prueba"}'
```

## Semgrep local

```bash
semgrep scan --config auto --config .semgrep.yml src/main/java
```

## Pipeline DevSecOps (GitHub Actions)

Workflow: `.github/workflows/devsecops-pipeline.yml`. Se ejecuta en `push` a
`main`, `develop` y `lab/**`, en pull requests a `main` y manualmente.

| Job | Control | Herramienta | Reporte (artifact) |
|---|---|---|---|
| Build & Test | CI | Maven | `build-and-test` |
| SAST - Semgrep | SAST | Semgrep | `semgrep-report.json` |
| SCA - Trivy (SBOM) | SCA | CycloneDX + Trivy | `trivy-sca-report.json`, `bom.json` |
| Policy as Code - Conftest | Políticas del `Dockerfile` | Conftest (`policy/dockerfile`) | `conftest-report.json` |
| Image - Build & Trivy | Análisis de la imagen del proyecto | Trivy | `trivy-report.json`, `app-image` |
| Security Gate | Umbrales | jq | `devsecops-reports` (todos los JSON) |

El gate falla con hallazgos Semgrep `ERROR`, vulnerabilidades `CRITICAL` en la
imagen o políticas incumplidas. Los reportes se publican antes de evaluar los
umbrales, por lo que quedan disponibles aunque el pipeline se bloquee.

## Despliegue local (CD)

1. Descargar el artifact `app-image` de la ejecución de GitHub Actions.
2. Cargar la imagen y desplegarla con Docker Compose:

```powershell
.\scripts\deploy-local.ps1 -ImageArtifact "$HOME\Downloads\app-image.zip"
```

El script ejecuta `docker load`, levanta `compose.yaml` con esa imagen (etiquetada
con el SHA del commit) y espera a que `/actuator/health` responda `UP`. Para
desplegar una imagen construida en la máquina local: `.\scripts\deploy-local.ps1 -Build`.

## DefectDojo

Los reportes `semgrep-report.json` (parser *Semgrep JSON Report*),
`trivy-report.json` y `trivy-sca-report.json` (parser *Trivy Scan*) se cargan
manualmente o con `scripts/defectdojo-import.ps1`. Conftest no tiene parser en
DefectDojo; su reporte se adjunta al informe.

El docente dispone de `docs/GUIA-DOCENTE.md`, que contiene el catálogo de
hallazgos y las pruebas sugeridas. Se recomienda entregar inicialmente a los
estudiantes el resto del repositorio sin dicho documento.
