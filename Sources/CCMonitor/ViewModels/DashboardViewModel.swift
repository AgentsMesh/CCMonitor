import Foundation
import Observation

/// 选择的时间范围（保留用于兼容粒度标签显示）
enum TimeRange: String, CaseIterable, Sendable {
    case minutes = "Minutes"
    case hours = "Hours"
    case days = "Days"
}

/// 图表类型
enum ChartStyle: String, CaseIterable, Sendable {
    case bar = "Bar"
    case line = "Line"
}

/// 可见时间窗口模型
struct TimeWindow: Equatable {
    var start: Date
    var end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }

    /// 根据窗口宽度自动判定粒度
    var granularity: AggregationGranularity {
        let d = duration
        if d <= Constants.granularityMinuteThreshold { return .minute }
        if d <= Constants.granularityHourlyThreshold { return .hourly }
        return .daily
    }

    /// 对应的 TimeRange（用于 X 轴格式化等兼容场景）
    var timeRange: TimeRange {
        switch granularity {
        case .minute: return .minutes
        case .hourly: return .hours
        case .daily:  return .days
        }
    }

    /// 以中心为锚点缩放，clamp 到 [minDuration, maxDuration]
    func zoomed(by factor: Double) -> TimeWindow {
        let center = start.addingTimeInterval(duration / 2)
        let newDuration = (duration * factor).clamped(
            to: Constants.timeWindowMinDuration...Constants.timeWindowMaxDuration
        )
        let halfNew = newDuration / 2
        return TimeWindow(
            start: center.addingTimeInterval(-halfNew),
            end: center.addingTimeInterval(halfNew)
        )
    }

    /// 平移指定秒数
    func shifted(by seconds: TimeInterval) -> TimeWindow {
        TimeWindow(
            start: start.addingTimeInterval(seconds),
            end: end.addingTimeInterval(seconds)
        )
    }

    /// 限制在数据可用范围内
    func clamped(to bounds: ClosedRange<Date>) -> TimeWindow {
        let dur = duration
        var s = start
        var e = end

        if s < bounds.lowerBound {
            s = bounds.lowerBound
            e = s.addingTimeInterval(dur)
        }
        if e > bounds.upperBound {
            e = bounds.upperBound
            s = e.addingTimeInterval(-dur)
        }
        // 再次确保 start 不越过 lower bound
        if s < bounds.lowerBound {
            s = bounds.lowerBound
        }
        return TimeWindow(start: s, end: e)
    }

    /// 默认窗口：最近 N 秒
    static func defaultWindow() -> TimeWindow {
        let now = Date()
        return TimeWindow(
            start: now.addingTimeInterval(-Constants.timeWindowDefaultDuration),
            end: now
        )
    }
}

/// 时间序列数据点
struct TimeSeriesPoint: Identifiable {
    let id: Date
    let date: Date
    let cost: Double
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int
    let requests: Int

    /// input + output (展示用)
    var tokens: Int { inputTokens + outputTokens }

    /// 分类展示文本 (e.g., "I:2.1M O:0.8M C:95.2M")
    var tokenBreakdown: String {
        Formatters.formatTokenBreakdown(input: inputTokens, output: outputTokens, cacheRead: cacheTokens)
    }

    init(date: Date, cost: Double, inputTokens: Int, outputTokens: Int, cacheTokens: Int, requests: Int) {
        self.id = date
        self.date = date
        self.cost = cost
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheTokens = cacheTokens
        self.requests = requests
    }
}

/// Dashboard 主 ViewModel
@Observable
final class DashboardViewModel {
    /// 可见时间窗口
    var timeWindow: TimeWindow = .defaultWindow()

    /// 兼容属性：基于 timeWindow 自动推导
    var selectedTimeRange: TimeRange { timeWindow.timeRange }

    var selectedChartStyle: ChartStyle = .bar

    /// 实时模式：窗口右端跟随 now 自动滚动
    var isLive: Bool = true

    /// 拖拽中标记（拖拽时忽略 tooltip selection）
    var isDragging: Bool = false

    /// 全部数据的时间极值
    var dataBounds: ClosedRange<Date>?

    // 摘要数据
    var todayCost: Double = 0
    var todayInputTokens: Int = 0
    var todayOutputTokens: Int = 0
    var todayCacheReadTokens: Int = 0
    var todayCacheCreationTokens: Int = 0
    var burnRate: BurnRateCalculator.BurnRate = .zero
    var activeSessions: Int = 0

    /// token 分类展示文本
    var todayTokenBreakdown: String {
        Formatters.formatTokenBreakdown(
            input: todayInputTokens,
            output: todayOutputTokens,
            cacheRead: todayCacheReadTokens,
            cacheCreation: todayCacheCreationTokens
        )
    }

    // 时间序列数据
    var timeSeriesData: [TimeSeriesPoint] = []

    // 选中的数据点（用于 tooltip）
    var selectedPoint: TimeSeriesPoint?
    /// chartXSelection 绑定的原始日期值
    var rawSelectedDate: Date?

    // 模型分布
    var modelDistribution: [(model: String, count: Int)] = []

    // 项目列表
    var projects: [ProjectInfo] = []

    // MARK: - 时间窗口操作

    /// 缩放：factor > 1 缩小（看到更多数据），< 1 放大（看到更少数据）
    func zoom(by factor: Double) {
        isLive = false
        var newWindow = timeWindow.zoomed(by: factor)
        if let bounds = dataBounds {
            newWindow = newWindow.clamped(to: bounds)
        }
        timeWindow = newWindow
    }

    /// 平移：正值向右（未来），负值向左（过去）
    func pan(by seconds: TimeInterval) {
        isLive = false
        var newWindow = timeWindow.shifted(by: seconds)
        if let bounds = dataBounds {
            newWindow = newWindow.clamped(to: bounds)
        }
        timeWindow = newWindow
    }

    /// 应用预设窗口宽度
    func applyPreset(duration: TimeInterval) {
        let now = Date()
        timeWindow = TimeWindow(
            start: now.addingTimeInterval(-duration),
            end: now
        )
        if let bounds = dataBounds {
            timeWindow = timeWindow.clamped(to: bounds)
        }
        // 预设始终回到实时模式
        isLive = true
    }

    /// 恢复实时跟随
    func goLive() {
        isLive = true
        let dur = timeWindow.duration
        let now = Date()
        timeWindow = TimeWindow(
            start: now.addingTimeInterval(-dur),
            end: now
        )
    }

    // MARK: - 数据更新

    /// 更新所有面板数据
    func update(from aggregator: UsageAggregator) {
        let today = aggregator.todayUsage
        todayCost = today.totalCostUSD
        todayInputTokens = today.inputTokens
        todayOutputTokens = today.outputTokens
        todayCacheReadTokens = today.cacheReadTokens
        todayCacheCreationTokens = today.cacheCreationTokens
        activeSessions = aggregator.activeSessionCount
        burnRate = BurnRateCalculator.calculate(minuteUsage: aggregator.minuteUsage)

        // 计算数据时间边界
        updateDataBounds(from: aggregator)

        // isLive 时自动右移窗口
        if isLive {
            let dur = timeWindow.duration
            let now = Date()
            timeWindow = TimeWindow(
                start: now.addingTimeInterval(-dur),
                end: now
            )
        }

        // 更新时间序列
        updateTimeSeries(from: aggregator)

        // 更新模型分布
        modelDistribution = aggregator.modelUsage
            .map { (model: $0.key, count: $0.value.requestCount) }
            .sorted { $0.count > $1.count }

        // 更新项目列表
        projects = aggregator.projectUsage.values
            .sorted { $0.totalCostUSD > $1.totalCostUSD }
    }

    private func updateDataBounds(from aggregator: UsageAggregator) {
        // 收集所有数据源的时间极值
        var allDates: [Date] = []

        for bucket in aggregator.minuteUsage.keys { allDates.append(bucket.date) }
        for bucket in aggregator.hourlyUsage.keys { allDates.append(bucket.date) }
        for bucket in aggregator.dailyUsage.keys { allDates.append(bucket.date) }

        guard let minDate = allDates.min(), let maxDate = allDates.max() else {
            dataBounds = nil
            return
        }
        // 右边界扩展一点，确保最新数据点不被裁掉
        dataBounds = minDate...maxDate.addingTimeInterval(3600)
    }

    private func updateTimeSeries(from aggregator: UsageAggregator) {
        let bucketData: [(DateBucket, UsageSummary)]

        switch timeWindow.granularity {
        case .minute:
            bucketData = aggregator.minuteUsage.sorted { $0.key < $1.key }
        case .hourly:
            bucketData = aggregator.hourlyUsage.sorted { $0.key < $1.key }
        case .daily:
            bucketData = aggregator.dailyUsage.sorted { $0.key < $1.key }
        }

        // 按时间窗口过滤
        let windowStart = timeWindow.start
        let windowEnd = timeWindow.end

        timeSeriesData = bucketData.compactMap { bucket, summary in
            guard bucket.date >= windowStart && bucket.date <= windowEnd else { return nil }
            return TimeSeriesPoint(
                date: bucket.date,
                cost: summary.totalCostUSD,
                inputTokens: summary.inputTokens,
                outputTokens: summary.outputTokens,
                cacheTokens: summary.cacheTokens,
                requests: summary.requestCount
            )
        }
    }
}

// MARK: - Comparable clamping helper

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
