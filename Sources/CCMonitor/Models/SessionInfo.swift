import Foundation

/// Session 状态
enum SessionStatus: String, Sendable {
    case active
    case idle
    case dead
}

/// Session 信息
struct SessionInfo: Identifiable, Sendable {
    let id: String // sessionId
    var status: SessionStatus
    var lastActivity: Date
    var projectPath: String?
    var totalTokens: Int
    var totalCostUSD: Double
    var modelName: String?
    var entryCount: Int

    /// 判断 session 是否活跃
    /// 基于 _session-blocks.ts 的逻辑: now - lastActivity < sessionDuration
    mutating func updateStatus(sessionDurationHours: Double = Constants.defaultSessionDurationHours) {
        let elapsed = Date().timeIntervalSince(lastActivity)
        let threshold = sessionDurationHours * 3600

        if elapsed < 300 { // 5 分钟内有活动 = active
            status = .active
        } else if elapsed < threshold {
            status = .idle
        } else {
            status = .dead
        }
    }
}
