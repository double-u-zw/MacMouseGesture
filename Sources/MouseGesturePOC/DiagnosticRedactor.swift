import Foundation

/// Conservative boundary for every user-visible diagnostic/error. Never export a
/// filesystem path: free-form errors can contain private filenames as well as home.
enum DiagnosticRedactor {
    static func redact(_ text: String) -> String {
        let decoded = text.removingPercentEncoding ?? text
        // Drop the remainder of a path-bearing line, including spaces and CJK.
        // This intentionally sacrifices error detail to avoid leaking filenames.
        return decoded.replacingOccurrences(
            of: #"(?m)(?<![A-Za-z0-9_])(?:file://|~)?/(?=[^\s/])[^\r\n]*"#,
            with: "<PRIVATE_PATH>", options: .regularExpression)
    }
    static func installation(_ url: URL = Bundle.main.bundleURL) -> String {
        let parent = url.deletingLastPathComponent().standardizedFileURL
        let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        return parent.path == "/Applications" || parent == userApps ? "Applications" : "非 Applications"
    }
}
