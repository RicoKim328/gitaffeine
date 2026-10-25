import Foundation
import Testing
@testable import GitaffeineCore

@Test func parsesHashEmailAndDayLines() {
    let output = "a1\tme@example.com\t2026-10-01\n\nb2\tMe@Example.com\t2026-10-02\nnot a commit line\n"
    #expect(GitLog.parse(output) == [
        Commit(hash: "a1", email: "me@example.com", day: "2026-10-01"),
        Commit(hash: "b2", email: "Me@Example.com", day: "2026-10-02"),
    ])
}

@Test func countsOnlyMatchingEmailsIgnoringCaseAndDuplicates() {
    let commits = [
        Commit(hash: "a1", email: "ME@example.com", day: "2026-10-01"),
        Commit(hash: "b2", email: "me@example.com", day: "2026-10-01"),
        Commit(hash: "b2", email: "me@example.com", day: "2026-10-01"), // same commit seen in another clone
        Commit(hash: "c3", email: "me@example.com", day: "2026-10-03"),
        Commit(hash: "d4", email: "other@example.com", day: "2026-10-01"),
    ]
    #expect(ContributionCounter.dailyCounts(commits, emails: ["me@example.com"]) == [
        "2026-10-01": 2,
        "2026-10-03": 1,
    ])
}

@Test func linkedWorktreeDoesNotDoubleCount() throws {
    let root = try TempDir()
    let main = root.url.appending(path: "main")
    try FileManager.default.createDirectory(at: main, withIntermediateDirectories: true)
    let git = TestGit(main)
    try git("init", "-q", "-b", "main")
    let yesterday = Date().addingTimeInterval(-86_400)
    try git.commit(email: "me@example.com", date: yesterday)
    try git("worktree", "add", "-q", "-b", "wt", root.url.appending(path: "wt").path)

    let repos = RepoScanner.findRepos(under: root.url)
    let counts = ContributionCounter.dailyCounts(repos: repos, emails: ["me@example.com"], sinceDays: 60)

    #expect(repos.count == 2)
    #expect(counts == [dayKey(yesterday): 1])
}

@Test func countsCommitsOnAllBranchesOfRealRepo() throws {
    let repo = try TempDir()
    let git = TestGit(repo.url)
    try git("init", "-q", "-b", "main")
    let oneDayAgo = Date().addingTimeInterval(-86_400)
    let threeDaysAgo = Date().addingTimeInterval(-3 * 86_400)
    try git.commit(email: "me@example.com", date: oneDayAgo)
    try git.commit(email: "other@example.com", date: oneDayAgo)
    try git("switch", "-q", "-c", "feature")
    try git.commit(email: "ME@example.com", date: threeDaysAgo)
    try git("switch", "-q", "main")

    let counts = ContributionCounter.dailyCounts(repos: [repo.url], emails: ["me@example.com"], sinceDays: 60)

    #expect(counts == [dayKey(oneDayAgo): 1, dayKey(threeDaysAgo): 1])
}

@Test func emptyRepoHasNoCommits() throws {
    let repo = try TempDir()
    try TestGit(repo.url)("init", "-q")
    #expect(try GitLog.commits(in: repo.url, sinceDays: 60).isEmpty)
}

private func dayKey(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}
