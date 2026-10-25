import Foundation

/// One commit reduced to what the grid needs: hash, author email and local calendar day ("yyyy-MM-dd").
public struct Commit: Equatable, Sendable {
    public let hash: String
    public let email: String
    public let day: String
}

public enum GitLog {
    /// Commits from the last `sinceDays` days reachable from `refs`, or from all refs of `repo` when nil.
    /// `%aE` applies .mailmap; `format-local` puts the author date in this Mac's time zone.
    /// shortcut: `--since` stops at the first older commit, so a commit made with a wrong clock can hide newer ones.
    /// `--since-as-filter` fixes that but walks the whole history, which never finished on an iCloud-offloaded repo.
    public static func commits(in repo: URL, sinceDays: Int, reachableFrom refs: [String]? = nil) throws -> [Commit] {
        parse(try git(["-C", repo.path, "log"] + (refs ?? ["--all"]) + ["--since=\(sinceDays).days",
                       "--format=%H%x09%aE%x09%ad", "--date=format-local:%Y-%m-%d", "--"]))
    }

    static func parse(_ output: String) -> [Commit] {
        output.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t")
            guard fields.count == 3 else { return nil }
            return Commit(hash: String(fields[0]), email: String(fields[1]), day: String(fields[2]))
        }
    }

    /// `git config --global user.email`, or nil when it isn't set.
    public static func globalEmail() -> String? {
        let email = (try? git(["config", "--global", "user.email"]))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return email?.isEmpty == false ? email : nil
    }

    /// Remote-tracking refs whose commits GitHub already counts as contributions:
    /// each GitHub remote's default branch and gh-pages. Empty when the repo has no GitHub remote.
    /// Uses only refs already fetched (no network), so a repo that wasn't fetched recently can count pushed commits twice.
    public static func githubCountedRefs(in repo: URL) throws -> [String] {
        try githubRemotes(fromRemoteList: git(["-C", repo.path, "remote", "-v"])).flatMap { remote in
            countedRefs(remote: remote, refList: try git(["-C", repo.path, "for-each-ref",
                                                          "--format=%(refname)%09%(symref)", "refs/remotes/\(remote)/"]))
        }
    }

    /// Remote names from `git remote -v` whose fetch URL's host is github.com.
    static func githubRemotes(fromRemoteList output: String) -> [String] {
        output.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t")
            guard fields.count == 2, fields[1].hasSuffix(" (fetch)") else { return nil }
            let url = String(fields[1].dropLast(" (fetch)".count))
            return host(ofRemoteURL: url) == "github.com" ? String(fields[0]) : nil
        }
    }

    /// Host of `https://host/…`, `ssh://user@host/…` or scp-style `user@host:path`; nil for local paths.
    static func host(ofRemoteURL url: String) -> String? {
        if url.contains("://") { return URL(string: url)?.host?.lowercased() }
        guard let colon = url.firstIndex(of: ":"), !url[..<colon].contains("/") else { return nil }
        return url[..<colon].split(separator: "@").last.map { $0.lowercased() }
    }

    /// From `for-each-ref` lines ("refname<TAB>symref"): the default branch (what `<remote>/HEAD` points to,
    /// else `main`, else `master`) plus `gh-pages` when present.
    static func countedRefs(remote: String, refList: String) -> [String] {
        let prefix = "refs/remotes/\(remote)/"
        var refs: Set<String> = []
        var head: String?
        for line in refList.split(separator: "\n") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            if fields[0] == prefix + "HEAD" { head = fields.count > 1 && !fields[1].isEmpty ? fields[1] : nil }
            else { refs.insert(fields[0]) }
        }
        let defaultBranch = head ?? [prefix + "main", prefix + "master"].first(where: refs.contains)
        return [defaultBranch, refs.contains(prefix + "gh-pages") ? prefix + "gh-pages" : nil].compactMap { $0 }
    }

    private static func git(_ arguments: [String]) throws -> String {
        String(decoding: try Command.run(URL(fileURLWithPath: "/usr/bin/git"), arguments), as: UTF8.self)
    }
}
