import AppKit
import SwiftUI
import YuzuCore

typealias FormatAvailability = [FileFormat: [FileFormat: ConversionAvailability]]

@MainActor
struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var updater: AppUpdater
    @ObservedObject var access: AccessStore
    @State private var search = ""
    @State private var selectedFormat: FileFormat
    @State private var catalog: FormatAvailability

    init(settings: Settings, updater: AppUpdater, access: AccessStore,
         selectedFormat: FileFormat = .jpg, catalog: FormatAvailability = [:]) {
        self.settings = settings
        self.updater = updater
        self.access = access
        _selectedFormat = State(initialValue: selectedFormat)
        _catalog = State(initialValue: catalog)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.text("Settings"), selection: $settings.section) {
                ForEach(SettingsSection.allCases) { section in
                    Text(L10n.text(section.rawValue)).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(18)

            Group {
                switch settings.section {
                case .general: GeneralSettingsView(settings: settings, login: settings.loginItem)
                case .formats: formats
                case .compatibility: compatibility
                case .folders: folders
                case .about: about
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.orange)
        .accentColor(.orange)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            settings.loginItem.refresh()
            access.refresh()
        }
        .task {
            guard catalog.isEmpty else { return }
            // Encoder discovery belongs off the main actor, just like the wheel's source detection.
            let worker = Task.detached { try Self.makeCatalog() }
            let result = try? await withTaskCancellationHandler(operation: { try await worker.value },
                                                               onCancel: { worker.cancel() })
            if !Task.isCancelled, let result { catalog = result }
        }
    }

    nonisolated static func makeCatalog() throws -> FormatAvailability {
        let engine = ConversionEngine()
        var result: FormatAvailability = [:]
        for source in FileFormat.allCases {
            try Task.checkCancellation()
            result[source] = Dictionary(uniqueKeysWithValues: FileFormat.allCases.map {
                ($0, engine.availability(from: source, to: $0))
            })
        }
        return result
    }

    private var matchingFormats: [FileFormat] {
        FileFormat.allCases.filter {
            search.isEmpty || $0.label.localizedCaseInsensitiveContains(search)
                || L10n.text($0.category).localizedCaseInsensitiveContains(search)
        }
    }
    private let categories = ["Images", "Documents", "Audio", "Video", "Spreadsheets", "Subtitles", "Archives"]

    private var formats: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(L10n.text("Search"), text: $search).textFieldStyle(.plain)
                        .accessibilityLabel(L10n.text("Search formats"))
                }
                .padding(7)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(categories, id: \.self) { category in
                            let formats = matchingFormats.filter { $0.category == category }
                            if !formats.isEmpty {
                                Text(L10n.text(category)).font(.caption.bold()).foregroundStyle(.secondary)
                                    .padding(.top, 10).padding(.horizontal, 8)
                                ForEach(formats, id: \.self) { format in
                                    Button { selectedFormat = format } label: {
                                        Text(format.label)
                                            .frame(maxWidth: .infinity, alignment: .leading).padding(7)
                                            .background(selectedFormat == format ? Color.orange.opacity(0.22) : .clear,
                                                        in: RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(selectedFormat == format ? .isSelected : [])
                                }
                            }
                        }
                        if matchingFormats.isEmpty {
                            Text(L10n.text("No matching formats")).foregroundStyle(.secondary).padding(8)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .frame(width: 148)
            Divider()
            FormatSettingsView(settings: settings, format: selectedFormat, catalog: catalog)
                .id(selectedFormat)
        }
        .padding(.bottom, 12)
    }

    private var compatibility: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.text("Format Compatibility")).font(.headline)
                Text(L10n.text("✓ Available · ◐ Depends on the file · — Unavailable"))
                    .font(.caption).foregroundStyle(.secondary)
                Text(L10n.text("The tables show current Yuzu outputs on this Mac. Media compatibility also depends on the selected file."))
                    .font(.callout).foregroundStyle(.secondary)
                if catalog.isEmpty { ProgressView(L10n.text("Checking available formats…")) }
                ForEach(categories, id: \.self) { category in
                    let sources = FileFormat.allCases.filter { $0.category == category }
                    let targets = FileFormat.allCases.filter { target in
                        sources.contains { catalog[$0]?[target] != nil && catalog[$0]?[target] != .unavailable }
                    }
                    GroupBox {
                        if targets.isEmpty {
                            Text(L10n.text("No output formats are available for this group."))
                                .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(8)
                        } else {
                            ScrollView(.horizontal) {
                                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                                    GridRow {
                                        Text("↱").frame(width: 60, height: 28)
                                        ForEach(targets, id: \.self) { Text($0.label).frame(width: 44, height: 28) }
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    ForEach(sources, id: \.self) { source in
                                        GridRow {
                                            Text(source.label).font(.system(size: 10, weight: .semibold))
                                                .frame(width: 60, height: 27)
                                            ForEach(targets, id: \.self) { target in
                                                let state = catalog[source]?[target] ?? .unavailable
                                                Text(symbol(for: state)).frame(width: 44, height: 27)
                                                    .foregroundStyle(state == .unavailable ? Color.secondary.opacity(0.45) : Color.primary)
                                                    .accessibilityLabel(L10n.text("%@ to %@: %@", source.label, target.label, title(for: state)))
                                            }
                                        }
                                        .background(Color.primary.opacity(0.025))
                                    }
                                }
                                .padding(6)
                            }
                        }
                    } label: { Text(L10n.text(category)).font(.headline) }
                }
                Link(L10n.text("Format support and limitations"),
                     destination: URL(string: "https://github.com/StPashik/Yuzu-converter/blob/main/docs/Conversion-matrix.md")!)
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    private func symbol(for state: ConversionAvailability) -> String {
        switch state { case .available: return "✓"; case .dependsOnFile: return "◐"; case .unavailable: return "—" }
    }
    private func title(for state: ConversionAvailability) -> String {
        switch state {
        case .available: return L10n.text("Available")
        case .dependsOnFile: return L10n.text("Depends on the file")
        case .unavailable: return L10n.text("Unavailable")
        }
    }

    private var folders: some View {
        Form {
            Section {
                Text(L10n.text("Yuzu saves results beside the originals. Add a folder to remember permission for it and its subfolders."))
                    .foregroundStyle(.secondary)
                if access.folders.isEmpty {
                    Label(L10n.text("No folders added yet"), systemImage: "folder")
                        .foregroundStyle(.secondary).padding(.vertical, 8)
                }
                ForEach(access.folders, id: \.path) { folder in
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill").foregroundStyle(.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(folder.lastPathComponent.isEmpty ? folder.path : folder.lastPathComponent)
                            Text(folder.path).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                .truncationMode(.middle).textSelection(.enabled)
                        }
                        Spacer()
                        Button { access.forgetFolder(folder) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(L10n.text("Forget access to %@", folder.path))
                            .help(L10n.text("Forget access to %@", folder.path))
                    }
                    .padding(.vertical, 3)
                }
                HStack {
                    Spacer()
                    Button(L10n.text("Add Folder…")) {
                        do { try access.addFolder() } catch { ActionController.show(error) }
                    }
                }
            } header: { Text(L10n.text("Folder Access")) }
            Text(L10n.text("Forgetting a folder keeps its files and active jobs intact. Yuzu will ask again when access is needed."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var about: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable().scaledToFit().frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text("Yuzu Converter").font(.title2.bold())
                Text(L10n.text("Version %@", Bundle.main.bundleIdentifier == "com.stpashik.yuzu-converter"
                               ? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L10n.text("Development")
                               : L10n.text("Development")))
                    .foregroundStyle(.secondary)
                Text(L10n.text("Convert files and run Actions from your menu bar."))
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button(L10n.text("Check for Updates…")) { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates).controlSize(.large)
                Text(L10n.text(updater.installationWaiting
                    ? "The update will install when file operations finish."
                    : "Updates are checked only when you ask. Installation requires your confirmation."))
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
                HStack(spacing: 22) {
                    Link(L10n.text("Documentation"), destination: URL(string: "https://github.com/StPashik/Yuzu-converter#readme")!)
                    Link(L10n.text("Releases"), destination: URL(string: "https://github.com/StPashik/Yuzu-converter/releases")!)
                }
                .padding(.top, 8)
                Text(L10n.text("Media conversion uses FFmpeg under LGPL 2.1 or later."))
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Link(L10n.text("Media engine source and licenses"), destination: URL(string: "https://github.com/StPashik/Yuzu-converter/blob/main/docs/Bundled-media.md")!)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity).padding(32).padding(.top, 40)
        }
    }
}

@MainActor
private struct GeneralSettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var login: LoginItemController

    var body: some View {
        Form {
            Section {
                Picker(L10n.text("Style"), selection: $settings.wheelStyle) {
                    ForEach(WheelStyle.allCases) { Text(L10n.text($0.rawValue)).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(L10n.text("Glass uses the macOS backdrop. Reduce Transparency uses a solid surface."))
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text(L10n.text("Appearance")) }

            Section {
                Toggle(L10n.text("Launch at login"), isOn: Binding(get: { login.isRequested }, set: { login.setEnabled($0) }))
                    .disabled(!login.isAvailable)
                if let message = login.message, login.errorMessage == nil {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                if let message = login.errorMessage {
                    Text(L10n.text(message)).font(.caption).foregroundStyle(.red)
                }
                if login.requiresApproval || login.errorMessage != nil {
                    Button(L10n.text("Open Login Items")) { login.openLoginItems() }
                }
                Toggle(L10n.text("Sound and haptic feedback"), isOn: $settings.soundsAndHapticsEnabled)
                Toggle(L10n.text("Enable wheels"), isOn: $settings.wheelsEnabled)
                Picker(L10n.text("Language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.name).tag($0) }
                }
                Text(L10n.text("Some system dialogs use the new language after restarting the app."))
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text(L10n.text("General")) }

            Section {
                modifierPicker("Conversion wheel", mode: .conversion)
                modifierPicker("Actions wheel", mode: .actions)
                Text(L10n.text("Tap the chosen modifier combination while dragging files. Escape cancels selection."))
                    .font(.caption).foregroundStyle(.secondary)
                Text(settings.shortcutDescription).font(.callout.monospaced())
            } header: { Text(L10n.text("Drag Modifiers")) }

            Section {
                Picker(L10n.text("Float Behaviour"), selection: $settings.addToShelf) {
                    Text(L10n.text("Create a New Float")).tag(false)
                    Text(L10n.text("Add to Existing Float")).tag(true)
                }
                ShelfShortcutSettingsView(controller: settings.shelfShortcut)
                Picker(L10n.text("Terminal app"), selection: $settings.terminalApplication) {
                    ForEach(TerminalApplication.allCases) { Text($0.name).tag($0) }
                }
            } header: { Text(L10n.text("Actions")) }
        }
        .formStyle(.grouped)
        .toggleStyle(.checkbox)
        .controlSize(.small)
    }

    private func modifierPicker(_ title: String, mode: WheelMode) -> some View {
        Picker(L10n.text(title), selection: Binding(
            get: { mode == .conversion ? settings.conversionModifier : settings.actionsModifier },
            set: { settings.setModifier($0, for: mode) }
        )) {
            ForEach(DragModifier.allCases) { modifier in
                Text(modifier.displayName).tag(modifier).accessibilityLabel(modifier.title)
            }
        }
    }
}

private struct ShelfShortcutSettingsView: View {
    @ObservedObject var controller: ShelfShortcutController
    var body: some View {
        HStack {
            Text(L10n.text("Add Finder selection to shelf"))
            Spacer()
            ShelfShortcutRecorder(controller: controller).fixedSize()
        }
        Text(L10n.text("Click to record. Escape cancels; Delete disables the shortcut."))
            .font(.caption).foregroundStyle(.secondary)
        Text(L10n.text("Works while Finder is active. First use may ask for Finder and folder access."))
            .font(.caption).foregroundStyle(.secondary)
        if let message = controller.errorMessage {
            Text(L10n.text(message)).font(.caption).foregroundStyle(.red)
        }
    }
}

@MainActor
private struct FormatSettingsView: View {
    @ObservedObject var settings: Settings
    let format: FileFormat
    let catalog: FormatAvailability

    private var video: Bool { [.mp4, .mov, .mkv, .webm, .avi, .wmv].contains(format) }
    private var lossyAudio: Bool { [.mp3, .m4a, .ogg, .opus, .wma].contains(format) }
    private var raster: Bool { [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp].contains(format) }
    private var hasQuality: Bool { video || lossyAudio || [.jpg, .heic, .webp, .avif].contains(format) }
    private var hasMetadata: Bool { raster || video || lossyAudio || format == .flac }
    private var outputAvailable: Bool {
        catalog.values.contains { $0[format] != nil && $0[format] != .unavailable }
    }
    private var targets: [FileFormat] {
        FileFormat.allCases.filter { catalog[format]?[$0] != nil && catalog[format]?[$0] != .unavailable }
    }
    private var hasOptions: Bool {
        hasQuality || hasMetadata || [.wav, .aiff, .gif, .zip, .gzip, .epub, .docx, .pages, .pptx, .xlsx].contains(format)
    }

    var body: some View {
        Form {
            Section {
                Text(L10n.text("%@ Settings", format.label)).font(.headline)
                Text(L10n.text("Conversion defaults apply to this output format. Queued jobs keep their original settings."))
                    .font(.callout).foregroundStyle(.secondary)
                if catalog.isEmpty {
                    ProgressView(L10n.text("Checking available formats…"))
                } else {
                    Text(targets.isEmpty ? L10n.text("No output formats are available for this input.")
                         : L10n.text("Available output formats: %@", targets.map(\.label).joined(separator: ", ")))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                if hasQuality {
                    Picker(L10n.text("Quality"), selection: option(\.quality)) {
                        Text(L10n.text("Compact")).tag(ConversionQuality.compact)
                        Text(L10n.text("Balanced")).tag(ConversionQuality.balanced)
                        Text(L10n.text("High")).tag(ConversionQuality.high)
                    }
                    .disabled(lossyAudio && settings.options(for: format).audioBitrate != nil)
                }
                if hasMetadata {
                    Toggle(L10n.text("Preserve metadata"), isOn: option(\.preserveMetadata))
                    Text(L10n.text(raster
                        ? "Keeps supported source metadata. Turning this off removes descriptive metadata; image orientation and color stay correct."
                        : "Preserve supported descriptive metadata, such as titles, comments, and location tags."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if video {
                    numberPicker("Maximum video height", path: \.videoMaxHeight, values: [nil, 480, 720, 1080, 2160], unit: "%ld px")
                }
                if lossyAudio {
                    numberPicker("Audio bitrate", path: \.audioBitrate, values: [nil, 64, 96, 128, 192, 256, 320], unit: "%ld kbit/s")
                    Text(L10n.text("Automatic bitrate follows quality. An explicit bitrate overrides the quality preset."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if format == .wav || format == .aiff {
                    Picker(L10n.text("Audio sample depth"), selection: option(\.audioSampleDepth)) {
                        Text(L10n.text("Match source")).tag(AudioSampleDepth.matchSource)
                        Text(L10n.text("16-bit")).tag(AudioSampleDepth.bit16)
                        Text(L10n.text("24-bit")).tag(AudioSampleDepth.bit24)
                        Text(L10n.text("32-bit")).tag(AudioSampleDepth.bit32)
                        Text(L10n.text("32-bit float")).tag(AudioSampleDepth.float32)
                    }
                }
                if format == .gif {
                    numberPicker("GIF frame rate", path: \.gifFrameRate, values: [nil, 10, 15, 24, 30, 60], unit: "%ld fps")
                    numberPicker("Maximum GIF width", path: \.gifMaxWidth, values: [nil, 320, 480, 640, 960, 1280], unit: "%ld px")
                }
                if format == .zip || format == .gzip {
                    Picker(L10n.text("Compression"), selection: option(\.compression)) {
                        Text(L10n.text("Fast")).tag(ArchiveCompression.fast)
                        Text(L10n.text("Balanced")).tag(ArchiveCompression.balanced)
                        Text(L10n.text("Maximum")).tag(ArchiveCompression.maximum)
                    }
                    if format == .zip {
                        Text(L10n.text("Also applies to the Compress to ZIP Action. Originals stay in place."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if format == .epub {
                    Picker(L10n.text("EPUB version"), selection: option(\.epubReflowVersion)) {
                        Text("EPUB 2").tag(2)
                        Text("EPUB 3").tag(3)
                    }
                    Picker(L10n.text("Layout"), selection: option(\.epubLayout)) {
                        Text(L10n.text("Adjustable text")).tag(EPUBLayout.adjustableText)
                        Text(L10n.text("Preserve original pages")).tag(EPUBLayout.preservePages)
                    }
                    .disabled(true)
                    Text(L10n.text("Original-page EPUB layout is unavailable with the current document reader."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if [.docx, .pages, .pptx, .xlsx].contains(format) {
                    Picker(L10n.text("PDF to Office layout"), selection: option(\.pdfOfficeLayout)) {
                        Text(L10n.text("Editable")).tag(PDFOfficeLayout.editable)
                        Text(L10n.text("Preserve original pages")).tag(PDFOfficeLayout.preservePages)
                    }
                    .disabled(true)
                    Text(L10n.text("PDF to Office reconstruction is unavailable in this version. Text and images do not recreate editable document layout."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !hasOptions {
                    Text(L10n.text("This format has no adjustable conversion settings.")).foregroundStyle(.secondary)
                }
                if hasOptions {
                    HStack {
                        Spacer()
                        Button(L10n.text("Restore Defaults")) { settings.resetOptions(for: format) }
                    }
                }
            } header: { Text(L10n.text("Conversion Settings")) }
            .disabled(!outputAvailable)

            if !outputAvailable && !catalog.isEmpty {
                Text(L10n.text("This output is unavailable with the current app backends. Its settings remain visible for reference."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if format == .gif {
                Text(L10n.text("GIF exports are animated and contain no audio."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if [.xlsx, .ods, .csv, .tsv].contains(format) {
                Text(L10n.text("Values only. Formulas, formatting, and embedded objects are not preserved."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func option<Value>(_ path: WritableKeyPath<ConversionOptions, Value>) -> Binding<Value> {
        Binding(get: { settings.options(for: format)[keyPath: path] }, set: { value in
            var options = settings.options(for: format)
            options[keyPath: path] = value
            settings.setOptions(options, for: format)
        })
    }

    private func numberPicker(_ title: String, path: WritableKeyPath<ConversionOptions, Int?>,
                              values: [Int?], unit: String) -> some View {
        Picker(L10n.text(title), selection: option(path)) {
            ForEach(values, id: \.self) { value in
                Text(value.map { L10n.text(unit, $0) } ?? L10n.text("Automatic")).tag(value)
            }
        }
    }
}
