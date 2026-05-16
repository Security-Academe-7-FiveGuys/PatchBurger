# FiveGuys Security Scan Action

FiveGuys Security Scan Action scans dependency files in a GitHub repository before deployment.

The action sends dependency file contents to the FiveGuys `/query/file-check` API and prints the scan result in GitHub Actions logs.

It can be used as a CI/CD security gate:

- Stop deployment when risky dependencies are found
- Continue deployment when the user explicitly accepts the risk
- Scan standard dependency files automatically
- Scan custom-named dependency files with explicit mapping

## Quick Start

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

With this configuration, the workflow fails when WARNING or CRITICAL results are found.

## Usage With Deployment

Place this action before the deployment step.

```yaml
name: Deploy With FiveGuys Security Scan

on:
  push:
    branches: ["main"]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
        with:
          deploy-on-risk: "false"

      - name: Deploy
        run: |
          echo "Run deployment here"
```

If `deploy-on-risk` is `false` and risky dependencies are found, this action exits with failure and the later `Deploy` step does not run.

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `api-url` | No | `http://43.200.169.247:8081/query/file-check` | FiveGuys file-check API URL |
| `deploy-on-risk` | No | `false` | Continue workflow even when WARNING or CRITICAL items are found |
| `dependency-files` | No | empty | Custom dependency files. Format: `path:fileType:ecosystem`, one item per line |

## Deployment Policy

| `deploy-on-risk` | Scan result | Workflow result | Later deploy step |
| --- | --- | --- | --- |
| `false` | WARNING or CRITICAL found | Failed | Not executed |
| `true` | WARNING or CRITICAL found | Passed | Executed |
| `false` or `true` | SAFE only | Passed | Executed |

`deploy-on-risk` only controls risky scan results.

The action still fails when the scan itself cannot be completed:

- More than two dependency files are selected
- A custom dependency file path does not exist
- `dependency-files` has an invalid format
- The FiveGuys API cannot be reached
- The FiveGuys API rejects the request

## Supported Dependency Files

| File | Ecosystem |
| --- | --- |
| `package.json` | `npm` |
| `composer.json` | `composer` |
| `go.mod` | `go` |
| `pom.xml` | `maven` |
| `build.gradle` | `maven` |
| `build.gradle.kts` | `maven` |
| `requirements.txt` | `pip` |
| `pyproject.toml` | `pip` |
| `Cargo.toml` | `cargo` |

## Dependency File Limit

The action scans up to two dependency files per run.

When automatic discovery finds three or more supported dependency files, the action fails before calling the FiveGuys API.

This prevents users from assuming that all dependency files were scanned when some files were skipped.

To resolve this:

- Keep only two supported dependency files in the repository root, or
- Use `dependency-files` to explicitly choose up to two files to scan

## Custom Dependency Files

By default, this action scans standard dependency file names such as `package.json` and `pom.xml`.

If your dependency file uses a custom name, set `dependency-files`.

```yaml
- uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
  with:
    deploy-on-risk: "false"
    dependency-files: |
      custom-deps.json:package.json:npm
      custom-pom.xml:pom.xml:maven
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

`path` is relative to the repository root after `actions/checkout`.

When `dependency-files` is set, automatic dependency file discovery is skipped and only the specified files are scanned.

For example, if a repository has three dependency files but only two are specified in `dependency-files`, the action scans only the two specified files.

## Custom File Examples

Repository root:

```text
custom-deps.json
custom-pom.xml
```

Workflow:

```yaml
dependency-files: |
  custom-deps.json:package.json:npm
  custom-pom.xml:pom.xml:maven
```

Nested paths:

```text
services/frontend/custom-deps.json
services/backend/custom-pom.xml
```

Workflow:

```yaml
dependency-files: |
  services/frontend/custom-deps.json:package.json:npm
  services/backend/custom-pom.xml:pom.xml:maven
```

## Scan Result Categories

The action prints results grouped by source:

| Source | Meaning |
| --- | --- |
| `TYPOSQUATTING` | Package name is similar to a known popular package |
| `UNRESOLVED_VERSION` | Version is not exact, so vulnerability range comparison is limited |
| `ADVISORY_UNAVAILABLE` | GitHub Advisory lookup failed |
| `GITHUB_ADVISORY` | Vulnerability found in GitHub Advisory data |
| `SILENT_PATCH` | Silent Patch suspicion found in FiveGuys data |
| `SAFE` | No risk found |

## Versioning

Use the major tag for normal usage:

```yaml
- uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
```

The `v1` tag points to the latest compatible v1 release.

If strict reproducibility is required later, use a fixed release tag such as `v1.0.0`.
