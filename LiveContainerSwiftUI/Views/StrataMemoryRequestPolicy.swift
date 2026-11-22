import Foundation

enum StrataMemoryRequestPolicy {
    /// Only the two bundle IDs read from this installed app may be changed.
    static func matchingTargets(registered: [String], allowed: Set<String>) -> Set<String>? {
        guard allowed.count == 2, !allowed.contains("") else { return nil }
        let found = Set(registered).intersection(allowed)
        return found == allowed ? found : nil
    }
    /// Strip only the verified team prefix, never arbitrary dot-separated components.
    static func bundleIdentity(signedID: String, team: String, fallback: String) -> String {
        let prefix = team + "."
        guard !team.isEmpty, signedID.hasPrefix(prefix) else { return fallback }
        let identity = String(signedID.dropFirst(prefix.count))
        return identity.isEmpty ? fallback : identity
    }
    /// Match an App ID registration to the exact installed executable identity.
    /// Apple's explicit and wildcard App IDs are both supported; arbitrary registrations are rejected.
    static func registrationMatches(bundleIdentifier: String, expectedBundle: String) -> Bool {
        guard !bundleIdentifier.isEmpty, !expectedBundle.isEmpty else { return false }
        if bundleIdentifier == expectedBundle || bundleIdentifier == "*" { return true }
        guard bundleIdentifier.hasSuffix(".*") else { return false }
        let prefix = String(bundleIdentifier.dropLast())
        return expectedBundle.hasPrefix(prefix) && expectedBundle.count > prefix.count
    }
    /// Selections must be authenticated registrations and must cover the actual signed host/guest IDs.
    /// A shared wildcard registration can legitimately cover both executables.
    static func selectedTargets(host: String, guest: String, expectedHost: String, expectedGuest: String,
                                registrations: [(identifier: String, bundleIdentifier: String)]) -> Set<String>? {
        guard !host.isEmpty, !guest.isEmpty,
              let hostRegistration = registrations.first(where: { $0.identifier == host }),
              let guestRegistration = registrations.first(where: { $0.identifier == guest }),
              registrationMatches(bundleIdentifier: hostRegistration.bundleIdentifier, expectedBundle: expectedHost),
              registrationMatches(bundleIdentifier: guestRegistration.bundleIdentifier, expectedBundle: expectedGuest) else { return nil }
        return [host, guest]
    }
    static let capabilities = ["INCREASED_MEMORY_LIMIT"]
    /// RAM bypass: Apple's Increased Debugging Memory Limit raises the jetsam limit above the regular
    /// increased limit while a debugger is attached (JIT launches attach one). Requested separately so a
    /// refusal never affects the regular request.
    static let bypassCapabilities = ["INCREASED_MEMORY_LIMIT", "INCREASED_MEMORY_LIMIT_DEBUGGING"]
}
