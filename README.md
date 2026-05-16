# FiveGuys Security Scan Action

FiveGuys Security Scan Action은 GitHub Actions에서 의존성 파일을 검사하고, 위험 항목 발견 여부에 따라 이후 배포 단계를 진행하거나 중단할 수 있도록 돕는 CI/CD 보안 게이트입니다.

이 Action은 사용자의 레포지토리에서 의존성 파일을 읽고, FiveGuys 백엔드의 `/query/file-check` API로 파일 내용을 전달합니다. 백엔드는 의존성 파일 내부의 라이브러리를 파싱한 뒤 타이포스쿼팅, GitHub Advisory, Silent Patch 등을 검사하고 결과를 반환합니다.

주요 기능은 다음과 같습니다.

- 표준 의존성 파일 자동 탐색
- 사용자 지정 의존성 파일 매핑
- WARNING/CRITICAL 결과에 따른 배포 중단 또는 허용
- 의존성 파일 3개 이상 선택 시 검사 중단
- GitHub Actions 로그 기반 검사 결과 출력

## 빠른 시작

사용자 레포지토리에 `.github/workflows/fiveguys-security-scan.yml` 파일을 생성합니다.

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

위 설정에서는 검사 결과에 WARNING 또는 CRITICAL 항목이 발견되면 workflow가 실패합니다.

## 배포 단계와 함께 사용하기

실제 배포 workflow에서는 FiveGuys Action을 배포 step보다 먼저 실행해야 합니다.

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
          echo "여기에 실제 배포 명령어를 작성합니다."
```

`deploy-on-risk`가 `false`이고 위험 항목이 발견되면 FiveGuys Action이 실패 처리됩니다. 따라서 뒤에 있는 `Deploy` step은 실행되지 않습니다.

## 입력 옵션

| 이름 | 필수 여부 | 기본값 | 설명 |
| --- | --- | --- | --- |
| `api-url` | 아니오 | `http://43.200.169.247:8081/query/file-check` | FiveGuys `/query/file-check` API 주소 |
| `deploy-on-risk` | 아니오 | `false` | WARNING 또는 CRITICAL 항목이 발견되어도 workflow를 계속 진행할지 여부 |
| `dependency-files` | 아니오 | 빈 값 | 사용자 지정 의존성 파일 목록. 형식은 `path:fileType:ecosystem` |

## deploy-on-risk 정책

| `deploy-on-risk` | 검사 결과 | workflow 결과 | 이후 배포 step |
| --- | --- | --- | --- |
| `false` | WARNING 또는 CRITICAL 발견 | 실패 | 실행되지 않음 |
| `true` | WARNING 또는 CRITICAL 발견 | 성공 | 실행됨 |
| `false` 또는 `true` | SAFE만 존재 | 성공 | 실행됨 |

`deploy-on-risk`는 위험 항목 발견 시 배포를 허용할지 결정하는 옵션입니다.

다만 아래와 같이 검사 자체를 정상적으로 수행할 수 없는 경우에는 `deploy-on-risk`가 `true`여도 실패합니다.

- 선택된 의존성 파일이 3개 이상인 경우
- `dependency-files`에 지정한 파일 경로가 존재하지 않는 경우
- `dependency-files` 형식이 잘못된 경우
- FiveGuys API 서버에 연결할 수 없는 경우
- FiveGuys API가 요청을 거부한 경우

## 지원 의존성 파일

| 파일 | 생태계 |
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

## 의존성 파일 개수 제한

이 Action은 한 번의 실행에서 최대 2개의 의존성 파일만 검사합니다.

자동 탐색 모드에서 지원 의존성 파일이 3개 이상 발견되면, 일부 파일만 검사하지 않고 API 호출 전에 실패 처리합니다.

이 정책은 사용자가 일부 파일만 검사된 결과를 전체 의존성 파일이 검사된 것으로 오해하는 상황을 방지하기 위한 것입니다.

해결 방법은 다음과 같습니다.

- 레포지토리 내 검사 대상 의존성 파일을 2개 이하로 유지합니다.
- `dependency-files` 옵션으로 검사할 파일을 최대 2개까지 명시합니다.

## 사용자 지정 의존성 파일

기본적으로 이 Action은 `package.json`, `pom.xml`처럼 표준 의존성 파일명을 자동 탐색합니다.

파일명이 표준과 다르다면 `dependency-files` 옵션을 사용해 실제 파일 경로, `fileType`, `ecosystem`을 직접 지정할 수 있습니다.

```yaml
- uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
  with:
    deploy-on-risk: "false"
    dependency-files: |
      custom-deps.json:package.json:npm
      custom-pom.xml:pom.xml:maven
```

각 줄은 다음 형식을 사용합니다.

```text
path:fileType:ecosystem
```

| 항목 | 설명 |
| --- | --- |
| `path` | 사용자 레포지토리에 존재하는 실제 파일 경로 |
| `fileType` | FiveGuys API에 전달할 의존성 파일 형식 |
| `ecosystem` | 검사 기준이 되는 패키지 생태계 |

`path`는 `actions/checkout` 이후의 레포지토리 루트를 기준으로 작성합니다.

`dependency-files` 옵션이 설정되면 자동 탐색은 수행하지 않고, 사용자가 지정한 파일만 검사합니다.

예를 들어 실제 레포지토리에 의존성 파일이 3개 있더라도 `dependency-files`에 2개만 지정했다면, 지정된 2개만 검사합니다.

## 사용자 지정 파일 예시

레포지토리 루트에 파일이 있는 경우:

```text
custom-deps.json
custom-pom.xml
```

workflow:

```yaml
dependency-files: |
  custom-deps.json:package.json:npm
  custom-pom.xml:pom.xml:maven
```

폴더 내부에 파일이 있는 경우:

```text
services/frontend/custom-deps.json
services/backend/custom-pom.xml
```

workflow:

```yaml
dependency-files: |
  services/frontend/custom-deps.json:package.json:npm
  services/backend/custom-pom.xml:pom.xml:maven
```

## 검사 결과 분류

Action 로그에는 결과가 source 기준으로 나뉘어 출력됩니다.

| source | 의미 |
| --- | --- |
| `TYPOSQUATTING` | 유명 패키지와 이름이 유사한 타이포스쿼팅 의심 항목 |
| `UNRESOLVED_VERSION` | 정확한 버전이 아니어서 취약점 범위 비교가 제한되는 항목 |
| `ADVISORY_UNAVAILABLE` | GitHub Advisory 조회에 실패한 항목 |
| `GITHUB_ADVISORY` | GitHub Advisory에서 취약점이 발견된 항목 |
| `SILENT_PATCH` | FiveGuys 데이터에서 Silent Patch 의심 항목으로 탐지된 항목 |
| `SAFE` | 위험 항목이 발견되지 않은 항목 |

## 버전 태그 정책

일반 사용자는 major 태그를 사용합니다.

```yaml
- uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1
```

`v1` 태그는 호환 가능한 최신 v1 버전을 가리킵니다.

특정 시점의 동작을 고정하고 싶다면 고정 릴리즈 태그를 사용할 수 있습니다.

```yaml
- uses: Security-Academe-7-FiveGuys/fiveguys-security-scan-action@v1.0.0
```

## 테스트 시나리오

주요 검증 시나리오는 [TEST_SCENARIOS.md](./TEST_SCENARIOS.md)에 정리되어 있습니다.
