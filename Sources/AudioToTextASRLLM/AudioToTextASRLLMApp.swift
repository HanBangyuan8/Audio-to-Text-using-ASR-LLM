import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum MotionIntensity: String, CaseIterable, Identifiable {
    case enhanced
    case reduced
    case none

    var id: String { rawValue }
}

struct AccentColorOption: Identifiable, Hashable {
    let id: String
    let englishName: String
    let color: Color

    static let all: [AccentColorOption] = [
        AccentColorOption(id: "red", englishName: "Red", color: Color(red: 0.90, green: 0.24, blue: 0.28)),
        AccentColorOption(id: "orange", englishName: "Orange", color: Color(red: 0.94, green: 0.48, blue: 0.16)),
        AccentColorOption(id: "yellow", englishName: "Yellow", color: Color(red: 0.90, green: 0.72, blue: 0.18)),
        AccentColorOption(id: "green", englishName: "Green", color: Color(red: 0.22, green: 0.70, blue: 0.38)),
        AccentColorOption(id: "cyan", englishName: "Cyan", color: Color(red: 0.10, green: 0.70, blue: 0.76)),
        AccentColorOption(id: "blue", englishName: "Blue", color: Color(red: 0.20, green: 0.48, blue: 0.92)),
        AccentColorOption(id: "purple", englishName: "Purple", color: Color(red: 0.56, green: 0.34, blue: 0.88)),
        AccentColorOption(id: "pink", englishName: "Pink", color: Color(red: 0.92, green: 0.34, blue: 0.62)),
        AccentColorOption(id: "rose", englishName: "Rose", color: Color(red: 0.86, green: 0.30, blue: 0.42)),
        AccentColorOption(id: "amber", englishName: "Amber", color: Color(red: 0.96, green: 0.58, blue: 0.18)),
        AccentColorOption(id: "lime", englishName: "Lime", color: Color(red: 0.54, green: 0.76, blue: 0.22)),
        AccentColorOption(id: "mint", englishName: "Mint", color: Color(red: 0.18, green: 0.72, blue: 0.56)),
        AccentColorOption(id: "teal", englishName: "Teal", color: Color(red: 0.12, green: 0.58, blue: 0.70)),
        AccentColorOption(id: "indigo", englishName: "Indigo", color: Color(red: 0.36, green: 0.38, blue: 0.86)),
        AccentColorOption(id: "darkGray", englishName: "Dark Gray", color: Color(red: 0.36, green: 0.38, blue: 0.43)),
        AccentColorOption(id: "lightGray", englishName: "Light Gray", color: Color(red: 0.72, green: 0.74, blue: 0.78))
    ]

    static func option(for id: String) -> AccentColorOption {
        all.first { $0.id == id } ?? all[6]
    }
}

@available(macOS 12.0, *)
struct AccentColorPicker: View {
    @Binding var selection: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 16), spacing: 7), count: 8)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
            ForEach(AccentColorOption.all) { option in
                Button {
                    withAnimation(reduceMotion ? nil : MotionTokens.color) {
                        selection = option.id
                    }
                } label: {
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(option.color)
                            .frame(height: 14)
                            .overlay {
                                if selection == option.id {
                                    Capsule(style: .continuous)
                                        .strokeBorder(.primary.opacity(0.9), lineWidth: 1.5)
                                        .overlay {
                                            Capsule(style: .continuous)
                                                .strokeBorder(.white.opacity(0.9), lineWidth: 0.8)
                                        }
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
                    .contentShape(Rectangle())
                    .accessibilityLabel(option.englishName)
                }
                .buttonStyle(LightweightPressButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(macOS 12.0, *)
struct SidebarStatusRow<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            content
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

@available(macOS 12.0, *)
struct StatCard: View {
    let title: String
    let value: String
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            Text(title)
                .font((compact ? Font.footnote : Font.subheadline).weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: compact ? 20 : 23, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 14 : 18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .gentleAppear()
    }
}

@available(macOS 12.0, *)
struct SettingsRow<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if title.isEmpty {
                Spacer(minLength: 0)
                    .frame(width: 160)
            } else {
                Text(title)
                    .frame(width: 160, alignment: .leading)
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension View {
    @ViewBuilder
    func compatibleTint(_ color: Color) -> some View {
        if #available(macOS 13.0, *) {
            tint(color)
        } else {
            accentColor(color)
        }
    }
}

@MainActor
final class ASRAppDelegate: NSObject, NSApplicationDelegate {
    private let viewModel = TranscriptionViewModel()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    private func showMainWindow() {
        if window == nil {
            buildMainWindow()
            return
        }
        if window?.isMiniaturized == true {
            window?.deminiaturize(nil)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildMainWindow() {
        let rootView = ContentView()
            .environmentObject(viewModel)
        let hostingController = NSHostingController(rootView: rootView)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 820),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = "Audio to Text using ASR LLM"
        window.toolbarStyle = .unified
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

struct ContentView: View {
    @EnvironmentObject private var viewModel: TranscriptionViewModel

    var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                ASRNativeContentView(viewModel: viewModel)
            } else {
                ASRCompatibilityContentView(viewModel: viewModel)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            Task { @MainActor in
                viewModel.addAudioFiles(await loadDroppedFileURLs(from: providers))
            }
            return true
        }
    }

    private func loadDroppedFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
               let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                urls.append(url)
            } else if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
                      let url = item as? URL {
                urls.append(url)
            }
        }
        return urls
    }
}

@available(macOS 13.0, *)
private struct ASRNativeContentView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("interfaceMotion") private var motionIntensityID = MotionIntensity.enhanced.rawValue
    @AppStorage("interfaceAccent") private var accentColorID = "purple"
    @State private var selectedSidebarPage = "overview"
    @State private var navigationDirection: PageNavigationDirection = .downward

    private var motionIntensity: MotionIntensity { MotionIntensity(rawValue: motionIntensityID) ?? .enhanced }
    private var accentColor: Color { AccentColorOption.option(for: accentColorID).color }
    private var profile: VersionedMotionProfile { VersionedMotionProfile(runtimeProfile: .current, intensity: motionIntensity) }
    private var interfaceAnimation: Animation? { reduceMotion || motionIntensity == .none ? nil : profile.pageSwitchAnimation }
    private var pageTransition: AnyTransition { navigationDirection.transition(reduceMotion: reduceMotion, intensity: motionIntensity) }
    private var pageOrder: [String] { ["overview", "provider"] + viewModel.records.map { filePage($0.id) } }

    var body: some View {
        NavigationSplitView {
            ASRSidebar(
                viewModel: viewModel,
                selectedPage: $selectedSidebarPage,
                motionIntensityID: $motionIntensityID,
                accentColorID: $accentColorID,
                nativeNavigation: true,
                profile: profile,
                onSelectPage: selectPage
            )
            .navigationTitle("Audio to Text using ASR LLM")
            .navigationSplitViewColumnWidth(min: 248, ideal: 272, max: 330)
        } detail: {
            ASRDetailRouter(
                viewModel: viewModel,
                selectedPage: selectedSidebarPage,
                navigationDirection: navigationDirection,
                profile: profile,
                accentColor: accentColor,
                pageTransition: pageTransition,
                interfaceAnimation: interfaceAnimation,
                showsInlineActions: false
            )
            .navigationTitle("ASR Transcription")
        }
        .frame(minWidth: 1100, minHeight: 760)
        .tint(accentColor)
        .animation(interfaceAnimation, value: selectedSidebarPage)
        .animation(interfaceAnimation, value: accentColorID)
        .animation(interfaceAnimation, value: motionIntensityID)
        .versionedStartupMotion(profile: profile)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: viewModel.pickAudioFiles) {
                    Label("Add Audio", systemImage: "plus")
                }
                .help("Add audio files to the transcription queue")

                Button {
                    if viewModel.isTranscribing {
                        viewModel.cancelTranscription()
                    } else {
                        Task { await viewModel.transcribeSelectedFiles() }
                    }
                } label: {
                    Label(viewModel.isTranscribing ? "Cancel" : "Transcribe", systemImage: viewModel.isTranscribing ? "xmark" : "waveform")
                }
                .disabled(!viewModel.isTranscribing && !viewModel.canTranscribe)
                .help(viewModel.isTranscribing ? "Cancel the current queue" : "Transcribe queued audio files")

                Menu {
                    Button("Export Selected...", action: viewModel.exportSelectedResult)
                        .disabled(viewModel.selectedRecord?.result == nil)
                    Button("Export All Completed...", action: viewModel.exportAllCompletedResults)
                        .disabled(viewModel.completedRecords.isEmpty)
                    Divider()
                    Button("Reveal Selected Audio", action: viewModel.revealSelectedAudioFile)
                        .disabled(viewModel.selectedRecord == nil)
                    Button("Remove Selected", action: viewModel.removeSelectedRecord)
                        .disabled(viewModel.selectedRecord == nil || viewModel.isTranscribing)
                } label: {
                    Label("Queue Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .onChange(of: viewModel.selectedRecordID) { id in
            guard let id else { return }
            selectPage(filePage(id))
        }
    }

    private func selectPage(_ page: String) {
        guard page != selectedSidebarPage else { return }
        let currentIndex = pageOrder.firstIndex(of: selectedSidebarPage) ?? 0
        let nextIndex = pageOrder.firstIndex(of: page) ?? currentIndex
        navigationDirection = nextIndex >= currentIndex ? .downward : .upward
        withAnimation(interfaceAnimation) { selectedSidebarPage = page }
    }

    private func filePage(_ id: UUID) -> String { "file:\(id.uuidString)" }
}

private struct ASRCompatibilityContentView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("interfaceMotion") private var motionIntensityID = MotionIntensity.enhanced.rawValue
    @AppStorage("interfaceAccent") private var accentColorID = "purple"
    @State private var selectedSidebarPage = "overview"
    @State private var navigationDirection: PageNavigationDirection = .downward

    private var motionIntensity: MotionIntensity { MotionIntensity(rawValue: motionIntensityID) ?? .enhanced }
    private var accentColor: Color { AccentColorOption.option(for: accentColorID).color }
    private var profile: VersionedMotionProfile { VersionedMotionProfile(runtimeProfile: .current, intensity: motionIntensity) }
    private var interfaceAnimation: Animation? { reduceMotion || motionIntensity == .none ? nil : profile.pageSwitchAnimation }
    private var pageTransition: AnyTransition { navigationDirection.transition(reduceMotion: reduceMotion, intensity: motionIntensity) }
    private var pageOrder: [String] { ["overview", "provider"] + viewModel.records.map { filePage($0.id) } }

    var body: some View {
        HStack(spacing: 0) {
            ASRSidebar(
                viewModel: viewModel,
                selectedPage: $selectedSidebarPage,
                motionIntensityID: $motionIntensityID,
                accentColorID: $accentColorID,
                nativeNavigation: false,
                profile: profile,
                onSelectPage: selectPage
            )
            .frame(width: 238)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.82))

            Divider()

            ASRDetailRouter(
                viewModel: viewModel,
                selectedPage: selectedSidebarPage,
                navigationDirection: navigationDirection,
                profile: profile,
                accentColor: accentColor,
                pageTransition: pageTransition,
                interfaceAnimation: interfaceAnimation,
                showsInlineActions: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1010, minHeight: 760)
        .compatibleTint(accentColor)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(NSColor.windowBackgroundColor).opacity(0.98),
                    Color(NSColor.controlBackgroundColor).opacity(0.88)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .animation(interfaceAnimation, value: selectedSidebarPage)
        .animation(interfaceAnimation, value: accentColorID)
        .animation(interfaceAnimation, value: motionIntensityID)
        .versionedStartupMotion(profile: profile)
        .onChange(of: viewModel.selectedRecordID) { id in
            guard let id else { return }
            selectPage(filePage(id))
        }
    }

    private func selectPage(_ page: String) {
        guard page != selectedSidebarPage else { return }
        let currentIndex = pageOrder.firstIndex(of: selectedSidebarPage) ?? 0
        let nextIndex = pageOrder.firstIndex(of: page) ?? currentIndex
        navigationDirection = nextIndex >= currentIndex ? .downward : .upward
        withAnimation(interfaceAnimation) { selectedSidebarPage = page }
    }

    private func filePage(_ id: UUID) -> String { "file:\(id.uuidString)" }
}

private struct ASRSidebar: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @Binding var selectedPage: String
    @Binding var motionIntensityID: String
    @Binding var accentColorID: String
    let nativeNavigation: Bool
    let profile: VersionedMotionProfile
    let onSelectPage: (String) -> Void

    private var accentColor: Color { AccentColorOption.option(for: accentColorID).color }

    var body: some View {
        List {
            Section("Motion") {
                Picker("", selection: $motionIntensityID) {
                    Text("Enhanced").tag(MotionIntensity.enhanced.rawValue)
                    Text("Reduced").tag(MotionIntensity.reduced.rawValue)
                    Text("Off").tag(MotionIntensity.none.rawValue)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Section("Accent Color") {
                AccentColorPicker(selection: $accentColorID)
            }

            Section("Transcription") {
                pageButton("Overview", systemImage: "rectangle.stack", page: "overview")
                pageButton("Provider Settings", systemImage: "slider.horizontal.3", page: "provider")
            }

            Section("Audio Files") {
                ForEach(viewModel.records) { record in
                    let page = filePage(record.id)
                    Button {
                        viewModel.selectedRecordID = record.id
                        onSelectPage(page)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: record.status.symbolName).foregroundStyle(statusColor(record.status))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.file.name).lineLimit(1)
                                Text(record.status.label).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedPage == page { Image(systemName: "checkmark") }
                        }
                    }
                    .buttonStyle(pageStyle(selected: selectedPage == page))
                    .contextMenu {
                        Button("Reveal Audio File") {
                            viewModel.selectedRecordID = record.id
                            viewModel.revealSelectedAudioFile()
                        }
                        Button("Remove", role: .destructive) {
                            viewModel.selectedRecordID = record.id
                            viewModel.removeSelectedRecord()
                            onSelectPage("overview")
                        }
                        .disabled(viewModel.isTranscribing)
                    }
                }
            }

            Section("Status") {
                SidebarStatusRow(title: "Files") { Text("\(viewModel.records.count)").monospacedDigit() }
                SidebarStatusRow(title: "Completed") { Text("\(count(.complete))").monospacedDigit() }
                SidebarStatusRow(title: "Queued") { Text("\(count(.queued))").monospacedDigit() }
                SidebarStatusRow(title: "Queue") { Text(viewModel.isTranscribing ? "Running" : "Ready") }
                if viewModel.isTranscribing { ProgressView().controlSize(.small) }
                Text(viewModel.statusMessage).font(.footnote).foregroundStyle(viewModel.isTranscribing ? accentColor : .secondary).lineLimit(3)
            }
        }
        .listStyle(.sidebar)
    }

    private func count(_ status: TranscriptionStatus) -> Int { viewModel.records.filter { $0.status == status }.count }
    private func filePage(_ id: UUID) -> String { "file:\(id.uuidString)" }

    private func pageButton(_ title: String, systemImage: String, page: String) -> some View {
        Button { onSelectPage(page) } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if selectedPage == page { Image(systemName: "checkmark") }
            }
        }
        .buttonStyle(pageStyle(selected: selectedPage == page))
    }

    private func pageStyle(selected: Bool) -> ASRAnyButtonStyle {
        if nativeNavigation {
            return ASRAnyButtonStyle(VersionedPagePressButtonStyle(isSelected: selected, accentColor: accentColor, profile: profile))
        }
        return ASRAnyButtonStyle(Legacy15SidebarButtonStyle(isSelected: selected, accentColor: accentColor))
    }

    private func statusColor(_ status: TranscriptionStatus) -> Color {
        switch status {
        case .complete: .green
        case .failed: .red
        case .running: accentColor
        case .canceled: .secondary
        case .queued: .orange
        }
    }
}

private struct ASRAnyButtonStyle: ButtonStyle {
    private let bodyBuilder: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { bodyBuilder = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { bodyBuilder(configuration) }
}

private struct ASRDetailRouter: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    let selectedPage: String
    let navigationDirection: PageNavigationDirection
    let profile: VersionedMotionProfile
    let accentColor: Color
    let pageTransition: AnyTransition
    let interfaceAnimation: Animation?
    let showsInlineActions: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if showsInlineActions {
                    ASRActionStrip(viewModel: viewModel, accentColor: accentColor)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }
                Group {
                    if selectedPage == "provider" {
                        ASRProviderSettingsPage(viewModel: viewModel, profile: profile, accentColor: accentColor)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .id(selectedPage)
                    .transition(pageTransition)
                    .versionedPageSwitchMotion(profile: profile, pageID: selectedPage, direction: navigationDirection)
                    .coordinateSpace(name: "detailScroll")
                    } else if selectedPage.hasPrefix("file:") {
                        ASRTranscriptPage(viewModel: viewModel, profile: profile, accentColor: accentColor, pageID: selectedPage, direction: navigationDirection)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .id(selectedPage)
                    .transition(pageTransition)
                    .versionedPageSwitchMotion(profile: profile, pageID: selectedPage, direction: navigationDirection)
                    .coordinateSpace(name: "detailScroll")
                    } else {
                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                Color.clear.frame(height: 0).id("detailTop")
                                ASROverviewPage(viewModel: viewModel, profile: profile, accentColor: accentColor, direction: navigationDirection)
                                    .padding(20)
                                    .id(selectedPage)
                                    .transition(pageTransition)
                            }
                            .versionedPageSwitchMotion(profile: profile, pageID: selectedPage, direction: navigationDirection)
                            .coordinateSpace(name: "detailScroll")
                            .onChange(of: selectedPage) { _ in
                                withAnimation(interfaceAnimation) { scrollProxy.scrollTo("detailTop", anchor: .top) }
                            }
                            .onAppear {
                                scrollProxy.scrollTo("detailTop", anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ASRActionStrip: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    let accentColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Button(action: viewModel.pickAudioFiles) {
                Label("Add Audio", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            Button {
                if viewModel.isTranscribing {
                    viewModel.cancelTranscription()
                } else {
                    Task { await viewModel.transcribeSelectedFiles() }
                }
            } label: {
                Label(viewModel.isTranscribing ? "Cancel" : "Transcribe", systemImage: viewModel.isTranscribing ? "xmark" : "waveform")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isTranscribing && !viewModel.canTranscribe)

            Menu {
                Button("Export Selected...", action: viewModel.exportSelectedResult)
                    .disabled(viewModel.selectedRecord?.result == nil)
                Button("Export All Completed...", action: viewModel.exportAllCompletedResults)
                    .disabled(viewModel.completedRecords.isEmpty)
                Divider()
                Button("Reveal Selected Audio", action: viewModel.revealSelectedAudioFile)
                    .disabled(viewModel.selectedRecord == nil)
                Button("Remove Selected", action: viewModel.removeSelectedRecord)
                    .disabled(viewModel.selectedRecord == nil || viewModel.isTranscribing)
                Divider()
                Button("Reset Failed and Canceled", action: viewModel.resetFailedAndCanceled)
                Button("Clear Completed", action: viewModel.clearCompleted)
            } label: {
                Label("Queue", systemImage: "ellipsis.circle")
            }
            .disabled(viewModel.records.isEmpty)

            Spacer(minLength: 12)

            if viewModel.isTranscribing {
                ProgressView().controlSize(.small)
            }
            Text(viewModel.statusMessage)
                .font(.footnote)
                .foregroundStyle(viewModel.isTranscribing ? accentColor : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .compatibleTint(accentColor)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .interactivePanel(cornerRadius: 14, accentColor: accentColor)
    }
}

private struct ASROverviewPage: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    let profile: VersionedMotionProfile
    let accentColor: Color
    let direction: PageNavigationDirection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcription Overview")
                .font(.title2.bold())
                .versionedComponentAppear(profile: profile, pageID: "overview", direction: direction)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 12) {
                StatCard(title: "Files", value: "\(viewModel.records.count)", compact: true)
                StatCard(title: "Queued", value: "\(count(.queued))", compact: true)
                StatCard(title: "Running", value: "\(count(.running))", compact: true)
                StatCard(title: "Completed", value: "\(count(.complete))", compact: true)
                StatCard(title: "Failed", value: "\(count(.failed))", compact: true)
            }
            .versionedComponentAppear(profile: profile, pageID: "overview", direction: direction)

            Text("Recent Tasks").font(.title3.bold())
                .versionedComponentAppear(profile: profile, pageID: "overview", direction: direction)
            ASRTaskList(viewModel: viewModel, accentColor: accentColor)
                .frame(minHeight: 360)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .interactivePanel(cornerRadius: 16, accentColor: accentColor)
                .versionedComponentAppear(profile: profile, pageID: "overview", direction: direction)
        }
    }

    private func count(_ status: TranscriptionStatus) -> Int { viewModel.records.filter { $0.status == status }.count }
}

private struct ASRTaskList: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    let accentColor: Color

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                header("File").frame(maxWidth: .infinity, alignment: .leading)
                header("Status").frame(width: 120, alignment: .leading)
                header("Result").frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.secondary.opacity(0.08))

            Divider()

            if viewModel.records.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.badge.plus").font(.largeTitle)
                    Text("No audio files").font(.headline)
                    Text("Drop audio files here or use Add Audio Files.").font(.footnote).foregroundStyle(.secondary)
                    Button(action: viewModel.pickAudioFiles) {
                        Label("Add Audio Files", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .compatibleTint(accentColor)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.records) { record in
                            Button {
                                viewModel.selectedRecordID = record.id
                            } label: {
                                HStack(spacing: 12) {
                                    Text(record.file.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                    HStack(spacing: 6) {
                                        Image(systemName: record.status.symbolName)
                                        Text(record.status.label)
                                    }
                                    .foregroundStyle(statusColor(record.status))
                                    .frame(width: 120, alignment: .leading)
                                    Text(record.errorMessage ?? record.result?.model ?? "--")
                                        .foregroundStyle(record.errorMessage == nil ? Color.secondary : Color.red)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                            }
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .buttonStyle(.plain)
                            .background(viewModel.selectedRecordID == record.id ? accentColor.opacity(0.10) : Color.clear)
                            .contextMenu {
                                Button("Reveal Audio File") {
                                    viewModel.selectedRecordID = record.id
                                    viewModel.revealSelectedAudioFile()
                                }
                                Button("Remove", role: .destructive) {
                                    viewModel.selectedRecordID = record.id
                                    viewModel.removeSelectedRecord()
                                }
                                .disabled(viewModel.isTranscribing)
                            }
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func header(_ value: String) -> some View { Text(value).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
    private func statusColor(_ status: TranscriptionStatus) -> Color {
        switch status {
        case .complete: .green
        case .failed: .red
        case .running: accentColor
        case .canceled: .secondary
        case .queued: .orange
        }
    }
}

private struct ASRProviderSettingsPage: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    let profile: VersionedMotionProfile
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Provider Settings").font(.title2.bold())
                .versionedComponentAppear(profile: profile, pageID: "provider", direction: .unchanged)
            ScrollViewReader { scrollProxy in
                ScrollView {
                    Color.clear
                        .frame(height: 0)
                        .id("providerTop")

                    VStack(alignment: .leading, spacing: 10) {
                        settingsSection("Provider", index: 0) { providerRows }
                        settingsSection("Recognition", index: 1) { recognitionRows }
                        settingsSection("Reliability", index: 2) { reliabilityRows }
                        settingsSection("Advanced", index: 3) { advancedRows }
                    }
                }
                .onAppear {
                    scrollProxy.scrollTo("providerTop", anchor: .top)
                }
            }
            .versionedComponentAppear(profile: profile, pageID: "provider", direction: .unchanged)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func settingsSection<Content: View>(_ title: String, index: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline.weight(.semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) { content() }
                .settingsSolidCard(accentColor: accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .staggeredGroupAppear(index: index)
    }

    private var providerRows: some View {
        Group {
            SettingsRow(title: "Preset") {
                Picker("Preset", selection: Binding(
                    get: { "" },
                    set: { name in
                        guard let preset = ProviderPresets.all.first(where: { $0.name == name }) else { return }
                        viewModel.applyPreset(preset)
                    }
                )) {
                    Text("Custom").tag("")
                    ForEach(ProviderPresets.all) { Text($0.name).tag($0.name) }
                }
                .labelsHidden().pickerStyle(.menu)
            }
            SettingsRow(title: "Backend") {
                Picker("Backend", selection: $viewModel.configuration.backend) {
                    ForEach(ASRBackendMode.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu)
            }
            SettingsRow(title: "Base URL") { TextField("Base URL", text: $viewModel.configuration.baseURL).disabled(viewModel.configuration.backend == .localCommand) }
            SettingsRow(title: "Endpoint Path") { TextField("Endpoint Path", text: $viewModel.configuration.endpointPath).disabled(viewModel.configuration.backend == .localCommand) }
            SettingsRow(title: "API Key") { SecureField("API Key", text: $viewModel.configuration.apiKey).disabled(viewModel.configuration.backend == .localCommand) }
            SettingsRow(title: "ASR Model") { TextField("ASR Model", text: $viewModel.configuration.model) }
            if viewModel.configuration.backend == .apiChatAudio {
                SettingsRow(title: "Audio Payload") {
                    Picker("Audio Payload", selection: $viewModel.configuration.chatAudioPayload) {
                        ForEach(ChatAudioPayloadMode.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu)
                }
            }
            SettingsRow(title: "Configuration") {
                HStack {
                    Button("Import", action: viewModel.importConfiguration)
                    Button("Export", action: viewModel.exportConfiguration)
                }
            }
        }
    }

    private var recognitionRows: some View {
        Group {
            SettingsRow(title: "Language Hint") { TextField("e.g. zh, en, ja", text: $viewModel.configuration.language) }
            SettingsRow(title: "Response") {
                Picker("Response", selection: $viewModel.configuration.responseFormat) {
                    ForEach(ASRResponseFormat.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu)
            }
            SettingsRow(title: "Temperature") {
                HStack {
                    Slider(value: $viewModel.configuration.temperature, in: 0...1, step: 0.05)
                    Text("\(viewModel.configuration.temperature, specifier: "%.2f")").monospacedDigit().frame(width: 52, alignment: .trailing)
                }
            }
            SettingsRow(title: "Prompt") {
                editor(text: $viewModel.configuration.prompt, placeholder: "Glossary, speaker names, product names, and formatting preferences", height: 88)
            }
        }
    }

    private var reliabilityRows: some View {
        Group {
            SettingsRow(title: "Retries") {
                Stepper(value: $viewModel.configuration.maxRetries, in: 0...10) { Text("\(viewModel.configuration.maxRetries)") }
            }
            SettingsRow(title: "Timeout") {
                HStack {
                    Slider(value: $viewModel.configuration.requestTimeout, in: 30...3600, step: 30)
                    Text("\(Int(viewModel.configuration.requestTimeout)) s").monospacedDigit().frame(width: 72, alignment: .trailing)
                }
            }
        }
    }

    private var advancedRows: some View {
        Group {
            if viewModel.configuration.backend == .apiCustomJSON {
                SettingsRow(title: "Response Path") { TextField("choices.0.message.content", text: $viewModel.configuration.responseTextPath) }
                SettingsRow(title: "JSON Template") { editor(text: $viewModel.configuration.customJSONTemplate, placeholder: "Custom JSON body", height: 150, monospaced: true) }
            }
            if viewModel.configuration.backend == .localCommand {
                SettingsRow(title: "Local Command") { editor(text: $viewModel.configuration.localCommandTemplate, placeholder: "Command template", height: 96, monospaced: true) }
            }
            SettingsRow(title: "HTTP Headers") { editor(text: $viewModel.configuration.customHeaders, placeholder: "Header: value", height: 62, monospaced: true).disabled(viewModel.configuration.backend == .localCommand) }
            SettingsRow(title: "Multipart Fields") { editor(text: $viewModel.configuration.extraFields, placeholder: "key=value", height: 84, monospaced: true) }
        }
    }

    private func editor(text: Binding<String>, placeholder: String, height: CGFloat, monospaced: Bool = false) -> some View {
        TextEditor(text: text)
            .font(monospaced ? .system(.body, design: .monospaced) : .body)
            .frame(minHeight: height)
            .overlay(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder).foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                }
            }
    }
}

private struct ASRTranscriptPage: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    let profile: VersionedMotionProfile
    let accentColor: Color
    let pageID: String
    let direction: PageNavigationDirection

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id("transcriptTop")

                VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.selectedRecord?.file.name ?? "No Transcript Selected").font(.title2.bold()).lineLimit(1)
                        Text(viewModel.selectedRecord?.file.path ?? "Add an audio file to begin")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    HStack(spacing: 8) {
                        Picker("Export", selection: $viewModel.exportFormat) {
                            ForEach(TextExportFormat.allCases) { Text($0.label).tag($0) }
                        }
                        .frame(width: 150)
                        Button("Export", action: viewModel.exportSelectedResult).disabled(viewModel.selectedRecord?.result == nil)
                        Button("Copy", action: viewModel.copySelectedTranscript).disabled(viewModel.selectedRecord?.result == nil)
                        Menu("More") {
                            Button("Reveal Audio File", action: viewModel.revealSelectedAudioFile)
                            Button("Remove from Queue", role: .destructive, action: viewModel.removeSelectedRecord)
                                .disabled(viewModel.isTranscribing)
                        }
                        .disabled(viewModel.selectedRecord == nil)
                        Spacer()
                        if let record = viewModel.selectedRecord {
                            Label(record.status.label, systemImage: record.status.symbolName)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(statusColor(record.status))
                        }
                    }
                }
                .versionedComponentAppear(profile: profile, pageID: pageID, direction: direction)

                if let record = viewModel.selectedRecord {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        StatCard(title: "Status", value: record.status.label, compact: true)
                        StatCard(title: "Model", value: record.result?.model ?? viewModel.configuration.model, compact: true)
                        StatCard(title: "Segments", value: "\(record.result?.segments.count ?? 0)", compact: true)
                    }
                    .versionedComponentAppear(profile: profile, pageID: pageID, direction: direction)

                    if let error = record.errorMessage {
                        transcriptSection("Error") { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                    } else if let result = record.result {
                        transcriptSection("Transcript Preview") {
                            Text(result.text).font(.system(.body, design: .serif)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !result.segments.isEmpty {
                            transcriptSection("Segments") {
                                LazyVStack(alignment: .leading, spacing: 10) {
                                    ForEach(result.segments) { segment in
                                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                                            Text(timeRange(segment)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).frame(width: 150, alignment: .leading)
                                            Text(segment.text).textSelection(.enabled)
                                        }
                                        Divider()
                                    }
                                }
                            }
                        }
                    } else {
                        transcriptSection("Transcript Preview") {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass").font(.largeTitle)
                                Text("Completed transcriptions will appear here.").font(.footnote)
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 240)
                        }
                    }
                }
                }
            }
            .onAppear {
                scrollProxy.scrollTo("transcriptTop", anchor: .top)
            }
            .onChange(of: pageID) { _ in
                scrollProxy.scrollTo("transcriptTop", anchor: .top)
            }
        }
    }

    private func transcriptSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.bold())
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .interactivePanel(cornerRadius: 16, accentColor: accentColor)
        }
        .versionedComponentAppear(profile: profile, pageID: pageID, direction: direction)
    }

    private func timeRange(_ segment: TranscriptSegment) -> String {
        "\(formatTime(segment.start)) – \(formatTime(segment.end))"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        String(format: "%02d:%02d:%02d", Int(seconds / 3600), Int(seconds.truncatingRemainder(dividingBy: 3600) / 60), Int(seconds.truncatingRemainder(dividingBy: 60)))
    }

    private func statusColor(_ status: TranscriptionStatus) -> Color {
        switch status {
        case .complete: .green
        case .failed: .red
        case .running: accentColor
        case .canceled: .secondary
        case .queued: .orange
        }
    }
}

private extension TranscriptionStatus {
    var symbolName: String {
        switch self {
        case .queued: "clock"
        case .running: "waveform"
        case .complete: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .canceled: "xmark.circle"
        }
    }
}
