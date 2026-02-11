import Testing
import Foundation
@testable import CCMonitor

@Suite("IncrementalFileReader Tests")
struct IncrementalFileReaderTests {
    @Test("Read new lines from file")
    func testReadNewLines() async throws {
        let reader = IncrementalFileReader()
        let tempFile = NSTemporaryDirectory() + "test_incremental_\(UUID().uuidString).jsonl"

        // 写入初始内容
        try "line1\nline2\n".write(toFile: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        // 从头开始读
        await reader.initializeToStart(tempFile)
        let lines1 = await reader.readNewLines(from: tempFile)
        #expect(lines1.count == 2)
        #expect(lines1[0] == "line1")
        #expect(lines1[1] == "line2")

        // 追加新内容
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: tempFile))
        try handle.seekToEnd()
        try handle.write(contentsOf: "line3\n".data(using: .utf8)!)
        try handle.close()

        // 只读到新内容
        let lines2 = await reader.readNewLines(from: tempFile)
        #expect(lines2.count == 1)
        #expect(lines2[0] == "line3")
    }

    @Test("Initialize to end skips existing content")
    func testInitializeToEnd() async throws {
        let reader = IncrementalFileReader()
        let tempFile = NSTemporaryDirectory() + "test_end_\(UUID().uuidString).jsonl"

        try "existing1\nexisting2\n".write(toFile: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        await reader.initializeToEnd(tempFile)

        // 不应读到任何内容
        let lines = await reader.readNewLines(from: tempFile)
        #expect(lines.isEmpty)
    }

    @Test("Handle non-existent file")
    func testNonExistentFile() async {
        let reader = IncrementalFileReader()
        let lines = await reader.readNewLines(from: "/nonexistent/file.jsonl")
        #expect(lines.isEmpty)
    }

    @Test("Tracked file count")
    func testTrackedFileCount() async throws {
        let reader = IncrementalFileReader()
        let tempFile = NSTemporaryDirectory() + "test_count_\(UUID().uuidString).jsonl"
        try "test\n".write(toFile: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        await reader.initializeToStart(tempFile)
        _ = await reader.readNewLines(from: tempFile)

        let count = await reader.trackedFileCount
        #expect(count == 1)

        await reader.resetAll()
        let countAfterReset = await reader.trackedFileCount
        #expect(countAfterReset == 0)
    }
}
