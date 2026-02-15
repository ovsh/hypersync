import Foundation

struct GitHubCLI {
    private let runner = CommandRunner()

    /// Homebrew paths that macOS GUI apps don't have in PATH
    private static let brewPaths = "/opt/homebrew/bin:/usr/local/bin:/opt/homebrew/sbin:/usr/local/sbin"

    /// Environment with Homebrew paths injected so `gh` is discoverable
    private var shellEnv: [String: String] {
        let base = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        return ["PATH": "\(Self.brewPaths):\(base)"]
    }

    /// Resolves the absolute path to `gh`, or nil if not found
    func ghPath() -> String? {
        // Check common Homebrew locations first (fast, no subprocess)
        for path in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // Fallback: ask the shell
        guard let result = try? runner.run(
            command: "/usr/bin/env", arguments: ["which", "gh"],
            extraEnvironment: shellEnv
        ), result.exitCode == 0 else {
            return nil
        }
        let path = result.stdout.trimmed
        return path.isEmpty ? nil : path
    }

    /// Returns true if `gh` is installed
    func isInstalled() -> Bool {
        ghPath() != nil
    }

    /// Returns true if authenticated with GitHub
    func isAuthenticated() -> Bool {
        guard let gh = ghPath() else { return false }
        guard let result = try? runner.run(
            command: gh, arguments: ["auth", "status"],
            extraEnvironment: shellEnv
        ) else {
            return false
        }
        return result.exitCode == 0
    }

    /// Returns the authenticated username, or nil
    func currentUser() -> String? {
        guard let gh = ghPath() else { return nil }
        guard let result = try? runner.run(
            command: gh, arguments: ["api", "user", "--jq", ".login"],
            extraEnvironment: shellEnv
        ) else {
            return nil
        }
        let username = result.stdout.trimmed
        return result.exitCode == 0 && !username.isEmpty ? username : nil
    }

    /// Returns list of org logins the user belongs to
    func userOrgs() -> [String] {
        guard let gh = ghPath() else { return [] }
        guard let result = try? runner.run(
            command: gh, arguments: ["api", "user/orgs", "--jq", ".[].login"],
            extraEnvironment: shellEnv
        ) else {
            return []
        }
        guard result.exitCode == 0 else { return [] }
        return result.stdout
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Creates a repo from template. Returns the HTTPS clone URL on success.
    func createRepoFromTemplate(
        owner: String,
        name: String,
        template: String,
        isPrivate: Bool
    ) throws -> String {
        guard let gh = ghPath() else {
            throw GitHubCLIError.createFailed("GitHub CLI (gh) not found")
        }
        let visibility = isPrivate ? "--private" : "--public"
        let result = try runner.run(
            command: gh,
            arguments: [
                "repo", "create", "\(owner)/\(name)",
                "--template", template,
                visibility,
                "--clone=false",
            ],
            extraEnvironment: shellEnv
        )

        if result.exitCode != 0 {
            let raw = (result.stderr.trimmed.isEmpty ? result.stdout.trimmed : result.stderr.trimmed).lowercased()
            let friendly: String
            if raw.contains("name already exists") || raw.contains("already exists") {
                friendly = "A project with that name already exists. Try a different name."
            } else if raw.contains("could not resolve") || raw.contains("not found") {
                friendly = "Couldn\u{2019}t reach GitHub. Check your connection and try again."
            } else if raw.contains("permission") || raw.contains("forbidden") || raw.contains("401") || raw.contains("403") {
                friendly = "You don\u{2019}t have permission to create this. Try a different account."
            } else {
                friendly = "Something went wrong. Please try again."
            }
            throw GitHubCLIError.createFailed(friendly)
        }

        return "https://github.com/\(owner)/\(name).git"
    }
}

enum GitHubCLIError: LocalizedError {
    case createFailed(String)

    var errorDescription: String? {
        switch self {
        case .createFailed(let message):
            return message
        }
    }
}
