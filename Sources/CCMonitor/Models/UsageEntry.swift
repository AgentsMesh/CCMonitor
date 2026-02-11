import Foundation

/// JSONL 中单条 usage 数据
/// 对照 ccusage data-loader.ts:167-192 的 usageDataSchema
struct UsageEntry: Codable, Sendable, Identifiable {
    var id: String { uniqueHash ?? UUID().uuidString }

    let cwd: String?
    let sessionId: String?
    let timestamp: String // ISO 8601
    let version: String?
    let message: Message
    let costUSD: Double?
    let requestId: String?
    let isApiErrorMessage: Bool?

    struct Message: Codable, Sendable {
        let usage: Usage?
        let model: String?
        let id: String?
        let content: [ContentBlock]?

        struct Usage: Codable, Sendable {
            let input_tokens: Int
            let output_tokens: Int
            let cache_creation_input_tokens: Int?
            let cache_read_input_tokens: Int?
        }

        struct ContentBlock: Codable, Sendable {
            let text: String?
        }
    }

    // MARK: - 去重

    /// 生成唯一哈希 (messageId:requestId)
    /// 对照 data-loader.ts:521-531 的 createUniqueHash()
    var uniqueHash: String? {
        guard let messageId = message.id, let requestId = requestId else {
            return nil
        }
        return "\(messageId):\(requestId)"
    }

    /// 解析 ISO 时间戳
    var parsedTimestamp: Date? {
        ISO8601DateFormatter().date(from: timestamp)
            ?? Formatters.fallbackISO8601(timestamp)
    }

    /// 总 token 数 (input + output，不含 cache)
    /// cache_read 是从缓存读取的已有 prompt，单价极低（base 的 1/10），
    /// 计入 totalTokens 会严重膨胀展示数量，与实际成本不匹配
    var totalTokens: Int {
        guard let usage = message.usage else { return 0 }
        return usage.input_tokens + usage.output_tokens
    }
}

// Formatter 扩展: 备用 ISO8601 解析
extension Formatters {
    static func fallbackISO8601(_ str: String) -> Date? {
        let f = DateFormatter()
        // 带毫秒的 ISO 格式
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        if let d = f.date(from: str) { return d }
        // 不带毫秒
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f.date(from: str)
    }
}
