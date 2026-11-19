import Foundation
import Combine
import QuartzCore
import SwiftUI
import UIKit


/// Persistent, per-launch diagnostic capture for the embedded Husk session.
/// The file is append-only for the lifetime of one launch; prior sessions are retained.
@MainActor
final class INFINITYHuskSessionLogger: ObservableObject {
    @Published private(set) var logURL: URL?
    @Published private(set) var lines: [String] = []
    @Published private(set) var isRecording = false

    private var handle: FileHandle?
    private let formatter: ISO8601DateFormatter = {
        let value = ISO8601DateFormatter()
        value.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return value
    }()

    var contents: String { lines.joined(separator: "
") }

    @discardableResult
    func begin(packageName: String, displayName: String, version: String?,
               engine: String?, apkURL: URL) -> URL? {
        finish(outcome: "previous session closed before a new launch")
        do {
            let documents = try FileManager.default.url(for: .documentDirectory,
                                                        in: .userDomainMask,
                                                        appropriateFor: nil,
                                                        create: true)
            let safePackage = packageName.replacingOccurrences(
                of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression
            )
            let directory = documents
                .appendingPathComponent("INFINITY", isDirectory: true)
                .appendingPathComponent("SessionLogs", isDirectory: true)
                .appendingPathComponent(safePackage, isDirectory: true)
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
            let stamp = formatter.string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let file = directory.appendingPathComponent(
                "Session-\(stamp)-\(UUID().uuidString.prefix(8)).log"
            )
            guard FileManager.default.createFile(atPath: file.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
            handle = try FileHandle(forWritingTo: file)
            logURL = file
            lines = []
            isRecording = true
            record("SESSION_START", "INFINITY Husk diagnostic session")
            record("APP", "name=\(displayName) package=\(packageName) version=\(version ?? "unknown")")
            record("ENGINE", engine ?? "unidentified")
            record("APK", "name=\(apkURL.lastPathComponent) readable=\(FileManager.default.isReadableFile(atPath: apkURL.path))")
            record("HOST", "device=\(UIDevice.current.model) iOS=\(UIDevice.current.systemVersion) appBuild=\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")")
            return file
        } catch {
            logURL = nil
            isRecording = false
            recordInMemory("LOGGER_ERROR", error.localizedDescription)
            return nil
        }
    }

    func record(_ event: String, _ details: String = "") {
        guard isRecording else { return }
        let line = "[\(formatter.string(from: Date()))] [\(event)]\(details.isEmpty ? "" : " \(details)")"
        lines.append(line)
        if lines.count > 500 { lines.removeFirst(lines.count - 500) }
        if let data = (line + "
").data(using: .utf8) {
            do { try handle?.write(contentsOf: data) }
            catch { recordInMemory("LOGGER_WRITE_ERROR", error.localizedDescription) }
        }
    }

    func finish(outcome: String) {
        guard isRecording else { return }
        record("SESSION_END", outcome)
        do { try handle?.synchronize() } catch { }
        try? handle?.close()
        handle = nil
        isRecording = false
    }

    private func recordInMemory(_ event: String, _ details: String) {
        let line = "[\(formatter.string(from: Date()))] [\(event)] \(details)"
        lines.append(line)
        if lines.count > 500 { lines.removeFirst(lines.count - 500) }
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

/// Main-thread owner for the native Husk session embedded in Strata.
@MainActor
final class INFINITYHuskRuntime: ObservableObject {
    enum Engine: Int32 {
        case unity = 0
        case java = 1
        case cocos = 2
        case gameActivity = 3
        case sdl = 4
        case unreal = 5
        case godot = 6
        case gta = 7
        case flutter = 8
        case gameMaker = 9
    }

    enum State: Int32 {
        case idle = 0
        case starting = 1
        case running = 2
        case failed = 3
        case ended = 4
    }

    enum RuntimeError: LocalizedError {
        case javaRuntimeNotPrepared
        case nativeRuntimeNotPrepared
        case graphicsRuntimeNotPrepared
        case vulkanRuntimeNotPrepared
        case invalidSurface
        case rejectedLaunch
        case splitPackageNotSupported

        var errorDescription: String? {
            switch self {
            case .javaRuntimeNotPrepared:
                return "Android Java runtime assets are not prepared."
            case .nativeRuntimeNotPrepared:
                return "Android system libraries, fonts and certificates are not prepared."
            case .graphicsRuntimeNotPrepared:
                return "The ANGLE graphics runtime is missing or unreadable."
            case .vulkanRuntimeNotPrepared:
                return "The selected Unreal backend requires a readable MoltenVK library."
            case .invalidSurface:
                return "The Android surface has an invalid size."
            case .rejectedLaunch:
                return "Husk rejected the launch request. Check the APK, data folder and runtime assets."
            case .splitPackageNotSupported:
                return "This app requires split APK loading. The current Husk adapter only accepts a single base APK, so execution is blocked safely."
            }
        }
    }

    struct Performance {
        let fps: Double
        let meanMilliseconds: Double
        let maxMilliseconds: Double
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var frameCount: UInt = 0
    @Published private(set) var framesPerSecond: Double = 0
    @Published private(set) var meanFrameMilliseconds: Double = 0
    @Published private(set) var maxFrameMilliseconds: Double = 0
    @Published private(set) var loadedAPK: String?
    @Published private(set) var lastError: String?
    @Published private(set) var selectedEngine: Engine?
    @Published private(set) var isStopping = false

    private var javaRuntimePrepared = false
    private var pollingTask: Task<Void, Never>?
    private var diagnosticLogURL: URL?
    private var jitlessModeEnabled = false
    private var sessionLogger: INFINITYHuskSessionLogger?
    private var lastMetricsLogDate = Date.distantPast
    private var lastRecordedState: State = .idle

    var isRunning: Bool { state == .running || state == .starting }

    func attachSessionLogger(_ logger: INFINITYHuskSessionLogger) {
        sessionLogger = logger
        lastRecordedState = state
        lastMetricsLogDate = Date.distantPast
    }

    func recordSessionEvent(_ event: String, details: String = "") {
        sessionLogger?.record(event, details)
        INFINITYHuskNativeLog.log("session", details.isEmpty ? event : "\(event): \(details)")
    }

    func prepareNative(certificatesDirectory: URL,
                       systemFilesRoot: URL,
                       extraFontsDirectory: URL? = nil,
                       sharedStorageDirectory: URL? = nil) throws {
        let prepared = certificatesDirectory.path.withCString { certificates in
            systemFilesRoot.path.withCString { systemFiles in
                withOptionalCString(extraFontsDirectory?.path) { extraFonts in
                    withOptionalCString(sharedStorageDirectory?.path) { shared in
                        infinity_husk_prepare_native(certificates, systemFiles, extraFonts, shared)
                    }
                }
            }
        }
        guard prepared else { throw RuntimeError.nativeRuntimeNotPrepared }
        lastError = nil
    }

    func prepareJava(runtimeRoot: URL,
                     density: Float,
                     certificatesDirectory: URL,
                     systemFilesRoot: URL,
                     extraFontsDirectory: URL? = nil,
                     sharedStorageDirectory: URL? = nil,
                     nightMode: Bool) throws {
        let prepared = runtimeRoot.path.withCString { root in
            certificatesDirectory.path.withCString { certificates in
                systemFilesRoot.path.withCString { systemFiles in
                    withOptionalCString(extraFontsDirectory?.path) { extraFonts in
                        withOptionalCString(sharedStorageDirectory?.path) { shared in
                            infinity_husk_prepare_java(root, density, certificates, systemFiles,
                                                       extraFonts, shared, nightMode)
                        }
                    }
                }
            }
        }
        guard prepared else {
            javaRuntimePrepared = false
            throw RuntimeError.javaRuntimeNotPrepared
        }
        javaRuntimePrepared = true
        lastError = nil
    }

    func launch(engine: Engine,
                apk: URL,
                dataDirectory: URL,
                metalLayer: CAMetalLayer,
                width: Int,
                height: Int,
                angleLibrary: URL,
                certificateBundle: URL? = nil,
                moltenVKLibrary: URL? = nil,
                jitlessEnabled: Bool = false,
                diagnosticLogURL: URL? = nil) throws {
        if engine == .java && !javaRuntimePrepared {
            throw RuntimeError.javaRuntimeNotPrepared
        }
        guard width > 0, height > 0 else { throw RuntimeError.invalidSurface }
        guard let frameworks = Bundle.main.privateFrameworksURL else {
            throw RuntimeError.graphicsRuntimeNotPrepared
        }
        let embeddedANGLE = frameworks.appendingPathComponent("libANGLE-shared.dylib").standardizedFileURL
        guard angleLibrary.standardizedFileURL == embeddedANGLE,
              FileManager.default.isReadableFile(atPath: embeddedANGLE.path) else {
            throw RuntimeError.graphicsRuntimeNotPrepared
        }
        if engine == .unreal {
            let embeddedMoltenVK = frameworks.appendingPathComponent("libMoltenVK.dylib").standardizedFileURL
            guard let moltenVKLibrary,
                  moltenVKLibrary.standardizedFileURL == embeddedMoltenVK,
                  FileManager.default.isReadableFile(atPath: embeddedMoltenVK.path) else {
                throw RuntimeError.vulkanRuntimeNotPrepared
            }
        }

        let layer = Unmanaged.passUnretained(metalLayer).toOpaque()
        let accepted = apk.path.withCString { apkPath in
            dataDirectory.path.withCString { dataPath in
                angleLibrary.path.withCString { angle in
                    withOptionalCString(certificateBundle?.path) { certificates in
                        withOptionalCString(moltenVKLibrary?.path) { moltenVK in
                            infinity_husk_launch_engine(engine.rawValue, apkPath, dataPath,
                                                       layer, Int32(width), Int32(height),
                                                       angle, certificates, moltenVK)
                        }
                    }
                }
            }
        }
        guard accepted else { throw RuntimeError.rejectedLaunch }
        sessionLogger?.record("HUSK_LAUNCH_ACCEPTED", "engine=\(engine) surface=\(width)x\(height)")
        selectedEngine = engine
        self.jitlessModeEnabled = jitlessEnabled
        self.diagnosticLogURL = diagnosticLogURL
        lastError = nil
        beginPolling()
    }

    func launchJava(apk: URL,
                    dataDirectory: URL,
                    metalLayer: CAMetalLayer,
                    width: Int,
                    height: Int,
                    angleLibrary: URL,
                    certificateBundle: URL? = nil) throws {
        guard javaRuntimePrepared else { throw RuntimeError.javaRuntimeNotPrepared }
        try launch(engine: .java, apk: apk, dataDirectory: dataDirectory,
                   metalLayer: metalLayer, width: width, height: height,
                   angleLibrary: angleLibrary, certificateBundle: certificateBundle)
    }

    func launchUnity(apk: URL,
                     dataDirectory: URL,
                     metalLayer: CAMetalLayer,
                     width: Int,
                     height: Int,
                     angleLibrary: URL,
                     certificateBundle: URL? = nil) throws {
        try launch(engine: .unity, apk: apk, dataDirectory: dataDirectory,
                   metalLayer: metalLayer, width: width, height: height,
                   angleLibrary: angleLibrary, certificateBundle: certificateBundle)
    }

    func setJavaInsets(left: Int, top: Int, right: Int, bottom: Int, keyboardBottom: Int) {
        infinity_husk_java_set_insets(Int32(left), Int32(top), Int32(right),
                                      Int32(bottom), Int32(keyboardBottom))
    }

    func sendJavaTouch(phase: Int, pointerID: Int, x: Float, y: Float) {
        infinity_husk_java_touch(Int32(phase), Int32(pointerID), x, y)
    }

    func sendTouch(phase: Int, pointerID: Int, x: Float, y: Float) {
        infinity_husk_touch(Int32(phase), Int32(pointerID), x, y)
    }

    func sendJavaKey(androidKeyCode: Int, down: Bool) {
        infinity_husk_java_key(Int32(androidKeyCode), down)
    }

    func sendJavaText(_ text: String) {
        text.withCString { infinity_husk_java_insert_text($0) }
    }

    func deleteJavaBackward() {
        infinity_husk_java_delete_backward()
    }

    func performJavaTextAction() {
        infinity_husk_java_text_action()
    }

    func javaBack() {
        infinity_husk_java_back()
    }

    func setPaused(_ paused: Bool) {
        infinity_husk_set_paused(paused)
    }

    func setJavaPaused(_ paused: Bool) {
        infinity_husk_java_set_paused(paused)
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        // The C launch can be accepted before the first state poll updates SwiftUI.
        // Always ask the adapter to stop; it is an idempotent no-op without a session.
        // Native shutdown may wait for engine threads; never block the SwiftUI main actor.
        isStopping = true
        sessionLogger?.record("STOP_REQUESTED", "runtime shutdown requested")
        Task { [weak self] in
            await Task.detached(priority: .userInitiated) {
                infinity_husk_stop()
                try? INFINITYJITLess.configure(enabled: false)
            }.value
            guard let self else { return }
            self.refreshState()
            self.sessionLogger?.finish(outcome: "runtime stopped; finalState=\(self.state) frames=\(self.frameCount)")
            self.sessionLogger = nil
            self.resetPublishedSession()
            self.isStopping = false
        }
    }

    func refreshState() {
        state = State(rawValue: Int32(infinity_husk_get_state().rawValue)) ?? .failed
        frameCount = infinity_husk_frames()

        var fps = 0.0
        var mean = 0.0
        var maximum = 0.0
        infinity_husk_performance_snapshot(&fps, &mean, &maximum)
        framesPerSecond = fps
        meanFrameMilliseconds = mean
        maxFrameMilliseconds = maximum

        if let path = infinity_husk_loaded_apk() {
            loadedAPK = String(cString: path)
        } else {
            loadedAPK = nil
        }
        if state != lastRecordedState {
            sessionLogger?.record("STATE", "\(lastRecordedState) -> \(state) frames=\(frameCount)")
            lastRecordedState = state
        }
        if Date().timeIntervalSince(lastMetricsLogDate) >= 5, isRunning {
            sessionLogger?.record("PERFORMANCE", String(format: "fps=%.1f mean_ms=%.2f max_ms=%.2f frames=%lu",
                                                        framesPerSecond, meanFrameMilliseconds,
                                                        maxFrameMilliseconds, frameCount))
            lastMetricsLogDate = Date()
        }
        if state == .failed && lastError == nil {
            lastError = INFINITYJITLess.failureMessage(logURL: diagnosticLogURL,
                                                       jitlessEnabled: jitlessModeEnabled)
            sessionLogger?.record("RUNTIME_ERROR", lastError ?? "Husk entered failed state without an error message")
            sessionLogger?.finish(outcome: "failed")
        } else if state == .ended {
            sessionLogger?.finish(outcome: "ended normally; frames=\(frameCount)")
        }
    }

    func performanceSnapshot() -> Performance {
        Performance(fps: framesPerSecond,
                    meanMilliseconds: meanFrameMilliseconds,
                    maxMilliseconds: maxFrameMilliseconds)
    }

    func apkOrientation(_ apk: URL) -> Int {
        apk.path.withCString { Int(infinity_husk_apk_orientation($0)) }
    }

    func apkIsGame(_ apk: URL) -> Bool {
        apk.path.withCString { infinity_husk_apk_is_game($0) }
    }

    func apkRequiresSplits(_ apk: URL) -> Bool {
        apk.path.withCString { infinity_husk_apk_requires_splits($0) }
    }

    private func beginPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.refreshState()
                if self.state == .failed || self.state == .ended || self.state == .idle {
                    return
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }

    private func resetPublishedSession() {
        frameCount = 0
        framesPerSecond = 0
        meanFrameMilliseconds = 0
        maxFrameMilliseconds = 0
        loadedAPK = nil
        selectedEngine = nil
        diagnosticLogURL = nil
        jitlessModeEnabled = false
        lastRecordedState = .idle
        lastMetricsLogDate = .distantPast
    }

    private func withOptionalCString<T>(_ value: String?,
                                       _ body: (UnsafePointer<CChar>?) -> T) -> T {
        guard let value, !value.isEmpty else { return body(nil) }
        return value.withCString { body($0) }
    }
}
