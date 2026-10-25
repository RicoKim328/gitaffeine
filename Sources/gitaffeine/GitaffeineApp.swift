import GitaffeineCore
import SwiftUI

@main
struct GitaffeineApp: App {
    @State private var contributions = ContributionStore()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                Text("gitaffeine").font(.headline)
                if let message = contributions.message {
                    Text(message).foregroundStyle(.secondary)
                } else {
                    ContributionGrid(counts: contributions.counts)
                }
                Divider()
                Button("Quit gitaffeine") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding()
            .frame(width: 280, alignment: .leading)
            .task { await contributions.refresh() }
        } label: {
            Image(nsImage: PillIcon.image)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Commit counts for the grid, recounted each time the popup opens.
@MainActor @Observable
final class ContributionStore {
    private(set) var counts: [String: Int] = [:]
    private(set) var message: String? = "Scanning…"
    private var isRefreshing = false

    func refresh() async {
        // The scan keeps running after the popup closes; don't start a second one on reopen.
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let result = await Task.detached { () -> [String: Int]? in
            guard let email = GitLog.globalEmail() else { return nil }
            let repos = RepoScanner.findRepos(under: FileManager.default.homeDirectoryForCurrentUser)
            return ContributionCounter.dailyCounts(repos: repos, emails: [email], sinceDays: 63) // covers the 9-week grid
        }.value
        if let result {
            counts = result
            message = nil
        } else {
            message = "git user.email이 설정되지 않음"
        }
    }
}
