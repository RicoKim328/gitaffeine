import SwiftUI

/// Nine weeks of daily commit counts: one column per week, oldest on the left, ending with the current week.
struct ContributionGrid: View {
    let counts: [String: Int]
    var today = Date()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(weeks, id: \.self) { week in
                VStack(spacing: 3) {
                    ForEach(week, id: \.self) { day in
                        cell(for: day)
                    }
                }
            }
        }
    }

    private var weeks: [[Date]] {
        let calendar = Calendar.current
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        let first = calendar.date(byAdding: .weekOfYear, value: -8, to: thisWeek)!
        return (0..<9).map { week in
            (0..<7).map { calendar.date(byAdding: .day, value: week * 7 + $0, to: first)! }
        }
    }

    @ViewBuilder
    private func cell(for day: Date) -> some View {
        let key = Self.dayKey.string(from: day)
        let count = counts[key, default: 0]
        RoundedRectangle(cornerRadius: 2)
            .fill(day > today ? Color.clear : Self.color(for: count))
            .frame(width: 12, height: 12)
            .help("\(key): \(count) commits")
    }

    private static func color(for count: Int) -> Color {
        switch count {
        case 0: Color.secondary.opacity(0.2)
        case 1...2: Color.green.opacity(0.4)
        case 3...5: Color.green.opacity(0.7)
        default: Color.green
        }
    }

    /// Same day format as `GitLog` ("yyyy-MM-dd" in this Mac's time zone).
    private static let dayKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
