import Charts
import GitaffeineCore
import SwiftUI

/// An AI tab (Codex, Claude, Grok): account, the 5-hour and weekly limits, then 20 weeks of daily tokens and a chart
/// (without daily tokens, only the limits).
struct UsageTab: View {
    let title: String
    /// Small grey line under the title, e.g. "실험적 방식".
    var note: String?
    var error: String?
    var windows: [UsageWindow] = []
    /// Shown instead of the limits when there are none, e.g. how to install the status line wrapper.
    var noWindowsHint: String?
    /// nil shows only the limits, e.g. Grok, which gives no daily history.
    var dailyTokens: [String: Int]?
    /// Estimated $ per day; nil disables the $ toggle.
    var dailyCost: [String: Double]?
    /// Said after every amount, e.g. "API 정가 기준 추정".
    var costNote = "API 정가 기준 추정"
    /// Days before this one have no data and are hatched in the grid.
    var firstDay: String?

    @State private var days = 60
    @State private var showsCost = false

    var body: some View {
        Text(title).font(.headline)
        if let note { small(note) }
        if let error {
            small(error)
        } else {
            let today = Date()
            if let fiveHour = windows.first(where: { $0.minutes < 24 * 60 }) {
                separator
                UsageCells(fills: fiveHour.cellFills(count: 20))
                small("남음 \(fiveHour.remainingPercent)% · 초기화까지 \(Self.duration(fiveHour.resetsAt.timeIntervalSince(today))) · 토큰 — · 금액 —")
            }
            if let week = windows.first(where: { $0.minutes >= 24 * 60 }) {
                separator
                let fills = week.dayFills(at: today)
                UsageCells(fills: fills, tips: fills.indices.map { Self.dayRange(week, day: $0) })
                HStack(spacing: 2) {
                    ForEach(1...fills.count, id: \.self) {
                        Text("\($0)").font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                small(Self.pace(week, at: today) + "\n초기화까지 \(Self.duration(week.resetsAt.timeIntervalSince(today)))"
                      + (dailyTokens.map { " · 약 \(week.total(in: $0, today: today, calendar: .current).formatted()) 토큰"
                          + " · " + amount(dailyCost.map { week.total(in: $0, today: today, calendar: .current) }) } ?? ""))
            }
            if windows.isEmpty, dailyTokens != nil, let noWindowsHint {
                separator
                small(noWindowsHint)
            }
            if let dailyTokens {
                separator
                ContributionGrid(weeks: ContributionCalendar.weeks(endingAt: today, count: ContributionStore.weekCount,
                                                                   calendar: .current),
                                 counts: dailyTokens, today: today,
                                 thresholds: ContributionCalendar.levelThresholds(for: dailyTokens), firstDay: firstDay)
                if showsCost, let dailyCost {
                    DailyChart(daily: dailyCost, days: days, today: today, label: "$")
                } else {
                    DailyChart(daily: dailyTokens.mapValues(Double.init), days: days, today: today, label: "토큰")
                }
                HStack {
                    Picker("기간", selection: $days) {
                        ForEach([7, 30, 60], id: \.self) { Text("\($0)일") }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Picker("단위", selection: $showsCost) {
                        Text("토큰").tag(false)
                        Text("$").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(dailyCost == nil)
                    .frame(width: 80)
                }
                if showsCost, dailyCost != nil {
                    small("$는 \(costNote)")
                }
            }
        }
    }

    /// Same line as the popup's: black in light mode, white in dark mode.
    private var separator: some View { Rectangle().fill(Color.primary).frame(height: 1) }

    /// Small grey text that wraps instead of being cut off.
    private func small(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private func amount(_ dollars: Double?) -> String {
        dollars.map { "약 \($0.formatted(.currency(code: "USD"))) (\(costNote))" } ?? "금액 —"
    }

    /// "경과 1일 5시간(17%) · 남음 95% · 이 속도면 초기화 때 남음 약 71%(예상)"
    private static func pace(_ week: UsageWindow, at now: Date) -> String {
        let elapsed = week.elapsedFraction(at: now)
        var text = "경과 \(duration(now.timeIntervalSince(week.start)))(\(Int((elapsed * 100).rounded()))%) · 남음 \(week.remainingPercent)%"
        if let projected = week.projectedRemainingPercent(at: now) {
            text += " · 이 속도면 초기화 때 남음 약 \(projected)%(예상)"
        }
        return text
    }

    /// "10-24 09:30 ~ 10-25 09:30" for the `day`-th 24 hours of the window.
    private static func dayRange(_ week: UsageWindow, day: Int) -> String {
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

/// Daily values (tokens or $) for the last `days` days as bars.
struct DailyChart: View {
    let daily: [String: Double]
    let days: Int
    let today: Date
    let label: String

    var body: some View {
        let calendar = Calendar.current
        let dates = (0..<days).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        Chart(dates, id: \.self) { date in
            BarMark(x: .value("날짜", date, unit: .day),
                    y: .value(label, daily[ContributionCalendar.dayKey(date, calendar: calendar), default: 0]))
                .foregroundStyle(Color.green)
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    let number = (value.as(Double.self) ?? 0).formatted(.number.notation(.compactName))
                    Text(label == "$" ? "$\(number)" : number)
                }
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

/// Claude usage from local files, reread each time the popup opens or on 새로고침; daily totals are cached on disk.
@MainActor @Observable
final class ClaudeStore {
    private(set) var usage: ClaudeUsage.Usage?
    private(set) var error: String?
    private(set) var isRefreshing = false
    private(set) var hasLoaded = false

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let result = await Task.detached { Result { try ClaudeUsage.load() } }.value
        switch result {
        case .success(let loaded):
            usage = loaded
            error = nil
        case .failure:
            usage = nil
            error = "사용량 캐시를 저장하지 못함 · ~/Library/Application Support/gitaffeine 권한 확인"
        }
        hasLoaded = true
    }
}

/// SuperGrok usage, fetched each time the popup opens or on 새로고침. Memory only: there is no history to keep.
@MainActor @Observable
final class GrokStore {
    private(set) var usage: GrokUsage.Usage?
    private(set) var error: String?
    private(set) var isRefreshing = false
    private(set) var hasLoaded = false

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let result = await Task.detached { Result { try GrokUsage.fetch() } }.value
        switch result {
        case .success(let fetched):
            usage = fetched
            error = nil
        case .failure(let failure):
            usage = nil
            error = (failure as? CocoaError)?.code == .fileNoSuchFile
                ? "grok CLI를 찾을 수 없음 · 설치 후 새로고침"
                : "grok 로그인 필요 또는 연결 오류 · 터미널에서 grok login 후 새로고침"
        }
        hasLoaded = true
    }
}
