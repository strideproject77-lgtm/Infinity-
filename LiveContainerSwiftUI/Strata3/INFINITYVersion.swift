import Foundation

/// The app's display version, read from the built bundle so every UI surface
/// reports the exact version embedded by the active Xcode/Codemagic build.
enum INFINITYVersion {
    static var display: String {
        let info = Bundle.main.infoDictionary ?? [:]
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

        if let buildVersion, !buildVersion.isEmpty {
            return buildVersion
        }

        return "Unknown"
    }
}
