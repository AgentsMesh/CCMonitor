import Foundation
import Logging

/// 聚合数据快照 — 可 Codable 序列化到磁盘
struct AggregationSnapshot: Codable {
    /// 按天聚合 (key: "yyyy-MM-dd")
    var dailyUsage: [String: CodableUsageSummary]
    /// 按模型聚合
    var modelUsage: [String: CodableUsageSummary]
    /// 按项目聚合
    var projectUsage: [String: CodableProjectInfo]
    /// 总计
    var totalCostUSD: Double
    var totalTokens: Int
    var totalRequests: Int
    /// 去重哈希集合
    var seenHashes: [String]
    /// 快照时间
    var snapshotTime: TimeInterval
}

/// Codable 版本的 UsageSummary
struct CodableUsageSummary: Codable {
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int
    var totalCostUSD: Double
    var requestCount: Int
    var modelDistribution: [String: Int]

    func toUsageSummary() -> UsageSummary {
        UsageSummary(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            totalCostUSD: totalCostUSD,
            requestCount: requestCount,
            modelDistribution: modelDistribution
        )
    }

    static func from(_ s: UsageSummary) -> CodableUsageSummary {
        CodableUsageSummary(
            inputTokens: s.inputTokens,
            outputTokens: s.outputTokens,
            cacheCreationTokens: s.cacheCreationTokens,
            cacheReadTokens: s.cacheReadTokens,
            totalCostUSD: s.totalCostUSD,
            requestCount: s.requestCount,
            modelDistribution: s.modelDistribution
        )
    }
}

/// Codable 版本的 ProjectInfo
struct CodableProjectInfo: Codable {
    var projectPath: String
    var displayName: String
    var totalTokens: Int
    var totalCostUSD: Double
    var requestCount: Int
    var lastActivity: TimeInterval
    var models: [String]

    func toProjectInfo() -> ProjectInfo {
        ProjectInfo(
            projectPath: projectPath,
            displayName: displayName,
            totalTokens: totalTokens,
            totalCostUSD: totalCostUSD,
            requestCount: requestCount,
            lastActivity: Date(timeIntervalSince1970: lastActivity),
            activeSessions: 0,
            models: Set(models)
        )
    }

    static func from(_ p: ProjectInfo) -> CodableProjectInfo {
        CodableProjectInfo(
            projectPath: p.projectPath,
            displayName: p.displayName,
            totalTokens: p.totalTokens,
            totalCostUSD: p.totalCostUSD,
            requestCount: p.requestCount,
            lastActivity: p.lastActivity.timeIntervalSince1970,
            models: Array(p.models)
        )
    }
}

/// 聚合数据缓存管理
enum AggregationCache {
    private static let logger = Logger(label: "com.ccmonitor.AggregationCache")

    private static var cacheURL: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.ccmonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir.appendingPathComponent("aggregation_snapshot.json")
    }

    /// 从 aggregator 创建快照并保存到磁盘
    static func save(from aggregator: UsageAggregator) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var dailyMap: [String: CodableUsageSummary] = [:]
        for (bucket, summary) in aggregator.dailyUsage {
            let key = formatter.string(from: bucket.date)
            dailyMap[key] = CodableUsageSummary.from(summary)
        }

        var modelMap: [String: CodableUsageSummary] = [:]
        for (model, summary) in aggregator.modelUsage {
            modelMap[model] = CodableUsageSummary.from(summary)
        }

        var projectMap: [String: CodableProjectInfo] = [:]
        for (path, info) in aggregator.projectUsage {
            projectMap[path] = CodableProjectInfo.from(info)
        }

        let snapshot = AggregationSnapshot(
            dailyUsage: dailyMap,
            modelUsage: modelMap,
            projectUsage: projectMap,
            totalCostUSD: aggregator.totalCostUSD,
            totalTokens: aggregator.totalTokens,
            totalRequests: aggregator.totalRequests,
            seenHashes: Array(aggregator.seenHashesSnapshot),
            snapshotTime: Date().timeIntervalSince1970
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: cacheURL, options: .atomic)
            logger.info("Saved aggregation snapshot: \(snapshot.totalRequests) requests, $\(String(format: "%.2f", snapshot.totalCostUSD))")
        } catch {
            logger.warning("Failed to save aggregation snapshot: \(error.localizedDescription)")
        }
    }

    /// 从磁盘加载快照到 aggregator
    static func load(into aggregator: UsageAggregator) -> Bool {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            logger.info("No aggregation snapshot found")
            return false
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            let snapshot = try JSONDecoder().decode(AggregationSnapshot.self, from: data)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")

            // 恢复 daily usage
            for (dateStr, summary) in snapshot.dailyUsage {
                if let date = formatter.date(from: dateStr) {
                    let bucket = DateBucket.day(from: date)
                    aggregator.dailyUsage[bucket] = summary.toUsageSummary()
                }
            }

            // 恢复 model usage
            for (model, summary) in snapshot.modelUsage {
                aggregator.modelUsage[model] = summary.toUsageSummary()
            }

            // 恢复 project usage
            for (path, info) in snapshot.projectUsage {
                aggregator.projectUsage[path] = info.toProjectInfo()
            }

            // 恢复总计
            aggregator.totalCostUSD = snapshot.totalCostUSD
            aggregator.totalTokens = snapshot.totalTokens
            aggregator.totalRequests = snapshot.totalRequests

            // 恢复去重哈希
            aggregator.restoreSeenHashes(Set(snapshot.seenHashes))

            // 恢复今日聚合 (从 daily 中提取今日数据)
            // 注意：快照可能是昨天保存的，只有当 daily 中有"今天"的数据才恢复
            let todayStr = formatter.string(from: Date())
            if let todaySummary = snapshot.dailyUsage[todayStr] {
                aggregator.todayUsage = todaySummary.toUsageSummary()
            } else {
                aggregator.todayUsage = .empty
            }
            aggregator.syncTodayDate()

            logger.info("Restored aggregation snapshot: \(snapshot.totalRequests) requests, $\(String(format: "%.2f", snapshot.totalCostUSD)), \(snapshot.seenHashes.count) dedup hashes")
            return true
        } catch {
            logger.warning("Failed to load aggregation snapshot: \(error.localizedDescription)")
            return false
        }
    }

    /// 清除缓存
    static func clear() {
        try? FileManager.default.removeItem(at: cacheURL)
        logger.info("Cleared aggregation snapshot")
    }
}
