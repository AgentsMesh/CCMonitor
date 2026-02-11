import Testing
import Foundation
@testable import CCMonitor

@Suite("UsageAggregator Tests")
struct UsageAggregatorTests {
    @Test("Aggregate single entry")
    func testSingleEntry() {
        let aggregator = UsageAggregator()
        let line = """
        {"timestamp":"\(ISO8601DateFormatter().string(from: Date()))","message":{"usage":{"input_tokens":1000,"output_tokens":500},"model":"claude-sonnet-4-20250514","id":"msg_1"},"requestId":"req_1","sessionId":"sess_1"}
        """

        let entry = JSONLParser.parseLine(line)!
        aggregator.process(entries: [entry], costs: [0.01], filePath: "/test/projects/myproject/session.jsonl")

        #expect(aggregator.totalRequests == 1)
        #expect(aggregator.totalTokens == 1500)
        #expect(abs(aggregator.totalCostUSD - 0.01) < 1e-10)
    }

    @Test("Deduplication by hash")
    func testDeduplication() {
        let aggregator = UsageAggregator()
        let line = """
        {"timestamp":"\(ISO8601DateFormatter().string(from: Date()))","message":{"usage":{"input_tokens":1000,"output_tokens":500},"model":"claude-sonnet-4-20250514","id":"msg_dup"},"requestId":"req_dup"}
        """

        let entry = JSONLParser.parseLine(line)!
        // 处理两次相同条目
        aggregator.process(entries: [entry], costs: [0.01], filePath: "/test/session.jsonl")
        aggregator.process(entries: [entry], costs: [0.01], filePath: "/test/session.jsonl")

        // 应该只计一次
        #expect(aggregator.totalRequests == 1)
    }

    @Test("Multiple models tracked")
    func testMultipleModels() {
        let aggregator = UsageAggregator()
        let now = ISO8601DateFormatter().string(from: Date())

        let line1 = """
        {"timestamp":"\(now)","message":{"usage":{"input_tokens":100,"output_tokens":50},"model":"claude-sonnet-4-20250514","id":"msg_a"},"requestId":"req_a"}
        """
        let line2 = """
        {"timestamp":"\(now)","message":{"usage":{"input_tokens":200,"output_tokens":100},"model":"claude-3-5-haiku-20241022","id":"msg_b"},"requestId":"req_b"}
        """

        let entry1 = JSONLParser.parseLine(line1)!
        let entry2 = JSONLParser.parseLine(line2)!

        aggregator.process(entries: [entry1, entry2], costs: [0.01, 0.005], filePath: "/test/session.jsonl")

        #expect(aggregator.modelUsage.count == 2)
        #expect(aggregator.modelUsage["claude-sonnet-4-20250514"] != nil)
        #expect(aggregator.modelUsage["claude-3-5-haiku-20241022"] != nil)
    }

    @Test("Session tracking")
    func testSessionTracking() {
        let aggregator = UsageAggregator()
        let now = ISO8601DateFormatter().string(from: Date())

        let line = """
        {"timestamp":"\(now)","message":{"usage":{"input_tokens":100,"output_tokens":50},"model":"claude-sonnet-4-20250514","id":"msg_s"},"requestId":"req_s","sessionId":"session_123"}
        """

        let entry = JSONLParser.parseLine(line)!
        aggregator.process(entries: [entry], costs: [0.01], filePath: "/test/session.jsonl")

        #expect(aggregator.sessions["session_123"] != nil)
        #expect(aggregator.sessions["session_123"]?.status == .active)
    }

    @Test("Reset clears all data")
    func testReset() {
        let aggregator = UsageAggregator()
        let line = """
        {"timestamp":"\(ISO8601DateFormatter().string(from: Date()))","message":{"usage":{"input_tokens":100,"output_tokens":50},"model":"test","id":"msg_r"},"requestId":"req_r"}
        """

        let entry = JSONLParser.parseLine(line)!
        aggregator.process(entries: [entry], costs: [0.01], filePath: "/test/session.jsonl")

        aggregator.reset()

        #expect(aggregator.totalRequests == 0)
        #expect(aggregator.totalCostUSD == 0)
        #expect(aggregator.sessions.isEmpty)
    }
}
