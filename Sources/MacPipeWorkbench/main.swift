import AppKit
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?
    private var serverProcess: Process?

    private let rootPath = "/Users/ginugeorge/macpipe"
    private let port = 8787

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        startServer()
        createWindow()
        loadWorkbenchWhenReady(attemptsRemaining: 40)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        serverProcess?.terminate()
    }

    private func startServer() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.currentDirectoryURL = URL(fileURLWithPath: rootPath)
        process.arguments = ["workbench/server.py", "--port", String(port)]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env

        let logURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("macpipe-workbench-app.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            process.standardOutput = handle
            process.standardError = handle
        }

        do {
            try process.run()
            serverProcess = process
        } catch {
            showError("Could not start MacPipe workbench server: \(error)")
        }
    }

    private func createWindow() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        self.webView = webView

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let targetArea = visibleFrame.width * visibleFrame.height * 0.20
        let aspectRatio: CGFloat = 1.2
        let targetWidth = sqrt(targetArea * aspectRatio)
        let targetHeight = targetWidth / aspectRatio
        let windowRect = NSRect(
            x: visibleFrame.midX - targetWidth / 2,
            y: visibleFrame.midY - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )

        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacPipe"
        window.minSize = NSSize(width: 460, height: 380)
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func loadWorkbenchWhenReady(attemptsRemaining: Int) {
        guard attemptsRemaining > 0 else {
            showError("MacPipe workbench server did not become ready on port \(port).")
            return
        }

        let url = URL(string: "http://127.0.0.1:\(port)/debug/health")!
        URLSession.shared.dataTask(with: url) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    self?.webView?.load(URLRequest(url: URL(string: "http://127.0.0.1:\(self?.port ?? 8787)/")!))
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self?.loadWorkbenchWhenReady(attemptsRemaining: attemptsRemaining - 1)
                    }
                }
            }
        }.resume()
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "MacPipe Workbench"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
