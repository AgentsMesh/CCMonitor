import Foundation

/// Burn Rate 计算器
/// 基于最近 N 分钟的消耗速率推算日/月成本
enum BurnRateCalculator {
    struct BurnRate: Sendable {
        let costPerMinute: Double
        let costPerHour: Double
        let tokensPerMinute: Double
        let projectedDailyCost: Double
        let projectedMonthlyCost: Double

        static let zero = BurnRate(
            costPerMinute: 0, costPerHour: 0,
            tokensPerMinute: 0,
            projectedDailyCost: 0, projectedMonthlyCost: 0
        )
    }

    /// 从最近的分钟级数据计算 burn rate
    static func calculate(
        minuteUsage: [DateBucket: UsageSummary],
        windowMinutes: Int = Constants.burnRateWindowMinutes
    ) -> BurnRate {
        let now = Date()
        let windowStart = now.addingTimeInterval(-Double(windowMinutes) * 60)

        // 筛选窗口内的数据
        let recentData = minuteUsage.filter { key, _ in
            key.date >= windowStart && key.date <= now
        }

        guard !recentData.isEmpty else { return .zero }

        // 计算窗口内的总计
        let totalCost = recentData.values.reduce(0.0) { $0 + $1.totalCostUSD }
        let totalTokens = recentData.values.reduce(0) { $0 + $1.totalTokens }

        // 计算实际活跃时间跨度 (分钟)
        let sortedDates = recentData.keys.sorted()
        guard let firstDate = sortedDates.first?.date,
              let lastDate = sortedDates.last?.date else { return .zero }

        let spanMinutes = max(1, lastDate.timeIntervalSince(firstDate) / 60 + 1)

        let costPerMinute = totalCost / spanMinutes
        let costPerHour = costPerMinute * 60
        let tokensPerMinute = Double(totalTokens) / spanMinutes

        return BurnRate(
            costPerMinute: costPerMinute,
            costPerHour: costPerHour,
            tokensPerMinute: tokensPerMinute,
            projectedDailyCost: costPerHour * 24,
            projectedMonthlyCost: costPerHour * 24 * 30
        )
    }
}
