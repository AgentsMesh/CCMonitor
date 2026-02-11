import Foundation

enum Constants {
    // MARK: - Claude 数据路径

    static let userHomeDir = FileManager.default.homeDirectoryForCurrentUser.path
    static let defaultClaudeCodePath = ".claude"
    static let defaultClaudeConfigPath: String = {
        if let xdgConfig = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            return "\(xdgConfig)/claude"
        }
        return "\(FileManager.default.homeDirectoryForCurrentUser.path)/.config/claude"
    }()
    static let claudeConfigDirEnv = "CLAUDE_CONFIG_DIR"
    static let claudeProjectsDirName = "projects"
    static let usageDataGlobPattern = "**/*.jsonl"

    // MARK: - 定价

    static let defaultTieredThreshold: Int = 200_000
    static let liteLLMPricingURL = "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"
    static let pricingCacheFileName = "ccmonitor_pricing_cache.json"
    static let pricingCacheDuration: TimeInterval = 24 * 60 * 60 // 24 hours

    // MARK: - Session

    static let defaultSessionDurationHours: Double = 5.0

    // MARK: - 监控

    static let fsEventsLatency: Double = 0.5 // seconds

    // MARK: - 预算告警

    static let blocksWarningThreshold: Double = 0.8

    // MARK: - UI

    static let dashboardDefaultWidth: CGFloat = 1200
    static let dashboardDefaultHeight: CGFloat = 800

    // MARK: - 默认 Provider 前缀 (用于模型名匹配)

    static let defaultProviderPrefixes = [
        "anthropic/",
        "claude-3-5-",
        "claude-3-",
        "claude-",
        "openai/",
        "azure/",
        "openrouter/openai/",
    ]

    // MARK: - 刷新间隔

    static let defaultRefreshIntervalSeconds: Double = 1.0

    // MARK: - 聚合

    static let burnRateWindowMinutes: Int = 30
}
