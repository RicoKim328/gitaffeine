import Foundation
@testable import GitaffeineCore
import Testing

// Shapes from a real `grok agent stdio` reply (2026-10-25), trimmed. One JSON message per line, notifications in between.
private let fixture = """
{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{}}}
{"jsonrpc":"2.0","method":"_x.ai/mcp/servers_updated","params":{}}
{"jsonrpc":"2.0","id":2,"result":{"config":{"creditUsagePercent":6.0,"currentPeriod":\
{"type":"USAGE_PERIOD_TYPE_WEEKLY","start":"2026-10-25T04:43:45.477+00:00","end":"2026-11-01T04:43:45.477+00:00"},\
"prepaidBalance":{"val":0},"isUnifiedBillingUser":true,"billingPeriodStart":"2026-10-25T04:43:45.477+00:00",\
"billingPeriodEnd":"2026-11-01T04:43:45.477+00:00"},"subscription_tier":"SuperGrok"}}
{"jsonrpc":"2.0","id":3,"result":{"authenticated":true,"meta":{"email":"user@example.com","auth_mode":"x",\
"team_id":"fake-team","team_name":null,"subscription_tier":"SuperGrok"}}}

"""

@Test func parsesTierWeeklyWindowAndBalance() throws {
    let usage = try GrokUsage.parse(Data(fixture.utf8))
    #expect(usage.tier == "SuperGrok")
    #expect(usage.window.usedPercent == 6)
    #expect(usage.window.minutes == 7 * 24 * 60)
    #expect(abs(usage.window.resetsAt.timeIntervalSince1970 - 1_793_508_225.477) < 0.001)
    #expect(usage.prepaidBalance == 0)
    #expect(usage.email == "user@example.com")
}

@Test func failedSubscriptionReplyOnlyDropsEmail() throws {
    let json = fixture.replacingOccurrences(of: #"{"jsonrpc":"2.0","id":3,"result""#,
                                            with: #"{"jsonrpc":"2.0","id":3,"error":{"code":-32601,"message":"Method not found"},"x""#)
    let usage = try GrokUsage.parse(Data(json.utf8))
    #expect(usage.email == nil)
    #expect(usage.window.usedPercent == 6)
}

@Test func omittedZeroFieldsMeanZero() throws {
    // Protobuf JSON leaves out zero values.
    let json = fixture.replacingOccurrences(of: #""creditUsagePercent":6.0,"#, with: "")
        .replacingOccurrences(of: #"{"val":0}"#, with: "{}")
    let usage = try GrokUsage.parse(Data(json.utf8))
    #expect(usage.window.usedPercent == 0)
    #expect(usage.prepaidBalance == 0)
}

@Test func grokErrorReplyThrows() {
    let json = fixture.replacingOccurrences(of: #"{"jsonrpc":"2.0","id":2,"result""#,
                                            with: #"{"jsonrpc":"2.0","id":2,"error":{"code":-32601,"message":"Method not found"},"x""#)
    #expect(throws: (any Error).self) { try GrokUsage.parse(Data(json.utf8)) }
}

@Test func missingBillingReplyThrows() {
    let json = fixture.split(separator: "\n").filter { !$0.contains(#""id":2"#) }.joined(separator: "\n")
    #expect(throws: (any Error).self) { try GrokUsage.parse(Data(json.utf8)) }
}

@Test func grokRequestsAreOneJSONMessagePerLine() throws {
    let lines = String(decoding: GrokUsage.requests, as: UTF8.self).split(separator: "\n")
    let messages = try lines.map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any] }
    #expect(messages.map { $0["method"] as! String } == ["initialize", "_x.ai/billing", "_x.ai/auth/check_subscription"])
}

@Test func timesWithoutFractionParse() throws {
    let json = fixture.replacingOccurrences(of: ".477+00:00", with: "+00:00")
    #expect(try GrokUsage.parse(Data(json.utf8)).window.resetsAt == Date(timeIntervalSince1970: 1_793_508_225))
}
