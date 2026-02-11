import Foundation
import Observation
import SwiftData
import Logging

/// 全局应用状态
/// 协调数据管道: FSEvents → 增量读取 → 解析 → 计算成本 → 聚合
///
/// 启动策略:
/// 1. 从磁盘恢复聚合快照 + 文件 offset → 秒级启动
/// 2. 仅处理自上次关闭以来有变更的文件（增量）
/// 3. 定期持久化状态，保障下次启动速度
@Observable
final class AppState {
    private static let logger = Logger(label: "com.ccmonitor.AppState")

    let aggregator = UsageAggregator()
    let menuBarVM = MenuBarViewModel()
    let dashboardVM = DashboardViewModel()
    let settingsVM = SettingsViewModel()

    /// 加载进度状态
    var isLoadingHistory = true
    var loadingProgress: String = "Initializing..."

    private let pricingService = PricingService()
    private let fileReader = IncrementalFileReader()
    private var watcher: FSEventsWatcher?
    private var refreshTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?
    private var usageStore: UsageStore?

    /// 串行化文件处理队列，防止并发修改 aggregator 导致 crash
    private var fileChannel: AsyncStream<[String]>.Continuation?

    init() {
        startPipeline()
    }

    deinit {
        watcher?.stop()
        refreshTask?.cancel()
        saveTask?.cancel()
        processingTask?.cancel()
        fileChannel?.finish()
        // 退出时保存状态
        let reader = fileReader
        let agg = aggregator
        Task.detached {
            await reader.saveStates()
            AggregationCache.save(from: agg)
        }
    }

    /// 启动完整数据管道
    private func startPipeline() {
        Task { @MainActor in
            let startTime = CFAbsoluteTimeGetCurrent()
            Self.logger.info("🚀 Pipeline starting...")

            // 1. 加载定价
            await pricingService.loadPricing()
            let pricingCount = await pricingService.databaseCount
            Self.logger.info("💰 Pricing loaded: \(pricingCount) models")

            // 2. 初始化持久化
            usageStore = try? UsageStore()

            // 3. 恢复聚合快照（如有）
            let hasSnapshot = AggregationCache.load(into: aggregator)
            if hasSnapshot {
                updateViewModels()
                Self.logger.info("📸 Restored from snapshot — showing cached data immediately")
                loadingProgress = "Restored cached data, checking for updates..."
            }

            // 4. 发现所有项目目录
            let projectDirs = PathDiscovery.getProjectDirectories()
            Self.logger.info("📁 Project directories found: \(projectDirs)")
            guard !projectDirs.isEmpty else {
                Self.logger.warning("⚠️ No project directories found! Pipeline aborted.")
                isLoadingHistory = false
                loadingProgress = "No data directories found"
                return
            }

            // 5. 启动串行文件处理队列 + FSEvents 监控
            startFileProcessingQueue()
            startWatcher(paths: projectDirs)

            // 6. 启动定时刷新
            startPeriodicRefresh()

            // 7. 增量加载：只处理有变更的文件
            await loadIncrementalData(from: projectDirs, isFirstLoad: !hasSnapshot)

            isLoadingHistory = false
            updateViewModels()

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            Self.logger.info("✅ Pipeline ready in \(String(format: "%.1f", elapsed))s — totalRequests=\(aggregator.totalRequests), totalCost=$\(String(format: "%.2f", aggregator.totalCostUSD))")

            // 8. 保存状态
            await saveAllState()

            // 9. 启动定期保存
            startPeriodicSave()
        }
    }

    /// 增量加载数据：只处理新增或修改过的文件
    private func loadIncrementalData(from directories: [String], isFirstLoad: Bool) async {
        let fm = FileManager.default
        var processedCount = 0
        var skippedCount = 0
        var totalEntries = 0

        // 收集所有 JSONL 文件
        var allFiles: [String] = []
        for dir in directories {
            guard let enumerator = fm.enumerator(atPath: dir) else { continue }
            while let file = enumerator.nextObject() as? String {
                if file.hasSuffix(".jsonl") {
                    allFiles.append("\(dir)/\(file)")
                }
            }
        }

        Self.logger.info("📚 Found \(allFiles.count) JSONL files, checking for changes...")
        loadingProgress = "Scanning \(allFiles.count) files..."

        let batchSize = 200
        for fullPath in allFiles {
            // 检查文件是否需要处理
            let needsWork = await fileReader.needsProcessing(fullPath)
            guard needsWork else {
                skippedCount += 1
                continue
            }

            // 首次加载没有缓存时，从头开始读
            let hasCached = await fileReader.hasCachedState(for: fullPath)
            if isFirstLoad && !hasCached {
                await fileReader.initializeToStart(fullPath)
            }
            // 有缓存的文件，readNewLines 会自动从上次 offset 继续

            let before = aggregator.totalRequests
            await processFile(fullPath)
            let added = aggregator.totalRequests - before
            totalEntries += added
            processedCount += 1

            // 定期刷新 UI
            if processedCount % batchSize == 0 {
                updateViewModels()
                loadingProgress = "Processing: \(processedCount) changed files (\(skippedCount) cached, \(totalEntries) new entries)"
                Self.logger.info("📊 Progress: \(processedCount) processed, \(skippedCount) skipped, \(totalEntries) entries, cost=$\(String(format: "%.2f", aggregator.totalCostUSD))")
                await Task.yield()
            }
        }

        Self.logger.info("📚 Incremental load complete: \(processedCount) processed, \(skippedCount) skipped (cached), \(totalEntries) new entries")
        loadingProgress = processedCount == 0
            ? "All \(allFiles.count) files up to date"
            : "Processed \(processedCount) files, \(totalEntries) new entries"
    }

    /// 启动串行文件处理队列
    /// 所有对 aggregator 的写入都经过此队列，避免并发修改导致 crash
    private func startFileProcessingQueue() {
        let (stream, continuation) = AsyncStream<[String]>.makeStream()
        self.fileChannel = continuation

        processingTask = Task { @MainActor [weak self] in
            for await paths in stream {
                guard let self else { break }
                for path in paths {
                    await self.processFile(path)
                }
                self.updateViewModels()
            }
        }
    }

    /// 启动 FSEvents 监控
    private func startWatcher(paths: [String]) {
        watcher = FSEventsWatcher(paths: paths) { [weak self] changedPaths in
            guard let self else { return }
            Self.logger.debug("🔄 FSEvents: \(changedPaths.count) files changed")
            self.fileChannel?.yield(changedPaths)
        }
        watcher?.start()
        Self.logger.info("👁️ FSEvents watcher started for \(paths.count) directories")
    }

    /// 处理单个文件的新增数据
    private func processFile(_ filePath: String) async {
        let newLines = await fileReader.readNewLines(from: filePath)
        guard !newLines.isEmpty else { return }

        let entries = JSONLParser.parse(lines: newLines)
        guard !entries.isEmpty else { return }

        // 计算成本
        var costs: [Double] = []
        for entry in entries {
            let model = entry.message.model ?? "unknown"
            let pricing = await pricingService.getPricing(for: model)
            let cost = CostCalculator.calculateCost(entry: entry, pricing: pricing)
            costs.append(cost)
        }

        // 聚合
        aggregator.process(entries: entries, costs: costs, filePath: filePath)
    }

    /// 定时刷新 ViewModel
    private func startPeriodicRefresh() {
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Constants.defaultRefreshIntervalSeconds))
                self?.updateViewModels()
                self?.aggregator.pruneOldData()
            }
        }
    }

    /// 定期保存状态到磁盘（每 5 分钟）
    private func startPeriodicSave() {
        saveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await self?.saveAllState()
                Self.logger.debug("💾 Periodic state save completed")
            }
        }
    }

    /// 保存所有状态到磁盘
    private func saveAllState() async {
        await fileReader.saveStates()
        AggregationCache.save(from: aggregator)
    }

    /// 更新所有 ViewModel
    private func updateViewModels() {
        menuBarVM.update(from: aggregator)
        dashboardVM.update(from: aggregator)
    }
}
