import Foundation
import Darwin
import CryptoKit

/// Husk 3.2 AOT preparation for running supported ARM64 Android libraries
/// without asking iOS for executable memory at runtime.
enum INFINITYJITLess {
    enum PreparationError: LocalizedError {
        case noAPKPaths
        case certificateUnavailable
        case invalidCertificate
        case certificateTeamMismatch
        case incompleteAOT(expected: Int, prepared: Int)
        case pathAllocation
        case nativeFailure(String)

        var errorDescription: String? {
            switch self {
            case .noAPKPaths:
                return "No APK or Android runtime libraries were supplied for JIT-less preparation."
            case .certificateUnavailable:
                return "The SideStore/LiveContainer JIT-less signing certificate or its password is not available. Normal execution will be attempted."
            case .invalidCertificate:
                return "The imported JIT-less certificate could not be validated. Normal execution will be attempted."
            case .certificateTeamMismatch:
                return "The imported certificate belongs to a different Apple signing team than INFINITY. JIT-less signing was skipped."
            case .incompleteAOT(let expected, let prepared):
                return String(format: "Husk prepared %d of %d required ARM64 libraries. JIT-less mode was not enabled.", prepared, expected)
            case .pathAllocation:
                return "Could not prepare the APK paths for native conversion."
            case .nativeFailure(let message):
                return message
            }
        }
    }

    enum FailureClassification: Equatable {
        case confirmedJITRequired
        case jitlessAOTUnavailable
        case other
    }

    static var cacheDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("INFINITY/JITless", isDirectory: true)
    }

    static var preparedLibraryCount: Int {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path)) ?? []
        return names.filter { $0.hasPrefix("aot-v") && $0.hasSuffix(".dylib") }.count
    }

    /// Reads the existing SideStore/LiveContainer identity supplied by the host.
    /// The caller passes it in so this narrow facade remains independently type-checkable.
    /// JIT-less is enabled only when every unique ARM64 library has a matching AOT dylib.
    @discardableResult
    static func prepareForLaunch(apk: URL,
                                 nativeLibraryPaths: [String],
                                 runtimeLibraries: [URL] = [],
                                 certificateP12: Data?,
                                 certificatePassword: String?,
                                 certificateTeamID: String?,
                                 appTeamID: String?) throws -> Bool {
        try configure(enabled: false)

        let apkLibraries = nativeLibraryPaths.filter {
            $0.hasPrefix("lib/arm64-v8a/") || $0.hasPrefix("lib/arm64/")
        }.map { URL(fileURLWithPath: $0).lastPathComponent }
        let runtimeNames = runtimeLibraries.map { $0.lastPathComponent }
        let requiredNames = Set((apkLibraries + runtimeNames).filter { $0.hasSuffix(".so") })
        guard !requiredNames.isEmpty else { return false }

        guard let certificateP12, !certificateP12.isEmpty,
              let certificatePassword else {
            throw PreparationError.certificateUnavailable
        }
        guard let certificateTeamID, !certificateTeamID.isEmpty else {
            throw PreparationError.invalidCertificate
        }
        guard let appTeamID, !appTeamID.isEmpty,
              certificateTeamID == appTeamID else {
            throw PreparationError.certificateTeamMismatch
        }

        let tag = SHA256.hash(data: certificateP12)
            .map { String(format: "%02x", $0) }.joined()
        let paths = [apk] + runtimeLibraries
        let prepared = try prepare(apksAndRuntimeLibraries: paths,
                                   certificateP12: certificateP12,
                                   certificatePassword: certificatePassword,
                                   certificateTag: tag,
                                   signingIdentifier: Bundle.main.bundleIdentifier ?? "")
        guard prepared == requiredNames.count else {
            throw PreparationError.incompleteAOT(expected: requiredNames.count, prepared: prepared)
        }

        try configure(enabled: true)
        return true
    }

    /// Convert ARM64 libraries found in the supplied APKs and explicitly supplied
    /// Android runtime .so files. Original APKs are never modified.
    @discardableResult
    static func prepare(apksAndRuntimeLibraries: [URL],
                        certificateP12: Data,
                        certificatePassword: String,
                        certificateTag: String,
                        signingIdentifier: String,
                        appExecutable: URL = Bundle.main.executableURL ?? URL(fileURLWithPath: "/")) throws -> Int {
        guard !apksAndRuntimeLibraries.isEmpty else { throw PreparationError.noAPKPaths }
        guard !certificateP12.isEmpty, !certificateTag.isEmpty,
              !signingIdentifier.isEmpty else { throw PreparationError.invalidCertificate }

        try FileManager.default.createDirectory(at: cacheDirectory,
                                                withIntermediateDirectories: true)

        let allocated = apksAndRuntimeLibraries.map { strdup($0.path) }
        guard allocated.allSatisfy({ $0 != nil }) else {
            allocated.forEach { if let path = $0 { free(path) } }
            throw PreparationError.pathAllocation
        }
        defer { allocated.forEach { if let path = $0 { free(path) } } }

        var error = [CChar](repeating: 0, count: 512)
        let result: Int32 = cacheDirectory.path.withCString { cachePath in
            certificatePassword.withCString { password in
                certificateTag.withCString { tag in
                    signingIdentifier.withCString { identifier in
                        appExecutable.path.withCString { executable in
                            allocated.withUnsafeBufferPointer { paths in
                                guard let base = paths.baseAddress else { return -1 }
                                return base.withMemoryRebound(to: UnsafePointer<CChar>?.self,
                                                              capacity: paths.count) { nativePaths in
                                    certificateP12.withUnsafeBytes { bytes in
                                        let p12 = bytes.bindMemory(to: UInt8.self)
                                        return error.withUnsafeMutableBufferPointer { errorBuffer in
                                            infinity_husk_prepare_jitless(
                                                nativePaths, Int32(paths.count), cachePath,
                                                p12.baseAddress, p12.count, password, tag,
                                                identifier, executable,
                                                errorBuffer.baseAddress, errorBuffer.count
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        guard result >= 0 else {
            let message = error.withUnsafeBufferPointer { buffer -> String in
                guard let base = buffer.baseAddress, base.pointee != 0 else {
                    return "Husk could not convert or sign the APK's ARM64 native libraries."
                }
                return String(cString: base)
            }
            throw PreparationError.nativeFailure(message)
        }
        return Int(result)
    }

    /// Configure the loader before launch. AOT directories are only activated after
    /// the required library set has been completely prepared and signed.
    static func configure(enabled: Bool,
                          bundledFrameworks: URL? = Bundle.main.privateFrameworksURL) throws {
        try FileManager.default.createDirectory(at: cacheDirectory,
                                                withIntermediateDirectories: true)
        let configured = cacheDirectory.path.withCString { cachePath in
            if let bundledFrameworks {
                return bundledFrameworks.path.withCString { frameworksPath in
                    infinity_husk_configure_jitless(enabled, cachePath, frameworksPath)
                }
            }
            return infinity_husk_configure_jitless(enabled, cachePath, nil)
        }
        guard configured else {
            throw PreparationError.nativeFailure(
                enabled
                    ? "JIT-less mode could not be enabled. Confirm the AOT cache and bundled frameworks are readable."
                    : "JIT-less mode could not be disabled while a runtime session is active."
            )
        }
    }

    /// Classify only Husk's explicit executable-memory denial messages. Generic
    /// loader, graphics, DEX, ELF, memory, and crash messages are never JIT errors.
    static func classifyFailure(log: String, jitlessEnabled: Bool) -> FailureClassification {
        let normalized = log.lowercased()
        if normalized.contains("no stikdebug jit region:") ||
            normalized.contains("this process cannot make executable memory for itself") {
            return .confirmedJITRequired
        }
        if jitlessEnabled &&
            normalized.contains("executable memory is turned off (tl_no_xmem)") {
            return .jitlessAOTUnavailable
        }
        return .other
    }

    static func failureMessage(logURL: URL?, jitlessEnabled: Bool) -> String {
        guard let logURL,
              let log = try? String(contentsOf: logURL, encoding: .utf8) else {
            return "The Android runtime failed. No confirmed JIT restriction was found; inspect the session log for the actual cause."
        }

        switch classifyFailure(log: log, jitlessEnabled: jitlessEnabled) {
        case .confirmedJITRequired:
            return "Confirmed iOS executable-memory restriction. External StikDebug may attach to INFINITY's process. Strata's current built-in JIT path requires a separate guest process and is not yet connected to this in-process APK runtime."
        case .jitlessAOTUnavailable:
            return "Husk JIT-less mode blocked an executable-memory request. This indicates the current APK path needs executable memory or an AOT-compatible library; it does not identify a specific missing library. External StikDebug may attach to INFINITY's process. Strata's built-in JIT currently requires a separate guest process and is not connected to this APK runtime."
        case .other:
            return "The Android runtime failed, but its log does not confirm a JIT restriction. This may be an APK, DEX, ELF, Android API, graphics, audio, or memory issue. Check the session log."
        }
    }
}
