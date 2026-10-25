import Foundation

/// Codex account, rate limits and daily token totals from `codex app-server` (experimental).
/// The user's codex CLI makes the requests with its own login; this app never reads or stores the token.
public enum CodexUsage {
    public struct Usage: Equatable, Sendable {
        /// The ChatGPT account email; nil for an API key account.
        public let email: String?
        /// Rate limit windows (e.g. 5 hours, a week), shortest first. An account may have only one.
        public let windows: [UsageWindow]
        /// Tokens per day ("yyyy-MM-dd"), only days with usage.
        public let dailyTokens: [String: Int]

        /// Estimated $ per day at the blended list price below.
        public var dailyCost: [String: Double] { dailyTokens.mapValues { Double($0) * blendedPrice / 1_000_000 } }
    }

    /// $ per million tokens. The account only gives daily totals, so one price blends gpt-6-sol's list prices
    /// ($0.20 cached input, $2 input, $10 output, short context; developers.openai.com 2026-10-25) by this Mac's
    /// share of each in ~/.codex/sessions on 2026-10-25: 91.6% cached input, 8.0% input, 0.4% output.
    // shortcut: fixed share and one model; wrong for other use patterns or models, re-measure if estimates look off.
    static let blendedPrice = 0.916 * 0.20 + 0.080 * 2.00 + 0.004 * 10.00

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
                         .map { UsageWindow(usedPercent: $0.usedPercent, minutes: $0.windowDurationMins,
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
