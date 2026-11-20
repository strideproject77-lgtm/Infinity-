import Foundation
import CryptoKit

struct INFINITYAPKInstalledApp: Codable, Hashable, Identifiable, Sendable {
    let packageName: String
    let displayName: String
    let versionName: String?
    let versionCode: UInt64?
    let launchActivity: String?
    let archiveBytes: UInt64
    let nativeLibraries: [String]
    let detectedEngine: String?
    let requiresSplits: Bool
    let splitAPKCount: Int
    let installedAt: Date

    private enum CodingKeys: String, CodingKey {
        case packageName, displayName, versionName, versionCode, launchActivity
        case archiveBytes, nativeLibraries, detectedEngine, requiresSplits, splitAPKCount, installedAt
    }

    init(packageName: String,
         displayName: String,
         versionName: String?,
         versionCode: UInt64?,
         launchActivity: String?,
         archiveBytes: UInt64,
         nativeLibraries: [String],
         detectedEngine: String?,
         requiresSplits: Bool,
         splitAPKCount: Int = 0,
         installedAt: Date) {
        self.packageName = packageName
        self.displayName = displayName
        self.versionName = versionName
        self.versionCode = versionCode
        self.launchActivity = launchActivity
        self.archiveBytes = archiveBytes
        self.nativeLibraries = nativeLibraries
        self.detectedEngine = detectedEngine
        self.requiresSplits = requiresSplits
        self.splitAPKCount = splitAPKCount
        self.installedAt = installedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        packageName = try values.decode(String.self, forKey: .packageName)
        displayName = try values.decode(String.self, forKey: .displayName)
        versionName = try values.decodeIfPresent(String.self, forKey: .versionName)
        versionCode = try values.decodeIfPresent(UInt64.self, forKey: .versionCode)
        launchActivity = try values.decodeIfPresent(String.self, forKey: .launchActivity)
        archiveBytes = try values.decode(UInt64.self, forKey: .archiveBytes)
        nativeLibraries = try values.decode([String].self, forKey: .nativeLibraries)
        detectedEngine = try values.decodeIfPresent(String.self, forKey: .detectedEngine)
        requiresSplits = try values.decodeIfPresent(Bool.self, forKey: .requiresSplits) ?? false
        splitAPKCount = try values.decodeIfPresent(Int.self, forKey: .splitAPKCount) ?? 0
        installedAt = try values.decode(Date.self, forKey: .installedAt)
    }

    var id: String { packageName }
}

struct INFINITYAPKNativeRuntimeBundle: Sendable {
    let systemRoot: URL
    let certificatesDirectory: URL
    let angleLibrary: URL
    let certificateBundle: URL
}

struct INFINITYAPKRuntimeBundle: Sendable {
    let javaRoot: URL
    let systemRoot: URL
    let certificatesDirectory: URL
    let angleLibrary: URL
    let certificateBundle: URL
}

enum INFINITYAPKStore {
    private struct RuntimeAssetManifest: Decodable {
        struct PayloadFile: Decodable {
            let path: String
            let size: UInt64
            let sha256: String
        }

        let format: Int
        let payloadFiles: [PayloadFile]

        enum CodingKeys: String, CodingKey {
            case format
            case payloadFiles = "payload_files"
        }
    }

    enum StoreError: LocalizedError {
        case invalidManifest
        case invalidPackageName
        case incompleteArchive
        case missingInstalledAPK
        case missingRuntimeAssets
        case unsupportedPackageFormat
        case missingBaseAPK
        case ambiguousBaseAPK
        case missingSplitPackages
        case invalidSplitPackage
        case tooManySplitPackages
        case runtimeAssetRollbackFailed(String)
        case invalidRuntimeArchive
        case runtimeArchiveTooLarge

        var errorDescription: String? {
            switch self {
            case .invalidManifest: return "The APK manifest could not be decoded. The package was not installed."
            case .invalidPackageName: return "The APK has an invalid Android package identifier."
            case .incompleteArchive: return "The selected archive is missing its Android manifest or executable content."
            case .missingInstalledAPK: return "The installed APK file is missing. Remove this entry and import it again."
            case .missingRuntimeAssets: return "The Android Java runtime or ANGLE graphics assets are not installed yet."
            case .unsupportedPackageFormat: return "Supported Android packages are .apk, .xapk, .apks and .apkm. Android App Bundles (.aab) and OBB files are not directly installable."
            case .missingBaseAPK: return "The selected package archive does not contain a base APK."
            case .ambiguousBaseAPK: return "The selected package archive contains multiple possible base APKs and cannot be imported safely."
            case .missingSplitPackages: return "This app requires split APKs, but its installed package is missing one or more split files. Re-import the complete XAPK/APKS/APKM package."
            case .invalidSplitPackage: return "A split APK does not match the base package name or version, or its manifest is invalid. The package was not launched."
            case .tooManySplitPackages: return "This package contains more split APKs than the Husk loader can accept (maximum 47 plus the base APK)."
            case .runtimeAssetRollbackFailed(let recovery): return "The runtime update failed and the previous assets could not be fully restored. Recovery data was preserved at: \(recovery)"
            }
        }
    }

    /// Husk's loader accepts 48 APK containers total, including the base APK.
    static let maximumSplitAPKCount = 47

    private static let indexName = "installed-apks.json"
    private static let fileManager = FileManager.default

    static var root: URL {
        LCPath.docPath.appendingPathComponent("Strata3/AndroidApps", isDirectory: true)
    }

    static var runtimeRoot: URL {
        LCPath.docPath.appendingPathComponent("Strata3/AndroidRuntime", isDirectory: true)
    }

    static var hasEmbeddedAngle: Bool {
        guard let embedded = Bundle.main.privateFrameworksURL?.appendingPathComponent("libANGLE-shared.dylib") else {
            return false
        }
        return fileManager.isReadableFile(atPath: embedded.path)
    }

    static var hasEmbeddedMoltenVK: Bool {
        guard let embedded = Bundle.main.privateFrameworksURL?.appendingPathComponent("libMoltenVK.dylib") else {
            return false
        }
        return fileManager.isReadableFile(atPath: embedded.path)
    }

    static var angleLibraryURL: URL {
        Bundle.main.privateFrameworksURL?.appendingPathComponent("libANGLE-shared.dylib")
            ?? runtimeRoot.appendingPathComponent("libANGLE-shared.dylib")
    }

    static var isANGLEEmbeddedAndReadable: Bool {
        guard let embedded = Bundle.main.privateFrameworksURL?.appendingPathComponent("libANGLE-shared.dylib") else {
            return false
        }
        return fileManager.isReadableFile(atPath: embedded.path)
    }

    static var moltenVKLibraryURL: URL {
        Bundle.main.privateFrameworksURL?.appendingPathComponent("libMoltenVK.dylib")
            ?? runtimeRoot.appendingPathComponent("libMoltenVK.dylib")
    }

    static var isMoltenVKEmbeddedAndReadable: Bool {
        guard let embedded = Bundle.main.privateFrameworksURL?.appendingPathComponent("libMoltenVK.dylib") else {
            return false
        }
        return fileManager.isReadableFile(atPath: embedded.path)
    }

    static func installedApps() throws -> [INFINITYAPKInstalledApp] {
        try ensureRoot()
        let index = root.appendingPathComponent(indexName)
        guard fileManager.fileExists(atPath: index.path) else { return [] }
        let data = try Data(contentsOf: index)
        let records = try JSONDecoder().decode([INFINITYAPKInstalledApp].self, from: data)
        return records.filter {
            isValidPackageName($0.packageName) && fileManager.fileExists(atPath: apkURL(for: $0).path)
        }.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    @discardableResult
    static func install(from source: URL) throws -> INFINITYAPKInstalledApp {
        let fileExtension = source.pathExtension.lowercased()
        guard ["apk", "xapk", "apks", "apkm"].contains(fileExtension) else {
            throw StoreError.unsupportedPackageFormat
        }
        if fileExtension != "apk" { return try installPackageArchive(from: source) }

        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        try ensureRoot()
        let stage = root.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
        let finalAPK = stage.appendingPathComponent("base.apk")
        try fileManager.createDirectory(at: stage, withIntermediateDirectories: true)
        do {
            try fileManager.copyItem(at: source, to: finalAPK)
            let inspection = try INFINITYAPKInspection.inspect(url: finalAPK)
            guard inspection.hasManifest, !inspection.dexFiles.isEmpty, !inspection.entries.isEmpty else {
                throw StoreError.incompleteArchive
            }
            guard let manifest = inspection.manifest else { throw StoreError.invalidManifest }
            guard Self.isValidPackageName(manifest.packageName) else { throw StoreError.invalidPackageName }
            let engine = Self.detectEngine(inspection)
            let requiresSplits = finalAPK.path.withCString { infinity_husk_apk_requires_splits($0) }
            let record = INFINITYAPKInstalledApp(
                packageName: manifest.packageName,
                displayName: manifest.applicationLabel?.isEmpty == false
                    ? manifest.applicationLabel!
                    : source.deletingPathExtension().lastPathComponent,
                versionName: manifest.versionName,
                versionCode: manifest.versionCode,
                launchActivity: manifest.launchActivity,
                archiveBytes: inspection.archiveBytes,
                nativeLibraries: inspection.nativeLibraries,
                detectedEngine: engine,
                requiresSplits: requiresSplits,
                installedAt: Date()
            )

            let finalDirectory = root.appendingPathComponent(record.packageName, isDirectory: true)
            let backupDirectory = root.appendingPathComponent(".rollback-\(UUID().uuidString)", isDirectory: true)
            let hadPrevious = fileManager.fileExists(atPath: finalDirectory.path)
            if hadPrevious {
                try fileManager.moveItem(at: finalDirectory, to: backupDirectory)
            }

            do {
                try fileManager.moveItem(at: stage, to: finalDirectory)
                var records = try Self.readIndex()
                records.removeAll { $0.packageName == record.packageName }
                records.append(record)
                try Self.writeIndex(records)
                if hadPrevious { try? fileManager.removeItem(at: backupDirectory) }
            } catch {
                try? fileManager.removeItem(at: finalDirectory)
                if hadPrevious, fileManager.fileExists(atPath: backupDirectory.path) {
                    try? fileManager.moveItem(at: backupDirectory, to: finalDirectory)
                }
                throw error
            }
            return record
        } catch {
            try? fileManager.removeItem(at: stage)
            throw error
        }
    }


    /// Imports XAPK, APKS and APKM ZIP containers. The base APK and every
    /// accompanying split APK are preserved in the package directory. Husk's
    /// shared linker queues these splits for every engine before the base APK
    /// is opened, so incomplete sets are never launched as base-only packages.
    private static func installPackageArchive(from source: URL) throws -> INFINITYAPKInstalledApp {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let container = try INFINITYAPKInspection.inspect(url: source)
        let apkEntries = container.entries.filter { $0.path.lowercased().hasSuffix(".apk") }
        guard !apkEntries.isEmpty else { throw StoreError.missingBaseAPK }

        let preferred = apkEntries.filter {
            let name = URL(fileURLWithPath: $0.path).lastPathComponent.lowercased()
            return name == "base.apk" || name == "base-master.apk"
        }
        let baseEntry: INFINITYAPKInspection.Entry
        if preferred.count == 1 {
            baseEntry = preferred[0]
        } else if preferred.count > 1 {
            throw StoreError.ambiguousBaseAPK
        } else if apkEntries.count == 1, let only = apkEntries.first {
            baseEntry = only
        } else {
            throw StoreError.missingBaseAPK
        }

        try ensureRoot()
        let stage = root.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
        let baseURL = stage.appendingPathComponent("base.apk")
        let splitEntries = apkEntries.filter { $0.path != baseEntry.path }
        guard splitEntries.count <= maximumSplitAPKCount else {
            throw StoreError.tooManySplitPackages
        }
        let splitDirectory = stage.appendingPathComponent("splits", isDirectory: true)
        try fileManager.createDirectory(at: stage, withIntermediateDirectories: true)
        do {
            if !splitEntries.isEmpty {
                try fileManager.createDirectory(at: splitDirectory, withIntermediateDirectories: true)
            }
            let entries = [baseEntry] + splitEntries
            for (index, entry) in entries.enumerated() {
                let destination = index == 0
                    ? baseURL
                    : splitDirectory.appendingPathComponent(String(format: "split-%03d.apk", index))
                let status = source.path.withCString { archivePath in
                    entry.path.withCString { entryName in
                        destination.path.withCString { outputPath in
                            infinity_apk_extract_entry_to_file(archivePath, entryName, outputPath)
                        }
                    }
                }
                guard status == 0 else {
                    throw StoreError.incompleteArchive
                }
            }

            let inspection = try INFINITYAPKInspection.inspect(url: baseURL)
            guard inspection.hasManifest, !inspection.dexFiles.isEmpty, !inspection.entries.isEmpty else {
                throw StoreError.incompleteArchive
            }
            guard let manifest = inspection.manifest else { throw StoreError.invalidManifest }
            guard Self.isValidPackageName(manifest.packageName) else { throw StoreError.invalidPackageName }
            let engine = Self.detectEngine(inspection)
            let requiresSplits = !splitEntries.isEmpty ||
                baseURL.path.withCString { infinity_husk_apk_requires_splits($0) }
            let record = INFINITYAPKInstalledApp(
                packageName: manifest.packageName,
                displayName: manifest.applicationLabel?.isEmpty == false
                    ? manifest.applicationLabel!
                    : source.deletingPathExtension().lastPathComponent,
                versionName: manifest.versionName,
                versionCode: manifest.versionCode,
                launchActivity: manifest.launchActivity,
                archiveBytes: inspection.archiveBytes,
                nativeLibraries: inspection.nativeLibraries,
                detectedEngine: engine,
                requiresSplits: requiresSplits,
                splitAPKCount: splitEntries.count,
                installedAt: Date()
            )

            let finalDirectory = root.appendingPathComponent(record.packageName, isDirectory: true)
            let backupDirectory = root.appendingPathComponent(".rollback-\(UUID().uuidString)", isDirectory: true)
            let hadPrevious = fileManager.fileExists(atPath: finalDirectory.path)
            if hadPrevious { try fileManager.moveItem(at: finalDirectory, to: backupDirectory) }
            do {
                try fileManager.moveItem(at: stage, to: finalDirectory)
                var records = try Self.readIndex()
                records.removeAll { $0.packageName == record.packageName }
                records.append(record)
                try Self.writeIndex(records)
                if hadPrevious { try? fileManager.removeItem(at: backupDirectory) }
            } catch {
                try? fileManager.removeItem(at: finalDirectory)
                if hadPrevious, fileManager.fileExists(atPath: backupDirectory.path) {
                    try? fileManager.moveItem(at: backupDirectory, to: finalDirectory)
                }
                throw error
            }
            return record
        } catch {
            try? fileManager.removeItem(at: stage)
            throw error
        }
    }

    static func remove(packageName: String) throws {
        guard isValidPackageName(packageName) else { throw StoreError.invalidPackageName }
        try ensureRoot()
        let directory = root.appendingPathComponent(packageName, isDirectory: true).standardizedFileURL
        guard directory.path.hasPrefix(root.standardizedFileURL.path + "/") else {
            throw StoreError.invalidPackageName
        }
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        let dataDirectory = root.appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent(packageName, isDirectory: true).standardizedFileURL
        if dataDirectory.path.hasPrefix(root.standardizedFileURL.path + "/"),
           fileManager.fileExists(atPath: dataDirectory.path) {
            try fileManager.removeItem(at: dataDirectory)
        }
        var records = try readIndex()
        records.removeAll { $0.packageName == packageName }
        try writeIndex(records)
    }

    static func apkURL(for app: INFINITYAPKInstalledApp) -> URL {
        root.appendingPathComponent(app.packageName, isDirectory: true).appendingPathComponent("base.apk")
    }

    /// Finds and validates the complete split APK set for an installed package.
    /// The common Husk APK linker consumes these for Java and native engines.
    static func splitAPKURLs(for app: INFINITYAPKInstalledApp) throws -> [URL] {
        guard isValidPackageName(app.packageName) else { throw StoreError.invalidPackageName }
        let packageDirectory = root.appendingPathComponent(app.packageName, isDirectory: true).standardizedFileURL
        guard packageDirectory.path.hasPrefix(root.standardizedFileURL.path + "/") else {
            throw StoreError.invalidPackageName
        }
        let splitDirectory = packageDirectory.appendingPathComponent("splits", isDirectory: true)
        let baseURL = apkURL(for: app)
        guard fileManager.isReadableFile(atPath: baseURL.path) else {
            throw StoreError.missingInstalledAPK
        }

        let urls: [URL]
        if fileManager.fileExists(atPath: splitDirectory.path) {
            let values = try fileManager.contentsOfDirectory(
                at: splitDirectory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
            urls = values.filter { url in
                guard url.pathExtension.lowercased() == "apk",
                      let resource = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
                    return false
                }
                return resource.isRegularFile == true && resource.isSymbolicLink != true
            }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        } else {
            urls = []
        }

        guard urls.count == app.splitAPKCount else {
            if app.requiresSplits || app.splitAPKCount > 0 { throw StoreError.missingSplitPackages }
            return []
        }
        guard urls.count <= maximumSplitAPKCount else { throw StoreError.tooManySplitPackages }
        guard !app.requiresSplits || !urls.isEmpty else { throw StoreError.missingSplitPackages }
        guard !urls.isEmpty else { return [] }

        let baseInspection = try INFINITYAPKInspection.inspect(url: baseURL)
        guard let baseManifest = baseInspection.manifest else { throw StoreError.invalidManifest }
        for url in urls {
            let standardized = url.standardizedFileURL
            guard standardized.path.hasPrefix(splitDirectory.standardizedFileURL.path + "/") else {
                throw StoreError.invalidPackageName
            }
            let inspection = try INFINITYAPKInspection.inspect(url: standardized)
            guard inspection.hasManifest,
                  let manifest = inspection.manifest,
                  manifest.packageName == baseManifest.packageName,
                  manifest.packageName == app.packageName,
                  (manifest.versionCode == nil || baseManifest.versionCode == nil ||
                   manifest.versionCode == baseManifest.versionCode) else {
                throw StoreError.invalidSplitPackage
            }
        }
        return urls
    }

    static func dataURL(for app: INFINITYAPKInstalledApp) throws -> URL {
        let directory = root.appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent(app.packageName, isDirectory: true).standardizedFileURL
        guard directory.path.hasPrefix(root.standardizedFileURL.path + "/") else {
            throw StoreError.invalidPackageName
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func nativeRuntimeBundle() -> INFINITYAPKNativeRuntimeBundle? {
        let system = runtimeRoot.appendingPathComponent("android-system", isDirectory: true)
        let certificates = system.appendingPathComponent("cacerts", isDirectory: true)
        let angle = angleLibraryURL
        let caBundle = runtimeRoot.appendingPathComponent("cacert.pem")
        let fontFiles = system.appendingPathComponent("fonts", isDirectory: true)
        guard fileManager.fileExists(atPath: certificates.path),
              (try? fileManager.contentsOfDirectory(at: certificates, includingPropertiesForKeys: nil).isEmpty) == false,
              fileManager.fileExists(atPath: fontFiles.path),
              fileManager.isReadableFile(atPath: system.appendingPathComponent("etc/fonts.xml").path),
              fileManager.isReadableFile(atPath: system.appendingPathComponent("etc/font_fallback.xml").path),
              hasEmbeddedAngle,
              fileManager.isReadableFile(atPath: caBundle.path) else {
            return nil
        }
        return INFINITYAPKNativeRuntimeBundle(systemRoot: system,
                                              certificatesDirectory: certificates,
                                              angleLibrary: angle,
                                              certificateBundle: caBundle)
    }

    static func runtimeDataReady() -> Bool {
        hasJavaRuntimeAssets(at: runtimeRoot) && hasAndroidSystemAssets(at: runtimeRoot)
    }

    static func runtimeBundle() -> INFINITYAPKRuntimeBundle? {
        guard let native = nativeRuntimeBundle() else { return nil }
        let java = runtimeRoot.appendingPathComponent("java-runtime", isDirectory: true)
        let required = [
            "com.android.art/javalib/core-oj.jar",
            "com.android.art/javalib/core-libart.jar",
            "com.android.art/javalib/okhttp.jar",
            "com.android.art/javalib/bouncycastle.jar",
            "com.android.art/javalib/apache-xml.jar",
            "com.android.art/lib64/libandroidio.so",
            "com.android.art/lib64/libbase.so",
            "com.android.art/lib64/libc++.so",
            "com.android.art/lib64/libexpat.so",
            "com.android.art/lib64/libjavacore.so",
            "com.android.art/lib64/libnativehelper.so",
            "com.android.art/lib64/libopenjdk.so",
            "com.android.i18n/javalib/core-icu4j.jar",
            "com.android.conscrypt/javalib/conscrypt.jar",
            "com.android.conscrypt/lib64/libjavacrypto.so",
            "com.android.conscrypt/lib64/libcrypto.so",
            "com.android.conscrypt/lib64/libssl.so",
            "husk-framework.dex",
            "husk-framework-core.dex",
            "org.apache.http.legacy.jar",
            "framework-res.apk"
        ]
        guard required.allSatisfy({ fileManager.isReadableFile(atPath: java.appendingPathComponent($0).path) }),
              fileManager.fileExists(atPath: java.appendingPathComponent("com.android.i18n/etc/icu").path),
              fileManager.fileExists(atPath: java.appendingPathComponent("com.android.tzdata/etc").path) else {
            return nil
        }
        return INFINITYAPKRuntimeBundle(javaRoot: java,
                                        systemRoot: native.systemRoot,
                                        certificatesDirectory: native.certificatesDirectory,
                                        angleLibrary: native.angleLibrary,
                                        certificateBundle: native.certificateBundle)
    }

    /// Installs a prepared runtime-data folder exported by the INFINITY asset workflow.
    /// The folder must contain java-runtime/, android-system/ and cacert.pem.
    /// ANGLE remains an app-bundled, code-signed dependency and is not installed here.
    static func installRuntimeAssets(from source: URL) throws {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let sourceRoot = source.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceRoot.path, isDirectory: &isDirectory) else {
            throw StoreError.missingRuntimeAssets
        }
        if !isDirectory.boolValue {
            guard sourceRoot.pathExtension.lowercased() == "zip" else {
                throw StoreError.invalidRuntimeArchive
            }
            try fileManager.createDirectory(at: runtimeRoot, withIntermediateDirectories: true)
            let extractionRoot = runtimeRoot.appendingPathComponent(
                ".runtime-import-\(UUID().uuidString)", isDirectory: true
            )
            try fileManager.createDirectory(at: extractionRoot, withIntermediateDirectories: true)
            do {
                try extractRuntimeAssetsArchive(from: sourceRoot, to: extractionRoot)
                try installRuntimeAssets(from: extractionRoot)
                try? fileManager.removeItem(at: extractionRoot)
            } catch {
                try? fileManager.removeItem(at: extractionRoot)
                throw error
            }
            return
        }
        guard hasJavaRuntimeAssets(at: sourceRoot),
              hasAndroidSystemAssets(at: sourceRoot) else {
            throw StoreError.missingRuntimeAssets
        }

        try fileManager.createDirectory(at: runtimeRoot, withIntermediateDirectories: true)
        let stage = runtimeRoot.appendingPathComponent(".runtime-stage-\(UUID().uuidString)", isDirectory: true)
        let backup = runtimeRoot.appendingPathComponent(".runtime-backup-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stage, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: backup, withIntermediateDirectories: true)

        let components = ["java-runtime", "android-system", "cacert.pem"]
        do {
            for name in components {
                try fileManager.copyItem(at: sourceRoot.appendingPathComponent(name),
                                         to: stage.appendingPathComponent(name))
            }
            guard hasJavaRuntimeAssets(at: stage), hasAndroidSystemAssets(at: stage) else {
                throw StoreError.missingRuntimeAssets
            }

            var movedOld: [String] = []
            var movedNew: [String] = []
            do {
                for name in components {
                    let current = runtimeRoot.appendingPathComponent(name)
                    if fileManager.fileExists(atPath: current.path) {
                        try fileManager.moveItem(at: current, to: backup.appendingPathComponent(name))
                        movedOld.append(name)
                    }
                }
                for name in components {
                    try fileManager.moveItem(at: stage.appendingPathComponent(name),
                                             to: runtimeRoot.appendingPathComponent(name))
                    movedNew.append(name)
                }
            } catch {
                var rollbackFailures: [String] = []
                for name in movedNew {
                    do {
                        try fileManager.removeItem(at: runtimeRoot.appendingPathComponent(name))
                    } catch {
                        rollbackFailures.append("remove \(name): \(error.localizedDescription)")
                    }
                }
                for name in movedOld {
                    do {
                        try fileManager.moveItem(at: backup.appendingPathComponent(name),
                                                 to: runtimeRoot.appendingPathComponent(name))
                    } catch {
                        rollbackFailures.append("restore \(name): \(error.localizedDescription)")
                    }
                }
                if rollbackFailures.isEmpty {
                    try? fileManager.removeItem(at: backup)
                } else {
                    // Never delete the only remaining copy of a previous runtime component.
                    let recovery = backup.path + " (" + rollbackFailures.joined(separator: "; ") + ")"
                    throw StoreError.runtimeAssetRollbackFailed(recovery)
                }
                throw error
            }
            try? fileManager.removeItem(at: backup)
            try? fileManager.removeItem(at: stage)
        } catch {
            try? fileManager.removeItem(at: stage)
            // A non-empty backup may be the only surviving copy after a failed rollback.
            if (try? fileManager.contentsOfDirectory(at: backup, includingPropertiesForKeys: nil).isEmpty) == true {
                try? fileManager.removeItem(at: backup)
            }
            throw error
        }
    }

    /// Extracts only the known runtime payload paths from the official builder ZIP.
    /// ZIP entry names are validated by INFINITYAPKInspection before any file is written.
    private static func extractRuntimeAssetsArchive(from archive: URL, to destinationRoot: URL) throws {
        let inspection: INFINITYAPKInspection
        do {
            inspection = try INFINITYAPKInspection.inspect(url: archive)
        } catch {
            throw StoreError.invalidRuntimeArchive
        }
        guard !inspection.entries.isEmpty else { throw StoreError.invalidRuntimeArchive }

        let root = destinationRoot.standardizedFileURL
        var totalBytes: UInt64 = 0
        let maximumTotalBytes: UInt64 = 8 * 1024 * 1024 * 1024
        let maximumEntryBytes: UInt64 = 1024 * 1024 * 1024

        for entry in inspection.entries {
            // Optional ART support is not consumed by the iOS host runtime.
            if entry.path.hasPrefix("art-support/") { continue }
            let isManifest = entry.path == "runtime-assets-manifest.json"
            let isRuntimePath = isManifest || entry.path == "cacert.pem" ||
                entry.path.hasPrefix("java-runtime/") ||
                entry.path.hasPrefix("android-system/")
            guard isRuntimePath else { throw StoreError.invalidRuntimeArchive }

            let (nextTotal, overflow) = totalBytes.addingReportingOverflow(entry.uncompressedSize)
            let entryLimit = isManifest ? UInt64(4 * 1024 * 1024) : maximumEntryBytes
            guard !overflow, nextTotal <= maximumTotalBytes,
                  entry.uncompressedSize <= entryLimit else {
                throw StoreError.runtimeArchiveTooLarge
            }
            totalBytes = nextTotal

            let output = root.appendingPathComponent(entry.path).standardizedFileURL
            guard output.path.hasPrefix(root.path + "/") else {
                throw StoreError.invalidRuntimeArchive
            }
            try fileManager.createDirectory(at: output.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
            let status = archive.path.withCString { archivePath in
                entry.path.withCString { entryName in
                    output.path.withCString { outputPath in
                        infinity_apk_extract_entry_to_file(archivePath, entryName, outputPath)
                    }
                }
            }
            guard status == 0 else { throw StoreError.invalidRuntimeArchive }
        }

        try validateRuntimeArchiveManifest(at: root)
        guard hasJavaRuntimeAssets(at: root), hasAndroidSystemAssets(at: root) else {
            throw StoreError.missingRuntimeAssets
        }
    }

    /// Verify every core payload file against the SHA-256 inventory produced by
    /// build_infinity_runtime_assets.sh before the data can replace an installed runtime.
    private static func validateRuntimeArchiveManifest(at root: URL) throws {
        let manifestURL = root.appendingPathComponent("runtime-assets-manifest.json")
        guard fileManager.isReadableFile(atPath: manifestURL.path) else {
            throw StoreError.invalidRuntimeArchive
        }
        let data = try Data(contentsOf: manifestURL, options: [.mappedIfSafe])
        guard data.count <= 4 * 1024 * 1024 else { throw StoreError.runtimeArchiveTooLarge }
        let manifest: RuntimeAssetManifest
        do {
            manifest = try JSONDecoder().decode(RuntimeAssetManifest.self, from: data)
        } catch {
            throw StoreError.invalidRuntimeArchive
        }
        guard manifest.format == 1, !manifest.payloadFiles.isEmpty else {
            throw StoreError.invalidRuntimeArchive
        }

        let allowedRoots = ["java-runtime/", "android-system/"]
        var expected: [String: RuntimeAssetManifest.PayloadFile] = [:]
        for item in manifest.payloadFiles {
            let path = item.path
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard path == "cacert.pem" ||
                    (allowedRoots.contains(where: { path.hasPrefix($0) }) &&
                     !path.hasPrefix("/") && !path.contains("\\") &&
                     components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
                  item.sha256.range(of: "^[0-9a-fA-F]{64}$", options: .regularExpression) != nil,
                  expected[path] == nil else {
                throw StoreError.invalidRuntimeArchive
            }
            expected[path] = item
        }

        var actualPaths = Set<String>()
        for top in ["java-runtime", "android-system", "cacert.pem"] {
            let topURL = root.appendingPathComponent(top)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: topURL.path, isDirectory: &isDirectory) else {
                throw StoreError.missingRuntimeAssets
            }
            if isDirectory.boolValue {
                guard let enumerator = fileManager.enumerator(
                    at: topURL,
                    includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                    options: []
                ) else { throw StoreError.invalidRuntimeArchive }
                for case let fileURL as URL in enumerator {
                    let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    if values.isSymbolicLink == true { throw StoreError.invalidRuntimeArchive }
                    guard values.isRegularFile == true else { continue }
                    let relative = String(fileURL.standardizedFileURL.path.dropFirst(root.path.count + 1))
                    actualPaths.insert(relative)
                }
            } else {
                actualPaths.insert(top)
            }
        }
        guard actualPaths == Set(expected.keys) else { throw StoreError.invalidRuntimeArchive }

        for (path, item) in expected {
            let fileURL = root.appendingPathComponent(path)
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  let fileSize = values.fileSize, fileSize >= 0,
                  UInt64(fileSize) == item.size else {
                throw StoreError.invalidRuntimeArchive
            }
            let digest = try sha256Hex(of: fileURL)
            guard digest.caseInsensitiveCompare(item.sha256) == .orderedSame else {
                throw StoreError.invalidRuntimeArchive
            }
        }
    }

    private static func sha256Hex(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func hasJavaRuntimeAssets(at root: URL) -> Bool {
        let java = root.appendingPathComponent("java-runtime", isDirectory: true)
        let required = [
            "com.android.art/javalib/core-oj.jar",
            "com.android.art/javalib/core-libart.jar",
            "com.android.art/javalib/okhttp.jar",
            "com.android.art/javalib/bouncycastle.jar",
            "com.android.art/javalib/apache-xml.jar",
            "com.android.art/lib64/libandroidio.so",
            "com.android.art/lib64/libbase.so",
            "com.android.art/lib64/libc++.so",
            "com.android.art/lib64/libexpat.so",
            "com.android.art/lib64/libjavacore.so",
            "com.android.art/lib64/libnativehelper.so",
            "com.android.art/lib64/libopenjdk.so",
            "com.android.i18n/javalib/core-icu4j.jar",
            "com.android.conscrypt/javalib/conscrypt.jar",
            "com.android.conscrypt/lib64/libjavacrypto.so",
            "com.android.conscrypt/lib64/libcrypto.so",
            "com.android.conscrypt/lib64/libssl.so",
            "husk-framework.dex",
            "husk-framework-core.dex",
            "org.apache.http.legacy.jar",
            "framework-res.apk"
        ]
        return required.allSatisfy {
            fileManager.isReadableFile(atPath: java.appendingPathComponent($0).path)
        } && fileManager.fileExists(atPath: java.appendingPathComponent("com.android.i18n/etc/icu").path)
          && fileManager.fileExists(atPath: java.appendingPathComponent("com.android.tzdata/etc").path)
    }

    private static func hasAndroidSystemAssets(at root: URL) -> Bool {
        let system = root.appendingPathComponent("android-system", isDirectory: true)
        let certificates = system.appendingPathComponent("cacerts", isDirectory: true)
        let fonts = system.appendingPathComponent("fonts", isDirectory: true)
        return (try? fileManager.contentsOfDirectory(at: certificates, includingPropertiesForKeys: nil).isEmpty) == false
            && fileManager.fileExists(atPath: fonts.path)
            && fileManager.isReadableFile(atPath: system.appendingPathComponent("etc/fonts.xml").path)
            && fileManager.isReadableFile(atPath: system.appendingPathComponent("etc/font_fallback.xml").path)
            && fileManager.isReadableFile(atPath: root.appendingPathComponent("cacert.pem").path)
    }

    private static func ensureRoot() throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private static func readIndex() throws -> [INFINITYAPKInstalledApp] {
        let url = root.appendingPathComponent(indexName)
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([INFINITYAPKInstalledApp].self, from: Data(contentsOf: url))
    }

    private static func writeIndex(_ records: [INFINITYAPKInstalledApp]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: root.appendingPathComponent(indexName), options: .atomic)
    }

    private static func isValidPackageName(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$",
                    options: .regularExpression) != nil
    }

    private static func detectEngine(_ inspection: INFINITYAPKInspection) -> String? {
        let names = Set(inspection.nativeLibraries.map { URL(fileURLWithPath: $0).lastPathComponent.lowercased() })
        if names.contains("libunity.so") { return "unity" }
        if names.contains("libue4.so") || names.contains("libunreal.so") { return "unreal" }
        if names.contains("libgodot_android.so") || names.contains("libgodot.so") { return "godot" }
        if names.contains("libyoyo.so") { return "gameMaker" }
        if names.contains("libflutter.so") { return "flutter" }
        if names.contains("libcocos2dcpp.so") { return "cocos" }
        if names.contains("libsdl2.so") || names.contains("libsdl3.so") { return "sdl" }
        if names.contains("libminecraftpe.so") || names.contains("libgameactivity.so") { return "gameActivity" }
        if inspection.dexFiles.isEmpty == false { return "java" }
        return nil
    }
}
