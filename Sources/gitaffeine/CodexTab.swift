import Charts
import GitaffeineCore
import SwiftUI

/// Codex tab: account, the 5-hour and weekly limits, then 16 weeks of daily tokens and a chart.
struct CodexTab: View {
    let store: CodexStore
    @State private var days = 60

    var body: some View {
        Text(store.usage?.email.map { "Codex (\($0))" } ?? (store.hasLoaded ? "Codex" : "Codex (…)"))
            .font(.headline)
        if let error = store.error {
            Text(error).font(.caption).foregroundStyle(.secondary)
        } else if let usage = store.usage {
            let today = Date()
            if let fiveHour = usage.windows.first(where: { $0.minutes < 24 * 60 }) {
                separator
                UsageCells(fills: fiveHour.cellFills(count: 20))
                caption("남음 \(fiveHour.remainingPercent)% · 초기화까지 \(Self.duration(fiveHour.resetsAt.timeIntervalSince(today)))",
                        tokens: nil)
            }
            if let week = usage.windows.first(where: { $0.minutes >= 24 * 60 }) {
                separator
                let fills = week.dayFills(at: today)
                UsageCells(fills: fills, tips: fills.indices.map { Self.dayRange(week, day: $0) })
                HStack(spacing: 2) {
                    ForEach(1...fills.count, id: \.self) {
                        Text("\($0)").font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                caption(Self.pace(week, at: today) + "\n초기화까지 \(Self.duration(week.resetsAt.timeIntervalSince(today)))",
                        tokens: week.tokens(in: usage.dailyTokens, today: today, calendar: .current))
            }
            separator
            ContributionGrid(weeks: ContributionCalendar.weeks(endingAt: today, count: ContributionStore.weekCount,
                                                               calendar: .current),
                             counts: usage.dailyTokens, today: today,
                             thresholds: ContributionCalendar.levelThresholds(for: usage.dailyTokens))
            DailyTokenChart(daily: usage.dailyTokens, days: days, today: today)
            HStack {
                Picker("기간", selection: $days) {
                    ForEach([7, 30, 60], id: \.self) { Text("\($0)일") }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Picker("단위", selection: .constant(0)) {
                    Text("토큰").tag(0)
                    Text("$").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(true) // $ estimate comes in M5
                .frame(width: 80)
            }
        }
    }

    /// Same line as the popup's: black in light mode, white in dark mode.
    private var separator: some View { Rectangle().fill(Color.primary).frame(height: 1) }

    /// Small grey lines under a limit's cells, ending with tokens and the amount placeholder.
    private func caption(_ text: String, tokens: Int?) -> some View {
        let tokenText = tokens.map { "약 \($0.formatted()) 토큰" } ?? "토큰 —"
        return Text("\(text) · \(tokenText) · 금액 추정 · M5 예정")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// "경과 1일 5시간(17%) · 남음 95% · 이 속도면 초기화 때 남음 약 71%(예상)"
    private static func pace(_ week: CodexUsage.Window, at now: Date) -> String {
        let elapsed = week.elapsedFraction(at: now)
        var text = "경과 \(duration(now.timeIntervalSince(week.start)))(\(Int((elapsed * 100).rounded()))%) · 남음 \(week.remainingPercent)%"
        if let projected = week.projectedRemainingPercent(at: now) {
            text += " · 이 속도면 초기화 때 남음 약 \(projected)%(예상)"
        }
        return text
    }

    /// "10-24 09:30 ~ 10-25 09:30" for the `day`-th 24 hours of the window.
    private static func dayRange(_ week: CodexUsage.Window, day: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let from = week.start.addingTimeInterval(Double(day) * 24 * 3600)
        return "\(formatter.string(from: from)) ~ \(formatter.string(from: from.addingTimeInterval(24 * 3600)))"
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(seconds, 0)) ?? ""
    }
}

/// One row of cells filled from the left; a partly used cell is drawn lighter.
struct UsageCells: View {
    let fills: [Double]
    /// Tooltip per cell, if any.
    var tips: [String] = []

    var body: some View {
        HStack(spacing: 2) {
            ForEach(fills.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(fills[index])))
                    .frame(height: 12)
                    .help(tips.indices.contains(index) ? tips[index] : "")
            }
        }
    }
}

/// Daily tokens for the last `days` days as bars.
struct DailyTokenChart: View {
    let daily: [String: Int]
    let days: Int
    let today: Date

    var body: some View {
        let calendar = Calendar.current
        let dates = (0..<days).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        Chart(dates, id: \.self) { date in
            BarMark(x: .value("날짜", date, unit: .day),
                    y: .value("토큰", daily[ContributionCalendar.dayKey(date, calendar: calendar), default: 0]))
                .foregroundStyle(Color.green)
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel { Text((value.as(Int.self) ?? 0).formatted(.number.notation(.compactName))) }
            }
        }
        .frame(height: 90)
    }
}

/// Codex usage, fetched each time the popup opens or on 새로고침. Memory only: the history lives on the server.
@MainActor @Observable
final class CodexStore {
    private(set) var usage: CodexUsage.Usage?
    private(set) var error: String?
    private(set) var isRefreshing = false
    private(set) var hasLoaded = false

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let result = await Task.detached { Result { try CodexUsage.fetch() } }.value
        switch result {
        case .success(let fetched):
            usage = fetched
            error = nil
        case .failure(let failure):
            usage = nil
            error = (failure as? CocoaError)?.code == .fileNoSuchFile
                ? "codex CLI를 찾을 수 없음 · 설치 후 새로고침"
                : "codex 로그인 필요 또는 연결 오류 · 터미널에서 codex login 후 새로고침"
        }
        hasLoaded = true
    }
}
