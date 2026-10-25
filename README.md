# gitaffeine

macOS 메뉴 막대 앱. 팝업에 최근 git 기여 잔디와 AI 도구(Codex, Claude, Grok) 사용량을 보여준다.

- macOS 14 이상, Apple Silicon(arm64)만.
- 금액은 모두 "API 정가 기준 추정"이다. Claude는 실험적 방식(로컬 기록), Grok은 비공식 방식(`grok agent`)이다.
- 로그인 토큰을 읽거나 저장하지 않는다. 각 탭은 이미 설치·로그인된 도구를 통해서만 값을 얻는다.
  - Git: `gh`(GitHub 로그인, 없으면 로컬 저장소만), Codex: `codex`, Claude: Claude Code 로컬 기록, Grok: `grok`

## 설치

1. [Releases](https://github.com/RicoKim328/gitaffeine/releases)에서 둘 중 하나를 받는다.
   - `gitaffeine-<버전>.dmg`: 열어서 `gitaffeine.app`을 옆의 Applications 폴더로 끌어다 놓는다.
   - `gitaffeine-<버전>.zip`: 압축을 풀고 `gitaffeine.app`을 `/Applications`로 옮긴다.
2. 처음 열 때 macOS가 막는다. Apple 공증을 받지 않은 앱(ad-hoc 서명)이기 때문이다. 둘 중 하나로 연다.
   - 앱을 한 번 열어 경고를 본 뒤, 시스템 설정 > 개인정보 보호 및 보안 아래쪽의 "그래도 열기"를 누른다.
   - 또는 터미널에서 `xattr -dr com.apple.quarantine /Applications/gitaffeine.app` 후 연다.
3. Dock 아이콘 없이 메뉴 막대에 알약 아이콘이 생긴다.

자동 업데이트는 없다. 새 버전은 Releases에서 새 dmg나 zip을 받아 `/Applications/gitaffeine.app`을 바꾸고, 위 2번을 다시 한다.

### Claude 5h·주간 한도

`scripts/claude-statusline.sh`를 Claude Code statusLine에 직접 설치해야 표시된다. 방법은 스크립트 첫 줄 주석에 있다. 앱은 `~/.claude/settings.json`을 고치지 않는다.

## 소스에서 빌드

- 빌드: `swift build`, 테스트: `swift test`
- 앱 묶기: `scripts/bundle.sh` → `build/gitaffeine.app`, `build/gitaffeine-<버전>.zip`, `build/gitaffeine-<버전>.dmg`

## 릴리스 (관리자)

1. `Resources/Info.plist`의 `CFBundleShortVersionString`을 올린다.
2. `scripts/bundle.sh` 실행 후, 커밋에 같은 값의 태그를 단다(예: `v0.1.0`).
3. GitHub 웹에서 그 태그로 Release를 만들고 `build/gitaffeine-<버전>.zip`과 `.dmg`를 첨부한다.
