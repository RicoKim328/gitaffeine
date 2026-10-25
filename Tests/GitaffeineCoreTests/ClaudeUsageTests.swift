import Foundation
@testable import GitaffeineCore
import Testing

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// One assistant line in the shape Claude Code writes to ~/.claude/projects/**/*.jsonl (2026-10-25), trimmed.
private func line(id: String, request: String = "req", model: String = "claude-opus-5-5",
                  at timestamp: String = "2026-10-24T10:00:00.000Z",
                  input: Int = 3, output: Int = 4, write5m: Int = 100, write1h: Int = 0, read: Int = 1000) -> String {
    """
    {"type":"assistant","timestamp":"\(timestamp)","requestId":"\(request)","message":{"id":"\(id)","model":"\(model)",\
    "usage":{"input_tokens":\(input),"output_tokens":\(output),"cache_creation_input_tokens":\(write5m + write1h),\
    "cache_read_input_tokens":\(read),"cache_creation":{"ephemeral_5m_input_tokens":\(write5m),\
    "ephemeral_1h_input_tokens":\(write1h)},"service_tier":"standard"}}}
    """
}

@Test func repeatedLinesOfOneResponseCountOnceWithTheFinalUsage() {
    // Claude Code writes a response once per content block; only the last line has the final output count.
    let file = [line(id: "m1", output: 4), line(id: "m1", output: 4), line(id: "m1", output: 238),
                #"{"type":"user","message":{"content":"hi"}}"#, "not json"].joined(separator: "\n")
    let daily = ClaudeUsage.daily(files: [Data(file.utf8)], calendar: utc)
    #expect(daily == ["2026-10-24": ["claude-opus-5-5": .init(input: 3, output: 238, cacheWrite5m: 100,
                                                              cacheWrite1h: 0, cacheRead: 1000)]])
}

@Test func sameResponseInTwoFilesCountsOnce() {
    let daily = ClaudeUsage.daily(files: [Data(line(id: "m1").utf8), Data(line(id: "m1").utf8)], calendar: utc)
    #expect(daily["2026-10-24"]?["claude-opus-5-5"]?.total == 1107)
}

@Test func responsesAreSummedPerDayAndModelInTheCalendarsTimeZone() {
    let file = [line(id: "a", at: "2026-10-24T23:30:00.000Z"), line(id: "b", at: "2026-10-24T10:00:00.000Z"),
                line(id: "c", model: "claude-haiku-4-5-20251001"),
                line(id: "d", model: "<synthetic>")].joined(separator: "\n")
    var seoul = utc
    seoul.timeZone = TimeZone(identifier: "Asia/Seoul")!
    let daily = ClaudeUsage.daily(files: [Data(file.utf8)], calendar: seoul)
    #expect(daily["2026-10-24"]?["claude-opus-5-5"]?.total == 1107)
    #expect(daily["2026-10-25"]?["claude-opus-5-5"]?.total == 1107) // 23:30 UTC is the next morning in Seoul
    #expect(daily["2026-10-24"]?["claude-haiku-4-5-20251001"]?.total == 1107)
    #expect(daily.values.allSatisfy { $0["<synthetic>"] == nil })
}

@Test func mergeKeepsTheLargerTotalPerDay() {
    let small = ["m": ClaudeUsage.Tokens(input: 1, output: 0, cacheWrite5m: 0, cacheWrite1h: 0, cacheRead: 0)]
    let large = ["m": ClaudeUsage.Tokens(input: 5, output: 0, cacheWrite5m: 0, cacheWrite1h: 0, cacheRead: 0)]
    let merged = ClaudeUsage.merge(cached: ["d1": large, "d2": small, "d3": small],
                                   parsed: ["d1": small, "d2": large, "d4": small])
    #expect(merged == ["d1": large, "d2": large, "d3": small, "d4": small])
}

@Test func costUsesListPricesAndSkipsUnknownModels() throws {
    let tokens = ClaudeUsage.Tokens(input: 1_000_000, output: 1_000_000, cacheWrite5m: 1_000_000,
                                    cacheWrite1h: 1_000_000, cacheRead: 1_000_000)
    // Opus 5.5: $4 in, $20 out, writes 1.25x / 2x input, reads $0.20.
    let opus: Double = 4 + 20 + 5 + 8 + 0.2
    #expect(abs(try #require(ClaudeUsage.cost(model: "claude-opus-5-5", tokens: tokens)) - opus) < 1e-9)
    let haiku: Double = 1 + 5 + 1.25 + 2 + 0.1
    #expect(abs(try #require(ClaudeUsage.cost(model: "claude-haiku-4-5-20251001", tokens: tokens)) - haiku) < 1e-9)
    #expect(ClaudeUsage.cost(model: "claude-unknown-9", tokens: tokens) == nil)
}

@Test func statusLineGivesBothWindowsAndDropsPassedOnes() throws {
    let json = Data("""
    {"model":{"id":"claude-opus-5-5"},"rate_limits":{"five_hour":{"used_percentage":37.6,"resets_at":2000},\
    "seven_day":{"used_percentage":5,"resets_at":900000}}}
    """.utf8)
    #expect(ClaudeUsage.windows(statusLine: json, now: Date(timeIntervalSince1970: 1000)) == [
        UsageWindow(usedPercent: 38, minutes: 300, resetsAt: Date(timeIntervalSince1970: 2000)),
        UsageWindow(usedPercent: 5, minutes: 7 * 24 * 60, resetsAt: Date(timeIntervalSince1970: 900000)),
    ])
    #expect(ClaudeUsage.windows(statusLine: json, now: Date(timeIntervalSince1970: 3000)).map(\.minutes) == [10080])
    #expect(ClaudeUsage.windows(statusLine: Data(#"{"rate_limits":null}"#.utf8), now: .now) == [])
}

@Test func emailComesFromTheAccountProfileOnly() {
    #expect(ClaudeUsage.email(claudeJSON: Data(#"{"oauthAccount":{"emailAddress":"rico@example.com"}}"#.utf8))
            == "rico@example.com")
    #expect(ClaudeUsage.email(claudeJSON: Data("{}".utf8)) == nil)
}

@Test func cachedDaysSurviveDeletedLogs() throws {
    let home = try TempDir()
    let projects = home.url.appending(path: ".claude/projects/p/sub")
    try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
    let log = projects.appending(path: "s.jsonl")
    try Data(line(id: "m1").utf8).write(to: log)
    let cache = home.url.appending(path: "support/claude-daily.json")

    let first = try ClaudeUsage.loadDaily(projects: home.url.appending(path: ".claude/projects"), cache: cache,
                                          calendar: utc)
    try FileManager.default.removeItem(at: log)
    let second = try ClaudeUsage.loadDaily(projects: home.url.appending(path: ".claude/projects"), cache: cache,
                                           calendar: utc)
    #expect(first["2026-10-24"]?["claude-opus-5-5"]?.total == 1107)
    #expect(second == first)
}
