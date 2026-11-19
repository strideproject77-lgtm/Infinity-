from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HuskRuntimeBridgeContractTests(unittest.TestCase):
    def read(self, relative: str) -> str:
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_strata_bridge_uses_infinity_owned_header_only(self):
        bridge = self.read("LiveContainerSwiftUI/Strata3/INFINITYHuskRuntimeBridge.h")
        self.assertIn("../../Vendor/Husk/include/INFINITYHuskRuntime.h", bridge)
        self.assertNotIn("HuskBridge.h", bridge)
        self.assertNotIn("husk-tl-unity-app.h", bridge)

    def test_runtime_package_compiles_both_upstream_translation_trees(self):
        package = self.read("Vendor/Husk/Package.swift")
        self.assertIn('"translation-layer"', package)
        self.assertIn('"translation-layer-next"', package)
        self.assertIn('"bridge"', package)
        self.assertIn('name: "INFINITYHuskRuntime"', package)
        self.assertIn('type: .static', package)

    def test_infinity_c_adapter_owns_launch_lifecycle_and_input_surface(self):
        adapter = self.read("Vendor/Husk/bridge/INFINITYHuskRuntime.c")
        for symbol in (
            "husk_java_launch(",
            "husk_unity_launch(",
            "husk_native_unload(",
            "tl_javaapp_touch(",
            "husk_unity_set_paused(",
            "husk_gamepad_update(",
            "husk_unity_perf_snapshot("
        ):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, adapter)

    def test_all_husk_backend_engines_are_dispatched_without_collapsing_identity(self):
        header = self.read("Vendor/Husk/include/INFINITYHuskRuntime.h")
        adapter = self.read("Vendor/Husk/bridge/INFINITYHuskRuntime.c")
        for engine in (
            "UNITY", "JAVA", "COCOS", "GAME_ACTIVITY", "SDL",
            "UNREAL", "GODOT", "GTA", "FLUTTER", "GAMEMAKER"
        ):
            with self.subTest(engine=engine):
                self.assertIn(f"INFINITY_HUSK_ENGINE_{engine}", header)
                self.assertIn(f"case INFINITY_HUSK_ENGINE_{engine}:", adapter)
        self.assertIn("atomic_compare_exchange_strong(&g_infinity_engine", adapter)
        self.assertIn("INFINITY_ENGINE_STARTING", adapter)
        self.assertIn("accepted ? engine : INFINITY_ENGINE_NONE", adapter)
        self.assertIn("isfinite(x) && isfinite(y)", adapter)
        self.assertIn("bool infinity_husk_launch_engine(int engine,", adapter)
        self.assertIn("atomic_load(&g_java_runtime_ready)", adapter)
        self.assertIn("atomic_load(&g_native_runtime_ready)", adapter)
        self.assertIn("atomic_store(&g_native_runtime_ready, true)", adapter)
        self.assertIn("atomic_store(&g_java_runtime_ready, false)", adapter)
        self.assertIn("atomic_load(&g_infinity_engine) != INFINITY_ENGINE_NONE", adapter)
        self.assertIn("if (!atomic_load(&g_native_runtime_ready)) return false;", adapter)
        self.assertIn("infinity_husk_prepare_native", header)
        swift = self.read("LiveContainerSwiftUI/Strata3/INFINITYHuskRuntime.swift")
        self.assertIn("func prepareNative(", swift)
        self.assertEqual(swift.count("func prepareNative("), 1)
        self.assertIn("nativeRuntimeNotPrepared", swift)
        self.assertIn("infinity_husk_launch_engine(int engine,", header)
        self.assertIn("husk_unity_touch(phase, pointer_id, x, y)", adapter)
        self.assertIn("husk_unity_set_paused(paused)", adapter)


    def test_dex_invoke_register_count_is_checked_against_prototype(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        self.assertIn("expected_slots != count", dvm)
        self.assertIn("invoke register count mismatch", dvm)
        self.assertIn("truncated method prototype", dvm)
        self.assertIn("index >= caller->regs", dvm)
        self.assertIn("count > 255", dvm)

    def test_jni_signature_parser_and_varargs_support_full_descriptor_limit(self):
        internal = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni-internal.h")
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        self.assertIn("char argk[256]", internal)
        self.assertIn("bool valid_sig", internal)
        self.assertIn("parse_descriptor_type", jni)
        self.assertIn("m->nargs >= 255", jni)
        self.assertIn("jvalue *va_arguments(", jni)
        self.assertIn("args_from_va(m, ap, args)", jni)
        self.assertIn("m->nargs <= 16 ? local : calloc", jni)
        self.assertNotIn("jvalue args[40]", jni)
        self.assertIn("free(args);", jni)
        self.assertIn("copying JNI UTF-16 String", jni)
        self.assertIn("JNI call has a null argument array", jni)

    def test_dex_frames_validate_incoming_slots_and_native_stack_args_are_dynamic(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        self.assertIn("m->regs < m->ins", dvm)
        self.assertIn("m->nparams > 4096", dvm)
        self.assertIn("incoming_slots != m->ins", dvm)
        self.assertIn("prototype/register mismatch", dvm)
        self.assertIn("int64_t *stk = calloc(stack_capacity, sizeof(*stk))", dvm)
        self.assertIn("free(stk);", dvm)
        self.assertNotIn("int64_t stk[256]", dvm)
        self.assertNotIn("ns < 256", dvm)

    def test_dex_header_tables_are_bounded_before_indexing(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        self.assertIn("dex_header_valid", dvm)
        self.assertIn("endian_tag != 0x12345678u", dvm)
        self.assertIn("dex_table_fits", dvm)
        self.assertIn("invalid or truncated DEX header/table", dvm)

    def test_encoded_static_values_are_recursively_bounds_checked(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        self.assertIn("encoded_uleb", dvm)
        self.assertIn("read_value_depth", dvm)
        self.assertIn("depth > 32", dvm)
        self.assertIn("v >= d->nstr", dvm)
        self.assertIn("v >= d->ntype", dvm)
        self.assertIn("invalid/truncated static_values array", dvm)
        self.assertIn("defaulting statics", dvm)

    def test_dex_field_resolution_cache_respects_staticness(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        resolver = dvm[dvm.index("typedef struct fref"):dvm.index("/* ================================================================== the interpreter */")]
        self.assertIn("bool is_static;", resolver)
        self.assertIn("cached->is_static == is_static", resolver)
        self.assertIn("wrong_static", resolver)
        self.assertIn("dvm_find_field_exact(c, name, type, !is_static)", resolver)

    def test_dex_field_indices_and_opcode_staticness_are_validated(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        self.assertIn("idx >= d->nfield", dvm)
        self.assertIn("invalid instance field index", dvm)
        self.assertIn("invalid static field index", dvm)
        self.assertIn("IncompatibleClassChangeError", dvm)

    def test_elf_loader_checks_file_ranges_before_reading_segments(self):
        loader = self.read("Vendor/Husk/translation-layer-next/husk-tl-ld.c")
        self.assertIn("static bool file_range_fits(size_t total, uint64_t offset, uint64_t length)", loader)
        self.assertIn("!file_range_fits(flen, eh->e_phoff", loader)
        self.assertIn("eh->e_ehsize < sizeof(*eh)", loader)
        self.assertIn("p->p_filesz > p->p_memsz", loader)
        self.assertIn("p->p_vaddr > UINT64_MAX - p->p_memsz", loader)
        self.assertIn("invalid or excessive PT_LOAD segment", loader)
        self.assertIn("dynamic table is outside the mapped image or truncated", loader)
        self.assertNotIn("eh->e_phoff + (uint64_t)eh->e_phnum * eh->e_phentsize > flen", loader)

    def test_jni_field_ids_resolve_by_exact_descriptor(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        hook = dvm.split("static bool hook_find_field(", 1)[1].split(
            "static uint32_t hook_slots", 1
        )[0]
        self.assertIn("dvm_find_field_exact(c, name, sig, is_static)", hook)
        self.assertNotIn("(void)sig", hook)
        self.assertIn("JNI %s field not found", hook)
        self.assertIn("dvm_ensure_init(f->cls)", hook)

    def test_dex_class_data_and_code_offsets_are_bounded(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        self.assertIn("dex_class_data_valid", dvm)
        self.assertIn("dex_uleb_bounded", dvm)
        self.assertIn("DEX delta indices restart for static_fields and instance_fields", dvm)
        self.assertIn("code_off > d->size", dvm)
        self.assertIn("d->nfield", dvm)
        self.assertIn("d->nmeth", dvm)

    def test_dex_method_prototypes_and_interface_lists_are_validated(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        self.assertIn("dex_proto_valid", dvm)
        self.assertIn("rd16(mi + 2)", dvm)
        self.assertIn("invalid interface list", dvm)
        self.assertIn("truncated interface list", dvm)
        self.assertIn("invalid interface type", dvm)

    def test_java_runtime_is_rejected_when_boot_assets_are_missing(self):
        adapter = self.read("Vendor/Husk/bridge/INFINITYHuskRuntime.c")
        for asset in (
            "com.android.art/javalib/core-oj.jar",
            "com.android.art/javalib/core-libart.jar",
            "com.android.i18n/javalib/core-icu4j.jar",
            "com.android.art/javalib/okhttp.jar",
            "com.android.art/lib64/libopenjdk.so",
            "com.android.i18n/javalib/core-icu4j.jar",
            "com.android.conscrypt/javalib/conscrypt.jar",
            "com.android.conscrypt/lib64/libjavacrypto.so",
            "husk-framework.dex",
            "husk-framework-core.dex",
            "org.apache.http.legacy.jar",
            "framework-res.apk"
        ):
            with self.subTest(asset=asset):
                self.assertIn(asset, adapter)
        self.assertIn('runtime_directory(system_fonts_root, "fonts")', adapter)
        self.assertIn('runtime_file(system_fonts_root, "etc/fonts.xml")', adapter)
        self.assertIn('runtime_file(system_fonts_root, "etc/font_fallback.xml")', adapter)
        self.assertIn('runtime_directory(runtime_root, "com.android.i18n/etc/icu")', adapter)
        self.assertIn('runtime_directory(runtime_root, "com.android.tzdata/etc")', adapter)

    def test_java_runtime_builder_preflights_and_atomically_promotes_complete_assets(self):
        builder = self.read("Vendor/Husk/build-support/build_java_runtime.sh")
        for marker in (
            "ANDROID_APEX_ROOT", "HUSK_ANDROID_ROOT", "require_file",
            "com.android.i18n/etc/icu", "com.android.tzdata/etc",
            "husk-framework-core.dex", "strip_framework_res.py",
            'mktemp -d "$BUILD_ROOT/.java-runtime.XXXXXX"',
            'mv "$STAGED" "$OUT"',
            "previous runtime restored"
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, builder)
        self.assertLess(builder.index('require_dir "$APEX"'), builder.index('WORK="$(mktemp'))
        self.assertLess(builder.index('require_file "$FRAMEWORK_RES"'), builder.index('WORK="$(mktemp'))
        self.assertNotIn('rm -rf "$OUT"; mkdir', builder)

    def test_swift_runtime_controller_uses_real_native_entrypoints(self):
        swift = self.read("LiveContainerSwiftUI/Strata3/INFINITYHuskRuntime.swift")
        self.assertIn("@MainActor", swift)
        self.assertIn("infinity_husk_launch_engine", swift)
        self.assertIn("case java = 1", swift)
        self.assertIn("case gameActivity = 3", swift)
        self.assertIn("case unreal = 5", swift)
        self.assertIn("infinity_husk_java_touch", swift)
        self.assertIn("infinity_husk_stop", swift)
        self.assertNotIn("Hello from Stride", swift)

    def test_package_dependency_is_attached_to_strata_swiftui_not_sidestore(self):
        project = self.read("LiveContainer.xcodeproj/project.pbxproj")
        swiftui = re.search(
            r"17413FB42D9C0BAE00F3F928 /\* LiveContainerSwiftUI \*/ = \{(.*?)\n\t\t\};",
            project,
            re.S
        )
        sidestore = re.search(
            r"173545A72E2C7913001B3B4C /\* SideStoreSupport \*/ = \{(.*?)\n\t\t\};",
            project,
            re.S
        )
        self.assertIsNotNone(swiftui)
        self.assertIsNotNone(sidestore)
        self.assertIn("F10000000000000000000002", swiftui.group(1))
        self.assertNotIn("F10000000000000000000002", sidestore.group(1))


    def test_apk_store_persists_private_apk_and_separate_data(self):
        store = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKStore.swift")
        self.assertIn("copyItem(at: source, to: finalAPK)", store)
        self.assertIn('appendingPathComponent("Data"', store)
        self.assertIn("isValidPackageName", store)
        self.assertIn("options: .atomic", store)
        self.assertIn("rollback-", store)

    def test_launch_surface_uses_metal_and_native_engine_dispatch(self):
        view = self.read("LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift")
        self.assertIn("CAMetalLayer", view)
        self.assertIn("MTLCreateSystemDefaultDevice()", view)
        self.assertIn("runtime.launch(engine:", view)
        self.assertIn("runtime.sendTouch(", view)
        self.assertIn("layer.drawableSize.width > 0", view)
        self.assertIn("Runtime assets required", view)
        self.assertNotIn("Hello from Stride", view)

    def test_runtime_asset_builder_is_data_only_and_vendor_scoped(self):
        builder = self.read("scripts/build_infinity_runtime_assets.sh")
        self.assertIn('tar -C "$ROOT/Vendor/Husk"', builder)
        self.assertIn("HUSK_D8", builder)
        self.assertIn("qemu_guest_included", builder)
        self.assertIn('"ipa_included": False', builder)
        self.assertNotIn("build_github.sh", builder)

    def test_angle_build_is_pinned_and_keeps_bsd_notice(self):
        script = self.read("Vendor/Husk/build-support/build_angle_ios.sh")
        self.assertIn("WEBKIT_REVISION=", script)
        self.assertIn("LICENSE-ANGLE.txt", script)
        self.assertIn("install_name_tool -id", script)

    def test_angle_is_embedded_only_in_the_strata_app_and_code_signed(self):
        project = self.read("LiveContainer.xcodeproj/project.pbxproj")
        self.assertIn("Vendor/Husk/Prebuilt/ANGLE/ios-arm64/lib/libANGLE-shared.dylib", project)
        self.assertIn("libANGLE-shared.dylib in Embed Frameworks", project)
        self.assertIn("ATTRIBUTES = (CodeSignOnCopy, );", project)
        app = re.search(
            r"17DCE99C2C7067EC00731D42 /\* LiveContainer \*/ = \{(.*?)\n\t\t\};",
            project,
            re.S
        )
        self.assertIsNotNone(app)
        self.assertIn("17413FC12D9C0BAE00F3F928", app.group(1))
        self.assertIn("INFINITYAPKStore.isANGLEEmbeddedAndReadable", self.read(
            "LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift"
        ))
        self.assertIn("INFINITYAPKStore.runtimeDataReady()", self.read(
            "LiveContainerSwiftUI/Strata3/INFINITYAPKLaunchView.swift"
        ))


if __name__ == "__main__":
    unittest.main()
