import GitaffeineCore
import SwiftUI

/// Daily counts drawn as a grid: one column per week, oldest on the left.
/// Takes any per-day counts, so other daily data (e.g. AI usage) can reuse it.
struct ContributionGrid: View {
    let weeks: [[Date]]
    let counts: [String: Int]
    let today: Date
    var calendar = Calendar.current
    /// The smallest count of each active level; commits use fixed levels.
    var thresholds = [1, 3, 6]

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

    @ViewBuilder
    private func cell(for day: Date) -> some View {
        let key = ContributionCalendar.dayKey(day, calendar: calendar)
        let count = counts[key, default: 0]
        RoundedRectangle(cornerRadius: 2)
            .fill(calendar.compare(day, to: today, toGranularity: .day) == .orderedDescending
                  ? Color.clear : color(for: count))
            .frame(width: 12, height: 12)
            .help("\(key): \(count)")
    }

    private func color(for count: Int) -> Color {
        switch count {
        case ..<thresholds[0]: Color.secondary.opacity(0.2)
        case ..<thresholds[1]: Color.green.opacity(0.4)
        case ..<thresholds[2]: Color.green.opacity(0.7)
        default: Color.green
        }
    }
}
