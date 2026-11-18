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

    def test_split_required_apps_are_not_offered_for_base_apk_only_launch(self):
        view = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        self.assertIn("guard !app.requiresSplits", view)
        self.assertIn("launch is blocked until split-package installation is implemented", view)

    def test_native_graphics_are_required_inside_the_signed_app_bundle(self):
        store = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKStore.swift")
        view = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        self.assertIn("static var hasEmbeddedAngle", store)
        self.assertIn("static var hasEmbeddedMoltenVK", store)
        self.assertIn("isANGLEEmbeddedAndReadable", store)
        self.assertIn("INFINITYAPKStore.nativeRuntimeBundle() != nil", view)
        self.assertIn("INFINITYAPKStore.isMoltenVKEmbeddedAndReadable", view)
        self.assertIn("not embedded and signed", view)

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
        self.assertIn('types: [.ipa, .tipa, UTType(filenameExtension: "apk") ?? .data]', view)
        self.assertIn("startInstallSelectedFile(fileURL)", view)
        self.assertIn('fileURL.pathExtension.lowercased() == "apk"', view)
        self.assertIn("INFINITYAPKStore.install(from: fileURL)", view)
        self.assertIn('Button("Import IPA / APK"', view)

    def test_android_apk_library_lists_and_removes_persisted_imports(self):
        view = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        app_list = self.read("LiveContainerSwiftUI/Views/AppList/LCAppListView.swift")
        self.assertIn("struct INFINITYAPKLibraryView", view)
        self.assertIn("INFINITYAPKStore.installedApps()", view)
        self.assertIn("INFINITYAPKStore.remove(packageName:", view)
        self.assertIn("INFINITYAPKLibraryView()", app_list)


if __name__ == "__main__":
    unittest.main()
