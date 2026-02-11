import Foundation
import Logging

enum PathDiscovery {
    private static let logger = Logger(label: "com.ccmonitor.PathDiscovery")
    /// 发现所有 Claude 数据目录路径
    /// 对照 ccusage 的 getClaudePaths()
    static func getClaudePaths() -> [String] {
        // 优先级1: 环境变量
        let envValue = ProcessInfo.processInfo.environment[Constants.claudeConfigDirEnv]?.trimmingCharacters(in: .whitespaces) ?? ""

        if !envValue.isEmpty {
            let paths = envValue
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { ($0 as NSString).expandingTildeInPath }
                .map { URL(fileURLWithPath: $0).standardized.path }

            let validPaths = paths.filter { path in
                isValidClaudeDirectory(path)
            }

            return Array(Set(validPaths))
        }

        // 优先级2: 默认路径
        let defaultPaths = [
            Constants.defaultClaudeConfigPath,
            "\(Constants.userHomeDir)/\(Constants.defaultClaudeCodePath)",
        ]

        logger.info("Checking default paths: \(defaultPaths)")

        let standardized = defaultPaths.map { URL(fileURLWithPath: $0).standardized.path }
        for path in standardized {
            let valid = isValidClaudeDirectory(path)
            logger.info("  Path '\(path)' valid=\(valid)")
        }

        let validPaths = standardized.filter { isValidClaudeDirectory($0) }

        return Array(Set(validPaths))
    }

    /// 获取所有 projects 目录路径
    static func getProjectDirectories() -> [String] {
        getClaudePaths().map { "\($0)/\(Constants.claudeProjectsDirName)" }
    }

    /// 验证目录是否为有效的 Claude 配置目录
    private static func isValidClaudeDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }

        let projectsPath = "\(path)/\(Constants.claudeProjectsDirName)"
        return FileManager.default.fileExists(atPath: projectsPath, isDirectory: &isDir) && isDir.boolValue
    }
}
