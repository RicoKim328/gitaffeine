import Foundation

/// Codex account, rate limits and daily token totals from `codex app-server` (experimental).
/// The user's codex CLI makes the requests with its own login; this app never reads or stores the token.
public enum CodexUsage {
    public struct Usage: Equatable, Sendable {
        /// The ChatGPT account email; nil for an API key account.
        public let email: String?
        /// Rate limit windows (e.g. 5 hours, a week), shortest first. An account may have only one.
        public let windows: [Window]
        /// Tokens per day ("yyyy-MM-dd"), only days with usage.
        public let dailyTokens: [String: Int]
    }

    public struct Window: Equatable, Sendable {
        public let usedPercent: Int
        public let minutes: Int
        public let resetsAt: Date

        /// Percent left in the window, 0...100.
        public var remainingPercent: Int { min(max(100 - usedPercent, 0), 100) }

        /// How full each of `count` cells is (0...1) for the percent left, filled from the left;
        /// the last one may be partly filled.
        public func cellFills(count: Int) -> [Double] {
            let filled = Double(remainingPercent) * Double(count) / 100
            return (0..<count).map { min(max(filled - Double($0), 0), 1) }
        }

        public var start: Date { resetsAt.addingTimeInterval(-Double(minutes) * 60) }

        /// Share of the window that has passed at `now`, 0...1.
        public func elapsedFraction(at now: Date) -> Double {
            min(max(now.timeIntervalSince(start) / (Double(minutes) * 60), 0), 1)
        }

        /// One cell per 24 hours from the window's start: passed ones full, the current one partly filled.
        public func dayFills(at now: Date) -> [Double] {
            let elapsedDays = elapsedFraction(at: now) * Double(minutes) / (24 * 60)
            return (0..<minutes / (24 * 60)).map { min(max(elapsedDays - Double($0), 0), 1) }
        }

        /// Percent left at the reset if use keeps its average pace so far; nil before any time has passed.
        public func projectedRemainingPercent(at now: Date) -> Int? {
            let elapsed = elapsedFraction(at: now)
            guard elapsed > 0 else { return nil }
            return min(max(100 - Int((Double(usedPercent) / elapsed).rounded()), 0), 100)
        }

        /// Tokens from the window's first day through `today`. Daily totals only, so the first day counts in full.
        public func tokens(in daily: [String: Int], today: Date, calendar: Calendar) -> Int {
            let first = ContributionCalendar.dayKey(start, calendar: calendar)
            let last = ContributionCalendar.dayKey(today, calendar: calendar)
            return daily.filter { $0.key >= first && $0.key <= last }.values.reduce(0, +)
        }
    }

    struct ReplyError: Error {
        let message: String
    }

    /// One JSON message per line: the initialize handshake, then account (id 2), rate limits (3) and usage (4).
    /// The usage methods are experimental, so initialize must opt in with `experimentalApi`.
    static let requests = Data("""
    {"id":1,"method":"initialize","params":{"clientInfo":{"name":"gitaffeine","version":"0"},\
    "capabilities":{"experimentalApi":true}}}
    {"method":"initialized"}
    {"id":2,"method":"account/read","params":{}}
    {"id":3,"method":"account/rateLimits/read","params":null}
    {"id":4,"method":"account/usage/read","params":null}

    """.utf8)

    /// Throws when codex is missing, not logged in, a request fails, or the replies take longer than 60 seconds
    /// (e.g. offline).
    public static func fetch() throws -> Usage {
        guard let codex = codexPath() else { throw CocoaError(.fileNoSuchFile) }
        return try parse(run(codex, ["app-server"], untilReplies: [2, 3, 4], timeout: 60))
    }

    /// Apps started from Finder don't get the shell's PATH, so look where the installers put codex.
    // shortcut: misses codex installed via nvm, fnm or a custom npm prefix; resolve those before distribution (M6).
    static func codexPath() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    /// `environment` with codex's folder and the Homebrew folders put in front of PATH,
    /// so an npm-installed codex (a `#!/usr/bin/env node` script) finds node when the app is opened from Finder.
    static func environment(for executable: URL, inheriting environment: [String: String]) -> [String: String] {
        var environment = environment
        let folders = [executable.deletingLastPathComponent().path, "/opt/homebrew/bin", "/usr/local/bin",
                       environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"]
        environment["PATH"] = folders.joined(separator: ":")
        return environment
    }

    /// Writes `requests` and returns stdout once replies with all `ids` have arrived.
    /// app-server quits without answering when stdin closes, so stdin stays open until then.
    static func run(_ executable: URL, _ arguments: [String], untilReplies ids: Set<Int>,
                    timeout: TimeInterval) throws -> Data {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment(for: executable, inheriting: ProcessInfo.processInfo.environment)
        let stdin = Pipe(), stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        try process.run()
        defer {
            try? stdin.fileHandleForWriting.close()
            process.terminate()
            process.waitUntilExit()
        }
        try stdin.fileHandleForWriting.write(contentsOf: requests)

        let output = Output()
        let done = DispatchSemaphore(value: 0)
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty || output.append(chunk, hasReplies: ids) {
                handle.readabilityHandler = nil
                done.signal()
            }
        }
        guard done.wait(timeout: .now() + timeout) == .success else {
            stdout.fileHandleForReading.readabilityHandler = nil
            throw Command.TimedOut()
        }
        return output.data
    }

    /// Output collected on the pipe's queue and read after the semaphore signals.
    private final class Output: @unchecked Sendable {
        private let lock = NSLock()
        private var buffer = Data()

        var data: Data { lock.withLock { buffer } }

        /// True once every id in `ids` has a reply line.
        func append(_ chunk: Data, hasReplies ids: Set<Int>) -> Bool {
            lock.withLock {
                buffer.append(chunk)
                let seen = buffer.split(separator: UInt8(ascii: "\n"))
                    .compactMap { try? JSONDecoder().decode(Reply.self, from: $0).replyID }
                return ids.isSubset(of: seen)
            }
        }
    }

    static func parse(_ output: Data) throws -> Usage {
        var replies: [Int: Data] = [:]
        for line in output.split(separator: UInt8(ascii: "\n")) {
            guard let reply = try? JSONDecoder().decode(Reply.self, from: line), let id = reply.replyID else { continue }
            if let error = reply.error { throw ReplyError(message: error.message) }
            replies[id] = Data(line)
        }
        func result<T: Decodable>(_ id: Int, as: T.Type) throws -> T {
            guard let line = replies[id] else { throw ReplyError(message: "no reply \(id)") }
            return try JSONDecoder().decode(Result<T>.self, from: line).result
        }

        let limits = try result(3, as: RateLimitsResult.self).rateLimits
        var dailyTokens: [String: Int] = [:]
        // shortcut: assumes startDate is a local "yyyy-MM-dd"; unverified (could be UTC), check against a late-night session.
        for bucket in try result(4, as: UsageResult.self).dailyUsageBuckets ?? [] where bucket.tokens > 0 {
            dailyTokens[bucket.startDate, default: 0] += bucket.tokens
        }
        return Usage(email: try result(2, as: AccountResult.self).account?.email,
                     windows: [limits.primary, limits.secondary].compactMap { $0 }
                         .map { Window(usedPercent: $0.usedPercent, minutes: $0.windowDurationMins,
                                       resetsAt: Date(timeIntervalSince1970: $0.resetsAt)) }
                         .sorted { $0.minutes < $1.minutes },
                     dailyTokens: dailyTokens)
    }

    private struct Reply: Decodable {
        let id: Int?
        let method: String?
        let error: ErrorBody?

        /// Requests from app-server also carry an id, but they have a method.
        var replyID: Int? { method == nil ? id : nil }
        struct ErrorBody: Decodable { let message: String }
    }

    private struct Result<T: Decodable>: Decodable { let result: T }

    private struct AccountResult: Decodable {
        let account: Account?
        struct Account: Decodable { let email: String? }
    }

    private struct RateLimitsResult: Decodable {
        let rateLimits: Limits
        struct Limits: Decodable {
            let primary: Limit?
            let secondary: Limit?
        }
        struct Limit: Decodable {
            let usedPercent: Int
            let windowDurationMins: Int
            let resetsAt: TimeInterval
        }
    }

    private struct UsageResult: Decodable {
        let dailyUsageBuckets: [Bucket]?
        struct Bucket: Decodable {
            let startDate: String
            let tokens: Int
        }
    }
}
