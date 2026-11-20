import Foundation

/// Single source of truth for the app version across Strata settings and the main UI.
enum INFINITYVersion {
    private static var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    /// Marketing version, preserving the custom INFINITY metadata when present.
    static var marketing: String {
        (info["INFINITYMarketingVersion"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
            ?? (info["CFBundleShortVersionString"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "1.0"
    }

    static var revision: Int? {
        (info["INFINITYRevision"] as? NSNumber)?.intValue
    }

    static var channel: String? {
        (info["INFINITYBuildChannel"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    /// Exact version embedded in the active Xcode/Codemagic build.
    static var display: String {
        let shortVersion = (info["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let buildVersion = (info["CFBundleVersion"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let shortVersion, !shortVersion.isEmpty {
            if let buildVersion, !buildVersion.isEmpty, buildVersion != shortVersion {
                return "\(shortVersion) (\(buildVersion))"
            }
            return shortVersion
        }

        return marketing
    }

    static var full: String { "INFINITY " + display }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
