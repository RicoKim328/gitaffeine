import GitaffeineCore
import SwiftUI

@main
struct GitaffeineApp: App {
    @State private var contributions = ContributionStore()

    var body: some Scene {
        MenuBarExtra {
            PopupView(store: contributions)
                .task { await contributions.refresh() }
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
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let today = Date()
        let calendar = Calendar.current
        let weeks = ContributionCalendar.weeks(endingAt: today, count: ContributionStore.weekCount, calendar: calendar)
        let share = ContributionCalendar.activeShare(of: weeks, counts: store.counts, today: today, calendar: calendar)

        VStack(alignment: .leading, spacing: 8) {
            Text("github \(store.account ?? (store.hasLoaded ? "이메일 미설정" : "…"))").font(.headline)
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
            Rectangle().fill(Color.primary).frame(height: 1)
            HStack {
                Button("설정") {
                    NSApp.activate() // menu bar apps have no Dock icon; bring the settings window to the front
                    openSettings()
                }
                Button("새로고침") { Task { await store.refresh() } }
                    .disabled(store.isRefreshing)
                Spacer()
                Button("종료") { NSApplication.shared.terminate(nil) }
                    .font(.caption)
                    .keyboardShortcut("q")
            }
        }
        .padding()
        .frame(width: 280, alignment: .leading)
    }
}

/// Commit counts for the grid, recounted each time the popup opens or on 새로고침.
@MainActor @Observable
final class ContributionStore {
    /// 16 weeks (112 days) fill the 280pt popup.
    nonisolated static let weekCount = 16

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
