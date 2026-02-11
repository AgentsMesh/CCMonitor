import Foundation

/// LiteLLM 模型定价数据
/// 对照 pricing.ts:31-47
struct ModelPricing: Codable, Sendable {
    let input_cost_per_token: Double?
    let output_cost_per_token: Double?
    let cache_creation_input_token_cost: Double?
    let cache_read_input_token_cost: Double?
    let max_tokens: Int?
    let max_input_tokens: Int?
    let max_output_tokens: Int?

    // 200k 阈值分层定价
    let input_cost_per_token_above_200k_tokens: Double?
    let output_cost_per_token_above_200k_tokens: Double?
    let cache_creation_input_token_cost_above_200k_tokens: Double?
    let cache_read_input_token_cost_above_200k_tokens: Double?
}

/// 定价数据库 (模型名 -> 定价)
typealias PricingDatabase = [String: ModelPricing]
