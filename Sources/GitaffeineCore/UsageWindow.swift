import Foundation

/// A rate limit window (e.g. 5 hours, a week): percent used and when it resets. Shared by Codex and Claude.
public struct UsageWindow: Equatable, Sendable {
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

    /// Percent left at the reset if use keeps its average pace so far; nil before any time has passed.
    public func projectedRemainingPercent(at now: Date) -> Int? {
        let elapsed = elapsedFraction(at: now)
        guard elapsed > 0 else { return nil }
        return min(max(100 - Int((Double(usedPercent) / elapsed).rounded()), 0), 100)
    }

    /// Sum of daily values (tokens, $) from the window's first day through `today`.
    /// Daily totals only, so the first day counts in full.
    public func total<T: AdditiveArithmetic>(in daily: [String: T], today: Date, calendar: Calendar) -> T {
        let first = ContributionCalendar.dayKey(start, calendar: calendar)
        let last = ContributionCalendar.dayKey(today, calendar: calendar)
        return daily.filter { $0.key >= first && $0.key <= last }.values.reduce(.zero, +)
    }
}
