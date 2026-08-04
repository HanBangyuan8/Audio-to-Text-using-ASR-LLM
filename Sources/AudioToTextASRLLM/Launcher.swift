import AppKit
import SwiftUI

private enum ASRAppRuntime {
    static var delegate: ASRAppDelegate?
}

@main
enum AudioToTextASRLLMLauncher {
    static func main() {
        let runtimePlan = RuntimeFeaturePlan.current
        if runtimePlan.usesSwiftUIAppLifecycle, #available(macOS 13.0, *) {
            NativeAudioToTextASRLLMApp.main()
        } else {
            MainActor.assumeIsolated {
                let app = NSApplication.shared
                let delegate = ASRAppDelegate()
                ASRAppRuntime.delegate = delegate
                app.delegate = delegate
                app.setActivationPolicy(.regular)
                app.run()
            }
        }
    }
}

@available(macOS 13.0, *)
struct NativeAudioToTextASRLLMApp: App {
    @StateObject private var viewModel = TranscriptionViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .background(LaunchWindowSizeResetter(width: 1100, height: 760))
        }
        .defaultSize(width: 1100, height: 760)

        Settings {
            ContentView()
                .environmentObject(viewModel)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Audio to Text using ASR LLM") {
                    ASRAboutPanelPresenter.show()
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Add Audio Files...") {
                    viewModel.pickAudioFiles()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu("Transcription") {
                Button("Start Transcription") {
                    Task { await viewModel.transcribeSelectedFiles() }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!viewModel.canTranscribe)

                Button("Cancel") {
                    viewModel.cancelTranscription()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!viewModel.isTranscribing)

                Divider()

                Button("Export Selected...") {
                    viewModel.exportSelectedResult()
                }
                .disabled(viewModel.selectedRecord?.result == nil)

                Button("Export All Completed...") {
                    viewModel.exportAllCompletedResults()
                }
                .disabled(viewModel.completedRecords.isEmpty)
            }

            CommandMenu("Provider") {
                Button("Import Configuration...") {
                    viewModel.importConfiguration()
                }

                Button("Export Configuration...") {
                    viewModel.exportConfiguration()
                }
            }
        }
    }
}

@available(macOS 13.0, *)
private struct LaunchWindowSizeResetter: NSViewRepresentable {
    let width: CGFloat
    let height: CGFloat

    func makeNSView(context: Context) -> LaunchWindowSizingView {
        LaunchWindowSizingView(contentSize: NSSize(width: width, height: height))
    }

    func updateNSView(_ nsView: LaunchWindowSizingView, context: Context) {}
}

@available(macOS 13.0, *)
private final class LaunchWindowSizingView: NSView {
    private let launchContentSize: NSSize
    private var didApplyLaunchSize = false

    init(contentSize: NSSize) {
        launchContentSize = contentSize
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !didApplyLaunchSize, let window else { return }
        didApplyLaunchSize = true
        window.contentMinSize = launchContentSize
        window.setContentSize(launchContentSize)
        window.center()
    }
}

enum ASRAboutPanelPresenter {
    @MainActor
    static func show() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.2.0"
        let build = info?["CFBundleVersion"] as? String ?? "5"
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Audio to Text using ASR LLM",
            .applicationVersion: version,
            .version: build,
            .credits: NSAttributedString(
                string: "Native audio transcription queue, provider configuration, transcript review, and export management.",
                attributes: [.font: NSFont.systemFont(ofSize: 12)]
            )
        ])
    }
}
