import Foundation

/// 项目维度统计
struct ProjectInfo: Identifiable, Sendable {
    var id: String { projectPath }

    let projectPath: String
    var displayName: String
    var totalTokens: Int
    var totalCostUSD: Double
    var requestCount: Int
    var lastActivity: Date
    var activeSessions: Int
    var models: Set<String>

    /// 从完整项目路径提取显示名
    static func extractDisplayName(from path: String) -> String {
        // 路径格式: ~/.claude/projects/{encoded_path}/{session}.jsonl
        // 从 encoded path 中提取项目名
        let components = path.split(separator: "/")
        // 找到 "projects" 后面的那段作为项目标识
        if let projectsIdx = components.firstIndex(of: "projects"),
           projectsIdx + 1 < components.count {
            let encodedPath = String(components[projectsIdx + 1])
            // 解码路径: 将 URL encoding 或连字符编码还原
            return encodedPath
                .replacingOccurrences(of: "-", with: "/")
                .removingPercentEncoding ?? encodedPath
        }
        return (path as NSString).lastPathComponent
    }
}
