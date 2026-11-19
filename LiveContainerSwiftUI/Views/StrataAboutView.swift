import SwiftUI

struct StrataAboutView: View {
        private let repository = URL(string: "https://github.com/strideproject77-lgtm/Infinity-")!
    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    if let icon = UIImage(contentsOfFile: Bundle.main.bundleURL.appendingPathComponent("AppIcon60x60@2x.png").path) {
                        Image(uiImage: icon).resizable().frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 19))
                    }
                    Text("INFINITY").font(.largeTitle.bold())
                    Text("Version " + INFINITYVersion.display).font(.subheadline).foregroundStyle(.secondary)
                    Text("Your apps. Your interface.").font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            Section("INFINITY project") {
                Link(destination: repository) { Label("Source code & project", systemImage: "chevron.left.forwardslash.chevron.right") }.accessibilityIdentifier("infinity.about.repository")
                Link(destination: repository.appendingPathComponent("releases")) { Label("Releases & updates", systemImage: "arrow.down.circle") }
                Link(destination: repository.appendingPathComponent("issues")) { Label("Report an issue", systemImage: "ladybug") }
            }
            Section("Upstream credits") {
                Link("LiveContainer", destination: URL(string: "https://github.com/LiveContainer/LiveContainer")!)
                Link("SideStore", destination: URL(string: "https://github.com/SideStore/SideStore")!)
                Link("StikJIT", destination: URL(string: "https://github.com/StikDebug/StikJIT")!)
                Link("LiveExec32", destination: URL(string: "https://github.com/LiveContainer/LiveExec32")!)
                Link("StosSign", destination: URL(string: "https://github.com/stossy11/StosSign")!)
                Link("Licenses & third-party notices", destination: repository.appendingPathComponent("blob/main/THIRD_PARTY_NOTICES.md"))
            }
        }.navigationTitle("About INFINITY").navigationBarTitleDisplayMode(.inline)
    }
}

struct StrataCreditsButton: View {
    var location = "infinity.about.button"
    @State private var showingAbout = false
    var body: some View {
        Button { showingAbout = true } label: {
            Label("About INFINITY", systemImage: "info.circle").frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityIdentifier(location)
        .sheet(isPresented: $showingAbout) {
            NavigationView {
                StrataAboutView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingAbout = false } } }
            }.navigationViewStyle(.stack)
        }
    }
}
