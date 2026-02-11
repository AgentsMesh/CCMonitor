import Testing
@testable import CCMonitor

@Suite("CostCalculator Tests")
struct CostCalculatorTests {
    // Claude Sonnet 4 pricing
    let sonnetPricing = ModelPricing(
        input_cost_per_token: 3e-06,
        output_cost_per_token: 1.5e-05,
        cache_creation_input_token_cost: 3.75e-06,
        cache_read_input_token_cost: 3e-07,
        max_tokens: 64000,
        max_input_tokens: 1000000,
        max_output_tokens: 64000,
        input_cost_per_token_above_200k_tokens: 6e-06,
        output_cost_per_token_above_200k_tokens: 2.25e-05,
        cache_creation_input_token_cost_above_200k_tokens: 7.5e-06,
        cache_read_input_token_cost_above_200k_tokens: 6e-07
    )

    @Test("Zero tokens should cost zero")
    func testZeroTokens() {
        let cost = CostCalculator.calculateCostFromPricing(
            inputTokens: 0, outputTokens: 0,
            cacheCreationTokens: 0, cacheReadTokens: 0,
            pricing: sonnetPricing
        )
        #expect(cost == 0)
    }

    @Test("Below threshold uses base pricing")
    func testBelowThreshold() {
        let cost = CostCalculator.calculateCostFromPricing(
            inputTokens: 1000, outputTokens: 500,
            cacheCreationTokens: 0, cacheReadTokens: 0,
            pricing: sonnetPricing
        )

        let expected = 1000 * 3e-06 + 500 * 1.5e-05
        #expect(abs(cost - expected) < 1e-10)
    }

    @Test("At exactly threshold uses base pricing")
    func testAtThreshold() {
        let cost = CostCalculator.calculateCostFromPricing(
            inputTokens: 200_000, outputTokens: 0,
            cacheCreationTokens: 0, cacheReadTokens: 0,
            pricing: sonnetPricing
        )

        let expected = 200_000 * 3e-06
        #expect(abs(cost - expected) < 1e-10)
    }

    @Test("Above threshold uses tiered pricing")
    func testAboveThreshold() {
        let cost = CostCalculator.calculateCostFromPricing(
            inputTokens: 300_000, outputTokens: 0,
            cacheCreationTokens: 0, cacheReadTokens: 0,
            pricing: sonnetPricing
        )

        // 200k * base + 100k * tiered
        let expected = 200_000 * 3e-06 + 100_000 * 6e-06
        #expect(abs(cost - expected) < 1e-10)
    }

    @Test("All four token types calculated correctly")
    func testAllTokenTypes() {
        let cost = CostCalculator.calculateCostFromPricing(
            inputTokens: 10_000, outputTokens: 5_000,
            cacheCreationTokens: 3_000, cacheReadTokens: 50_000,
            pricing: sonnetPricing
        )

        let expected = 10_000 * 3e-06 + 5_000 * 1.5e-05 + 3_000 * 3.75e-06 + 50_000 * 3e-07
        #expect(abs(cost - expected) < 1e-10)
    }

    @Test("CostUSD field takes priority")
    func testCostUSDPriority() {
        let line = """
        {"timestamp":"2024-01-15T10:30:00Z","message":{"usage":{"input_tokens":1000,"output_tokens":500},"model":"claude-sonnet-4-20250514"},"costUSD":0.42}
        """
        let entry = JSONLParser.parseLine(line)!
        let cost = CostCalculator.calculateCost(entry: entry, pricing: sonnetPricing)
        #expect(cost == 0.42)
    }

    @Test("No pricing returns zero")
    func testNoPricing() {
        let line = """
        {"timestamp":"2024-01-15T10:30:00Z","message":{"usage":{"input_tokens":1000,"output_tokens":500},"model":"unknown-model"}}
        """
        let entry = JSONLParser.parseLine(line)!
        let cost = CostCalculator.calculateCost(entry: entry, pricing: nil)
        #expect(cost == 0)
    }
}
