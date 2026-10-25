import Foundation

enum Command {
    struct Failure: Error {
        let status: Int32
    }

    struct TimedOut: Error {}

    /// Runs `executable` with `arguments` and returns stdout; throws on a non-zero exit.
    /// With `timeout` (seconds), a command still running after it is stopped and `TimedOut` is thrown.
    static func run(_ executable: URL, _ arguments: [String], timeout: TimeInterval? = nil) throws -> Data {
        // stdout goes to a temp file, so a large output can't fill a pipe and block the command.
        let output = FileManager.default.temporaryDirectory.appending(path: "gitaffeine-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: output.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: output) }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = try FileHandle(forWritingTo: output)
        process.standardError = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        try process.run()

        if let timeout, exited.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            process.waitUntilExit()
            throw TimedOut()
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Failure(status: process.terminationStatus) }
        return try Data(contentsOf: output)
    }
}
