import Foundation

struct CommandResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

enum CommandRunnerError: LocalizedError {
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let command):
            return "Failed to launch command: \(command)"
        }
    }
}

struct CommandRunner {
    func run(
        command: String,
        arguments: [String],
        currentDirectory: URL? = nil,
        extraEnvironment: [String: String] = [:]
    ) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }

        var environment = ProcessInfo.processInfo.environment
        for (k, v) in extraEnvironment {
            environment[k] = v
        }
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw CommandRunnerError.launchFailed(([command] + arguments).joined(separator: " "))
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return CommandResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
