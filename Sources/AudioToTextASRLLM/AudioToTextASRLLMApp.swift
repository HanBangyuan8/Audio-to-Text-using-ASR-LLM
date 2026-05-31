import SwiftUI

@main
struct AudioToTextASRLLMApp: App {
    @StateObject private var viewModel = TranscriptionViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowStyle(.titleBar)
        .commands {
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
        }
    }
}
