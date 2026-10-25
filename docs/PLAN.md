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
| M4 | 팝업 상단 탭 UI(Git·Codex·Claude·Grok) + Codex 사용량(`codex app-server`): 계정, 5h·주간 한도, AI 잔디·그래프 | 완료 `21e87c3` (푸시됨) |
| M5 | Claude 사용량(로컬 jsonl + rate_limits), "실험적" 라벨, $ 추정(Codex 포함), 폭 340 통일·높이 맞춤, 20주 잔디 | 완료 `63b6259` (푸시됨) |
| M5.5 | Grok 사용량 조사 + Grok 탭 최소 버전(`grok agent`의 `_x.ai/billing`): tier, 주간 한도, 선불 잔액 (2026-10-25 Rico: 번호 M5.5, M6는 그대로) | 완료 `6587ca6` (푸시됨) |
| M6 | 앱 아이콘, ~~Developer ID 서명, 공증~~(2026-10-25 Rico: 멤버십 없음, GitHub 배포), nvm·fnm·사용자 npm prefix에 설치된 codex 찾기(2026-10-25 codex 리뷰 P2, M4는 고정 경로 3곳만), Grok 제목 이메일, Claude 한도 안내 구분 | 구현 완료, 커밋 승인 대기 |

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
- 2026-10-25 표시: 공개 프로필 이메일이 있으면 `github <이메일>`, 없으면 `github @<로그인>`. → 2026-10-25 Rico: AI 탭과 같게 괄호 형식 `github (<이메일>)` / `github (@<로그인>)` / `github (이메일 미설정)` / 집계 전 `github (…)`. 로컬 커밋은 공개 이메일과 전역 git 이메일 둘 다로 거름.
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
  - `github (<계정>)`
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
- 2026-10-25 그래프는 $/토큰 토글. $는 항상 "API 정가 기준 추정". 기간 7/30/60일(기본 60)은 AI 그래프용이고 잔디와는 별개. ($는 M5부터, 아래 AI 탭 결정 참고)
- ~~xAI(Grok)는 범위 밖~~ → 2026-10-25 Grok을 범위에 포함(아래 "AI 탭" 결정). 공식 계정 단위 사용량 소스는 못 찾음 ❓.

### AI 탭 (2026-10-25 결정, M4부터)
- 2026-10-25 팝업 상단에 Git·Codex·Claude·Grok 선택 탭을 둠. 하단이 아님.
  - 탭은 각 서비스를 대표하는 이미지를 아이콘으로 만들어 표시.
  - Git 탭은 기존 M2/M3 구성 그대로.
- ~~2026-10-25 AI 탭 구성: 16주 AI 잔디 → 구분선 → 그래프~~ → 아래 레이아웃으로 대체.
- 2026-10-25 AI 탭 레이아웃(위→아래, 구역 사이마다 구분선, 버튼은 맨 아래 공통):
  - `<AI 이름> (<email>)`
  - 5h 구역: 5h 창이 있을 때만(없으면 구역·구분선·안내 문구 모두 없음). 20칸 한 줄, 칸 하나 = 5%, **남은 %**를 왼쪽부터 채우고 끝 칸은 남은 만큼 옅게. 아래 작은 회색 글자: 남은 %("남음 37%"), 초기화까지 남은 시간, 토큰, 금액
  - 주간 구역(2026-10-25 Rico 재결정, 아래 "1번"의 7칸을 대체): 5h와 같은 20칸 한 줄, **남은 %**를 왼쪽부터 채움. 글자는 그대로("경과 … · 남음 … · 이 속도면 초기화 때 남음 약 N%(예상)" / "초기화까지 … · 약 N 토큰 · 금액"). 7칸·1~7 숫자 줄·24시간 범위 툴팁은 삭제.
  - ~~주간 구역(2026-10-25 Rico 결정 "1번"): 목적은 초기화 전까지 얼마나 빨리 쓰는지 보기. 7칸 = 한도 창 시작 시각부터 24시간씩(날짜 경계 아님). 지난 칸은 채우고 진행 중 칸은 부분 채움, 남은 칸은 빈 칸. 칸 아래 1~7, 마우스를 올리면 그 24시간 범위("10-24 09:30 ~ 10-25 09:30"). 글자: "경과 1일 5시간(17%) · 남음 95% · 이 속도면 초기화 때 남음 약 71%(예상)" / "초기화까지 … · 약 N 토큰 · 금액". 예상 = 지금까지의 평균 속도(사용 % ÷ 경과 비율). 창 시작 직후 값이 흔들려도 숨기지 않고 "예상" 표기만 둠(2026-10-25 Rico). 계정 데이터에는 시간 단위가 없어서 칸에 토큰을 나눠 넣지 않음(로컬 codex 로그는 이 Mac 사용분만 있어서 안 씀). 요일별 7칸은 철회~~
  - 16주 AI 잔디 → 일별 막대 그래프 → [7|30|60일](기본 60) + [토큰|$]
- 2026-10-25 아이콘은 SF Symbols 일반 심볼(Git `arrow.triangle.branch`, Codex `terminal`, Claude `sparkle`, Grok `bolt`). 상표가 아니라서 공개 배포 전 교체 불필요.
- 2026-10-25 Codex 데이터(실호출로 확인): `account/usage/read`는 쓴 날의 하루 토큰 합계만 줌(모델·입출력 구분, 시간 단위 없음, 합계 = `lifetimeTokens`). `account/rateLimits/read`는 창별 사용 %·초기화 시각. Rico 계정(prolite)은 주간 창만 있음. `account/read`에서 email.
  - app-server는 stdin이 닫히면 응답 없이 끝나므로 응답이 다 올 때까지 stdin을 열어 둠. 실험적 메서드라 initialize에 `experimentalApi: true`.
  - 주간 토큰 = 한도 창 첫날~오늘의 일별 합계(첫날 전체 포함이라 "약"). 5h 토큰은 계산 불가라 "—".
  - 16주 AI 잔디 색 단계 = 쓴 날들을 3등분한 기준(커밋은 고정 1·3·6).
- 2026-10-25 금액: M4는 "금액 추정 · M5 예정"만 표시, [$] 토글 비활성. M5에서 "API 정가 기준 추정"으로 구현(Codex는 단일 단가 가정, 부풀려질 수 있음을 감안).
- 2026-10-25 조회: 팝업 열 때마다 + 새로고침 즉시. 디스크 캐시 없음(과거 값은 서버에 있음). codex 없음·로그인 오류는 안내 문구.
- 2026-10-25 Claude 탭은 "M5 예정", Grok 탭은 "미지원". Grok 조사는 M5 이후 별도 마일스톤(로컬 `grok usage <session>`가 CLI 세션별 토큰·비용만 줌, 계정 일별 API는 못 찾음).
- 2026-10-25 아이콘: 상표·로고 이미지 파일을 그대로 넣지 않음.
  - 라이선스·배포 문제가 없는 방식(직접 그린 단순 심볼, SF Symbols 등)을 M4 계획에서 제안하고 Rico에게 물음.
  - 개인 사용 단계라도 공개 배포 전에 교체가 필요한지 명시.
- 2026-10-25 Grok: 구현 전에 xAI/Grok 사용량 데이터 소스를 조사해 옵션을 정리하고 Rico에게 물음.
  - 소스가 없으면 가장 단순한 기본안 제안: 탭만 두고 "미지원" 표시.
  - 마일스톤 배치는 조사 결과에 따라 제안(탭 UI와 Codex는 M4, Claude는 M5).
- 2026-10-25 Grok 조사 결과(M5.5): 보려는 것은 SuperGrok 구독 계정 사용량(Rico).
  - `grok agent --no-leader stdio`(ACP)의 확장 메서드 `_x.ai/billing`(앞에 `_` 필요, 문서 없음 ❓)이 계정 단위 `creditUsagePercent`(0–100), 현재 주간 기간(start·end), `prepaidBalance.val`, `subscription_tier`를 줌. 응답 약 1초. 일별 기록·토큰·$는 없음.
  - 로컬 세션 + `grok usage`(✅, 이 Mac 단위)는 이 Mac에 세션이 없어 제외. External OTEL(⚠️ alpha, 설정 변경·수신 서버 필요)·xAI 관리 API(관리 키 저장 필요, 규칙 위반)도 제외.
  - ~~`_x.ai/auth/check_subscription`은 이메일·team_id 등 신원 정보가 있어 쓰지 않음.~~ → 2026-10-25 Rico 승인: 이메일은 화면 표시에만 사용(아래 Grok 탭 제목). team_id 등 다른 필드는 쓰지 않음.
- 2026-10-25 Grok 탭(M5.5, Rico): 최소 버전. 계정 줄(tier) + 주간 한도 칸, "비공식" 표시, 잔디·그래프 없음. Codex처럼 팝업 열 때·새로고침 때 grok을 띄워 조회 후 종료.
  - 선불 잔액은 항상 원래 숫자 + "(단위 미확인)"으로 표시(2026-10-25 값 0이라 단위 확정 못 함).
  - grok agent 같은 실행(네트워크·프로세스)은 매번 실행 전에 rico/cursor로 물어봄(2026-10-25 Rico).
  - 2026-10-25 제목(Rico 승인, M6 커밋에 포함): 같은 grok 호출에 `_x.ai/auth/check_subscription`(id 3)을 더해 `result.meta.email`만 읽음. 제목 "tier (이메일)", 이메일 없으면 tier만("SuperGrok"), tier도 없으면 "Grok", 로딩 중 "Grok (…)". check_subscription만 실패하면 한도는 그대로, 제목에서 이메일만 뺌. 이메일은 메모리에서 화면 표시에만 사용(저장·로깅·전송 안 함).
- 2026-10-25 설정 창: 나중에 다시 만들어서 git, claude 등 서비스를 고를 수 있게 할 예정.
  - 구현 시점과 세부 설계는 미정이고 논의 후 결정.
  - M4에서 설정 모듈은 건드리지 않음.

### Claude 사용량·금액·창 크기 (M5, 2026-10-25 Rico 결정)
- 2026-10-25 Claude 일별 토큰: `~/.claude/projects/**/*.jsonl`(서브에이전트 포함)을 매번 전부 파싱(9.4MB 0.07초, 증분 offset 없음).
  - 한 응답이 content block마다 같은 (message.id, requestId)로 여러 줄 기록됨(913줄 중 고유 395). 키별로 합계가 가장 큰 줄(마지막 줄 = 최종 output)만 셈. 여러 파일에 있어도 한 번.
  - `<synthetic>` 모델 제외. 날짜는 timestamp(UTC)를 이 Mac 시간대로.
- 2026-10-25 캐시 `~/Library/Application Support/gitaffeine/claude-daily.json`(날짜 × 모델 × 토큰 5종). 병합은 날짜별로 합계가 더 큰 쪽 유지(Rico 승인). 한계: 같은 날 일부 로그만 지워진 뒤 새 사용이 생기면 과소 집계 → 코드 shortcut 주석.
- 2026-10-25 계정 표시: `~/.claude.json`의 `oauthAccount.emailAddress`만 읽음(Rico 승인). 토큰은 읽지 않음.
- 2026-10-25 5h·주간 %: `scripts/claude-statusline.sh` 래퍼가 statusLine 입력을 `claude-status.json`에 저장하고 같은 입력으로 기존 명령을 실행(출력·종료 코드 그대로, 검증함). 설치는 Rico가 직접. 필드는 `rate_limits.five_hour|seven_day.{used_percentage, resets_at}`(Claude Code 2.1.310 내장 문서로 확인). 초기화 시각이 지난 창은 숨김.
- 2026-10-25 Claude $: 모델별 API 정가(claude-api 스킬 표, 2026-10-06 기준). cache write 5m 1.25× · 1h 2× 입력가, cache read는 모델별 값. 단가 없는 모델은 빼고 "단가 없는 모델 제외" 표시. fast mode는 표준가로 계산(기록에 없음).
- 2026-10-25 Codex $: 혼합가 = 0.916×캐시입력가 + 0.080×입력가 + 0.004×출력가(이 Mac `~/.codex/sessions` 비율, 1회 측정), 모델은 gpt-6-sol(Rico 결정), developers.openai.com/api/docs/pricing 2026-10-25 기준 입력 $2.00 · 캐시 입력 $0.20 · 출력 $10.00(272K 이하) → $0.3832/MTok. "API 정가 기준 추정 · gpt-6-sol 혼합 단가" 표시. Claude는 모델별 정가 유지(Rico 결정).
- 2026-10-25 데이터 시작일(캐시·로그의 가장 이른 날) 이전 날은 잔디에서 빗금. Codex는 서버에 전체 기록이 있어 빗금 없음.
- ~~2026-10-25 창 크기: 탭마다 폭 다르게~~ → 2026-10-25 Rico 번복: 폭이 바뀌면 창이 아이콘 기준으로 다시 가운데 정렬돼 탭 바가 움직이고 빈 영역이 보임. 폭은 모든 탭 340으로 통일(Rico가 만족한 Codex 폭), 높이는 탭마다 내용에 자동. 탭 바는 창 폭을 채움. 창 위치 보정 코드는 넣지 않음. 긴 글자는 잘리지 않고 줄바꿈.

- 2026-10-25 잔디 16주 → 20주(Rico 결정 b): 297pt로 폭 340을 채움. 기여한 날 %와 AI 잔디도 20주(140일) 기준. 위 M2 "16주" 결정을 대체.
- 2026-10-25 짧은 탭에서 팝업 상하에 빈 공간이 남는 문제(Rico 제보): MenuBarExtra 창은 커지기만 하고 줄지 않음(`.fixedSize`만으로는 해결 안 됨, Rico 확인). Rico 결정 2번: 뷰에서 `NSView.window`로 창을 얻어 내용 높이로 줄임(위쪽 끝 고정, 아래만). 한계: SwiftUI가 만든 창을 직접 바꾸므로 macOS가 MenuBarExtra 창 처리를 바꾸면 다시 고쳐야 할 수 있음.

### M6 (2026-10-25 Rico 결정)
- 서명·공증: 유료 Apple Developer 멤버십 없음 → Developer ID 서명·공증 안 함. ad-hoc 서명 유지, GitHub로 배포.
- 배포(2026-10-25 Rico, 추천안 전부): zip(`ditto -c -k --keepParent`, bundle.sh가 `build/gitaffeine-<버전>.zip` 생성) · Rico가 GitHub 웹에서 Release 생성·zip 첨부(에이전트는 `gh release create` 안 함) · README에 "그래도 열기"와 `xattr -dr com.apple.quarantine` 두 방법 안내 · 자동 업데이트 없음(새 Release로 교체) · Apple Silicon(arm64)만 · Info.plist 버전을 손으로 올리고 같은 값의 git 태그(v0.1.0).
- 2026-10-25 dmg 추가(Rico, 추천안 전부): zip과 dmg 둘 다 제공. bundle.sh가 `hdiutil create -format UDZO`로 `build/gitaffeine-<버전>.dmg` 생성(앱 + `/Applications` 바로가기, 기본 Finder 창, 배경·아이콘 위치 꾸미기 없음, dmg 자체 서명 안 함). Gatekeeper 안내는 그대로(dmg에서 복사한 앱도 격리 표시가 이어짐). 검증: `hdiutil verify`, 읽기 전용 연결 후 앱·바로가기 존재와 `codesign --verify --deep --strict` 확인.
- codex 찾기: 정해진 위치 방식. 고정 3곳 → nvm(`~/.nvm/versions/node/*/bin`) → fnm(`~/.local/share/fnm`, `~/Library/Application Support/fnm`의 `node-versions/*/installation/bin`) → `~/.npmrc`의 `prefix=`(`~/`, `${HOME}` 펼침)`/bin`. 버전이 여러 개면 높은 버전 먼저(숫자 비교). 로그인 셸 실행 방식은 안 씀(느리고 멈출 위험).
- 아이콘: 진한 갈색(커피) 둥근 사각형 위 흰 알약(PillIcon 모양 확대). `scripts/make-icon.swift`로 그려 `iconutil`로 `AppIcon.icns`, bundle.sh가 매번 생성(바이너리 파일을 저장소에 두지 않음).
- Claude 한도 안내: 래퍼 파일 없음(미설치)과 파일은 있는데 현재 rate_limits 없음을 다른 문구로 표시(2026-10-25 Rico 승인, 상태줄 래퍼 설치 후 정상 표시 확인).

### 마일스톤별 검증 기준 (남은 것)
- M4: 앱 수치 = app-server 원본 JSON 합계 · `codex` 없음·미로그인 시 안내 · 금액 자리에 "추정" 라벨.
  - 2026-10-25 실행 확인(Rico 승인): 일별 버킷 합계 755,120,134 = `lifetimeTokens`. 팝업 Codex 탭이 원본 JSON과 일치(사용 5% — 당시 표시 기준, 초기화 약 5일 19시간, 주간 약 12,223,872 토큰, 토요일 칸만 색, 5h 구역 없음).
- M5: 고정 fixture로 파서·중복 제거 테스트 · fixture 삭제 후에도 캐시 일별 값 유지 · 데이터 없는 날 빗금 · 래퍼 설치 후 기존 statusline 출력이 바뀌지 않음.
- M6: ~~`spctl -a -vv build/gitaffeine.app` 통과~~ (Developer ID 없음, 2026-10-25) → 2026-10-25 Rico 결정: `codesign --verify --deep --strict build/gitaffeine.app` 통과(bundle.sh가 실행) · Finder에서 아이콘 표시 · Release zip을 다른 macOS 계정이나 다른 Mac에서 README 절차대로 열어 Git/Codex/Claude/Grok 탭 표시(Rico 확인) · `spctl`은 "rejected"가 정상(기록만).
  - 2026-10-25 확인: Rico가 bundle.sh 실행 → `build/gitaffeine-0.1.0.zip` 생성, `codesign --verify --deep --strict` 통과, `spctl` rejected(예상대로), Finder 갈색 알약 아이콘·팝업 정상(Rico). 다른 계정/Mac 확인은 Release 업로드 후 Rico.

## 하네스
- 순서: 구현(파서·집계는 fixture 테스트 먼저) → `swift build` + `swift test` → `ponytail:ponytail-review` → karpathy 점검 → `/codex:review`(M3·M5는 `/codex:adversarial-review` 추가) → rico/cursor로 보고 → Rico 승인 후 커밋 → 별도 승인 후 푸시.
- Codex review gate는 켜져 있음(응답이 끝날 때마다 Codex 리뷰가 돎, 최대 15분). `/codex:rescue`는 막혔을 때만 `--effort high`로.
- 모델: Claude 메인 claude-opus-5-5, Codex 기본 gpt-6-astra / medium.
- 2026-10-25 wshobson/agents 플러그인은 쓰지 않음(현재 구성 유지).
- 커밋·푸시·네트워크·설치·의존성 추가·오래 도는 프로세스는 rico/cursor를 통한 Rico 승인 후에만.

## 다음 작업 / 열린 질문
- 2026-10-25 M5는 Rico 결정으로 리뷰 생략(ponytail 1회만 실행, 지적 1건 주석 수정으로 반영). 커밋 `63b6259`, 푸시 완료.
- 다음 작업: M6 커밋 승인 대기(2026-10-25). 이후 Rico가 v0.1.0 태그·Release. (2026-10-25 ponytail·codex 리뷰 통과, Rico 팝업 확인 후 커밋) M5.5 결과·결정은 위 "Grok 조사 결과", "Grok 탭" 항목.

### M5.5 시작 맥락 (2026-10-25, 조사 시작 시점 기록. 결과는 위 결정 항목)
- 목표: 조사만. xAI/Grok 사용량 데이터 소스를 찾아 선택지(출처, 얻는 값: 일별 토큰·비용·한도 %, 계정 단위인지 이 Mac 단위인지, 공식/실험/비공식 ✅⚠️❓, 필요한 권한)를 표로 정리해 Rico에게 묻는다. 구현은 Rico 결정 후, 마일스톤 배치도 그때 제안.
- 지금까지 아는 것:
  - 로컬 `grok usage <session>`은 Grok CLI 세션별 토큰·비용만 줌. 계정 단위 일별 사용량 API는 못 찾음(❓).
  - Grok 탭은 SF Symbol `bolt`, 현재 "미지원" 문구만 표시(`GitaffeineApp.swift`의 `case .grok`).
  - 소스가 없으면 기본안: 탭만 두고 "미지원" 유지.
- 조사 순서 제안: ① 로컬에서 읽기만 — `grok` CLI 위치·버전·`--help`, `grok usage` 출력 형식, 로컬 세션 기록 폴더(있다면 Codex·Claude처럼 일별 집계 가능한지) ② 공식 문서(xAI API 사용량·과금 문서, Grok 구독 한도 표시 방법) — 네트워크는 Rico 사전 승인 후, 승인된 페이지만 ③ 선택지 표 + 권장안을 rico/cursor로 보고.
- 붙어 있는 구현 틀(조사 결과가 맞으면 재사용): `UsageTab`(계정 줄, 5h·주간 칸, 20주 잔디, 일별 그래프, [토큰|$]), `UsageWindow`(한도 창), 일별 캐시 방식(`ClaudeUsage.loadDaily`, 날짜별 큰 합계 유지).
- 지킬 규칙: 로그인 토큰·인증 파일(예: Grok/xAI 자격 증명, `~/.codex/auth.json`, Claude OAuth)을 읽거나 저장하지 않음. 사용자 설정 파일은 수정하지 않고 안내만. 네트워크·설치·새 의존성·오래 도는 프로세스는 rico/cursor로 Rico 사전 승인. 결정은 Rico. 커밋·푸시는 각각 승인 후. 팝업 화면 확인은 화면 캡처가 아니라 Rico가 앱을 실행해서 봄.
- ~~M4 계획 질문(토글·기간 위치, 아이콘, Grok)~~ → 2026-10-25 위 "AI 탭" 결정으로 답함.
- ~~Codex 사용량을 잔디로 보일지, 그래프로 보일지~~ → 2026-10-25 잔디와 그래프 둘 다로 결정.
- 마일스톤마다 끝날 때: 이 문서의 상태 갱신 → 커밋 → 보고 → (Rico 결정 시) 세션 clear.
- clear 뒤 Reason 세션 주소가 유지되는지는 확인되지 않음. clear 직후 rico/cursor가 확인.
