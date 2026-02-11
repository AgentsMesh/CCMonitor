import Foundation
import Logging

/// 文件处理状态记录
struct FileProcessState: Codable, Sendable {
    /// 已读取的字节偏移量
    var offset: UInt64
    /// 文件最后修改时间 (Unix timestamp)
    var lastModified: TimeInterval
    /// 上次处理时间 (Unix timestamp)
    var lastProcessed: TimeInterval
    /// 文件大小 (用于检测截断)
    var fileSize: UInt64
}

/// 增量文件读取器
/// 每个文件维护 byte offset + 修改时间，仅读取新增内容
/// 支持状态持久化到磁盘，重启后从断点继续
actor IncrementalFileReader {
    private static let logger = Logger(label: "com.ccmonitor.IncrementalFileReader")

    /// 文件路径 -> 处理状态
    private var states: [String: FileProcessState] = [:]

    /// 缓存文件路径
    private let cacheURL: URL = {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.ccmonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir.appendingPathComponent("file_states.json")
    }()

    init() {
        // 同步加载缓存（在 actor 初始化时直接操作 states）
        if FileManager.default.fileExists(atPath: cacheURL.path),
           let data = try? Data(contentsOf: cacheURL),
           let loaded = try? JSONDecoder().decode([String: FileProcessState].self, from: data) {
            let filtered = loaded.filter { FileManager.default.fileExists(atPath: $0.key) }
            states = filtered
            Self.logger.info("Loaded \(filtered.count) cached file states")
        } else {
            Self.logger.info("No cached file states found, starting fresh")
        }
    }

    /// 读取文件从上次 offset 到当前末尾的新增行
    func readNewLines(from filePath: String) -> [String] {
        let currentOffset = states[filePath]?.offset ?? 0

        guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            return []
        }
        defer { try? fileHandle.close() }

        let fileSize: UInt64
        do {
            fileSize = try fileHandle.seekToEnd()
        } catch {
            return []
        }

        // 文件没有新内容
        guard fileSize > currentOffset else {
            // 文件被截断/重写，重置 offset
            if fileSize < currentOffset {
                states[filePath]?.offset = 0
                states[filePath]?.fileSize = fileSize
                return readNewLines(from: filePath)
            }
            return []
        }

        do {
            try fileHandle.seek(toOffset: currentOffset)
        } catch {
            return []
        }

        let newData = fileHandle.readDataToEndOfFile()
        guard !newData.isEmpty else { return [] }

        // 获取文件修改时间
        let modTime = getFileModificationTime(filePath)
        let now = Date().timeIntervalSince1970

        // 更新状态
        states[filePath] = FileProcessState(
            offset: currentOffset + UInt64(newData.count),
            lastModified: modTime,
            lastProcessed: now,
            fileSize: fileSize
        )

        guard let text = String(data: newData, encoding: .utf8) else { return [] }

        let lines = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        return lines
    }

    /// 初始化文件 offset 到当前文件末尾（跳过历史数据）
    func initializeToEnd(_ filePath: String) {
        guard let fileHandle = FileHandle(forReadingAtPath: filePath) else { return }
        defer { try? fileHandle.close() }

        if let endOffset = try? fileHandle.seekToEnd() {
            let modTime = getFileModificationTime(filePath)
            states[filePath] = FileProcessState(
                offset: endOffset,
                lastModified: modTime,
                lastProcessed: Date().timeIntervalSince1970,
                fileSize: endOffset
            )
        }
    }

    /// 初始化文件 offset 到开头（读取全部历史数据）
    func initializeToStart(_ filePath: String) {
        let modTime = getFileModificationTime(filePath)
        states[filePath] = FileProcessState(
            offset: 0,
            lastModified: modTime,
            lastProcessed: 0,
            fileSize: 0
        )
    }

    /// 检查文件是否需要处理（新文件或被修改过的文件）
    func needsProcessing(_ filePath: String) -> Bool {
        guard let state = states[filePath] else {
            return true // 新文件
        }

        // 检查文件是否在上次处理后被修改
        let currentModTime = getFileModificationTime(filePath)
        if currentModTime > state.lastProcessed {
            return true
        }

        // 检查文件大小是否变化
        if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
           let size = attrs[.size] as? UInt64,
           size != state.fileSize {
            return true
        }

        return false
    }

    /// 检查文件是否已有缓存状态（即已处理过）
    func hasCachedState(for filePath: String) -> Bool {
        states[filePath] != nil
    }

    /// 获取指定文件的当前 offset
    func getOffset(for filePath: String) -> UInt64? {
        states[filePath]?.offset
    }

    /// 获取指定文件的处理状态
    func getState(for filePath: String) -> FileProcessState? {
        states[filePath]
    }

    /// 重置指定文件的状态
    func reset(_ filePath: String) {
        states.removeValue(forKey: filePath)
    }

    /// 重置所有状态
    func resetAll() {
        states.removeAll()
    }

    /// 获取当前追踪的文件数量
    var trackedFileCount: Int {
        states.count
    }

    // MARK: - 状态持久化

    /// 保存状态到磁盘
    func saveStates() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(states)
            try data.write(to: cacheURL, options: .atomic)
            Self.logger.debug("Saved \(states.count) file states to cache")
        } catch {
            Self.logger.warning("Failed to save states: \(error.localizedDescription)")
        }
    }

    /// 从磁盘加载状态
    private func loadStates() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            Self.logger.info("No cached file states found, starting fresh")
            return
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            states = try JSONDecoder().decode([String: FileProcessState].self, from: data)
            // 清理已不存在的文件
            let before = states.count
            states = states.filter { FileManager.default.fileExists(atPath: $0.key) }
            let removed = before - states.count
            if removed > 0 {
                Self.logger.info("Pruned \(removed) stale entries from cache")
            }
            Self.logger.info("Loaded \(states.count) cached file states")
        } catch {
            Self.logger.warning("Failed to load cached states: \(error.localizedDescription)")
            states = [:]
        }
    }

    /// 清除持久化缓存
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheURL)
        states.removeAll()
        Self.logger.info("Cleared state cache")
    }

    // MARK: - Private

    private func getFileModificationTime(_ path: String) -> TimeInterval {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modDate = attrs[.modificationDate] as? Date else {
            return 0
        }
        return modDate.timeIntervalSince1970
    }
}
