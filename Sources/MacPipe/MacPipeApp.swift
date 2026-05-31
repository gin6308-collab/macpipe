import SwiftUI
import AppKit

@main
struct MacPipeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 700)

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SPM-built apps don't become regular GUI apps by default.
        // This makes the app appear in Dock and accept keyboard focus.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MacPipe macOS")
                .font(.title2)
                .bold()

            Form {
                Section("About") {
                    LabeledContent("Version", value: "0.1.0-alpha")
                    LabeledContent("Extraction", value: "yt-dlp")
                    LabeledContent("Built with", value: "SwiftUI + AVKit")
                }

                Section("Privacy") {
                    Text("MacPipe macOS does not track you or store data externally. Watch history is local-only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 400, height: 250)
    }
}
