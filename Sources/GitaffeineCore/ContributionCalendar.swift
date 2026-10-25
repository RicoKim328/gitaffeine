import Foundation

/// Which days a contribution grid shows, and how many of them were active.
public enum ContributionCalendar {
    /// `count` weeks of days, oldest first, ending with the week that contains `today`.
    /// Weeks start on `calendar.firstWeekday`; the last week can include days after `today`.
    public static func weeks(endingAt today: Date, count: Int, calendar: Calendar) -> [[Date]] {
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        let first = calendar.date(byAdding: .weekOfYear, value: -(count - 1), to: thisWeek)!
        return (0..<count).map { week in
            (0..<7).map { calendar.date(byAdding: .day, value: week * 7 + $0, to: first)! }
        }
    }

    /// "yyyy-MM-dd" in the calendar's time zone, the same key `GitLog` produces.
    /// Always Gregorian, like git's dates, even when the system uses e.g. the Buddhist calendar.
    public static func dayKey(_ date: Date, calendar: Calendar) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    public struct Share: Equatable, Sendable {
        public let activeDays: Int
        public let shownDays: Int

        /// Rounded to a whole percent; 0 when no days are shown.
        public var percent: Int {
            shownDays == 0 ? 0 : Int((Double(activeDays) * 100 / Double(shownDays)).rounded())
        }
    }

    /// Days in `weeks` up to and including `today`, and how many of them have at least one contribution.
    public static func activeShare(of weeks: [[Date]], counts: [String: Int], today: Date, calendar: Calendar) -> Share {
        let shown = weeks.joined().filter { calendar.compare($0, to: today, toGranularity: .day) != .orderedDescending }
        let active = shown.filter { counts[dayKey($0, calendar: calendar), default: 0] > 0 }
        return Share(activeDays: active.count, shownDays: shown.count)
    }

    /// The smallest count of each of the grid's three active levels: thirds of the active days.
    /// For counts with no natural scale, such as AI tokens; git commits use fixed levels.
    public static func levelThresholds(for counts: [String: Int]) -> [Int] {
        let active = counts.values.filter { $0 > 0 }.sorted()
        guard !active.isEmpty else { return [1, 2, 3] }
        return [1, active[active.count / 3], active[active.count * 2 / 3]]
    }
}
