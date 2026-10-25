import Foundation

public struct GitHubContributions: Equatable, Sendable {
    public let login: String
    /// The public profile email; nil when it is private.
    public let email: String?
    /// Contributions per day ("yyyy-MM-dd"): commits, pull requests, issues and reviews, as on the profile calendar.
    public let counts: [String: Int]
}

/// The signed-in GitHub user's contribution calendar, fetched through the `gh` CLI.
/// gh keeps the login token; this app never reads or stores it.
public enum GitHubCalendar {
    static let query = """
    query($from: DateTime!, $to: DateTime!) { viewer { login email \
    contributionsCollection(from: $from, to: $to) { contributionCalendar { weeks { contributionDays { date contributionCount } } } } } }
    """

    /// Throws when gh is missing, not logged in, the request fails, or it takes longer than 60 seconds
    /// (e.g. offline), so the app can fall back to local counts.
    public static func fetch(from: Date, to: Date) throws -> GitHubContributions {
        guard let gh = ghPath() else { throw CocoaError(.fileNoSuchFile) }
        let iso = ISO8601DateFormatter()
        return try parse(Command.run(gh, ["api", "graphql", "-f", "query=\(query)",
                                          "-f", "from=\(iso.string(from: from))", "-f", "to=\(iso.string(from: to))"],
                                     timeout: 60))
    }

    /// Apps started from Finder don't get the shell's PATH, so look in the usual Homebrew locations.
    static func ghPath() -> URL? {
        ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"].first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    static func parse(_ data: Data) throws -> GitHubContributions {
        let viewer = try JSONDecoder().decode(Response.self, from: data).data.viewer
        var counts: [String: Int] = [:]
        for day in viewer.contributionsCollection.contributionCalendar.weeks.flatMap(\.contributionDays)
        where day.contributionCount > 0 {
            counts[day.date] = day.contributionCount
        }
        return GitHubContributions(login: viewer.login, email: viewer.email?.isEmpty == false ? viewer.email : nil,
                                   counts: counts)
    }

    private struct Response: Decodable {
        let data: DataField
        struct DataField: Decodable { let viewer: Viewer }
        struct Viewer: Decodable {
            let login: String
            let email: String?
            let contributionsCollection: Collection
        }
        struct Collection: Decodable { let contributionCalendar: Calendar }
        struct Calendar: Decodable { let weeks: [Week] }
        struct Week: Decodable { let contributionDays: [Day] }
        struct Day: Decodable {
            let date: String
            let contributionCount: Int
        }
    }
}
