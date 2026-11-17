import Foundation

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
    let installedAt: Date

    private enum CodingKeys: String, CodingKey {
        case packageName, displayName, versionName, versionCode, launchActivity
        case archiveBytes, nativeLibraries, detectedEngine, requiresSplits, installedAt
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
    enum StoreError: LocalizedError {
        case invalidManifest
        case invalidPackageName
        case incompleteArchive
        case missingInstalledAPK
        case missingRuntimeAssets

        var errorDescription: String? {
            switch self {
            case .invalidManifest: return "The APK manifest could not be decoded. The package was not installed."
            case .invalidPackageName: return "The APK has an invalid Android package identifier."
            case .incompleteArchive: return "The selected archive is missing its Android manifest or executable content."
            case .missingInstalledAPK: return "The installed APK file is missing. Remove this entry and import it again."
            case .missingRuntimeAssets: return "The Android Java runtime or ANGLE graphics assets are not installed yet."
            }
        }
    }

    private static let indexName = "installed-apks.json"
    private static let fileManager = FileManager.default

    static var root: URL {
        LCPath.docPath.appendingPathComponent("Strata3/AndroidApps", isDirectory: true)
    }

    static var runtimeRoot: URL {
        LCPath.docPath.appendingPathComponent("Strata3/AndroidRuntime", isDirectory: true)
    }

    static var angleLibraryURL: URL {
        if let embedded = Bundle.main.privateFrameworksURL?.appendingPathComponent("libANGLE-shared.dylib"),
           fileManager.isReadableFile(atPath: embedded.path) {
            return embedded
        }
        return runtimeRoot.appendingPathComponent("libANGLE-shared.dylib")
    }

    static var moltenVKLibraryURL: URL {
        if let embedded = Bundle.main.privateFrameworksURL?.appendingPathComponent("libMoltenVK.dylib"),
           fileManager.isReadableFile(atPath: embedded.path) {
            return embedded
        }
        return runtimeRoot.appendingPathComponent("libMoltenVK.dylib")
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
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        try ensureRoot()
        let stage = root.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
        let finalAPK = stage.appendingPathComponent("base.apk")
        try fileManager.createDirectory(at: stage, withIntermediateDirectories: true)
        do {
            try fileManager.copyItem(at: source, to: finalAPK)
            let inspection = try INFINITYAPKInspection.inspect(url: finalAPK)
            guard inspection.hasManifest, !inspection.entries.isEmpty else {
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
              fileManager.isReadableFile(atPath: angle.path),
              fileManager.isReadableFile(atPath: caBundle.path) else {
            return nil
        }
        return INFINITYAPKNativeRuntimeBundle(systemRoot: system,
                                              certificatesDirectory: certificates,
                                              angleLibrary: angle,
                                              certificateBundle: caBundle)
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
