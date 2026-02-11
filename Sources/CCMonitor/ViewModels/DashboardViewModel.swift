import Foundation
import Observation

/// 选择的时间范围
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
    var selectedTimeRange: TimeRange = .hours
    var selectedChartStyle: ChartStyle = .bar

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

    private func updateTimeSeries(from aggregator: UsageAggregator) {
        let bucketData: [(DateBucket, UsageSummary)]

        switch selectedTimeRange {
        case .minutes:
            bucketData = aggregator.minuteUsage.sorted { $0.key < $1.key }
        case .hours:
            bucketData = aggregator.hourlyUsage.sorted { $0.key < $1.key }
        case .days:
            bucketData = aggregator.dailyUsage.sorted { $0.key < $1.key }
        }

        timeSeriesData = bucketData.map { bucket, summary in
            TimeSeriesPoint(
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
