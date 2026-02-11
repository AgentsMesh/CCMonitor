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
    let tokens: Int
    let requests: Int

    init(date: Date, cost: Double, tokens: Int, requests: Int) {
        self.id = date
        self.date = date
        self.cost = cost
        self.tokens = tokens
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
    var todayTokens: Int = 0
    var burnRate: BurnRateCalculator.BurnRate = .zero
    var activeSessions: Int = 0

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
        todayCost = aggregator.todayUsage.totalCostUSD
        todayTokens = aggregator.todayUsage.totalTokens
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
                tokens: summary.totalTokens,
                requests: summary.requestCount
            )
        }
    }
}
