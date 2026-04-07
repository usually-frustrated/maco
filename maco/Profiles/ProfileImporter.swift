import Foundation

enum ProfileImportError: Error, LocalizedError {
    case emptyProfile
    case unreadableProfile

    var errorDescription: String? {
        switch self {
        case .emptyProfile:
            return "The imported profile file is empty."
        case .unreadableProfile:
            return "The imported profile file could not be read."
        }
    }
}

final class ProfileImporter {
    private let supportedDirectives: Set<String> = [
        "auth", "auth-nocache", "auth-token", "auth-user-pass", "ca", "cert", "cipher",
        "client", "comp-lzo", "compress", "compress-stub-v2", "connect-retry",
        "connect-timeout", "data-ciphers", "data-ciphers-fallback", "dev", "dhcp-option",
        "dev-type", "disable-occ", "explicit-exit-notify", "float", "ifconfig", "inactive", "key",
        "key-direction", "keepalive", "mssfix", "mute-replay-warnings", "nobind", "persist-key",
        "persist-remote-ip", "persist-tun", "proto", "pull", "pull-filter", "push-peer-info",
        "remote", "remote-cert-eku", "remote-cert-tls", "redirect-gateway", "reneg-sec",
        "resolv-retry", "route", "script-security", "server-poll-timeout", "setenv", "setenv-safe",
        "static-challenge", "tls-auth", "tls-client", "tls-cipher", "tls-crypt",
        "tls-version-min", "tun-mtu", "verify-x509-name", "verb"
    ]

    func contents(from fileURL: URL) throws -> String {
        guard let contents = readContents(from: fileURL) else {
            throw ProfileImportError.unreadableProfile
        }

        return contents
    }

    func analyze(fileURL: URL) throws -> ProfileImportAnalysis {
        let contents = try contents(from: fileURL)
        return try analyze(contents: contents, sourceFileName: fileURL.lastPathComponent)
    }

    func analyze(contents: String, sourceFileName: String) throws -> ProfileImportAnalysis {
        guard containsDirective(in: contents) else {
            throw ProfileImportError.emptyProfile
        }

        let warnings = analyze(contents: contents)
        let displayName = (sourceFileName as NSString)
            .deletingPathExtension
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ProfileImportAnalysis(
            displayName: displayName.isEmpty ? "Imported Profile" : displayName,
            content: contents,
            warnings: warnings
        )
    }

    private func readContents(from fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        let encodings: [String.Encoding] = [.utf8, .ascii, .isoLatin1, .windowsCP1252]
        for encoding in encodings {
            if let contents = String(data: data, encoding: encoding) {
                return contents
            }
        }

        return nil
    }

    private func analyze(contents: String) -> [ProfileImportWarning] {
        var warnings: [ProfileImportWarning] = []
        var seen = Set<String>()
        var activeBlockDirective: String?

        for (offset, rawLine) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineNumber = offset + 1
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if let currentBlockDirective = activeBlockDirective {
                if line.lowercased().hasPrefix("</\(currentBlockDirective)>") {
                    activeBlockDirective = nil
                }
                continue
            }

            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix(";") else {
                continue
            }

            if let blockDirective = openingBlockDirective(in: line) {
                activeBlockDirective = blockDirective
                if !supportedDirectives.contains(blockDirective), !seen.contains(blockDirective) {
                    seen.insert(blockDirective)
                    warnings.append(
                        ProfileImportWarning(
                            line: lineNumber,
                            directive: blockDirective,
                            message: "Block directive '\(blockDirective)' is imported but not interpreted yet."
                        )
                    )
                }
                continue
            }

            guard let directive = directiveName(in: line) else { continue }
            guard !supportedDirectives.contains(directive), !seen.contains(directive) else { continue }

            seen.insert(directive)
            warnings.append(
                ProfileImportWarning(
                    line: lineNumber,
                    directive: directive,
                    message: "Directive '\(directive)' is imported but not interpreted yet."
                )
            )
        }

        return warnings
    }

    private func containsDirective(in contents: String) -> Bool {
        contents.split(separator: "\n", omittingEmptySubsequences: false).contains { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            return !line.isEmpty && !line.hasPrefix("#") && !line.hasPrefix(";") && !line.hasPrefix("</")
        }
    }

    private func directiveName(in line: String) -> String? {
        guard let firstToken = line.split(whereSeparator: { $0.isWhitespace }).first else {
            return nil
        }

        return firstToken.lowercased()
    }

    private func openingBlockDirective(in line: String) -> String? {
        guard line.hasPrefix("<"),
              let endIndex = line.firstIndex(of: ">"),
              line.count > 2,
              line[line.index(after: line.startIndex)] != "/" else {
            return nil
        }

        let directive = line[line.index(after: line.startIndex)..<endIndex]
        return directive.lowercased()
    }
}

struct ProfileImportAnalysis {
    let displayName: String
    let content: String
    let warnings: [ProfileImportWarning]
}
