// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "INFINITYHuskRuntime",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "INFINITYHuskRuntime",
            type: .static,
            targets: ["HuskTranslationRuntime"]
        )
    ],
    targets: [
        .target(
            name: "HuskTranslationRuntime",
            path: ".",
            exclude: [
                "build-support",
                "host-reference",
                "host-runtime",
                "resources",
                "src",
                "tools",
                "upstream-docs",
                "objc-adapters",
                "scripts",
                "Package.swift",
                "UPSTREAM_REVISION.txt",
                "translation-layer/stb_vorbis.inc",
                "translation-layer-next/husk-tl-codesign-wwdr.inc",
                "translation-layer-next/husk-tl-egl-es31.inc"
            ],
            sources: [
                "translation-layer",
                "translation-layer-next",
                "bridge"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("_DARWIN_C_SOURCE"),
                .headerSearchPath("translation-layer"),
                .headerSearchPath("translation-layer-next"),
                .headerSearchPath("include"),
                .unsafeFlags(["-fblocks", "-fobjc-arc", "-Wno-macro-redefined"])
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("resolv"),
                .linkedLibrary("sqlite3"),
                .linkedFramework("Foundation"),
                .linkedFramework("UIKit"),
                .linkedFramework("CoreMotion"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreText"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ImageIO"),
                .linkedFramework("WebKit"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Security"),
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore")
            ]
        )
    ],
    cLanguageStandard: .gnu11
)
