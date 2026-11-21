from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class APKStoreContractTests(unittest.TestCase):
    def read(self, relative: str) -> str:
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_apk_install_is_persistent_and_split_requirements_are_recorded(self):
        store = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKStore.swift")
        self.assertIn("Strata3/AndroidApps", store)
        self.assertIn("installed-apks.json", store)
        self.assertIn("infinity_husk_apk_requires_splits", store)
        self.assertIn("requiresSplits: requiresSplits", store)
        self.assertIn("decodeIfPresent(Bool.self, forKey: .requiresSplits) ?? false", store)

    def test_launch_action_is_visible_even_when_runtime_is_not_ready(self):
        view = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        self.assertIn('Label("Launch", systemImage: "play.fill")', view)
        self.assertIn("INFINITYAPKLaunchView(app: app)", view)
        self.assertNotIn("if canLaunch", view)

    def test_split_required_apps_require_stored_split_payload_before_launch(self):
        view = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        self.assertIn("let splitPackages = try INFINITYAPKStore.splitAPKURLs(for: app)", view)
        self.assertIn("if app.requiresSplits && splitPackages.isEmpty", view)
        self.assertIn("INFINITYAPKStore.StoreError.missingSplitPackages", view)
        self.assertIn("additionalPackages: splitPackages", view)

    def test_native_graphics_are_required_inside_the_signed_app_bundle(self):
        store = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKStore.swift")
        view = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        runtime = self.read("LiveContainerSwiftUI/Strata3/INFINITYHuskRuntime.swift")
        self.assertIn("static var hasEmbeddedAngle", store)
        self.assertIn("static var hasEmbeddedMoltenVK", store)
        self.assertIn("isANGLEEmbeddedAndReadable", store)
        self.assertIn("INFINITYAPKStore.nativeRuntimeMissingAssets()", view)
        self.assertIn("StoreError.missingNativeRuntimeAssets(missingNativeAssets)", view)
        self.assertIn('runtime.recordSessionEvent("NATIVE_RUNTIME_MISSING"', view)
        self.assertIn("angleLibrary.standardizedFileURL == embeddedANGLE", runtime)
        self.assertIn("moltenVKLibrary.standardizedFileURL == embeddedMoltenVK", runtime)

    def test_runtime_preflight_reports_each_missing_host_and_java_asset(self):
        store = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKStore.swift")
        view = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        self.assertIn("static func nativeRuntimeMissingAssets() -> [String]", store)
        self.assertIn("android-system/cacerts/ (non-empty)", store)
        self.assertIn("android-system/fonts/ (non-empty)", store)
        self.assertIn("App.frameworks/libANGLE-shared.dylib", store)
        self.assertIn("static func javaRuntimeMissingAssets() -> [String]", store)
        self.assertIn('"com.android.art/javalib/core-oj.jar"', store)
        self.assertIn('.map { "java-runtime/" + $0 }', store)
        self.assertIn("StoreError.missingJavaRuntimeAssets(missingJavaAssets)", view)
        self.assertIn('runtime.recordSessionEvent("JAVA_RUNTIME_MISSING"', view)

    def test_runtime_data_install_is_staged_and_rollback_safe(self):
        store = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKStore.swift")
        self.assertIn("installRuntimeAssets(from source: URL)", store)
        self.assertIn(".runtime-stage-", store)
        self.assertIn(".runtime-backup-", store)
        self.assertIn("hasJavaRuntimeAssets(at: stage)", store)
        self.assertIn("ANGLE remains an app-bundled, code-signed dependency", store)

    def test_unsigned_runtime_folder_dylibs_are_not_accepted_as_graphics_engines(self):
        store = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKStore.swift")
        runtime = self.read("LiveContainerSwiftUI/Strata3/INFINITYHuskRuntime.swift")
        self.assertIn("isANGLEEmbeddedAndReadable", store)
        self.assertIn("privateFrameworksURL", store)
        self.assertIn("angleLibrary.standardizedFileURL == embeddedANGLE", runtime)
        self.assertIn("moltenVKLibrary.standardizedFileURL == embeddedMoltenVK", runtime)

    def test_runtime_launch_surface_requires_a_sized_metal_drawable(self):
        view = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        self.assertIn("layer.drawableSize.width > 0", view)
        self.assertIn("layer.drawableSize.height > 0", view)
        self.assertIn("isMultipleTouchEnabled = true", view)

    def test_existing_ipa_picker_also_routes_apk_imports_to_the_android_store(self):
        view = self.read("LiveContainerSwiftUI/Views/AppList/LCAppListView.swift")
        self.assertIn('UTType(filenameExtension: "xapk") ?? .data', view)
        self.assertIn('UTType(filenameExtension: "apks") ?? .data', view)
        self.assertIn('UTType(filenameExtension: "apkm") ?? .data', view)
        self.assertIn("startInstallSelectedFile(fileURL)", view)
        self.assertIn('["apk", "xapk", "apks", "apkm"].contains(fileURL.pathExtension.lowercased())', view)
        self.assertIn("INFINITYAPKStore.install(from: fileURL)", view)
        store = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKStore.swift")
        self.assertIn("installPackageArchive(from: source)", store)
        self.assertIn("infinity_apk_extract_entry_to_file", store)
        self.assertIn("splitAPKCount: splitEntries.count", store)
        self.assertIn('Button("Import IPA / APK"', view)

    def test_apkpure_xapk_manifest_selects_named_base_and_orders_all_splits(self):
        store = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKStore.swift")
        self.assertIn('container.entries.contains(where: { $0.path == "manifest.json" })', store)
        self.assertIn('metadata["split_apks"] as? [[String: Any]]', store)
        self.assertIn('identifier == "base"', store)
        self.assertIn("xapkOrderedEntries", store)
        self.assertIn("mapped.count == apkEntries.count", store)
        self.assertIn("xapkPackageName != manifest.packageName", store)
        self.assertIn('rawVersionCode as? NSNumber', store)
        self.assertIn('let stringVersionCode = rawVersionCode as? String', store)
        self.assertIn("splitManifest.packageName == manifest.packageName", store)
        self.assertIn("splitManifest.versionCode == manifest.versionCode", store)

    def test_archive_extractor_streams_embedded_apks_without_large_heap_allocations(self):
        source = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKArchive.c")
        header = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKArchive.h")
        self.assertIn("infinity_apk_extract_entry_to_file", source)
        self.assertIn("inflateInit2(&stream, -MAX_WBITS)", source)
        self.assertIn("munmap((void *)data, length)", source)
        self.assertIn("infinity_apk_extract_entry_to_file", header)

    def test_android_apk_library_lists_and_removes_persisted_imports(self):
        view = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        app_list = self.read("LiveContainerSwiftUI/Views/AppList/LCAppListView.swift")
        self.assertIn("struct INFINITYAPKLibraryView", view)
        self.assertIn("INFINITYAPKStore.installedApps()", view)
        self.assertIn("INFINITYAPKStore.remove(packageName:", view)
        self.assertIn("INFINITYAPKLibraryView()", app_list)

    def test_imported_android_apps_appear_inline_with_the_existing_ipa_management_list(self):
        app_list = self.read("LiveContainerSwiftUI/Views/AppList/LCAppListView.swift")
        self.assertIn("@State private var installedAndroidApps: [INFINITYAPKInstalledApp] = []", app_list)
        self.assertIn("private var filteredAndroidApps: [INFINITYAPKInstalledApp]", app_list)
        self.assertIn('Text("Android Apps")', app_list)
        self.assertIn("INFINITYAPKInstalledAppDetail(app: androidApp)", app_list)
        self.assertIn("refreshInstalledAndroidApps()", app_list)
        self.assertIn("selectedAPKForDetails = installed", app_list)


    def test_runtime_manager_importer_accepts_android_formats_and_reports_results(self):
        center = self.read("LiveContainerSwiftUI/Strata3/StrataRuntimeCenter.swift")
        self.assertIn('UTType(filenameExtension: "apk") ?? .data', center)
        self.assertIn('UTType(filenameExtension: "xapk") ?? .data', center)
        self.assertIn('UTType(filenameExtension: "apks") ?? .data', center)
        self.assertIn('UTType(filenameExtension: "apkm") ?? .data', center)
        self.assertIn("INFINITYAPKStore.install(from: url)", center)
        self.assertIn("apkInspectionError = error.localizedDescription", center)
        self.assertIn("Imported \\(imported.0.displayName) successfully.", center)
        self.assertIn("installedAPKs = (try? INFINITYAPKStore.installedApps()) ?? []", center)

    def test_husk_session_logging_captures_native_output_and_exports_logs(self):
        native_log = self.read("LiveContainerSwiftUI/Strata3/INFINITYHuskNativeLog.swift")
        runtime = self.read("LiveContainerSwiftUI/Strata3/INFINITYHuskRuntime.swift")
        launch = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        self.assertIn("dup2(pipeWriteFD, STDOUT_FILENO)", native_log)
        self.assertIn("dup2(pipeWriteFD, STDERR_FILENO)", native_log)
        self.assertIn("installCrashHandlers()", native_log)
        self.assertIn("husk-native.log", native_log)
        self.assertIn("husk-prev.log", native_log)
        self.assertIn("recentLines", native_log)
        self.assertIn("INFINITYHuskNativeLog.start()", launch)
        self.assertIn("INFINITYHuskSessionLogger", runtime)
        self.assertIn("PERFORMANCE", runtime)
        self.assertIn("RUNTIME_ERROR", runtime)
        self.assertIn("INFINITYHuskNativeLog.recentLines(800)", launch)
        self.assertIn("Export native stderr log", launch)
        self.assertIn("Export Husk log", launch)
        self.assertIn("LAUNCH_ERROR", launch)
        self.assertNotIn("removeItem(at: logURL)", launch)

    def test_launch_attempt_records_preflight_and_preserves_unique_native_diagnostic_files(self):
        launch = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        self.assertIn('runtime.recordSessionEvent("LAUNCH_REQUESTED"', launch)
        self.assertIn('runtime.recordSessionEvent("RUNTIME_PREPARATION"', launch)
        self.assertIn('runtime.recordSessionEvent("HUSK_LAUNCH_REQUEST"', launch)
        self.assertIn('UUID().uuidString + ".log"', launch)
        self.assertIn('sessionLogger.finish(outcome: "launch failed")', launch)
        self.assertIn('Button {\n                        showSessionLog = true', launch)


if __name__ == "__main__":
    unittest.main()
