import Foundation
import Observation

/// 菜单栏 ViewModel
@Observable
final class MenuBarViewModel {
    var todayCost: Double = 0
    var todayInputTokens: Int = 0
    var todayOutputTokens: Int = 0
    var todayCacheReadTokens: Int = 0
    var todayCacheCreationTokens: Int = 0
    var activeSessions: Int = 0
    var burnRate: BurnRateCalculator.BurnRate = .zero
    var topModel: String = "N/A"

    /// token 分类展示文本 (e.g., "I:2.1M O:0.8M C:95.2M")
    var todayTokenBreakdown: String {
        Formatters.formatTokenBreakdown(
            input: todayInputTokens,
            output: todayOutputTokens,
            cacheRead: todayCacheReadTokens,
            cacheCreation: todayCacheCreationTokens
        )
    }

    /// 根据 displayMode 生成菜单栏标题
    func menuBarTitle(mode: SettingsViewModel.MenuBarDisplayMode) -> String {
        switch mode {
        case .costOnly:
            return Formatters.formatCostShort(todayCost)
        case .costAndTokens:
            return "\(Formatters.formatCostShort(todayCost)) · \(todayTokenBreakdown)"
        case .iconOnly:
            return ""
        }
    }

    /// 更新数据
    func update(from aggregator: UsageAggregator) {
        let today = aggregator.todayUsage
        todayCost = today.totalCostUSD
        todayInputTokens = today.inputTokens
        todayOutputTokens = today.outputTokens
        todayCacheReadTokens = today.cacheReadTokens
        todayCacheCreationTokens = today.cacheCreationTokens
        activeSessions = aggregator.activeSessionCount
        burnRate = BurnRateCalculator.calculate(minuteUsage: aggregator.minuteUsage)

        // 找到使用最多的模型
        if let top = aggregator.modelUsage.max(by: { $0.value.requestCount < $1.value.requestCount }) {
            topModel = top.key
        }
    }
}
