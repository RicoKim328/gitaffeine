import Foundation

/// Claude Code usage from local files only (experimental: the log format is not documented):
/// daily tokens from ~/.claude/projects/**/*.jsonl, kept in a cache so days survive Claude Code deleting old logs,
/// rate limits from the status line input the user's wrapper saves, and the email from ~/.claude.json.
/// Never reads the login token.
public enum ClaudeUsage {
    public struct Tokens: Codable, Equatable, Sendable {
        public var input = 0, output = 0, cacheWrite5m = 0, cacheWrite1h = 0, cacheRead = 0

        public var total: Int { input + output + cacheWrite5m + cacheWrite1h + cacheRead }

        static func + (a: Tokens, b: Tokens) -> Tokens {
            Tokens(input: a.input + b.input, output: a.output + b.output, cacheWrite5m: a.cacheWrite5m + b.cacheWrite5m,
                   cacheWrite1h: a.cacheWrite1h + b.cacheWrite1h, cacheRead: a.cacheRead + b.cacheRead)
        }
    }

    /// Tokens per day ("yyyy-MM-dd") per model.
    public typealias Daily = [String: [String: Tokens]]

    public struct Usage: Sendable {
        public let email: String?
        /// From the status line wrapper; empty when it isn't installed or the windows have reset since.
        public let windows: [UsageWindow]
        public let daily: Daily

        public var dailyTokens: [String: Int] { daily.mapValues { $0.values.reduce(0) { $0 + $1.total } } }

        /// Estimated $ per day at API list prices, leaving out models without a known price.
        public var dailyCost: [String: Double] {
            daily.mapValues { $0.reduce(0) { $0 + (cost(model: $1.key, tokens: $1.value) ?? 0) } }
        }

        /// Models that have tokens but no list price, so `dailyCost` leaves them out.
        public var unpricedModels: Set<String> {
            Set(daily.values.flatMap(\.keys).filter { price(for: $0) == nil })
        }
    }

    public static func load() throws -> Usage {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let support = URL.applicationSupportDirectory.appending(path: "gitaffeine")
        let statusLine = try? Data(contentsOf: support.appending(path: "claude-status.json"))
        return Usage(email: (try? Data(contentsOf: home.appending(path: ".claude.json"))).flatMap(email(claudeJSON:)),
                     windows: statusLine.map { windows(statusLine: $0, now: Date()) } ?? [],
                     daily: try loadDaily(projects: home.appending(path: ".claude/projects"),
                                          cache: support.appending(path: "claude-daily.json"), calendar: .current))
    }

    /// Parses every log under `projects`, merges it into the cache file and saves the result.
    // shortcut: rereads every log each time (9.4MB parsed in 0.07s in a Python check); track file offsets if the popup gets slow.
    static func loadDaily(projects: URL, cache: URL, calendar: Calendar) throws -> Daily {
        let files = FileManager.default.enumerator(at: projects, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "jsonl" }
            .compactMap { try? Data(contentsOf: $0) } ?? []
        let cached = (try? Data(contentsOf: cache)).flatMap { try? JSONDecoder().decode(Daily.self, from: $0) } ?? [:]
        let merged = merge(cached: cached, parsed: daily(files: files, calendar: calendar))
        try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(merged).write(to: cache, options: .atomic)
        return merged
    }

    /// Sums assistant responses per day and model. A response is written once per content block with the same
    /// message id and request id, possibly in more than one file; the line with the largest total is the final one.
    static func daily(files: [Data], calendar: Calendar) -> Daily {
        var responses: [String: (day: String, model: String, tokens: Tokens)] = [:]
        let timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for file in files {
            for line in file.split(separator: UInt8(ascii: "\n")) {
                guard let entry = try? JSONDecoder().decode(Entry.self, from: line), entry.type == "assistant",
                      let message = entry.message, let usage = message.usage, let model = message.model,
                      model != "<synthetic>", let id = message.id, let date = timestamp.date(from: entry.timestamp ?? "")
                else { continue }
                let key = "\(id) \(entry.requestId ?? "")"
                let tokens = usage.tokens
                if let seen = responses[key], seen.tokens.total >= tokens.total { continue }
                responses[key] = (ContributionCalendar.dayKey(date, calendar: calendar), model, tokens)
            }
        }
        var daily: Daily = [:]
        for response in responses.values {
            let sum = daily[response.day]?[response.model] ?? Tokens()
            daily[response.day, default: [:]][response.model] = sum + response.tokens
        }
        return daily
    }

    /// Per day, the side with the larger total wins, so days whose logs were deleted keep their cached value.
    // shortcut: if some of a day's logs are deleted and that day gets new use, the day can be undercounted.
    static func merge(cached: Daily, parsed: Daily) -> Daily {
        func total(_ day: [String: Tokens]) -> Int { day.values.reduce(0) { $0 + $1.total } }
        return cached.merging(parsed) { total($1) >= total($0) ? $1 : $0 }
    }

    struct Price {
        let input: Double, output: Double, cacheRead: Double
    }

    /// API list prices per million tokens (claude-api skill table, cached 2026-10-06).
    /// Cache writes are 1.25x (5 minutes) and 2x (1 hour) the input price.
    // shortcut: fast mode (2x) is priced as standard; no fast records in the logs yet (2026-10-25).
    static let prices: [String: Price] = [
        "claude-fable-5-1": Price(input: 10, output: 50, cacheRead: 0.25),
        "claude-opus-5-5": Price(input: 4, output: 20, cacheRead: 0.20),
        "claude-sonnet-5-5": Price(input: 2, output: 10, cacheRead: 0.20),
        "claude-sonnet-4-6": Price(input: 3, output: 15, cacheRead: 0.30),
        "claude-haiku-4-5": Price(input: 1, output: 5, cacheRead: 0.10),
    ]

    /// Log model ids may carry a date suffix, e.g. "claude-haiku-4-5-20251001".
    static func price(for model: String) -> Price? {
        prices.first { model == $0.key || model.hasPrefix($0.key + "-") }?.value
    }

    /// Estimated $ at API list prices; nil for a model without a known price.
    static func cost(model: String, tokens: Tokens) -> Double? {
        guard let price = price(for: model) else { return nil }
        let millions = Double(tokens.input) * price.input + Double(tokens.output) * price.output
            + Double(tokens.cacheWrite5m) * price.input * 1.25 + Double(tokens.cacheWrite1h) * price.input * 2
            + Double(tokens.cacheRead) * price.cacheRead
        return millions / 1_000_000
    }

    /// The 5-hour and 7-day windows from Claude Code's status line input, shortest first, without passed ones.
    static func windows(statusLine: Data, now: Date) -> [UsageWindow] {
        guard let limits = (try? JSONDecoder().decode(StatusLine.self, from: statusLine))?.rateLimits else { return [] }
        return [(limits.fiveHour, 5 * 60), (limits.sevenDay, 7 * 24 * 60)].compactMap { limit, minutes in
            guard let limit, limit.resetsAt > now.timeIntervalSince1970 else { return nil }
            return UsageWindow(usedPercent: Int(limit.usedPercentage.rounded()), minutes: minutes,
                               resetsAt: Date(timeIntervalSince1970: limit.resetsAt))
        }
    }

    /// Only the account email; the rest of ~/.claude.json is not read.
    static func email(claudeJSON: Data) -> String? {
        (try? JSONDecoder().decode(ClaudeJSON.self, from: claudeJSON))?.oauthAccount?.emailAddress
    }

    private struct Entry: Decodable {
        let type: String?
        let timestamp: String?
        let requestId: String?
        let message: Message?

        struct Message: Decodable {
            let id: String?
            let model: String?
            let usage: Usage?
        }

        struct Usage: Decodable {
            let input_tokens: Int?
            let output_tokens: Int?
            let cache_creation_input_tokens: Int?
            let cache_read_input_tokens: Int?
            let cache_creation: CacheCreation?

            struct CacheCreation: Decodable {
                let ephemeral_5m_input_tokens: Int?
                let ephemeral_1h_input_tokens: Int?
            }

            /// Older lines have no 5m/1h split; their cache writes count as 5-minute writes.
            var tokens: Tokens {
                let write1h = cache_creation?.ephemeral_1h_input_tokens ?? 0
                return Tokens(input: input_tokens ?? 0, output: output_tokens ?? 0,
                              cacheWrite5m: cache_creation?.ephemeral_5m_input_tokens
                                  ?? (cache_creation_input_tokens ?? 0) - write1h,
                              cacheWrite1h: write1h, cacheRead: cache_read_input_tokens ?? 0)
            }
        }
    }

    private struct StatusLine: Decodable {
        let rateLimits: Limits?
        enum CodingKeys: String, CodingKey { case rateLimits = "rate_limits" }

        struct Limits: Decodable {
            let fiveHour: Limit?
            let sevenDay: Limit?
            enum CodingKeys: String, CodingKey { case fiveHour = "five_hour", sevenDay = "seven_day" }
        }

        struct Limit: Decodable {
            let usedPercentage: Double
            let resetsAt: TimeInterval
            enum CodingKeys: String, CodingKey { case usedPercentage = "used_percentage", resetsAt = "resets_at" }
        }
    }

    private struct ClaudeJSON: Decodable {
        let oauthAccount: Account?
        struct Account: Decodable { let emailAddress: String? }
    }
}
