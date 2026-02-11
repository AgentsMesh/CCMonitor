import Foundation
import SwiftData

/// SwiftData 持久化存储
actor UsageStore {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init() throws {
        let schema = Schema([AggregatedUsage.self])
        let config = ModelConfiguration(
            "CCMonitorStore",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        self.modelContext = ModelContext(modelContainer)
    }

    /// 保存聚合数据
    func save(_ usage: AggregatedUsage) throws {
        modelContext.insert(usage)
        try modelContext.save()
    }

    /// 批量保存
    func saveBatch(_ usages: [AggregatedUsage]) throws {
        for usage in usages {
            modelContext.insert(usage)
        }
        try modelContext.save()
    }

    /// 查询指定粒度和时间范围的聚合数据
    func fetch(
        granularity: AggregationGranularity,
        from startDate: Date,
        to endDate: Date
    ) throws -> [AggregatedUsage] {
        let gran = granularity.rawValue
        let predicate = #Predicate<AggregatedUsage> { usage in
            usage.granularity == gran &&
            usage.periodStart >= startDate &&
            usage.periodEnd <= endDate
        }
        let descriptor = FetchDescriptor<AggregatedUsage>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.periodStart)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// 查询今日聚合数据
    func fetchToday() throws -> [AggregatedUsage] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        return try fetch(granularity: .hourly, from: startOfDay, to: endOfDay)
    }

    /// 清理过期数据 (保留最近 90 天)
    func pruneOldData(retentionDays: Int = 90) throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        let predicate = #Predicate<AggregatedUsage> { usage in
            usage.periodEnd < cutoff
        }
        let descriptor = FetchDescriptor<AggregatedUsage>(predicate: predicate)
        let oldRecords = try modelContext.fetch(descriptor)
        for record in oldRecords {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    /// 获取 ModelContainer (供 SwiftUI 使用)
    nonisolated var container: ModelContainer { modelContainer }
}
