import Foundation

public enum ContributionCounter {
    /// Commits per day ("yyyy-MM-dd" → count) whose author email is in `emails` (case-insensitive).
    /// Each hash counts once, so worktrees and extra clones of the same repo don't inflate the total.
    public static func dailyCounts(_ commits: [Commit], emails: Set<String>) -> [String: Int] {
        let wanted = Set(emails.map { $0.lowercased() })
        var seen: Set<String> = []
        var counts: [String: Int] = [:]
        for commit in commits where wanted.contains(commit.email.lowercased()) && seen.insert(commit.hash).inserted {
            counts[commit.day, default: 0] += 1
        }
        return counts
    }

    /// Daily counts summed over `repos`. A repo git can't read (broken, permission) is skipped.
    public static func dailyCounts(repos: [URL], emails: Set<String>, sinceDays: Int) -> [String: Int] {
        let commits = repos.flatMap { (try? GitLog.commits(in: $0, sinceDays: sinceDays)) ?? [] }
        return dailyCounts(commits, emails: emails)
    }
}
