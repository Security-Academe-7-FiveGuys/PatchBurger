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

If a later deployment step exists in the same job, this action should run before that deployment step.

```yaml
      - uses: actions/checkout@v4

      - uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
        with:
          deploy-on-risk: "false"

      - name: Deploy
        run: |
          echo "Run deployment here"
```

When `deploy-on-risk` is `false`, this action fails if WARNING or CRITICAL results are found. The later deployment step will not run.

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `api-url` | No | `http://43.200.169.247:8081/query/file-check` | FiveGuys file-check API URL |
| `deploy-on-risk` | No | `false` | If `true`, the workflow continues even when WARNING or CRITICAL items are found |
| `dependency-files` | No | empty | Custom dependency files. Format: `path:fileType:ecosystem`, one item per line |

## Deployment Policy

| `deploy-on-risk` | Scan result | Workflow result |
| --- | --- | --- |
| `false` | WARNING or CRITICAL found | Failed |
| `true` | WARNING or CRITICAL found | Passed |
| `false` or `true` | SAFE only | Passed |

`deploy-on-risk` only controls risky scan results. The action still fails when the scan itself cannot be completed, for example:

- More than two dependency files are found
- A custom dependency file path does not exist
- `dependency-files` has an invalid format
- The FiveGuys API cannot be reached
- The FiveGuys API rejects the request

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

If three or more dependency files are found, the action fails before calling the API. This prevents users from assuming that all dependency files were scanned when some files were skipped.

To resolve this, keep only two supported dependency files in the repository root or use `dependency-files` to explicitly choose the two files to scan.

## Custom Dependency Files

By default, this action scans standard dependency file names such as `package.json` and `pom.xml`.

If your dependency file uses a custom name, set `dependency-files` manually.

```yaml
- uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
  with:
    deploy-on-risk: "false"
    dependency-files: |
      frontend/custom-deps.json:package.json:npm
      backend/custom-pom.xml:pom.xml:maven
```

Each line uses this format:

```text
path:fileType:ecosystem
```

| Part | Description |
| --- | --- |
| `path` | Actual file path in the user's repository |
| `fileType` | Dependency file type passed to the FiveGuys API |
| `ecosystem` | Package ecosystem used for scanning |

When `dependency-files` is set, automatic dependency file discovery is skipped and only the specified files are scanned.

Examples:

```yaml
dependency-files: |
  custom-deps.json:package.json:npm
  custom-pom.xml:pom.xml:maven
```

```yaml
dependency-files: |
  services/api-deps.json:package.json:npm
  services/backend-pom.xml:pom.xml:maven
```

`path` is relative to the repository root after `actions/checkout`.

## Versioning

Use the major tag for normal usage:

```yaml
- uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
```

The `v1` tag points to the latest compatible v1 release. If strict reproducibility is required later, use a fixed release tag such as `v1.0.0`.
