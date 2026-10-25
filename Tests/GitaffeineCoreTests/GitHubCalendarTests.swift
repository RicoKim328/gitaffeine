import Foundation
import Testing
@testable import GitaffeineCore

private let fixture = """
{"data":{"viewer":{"login":"rico","email":"rico@example.com","contributionsCollection":{"contributionCalendar":{"weeks":[
  {"contributionDays":[{"date":"2026-10-18","contributionCount":0},{"date":"2026-10-19","contributionCount":4}]},
  {"contributionDays":[{"date":"2026-10-25","contributionCount":1}]}
]}}}}}
"""

@Test func parsesViewerAndDailyCounts() throws {
    let result = try GitHubCalendar.parse(Data(fixture.utf8))
    #expect(result == GitHubContributions(login: "rico", email: "rico@example.com", counts: [
        "2026-10-19": 4,
        "2026-10-25": 1,
    ]))
}

@Test func privateProfileEmailIsNil() throws {
    let json = fixture.replacingOccurrences(of: "\"rico@example.com\"", with: "\"\"")
    #expect(try GitHubCalendar.parse(Data(json.utf8)).email == nil)
}

@Test func errorResponseThrows() {
    let json = #"{"errors":[{"message":"Bad credentials"}]}"#
    #expect(throws: (any Error).self) { try GitHubCalendar.parse(Data(json.utf8)) }
}
