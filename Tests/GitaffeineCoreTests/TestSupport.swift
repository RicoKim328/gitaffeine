import Foundation

/// A temporary directory removed when the value is released.
final class TempDir {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appending(path: "gitaffeine-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }
}

/// Runs git in a test repo, isolated from the user's global git config.
struct TestGit {
    let repo: URL

    init(_ repo: URL) { self.repo = repo }

    func callAsFunction(_ args: String..., env: [String: String] = [:]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repo.path] + args
        process.environment = ["GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1", "HOME": repo.path]
            .merging(env) { $1 }
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CocoaError(.executableLoad, userInfo: [NSLocalizedDescriptionKey: "git \(args) failed"])
        }
    }

    func commit(email: String, date: Date) throws {
        let stamp = "@\(Int(date.timeIntervalSince1970)) +0000"
        // A unique message keeps two empty commits made in the same second from sharing a hash.
        try self("-c", "user.name=Test", "-c", "user.email=\(email)", "commit", "-q", "--allow-empty",
                 "-m", UUID().uuidString, env: ["GIT_AUTHOR_DATE": stamp])
    }
}
