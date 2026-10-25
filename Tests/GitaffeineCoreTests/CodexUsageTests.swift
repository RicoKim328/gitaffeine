import Foundation
@testable import GitaffeineCore
import Testing

// Shapes from a real app-server reply (2026-10-25), trimmed. One JSON message per line, notifications in between.
private let fixture = """
{"id":1,"result":{"userAgent":"codex/0.164.0"}}
{"method":"remoteControl/status/changed","params":{}}
{"id":2,"result":{"account":{"type":"chatgpt","email":"rico@example.com","planType":"prolite"},"requiresOpenaiAuth":true}}
{"id":3,"result":{"ordinaryUsageAllowed":true,"rateLimits":{"limitId":"codex","primary":\
{"usedPercent":5,"windowDurationMins":10080,"resetsAt":1793406650},"secondary":null,"planType":"prolite"}}}
{"id":4,"result":{"summary":{"lifetimeTokens":1500},"dailyUsageBuckets":[\
{"startDate":"2026-10-19","tokens":1200},{"startDate":"2026-10-24","tokens":0},{"startDate":"2026-10-25","tokens":300}]}}

"""

@Test func parsesAccountLimitsAndDailyTokens() throws {
    let usage = try CodexUsage.parse(Data(fixture.utf8))
    #expect(usage.email == "rico@example.com")
    #expect(usage.windows == [UsageWindow(usedPercent: 5, minutes: 10080,
                                                resetsAt: Date(timeIntervalSince1970: 1793406650))])
    #expect(usage.dailyTokens == ["2026-10-19": 1200, "2026-10-25": 300])
}

@Test func bothWindowsAreKeptShortestFirst() throws {
    let json = fixture.replacingOccurrences(of: #""secondary":null"#, with:
        #""secondary":{"usedPercent":40,"windowDurationMins":300,"resetsAt":1793300000}"#)
    #expect(try CodexUsage.parse(Data(json.utf8)).windows.map(\.minutes) == [300, 10080])
}

@Test func missingBucketsMeanNoUsage() throws {
    let json = fixture.replacingOccurrences(of: #""dailyUsageBuckets":[{"startDate":"2026-10-19","tokens":1200},{"startDate":"2026-10-24","tokens":0},{"startDate":"2026-10-25","tokens":300}]"#,
                                            with: #""dailyUsageBuckets":null"#)
    #expect(try CodexUsage.parse(Data(json.utf8)).dailyTokens == [:])
}

@Test func apiKeyAccountHasNoEmail() throws {
    let json = fixture.replacingOccurrences(of: #"{"type":"chatgpt","email":"rico@example.com","planType":"prolite"}"#,
                                            with: #"{"type":"apiKey"}"#)
    #expect(try CodexUsage.parse(Data(json.utf8)).email == nil)
}

@Test func errorReplyThrows() {
    let json = fixture.replacingOccurrences(of: #"{"id":4,"result""#, with: #"{"id":4,"error":{"code":-32600,"message":"not logged in"},"x""#)
    #expect(throws: (any Error).self) { try CodexUsage.parse(Data(json.utf8)) }
}

@Test func missingReplyThrows() {
    let json = fixture.split(separator: "\n").filter { !$0.hasPrefix(#"{"id":4"#) }.joined(separator: "\n")
    #expect(throws: (any Error).self) { try CodexUsage.parse(Data(json.utf8)) }
}

@Test func requestsAreOneJSONMessagePerLine() throws {
    let lines = String(decoding: CodexUsage.requests, as: UTF8.self).split(separator: "\n")
    let messages = try lines.map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any] }
    #expect(messages.map { $0["method"] as! String }
        == ["initialize", "initialized", "account/read", "account/rateLimits/read", "account/usage/read"])
    let capabilities = (messages[0]["params"] as! [String: Any])["capabilities"] as! [String: Any]
    #expect(capabilities["experimentalApi"] as? Bool == true)
}

@Test func runKeepsInputOpenUntilEveryReplyArrives() throws {
    // Like app-server, this script replies a moment later and drops pending replies when stdin closes.
    let script = #"while read -r line; do case "$line" in *'"id":4'*) (sleep 0.3; echo '{"id":4,"result":{}}') & ;; esac; done; kill $! 2>/dev/null"#
    let output = try CodexUsage.run(URL(fileURLWithPath: "/bin/sh"), ["-c", script], untilReplies: [4], timeout: 5)
    #expect(String(decoding: output, as: UTF8.self) == "{\"id\":4,\"result\":{}}\n")
}

@Test func runStopsWhenNoReplyComes() {
    #expect(throws: (any Error).self) {
        try CodexUsage.run(URL(fileURLWithPath: "/bin/sleep"), ["10"], untilReplies: [4], timeout: 0.5)
    }
}

private let seoul: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar
}()

private func window(_ used: Int, minutes: Int = 300, resetsAt: Date = .now) -> UsageWindow {
    UsageWindow(usedPercent: used, minutes: minutes, resetsAt: resetsAt)
}

@Test func cellsShowTheRemainingPercentFiveEachWithAPartialLastCell() {
    let fills = window(63).cellFills(count: 20) // 37% left
    #expect(fills.count == 20)
    #expect(fills.prefix(7).allSatisfy { $0 == 1 })
    #expect(abs(fills[7] - 0.4) < 1e-9)
    #expect(fills.dropFirst(8).allSatisfy { $0 == 0 })
}

@Test func remainingPercentIsClamped() {
    #expect(window(63).remainingPercent == 37)
    #expect(window(130).remainingPercent == 0)
    #expect(window(-5).remainingPercent == 100)
}

@Test func cellFillsAreClampedToEmptyAndFull() {
    #expect(window(100).cellFills(count: 20).allSatisfy { $0 == 0 })
    #expect(window(130).cellFills(count: 20).allSatisfy { $0 == 0 })
    #expect(window(0).cellFills(count: 20).allSatisfy { $0 == 1 })
}

@Test func windowTokensAddTheDaysFromTheWindowStartToToday() {
    // A week ending 2026-10-30 09:00 KST started 2026-10-23 09:00, so 10-23 counts in full.
    let resets = seoul.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 9))!
    let today = seoul.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 15))!
    let daily = ["2026-10-22": 1000, "2026-10-23": 200, "2026-10-25": 30, "2026-10-26": 4]
    #expect(window(5, minutes: 10080, resetsAt: resets).total(in: daily, today: today, calendar: seoul) == 230)
}

@Test func weekCellsFillOnePerElapsedDayAndProjectTheRemainingPercent() {
    // 1 day 5 hours into a week, 5% used: 17% of the time gone.
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let week = window(5, minutes: 10080, resetsAt: now.addingTimeInterval((5 * 24 + 19) * 3600))
    #expect(Int((week.elapsedFraction(at: now) * 100).rounded()) == 17)
    let fills = week.dayFills(at: now)
    #expect(fills.count == 7)
    #expect(fills[0] == 1)
    #expect(abs(fills[1] - 5.0 / 24) < 1e-9)
    #expect(fills.dropFirst(2).allSatisfy { $0 == 0 })
    #expect(week.projectedRemainingPercent(at: now) == 71)
}

@Test func projectionNeedsElapsedTimeAndStaysInRange() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(window(5, minutes: 10080, resetsAt: now.addingTimeInterval(10080 * 60)).projectedRemainingPercent(at: now) == nil)
    // 50% used after one day of seven runs out well before the reset.
    #expect(window(50, minutes: 10080, resetsAt: now.addingTimeInterval(6 * 24 * 3600)).projectedRemainingPercent(at: now) == 0)
}

@Test func codexGetsAPathWithItsFolderAndHomebrewForNode() {
    // An npm-installed codex is a `#!/usr/bin/env node` script; apps opened from Finder get only /usr/bin:/bin.
    let environment = CodexUsage.environment(for: URL(fileURLWithPath: "/opt/tools/bin/codex"),
                                             inheriting: ["PATH": "/usr/bin:/bin", "HOME": "/Users/rico"])
    #expect(environment["PATH"] == "/opt/tools/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin")
    #expect(environment["HOME"] == "/Users/rico")
}

@Test func dailyCostUsesTheBlendedGpt6SolPrice() throws {
    let usage = try CodexUsage.parse(Data(fixture.utf8))
    // 0.916 x $0.20 cached + 0.080 x $2 input + 0.004 x $10 output = $0.3832 per million tokens.
    let cost = usage.dailyCost.mapValues { ($0 * 1e10).rounded() / 1e10 }
    #expect(cost == ["2026-10-19": 0.00045984, "2026-10-25": 0.00011496])
}
