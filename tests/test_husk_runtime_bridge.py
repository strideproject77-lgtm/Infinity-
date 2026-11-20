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

    def test_elf_dynamic_metadata_is_bounded_before_linker_dereferences(self):
        loader = self.read("Vendor/Husk/translation-layer-next/husk-tl-ld.c")
        self.assertIn("static bool image_range_fits(", loader)
        self.assertIn("static const char *dynamic_string(", loader)
        self.assertIn("memchr(s, 0, (size_t)(L->strsz - offset))", loader)
        self.assertIn("static bool parse_dynamic(", loader)
        self.assertIn("a bounded dynamic segment must contain DT_NULL", loader)
        self.assertIn("static bool validate_dynamic_metadata(", loader)
        self.assertIn("malformed or incomplete ELF dynamic metadata", loader)
        self.assertIn("invalid DT_SONAME string offset", loader)
        self.assertIn("L->relasz % sizeof(elf_rela)", loader)
        self.assertIn("L->relrsz % 8", loader)
        self.assertIn("chain_words", loader)
        self.assertIn("dynamic symbol table exceeds the mapped image", loader)
        self.assertIn("has an invalid or unterminated name", loader)
        self.assertIn("relocation references symbol", loader)
        self.assertIn("if (!image_range_fits(L, r_offset, 8)) return false;", loader)
        self.assertIn("resolver_vaddr", loader)
        self.assertIn("TLS relocation references symbol", loader)
        self.assertIn("if (!image_range_fits(L, word, 8)) return false;", loader)
        self.assertIn("if (type == R_NONE) return true;", loader)

    def test_bionic_symbol_table_lookup_fails_closed_on_bad_input_or_oom(self):
        bionic = self.read("Vendor/Husk/translation-layer-next/husk-tl-bionic.c")
        self.assertIn("static bool g_table_ready;", bionic)
        self.assertIn('if (!g_slots) { g_nslots = 0; tl_log_line("bionic: unable to allocate symbol lookup table"); return; }', bionic)
        self.assertIn("if (!name || !name[0]) return NULL;", bionic)
        self.assertIn("if (!g_table_ready || !g_slots || !g_nslots) return NULL;", bionic)

    def test_elf_loader_checks_file_ranges_before_reading_segments(self):
        loader = self.read("Vendor/Husk/translation-layer-next/husk-tl-ld.c")
        self.assertIn("static bool file_range_fits(size_t total, uint64_t offset, uint64_t length)", loader)
        self.assertIn("!file_range_fits(flen, eh->e_phoff", loader)
        self.assertIn("eh->e_ehsize < sizeof(*eh)", loader)
        self.assertIn("p->p_filesz > p->p_memsz", loader)
        self.assertIn("p->p_vaddr > UINT64_MAX - p->p_memsz", loader)
        self.assertIn("invalid or excessive PT_LOAD segment", loader)
        self.assertIn("dynamic table is outside the mapped image or truncated", loader)
        self.assertIn("out of memory for library metadata", loader)
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

    def test_elf_linker_resolves_ifuncs_and_honors_symbol_visibility(self):
        loader = self.read("Vendor/Husk/translation-layer-next/husk-tl-ld.c")
        for marker in (
            "STV_HIDDEN_ = 2", "STV_INTERNAL_ = 1", "STV_PROTECTED_ = 3",
            "symbol_is_exported", "resolved_symbol_value",
            "STT_GNU_IFUNC_", "recursive IFUNC resolution",
            "recursive symbol resolution at index",
            "__atomic_load_n(&L->symcache[index]", "__atomic_store_n(&L->symcache[index]"
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, loader)
        self.assertIn("s && symbol_is_exported(s)", loader)
        self.assertNotIn("STT_GNU_IFUNC_) { *failed = true; return 0; }", loader)

    def test_gnu_version_requirement_is_bound_to_declared_dependency_file(self):
        loader = self.read("Vendor/Husk/translation-layer-next/husk-tl-ld.c")
        self.assertIn("symbol_version_file", loader)
        self.assertIn("lookup_for_version(tl_lib *L, const char *name, const char *version, const char *required_file)", loader)
        self.assertIn("strcmp(dep->soname, required_file)", loader)
        self.assertIn("const char *required_file = symbol_version_file(L, symidx)", loader)
        self.assertIn("!required_version || !required_file", loader)

    def test_gnu_version_table_covers_import_symbols_beyond_hash_exports(self):
        loader = self.read("Vendor/Husk/translation-layer-next/husk-tl-ld.c")
        self.assertIn("L->ncache * sizeof(uint16_t)", loader)
        self.assertIn("L->versym, L->verdef, L->verneed", loader)
        self.assertIn("symbol_index >= L->ncache", loader)
        self.assertIn("d[i].d_val > UINT32_MAX", loader)

    def test_bionic_pthread_custom_stack_is_honored_by_native_thread_creation(self):
        pthread = self.read("Vendor/Husk/translation-layer-next/husk-tl-bionic-pthread.c")
        self.assertIn("#define GATTR_USER_STACK 2u", pthread)
        self.assertIn("static int b_attr_setstack(guest_attr *a, void *base, size_t n)", pthread)
        self.assertIn("a->flags |= GATTR_USER_STACK", pthread)
        self.assertIn("pthread_attr_setstack(&a, attr->stack_base, stack)", pthread)
        self.assertIn("exact range, never silently replace it with a host-owned stack", pthread)
        self.assertIn('TL_WRAP("pthread_attr_setstack", b_attr_setstack)', pthread)
        self.assertIn("if (stack_result) { pthread_attr_destroy(&a); return rc(stack_result); }", pthread)

    def test_jni_object_method_returns_are_local_refs_and_vm_env_is_thread_owned(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        for marker in (
            "static jo call_object_a",
            "static jo call_object_v",
            "local_frame_adopt(tl_jni_ref(call_a(kind, receiver, mid, args).l))",
            "jni_CallObjectMethodA",
            "jni_CallNonvirtualObjectMethodA",
            "jni_CallStaticObjectMethodA",
            "static env_t t_env, g_vm",
            "static __thread bool t_vm_attached",
            "JNI_EDETACHED (-2)",
            "JNI_EVERSION (-3)",
            "if (!t_vm_attached) { *penv = NULL; return JNI_EDETACHED; }",
            "local_frames_detach();",
            "return thread_env();",
            "jobj *tl_jni_class_object(const char *name) { return tl_jni_class(name)->mirror; }",
            "local_frame_adopt(tl_jni_ref(tl_jni_class(name)->mirror))",
            "if (!local_frame_current()) return JNI_ERR;",
            "if (!local_frame_current()) return NULL;",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, jni)
        self.assertNotIn("static env_t g_env, g_vm;", jni)
        self.assertNotIn("static int32_t vm_GetEnv(void *vm, void **penv, int32_t version) { (void)vm; (void)version; *penv = &g_env; return 0; }", jni)

    def test_jni_modified_utf8_and_native_registration_lifecycle(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        internal = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni-internal.h")
        for marker in (
            "jni_mutf8_encode",
            "jni_mutf8_from_utf8",
            "jni_mutf8_to_utf8",
            "Modified UTF-8",
            "GetStringUTFLength received a null or non-string reference",
            "encoding Modified UTF-8 string region",
            "current guest string storage is NUL-terminated",
            "RegisterNatives received an incomplete native method",
            "allocating native registration transaction",
            "RegisterNatives received an invalid JNI method descriptor",
            "tl_jmeth signature = {0};",
            "if (!parse_sig(&signature))",
            "native registration batch is too large",
            "Reserve every destination before publishing any registration.",
            "reserving JNI native method table transaction",
            "owner->natives[owner->nnatives].registered_on = given",
            "__atomic_add_fetch(&g_natives_generation, 1, __ATOMIC_RELEASE)",
            "reserving JNI native method table transaction",
            "static int32_t jni_UnregisterNatives(void *env, jo cls)",
            "owner->natives[read].registered_on == registered",
            "static char *jni_mutf8_encode(",
            "out[n++] = (char)0xc0; out[n++] = (char)0x80;",
            "static jo jni_NewStringUTF(",
            "static int32_t jni_GetStringUTFLength(",
            "static const char *jni_GetStringUTFChars(",
            "memcpy(buf, out, out_len)",
            "current guest string store is NUL-terminated UTF-8",
            "registered_on = given",
            "if (changed) __atomic_add_fetch(&g_natives_generation, 1, __ATOMIC_RELEASE)",
            "tl_jni_throw(\"java/lang/OutOfMemoryError\"",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, jni)
        self.assertIn("tl_jclass *registered_on;", internal)
        self.assertNotIn("static int32_t jni_UnregisterNatives(void *env, jo cls) { (void)env; (void)cls; return 0; }", jni)

    def test_jni_constructors_validate_lengths_types_and_allocation_failures(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        for marker in (
            "if (len < 0 || (!chars && len))",
            "if (!s) return NULL;",
            "if (!out) return NULL;",
            "if (!value) { tl_jni_throw(\"java/lang/NullPointerException\", \"GetStringChars",
            "if (len < 0 || !cls || cls->kind != TL_K_CLASS)",
            "java/lang/ArrayStoreException",
            "java/lang/ArrayIndexOutOfBoundsException",
            "if (!etype || !strchr(\"ZBCSIJFD\", etype))",
            "primitive array type mismatch",
            "(uint32_t)n > a->arr.len - (uint32_t)s",
            "cap < 0 || cap > INT32_MAX || (!addr && cap > 0)",
            "allocating DirectByteBuffer",
            "GetPrimitiveArrayCritical requires a primitive array",
            "ReleasePrimitiveArrayCritical requires a primitive array",
            "t_pending = NULL;",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, jni)
        self.assertNotIn("(uint32_t)(s + n) <= a->arr.len", jni)
        self.assertNotIn("(size_t)(start + len) <= n", jni)

    def test_jni_string_character_buffers_are_tracked_by_kind_and_thread(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        for marker in (
            "typedef enum {",
            "JNI_STRING_ACCESS_UTF16 = 1",
            "JNI_STRING_ACCESS_MUTF8 = 2",
            "JNI_STRING_ACCESS_CRITICAL = 3",
            "static __thread jni_string_access *t_string_accesses",
            "static bool jni_string_access_track(",
            "static bool jni_string_access_release(",
            "JNI string buffer is not outstanding for this string and access kind",
            "tracking UTF-16 string characters",
            "tracking JNI Modified UTF-8 characters",
            "tracking critical UTF-16 string characters",
            "jni_string_access_release(s, c, JNI_STRING_ACCESS_UTF16)",
            "jni_string_access_release(s, c, JNI_STRING_ACCESS_MUTF8)",
            "jni_string_access_release(s, c, JNI_STRING_ACCESS_CRITICAL)",
            "static void jni_string_accesses_detach(void)",
            "jni_string_accesses_detach();",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, jni)

    def test_jni_string_access_retains_owner_and_checks_utf16_length(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        for marker in (
            "access->string = tl_jni_ref(string);",
            "tl_jni_unref(access->string);",
            "static int32_t jni_GetStringLength(void *env, jo s)",
            "GetStringLength received a null or non-string reference",
            "if (length > INT32_MAX)",
            "JNI UTF-16 string exceeds jint length",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, jni)

    def test_jni_array_accesses_retain_owner_until_release_or_detach(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        for marker in (
            "access->array = tl_jni_ref(array);",
            "access->array = tl_jni_ref(a);",
            "tl_jni_unref(access->array);",
            "static void jni_array_accesses_detach(void)",
            "static void jni_critical_array_accesses_detach(void)",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, jni)

    def test_nativeactivity_delivers_owned_ndk_input_queue_lifecycle(self):
        activity = self.read("Vendor/Husk/translation-layer-next/husk-tl-nativeactivity.c")
        ndk = self.read("Vendor/Husk/translation-layer-next/husk-tl-bionic-ndk.c")
        self.assertIn("tl_bionic_input_queue_create", activity)
        self.assertIn("tl_bionic_input_queue_destroy", activity)
        self.assertIn("N.callbacks.onInputQueueCreated(&N.na, input_queue)", activity)
        self.assertIn("N.callbacks.onInputQueueDestroyed(&N.na, input_queue)", activity)
        self.assertNotIn("callback withheld because no real queue is available", activity)
        for marker in (
            "return e ? e->type : 0;",
            "return e ? e->source : 0;",
            "return e ? e->device : 0;",
            "return e ? e->action : 0;",
            "return e ? e->flags : 0;",
            "return e ? e->meta : 0;",
            "return e ? e->button_state : 0;",
            "return e && e->nptr > 0 ? (size_t)e->nptr : 0;",
            "e && i < (size_t)e->nptr && i < 10",
            "if (!e || axis < 0) return 0.0f;",
            "return e ? e->keycode : 0;",
            "return e ? e->time : 0;",
            "static int iq_enqueue_locked(tl_ievent *e)",
            "int wake_fd = iq_enqueue_locked(e);",
            "static void iq_wake(int fd)",
            "static pthread_mutex_t IQ_init_mu = PTHREAD_MUTEX_INITIALIZER;",
            "if (!e || !IQ.attached || !IQ.ready)",
            "if (fd >= 0) (void)!write(fd, &c, 1);",
            "if (!f) { pthread_mutex_unlock(&l->mu); return -1; }",
            "if (!IQ.attached) { pthread_mutex_unlock(&IQ.mu); return; }",
            "void *tl_bionic_input_queue_create(void)",
            "void tl_bionic_input_queue_destroy(void *queue)",
            "return &IQ;",
            "if (q != &IQ || !looper) return;",
            "IQ.looper = looper;",
            "if (q != &IQ || !ev) return -1;",
            "if (queue != &IQ || !IQ.ready) return;",
            "b_ALooper_removeFd(looper, IQ.rd)",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, ndk)
        self.assertIn("tl_ievent *pending = IQ.head;", ndk)
        self.assertIn("while (pending) { tl_ievent *next = pending->next; free(pending); pending = next; }", ndk)

    def test_native_activity_stop_handles_ui_thread_self_shutdown(self):
        source = self.read("Vendor/Husk/translation-layer-next/husk-tl-nativeactivity.c")
        start = source.index("void tl_na_stop(void)")
        end = source.index("\nunsigned long tl_vk_frames_presented", start)
        stop = source[start:end]
        for marker in (
            "atomic_store(&N.stop_requested, true);",
            "if (pthread_equal(pthread_self(), N.ui))",
            "pthread_detach(N.ui)",
            "N.ui_thread_created = false;",
            "int joined = pthread_join(N.ui, NULL);",
            "if (joined != 0)",
            "return;",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, stop)
        self.assertLess(stop.index("pthread_detach(N.ui)"), stop.index("pthread_join(N.ui, NULL)"))

    def test_bionic_lazy_pthread_objects_handle_allocation_and_init_failures(self):
        source = self.read("Vendor/Husk/translation-layer-next/husk-tl-bionic-pthread.c")
        for marker in (
            "static __thread int t_obj_error;",
            "if (!g || !make) { t_obj_error = EINVAL; return NULL; }",
            "atomic_store_explicit(&o->magic, 0, memory_order_release);",
            "static int obj_error(void)",
            "if (!m) { pthread_mutexattr_destroy(&a); t_obj_error = ENOMEM; return NULL; }",
            "r = pthread_mutex_init(m, &a);",
            "if (!c) { t_obj_error = ENOMEM; return NULL; }",
            "int r = pthread_cond_init(c, NULL);",
            "if (!l) { t_obj_error = ENOMEM; return NULL; }",
            "int r = pthread_rwlock_init(l, NULL);",
            "if (!m) return obj_error();",
            "if (!c) return obj_error();",
            "if (!mutex) return obj_error();",
            "return l ? rc(fn(l)) : obj_error();",
            "if (clock_gettime(clk, &now) != 0) return rc(errno);",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, source)

    def test_bionic_semaphore_rejects_unsupported_process_sharing(self):
        source = self.read("Vendor/Husk/translation-layer-next/husk-tl-bionic-pthread.c")
        for marker in (
            "if (pshared == 1)",
            "This host semaphore is process-local",
            'tl_set_guest_errno(95); /* ENOTSUP in the Bionic errno namespace */',
            "host_sem *s = make_sem(value);",
            "if (!s) { tl_set_guest_errno(12); return -1; }",
            "abs->tv_nsec < 0 || abs->tv_nsec >= 1000000000L",
            "if (clock_gettime(CLOCK_REALTIME, &now) != 0)",
            "tl_set_guest_errno(tl_errno_to_guest(errno));",
            "if (!g || !v) { tl_set_guest_errno(22); return -1; }",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, source)

    def test_jni_array_length_checks_jint_boundary(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        for marker in (
            "static int32_t jni_GetArrayLength(void *env, jo a)",
            "size_t length = a->kind == TL_K_OBJ_ARRAY ? a->oarr.len : a->arr.len;",
            "if (length > INT32_MAX)",
            "JNI array length exceeds jint range",
            "return (int32_t)length;",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, jni)

    def test_jni_primitive_array_elements_obey_copy_and_release_modes(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        for marker in (
            "typedef struct jni_array_access",
            "static __thread jni_array_access *t_array_accesses",
            "static void *jni_array_copy_out(",
            "if (is_copy) *is_copy = 1;",
            "static void jni_array_release(",
            "if (mode != 0 && mode != 1 && mode != 2)",
            "if (mode != 2)",
            "if (mode == 1) return; /* JNI_COMMIT copies back but retains the buffer. */",
            "static void jni_array_accesses_detach(void)",
            "jni_array_accesses_detach();",
            "return (CT *)jni_array_copy_out(a, K, sizeof(CT), copy);",
            "jni_array_release(a, e, mode, K);",
            "array->arr.len != access->length",
            "typedef struct jni_critical_array_access",
            "static __thread jni_critical_array_access *t_critical_array_accesses",
            "allocating JNI critical array copy",
            "critical array pointer is not outstanding for this array",
            "static size_t jni_critical_element_size(char etype)",
            "static bool jni_critical_array_copyback(jni_critical_array_access *access)",
            "allocating JNI critical array copy",
            "if (copy) *copy = 1;",
            "if (mode != 2 && !jni_critical_array_copyback(access)) return;",
            "if (mode == 1) return; /* JNI_COMMIT copies back but retains the buffer. */",
            "free(access->address);",
            "static void jni_critical_array_accesses_detach(void)",
            "jni_critical_array_accesses_detach();"
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, jni)
        self.assertNotIn("if (copy) *copy = 0; return a->arr.data;", jni)

    def test_jni_local_reference_frames_are_thread_scoped_and_released_on_detach(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        for marker in (
            "static __thread jni_local_frame *t_local_frame",
            "local_frame_reserve",
            "local_frame_add_owned",
            "local_frame_adopt",
            "local_frame_remove",
            "return local_frame_adopt(new_object(cls, mid, 2, a, NULL))",
            "jo o = tl_jni_new_string(decoded);",
            "jo a = tl_jni_new_prim_array(K, (uint32_t)len);",
            "static int32_t jni_PushLocalFrame",
            "static jo jni_PopLocalFrame",
            "static jo jni_NewLocalRef",
            "static int32_t jni_EnsureLocalCapacity",
            "local_frames_detach()",
            "OutOfMemoryError"
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, jni)
        self.assertNotIn("static int32_t jni_PushLocalFrame(void *env, int32_t cap) { (void)env; (void)cap; return 0; }", jni)
        self.assertNotIn("static jo jni_PopLocalFrame(void *env, jo r) { (void)env; return r; }", jni)

    def test_jni_local_roots_are_shadowed_in_typed_reference_registry(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        for marker in (
            '#include "husk-tl-jni-refs.h"',
            "tl_jni_refs_new_local(o)",
            "tl_jni_refs_push_local_frame((size_t)cap)",
            "tl_jni_refs_pop_local_frame(NULL)",
            "tl_jni_refs_detach_thread()",
            "return local_frame_adopt(ref);"
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, jni)

    def test_jni_delete_local_ref_releases_its_typed_shadow_root_immediately(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        self.assertIn("typedef struct jni_local_entry", jni)
        self.assertIn("tl_jni_ref_handle *root;", jni)
        self.assertIn("f->items[f->count++] = (jni_local_entry){ .object = o, .root = root };", jni)
        remove_start = jni.index("static bool local_frame_remove(jobj *o)")
        remove_end = jni.index("static void local_frame_release", remove_start)
        remove = jni[remove_start:remove_end]
        self.assertIn("f->items[i - 1].object == o", remove)
        self.assertIn("tl_jni_refs_delete(removed.root, TL_JNI_REF_LOCAL);", remove)
        release_start = jni.index("static void local_frame_release(jni_local_frame *f)")
        release_end = jni.index("static void local_frames_detach", release_start)
        release = jni[release_start:release_end]
        self.assertIn("tl_jni_refs_delete(f->items[i].root, TL_JNI_REF_LOCAL);", release)
        self.assertIn("tl_jni_unref(f->items[i].object);", release)

    def test_jni_weak_global_slots_are_not_aliased_to_strong_global_slots(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        self.assertIn("static jo jni_NewWeakGlobalRef", jni)
        self.assertIn("static void jni_DeleteWeakGlobalRef", jni)
        self.assertIn("retain weak globals strongly", jni)
        self.assertIn("SLOT(226, jni_NewWeakGlobalRef)", jni)
        self.assertIn("SLOT(227, jni_DeleteWeakGlobalRef)", jni)
        self.assertNotIn("SLOT(226, jni_NewGlobalRef)", jni)
        self.assertNotIn("SLOT(227, jni_DeleteGlobalRef)", jni)

    def test_jni_global_and_weak_refs_use_distinct_typed_registry_handles(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        self.assertIn("typedef struct jni_nonlocal_ref", jni)
        self.assertIn("tl_jni_refs_new_global(object)", jni)
        self.assertIn("tl_jni_refs_new_weak_global(object)", jni)
        self.assertIn("tl_jni_refs_delete(entry->handle, kind);", jni)
        self.assertIn("jni_nonlocal_ref_add(o, TL_JNI_REF_GLOBAL)", jni)
        self.assertIn("jni_nonlocal_ref_add(o, TL_JNI_REF_WEAK_GLOBAL)", jni)
        self.assertIn("jni_nonlocal_ref_delete(o, TL_JNI_REF_GLOBAL)", jni)
        self.assertIn("jni_nonlocal_ref_delete(o, TL_JNI_REF_WEAK_GLOBAL)", jni)
        self.assertIn("if (kind == TL_JNI_REF_GLOBAL) return 2u;", jni)
        self.assertIn("if (kind == TL_JNI_REF_WEAK_GLOBAL) return 3u;", jni)
        self.assertIn("return 1u;", jni)

    def test_interpreted_native_calls_scope_jni_local_references(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        header = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.h")
        self.assertIn("bool tl_jni_native_frame_enter(void)", header)
        self.assertIn("jobj *tl_jni_native_frame_leave(jobj *result)", header)
        self.assertIn("return jni_PushLocalFrame(NULL, 16) == 0;", jni)
        self.assertIn("return jni_PopLocalFrame(NULL, result);", jni)
        self.assertIn("tl_jni_native_frame_enter()", dvm)
        self.assertIn("tl_jni_native_frame_leave(native_result)", dvm)
        self.assertIn("default: ret->l = preserved; break;", dvm)
        self.assertNotIn("((jobj *)ret->l)->refs = 1u << 30", dvm)

    def test_native_jni_frames_root_incoming_receiver_and_object_arguments(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        header = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.h")
        self.assertIn("bool tl_jni_native_frame_root(jobj *object)", header)
        self.assertIn("return local_frame_adopt(tl_jni_ref(object)) != NULL;", jni)
        self.assertIn("static bool native_frame_root_arguments", dvm)
        self.assertIn("m->shorty[1 + i] == 'L'", dvm)
        self.assertIn("native_frame_root_arguments(m, self, params)", dvm)
        self.assertGreaterEqual(dvm.count("native_frame_root_arguments(m, self, params)"), 2)

    def test_pending_jni_exception_is_kept_in_typed_strong_root_registry(self):
        jni = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni.c")
        self.assertIn("static __thread tl_jni_ref_handle *t_pending_root;", jni)
        self.assertIn("tl_jni_refs_new_global(exception)", jni)
        self.assertIn("tl_jni_refs_delete(previous, TL_JNI_REF_GLOBAL)", jni)
        self.assertIn("void tl_jni_set_pending(jobj *e) { pending_set(e); }", jni)
        self.assertIn("static int32_t jni_Throw(void *env, jo t) { (void)env; pending_set(t); return 0; }", jni)
        self.assertIn("pending_set(NULL);", jni)

    def test_dvm_tracks_active_call_receiver_and_object_argument_roots(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        header = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.h")
        self.assertIn("tl_dvm_visit_active_call_roots(tl_dvm_root_visitor visitor, void *context);", header)
        self.assertIn("static _Thread_local dvm_call_root_frame *t_call_root_frames;", dvm)
        self.assertIn("frame->method->shorty[i + 1] == 'L'", dvm)
        self.assertIn(".receiver = (m->flags & 8) ? NULL : self", dvm)
        self.assertIn("t_call_root_frames = root_frame.previous;", dvm)

    def test_typed_jni_root_callbacks_run_outside_registry_lock(self):
        refs = self.read("Vendor/Husk/translation-layer-next/husk-tl-jni-refs.c")
        start = refs.index("bool tl_jni_refs_visit_strong_roots(")
        end = refs.index("\nvoid tl_jni_refs_process_weak", start)
        walker = refs[start:end]
        unlock = walker.rindex("pthread_mutex_unlock(&g_refs_lock);")
        callback = walker.index("visitor(snapshot[i], context)")
        self.assertLess(unlock, callback)
        self.assertIn("if (count && !snapshot) return false;", walker)
        self.assertIn("return used == count;", walker)

    def test_dvm_composes_available_current_thread_and_jni_roots(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        header = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.h")
        start = dvm.index("bool tl_dvm_visit_current_thread_roots(")
        end = dvm.index("\nvoid tl_dvm_visit_static_roots", start)
        composer = dvm[start:end]
        self.assertIn("tl_dvm_visit_static_roots(visitor, context);", composer)
        self.assertIn("tl_dvm_visit_active_call_roots(visitor, context);", composer)
        self.assertIn("tl_jni_refs_visit_strong_roots(visitor, context)", composer)
        self.assertIn("requires external all-mutator safepoint", header.lower())

    def test_dex_root_callbacks_run_after_registry_lock_is_released(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        start = dvm.index("static void visit_dex_runtime_roots(")
        end = dvm.index("\nvoid tl_dvm_visit_static_roots", start)
        walker = dvm[start:end]
        unlock = walker.index("pthread_mutex_unlock(&g_lock);")
        callback = walker.index("walk->visitor(")
        self.assertLess(unlock, callback)
        self.assertIn("dvm_dex *snapshot[256];", walker)
        self.assertIn("__atomic_load_n(&dex->scache[n], __ATOMIC_ACQUIRE)", walker)

    def test_dvm_visits_runtime_owned_class_proxy_and_dex_roots(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        self.assertIn("if (jc->mirror) walk->visitor(jc->mirror, walk->context);", dvm)
        self.assertIn("methods[i].proxy_method", dvm)
        self.assertIn("methods[i].proxy_throws", dvm)
        self.assertIn("if (dex->loader) walk->visitor(dex->loader, walk->context);", dvm)
        self.assertIn("dex->scache[n]", dvm)
        self.assertIn("visit_dex_runtime_roots(&walk);", dvm)

    def test_dvm_exposes_object_valued_class_statics_as_gc_roots(self):
        dvm = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.c")
        header = self.read("Vendor/Husk/translation-layer-next/husk-tl-dvm.h")
        self.assertIn("void tl_dvm_visit_static_roots(tl_dvm_root_visitor visitor, void *context);", header)
        self.assertIn("tl_jni_each_declared(visit_class_static_roots);", dvm)
        self.assertIn("type[0] != 'L' && type[0] != '['", dvm)
        self.assertIn("jc->statics[slot].l", dvm)
        self.assertIn("slot >= (uint32_t)jc->nstatics", dvm)

    def test_nativeactivity_has_joinable_teardown_and_never_fakes_input_queue(self):
        native = self.read("Vendor/Husk/translation-layer-next/husk-tl-nativeactivity.c")
        header = self.read("Vendor/Husk/translation-layer-next/husk-tl-nativeactivity.h")
        bridge = self.read("Vendor/Husk/bridge/INFINITYHuskRuntime.c")
        for marker in (
            "atomic_bool stop_requested",
            "atomic_store(&N.stop_requested, false)",
            "while (!atomic_load(&N.stop_requested))",
            "void tl_na_stop(void)",
            "pthread_join(N.ui, NULL)",
            "N.callbacks.onNativeWindowDestroyed",
            "N.callbacks.onStop",
            "N.callbacks.onDestroy",
            "if (input_queue) N.callbacks.onInputQueueCreated(&N.na, input_queue)"
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, native)
        self.assertIn("void tl_na_stop(void);", header)
        self.assertIn("tl_na_stop();", bridge)
        self.assertNotIn("onInputQueueCreated(&N.na, (void *)&N)", native)

    def test_bionic_mutex_timed_and_clock_locking_and_semaphore_bounds_are_explicit(self):
        pthread = self.read("Vendor/Husk/translation-layer-next/husk-tl-bionic-pthread.c")
        for marker in (
            "static int mutex_timedlock_until(",
            "deadline->tv_nsec < 0 || deadline->tv_nsec >= 1000000000L",
            "pthread_mutex_trylock(m)",
            "clock_gettime(clock_id, &now)",
            "return 110; /* ETIMEDOUT in the Bionic errno namespace */",
            "static int b_mutex_timedlock(",
            "static int b_mutex_clocklock(",
            'TL_WRAP("pthread_mutex_timedlock", b_mutex_timedlock)',
            'TL_WRAP("pthread_mutex_clocklock", b_mutex_clocklock)',
            "value > INT_MAX",
            "if (s->count == INT_MAX)",
            "tl_set_guest_errno(75)"
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, pthread)

    def test_bionic_pthread_identity_naming_and_cond_clock_apis_are_real(self):
        pthread = self.read("Vendor/Husk/translation-layer-next/husk-tl-bionic-pthread.c")
        for marker in (
            "static int b_getname_np", "pthread_getname_np(t, name, length)",
            "static int b_gettid_np", "pthread_threadid_np(t, &tid)",
            "static int b_condattr_getclock", "*clock = (*a & 2L) ? 1 : 0",
            'TL_WRAP("pthread_getname_np", b_getname_np)',
            'TL_WRAP("pthread_gettid_np", b_gettid_np)',
            'TL_WRAP("pthread_condattr_getclock", b_condattr_getclock)',
            "if (!pthread_equal(t, pthread_self())) return 95;"
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, pthread)

    def test_bionic_dl_error_formatter_supports_versioned_symbol_diagnostics(self):
        bionic = self.read("Vendor/Husk/translation-layer-next/husk-tl-bionic.c")
        self.assertIn("static void dl_fail(const char *fmt, ...)", bionic)
        self.assertIn("vsnprintf(t_dlerr, sizeof(t_dlerr), fmt, ap)", bionic)
        self.assertIn('dl_fail("undefined symbol: %s@%s", name, version)', bionic)

    def test_elf_gnu_symbol_versioning_and_dlvsym_are_wired_end_to_end(self):
        loader = self.read("Vendor/Husk/translation-layer-next/husk-tl-ld.c")
        header = self.read("Vendor/Husk/translation-layer-next/husk-tl-ld.h")
        bionic = self.read("Vendor/Husk/translation-layer-next/husk-tl-bionic.c")
        for marker in (
            "DT_VERSYM_", "DT_VERDEF_", "DT_VERNEED_",
            "validate_version_tables", "symbol_version_name",
            "lib_find_version", "lookup_for_version",
            "tl_ld_sym_version", "tl_ld_sym_deep_version",
            "incomplete GNU version requirement"
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, loader)
        self.assertIn("tl_ld_sym_version", header)
        self.assertIn("bionic_dlvsym", bionic)
        self.assertIn('TL_WRAP("dlvsym", bionic_dlvsym)', bionic)
        self.assertNotIn("(void)ver; (void)caller; return bionic_dlsym(handle, name);", bionic)

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
