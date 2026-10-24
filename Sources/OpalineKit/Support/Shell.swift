import Foundation

enum Shell {
    struct Failure: LocalizedError {
        var status: Int32
        var output: String
        var errorDescription: String? { "Exited with \(status): \(output)" }
    }

    /// Runs an executable without a shell and returns its combined output.
    @discardableResult
    static func run(_ executable: URL, _ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { process in
                let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: Failure(status: process.terminationStatus, output: output))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Runs a command line through the user's login shell, for user-provided reload commands.
    @discardableResult
    static func runCommand(_ command: String) async throws -> String {
        try await run(URL(fileURLWithPath: "/bin/zsh"), ["-lc", command])
    }
}
