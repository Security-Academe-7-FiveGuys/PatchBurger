#!/usr/bin/env bash
set -euo pipefail

API_URL="${FIVEGUYS_API_URL:-}"
DEPLOY_ON_RISK="${FIVEGUYS_DEPLOY_ON_RISK:-false}"
CUSTOM_DEPENDENCY_FILES="${FIVEGUYS_DEPENDENCY_FILES:-}"

print_section() {
  echo ""
  echo "========================================"
  echo "$1"
  echo "========================================"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

print_section "FiveGuys Security Scan 시작"
echo "- 위험 항목 발견 시 배포 진행 여부: $DEPLOY_ON_RISK"

if [ -z "$(trim "$API_URL")" ]; then
  print_section "FiveGuys API URL 설정 오류"
  echo "- api-url 입력값이 비어 있습니다."
  echo "- GitHub Secrets에 API 주소를 저장한 뒤 workflow에서 api-url로 전달하세요."
  echo "- 예시: api-url: \${{ secrets.FIVEGUYS_API_URL }}"
  exit 1
fi

echo "- API URL: $API_URL"

rm -f files.json files.tmp request.json response.txt
echo "[]" > files.json

add_file() {
  local path="$1"
  local file_type="$2"
  local ecosystem="$3"

  if [ ! -f "$path" ]; then
    return
  fi

  echo "- 발견: $path / ecosystem=$ecosystem"

  jq --arg path "$path" \
     --arg fileType "$file_type" \
     --arg ecosystem "$ecosystem" \
     --rawfile content "$path" \
     '. + [{
       path: $path,
       fileType: $fileType,
       ecosystem: $ecosystem,
       content: $content
     }]' files.json > files.tmp

  mv files.tmp files.json
}

add_custom_file() {
  local line="$1"
  local path
  local file_type
  local ecosystem
  local extra

  IFS=':' read -r path file_type ecosystem extra <<< "$line"

  path=$(trim "${path:-}")
  file_type=$(trim "${file_type:-}")
  ecosystem=$(trim "${ecosystem:-}")

  if [ -z "$path" ] || [ -z "$file_type" ] || [ -z "$ecosystem" ] || [ -n "${extra:-}" ]; then
    print_section "사용자 지정 의존성 파일 형식 오류"
    echo "- 잘못된 입력: $line"
    echo "- 올바른 형식: path:fileType:ecosystem"
    echo "- 예시: frontend/custom-deps.json:package.json:npm"
    echo "- 지원 fileType/ecosystem 조합:"
    echo "  - package.json / npm"
    echo "  - pom.xml / maven"
    echo "  - build.gradle / maven"
    echo "  - build.gradle.kts / maven"
    echo "  - requirements.txt / pip"
    echo "  - pyproject.toml / pip"
    echo "  - composer.json / composer"
    echo "  - go.mod / go"
    echo "  - Cargo.toml / cargo"
    exit 1
  fi

  if [ ! -f "$path" ]; then
    print_section "사용자 지정 의존성 파일 없음"
    echo "- 지정한 파일을 찾을 수 없습니다: $path"
    echo "- dependency-files의 첫 번째 값은 checkout된 레포지토리 루트 기준 실제 파일 경로여야 합니다."
    echo "- 예시: custom-deps.json:package.json:npm"
    exit 1
  fi

  add_file "$path" "$file_type" "$ecosystem"
}

print_error_response() {
  print_section "FiveGuys API 호출 실패"

  if jq empty response.txt 2>/dev/null; then
    echo "- 상태 코드: $HTTP_STATUS"
    echo "- 에러 코드: $(jq -r '.code // "-"' response.txt)"
    echo "- 메시지: $(jq -r '.message // "-"' response.txt)"
    echo "- 상세 원인:"
    jq -r '.detail // "-"' response.txt | cut -c1-300 | fold -s -w 100 | sed 's/^/  /'
    echo "- 요청 경로: $(jq -r '.path // "-"' response.txt)"

    local supported_count
    supported_count=$(jq '(.supportedFormats // []) | length' response.txt)
    if [ "$supported_count" -gt 0 ]; then
      echo "- 지원 형식:"
      jq -r '.supportedFormats[]? | "  - " + .' response.txt
    fi
  else
    echo "- 상태 코드: $HTTP_STATUS"
    echo "- 응답 내용:"
    cat response.txt || true
  fi
}

print_results() {
  local title="$1"
  local source="$2"
  local empty_message="$3"

  print_section "$title"

  local count
  count=$(jq --arg source "$source" '
    [.fileResults[]?.results[]? | select(.source == $source)] | length
  ' response.txt)

  if [ "$count" -eq 0 ]; then
    echo "- 없음"
    return
  fi

  jq -r --arg source "$source" --arg empty_message "$empty_message" '
    .fileResults[]? as $file |
    $file.results[]? |
    select(.source == $source) |
    . as $result |
    (
      if $file.ecosystem == "maven" and ($result.name | contains(":")) then
        ($result.name | split(":")[1])
      else
        $result.name
      end
    ) as $displayName |
    "- [" + $file.path + "] "
    + $displayName + "@" + ($result.version // "-")
    + " -> riskLevel=" + ($result.riskLevel // "-")
    + " / 사유: "
    + (
        $result.typosquatting.reason
        // $result.aiSummary
        // $result.silentPatch.patchSummary
        // $empty_message
      )
  ' response.txt
}

print_section "검사 대상 파일 탐색"

if [ -n "$(trim "$CUSTOM_DEPENDENCY_FILES")" ]; then
  echo "- 사용자 지정 의존성 파일 모드"
  echo "- 형식: path:fileType:ecosystem"

  while IFS= read -r line || [ -n "$line" ]; do
    line=$(trim "$line")

    if [ -z "$line" ] || [ "${line#\#}" != "$line" ]; then
      continue
    fi

    add_custom_file "$line"
  done <<< "$CUSTOM_DEPENDENCY_FILES"
else
  echo "- 표준 의존성 파일 자동 탐색 모드"

  add_file "package.json" "package.json" "npm"
  add_file "composer.json" "composer.json" "composer"
  add_file "go.mod" "go.mod" "go"
  add_file "pom.xml" "pom.xml" "maven"
  add_file "build.gradle" "build.gradle" "maven"
  add_file "build.gradle.kts" "build.gradle.kts" "maven"
  add_file "requirements.txt" "requirements.txt" "pip"
  add_file "pyproject.toml" "pyproject.toml" "pip"
  add_file "Cargo.toml" "Cargo.toml" "cargo"
fi

FILE_COUNT=$(jq 'length' files.json)

if [ "$FILE_COUNT" -eq 0 ]; then
  echo "- 의존성 파일을 찾을 수 없습니다."
  exit 0
fi

if [ "$FILE_COUNT" -gt 2 ]; then
  print_section "검사 대상 파일 개수 초과"
  echo "- 발견된 의존성 파일 수: $FILE_COUNT"
  echo "- FiveGuys Security Scan은 현재 최대 2개의 의존성 파일만 검사할 수 있습니다."
  echo "- 일부 파일만 검사하면 누락 위험이 있으므로 검사를 중단합니다."
  echo "- 해결 방법: 자동 탐색 결과가 3개 이상이면 dependency-files 옵션으로 검사할 파일을 최대 2개까지 명시하세요."
  echo "- 이미 dependency-files를 사용 중이라면 항목을 2개 이하로 줄이세요."
  echo "- 검사 대상 파일:"
  jq -r '.[] | "  - " + .path + " / fileType=" + .fileType + " / ecosystem=" + .ecosystem' files.json
  exit 1
fi

jq -n --slurpfile files files.json '{ files: $files[0] }' > request.json

print_section "FiveGuys API 호출"

HTTP_STATUS=$(curl -s -o response.txt -w "%{http_code}" \
  -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @request.json || true)

echo "- HTTP_STATUS: $HTTP_STATUS"

if [ -z "$HTTP_STATUS" ] || [ "$HTTP_STATUS" = "000" ]; then
  print_section "FiveGuys API 연결 실패"
  echo "- FiveGuys API 서버에 연결할 수 없습니다."
  echo "- 확인 대상: $API_URL"
  exit 1
fi

if [ "$HTTP_STATUS" -ge 400 ]; then
  print_error_response
  exit 1
fi

TOTAL_FILES=$(jq -r '.totalFiles // 0' response.txt)
TOTAL_LIBRARIES=$(jq -r '.totalLibraries // 0' response.txt)
SAFE_COUNT=$(jq -r '.safeCount // 0' response.txt)
WARNING_COUNT=$(jq -r '.warningCount // 0' response.txt)
CRITICAL_COUNT=$(jq -r '.criticalCount // 0' response.txt)

print_section "FiveGuys Security Scan 결과 요약"
echo "- 검사 파일 수: $TOTAL_FILES"
echo "- 검사 라이브러리 수: $TOTAL_LIBRARIES"
echo "- SAFE: $SAFE_COUNT"
echo "- WARNING: $WARNING_COUNT"
echo "- CRITICAL: $CRITICAL_COUNT"

print_section "검사 대상 파일"
jq -r '
  .fileResults[]?
  | "- " + .path
  + " / fileType=" + .fileType
  + " / ecosystem=" + .ecosystem
  + " / status=" + (.status // "SUCCESS")
' response.txt

print_section "의존성 항목 없음 안내"
NO_DEPENDENCIES_COUNT=$(jq '[.fileResults[]? | select(.status == "NO_DEPENDENCIES_FOUND")] | length' response.txt)

if [ "$NO_DEPENDENCIES_COUNT" -gt 0 ]; then
  jq -r '
    .fileResults[]?
    | select(.status == "NO_DEPENDENCIES_FOUND")
    | "- " + .path + " / " + (.message // "의존성 항목을 찾을 수 없습니다.")
  ' response.txt
else
  echo "- 없음"
fi

print_results "1. 타이포스쿼팅 탐지 결과" "TYPOSQUATTING" "타이포스쿼팅 의심 항목입니다."
print_results "2. 버전 확인 불가 결과" "UNRESOLVED_VERSION" "정확한 버전 비교가 제한됩니다."
print_results "3. GitHub Advisory 조회 실패 결과" "ADVISORY_UNAVAILABLE" "GitHub Advisory 조회에 실패했습니다."
print_results "4. GitHub Advisory 탐지 결과" "GITHUB_ADVISORY" "GitHub Advisory 취약점이 발견되었습니다."
print_results "5. Silent Patch 탐지 결과" "SILENT_PATCH" "Silent Patch 의심 항목입니다."
print_results "6. SAFE 결과" "SAFE" "안전한 항목입니다."

print_section "최종 배포 옵션 판정"
echo "- 위험 항목 발견 시 배포 진행 여부: $DEPLOY_ON_RISK"
echo "- WARNING: $WARNING_COUNT"
echo "- CRITICAL: $CRITICAL_COUNT"

if [ "$WARNING_COUNT" -eq 0 ] && [ "$CRITICAL_COUNT" -eq 0 ]; then
  echo "- 위험 항목이 없어 배포를 계속 진행합니다."
  exit 0
fi

if [ "$DEPLOY_ON_RISK" = "true" ]; then
  echo "- 위험 항목이 발견되었지만 사용자 옵션에 따라 배포를 계속 진행합니다."
  exit 0
fi

echo "- 위험 항목이 발견되어 사용자 옵션에 따라 배포를 중단합니다."
echo "- 위험 항목이 있어도 배포하려면 deploy-on-risk 값을 true로 설정하세요."
exit 1
