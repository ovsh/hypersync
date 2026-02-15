import Foundation

struct SetupCheckResult {
    let passed: Bool
    let lines: [String]
    let checkedAt: Date
}

struct SetupChecker {
    private let runner = CommandRunner()

    func run(remoteGitURL: String) -> SetupCheckResult {
        var lines: [String] = []
        var passed = true
        let remote = remoteGitURL.trimmed
        let isHTTPS = Self.isHTTPS(remote)

        if remote.isEmpty {
            lines.append("Set your GitHub repo URL in Settings.")
            passed = false
        } else if !GitSync.isGitHubRemote(remote) {
            lines.append("Remote must be a GitHub URL (HTTPS or SSH).")
            passed = false
        } else {
            lines.append("Remote format looks valid (\(isHTTPS ? "HTTPS" : "SSH")).")
        }

        // HTTPS credential info (diagnostic only — git ls-remote below is the real pass/fail)
        if isHTTPS {
            do {
                let credHelper = try runner.run(command: "/usr/bin/env", arguments: ["git", "config", "--global", "credential.helper"])
                let helper = credHelper.stdout.trimmed
                if credHelper.exitCode == 0 && !helper.isEmpty {
                    lines.append("Git credential helper: \(helper)")
                } else {
                    lines.append("No explicit credential helper (macOS Keychain may provide credentials).")
                }
            } catch {
                lines.append("Could not check credential helper configuration.")
            }
        }

        // SSH-specific checks (skip for HTTPS)
        if !isHTTPS {
            do {
                let keys = try runner.run(command: "/usr/bin/env", arguments: ["ssh-add", "-l"])
                let stdout = keys.stdout.lowercased()
                let stderr = keys.stderr.lowercased()
                if keys.exitCode == 0 && !stdout.contains("no identities") && !stderr.contains("no identities") {
                    lines.append("SSH agent has at least one loaded key.")
                } else {
                    passed = false
                    lines.append("No keys loaded in ssh-agent. Run: ssh-add ~/.ssh/<your-key>")
                }
            } catch {
                passed = false
                lines.append("Could not run ssh-add. Ensure OpenSSH tools are installed.")
            }

            do {
                let ssh = try runner.run(
                    command: "/usr/bin/env",
                    arguments: ["ssh", "-T", "-o", "BatchMode=yes", "git@github.com"]
                )
                let combined = (ssh.stdout + "\n" + ssh.stderr).lowercased()
                if combined.contains("successfully authenticated") {
                    lines.append("GitHub SSH authentication works.")
                } else {
                    passed = false
                    if combined.contains("permission denied") {
                        lines.append("GitHub rejected your SSH key. Add the key to your GitHub account/org.")
                    } else {
                        lines.append("Could not verify GitHub SSH auth. Run: ssh -T git@github.com")
                    }
                }
            } catch {
                passed = false
                lines.append("Could not run ssh auth check against github.com.")
            }
        }

        if !remote.isEmpty && GitSync.isGitHubRemote(remote) {
            do {
                var env: [String: String] = [:]
                if !isHTTPS {
                    env["GIT_SSH_COMMAND"] = "ssh -o BatchMode=yes"
                }
                let ls = try runner.run(
                    command: "/usr/bin/env",
                    arguments: ["git", "ls-remote", remote, "main"],
                    extraEnvironment: env
                )
                if ls.exitCode == 0 {
                    lines.append("Repository access OK for main branch.")
                } else {
                    passed = false
                    let combined = (ls.stderr + "\n" + ls.stdout).lowercased()
                    if combined.contains("repository not found") {
                        lines.append("Repo not found or you do not have access.")
                    } else if combined.contains("permission denied") || combined.contains("authentication failed") {
                        lines.append("Authentication failed. Check your credentials.")
                    } else {
                        lines.append("Could not read repo main branch. Check URL and permissions.")
                    }
                }
            } catch {
                passed = false
                lines.append("Could not run git ls-remote check.")
            }
        }

        return SetupCheckResult(passed: passed, lines: lines, checkedAt: Date())
    }

    static func isHTTPS(_ remote: String) -> Bool {
        remote.lowercased().hasPrefix("https://")
    }
}
