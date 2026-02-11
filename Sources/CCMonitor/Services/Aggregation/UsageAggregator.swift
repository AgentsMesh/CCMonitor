import Foundation
import Observation
import Logging

/// 多维度增量聚合引擎
@Observable
final class UsageAggregator: @unchecked Sendable {
    private static let logger = Logger(label: "com.ccmonitor.UsageAggregator")
    // MARK: - 聚合数据

    /// 今日聚合
    var todayUsage: UsageSummary = .empty

    /// 按小时聚合 (最近 24h)
    var hourlyUsage: [DateBucket: UsageSummary] = [:]

    /// 按天聚合 (最近 30 天)
    var dailyUsage: [DateBucket: UsageSummary] = [:]

    /// 按分钟聚合 (最近 60 分钟)
    var minuteUsage: [DateBucket: UsageSummary] = [:]

    /// 按项目聚合
    var projectUsage: [String: ProjectInfo] = [:]

    /// 按模型聚合
    var modelUsage: [String: UsageSummary] = [:]

    /// 活跃 sessions
    var sessions: [String: SessionInfo] = [:]

    /// 总计
    var totalCostUSD: Double = 0
    var totalTokens: Int = 0
    var totalRequests: Int = 0

    // MARK: - 去重

    private var seenHashes: Set<String> = []

    /// 去重哈希快照（供缓存序列化使用）
    var seenHashesSnapshot: Set<String> { seenHashes }

    /// 从缓存恢复去重哈希集合
    func restoreSeenHashes(_ hashes: Set<String>) {
        seenHashes = hashes
    }

    // MARK: - 增量处理

    /// 增量处理一批 UsageEntry
    /// - Parameters:
    ///   - entries: 新的 usage 条目
    ///   - costs: 对应的计算成本 (与 entries 一一对应)
    ///   - filePath: 来源文件路径 (用于项目维度)
    func process(entries: [UsageEntry], costs: [Double], filePath: String) {
        guard entries.count == costs.count else { return }

        for (entry, cost) in zip(entries, costs) {
            processSingleEntry(entry, cost: cost, filePath: filePath)
        }
    }

    private func processSingleEntry(_ entry: UsageEntry, cost: Double, filePath: String) {
        // 去重检查
        if let hash = entry.uniqueHash {
            guard !seenHashes.contains(hash) else {
                Self.logger.trace("Dedup: skipped hash=\(hash)")
                return
            }
            seenHashes.insert(hash)
        }

        guard let timestamp = entry.parsedTimestamp else {
            Self.logger.warning("⚠️ Skipping entry: unparseable timestamp '\(entry.timestamp)'")
            return
        }
        guard let usage = entry.message.usage else {
            Self.logger.warning("⚠️ Skipping entry: no usage data")
            return
        }

        let model = entry.message.model ?? "unknown"
        let tokenInfo = TokenInfo(
            inputTokens: usage.input_tokens,
            outputTokens: usage.output_tokens,
            cacheCreationTokens: usage.cache_creation_input_tokens ?? 0,
            cacheReadTokens: usage.cache_read_input_tokens ?? 0
        )

        // 更新总计
        totalCostUSD += cost
        totalTokens += entry.totalTokens
        totalRequests += 1

        // 更新今日聚合
        if Calendar.current.isDateInToday(timestamp) {
            todayUsage.add(tokens: tokenInfo, cost: cost, model: model)
        }

        // 更新分钟聚合
        let minuteBucket = DateBucket.minute(from: timestamp)
        minuteUsage[minuteBucket, default: .empty].add(tokens: tokenInfo, cost: cost, model: model)

        // 更新小时聚合
        let hourBucket = DateBucket.hour(from: timestamp)
        hourlyUsage[hourBucket, default: .empty].add(tokens: tokenInfo, cost: cost, model: model)

        // 更新天聚合
        let dayBucket = DateBucket.day(from: timestamp)
        dailyUsage[dayBucket, default: .empty].add(tokens: tokenInfo, cost: cost, model: model)

        // 更新模型聚合
        modelUsage[model, default: .empty].add(tokens: tokenInfo, cost: cost, model: model)

        // 更新项目聚合
        let projectPath = extractProjectPath(from: filePath)
        if var proj = projectUsage[projectPath] {
            proj.totalTokens += entry.totalTokens
            proj.totalCostUSD += cost
            proj.requestCount += 1
            proj.lastActivity = max(proj.lastActivity, timestamp)
            proj.models.insert(model)
            projectUsage[projectPath] = proj
        } else {
            projectUsage[projectPath] = ProjectInfo(
                projectPath: projectPath,
                displayName: ProjectInfo.extractDisplayName(from: filePath),
                totalTokens: entry.totalTokens,
                totalCostUSD: cost,
                requestCount: 1,
                lastActivity: timestamp,
                activeSessions: 0,
                models: [model]
            )
        }

        // 更新 session
        if let sessionId = entry.sessionId {
            if var session = sessions[sessionId] {
                session.totalTokens += entry.totalTokens
                session.totalCostUSD += cost
                session.lastActivity = max(session.lastActivity, timestamp)
                session.modelName = model
                session.entryCount += 1
                session.updateStatus()
                sessions[sessionId] = session
            } else {
                var newSession = SessionInfo(
                    id: sessionId,
                    status: .active,
                    lastActivity: timestamp,
                    projectPath: projectPath,
                    totalTokens: entry.totalTokens,
                    totalCostUSD: cost,
                    modelName: model,
                    entryCount: 1
                )
                newSession.updateStatus()
                sessions[sessionId] = newSession
            }
        }
    }

    /// 从文件路径提取项目路径
    private func extractProjectPath(from filePath: String) -> String {
        // 路径: ~/.claude/projects/{encoded_project_path}/{session}.jsonl
        let components = filePath.split(separator: "/")
        if let idx = components.firstIndex(of: "projects"), idx + 1 < components.count {
            return String(components[idx + 1])
        }
        return "unknown"
    }

    /// 获取活跃 session 数量
    var activeSessionCount: Int {
        sessions.values.filter { $0.status == .active }.count
    }

    /// 清理过期数据
    func pruneOldData() {
        let now = Date()

        // 清理超过 60 分钟的分钟级数据
        minuteUsage = minuteUsage.filter { key, _ in
            now.timeIntervalSince(key.date) < 3600
        }

        // 清理超过 7 天的小时级数据
        hourlyUsage = hourlyUsage.filter { key, _ in
            now.timeIntervalSince(key.date) < 7 * 86400
        }

        // 清理超过 30 天的天级数据
        dailyUsage = dailyUsage.filter { key, _ in
            now.timeIntervalSince(key.date) < 30 * 86400
        }

        // 清理死亡 sessions
        sessions = sessions.filter { _, session in
            session.status != .dead
        }
    }

    /// 重置所有数据
    func reset() {
        todayUsage = .empty
        hourlyUsage = [:]
        dailyUsage = [:]
        minuteUsage = [:]
        projectUsage = [:]
        modelUsage = [:]
        sessions = [:]
        totalCostUSD = 0
        totalTokens = 0
        totalRequests = 0
        seenHashes = []
    }
}

// MARK: - 辅助类型

/// 时间桶 (用于聚合 key)
struct DateBucket: Hashable, Comparable, Sendable {
    let date: Date
    let granularity: AggregationGranularity

    static func < (lhs: DateBucket, rhs: DateBucket) -> Bool {
        lhs.date < rhs.date
    }

    static func minute(from date: Date) -> DateBucket {
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let truncated = cal.date(from: components) ?? date
        return DateBucket(date: truncated, granularity: .minute)
    }

    static func hour(from date: Date) -> DateBucket {
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month, .day, .hour], from: date)
        let truncated = cal.date(from: components) ?? date
        return DateBucket(date: truncated, granularity: .hourly)
    }

    static func day(from date: Date) -> DateBucket {
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month, .day], from: date)
        let truncated = cal.date(from: components) ?? date
        return DateBucket(date: truncated, granularity: .daily)
    }
}

/// Token 信息
struct TokenInfo: Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int

    var total: Int { inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens }
}

/// 使用量摘要
struct UsageSummary: Sendable {
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int
    var totalCostUSD: Double
    var requestCount: Int
    var modelDistribution: [String: Int]

    var totalTokens: Int { inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens }

    static let empty = UsageSummary(
        inputTokens: 0, outputTokens: 0,
        cacheCreationTokens: 0, cacheReadTokens: 0,
        totalCostUSD: 0, requestCount: 0,
        modelDistribution: [:]
    )

    mutating func add(tokens: TokenInfo, cost: Double, model: String) {
        inputTokens += tokens.inputTokens
        outputTokens += tokens.outputTokens
        cacheCreationTokens += tokens.cacheCreationTokens
        cacheReadTokens += tokens.cacheReadTokens
        totalCostUSD += cost
        requestCount += 1
        modelDistribution[model, default: 0] += 1
    }
}
