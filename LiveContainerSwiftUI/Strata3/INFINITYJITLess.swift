import Foundation
import Darwin

/// Thin Swift facade for Husk's ahead-of-time native-library conversion.
/// This does not grant JIT or execute DEX; it prepares signed ARM64 Mach-O
/// dylibs so the native loader can run supported Android .so files without
/// allocating executable memory at runtime.
enum INFINITYJITLess {
    enum PreparationError: LocalizedError {
        case noAPKPaths
        case invalidCertificate
        case pathAllocation
        case nativeFailure(String)

        var errorDescription: String? {
            switch self {
            case .noAPKPaths:
                return "Add at least one APK or Android runtime library before preparing JIT-less mode."
            case .invalidCertificate:
                return "A valid developer PKCS#12 certificate and password are required for JIT-less library signing."
            case .pathAllocation:
                return "Could not prepare the APK paths for native conversion."
            case .nativeFailure(let message):
                return message
            }
        }
    }

    static var cacheDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("INFINITY/JITless", isDirectory: true)
    }

    static var preparedLibraryCount: Int {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path)) ?? []
        return names.filter { $0.hasPrefix("aot-v") && $0.hasSuffix(".dylib") }.count
    }

    /// Convert all arm64-v8a libraries found in the supplied APKs and any
    /// explicitly supplied Java-runtime .so files. Original APKs stay intact.
    /// The PKCS#12 must belong to the same Apple signing team as this app.
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

    /// Must be called before launching an APK. JIT-less mode is only useful
    /// after every required native library has a matching signed AOT dylib.
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
}
