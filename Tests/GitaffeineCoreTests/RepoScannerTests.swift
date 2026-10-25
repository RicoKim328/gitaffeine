import Foundation
import Testing
@testable import GitaffeineCore

@Test func findsReposAndSkipsExcludedPlaces() throws {
    let root = try TempDir()
    let fm = FileManager.default
    func makeDir(_ path: String) throws {
        try fm.createDirectory(at: root.url.appending(path: path), withIntermediateDirectories: true)
    }
    try makeDir("code/app/.git")
    try makeDir("code/app/vendor/inner/.git")       // inside a repo: not searched
    try makeDir("code/web/node_modules/pkg/.git")   // excluded folder name
    try makeDir("code/web/.git")
    try makeDir(".hidden/repo/.git")                // hidden folder
    try makeDir("Library/Mobile Documents/r/.git")  // ~/Library
    try makeDir("notes/plain")
    try fm.createSymbolicLink(at: root.url.appending(path: "link"), withDestinationURL: root.url.appending(path: "code"))

    let found = RepoScanner.findRepos(under: root.url).map(\.lastPathComponent).sorted()

    #expect(found == ["app", "web"])
}

@Test func skipsReposInICloud() throws {
    let root = try TempDir()
    for path in ["local/.git", "synced/.git"] {
        try FileManager.default.createDirectory(at: root.url.appending(path: path), withIntermediateDirectories: true)
    }

    let found = RepoScanner.findRepos(under: root.url, isInICloud: { $0.path.contains("/synced/") })

    #expect(found.map(\.lastPathComponent) == ["local"])
}
