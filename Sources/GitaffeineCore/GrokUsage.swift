import Foundation

/// SuperGrok account weekly limit and prepaid balance from `grok agent stdio`, through the undocumented ACP
/// extension `_x.ai/billing` (unofficial). The user's grok CLI makes the request with its own login;
/// this app never reads or stores the token.
public enum GrokUsage {
    public struct Usage: Equatable, Sendable {
        /// e.g. "SuperGrok".
        public let tier: String?
        /// The current credit period (a week): percent used and when it resets.
        public let window: UsageWindow
        /// `prepaidBalance.val` as sent; the unit is unconfirmed.
        public let prepaidBalance: Int?
        /// From `_x.ai/auth/check_subscription`; memory only, shown in the title, never stored or logged.
        public let email: String?
    }

    /// ACP extension methods go on the wire with a leading "_"; "x.ai/billing" is "Method not found".
    static let requests = Data("""
    {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientCapabilities":{}}}
    {"jsonrpc":"2.0","id":2,"method":"_x.ai/billing","params":{}}
    {"jsonrpc":"2.0","id":3,"method":"_x.ai/auth/check_subscription","params":{}}

    """.utf8)

    /// Throws when grok is missing, not logged in, the request fails, or the reply takes longer than 30 seconds.
    public static func fetch() throws -> Usage {
        guard let grok = grokPath() else { throw CocoaError(.fileNoSuchFile) }
        // --no-leader: without it grok may start a shared leader process that keeps running after we quit.
        return try parse(CodexUsage.run(grok, ["agent", "--no-leader", "stdio"], requests: requests,
                                        untilReplies: [2, 3], required: [2], timeout: 30))
    }

    /// Where the grok installer and Homebrew put it; apps started from Finder don't get the shell's PATH.
    static func grokPath() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.local/bin/grok", "/opt/homebrew/bin/grok", "/usr/local/bin/grok"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    static func parse(_ output: Data) throws -> Usage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            // A time on a whole second may come without the fraction.
            guard let date = formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: text))
            }
            return date
        }
        let lines = output.split(separator: UInt8(ascii: "\n"))
        // Only meta.email is decoded; a failed subscription reply just leaves the email out.
        let email = lines.lazy.compactMap { try? decoder.decode(SubscriptionReply.self, from: $0) }
            .first { $0.id == 3 && $0.method == nil }?.result?.meta.email.flatMap { $0.isEmpty ? nil : $0 }
        for line in lines {
            guard let reply = try? decoder.decode(Reply.self, from: line), reply.id == 2, reply.method == nil else { continue }
            if let error = reply.error { throw CodexUsage.ReplyError(message: error.message) }
            guard let billing = reply.result else { break }
            let config = billing.config, period = config.currentPeriod
            return Usage(tier: billing.subscription_tier,
                         window: UsageWindow(usedPercent: Int((config.creditUsagePercent ?? 0).rounded()),
                                             minutes: Int(period.end.timeIntervalSince(period.start) / 60),
                                             resetsAt: period.end),
                         prepaidBalance: config.prepaidBalance.map { $0.val ?? 0 }, email: email)
        }
        throw CodexUsage.ReplyError(message: "no billing reply")
    }

    private struct Reply: Decodable {
        let id: Int?
        let method: String?
        let error: ErrorBody?
        let result: Billing?
        struct ErrorBody: Decodable { let message: String }
    }

    private struct SubscriptionReply: Decodable {
        let id: Int?
        let method: String?
        let result: Result?
        struct Result: Decodable { let meta: Meta }
        struct Meta: Decodable { let email: String? }
    }

    /// Protobuf JSON leaves out zero values, so the numbers are optional.
    private struct Billing: Decodable {
        let config: Config
        let subscription_tier: String?

        struct Config: Decodable {
            let creditUsagePercent: Double?
            let currentPeriod: Period
            let prepaidBalance: Balance?
        }
        struct Period: Decodable {
            let start: Date
            let end: Date
        }
        struct Balance: Decodable { let val: Int? }
    }
}
