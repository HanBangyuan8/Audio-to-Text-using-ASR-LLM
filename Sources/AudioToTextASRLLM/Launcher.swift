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
        }

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

enum ASRAboutPanelPresenter {
    @MainActor
    static func show() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.1.0"
        let build = info?["CFBundleVersion"] as? String ?? "4"
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
