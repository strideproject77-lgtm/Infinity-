import SwiftUI
import Metal
import QuartzCore
import UIKit
import UniformTypeIdentifiers

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

    private var splitStatus: String {
        guard app.splitAPKCount > 0 else {
            return app.requiresSplits ? "Required · missing" : "Not required"
        }
        return "\(app.splitAPKCount) stored · Husk multi-APK loader wired"
    }

    var body: some View {
        List {
            Section("Android app") {
                LabeledContent("Package", value: app.packageName)
                LabeledContent("Version", value: app.versionName ?? "Unknown")
                LabeledContent("Engine", value: app.detectedEngine ?? "Not identified")
                LabeledContent("Split APKs", value: splitStatus)
                LabeledContent("APK size", value: ByteCountFormatter.string(fromByteCount: Int64(clamping: app.archiveBytes), countStyle: .file))
                LabeledContent("Native libraries", value: "\(app.nativeLibraries.count)")
                if let activity = app.launchActivity {
                    LabeledContent("Launcher activity", value: activity)
                }
            }
            Section("Runtime readiness") {
                LabeledContent("ANGLE graphics", value: INFINITYAPKStore.isANGLEEmbeddedAndReadable ? "Embedded" : "Missing")
                LabeledContent("Android system assets", value: INFINITYAPKStore.runtimeDataReady() ? "Installed" : "Incomplete")
                if app.detectedEngine == "java" {
                    LabeledContent("Java / ART assets", value: INFINITYAPKStore.runtimeBundle() != nil ? "Ready" : "Incomplete")
                }
                if app.detectedEngine == "unreal" {
                    LabeledContent("MoltenVK", value: INFINITYAPKStore.isMoltenVKEmbeddedAndReadable ? "Embedded" : "Missing")
                }
            }
            Section("Execution") {
                NavigationLink {
                    INFINITYAPKLaunchView(app: app)
                } label: {
                    Label("Launch", systemImage: "play.fill")
                }
                Text("Launch is always available here. Runtime assets required? Tap Launch and the screen will show the exact missing component instead of hiding the button.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

}

@available(iOS 16.0, *)
struct INFINITYHuskSessionLogView: View {
    @ObservedObject var logger: INFINITYHuskSessionLogger

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Launch and runtime events")
                    .font(.headline)
                Text(logger.contents.isEmpty ? "No session events captured yet." : logger.contents)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                Text("Husk native output")
                    .font(.headline)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let nativeLines = INFINITYHuskNativeLog.recentLines(800)
                    Text(nativeLines.isEmpty ? "Native output will appear here after runtime startup." : nativeLines.joined(separator: "\n"))
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("Session Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let url = logger.logURL {
                    ShareLink(item: url) { Image(systemName: "doc.text") }
                        .accessibilityLabel("Export session events")
                }
                ShareLink(item: INFINITYHuskNativeLog.logFileURL) {
                    Image(systemName: "terminal")
                }
                .accessibilityLabel("Export Husk log")
                ShareLink(item: INFINITYHuskNativeLog.nativeLogURL) {
                    Image(systemName: "waveform.path")
                }
                .accessibilityLabel("Export native stderr log")
            }
        }
    }
}


private struct INFINITYHuskActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

@available(iOS 16.0, *)
struct INFINITYAPKLaunchView: View {
    let app: INFINITYAPKInstalledApp

    @StateObject private var runtime = INFINITYHuskRuntime()
    @StateObject private var sessionLogger = INFINITYHuskSessionLogger()
    @ObservedObject private var gamepads = INFINITYHuskGamepadManager.shared
    @State private var showSessionLog = false
    @State private var metalLayer: CAMetalLayer?
    @State private var launchAttempted = false
    @State private var launchError: String?
    @State private var jitlessPreparationNote: String?
    @State private var hostKeyboardVisible = false
    @State private var hostKeyboardText = ""
    @State private var previousHostKeyboardText = ""
    @State private var hostKeyboardInputType: Int32 = 1
    @State private var hostSharePayload: INFINITYHuskSharePayload?
    @State private var hostDocumentPickerPresented = false
    @State private var hostDocumentMIMETypes = "*/*"
    @State private var hostDocumentAllowsMultiple = true
    @FocusState private var hostKeyboardFocused: Bool
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

            TextField("", text: $hostKeyboardText)
                .focused($hostKeyboardFocused)
                .keyboardType(hostKeyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit {
                    runtime.performJavaTextAction()
                    hostKeyboardText = ""
                    previousHostKeyboardText = ""
                    hostKeyboardFocused = false
                }
                .onChange(of: hostKeyboardText) { value in
                    let old = Array(previousHostKeyboardText)
                    let new = Array(value)
                    var common = 0
                    while common < old.count && common < new.count && old[common] == new[common] {
                        common += 1
                    }
                    if old.count > common {
                        for _ in common..<old.count { runtime.deleteJavaBackward() }
                    }
                    if new.count > common {
                        runtime.sendJavaText(String(new.dropFirst(common)))
                    }
                    previousHostKeyboardText = value
                }
                .onChange(of: hostKeyboardFocused) { focused in
                    if !focused && hostKeyboardVisible {
                        hostKeyboardVisible = false
                        runtime.closeJavaKeyboard()
                    }
                }
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(app.displayName).font(.headline)
                    Spacer()
                    Text(String(format: "%.0f FPS", runtime.framesPerSecond))
                        .font(.caption.monospacedDigit())
                    Text(String(format: "%.1f ms", runtime.meanFrameMilliseconds))
                        .font(.caption.monospacedDigit())
                    Button {
                        showSessionLog = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityLabel("View Session Log")
                }
                if !gamepads.names.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                        Text(gamepads.names.joined(separator: ", "))
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Connected controllers: " + gamepads.names.joined(separator: ", "))
                }
                if !runtime.isRunning && !launchAttempted {
                    ProgressView("Preparing Android surface…")
                } else if runtime.state == .starting {
                    ProgressView("Starting Android runtime…")
                }
                if let jitlessPreparationNote {
                    Text(jitlessPreparationNote).font(.caption).foregroundStyle(.secondary)
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
        .sheet(isPresented: $showSessionLog) {
            NavigationStack {
                INFINITYHuskSessionLogView(logger: sessionLogger)
            }
        }
        .onChange(of: scenePhase) { phase in
            guard launchAttempted else { return }
            let paused = phase != .active
            let event: String
            switch phase {
            case .active:
                event = "HOST_SCENE_ACTIVE"
            case .inactive:
                event = "HOST_SCENE_INACTIVE"
            case .background:
                event = "HOST_SCENE_BACKGROUND"
            @unknown default:
                event = "HOST_SCENE_UNKNOWN"
            }
            runtime.recordSessionEvent(event, details: "scenePhase=\(phase); pausing both native and Java engines=\(paused)")
            runtime.setPaused(paused)
            runtime.setJavaPaused(paused)
        }
        .onReceive(NotificationCenter.default.publisher(for: .infinityHuskKeyboardRequest)) { note in
            let info = note.userInfo ?? [:]
            let show = info["show"] as? Bool ?? false
            hostKeyboardInputType = info["inputType"] as? Int32 ?? 1
            hostKeyboardVisible = show
            hostKeyboardFocused = show
            if !show {
                hostKeyboardText = ""
                previousHostKeyboardText = ""
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .infinityHuskShareRequest)) { note in
            if let text = note.userInfo?["text"] as? String {
                hostSharePayload = INFINITYHuskSharePayload(text: text)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .infinityHuskOrientationRequest)) { note in
            if let orientation = note.userInfo?["orientation"] as? Int32 {
                applyAndroidOrientation(orientation)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .infinityHuskDocumentPickerRequest)) { note in
            let info = note.userInfo ?? [:]
            hostDocumentMIMETypes = info["mimeTypes"] as? String ?? "*/*"
            hostDocumentAllowsMultiple = info["multiple"] as? Bool ?? true
            hostDocumentPickerPresented = true
        }
        .fileImporter(isPresented: $hostDocumentPickerPresented,
                      allowedContentTypes: hostDocumentTypes,
                      allowsMultipleSelection: hostDocumentAllowsMultiple) { result in
            switch result {
            case .success(let urls):
                runtime.completeJavaDocumentPicker(urls, for: app)
            case .failure(let error):
                runtime.recordSessionEvent("DOCUMENT_PICKER_CANCELLED", details: error.localizedDescription)
                runtime.completeJavaDocumentPicker([], for: app)
            }
        }
        .sheet(item: $hostSharePayload) { payload in
            INFINITYHuskActivitySheet(items: [payload.text])
        }
        .onDisappear {
            hostKeyboardFocused = false
            // Capture the phase at the moment of disappearance. Checking only
            // after the delay can misclassify a background-to-active return as
            // a navigation dismissal and stop the engine on resume.
            let phaseAtDisappear = scenePhase
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                // UIKit's application state is the authoritative delayed check:
                // the SwiftUI environment value captured by this view can be stale
                // after the view disappears during an app switch.
                let appIsActive = UIApplication.shared.applicationState == .active
                if phaseAtDisappear == .active && appIsActive {
                    runtime.recordSessionEvent("LAUNCH_VIEW_DISMISSED", details: "stopping Husk after active navigation dismissal")
                    runtime.stop()
                } else {
                    runtime.recordSessionEvent("LAUNCH_VIEW_DISAPPEARED_INACTIVE", details: "keeping Husk session alive across system app switching; initialPhase=\(phaseAtDisappear), applicationState=\(UIApplication.shared.applicationState.rawValue)")
                }
            }
        }
    }

    private var hostKeyboardType: UIKeyboardType {
        switch hostKeyboardInputType & 0x0f {
        case 2: return .decimalPad
        case 3: return .phonePad
        case 4: return .numbersAndPunctuation
        default: return .default
        }
    }

    private var hostDocumentTypes: [UTType] {
        let values = hostDocumentMIMETypes.split(separator: ",").compactMap {
            UTType(mimeType: String($0).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return values.isEmpty ? [.item] : values
    }

    private func applyAndroidOrientation(_ requested: Int32) {
        guard #available(iOS 16.0, *) else {
            runtime.recordSessionEvent("ORIENTATION_REQUEST", details: "iOS 16 or later is required for a host orientation request")
            return
        }
        let mask: UIInterfaceOrientationMask
        switch requested {
        case 0, 6, 8: mask = .landscape
        case 1, 7, 9: mask = .portrait
        default: mask = .all
        }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            runtime.recordSessionEvent("ORIENTATION_ERROR", details: "No active window scene")
            return
        }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
            runtime.recordSessionEvent("ORIENTATION_ERROR", details: error.localizedDescription)
        }
    }

    private func launchIfReady(on layer: CAMetalLayer) {
        guard !launchAttempted else { return }
        guard layer.drawableSize.width > 0, layer.drawableSize.height > 0 else { return }
        launchAttempted = true
        Task { @MainActor in
            await prepareAndLaunch(on: layer)
        }
    }

    private func prepareAndLaunch(on layer: CAMetalLayer) async {
        // Start the upstream Husk stdio/crash capture before any C runtime preparation.
        INFINITYHuskNativeLog.start()
        INFINITYHuskNativeLog.log("session", "INFINITY APK launch requested for \(app.packageName)")
        launchError = nil
        let apk = INFINITYAPKStore.apkURL(for: app)
        let engineName = selectedEngine.map { String(describing: $0) } ?? app.detectedEngine
        let sessionLogURL = sessionLogger.begin(packageName: app.packageName,
                                                displayName: app.displayName,
                                                version: app.versionName,
                                                engine: engineName,
                                                apkURL: apk)
        runtime.attachSessionLogger(sessionLogger)
        runtime.recordSessionEvent("LAUNCH_REQUESTED",
                                   details: "splitRequired=\(app.requiresSplits) engine=\(engineName ?? "unknown")")
        if let sessionLogURL {
            runtime.recordSessionEvent("LOG_FILE", details: sessionLogURL.lastPathComponent)
        } else {
            launchError = "Session log could not be created. Launch will continue without persistent logging."
        }
        do {
            guard let engine = selectedEngine else {
                throw INFINITYHuskRuntime.RuntimeError.unsupportedEngine
            }
            let splitPackages = try INFINITYAPKStore.splitAPKURLs(for: app)
            if app.requiresSplits && splitPackages.isEmpty {
                throw INFINITYAPKStore.StoreError.missingSplitPackages
            }
            runtime.recordSessionEvent("PACKAGE_SET_VALIDATED",
                                       details: "base=\(apk.lastPathComponent) splits=\(splitPackages.count) engine=\(engine)")
            runtime.recordSessionEvent("ENGINE_SELECTED", details: String(describing: engine))
            guard FileManager.default.isReadableFile(atPath: apk.path) else {
                throw INFINITYAPKStore.StoreError.missingInstalledAPK
            }
            runtime.recordSessionEvent("APK_VALIDATED", details: "bytes=\((try? apk.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)")
            let dataDirectory = try INFINITYAPKStore.dataURL(for: app)
            runtime.recordSessionEvent("APP_DATA", details: "directoryReady=\((try? dataDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false)")
            let missingNativeAssets = INFINITYAPKStore.nativeRuntimeMissingAssets()
            guard missingNativeAssets.isEmpty,
                  let nativeBundle = INFINITYAPKStore.nativeRuntimeBundle() else {
                runtime.recordSessionEvent("NATIVE_RUNTIME_MISSING",
                                           details: missingNativeAssets.isEmpty
                                               ? "Native runtime bundle could not be resolved"
                                               : missingNativeAssets.joined(separator: ", "))
                throw INFINITYAPKStore.StoreError.missingNativeRuntimeAssets(missingNativeAssets)
            }
            runtime.recordSessionEvent("NATIVE_RUNTIME", details: "ANGLE and Android system assets resolved")
            let angle = nativeBundle.angleLibrary
            let scale = layer.contentsScale
            let width = max(1, Int(layer.drawableSize.width))
            let height = max(1, Int(layer.drawableSize.height))
            let certificates = nativeBundle.certificateBundle

            var javaBundle: INFINITYAPKRuntimeBundle?
            if engine == .java {
                let missingJavaAssets = INFINITYAPKStore.javaRuntimeMissingAssets()
                guard missingJavaAssets.isEmpty,
                      let bundle = INFINITYAPKStore.runtimeBundle() else {
                    runtime.recordSessionEvent("JAVA_RUNTIME_MISSING",
                                               details: missingJavaAssets.joined(separator: ", "))
                    throw INFINITYAPKStore.StoreError.missingJavaRuntimeAssets(missingJavaAssets)
                }
                javaBundle = bundle
                runtime.recordSessionEvent("JAVA_RUNTIME", details: "ART/runtime assets resolved")
            }

            let runtimeLibraries = javaBundle.map { javaRuntimeLibraries(in: $0.javaRoot) } ?? []
            let certificateP12 = LCUtils.certificateData()
            let certificatePassword = LCSharedUtils.certificatePassword()
            let certificateTeamID: String?
            if let certificateP12, let certificatePassword {
                certificateTeamID = LCUtils.getCertTeamId(withKeyData: certificateP12,
                                                          password: certificatePassword)
            } else {
                certificateTeamID = nil
            }

            let jitlessEnabled: Bool
            do {
                jitlessEnabled = try await Task.detached(priority: .userInitiated) {
                    try INFINITYJITLess.prepareForLaunch(
                        apk: apk,
                        nativeLibraryPaths: app.nativeLibraries,
                        runtimeLibraries: runtimeLibraries,
                        certificateP12: certificateP12,
                        certificatePassword: certificatePassword,
                        certificateTeamID: certificateTeamID,
                        appTeamID: LCSharedUtils.teamIdentifier()
                    )
                }.value
                jitlessPreparationNote = jitlessEnabled
                    ? "JIT-less AOT ready · required libraries signed"
                    : "No ARM64 native libraries require JIT-less AOT preparation."
                runtime.recordSessionEvent("JITLESS_PREPARATION", details: jitlessPreparationNote ?? "completed")
            } catch {
                jitlessEnabled = false
                try? INFINITYJITLess.configure(enabled: false)
                jitlessPreparationNote = "JIT-less AOT not enabled: \(error.localizedDescription)"
                runtime.recordSessionEvent("JITLESS_WARNING", details: error.localizedDescription)
            }

            let logURL = dataDirectory.appendingPathComponent(
                (engine == .unity ? "unity-run-" : "native-run-") + UUID().uuidString + ".log"
            )
            runtime.recordSessionEvent("NATIVE_DIAGNOSTIC_PATH", details: logURL.lastPathComponent)

            runtime.recordSessionEvent("RUNTIME_PREPARATION", details: "begin")
            if let javaBundle {
                try runtime.prepareJava(runtimeRoot: javaBundle.javaRoot,
                                        density: Float(scale),
                                        certificatesDirectory: javaBundle.certificatesDirectory,
                                        systemFilesRoot: javaBundle.systemRoot,
                                        nightMode: UITraitCollection.current.userInterfaceStyle == .dark)
            } else {
                try runtime.prepareNative(certificatesDirectory: nativeBundle.certificatesDirectory,
                                          systemFilesRoot: nativeBundle.systemRoot)
            }
            runtime.recordSessionEvent("RUNTIME_PREPARATION", details: "success")

            let moltenVK = engine == .unreal ? INFINITYAPKStore.moltenVKLibraryURL : nil
            runtime.recordSessionEvent("HUSK_LAUNCH_REQUEST",
                                       details: "engine=\(engine) splitPackages=\(splitPackages.count)")
            try runtime.launch(engine: engine, apk: apk, dataDirectory: dataDirectory,
                               metalLayer: layer, width: width, height: height,
                               angleLibrary: angle, certificateBundle: certificates,
                               moltenVKLibrary: moltenVK,
                               additionalPackages: splitPackages,
                               jitlessEnabled: jitlessEnabled,
                               diagnosticLogURL: logURL)
        } catch {
            let nsError = error as NSError
            launchError = error.localizedDescription
            runtime.recordSessionEvent("LAUNCH_ERROR",
                                       details: "domain=\(nsError.domain) code=\(nsError.code) message=\(error.localizedDescription)")
            sessionLogger.finish(outcome: "launch failed")
        }
    }

    private func javaRuntimeLibraries(in root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var libraries: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "so",
                  url.pathComponents.contains("lib64"),
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            libraries.append(url)
        }
        return libraries
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


@available(iOS 16.0, *)
struct INFINITYAPKLibraryView: View {
    @State private var apps: [INFINITYAPKInstalledApp] = []
    @State private var loadError: String?
    @State private var showingRuntimeFolderPicker = false
    @State private var runtimeReady = INFINITYAPKStore.runtimeDataReady()

    var body: some View {
        List {
            Section("Husk Runtime") {
                Label(runtimeReady ? "Android runtime assets installed" : "Runtime assets required",
                      systemImage: runtimeReady ? "checkmark.circle.fill" : "exclamationmark.triangle")
                    .foregroundStyle(runtimeReady ? .green : .secondary)
                Button {
                    showingRuntimeFolderPicker = true
                } label: {
                    Label("Import Husk Runtime Folder", systemImage: "shippingbox")
                }
                Text("First download the INFINITY Android runtime asset ZIP from GitHub Actions and extract it in Files. Select the extracted folder containing java-runtime, android-system and cacert.pem.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let loadError {
                Section {
                    Text(loadError).foregroundStyle(.red)
                }
            }
            if apps.isEmpty && loadError == nil {
                VStack(spacing: 10) {
                    Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                    Text("No APKs imported").font(.headline)
                    Text("Use the + button and choose Import IPA / APK to add an Android app.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                ForEach(apps) { app in
                    NavigationLink {
                        INFINITYAPKInstalledAppDetail(app: app)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.displayName).font(.headline)
                            Text(app.packageName).font(.caption).foregroundStyle(.secondary)
                            Text(app.detectedEngine ?? "Engine not identified")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: removeApps)
            }
        }
        .navigationTitle("Android APKs")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
        .onAppear(perform: reload)
        .fileImporter(isPresented: $showingRuntimeFolderPicker,
                      allowedContentTypes: [.folder],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let folders):
                guard let folder = folders.first else {
                    loadError = "No runtime folder was selected."
                    return
                }
                do {
                    try INFINITYAPKStore.installRuntimeAssets(from: folder)
                    runtimeReady = INFINITYAPKStore.runtimeDataReady()
                    loadError = runtimeReady ? nil : "Runtime import finished, but required files are still missing."
                } catch {
                    loadError = error.localizedDescription
                }
            case .failure(let error):
                loadError = error.localizedDescription
            }
        }
    }

    private func reload() {
        do {
            apps = try INFINITYAPKStore.installedApps()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func removeApps(at offsets: IndexSet) {
        let selected = offsets.map { apps[$0] }
        for app in selected {
            do {
                try INFINITYAPKStore.remove(packageName: app.packageName)
            } catch {
                loadError = error.localizedDescription
            }
        }
        reload()
    }
}
