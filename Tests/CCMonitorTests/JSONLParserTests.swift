import Testing
@testable import CCMonitor

@Suite("JSONLParser Tests")
struct JSONLParserTests {
    @Test("Parse valid usage line")
    func testParseValidLine() {
        let line = """
        {"timestamp":"2024-01-15T10:30:00Z","message":{"usage":{"input_tokens":1000,"output_tokens":500,"cache_creation_input_tokens":200,"cache_read_input_tokens":100},"model":"claude-sonnet-4-20250514","id":"msg_123"},"requestId":"req_456","sessionId":"sess_789"}
        """

        let result = JSONLParser.parseLine(line)
        #expect(result != nil)
        #expect(result?.message.usage?.input_tokens == 1000)
        #expect(result?.message.usage?.output_tokens == 500)
        #expect(result?.message.usage?.cache_creation_input_tokens == 200)
        #expect(result?.message.usage?.cache_read_input_tokens == 100)
        #expect(result?.message.model == "claude-sonnet-4-20250514")
        #expect(result?.uniqueHash == "msg_123:req_456")
    }

    @Test("Skip line without usage field")
    func testSkipNoUsage() {
        let line = """
        {"timestamp":"2024-01-15T10:30:00Z","message":{"content":[{"text":"Hello"}]},"type":"user"}
        """
        let result = JSONLParser.parseLine(line)
        #expect(result == nil)
    }

    @Test("Skip API error message")
    func testSkipApiError() {
        let line = """
        {"timestamp":"2024-01-15T10:30:00Z","message":{"usage":{"input_tokens":100,"output_tokens":50}},"isApiErrorMessage":true}
        """
        let result = JSONLParser.parseLine(line)
        #expect(result == nil)
    }

    @Test("Skip invalid JSON")
    func testSkipInvalidJSON() {
        let result = JSONLParser.parseLine("not valid json {{{")
        #expect(result == nil)
    }

    @Test("Skip empty line")
    func testSkipEmptyLine() {
        #expect(JSONLParser.parseLine("") == nil)
        #expect(JSONLParser.parseLine("   ") == nil)
    }

    @Test("Parse multiple lines")
    func testParseMultipleLines() {
        let lines = [
            """
            {"timestamp":"2024-01-15T10:30:00Z","message":{"usage":{"input_tokens":1000,"output_tokens":500},"model":"claude-sonnet-4-20250514","id":"msg_1"},"requestId":"req_1"}
            """,
            "invalid line",
            """
            {"timestamp":"2024-01-15T10:31:00Z","message":{"usage":{"input_tokens":2000,"output_tokens":1000},"model":"claude-sonnet-4-20250514","id":"msg_2"},"requestId":"req_2"}
            """,
        ]

        let results = JSONLParser.parse(lines: lines)
        #expect(results.count == 2)
    }

    @Test("Unique hash generation")
    func testUniqueHash() {
        let line = """
        {"timestamp":"2024-01-15T10:30:00Z","message":{"usage":{"input_tokens":100,"output_tokens":50},"id":"msg_abc"},"requestId":"req_xyz"}
        """
        let entry = JSONLParser.parseLine(line)
        #expect(entry?.uniqueHash == "msg_abc:req_xyz")
    }

    @Test("Null unique hash when missing IDs")
    func testNullUniqueHash() {
        let line = """
        {"timestamp":"2024-01-15T10:30:00Z","message":{"usage":{"input_tokens":100,"output_tokens":50}}}
        """
        let entry = JSONLParser.parseLine(line)
        #expect(entry?.uniqueHash == nil)
    }
}
