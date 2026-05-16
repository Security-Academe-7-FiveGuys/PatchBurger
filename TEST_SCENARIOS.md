# FiveGuys Security Scan Action Test Scenarios

This document summarizes the main test scenarios for the FiveGuys Security Scan Action.

## 1. Standard Dependency File Discovery

### Purpose

Verify that the action automatically discovers standard dependency files.

### Files

```text
package.json
pom.xml
```

### Workflow

```yaml
- uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
  with:
    deploy-on-risk: "false"
```

### Expected Result

```text
- Standard dependency file discovery mode is used.
- package.json is detected as fileType=package.json, ecosystem=npm.
- pom.xml is detected as fileType=pom.xml, ecosystem=maven.
- The FiveGuys API is called.
- WARNING or CRITICAL results fail the workflow because deploy-on-risk is false.
```

## 2. Custom Dependency File Mapping

### Purpose

Verify that custom-named dependency files can be scanned with `dependency-files`.

### Files

```text
custom-deps.json
custom-pom.xml
```

### Workflow

```yaml
- uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
  with:
    deploy-on-risk: "false"
    dependency-files: |
      custom-deps.json:package.json:npm
      custom-pom.xml:pom.xml:maven
```

### Expected Result

```text
- Custom dependency file mode is used.
- custom-deps.json is sent as fileType=package.json, ecosystem=npm.
- custom-pom.xml is sent as fileType=pom.xml, ecosystem=maven.
- Automatic discovery is skipped.
- The FiveGuys API is called.
```

## 3. Dependency File Limit

### Purpose

Verify that the action fails before calling the API when more than two dependency files are selected.

### Files

```text
custom-deps.json
custom-pom.xml
custom-go.mod
```

### Workflow

```yaml
- uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
  with:
    deploy-on-risk: "false"
    dependency-files: |
      custom-deps.json:package.json:npm
      custom-pom.xml:pom.xml:maven
      custom-go.mod:go.mod:go
```

### Expected Result

```text
- The action detects three dependency files.
- The action fails before calling the FiveGuys API.
- The log explains that only up to two dependency files are supported.
```

## 4. Risky Result With Deployment Blocked

### Purpose

Verify that risky scan results fail the workflow when `deploy-on-risk` is `false`.

### Workflow

```yaml
- uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
  with:
    deploy-on-risk: "false"
```

### Expected Result

```text
- WARNING or CRITICAL results are printed.
- The final deployment policy section shows deploy-on-risk=false.
- The action exits with code 1.
- Later deployment steps do not run.
```

## 5. Risky Result With Deployment Allowed

### Purpose

Verify that risky scan results do not fail the workflow when `deploy-on-risk` is `true`.

### Workflow

```yaml
- uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
  with:
    deploy-on-risk: "true"
```

### Expected Result

```text
- WARNING or CRITICAL results are printed.
- The final deployment policy section shows deploy-on-risk=true.
- The action exits with code 0.
- Later deployment steps can run.
```

## 6. Silent Patch Detection

### Purpose

Verify that Silent Patch records stored in FiveGuys data are displayed in the action result.

### Example Dependencies

```json
{
  "dependencies": {
    "lod": "4.0.4"
  }
}
```

```xml
<dependency>
    <groupId>com.test</groupId>
    <artifactId>lod</artifactId>
    <version>4.0.4</version>
</dependency>
```

### Expected Result

```text
- Silent Patch results are printed in the "Silent Patch 탐지 결과" section.
- The source is SILENT_PATCH.
- The risk level is WARNING.
```

## 7. Invalid Custom Mapping Format

### Purpose

Verify that invalid `dependency-files` entries fail with a clear message.

### Workflow

```yaml
dependency-files: |
  wrong-format
```

### Expected Result

```text
- The action fails before calling the FiveGuys API.
- The log shows the correct format: path:fileType:ecosystem.
- Supported examples are printed.
```
