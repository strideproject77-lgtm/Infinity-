import SwiftUI
import Metal
import QuartzCore
import UIKit

private final class INFINITYHuskMetalView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }

    var onLayerReady: ((CAMetalLayer) -> Void)?
    var onTouch: ((Int, Int, Float, Float) -> Void)?
    private var pointerIDs: [ObjectIdentifier: Int] = [:]
    private var nextPointerID = 0

    var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .black
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
        backgroundColor = .black
        configureLayer()
    }

    private func configureLayer() {
        metalLayer.device = MTLCreateSystemDefaultDevice()
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.isOpaque = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = window?.screen.scale ?? UIScreen.main.scale
        contentScaleFactor = scale
        metalLayer.contentsScale = scale
        metalLayer.drawableSize = CGSize(width: bounds.width * scale,
                                         height: bounds.height * scale)
        if metalLayer.device != nil {
            onLayerReady?(metalLayer)
        }
    }

    private func deliver(_ touch: UITouch, phase: Int, removeAfter: Bool = false) {
        let key = ObjectIdentifier(touch)
        let pointer: Int
        if let existing = pointerIDs[key] {
            pointer = existing
        } else {
            pointer = nextPointerID
            nextPointerID += 1
            pointerIDs[key] = pointer
        }
        let point = touch.location(in: self)
        let scale = contentScaleFactor
        onTouch?(phase, pointer, Float(point.x * scale), Float(point.y * scale))
        if removeAfter { pointerIDs.removeValue(forKey: key) }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { deliver(touch, phase: 0) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { deliver(touch, phase: 1) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { deliver(touch, phase: 2, removeAfter: true) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { deliver(touch, phase: 3, removeAfter: true) }
    }
}

private struct INFINITYHuskSurface: UIViewRepresentable {
    let onLayerReady: (CAMetalLayer) -> Void
    let onTouch: (Int, Int, Float, Float) -> Void

    func makeUIView(context: Context) -> INFINITYHuskMetalView {
        let view = INFINITYHuskMetalView(frame: .zero)
        view.onLayerReady = onLayerReady
        view.onTouch = onTouch
        return view
    }

    func updateUIView(_ uiView: INFINITYHuskMetalView, context: Context) {
        uiView.onLayerReady = onLayerReady
        uiView.onTouch = onTouch
        uiView.setNeedsLayout()
    }
}

@available(iOS 16.0, *)
struct INFINITYAPKInstalledAppDetail: View {
    let app: INFINITYAPKInstalledApp

    private var canLaunch: Bool {
        guard !app.requiresSplits,
              app.detectedEngine != nil,
              INFINITYAPKStore.nativeRuntimeBundle() != nil else {
            return false
        }
        if app.detectedEngine == "java" {
            return INFINITYAPKStore.runtimeBundle() != nil
        }
        if app.detectedEngine == "unreal" {
            return FileManager.default.isReadableFile(atPath: INFINITYAPKStore.moltenVKLibraryURL.path)
        }
        return true
    }

    var body: some View {
        List {
            Section("Android app") {
                LabeledContent("Package", value: app.packageName)
                LabeledContent("Version", value: app.versionName ?? "Unknown")
                LabeledContent("Engine", value: app.detectedEngine ?? "Not identified")
                LabeledContent("Split APKs", value: app.requiresSplits ? "Required · not installed" : "Not required")
                LabeledContent("APK size", value: ByteCountFormatter.string(fromByteCount: Int64(clamping: app.archiveBytes), countStyle: .file))
                LabeledContent("Native libraries", value: "\(app.nativeLibraries.count)")
                if let activity = app.launchActivity {
                    LabeledContent("Launcher activity", value: activity)
                }
            }
            Section("Execution") {
                if canLaunch {
                    NavigationLink {
                        INFINITYAPKLaunchView(app: app)
                    } label: {
                        Label("Launch", systemImage: "play.fill")
                    }
                } else {
                    Label("Runtime assets required", systemImage: "exclamationmark.triangle")
                    Text(runtimeBlocker)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Storage") {
                Text("APK: \(INFINITYAPKStore.apkURL(for: app).lastPathComponent)")
                Text("Private data is stored separately from the APK, so reinstalling an update preserves app data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(app.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var runtimeBlocker: String {
        if app.requiresSplits {
            return "This app declares required split APKs. INFINITY currently imports one base APK only, so launch is blocked until split-package installation is implemented."
        }
        guard app.detectedEngine != nil else {
            return "The package's native engine could not be identified safely. No engine has been guessed."
        }
        guard INFINITYAPKStore.nativeRuntimeBundle() != nil else {
            return "The Android system files, fonts, certificates or signed ANGLE graphics library are missing."
        }
        if app.detectedEngine == "java" && INFINITYAPKStore.runtimeBundle() == nil {
            return "The Java APEX libraries, ICU/time-zone data, framework resources, or generated DEX files are incomplete."
        }
        if app.detectedEngine == "unreal" {
            return "The optional MoltenVK graphics library for this Unreal engine path is missing."
        }
        return "Required engine assets are not installed."
    }
}

@available(iOS 16.0, *)
struct INFINITYAPKLaunchView: View {
    let app: INFINITYAPKInstalledApp

    @StateObject private var runtime = INFINITYHuskRuntime()
    @State private var metalLayer: CAMetalLayer?
    @State private var launchAttempted = false
    @State private var launchError: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .top) {
            INFINITYHuskSurface(
                onLayerReady: { layer in
                    metalLayer = layer
                    launchIfReady(on: layer)
                },
                onTouch: { phase, pointer, x, y in
                    runtime.sendTouch(phase: phase, pointerID: pointer, x: x, y: y)
                }
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(app.displayName).font(.headline)
                    Spacer()
                    Text(String(format: "%.0f FPS", runtime.framesPerSecond))
                        .font(.caption.monospacedDigit())
                    Text(String(format: "%.1f ms", runtime.meanFrameMilliseconds))
                        .font(.caption.monospacedDigit())
                }
                if !runtime.isRunning && !launchAttempted {
                    ProgressView("Preparing Android surface…")
                } else if runtime.state == .starting {
                    ProgressView("Starting Android runtime…")
                }
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                } else if let error = runtime.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .background(.black)
        .navigationTitle(app.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { phase in
            guard launchAttempted else { return }
            let paused = phase != .active
            runtime.setPaused(paused)
        }
        .onDisappear { runtime.stop() }
    }

    private func launchIfReady(on layer: CAMetalLayer) {
        guard !launchAttempted else { return }
        guard layer.drawableSize.width > 0, layer.drawableSize.height > 0 else { return }
        launchAttempted = true

        do {
            guard let engine = selectedEngine else {
                throw INFINITYHuskRuntime.RuntimeError.rejectedLaunch
            }
            let apk = INFINITYAPKStore.apkURL(for: app)
            guard FileManager.default.isReadableFile(atPath: apk.path) else {
                throw INFINITYAPKStore.StoreError.missingInstalledAPK
            }
            let dataDirectory = try INFINITYAPKStore.dataURL(for: app)
            guard let nativeBundle = INFINITYAPKStore.nativeRuntimeBundle() else {
                throw INFINITYHuskRuntime.RuntimeError.nativeRuntimeNotPrepared
            }
            let angle = nativeBundle.angleLibrary
            let scale = layer.contentsScale
            let width = max(1, Int(layer.drawableSize.width))
            let height = max(1, Int(layer.drawableSize.height))
            let certificates = nativeBundle.certificateBundle

            if engine == .java {
                guard let bundle = INFINITYAPKStore.runtimeBundle() else {
                    throw INFINITYAPKStore.StoreError.missingRuntimeAssets
                }
                try runtime.prepareJava(runtimeRoot: bundle.javaRoot,
                                        density: Float(scale),
                                        certificatesDirectory: bundle.certificatesDirectory,
                                        systemFilesRoot: bundle.systemRoot,
                                        nightMode: UITraitCollection.current.userInterfaceStyle == .dark)
            } else {
                try runtime.prepareNative(certificatesDirectory: nativeBundle.certificatesDirectory,
                                          systemFilesRoot: nativeBundle.systemRoot)
            }

            let moltenVK = engine == .unreal ? INFINITYAPKStore.moltenVKLibraryURL : nil
            try runtime.launch(engine: engine, apk: apk, dataDirectory: dataDirectory,
                               metalLayer: layer, width: width, height: height,
                               angleLibrary: angle, certificateBundle: certificates,
                               moltenVKLibrary: moltenVK)
        } catch {
            launchError = error.localizedDescription
        }
    }

    private var selectedEngine: INFINITYHuskRuntime.Engine? {
        switch app.detectedEngine {
        case "unity": return .unity
        case "java": return .java
        case "cocos": return .cocos
        case "gameActivity": return .gameActivity
        case "sdl": return .sdl
        case "unreal": return .unreal
        case "godot": return .godot
        case "gta": return .gta
        case "flutter": return .flutter
        case "gameMaker": return .gameMaker
        default: return nil
        }
    }
}
