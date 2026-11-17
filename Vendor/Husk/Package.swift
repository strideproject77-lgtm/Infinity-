// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "INFINITYHuskRuntime",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "INFINITYHuskRuntime",
            type: .static,
            targets: ["HuskTranslationCore", "HuskAppleAdapters"]
        )
    ],
    targets: [
        .target(
            name: "HuskTranslationCore",
            path: ".",
            exclude: [
                "build-support",
                "docs",
                "host-reference",
                "host-runtime",
                "resources",
                "upstream-docs",
                "objc-adapters",
                "tests",
                "scripts",
                "Package.swift",
                "UPSTREAM_REVISION.txt"
            ],
            sources: [
                "translation-layer",
                "translation-layer-next",
                "bridge"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("_DARWIN_C_SOURCE"),
                .unsafeFlags(["-fblocks"])
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("resolv"),
                .linkedLibrary("sqlite3"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreText"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ImageIO"),
                .linkedFramework("WebKit"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Security")
            ]
        ),
        .target(
            name: "HuskAppleAdapters",
            dependencies: ["HuskTranslationCore"],
            path: "objc-adapters",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-fobjc-arc", "-fblocks", "-D_DARWIN_C_SOURCE"])
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("UIKit"),
                .linkedFramework("CoreMotion"),
                .linkedFramework("WebKit"),
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore")
            ]
        )
    ],
    cLanguageStandard: .gnu11
)
