# gitaffeine 계획과 결정

이 문서가 계획·결정의 기준이다. 새 결정은 날짜와 함께 여기에 기록한다. Rico의 승인은 rico/cursor를 통해 받는다.
표기: ✅ 공식 문서로 확인 / ⚠️ 공식이지만 실험적 / ❓ 비공식·미확인

## 마일스톤 상태 (2026-10-25)
| M | 내용 | 상태 |
|---|---|---|
| M0 | 뼈대: SwiftPM, 메뉴 막대 앱, 알약 아이콘, bundle.sh, CLAUDE.md | 완료 `32db5e1` (푸시됨) |
| M1 | home 스캔, 로컬 커밋 일별 집계, 잔디 | 완료 `e8b21d1` (푸시됨) |
| M2 | 팝업 구성 변경, 16주 잔디, 기여한 날 %, 설정 창 | 완료 `d1f9cf4` (푸시됨) |
| M3 | GitHub 기여 달력(gh) + GitHub가 아직 세지 않은 로컬 커밋 | 완료 `5440fd4` (푸시됨) |
| M4 | Codex 사용량(`codex app-server`), 토큰/$ 토글, 캐시 | **다음** — Rico의 go 전까지 시작 금지 |
| M5 | Claude 사용량(로컬 jsonl + rate_limits), "실험적" 라벨 | 대기 |
| M6 | 앱 아이콘, Developer ID 서명, 공증 | 대기 |

## 제품
- macOS 메뉴 막대 앱, CodexBar 대체. 최소 macOS 14. 처음엔 Rico 개인 사용, 나중에 배포.
- Swift 6 + SwiftUI `MenuBarExtra`(.window), Swift Charts. SwiftPM만 사용(Xcode 프로젝트 없음), `.app`은 `scripts/bundle.sh`로 묶음. 번들 id `com.munankim.gitaffeine`. Dock 아이콘 없음(`LSUIElement`).
- 메뉴 막대 아이콘: 세로 알약(가운데 가로줄, 아래 절반 채움), 코드로 그린 template 이미지. 고정, 숫자 표시 없음.

## 결정 목록
### git 스캔·집계
- 2026-10-25 스캔 루트는 home 고정. 제외: `~/Library`, 숨김 폴더(.Trash 포함), app bundle, `node_modules`, `.build`, `build`, `DerivedData`, `Pods`, `.venv`. 심볼릭 링크는 따라가지 않고, `.git`을 찾으면 그 아래로 내려가지 않음.
- 2026-10-25 iCloud 동기화 영역 저장소(.git의 `isUbiquitousItem == true`)는 다운로드 여부와 상관없이 전부 제외하고 git을 실행하지 않음. 이유: 일부 파일이 iCloud에만 있는 저장소에서 git이 10분 넘게 멈췄고, 다운로드 상태(Current) 값으로는 판별이 안 됨. git 호출에는 시간 제한을 두지 않음.
- 2026-10-25 `git log --all --since`. `--since-as-filter`는 iCloud 저장소에서 끝나지 않아 쓰지 않음. 시계가 틀린 커밋이 그 뒤 기록을 가릴 수 있는 한계는 코드에 shortcut 주석으로 남김.
- 2026-10-25 커밋 해시로 중복 제거(worktree·같은 저장소의 여러 clone). 날짜는 작성일, 이 Mac 시간대 기준이고 날짜 키는 항상 양력.
- 2026-10-25 저장소 목록·refs 캐시는 만들지 않음. 실측으로 충분히 빠름: 탐색 0.25초, 집계 콜드 11.7초 / 이후 0.8초, iCloud 제외 후 약 0.5초.

### 계정·GitHub (M3)
- 2026-10-25 이메일은 하나만 쓰고 목록 UI는 없음. 출처는 gh 로그인 계정. gh를 쓸 수 없으면 전역 `git config --global user.email`.
- 2026-10-25 표시: 공개 프로필 이메일이 있으면 `github <이메일>`, 없으면 `github @<로그인>`. 로컬 커밋은 공개 이메일과 전역 git 이메일 둘 다로 거름.
- 2026-10-25 GitHub 기여 = `gh api graphql`의 viewer `contributionCalendar` 전체(커밋+PR+이슈+리뷰). gh가 토큰을 관리하고 앱은 토큰을 읽거나 저장하지 않음. gh는 `/opt/homebrew/bin/gh`, `/usr/local/bin/gh` 순서로 찾음. private 기여에는 `read:user` 스코프 필요.
- 2026-10-25 gh 호출에만 60초 시간 제한. 넘으면 로컬 집계로 대체하고 새로고침 버튼도 다시 활성화.
- 2026-10-25 합계 = GitHub 달력 + GitHub가 아직 세지 않은 로컬 커밋.
  - "GitHub가 이미 셈" = URL host가 github.com인 remote의 기본 브랜치(`<remote>/HEAD` → `main` → `master`) 또는 `gh-pages`에서 도달 가능한 커밋.
  - 이미 fetch된 ref만 쓰고 네트워크는 쓰지 않음. 이렇게 세어진 해시는 모든 저장소(경로로 만든 다른 clone 포함)에서 뺌.
- 2026-10-25 남는 오차는 각주로 표시: "* fetch 안 한 저장소·squash merge·fork·시간대 차이로 오차가 있을 수 있음". fork 여부는 저장소별 네트워크 확인을 하지 않음.
- 2026-10-25 라벨: gh 연결 시 "GitHub + 미푸시 로컬 커밋", 미연결(gh 없음·미로그인·오류·시간 초과) 시 "Local 프로젝트 · gh 로그인 필요".
- 2026-10-25 실연동 결과(RicoKim328, 07-12~10-25):
  - 공개 프로필 페이지와 9일 일치
  - API에만 있는 4일(16건)은 로그인해야 보이는 private 기여로 추정
  - 10-14·10-16은 하루 차이(시간대 경계로 추정, 미확인)
  - 푸시 전후 10-25 합계가 7로 같아 이중 집계 없음

### 팝업·설정 (M2)
- 2026-10-25 팝업 구성(위→아래):
  - `github <계정>`
  - 라벨(작은 회색 글자)
  - 잔디 16주(112일, 팝업 너비 280pt를 채움)
  - "<오늘 날짜(시스템 언어 긴 형식)> · 기여한 날 N% (활동일/표시일일)"(작은 회색 글자)
  - (gh 연결 시) 각주
  - 구분선(라이트 검정 / 다크 흰색)
  - [설정] [새로고침] … 오른쪽 끝 작은 [종료](⌘Q)
- 2026-10-25 기여한 날 % = 기여 1개 이상인 날 수 ÷ 잔디에 표시된 날 중 오늘까지의 날 수, 정수로 반올림.
- 2026-10-25 팝업을 열 때와 새로고침 때 다시 집계. 집계 중에는 새로 시작하지 않음. 첫 집계 전에는 계정 자리에 "…".
- 2026-10-25 설정 창: Git 탭 하나에 계정과 출처를 읽기 전용으로 표시. 스캔 제외 경로 설정은 없음(고정 목록). 열 때 앱을 앞으로 가져옴.
- 2026-10-25 잔디 뷰는 일별 counts를 받으므로 M4/M5에서 AI 사용량도 같은 크기의 잔디로 표시할 예정.

### AI 사용량 (M4·M5, 조사 결과 기반)
- Claude 구독(Pro/Max):
  - 로그인 토큰(OAuth)을 제3자 앱이 쓰는 것은 약관상 금지 ✅
  - 2026-10-25 A안: 로컬 `~/.claude/projects/**/*.jsonl` 증분 파싱 ❓ + status line `rate_limits`(5시간·7일 %) ✅
    - statusLine 래퍼는 앱이 스크립트와 안내만 제공하고 Rico가 직접 설치. 현재 statusLine은 token-optimizer가 쓰고 있으므로 앱이나 에이전트가 사용자 설정을 수정하지 않음
    - 설치하지 않으면 토큰 그래프만 보임
    - 일별 합계는 `~/Library/Application Support/gitaffeine/` 캐시에 누적해서 jsonl이 삭제돼도 유지(기본 30일 삭제, 이 Mac은 `cleanupPeriodDays: 99999`)
    - 데이터 없는 날은 빗금, UI에 "실험적 방식" 라벨
- Codex 구독(ChatGPT): `codex app-server`의 `account/usage/read`(일별 토큰) ⚠️, `account/rateLimits/read`(%) ⚠️. 사용자의 codex CLI가 자기 로그인으로 호출하므로 앱이 토큰을 만지지 않음.
- 2026-10-25 그래프는 $/토큰 토글. $는 항상 "API 정가 기준 추정". 기간 7/30/60일(기본 60)은 AI 그래프용이고 잔디와는 별개.
- xAI(Grok)는 공식 사용량 API를 확인하지 못해 범위 밖.

### 마일스톤별 검증 기준 (남은 것)
- M4: 앱 수치 = app-server 원본 JSON 합계 · `codex` 없음·미로그인 시 안내 · $에 "추정" 라벨.
- M5: 고정 fixture로 파서·중복 제거 테스트 · fixture 삭제 후에도 캐시 일별 값 유지 · 데이터 없는 날 빗금 · 래퍼 설치 후 기존 statusline 출력이 바뀌지 않음.
- M6: `spctl -a -vv build/gitaffeine.app` 통과 · 다른 계정에서 실행 확인.

## 하네스
- 순서: 구현(파서·집계는 fixture 테스트 먼저) → `swift build` + `swift test` → `ponytail:ponytail-review` → karpathy 점검 → `/codex:review`(M3·M5는 `/codex:adversarial-review` 추가) → rico/cursor로 보고 → Rico 승인 후 커밋 → 별도 승인 후 푸시.
- Codex review gate는 켜져 있음(응답이 끝날 때마다 Codex 리뷰가 돎, 최대 15분). `/codex:rescue`는 막혔을 때만 `--effort high`로.
- 모델: Claude 메인 claude-opus-5-5, Codex 기본 gpt-6-astra / medium.
- 2026-10-25 wshobson/agents 플러그인은 쓰지 않음(현재 구성 유지).
- 커밋·푸시·네트워크·설치·의존성 추가·오래 도는 프로세스는 rico/cursor를 통한 Rico 승인 후에만.

## 다음 작업 / 열린 질문
- M4 시작 전 Rico가 정할 것:
  - Codex 사용량을 AI 잔디(같은 16주 크기)로 보일지, 그래프로 보일지, 둘 다인지
  - 토큰/$ 토글과 7/30/60 기간 UI의 위치
- 마일스톤마다 끝날 때: 이 문서의 상태 갱신 → 커밋 → 보고 → (Rico 결정 시) 세션 clear.
- clear 뒤 Reason 세션 주소가 유지되는지는 확인되지 않음. clear 직후 rico/cursor가 확인.
