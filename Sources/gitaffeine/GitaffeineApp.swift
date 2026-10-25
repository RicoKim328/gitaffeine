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
            SettingsView(email: contributions.email)
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
            Text("github \(store.email ?? (store.hasLoaded ? "이메일 미설정" : "…"))").font(.headline)
            Text("Local 프로젝트").font(.caption).foregroundStyle(.secondary)
            ContributionGrid(weeks: weeks, counts: store.counts, today: today, calendar: calendar)
            Text("\(today.formatted(date: .long, time: .omitted)) · 기여한 날 \(share.percent)% (\(share.activeDays)/\(share.shownDays)일)")
                .font(.caption)
                .foregroundStyle(.secondary)
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
    private(set) var email: String?
    private(set) var isRefreshing = false
    private(set) var hasLoaded = false

    func refresh() async {
        // The scan keeps running after the popup closes; don't start a second one on reopen.
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let (email, counts) = await Task.detached { () -> (String?, [String: Int]) in
            let email = GitLog.globalEmail() // temporary source until M3 switches to the gh account
            guard let email else { return (nil, [:]) }
            let repos = RepoScanner.findRepos(under: FileManager.default.homeDirectoryForCurrentUser)
            return (email, ContributionCounter.dailyCounts(repos: repos, emails: [email], sinceDays: Self.weekCount * 7))
        }.value
        self.email = email
        self.counts = counts
        hasLoaded = true
    }
}
