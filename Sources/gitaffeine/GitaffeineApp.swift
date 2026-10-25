import GitaffeineCore
import SwiftUI

@main
struct GitaffeineApp: App {
    @State private var contributions = ContributionStore()
    @State private var codex = CodexStore()
    @State private var claude = ClaudeStore()
    @State private var grok = GrokStore()

    var body: some Scene {
        MenuBarExtra {
            PopupView(store: contributions, codex: codex, claude: claude, grok: grok)
                .task { await contributions.refresh() }
                .task { await codex.refresh() }
                .task { await claude.refresh() }
                .task { await grok.refresh() }
        } label: {
            Image(nsImage: PillIcon.image)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(account: contributions.account, fromGitHub: contributions.fromGitHub)
        }
    }
}

struct PopupView: View {
    let store: ContributionStore
    let codex: CodexStore
    let claude: ClaudeStore
    let grok: GrokStore
    @Environment(\.openSettings) private var openSettings
    @State private var tab = Tab.git

    enum Tab: CaseIterable {
        case git, codex, claude, grok

        var symbol: String {
            switch self {
            case .git: "arrow.triangle.branch"
            case .codex: "terminal"
            case .claude: "sparkle"
            case .grok: "bolt"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Label(String(describing: $0).capitalized, systemImage: $0.symbol) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            switch tab {
            case .git: gitTab
            case .codex: codexTab
            case .claude: claudeTab
            case .grok: grokTab
            }
            Rectangle().fill(Color.primary).frame(height: 1)
            HStack {
                Button("설정") {
                    NSApp.activate() // menu bar apps have no Dock icon; bring the settings window to the front
                    openSettings()
                }
                Button("새로고침") {
                    Task { await store.refresh() }
                    Task { await codex.refresh() }
                    Task { await claude.refresh() }
                    Task { await grok.refresh() }
                }
                .disabled(store.isRefreshing && codex.isRefreshing && claude.isRefreshing && grok.isRefreshing)
                Spacer()
                Button("종료") { NSApplication.shared.terminate(nil) }
                    .font(.caption)
                    .keyboardShortcut("q")
            }
        }
        .padding()
        // One width for every tab so the popup doesn't jump sideways; the height follows each tab's content.
        .frame(width: 340, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { ShrinkWindow(height: $0.size.height) })
    }

    private var codexTab: some View {
        UsageTab(title: codex.usage?.email.map { "Codex (\($0))" } ?? (codex.hasLoaded ? "Codex" : "Codex (…)"),
                 error: codex.error, windows: codex.usage?.windows ?? [], dailyTokens: codex.usage?.dailyTokens,
                 dailyCost: codex.usage?.dailyCost, costNote: "API 정가 기준 추정 · gpt-6-sol 혼합 단가")
    }

    private var claudeTab: some View {
        let usage = claude.usage
        return UsageTab(title: usage?.email.map { "Claude (\($0))" } ?? (claude.hasLoaded ? "Claude" : "Claude (…)"),
                        note: "실험적 방식 · 이 Mac의 Claude Code 기록", error: claude.error,
                        windows: usage?.windows ?? [],
                        noWindowsHint: usage?.hasStatusLine == true
                            ? "5h·주간 한도: 상태줄 입력에 현재 rate_limits 없음 (요금제에 없거나 초기화 후 아직 갱신 전, Claude Code에서 메시지를 보내면 갱신)"
                            : "5h·주간 한도: scripts/claude-statusline.sh를 statusLine에 직접 설치하면 표시 (방법은 스크립트 첫 줄 주석)",
                        dailyTokens: usage?.dailyTokens, dailyCost: usage?.dailyCost,
                        costNote: usage?.unpricedModels.isEmpty == false ? "API 정가 기준 추정 · 단가 없는 모델 제외"
                                                                         : "API 정가 기준 추정",
                        firstDay: usage?.daily.keys.min())
    }

    private var grokTab: some View {
        let usage = grok.usage
        let title = usage?.tier.map { tier in usage?.email.map { "\(tier) (\($0))" } ?? tier }
        return UsageTab(title: title ?? (grok.hasLoaded ? "Grok" : "Grok (…)"),
                        note: "비공식 방식(grok agent) · 계정 단위"
                            + (usage.map { "\n선불 잔액 \($0.prepaidBalance.map(String.init) ?? "—") (단위 미확인)" } ?? ""),
                        error: grok.error, windows: usage.map { [$0.window] } ?? [])
    }

    /// The M2/M3 Git view, unchanged.
    @ViewBuilder
    private var gitTab: some View {
        let today = Date()
        let calendar = Calendar.current
        let weeks = ContributionCalendar.weeks(endingAt: today, count: ContributionStore.weekCount, calendar: calendar)
        let share = ContributionCalendar.activeShare(of: weeks, counts: store.counts, today: today, calendar: calendar)

        Text("github (\(store.account ?? (store.hasLoaded ? "이메일 미설정" : "…")))").font(.headline)
        Text(store.fromGitHub ? "GitHub + 미푸시 로컬 커밋" : "Local 프로젝트 · gh 로그인 필요")
            .font(.caption).foregroundStyle(.secondary)
        ContributionGrid(weeks: weeks, counts: store.counts, today: today, calendar: calendar)
        Text("\(today.formatted(date: .long, time: .omitted)) · 기여한 날 \(share.percent)% (\(share.activeDays)/\(share.shownDays)일)")
            .font(.caption)
            .foregroundStyle(.secondary)
        if store.fromGitHub {
            Text("* fetch 안 한 저장소·squash merge·fork·시간대 차이로 오차가 있을 수 있음")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Commit counts for the grid, recounted each time the popup opens or on 새로고침.
@MainActor @Observable
final class ContributionStore {
    /// 20 weeks (140 days), 297pt wide: fills the 340pt popup.
    nonisolated static let weekCount = 20

    private(set) var counts: [String: Int] = [:]
    /// The gh account's public email (else "@login"), or the global git email when gh isn't available.
    private(set) var account: String?
    /// True when counts are the GitHub calendar plus local commits GitHub doesn't count yet.
    private(set) var fromGitHub = false
    private(set) var isRefreshing = false
    private(set) var hasLoaded = false

    private struct Snapshot: Sendable {
        var account: String?
        var counts: [String: Int] = [:]
        var fromGitHub = false
    }

    func refresh() async {
        // The scan keeps running after the popup closes; don't start a second one on reopen.
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let snapshot = await Task.detached { Self.load() }.value
        account = snapshot.account
        counts = snapshot.counts
        fromGitHub = snapshot.fromGitHub
        hasLoaded = true
    }

    private nonisolated static func load() -> Snapshot {
        let today = Date()
        let days = weekCount * 7
        let repos = RepoScanner.findRepos(under: FileManager.default.homeDirectoryForCurrentUser)
        let firstDay = ContributionCalendar.weeks(endingAt: today, count: weekCount, calendar: .current)[0][0]
        if let github = try? GitHubCalendar.fetch(from: firstDay, to: today) {
            // Local commits may be authored with the git email even when the profile shows another one.
            let emails = Set([github.email, GitLog.globalEmail()].compactMap { $0 })
            let unpushed = ContributionCounter.dailyCounts(repos: repos, emails: emails, sinceDays: days,
                                                           onlyNotOnGitHub: true)
            return Snapshot(account: github.email ?? "@\(github.login)",
                            counts: github.counts.merging(unpushed, uniquingKeysWith: +), fromGitHub: true)
        }
        guard let email = GitLog.globalEmail() else { return Snapshot() }
        return Snapshot(account: email, counts: ContributionCounter.dailyCounts(repos: repos, emails: [email], sinceDays: days))
    }
}

/// MenuBarExtra's window grows with its content but never shrinks, leaving blank space after a taller tab.
/// Shrinks the window to `height` from the bottom, keeping its top edge under the menu bar.
// shortcut: resizes the window SwiftUI owns; recheck if macOS changes how MenuBarExtra sizes its window.
private struct ShrinkWindow: NSViewRepresentable {
    let height: CGFloat

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        // The window is attached after this view; wait for the next run loop turn.
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            let extra = window.contentLayoutRect.height - height
            guard extra > 0.5 else { return }
            var frame = window.frame
            frame.origin.y += extra
            frame.size.height -= extra
            window.setFrame(frame, display: true)
        }
    }
}
