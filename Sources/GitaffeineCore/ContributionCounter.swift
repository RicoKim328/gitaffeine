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
    /// With `onlyNotOnGitHub`, commits GitHub already counts (on a GitHub remote's default branch or gh-pages)
    /// are left out, so the result can be added to the GitHub calendar without counting them twice.
    /// They are left out of every repo, including other clones whose remote isn't GitHub.
    public static func dailyCounts(repos: [URL], emails: Set<String>, sinceDays: Int,
                                   onlyNotOnGitHub: Bool = false) -> [String: Int] {
        var commits: [Commit] = []
        var onGitHub: Set<String> = []
        for repo in repos {
            commits += (try? GitLog.commits(in: repo, sinceDays: sinceDays)) ?? []
            if onlyNotOnGitHub, let refs = try? GitLog.githubCountedRefs(in: repo), !refs.isEmpty {
                let counted = (try? GitLog.commits(in: repo, sinceDays: sinceDays, reachableFrom: refs)) ?? []
                onGitHub.formUnion(counted.map(\.hash))
            }
        }
        return dailyCounts(commits.filter { !onGitHub.contains($0.hash) }, emails: emails)
    }
}
