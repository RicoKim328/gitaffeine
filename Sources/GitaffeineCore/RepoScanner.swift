import Foundation

public enum RepoScanner {
    /// Folder names never searched: dependency and build output that can hold thousands of folders.
    static let skippedNames: Set<String> = ["node_modules", ".build", "build", "DerivedData", "Pods", ".venv"]

    /// Git repositories under `root`. Skips `root/Library` (private app data, needs extra macOS permissions),
    /// hidden folders, app bundles, `skippedNames`, repos in iCloud, and anything inside a repo.
    /// Symbolic links are not followed.
    public static func findRepos(under root: URL, isInICloud: (URL) -> Bool = isInICloud) -> [URL] {
        let fm = FileManager.default
        let library = root.appending(path: "Library").standardizedFileURL
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                                         options: [.skipsHiddenFiles, .skipsPackageDescendants],
                                         errorHandler: { _, _ in true }) else { return [] }
        var repos: [URL] = []
        for case let url as URL in walker {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
            if skippedNames.contains(url.lastPathComponent) || url.standardizedFileURL == library {
                walker.skipDescendants()
            } else if fm.fileExists(atPath: url.appending(path: ".git").path) {
                if !isInICloud(url.appending(path: ".git")) { repos.append(url) }
                walker.skipDescendants()
            }
        }
        return repos
    }

    /// True when `url` is in an iCloud-synced folder (e.g. ~/Documents with Desktop & Documents sync).
    /// Reads metadata only. Git can hang on such repos: files inside .git may exist only in iCloud,
    /// even when the folder itself reports as downloaded.
    public static func isInICloud(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true
    }
}
