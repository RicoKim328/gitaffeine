# gitaffeine

- 계획과 결정은 `docs/PLAN.md`가 기준이다. 새 결정은 거기에 날짜와 함께 기록한다.
- Rico의 승인은 rico/cursor를 통해 받는다.

macOS 메뉴 막대 앱(CodexBar 대체). 팝업에 최근 git 기여 잔디와 AI 도구(Codex, Claude) 사용량 그래프를 보여준다.
Swift 6, SwiftUI `MenuBarExtra`, Swift Charts, macOS 14+, SwiftPM만 사용(Xcode 프로젝트 없음).

## 명령
- 빌드: `swift build`
- 테스트: `swift test`
- 앱 묶기: `scripts/bundle.sh` → `build/gitaffeine.app` + GitHub Release용 `build/gitaffeine-<버전>.zip` (실행: `open build/gitaffeine.app`)

## 구조
- `Sources/gitaffeine/`: 앱과 UI. 로직이 생기면(M1부터) `Sources/GitaffeineCore/`로 분리하고 거기서 테스트한다.
- `Tests/`: 단위 테스트. `Resources/Info.plist`: 번들 정보(`LSUIElement`로 Dock 아이콘 없음).
- 메뉴 막대 아이콘은 코드로 그린 template 이미지(`PillIcon.swift`), 고정이며 숫자 표시 없음.

## 원칙
- karpathy: 가장 단순한 해법, 최소 변경, 검증 가능한 목표. 모호하면 진행하지 말고 묻는다.
- 마일스톤 범위를 넘지 않는다. 계획에 없는 파일·기능·의존성을 추가하지 않는다.
- 파서·집계 로직은 fixture 테스트를 먼저 쓰고 구현한다.
- 로그인 토큰(Claude OAuth, `~/.codex/auth.json` 등)을 읽거나 저장하지 않는다. Codex 사용량은 `codex app-server`, GitHub는 `gh`를 통해서만.
- 사용자 설정 파일(`~/.claude/settings.json` 등)을 앱이나 에이전트가 직접 수정하지 않는다. 안내만 제공한다.
- 사용량 $는 항상 "API 정가 기준 추정"으로 표시한다.

## 작업 순서
1. 구현 → `swift build` + `swift test`
2. `ponytail:ponytail-review` + karpathy 기준 점검
3. `/codex:review` 교차 리뷰
4. Rico에게 보고 → 승인 후에만 커밋

## 묻고 나서 할 것
- 커밋·푸시, 네트워크 접근, 오래 도는 프로세스, 패키지·도구 설치, 의존성 추가.
