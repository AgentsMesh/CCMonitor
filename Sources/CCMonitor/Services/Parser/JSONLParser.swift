import Foundation
import Logging

/// JSONL 解析器
/// 逐行解析 Claude Code 的 usage JSONL 数据
enum JSONLParser {
    private static let logger = Logger(label: "com.ccmonitor.JSONLParser")

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    /// 从原始行解析 UsageEntry
    /// 静默跳过无效行（格式错误、缺少 usage 等）
    static func parse(lines: [String]) -> [UsageEntry] {
        var results: [UsageEntry] = []
        var skippedNoUsageKeyword = 0
        var skippedDecodeError = 0
        var skippedNoUsageField = 0
        var skippedApiError = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let data = trimmed.data(using: .utf8) else { continue }

            // 快速预过滤: 必须包含 "usage" 字段
            guard trimmed.contains("\"usage\"") else {
                skippedNoUsageKeyword += 1
                continue
            }

            do {
                let entry = try decoder.decode(UsageEntry.self, from: data)

                // 验证必须包含 usage 数据
                guard entry.message.usage != nil else {
                    skippedNoUsageField += 1
                    continue
                }

                // 跳过 API 错误消息
                if entry.isApiErrorMessage == true {
                    skippedApiError += 1
                    continue
                }

                results.append(entry)
            } catch {
                skippedDecodeError += 1
                // 输出前几个解码错误的详细信息
                if skippedDecodeError <= 3 {
                    let preview = String(trimmed.prefix(300))
                    logger.debug("Decode error: \(error.localizedDescription)")
                    logger.debug("  Line preview: \(preview)")
                }
            }
        }

        if skippedDecodeError > 0 || skippedNoUsageKeyword > 0 {
            logger.debug("Parse stats: \(results.count) parsed, \(skippedNoUsageKeyword) no-usage-keyword, \(skippedDecodeError) decode-errors, \(skippedNoUsageField) no-usage-field, \(skippedApiError) api-errors")
        }

        return results
    }

    /// 解析单行 JSONL
    static func parseLine(_ line: String) -> UsageEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let data = trimmed.data(using: .utf8) else { return nil }

        // 快速预过滤: 必须包含 "usage" 字段
        guard trimmed.contains("\"usage\"") else { return nil }

        do {
            let entry = try decoder.decode(UsageEntry.self, from: data)

            // 验证必须包含 usage 数据
            guard entry.message.usage != nil else { return nil }

            // 跳过 API 错误消息
            if entry.isApiErrorMessage == true { return nil }

            return entry
        } catch {
            // 静默跳过解析失败的行
            return nil
        }
    }

    /// 从 JSONL 文件内容批量解析
    static func parseFileContent(_ content: String) -> [UsageEntry] {
        let lines = content.components(separatedBy: .newlines)
        return parse(lines: lines)
    }
}
