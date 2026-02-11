import Foundation

/// FSEvents 文件系统监控
/// 递归监控指定目录下的 .jsonl 文件变更
final class FSEventsWatcher: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private let paths: [String]
    private let latency: Double
    private let callback: @Sendable ([String]) -> Void

    /// 初始化 FSEvents 监控器
    /// - Parameters:
    ///   - paths: 要监控的目录路径列表
    ///   - latency: 事件合并延迟（秒）
    ///   - callback: 文件变更回调，参数为变更的文件路径列表
    init(paths: [String], latency: Double = Constants.fsEventsLatency, callback: @escaping @Sendable ([String]) -> Void) {
        self.paths = paths
        self.latency = latency
        self.callback = callback
    }

    deinit {
        stop()
    }

    func start() {
        guard stream == nil else { return }

        let cfPaths = paths as CFArray

        var context = FSEventStreamContext()
        context.info = Unmanaged.passRetained(CallbackBox(callback)).toOpaque()

        let flags: FSEventStreamCreateFlags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            cfPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else {
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}

// MARK: - 回调封装

private final class CallbackBox: @unchecked Sendable {
    let callback: @Sendable ([String]) -> Void
    init(_ callback: @escaping @Sendable ([String]) -> Void) {
        self.callback = callback
    }
}

private func fsEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let box = Unmanaged<CallbackBox>.fromOpaque(info).takeUnretainedValue()

    guard let cfArray = unsafeBitCast(eventPaths, to: CFArray.self) as? [String] else { return }

    // 仅关注 .jsonl 文件的修改事件
    let jsonlPaths = cfArray.filter { $0.hasSuffix(".jsonl") }

    if !jsonlPaths.isEmpty {
        box.callback(jsonlPaths)
    }
}
