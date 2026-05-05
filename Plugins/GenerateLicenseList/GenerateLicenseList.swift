import Foundation
import PackagePlugin

@main
struct GenerateLicenseList: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let licensePlist = try context.tool(named: "license-plist")

        let configPath = context.package.directoryURL.appending(path: "license_plist.yml")
        let packageSwiftPath = context.package.directoryURL.appending(path: "Package.swift")

        let workDirectory = context.pluginWorkDirectoryURL
        let markdownURL = workDirectory.appending(path: "Licenses.md")
        let plistOutputURL = workDirectory.appending(path: "license-plist-output")

        let outputSwiftURL = context.package.directoryURL.appending(path: "Sources/Pages/Generated/LicensesContent.swift")
        try FileManager.default.createDirectory(at: outputSwiftURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = licensePlist.url
        process.arguments = [
            "--config-path", configPath.path,
            "--package-path", packageSwiftPath.path,
            "--markdown-path", markdownURL.path,
            "--output-path", plistOutputURL.path,
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            Diagnostics.error("license-plist exited with status \(process.terminationStatus)")
            throw ExitCode()
        }

        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let swift = """
        internal let licensesMarkdown: String = #\"\"\"
        \(markdown)
        \"\"\"#

        """

        try swift.write(to: outputSwiftURL, atomically: true, encoding: .utf8)
    }
}

private struct ExitCode: Error {}
