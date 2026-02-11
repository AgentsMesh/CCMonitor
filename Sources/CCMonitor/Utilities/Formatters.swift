import Foundation

enum Formatters {
    // MARK: - Token 格式化

    /// 格式化 token 数量 (e.g., 1.2K, 3.5M)
    static func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    /// 格式化 token 数量（菜单栏紧凑格式，e.g., "1.2M", "350K"）
    static func formatTokenCountShort(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    /// 格式化 token 分类展示 (e.g., "I:2.1M O:0.8M C:95.2M")
    static func formatTokenBreakdown(input: Int, output: Int, cacheRead: Int, cacheCreation: Int = 0) -> String {
        let cache = cacheRead + cacheCreation
        var parts = [
            "I:\(formatTokenCountShort(input))",
            "O:\(formatTokenCountShort(output))"
        ]
        if cache > 0 {
            parts.append("C:\(formatTokenCountShort(cache))")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - 金额格式化

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 4
        return f
    }()

    /// 格式化 USD 金额
    static func formatCost(_ cost: Double) -> String {
        if cost < 0.01 && cost > 0 {
            return String(format: "$%.4f", cost)
        }
        return currencyFormatter.string(from: NSNumber(value: cost)) ?? String(format: "$%.2f", cost)
    }

    /// 格式化简短金额 (用于菜单栏)
    static func formatCostShort(_ cost: Double) -> String {
        if cost >= 100 {
            return String(format: "$%.0f", cost)
        } else if cost >= 10 {
            return String(format: "$%.1f", cost)
        } else if cost >= 0.01 {
            return String(format: "$%.2f", cost)
        }
        return String(format: "$%.3f", cost)
    }

    // MARK: - 日期格式化

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func formatDateTime(_ date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }

    // MARK: - 速率格式化

    /// 格式化 burn rate (e.g., "$1.23/hr")
    static func formatBurnRate(_ costPerHour: Double) -> String {
        "\(formatCostShort(costPerHour))/hr"
    }

    /// 格式化 token 速率 (e.g., "1.2K tok/min")
    static func formatTokenRate(_ tokensPerMinute: Double) -> String {
        "\(formatTokenCount(Int(tokensPerMinute))) tok/min"
    }
}
