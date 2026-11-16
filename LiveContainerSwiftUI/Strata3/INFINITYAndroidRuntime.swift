import Foundation

/// Android execution backends are deliberately separate from Strata's IPA launch path.
/// This registry is only a capability contract; a backend is selectable only after
/// its implementation has explicitly registered itself as ready.
enum INFINITYAndroidBackend: String, CaseIterable, Codable, Hashable {
    case nativeTranslation
    case qemuGuest
}

enum INFINITYAndroidBackendState: Equatable {
    case notIntegrated
    case unavailable(String)
    case ready

    var userFacingSummary: String {
        switch self {
        case .notIntegrated:
            return "Not integrated"
        case .unavailable(let reason):
            return reason
        case .ready:
            return "Ready"
        }
    }
}

enum INFINITYAndroidBackendPreference {
    case nativeFirst
    case qemuFirst
    case nativeOnly
    case qemuOnly

    fileprivate var orderedCandidates: [INFINITYAndroidBackend] {
        switch self {
        case .nativeFirst:
            return [.nativeTranslation, .qemuGuest]
        case .qemuFirst:
            return [.qemuGuest, .nativeTranslation]
        case .nativeOnly:
            return [.nativeTranslation]
        case .qemuOnly:
            return [.qemuGuest]
        }
    }
}

enum INFINITYAndroidBackendSelection: Equatable {
    case selected(INFINITYAndroidBackend)
    case noBackendAvailable([INFINITYAndroidBackend: String])
}

struct INFINITYAndroidRuntimeRegistry {
    private(set) var states: [INFINITYAndroidBackend: INFINITYAndroidBackendState] = [
        .nativeTranslation: .notIntegrated,
        .qemuGuest: .notIntegrated
    ]

    mutating func register(_ backend: INFINITYAndroidBackend, state: INFINITYAndroidBackendState) {
        states[backend] = state
    }

    func selectBackend(preference: INFINITYAndroidBackendPreference = .nativeFirst) -> INFINITYAndroidBackendSelection {
        for candidate in preference.orderedCandidates {
            if states[candidate] == .ready {
                return .selected(candidate)
            }
        }

        let reasons = Dictionary(uniqueKeysWithValues: preference.orderedCandidates.map { backend in
            (backend, states[backend, default: .notIntegrated].userFacingSummary)
        })
        return .noBackendAvailable(reasons)
    }
}