# FiveGuys Security Scan Action

GitHub Action for scanning dependency files with the FiveGuys Security Scan API.

## Usage

Create `.github/workflows/fiveguys-security-scan.yml` in your repository.

```yaml
name: FiveGuys Security Scan

on:
  push:
    branches: ["main"]

jobs:
  security-scan:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
        with:
          deploy-on-risk: "false"
```

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `api-url` | No | `http://43.200.169.247:8081/query/file-check` | FiveGuys file-check API URL |
| `deploy-on-risk` | No | `false` | If `true`, the workflow continues even when WARNING or CRITICAL items are found |

## Supported Dependency Files

- `package.json` / npm
- `composer.json` / Composer
- `go.mod` / Go
- `pom.xml` / Maven
- `build.gradle` / Maven
- `build.gradle.kts` / Maven
- `requirements.txt` / pip
- `pyproject.toml` / pip
- `Cargo.toml` / Cargo

The action scans up to two dependency files per repository run.
