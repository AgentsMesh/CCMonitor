import Foundation

/// 成本计算器
/// 分层定价算法，对照 pricing.ts:261-337 的 calculateCostFromPricing()
enum CostCalculator {
    /// 计算单条 UsageEntry 的成本
    /// - Parameters:
    ///   - entry: usage 数据
    ///   - pricing: 模型定价信息
    /// - Returns: 计算出的 USD 成本
    static func calculateCost(entry: UsageEntry, pricing: ModelPricing?) -> Double {
        // 优先使用条目自带的 costUSD（如果有）
        if let costUSD = entry.costUSD {
            return costUSD
        }

        guard let usage = entry.message.usage, let pricing = pricing else {
            return 0
        }

        return calculateCostFromPricing(
            inputTokens: usage.input_tokens,
            outputTokens: usage.output_tokens,
            cacheCreationTokens: usage.cache_creation_input_tokens ?? 0,
            cacheReadTokens: usage.cache_read_input_tokens ?? 0,
            pricing: pricing
        )
    }

    /// 从 token 数量和定价信息计算成本
    /// 实现 200k 分层定价算法
    static func calculateCostFromPricing(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        pricing: ModelPricing,
        threshold: Int = Constants.defaultTieredThreshold
    ) -> Double {
        let inputCost = calculateTieredCost(
            totalTokens: inputTokens,
            basePrice: pricing.input_cost_per_token,
            tieredPrice: pricing.input_cost_per_token_above_200k_tokens,
            threshold: threshold
        )

        let outputCost = calculateTieredCost(
            totalTokens: outputTokens,
            basePrice: pricing.output_cost_per_token,
            tieredPrice: pricing.output_cost_per_token_above_200k_tokens,
            threshold: threshold
        )

        let cacheCreationCost = calculateTieredCost(
            totalTokens: cacheCreationTokens,
            basePrice: pricing.cache_creation_input_token_cost,
            tieredPrice: pricing.cache_creation_input_token_cost_above_200k_tokens,
            threshold: threshold
        )

        let cacheReadCost = calculateTieredCost(
            totalTokens: cacheReadTokens,
            basePrice: pricing.cache_read_input_token_cost,
            tieredPrice: pricing.cache_read_input_token_cost_above_200k_tokens,
            threshold: threshold
        )

        return inputCost + outputCost + cacheCreationCost + cacheReadCost
    }

    /// 分层定价计算
    /// 对照 pricing.ts 中的 calculateTieredCost
    /// - Parameters:
    ///   - totalTokens: 总 token 数
    ///   - basePrice: 基础单价 (per token)
    ///   - tieredPrice: 超过阈值后的单价 (per token)
    ///   - threshold: 分层阈值 (默认 200,000)
    private static func calculateTieredCost(
        totalTokens: Int,
        basePrice: Double?,
        tieredPrice: Double?,
        threshold: Int
    ) -> Double {
        guard totalTokens > 0 else { return 0 }

        let tokens = Double(totalTokens)
        let thresh = Double(threshold)

        // 超过阈值且存在分层价格
        if tokens > thresh, let tieredPrice = tieredPrice {
            let tokensBelowThreshold = min(tokens, thresh)
            let tokensAboveThreshold = max(0, tokens - thresh)
            var cost = tokensAboveThreshold * tieredPrice
            if let basePrice = basePrice {
                cost += tokensBelowThreshold * basePrice
            }
            return cost
        }

        // 未超过阈值或无分层价格，使用基础价
        if let basePrice = basePrice {
            return tokens * basePrice
        }

        return 0
    }
}
