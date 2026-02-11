import Foundation
import SwiftData

/// 聚合粒度
enum AggregationGranularity: String, Codable, Sendable, CaseIterable {
    case minute
    case hourly
    case daily
}

/// 聚合后的 usage 数据 (可持久化)
@Model
final class AggregatedUsage {
    var periodStart: Date
    var periodEnd: Date
    var granularity: String // AggregationGranularity.rawValue

    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int
    var totalCostUSD: Double
    var requestCount: Int

    /// 按模型分布 (JSON encoded: [String: Int])
    var modelDistributionJSON: String

    init(
        periodStart: Date,
        periodEnd: Date,
        granularity: AggregationGranularity,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0,
        totalCostUSD: Double = 0,
        requestCount: Int = 0,
        modelDistribution: [String: Int] = [:]
    ) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.granularity = granularity.rawValue
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.totalCostUSD = totalCostUSD
        self.requestCount = requestCount
        self.modelDistributionJSON = (try? JSONEncoder().encode(modelDistribution))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    var modelDistribution: [String: Int] {
        get {
            guard let data = modelDistributionJSON.data(using: .utf8) else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }
        set {
            modelDistributionJSON = (try? JSONEncoder().encode(newValue))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        }
    }
}
