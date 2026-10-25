import Foundation
import Testing
@testable import GitaffeineCore

@Test func findsGitHubRemotesFromRemoteList() {
    let output = """
    origin\thttps://github.com/rico/app.git (fetch)
    origin\thttps://github.com/rico/app.git (push)
    work\tgit@github.com:team/app.git (fetch)
    work\tgit@github.com:team/app.git (push)
    lab\thttps://gitlab.com/rico/app.git (fetch)
    ssh\tssh://git@github.com/rico/app.git (fetch)
    mirror\t/backups/github.com/app.git (fetch)
    fake\thttps://github.com.example.org/rico/app.git (fetch)
    """
    #expect(GitLog.githubRemotes(fromRemoteList: output) == ["origin", "work", "ssh"])
}

@Test func countedRefsUseRemoteHeadThenMainOrMasterPlusGhPages() {
    let withHead = """
    refs/remotes/origin/HEAD\trefs/remotes/origin/develop
    refs/remotes/origin/develop\t
    refs/remotes/origin/main\t
    refs/remotes/origin/gh-pages\t
    """
    #expect(GitLog.countedRefs(remote: "origin", refList: withHead)
            == ["refs/remotes/origin/develop", "refs/remotes/origin/gh-pages"])

    let noHead = "refs/remotes/origin/feature\t\nrefs/remotes/origin/master\t\n"
    #expect(GitLog.countedRefs(remote: "origin", refList: noHead) == ["refs/remotes/origin/master"])

    let neither = "refs/remotes/origin/feature\t\n"
    #expect(GitLog.countedRefs(remote: "origin", refList: neither) == [])
}

@Test func countsOnlyCommitsGitHubDoesNotAlreadyCount() throws {
    let repo = try TempDir()
    let git = TestGit(repo.url)
    try git("init", "-q", "-b", "main")
    try git("remote", "add", "origin", "https://github.com/rico/app.git")
    let day = Date().addingTimeInterval(-86_400)

    try git.commit(email: "me@example.com", date: day)                  // pushed to origin/main
    try git("update-ref", "refs/remotes/origin/main", "HEAD")
    try git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
    try git.commit(email: "me@example.com", date: day)                  // not pushed
    try git("switch", "-q", "-c", "feature")
    try git.commit(email: "me@example.com", date: day)                  // pushed to a non-default branch
    try git("update-ref", "refs/remotes/origin/feature", "HEAD")
    try git("switch", "-q", "--orphan", "gh-pages")
    try git.commit(email: "me@example.com", date: day)                  // pushed to gh-pages
    try git("update-ref", "refs/remotes/origin/gh-pages", "HEAD")

    let all = ContributionCounter.dailyCounts(repos: [repo.url], emails: ["me@example.com"], sinceDays: 60)
    let notOnGitHub = ContributionCounter.dailyCounts(repos: [repo.url], emails: ["me@example.com"], sinceDays: 60,
                                                      onlyNotOnGitHub: true)

    #expect(all.values.reduce(0, +) == 4)
    #expect(notOnGitHub.values.reduce(0, +) == 2) // the unpushed commit and the feature-branch commit
}

@Test func commitOnGitHubIsNotCountedAgainFromAnotherLocalClone() throws {
    let root = try TempDir()
    let github = root.url.appending(path: "github")
    try FileManager.default.createDirectory(at: github, withIntermediateDirectories: true)
    let git = TestGit(github)
    try git("init", "-q", "-b", "main")
    try git("remote", "add", "origin", "https://github.com/rico/app.git")
    try git.commit(email: "me@example.com", date: Date().addingTimeInterval(-86_400))
    try git("update-ref", "refs/remotes/origin/main", "HEAD")
    try git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
    try TestGit(root.url)("clone", "-q", github.path, root.url.appending(path: "copy").path) // origin is a local path

    let counts = ContributionCounter.dailyCounts(repos: RepoScanner.findRepos(under: root.url), emails: ["me@example.com"],
                                                 sinceDays: 60, onlyNotOnGitHub: true)

    #expect(counts.isEmpty)
}

@Test func repoWithoutGitHubRemoteCountsEverything() throws {
    let repo = try TempDir()
    let git = TestGit(repo.url)
    try git("init", "-q", "-b", "main")
    try git("remote", "add", "origin", "https://gitlab.com/rico/app.git")
    try git.commit(email: "me@example.com", date: Date().addingTimeInterval(-86_400))
    try git("update-ref", "refs/remotes/origin/main", "HEAD")

    let counts = ContributionCounter.dailyCounts(repos: [repo.url], emails: ["me@example.com"], sinceDays: 60,
                                                 onlyNotOnGitHub: true)

    #expect(counts.values.reduce(0, +) == 1)
}
