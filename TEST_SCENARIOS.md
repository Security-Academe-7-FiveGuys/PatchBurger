# PatchBurger Security Scan Action 테스트 시나리오

이 문서는 PatchBurger Security Scan Action의 주요 동작을 검증하기 위한 테스트 시나리오를 정리한 문서입니다.

## 1. 표준 의존성 파일 자동 탐색

### 목적

표준 의존성 파일명을 사용하는 경우 Action이 파일을 자동으로 탐색하는지 확인합니다.

### 테스트 파일

```text
package.json
pom.xml
```

### Workflow 설정

```yaml
- uses: Security-Academe-7-FiveGuys/PatchBurger@v1
  with:
    api-url: ${{ secrets.FIVEGUYS_API_URL }}
    deploy-on-risk: "false"
```

### 기대 결과

```text
- 표준 의존성 파일 자동 탐색 모드가 사용됩니다.
- package.json이 fileType=package.json, ecosystem=npm으로 인식됩니다.
- pom.xml이 fileType=pom.xml, ecosystem=maven으로 인식됩니다.
- FiveGuys API가 호출됩니다.
- WARNING 또는 CRITICAL 결과가 있으면 deploy-on-risk=false 정책에 따라 workflow가 실패합니다.
```

## 2. 사용자 지정 의존성 파일 매핑

### 목적

표준 파일명이 아닌 의존성 파일도 `dependency-files` 옵션으로 검사할 수 있는지 확인합니다.

### 테스트 파일

```text
custom-deps.json
custom-pom.xml
```

### Workflow 설정

```yaml
- uses: Security-Academe-7-FiveGuys/PatchBurger@v1
  with:
    api-url: ${{ secrets.FIVEGUYS_API_URL }}
    deploy-on-risk: "false"
    dependency-files: |
      custom-deps.json:package.json:npm
      custom-pom.xml:pom.xml:maven
```

### 기대 결과

```text
- 사용자 지정 의존성 파일 모드가 사용됩니다.
- custom-deps.json이 fileType=package.json, ecosystem=npm으로 전달됩니다.
- custom-pom.xml이 fileType=pom.xml, ecosystem=maven으로 전달됩니다.
- 자동 탐색은 수행되지 않습니다.
- FiveGuys API가 호출됩니다.
```

## 3. 의존성 파일 3개 이상 차단

### 목적

선택된 의존성 파일이 3개 이상이면 API 호출 전에 Action이 실패하는지 확인합니다.

### 테스트 파일

```text
custom-deps.json
custom-pom.xml
custom-go.mod
```

### Workflow 설정

```yaml
- uses: Security-Academe-7-FiveGuys/PatchBurger@v1
  with:
    api-url: ${{ secrets.FIVEGUYS_API_URL }}
    deploy-on-risk: "false"
    dependency-files: |
      custom-deps.json:package.json:npm
      custom-pom.xml:pom.xml:maven
      custom-go.mod:go.mod:go
```

### 기대 결과

```text
- Action이 의존성 파일 3개를 감지합니다.
- FiveGuys API를 호출하기 전에 실패합니다.
- 로그에 최대 2개의 의존성 파일만 지원한다는 안내가 출력됩니다.
```

## 4. deploy-on-risk=false 위험 항목 차단

### 목적

위험 항목이 발견되었을 때 `deploy-on-risk`가 `false`이면 workflow가 실패하는지 확인합니다.

### Workflow 설정

```yaml
- uses: Security-Academe-7-FiveGuys/PatchBurger@v1
  with:
    api-url: ${{ secrets.FIVEGUYS_API_URL }}
    deploy-on-risk: "false"
```

### 기대 결과

```text
- WARNING 또는 CRITICAL 결과가 출력됩니다.
- 최종 배포 옵션 판정 구간에 deploy-on-risk=false가 표시됩니다.
- Action이 exit code 1로 종료됩니다.
- 뒤에 배포 step이 있다면 실행되지 않습니다.
```

## 5. deploy-on-risk=true 위험 항목 허용

### 목적

위험 항목이 발견되었더라도 `deploy-on-risk`가 `true`이면 workflow가 성공하는지 확인합니다.

### Workflow 설정

```yaml
- uses: Security-Academe-7-FiveGuys/PatchBurger@v1
  with:
    api-url: ${{ secrets.FIVEGUYS_API_URL }}
    deploy-on-risk: "true"
```

### 기대 결과

```text
- WARNING 또는 CRITICAL 결과가 출력됩니다.
- 최종 배포 옵션 판정 구간에 deploy-on-risk=true가 표시됩니다.
- Action이 exit code 0으로 종료됩니다.
- 뒤에 배포 step이 있다면 실행될 수 있습니다.
```

## 6. Silent Patch 탐지

### 목적

FiveGuys 데이터에 저장된 Silent Patch 의심 항목이 Action 결과에 표시되는지 확인합니다.

### 예시 의존성

`package.json` 또는 `custom-deps.json`:

```json
{
  "dependencies": {
    "lod": "4.0.4"
  }
}
```

`pom.xml` 또는 `custom-pom.xml`:

```xml
<dependency>
    <groupId>com.test</groupId>
    <artifactId>lod</artifactId>
    <version>4.0.4</version>
</dependency>
```

### 기대 결과

```text
- "Silent Patch 탐지 결과" 구간에 결과가 출력됩니다.
- source는 SILENT_PATCH입니다.
- riskLevel은 WARNING입니다.
```

## 7. dependency-files 형식 오류

### 목적

`dependency-files` 옵션의 형식이 잘못되었을 때 명확한 오류 메시지가 출력되는지 확인합니다.

### Workflow 설정

```yaml
dependency-files: |
  wrong-format
```

### 기대 결과

```text
- FiveGuys API 호출 전에 실패합니다.
- 로그에 올바른 형식인 path:fileType:ecosystem이 출력됩니다.
- 지원 예시가 함께 출력됩니다.
```

## 8. 레포지토리에 의존성 파일이 3개 이상이지만 2개만 직접 지정

### 목적

레포지토리에 의존성 파일이 3개 이상 존재하더라도 `dependency-files`로 2개만 명시하면 지정된 파일만 검사되는지 확인합니다.

### 테스트 파일

```text
package.json
pom.xml
go.mod
```

### Workflow 설정

```yaml
- uses: Security-Academe-7-FiveGuys/PatchBurger@v1
  with:
    api-url: ${{ secrets.FIVEGUYS_API_URL }}
    deploy-on-risk: "false"
    dependency-files: |
      package.json:package.json:npm
      pom.xml:pom.xml:maven
```

### 기대 결과

```text
- 사용자 지정 의존성 파일 모드가 사용됩니다.
- 자동 탐색은 수행되지 않습니다.
- package.json과 pom.xml만 검사 대상에 포함됩니다.
- go.mod는 검사 대상에서 제외됩니다.
- 선택된 파일 수가 2개이므로 FiveGuys API가 호출됩니다.
```
