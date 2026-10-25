import Foundation

/// One commit reduced to what the grid needs: hash, author email and local calendar day ("yyyy-MM-dd").
public struct Commit: Equatable, Sendable {
    public let hash: String
    public let email: String
    public let day: String
}

public enum GitLog {
    public struct Failure: Error {
        public let status: Int32
    }

    /// Commits on all refs of `repo` from the last `sinceDays` days.
    /// `%aE` applies .mailmap; `format-local` puts the author date in this Mac's time zone.
    /// shortcut: `--since` stops at the first older commit, so a commit made with a wrong clock can hide newer ones.
    /// `--since-as-filter` fixes that but walks the whole history, which never finished on an iCloud-offloaded repo.
    public static func commits(in repo: URL, sinceDays: Int) throws -> [Commit] {
        let output = try run(["-C", repo.path, "log", "--all", "--since=\(sinceDays).days",
                              "--format=%H%x09%aE%x09%ad", "--date=format-local:%Y-%m-%d"])
        return parse(output)
    }

    /// `git config --global user.email`, or nil when it isn't set.
    public static func globalEmail() -> String? {
        let email = (try? run(["config", "--global", "user.email"]))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return email?.isEmpty == false ? email : nil
    }

    static func parse(_ output: String) -> [Commit] {
        output.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t")
            guard fields.count == 3 else { return nil }
            return Commit(hash: String(fields[0]), email: String(fields[1]), day: String(fields[2]))
        }
    }

    private static func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile() // read before waiting so a full pipe can't block git
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Failure(status: process.terminationStatus) }
        return String(decoding: data, as: UTF8.self)
    }
}
