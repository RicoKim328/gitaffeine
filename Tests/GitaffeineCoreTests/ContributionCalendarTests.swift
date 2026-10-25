import Foundation
import Testing
@testable import GitaffeineCore

private func calendar(firstWeekday: Int) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    calendar.firstWeekday = firstWeekday
    return calendar
}

private func date(_ text: String, _ calendar: Calendar) -> Date {
    let parts = text.split(separator: "-").map { Int($0)! }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 15))!
}

@Test func weeksEndWithTheWeekOfTodayStartingSunday() {
    let cal = calendar(firstWeekday: 1)
    let today = date("2026-10-22", cal) // Thursday

    let weeks = ContributionCalendar.weeks(endingAt: today, count: 16, calendar: cal)

    #expect(weeks.count == 16)
    #expect(weeks.allSatisfy { $0.count == 7 })
    #expect(ContributionCalendar.dayKey(weeks[0][0], calendar: cal) == "2026-07-05")   // Sunday, 15 weeks earlier
    #expect(ContributionCalendar.dayKey(weeks[15][0], calendar: cal) == "2026-10-18")  // this week's Sunday
    #expect(ContributionCalendar.dayKey(weeks[15][6], calendar: cal) == "2026-10-24")  // Saturday, in the future
}

@Test func weeksCanStartOnMonday() {
    let cal = calendar(firstWeekday: 2)
    let weeks = ContributionCalendar.weeks(endingAt: date("2026-10-22", cal), count: 1, calendar: cal)
    #expect(weeks[0].map { ContributionCalendar.dayKey($0, calendar: cal) }.first == "2026-10-19")
}

@Test func activeShareCountsOnlyDaysUpToToday() {
    let cal = calendar(firstWeekday: 1)
    let today = date("2026-10-22", cal)
    let weeks = ContributionCalendar.weeks(endingAt: today, count: 2, calendar: cal) // Oct 11 ... Oct 24

    let share = ContributionCalendar.activeShare(of: weeks, counts: [
        "2026-10-11": 1,
        "2026-10-22": 3,
        "2026-10-23": 5, // future: ignored
        "2026-10-15": 0,
    ], today: today, calendar: cal)

    #expect(share == ContributionCalendar.Share(activeDays: 2, shownDays: 12))
    #expect(share.percent == 17) // 16.7 rounded
}

@Test func dayKeyIsGregorianWhateverTheSystemCalendar() {
    var buddhist = Calendar(identifier: .buddhist)
    buddhist.timeZone = TimeZone(identifier: "Asia/Seoul")!
    #expect(ContributionCalendar.dayKey(date("2026-10-22", calendar(firstWeekday: 1)), calendar: buddhist) == "2026-10-22")
}

@Test func activeShareEdges() {
    #expect(ContributionCalendar.Share(activeDays: 0, shownDays: 112).percent == 0)
    #expect(ContributionCalendar.Share(activeDays: 112, shownDays: 112).percent == 100)
    #expect(ContributionCalendar.Share(activeDays: 0, shownDays: 0).percent == 0)
}
