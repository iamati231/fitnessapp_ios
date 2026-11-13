#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import DeltiqCore
import DeltiqData
#if canImport(AVKit)
import AVKit
#endif

/// DEL-161 / Issue #9: Metadaten-Editor fuer die Uebungsbibliothek. Drei Modi, abgeleitet
/// aus dem uebergebenen Template:
///   * `template == nil`        → **Create**: legt ein neues Custom-Template an.
///   * `template.isCustom`      → **Edit**: editiert Name/Muskel/Equipment/
///                                 Compound + optionales Demonstrationsmedium.
///   * `template` System-Eintrag → **Read-Only**: zeigt die Basis-Metadaten,
///                                 nicht editierbar (App-Templates geschuetzt).
@available(iOS 17.0, macOS 14.0, *)
struct ExerciseLibraryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    /// Bestehendes Template (Edit/Read-Only) oder nil (Create).
    private let existing: ExerciseTemplate?

    @State private var name: String
    @State private var muscle: MuscleGroup
    @State private var equipment: Equipment
    @State private var isCompound: Bool
    @State private var showingDiscardConfirm = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @State private var showGifSheet = false

    // MARK: Issue #9 — Custom media state
    @State private var mediaFilename: String?
    @State private var youtubeURL: String?
    @State private var showVideoImporter = false
    @State private var showGifImporter = false
    @State private var showYouTubeAlert = false
    @State private var youtubeInput = ""
    @State private var mediaError: String?
    @State private var showMediaFullscreen = false
    /// Prevents orphaned files from discarded create sessions.
    @State private var isSaved = false

    init(template: ExerciseTemplate?) {
        self.existing = template
        _name = State(initialValue: template?.name ?? "")
        _muscle = State(initialValue: template?.primaryMuscle ?? .chest)
        _equipment = State(initialValue: template?.equipment ?? .bodyweight)
        _isCompound = State(initialValue: template?.isSystemCompound ?? false)
        _mediaFilename = State(initialValue: template?.customMediaFilename)
        _youtubeURL = State(initialValue: template?.customYouTubeURL)
    }

    private var isReadOnly: Bool {
        guard let existing else { return false }
        return !existing.isCustom
    }

    private var isCreate: Bool { existing == nil }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var titleText: String {
        if isCreate {
            return String(localized: "customExercise.title", bundle: .module)
        }
        return existing?.displayName ?? trimmedName
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DeltiqHeader(
                    eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                    title: titleText,
                    onBack: {
                        if !isReadOnly && isDirty {
                            showingDiscardConfirm = true
                        } else {
                            dismiss()
                        }
                    },
                    actions: isReadOnly ? [] : [
                        DeltiqHeaderAction(
                            systemImage: "checkmark",
                            isDisabled: trimmedName.isEmpty || isSaving,
                            accessibilityLabel: String(localized: isCreate ? "customExercise.add" : "common.done", bundle: .module)
                        ) {
                            save()
                        }
                    ]
                )
                Form {
                    if isReadOnly {
                        readOnlyContent
                    } else {
                        editableContent
                    }
                    if let saveErrorMessage {
                        Section {
                            Text(saveErrorMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.Deltiq.error)
                                .listRowBackground(Color.Deltiq.surface)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Color.Deltiq.background.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationBarBackButtonHidden(true)
            .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
                dismiss()
            }
            .interactiveDismissDisabled(isReadOnly ? false : isDirty)
            // System-exercise GIF fullscreen
            .sheet(isPresented: $showGifSheet) {
                ExerciseGifSheet(
                    exerciseName: existing?.name ?? trimmedName,
                    displayName: titleText
                )
            }
            // Custom media fullscreen
            .sheet(isPresented: $showMediaFullscreen) {
                if let filename = mediaFilename {
                    CustomMediaFullscreenSheet(filename: filename, title: trimmedName.isEmpty ? titleText : trimmedName)
                }
            }
            // Einzelner fileImporter — iOS erlaubt nur einen pro View-Baum.
            // showGifImporter bestimmt die erlaubten Typen; Video ist der Default.
            .fileImporter(
                isPresented: Binding(
                    get: { showVideoImporter || showGifImporter },
                    set: { if !$0 { showVideoImporter = false; showGifImporter = false } }
                ),
                allowedContentTypes: showGifImporter
                    ? CustomExerciseMediaStore.gifTypes
                    : CustomExerciseMediaStore.videoTypes
            ) { result in
                handleImport(result: result)
            }
            // YouTube URL entry
            .alert(
                String(localized: "customExercise.media.youTubePromptTitle", bundle: .module),
                isPresented: $showYouTubeAlert
            ) {
                TextField("https://youtube.com/shorts/…", text: $youtubeInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button(String(localized: "common.done", bundle: .module)) {
                    commitYouTubeURL()
                }
                Button(String(localized: "common.cancel", bundle: .module), role: .cancel) {}
            }
            .onDisappear {
                // Clean up newly staged media file if the user discarded
                guard !isSaved else { return }
                let savedFile = existing?.customMediaFilename
                if let newFile = mediaFilename, newFile != savedFile {
                    CustomExerciseMediaStore.delete(filename: newFile)
                }
            }
        }
    }

    // MARK: - isDirty

    private var isDirty: Bool {
        guard let existing, !isCreate else {
            return !name.isEmpty || muscle != .chest || equipment != .bodyweight || isCompound != false
                || mediaFilename != nil || youtubeURL != nil
        }
        return name != existing.name
            || muscle != existing.primaryMuscle
            || equipment != existing.equipment
            || isCompound != existing.isSystemCompound
            || mediaFilename != existing.customMediaFilename
            || youtubeURL != existing.customYouTubeURL
    }

    // MARK: - Editable (create + custom edit)

    @ViewBuilder
    private var editableContent: some View {
        Section {
            TextField(
                String(localized: "picker.exercise.namePlaceholder", bundle: .module),
                text: $name
            )
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            Text("customExercise.section.name", bundle: .module)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)

        Section {
            Picker(selection: $muscle) {
                ForEach(MuscleGroup.allCases, id: \.self) { m in
                    Text(m.localizedName).tag(m)
                }
            } label: {
                Text("customExercise.field.muscle", bundle: .module)
            }
            .listRowBackground(Color.Deltiq.surface)
            Picker(selection: $equipment) {
                ForEach(Equipment.allCases, id: \.self) { e in
                    Text(e.localizedName).tag(e)
                }
            } label: {
                Text("customExercise.field.equipment", bundle: .module)
            }
            .listRowBackground(Color.Deltiq.surface)
            Toggle(isOn: $isCompound) {
                Text("customExercise.field.compound", bundle: .module)
            }
            .tint(Color.deltiqOrange)
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            Text("customExercise.section.metadata", bundle: .module)
        } footer: {
            Text("customExercise.section.metadataFooter", bundle: .module)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)

        mediaSection
    }

    // MARK: - Media section (custom exercises only)

    @ViewBuilder
    private var mediaSection: some View {
        Section {
            if let error = mediaError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.error)
                    .listRowBackground(Color.Deltiq.surface)
            }
            if let filename = mediaFilename, CustomExerciseMediaStore.fileExists(filename: filename) {
                mediaFileRow(filename: filename)
            } else if let yt = youtubeURL {
                youTubeRow(url: yt)
            } else {
                // Group forces SwiftUI to expand the multi-view @ViewBuilder in an else branch
                Group { mediaAddRows }
            }
        } header: {
            Text("customExercise.section.media", bundle: .module)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    @ViewBuilder
    private var mediaAddRows: some View {
        Button {
            mediaError = nil
            showVideoImporter = true
        } label: {
            Label {
                Text("customExercise.media.addVideo", bundle: .module)
            } icon: {
                Image(systemName: "video.badge.plus")
            }
        }
        .foregroundStyle(Color.deltiqOrange)
        .listRowBackground(Color.Deltiq.surface)

        Button {
            mediaError = nil
            showGifImporter = true
        } label: {
            Label {
                Text("customExercise.media.addGif", bundle: .module)
            } icon: {
                Image(systemName: "photo.badge.plus")
            }
        }
        .foregroundStyle(Color.deltiqOrange)
        .listRowBackground(Color.Deltiq.surface)

        Button {
            mediaError = nil
            youtubeInput = youtubeURL ?? ""
            showYouTubeAlert = true
        } label: {
            Label {
                Text("customExercise.media.addYouTube", bundle: .module)
            } icon: {
                Image(systemName: "play.rectangle.badge.plus")
            }
        }
        .foregroundStyle(Color.deltiqOrange)
        .listRowBackground(Color.Deltiq.surface)
    }

    @ViewBuilder
    private func mediaFileRow(filename: String) -> some View {
        HStack(spacing: 12) {
            mediaThumb(filename: filename)
                .onTapGesture { showMediaFullscreen = true }
            VStack(alignment: .leading, spacing: 4) {
                Text(filename.lowercased().hasSuffix(".gif") ? "GIF" : "Video")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
                Button(role: .destructive) {
                    if let f = mediaFilename { CustomExerciseMediaStore.delete(filename: f) }
                    mediaFilename = nil
                    mediaError = nil
                } label: {
                    Text("customExercise.media.remove", bundle: .module)
                        .font(.caption)
                }
            }
            Spacer()
            Menu {
                Button { showVideoImporter = true } label: {
                    Label {
                        Text("customExercise.media.addVideo", bundle: .module)
                    } icon: { Image(systemName: "video.badge.plus") }
                }
                Button { showGifImporter = true } label: {
                    Label {
                        Text("customExercise.media.addGif", bundle: .module)
                    } icon: { Image(systemName: "photo.badge.plus") }
                }
                Button {
                    youtubeInput = ""
                    showYouTubeAlert = true
                } label: {
                    Label {
                        Text("customExercise.media.addYouTube", bundle: .module)
                    } icon: { Image(systemName: "play.rectangle.badge.plus") }
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
        }
        .listRowBackground(Color.Deltiq.surface)
    }

    @ViewBuilder
    private func mediaThumb(filename: String) -> some View {
        CustomMediaThumbnailView(
            url: CustomExerciseMediaStore.url(forFilename: filename),
            isGif: filename.lowercased().hasSuffix(".gif"),
            cornerRadius: Deltiq.Radius.input
        )
        .frame(width: 60, height: 60)
    }

    @ViewBuilder
    private func youTubeRow(url: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "play.rectangle.fill")
                .font(.title2)
                .foregroundStyle(Color.deltiqOrange)
                .frame(width: 60, height: 60)
                .background(Color.Deltiq.fill)
                .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("YouTube")
                    .font(.subheadline.weight(.medium))
                Text(url)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 8) {
                    Button {
                        if let u = URL(string: url) { openURL(u) }
                    } label: {
                        Text("customExercise.media.openYouTube", bundle: .module)
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.deltiqOrange)
                    Button(role: .destructive) {
                        youtubeURL = nil
                        mediaError = nil
                    } label: {
                        Text("customExercise.media.remove", bundle: .module)
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            Spacer()
        }
        .listRowBackground(Color.Deltiq.surface)
    }

    // MARK: - Read-only (system templates)

    @ViewBuilder
    private var readOnlyContent: some View {
        Section {
            HStack {
                Spacer()
                Button { showGifSheet = true } label: {
                    ExerciseGifView(exerciseName: existing?.name ?? trimmedName, displayName: titleText)
                        .frame(width: 140, height: 140)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        Section {
            LabeledContent {
                Text(muscle.localizedName)
            } label: {
                Text("customExercise.field.muscle", bundle: .module)
            }
            .listRowBackground(Color.Deltiq.surface)
            if let secondaryMuscles = ExerciseSecondaryMuscles.byNormalizedName[ExerciseMediaProvider.normalizedKey(for: existing?.name ?? trimmedName)], !secondaryMuscles.isEmpty {
                LabeledContent {
                    Text(secondaryMuscles.map { String(localized: $0.localizedName) }.joined(separator: ", "))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } label: {
                    Text("customExercise.field.secondaryMuscles", bundle: .module)
                }
                .listRowBackground(Color.Deltiq.surface)
            }
            LabeledContent {
                Text(equipment.localizedName)
            } label: {
                Text("customExercise.field.equipment", bundle: .module)
            }
            .listRowBackground(Color.Deltiq.surface)
            LabeledContent {
                Text(isCompound ? "common.yes" : "common.no", bundle: .module)
            } label: {
                Text("customExercise.field.compound", bundle: .module)
            }
            .listRowBackground(Color.Deltiq.surface)
        } header: {
            Text("customExercise.section.metadata", bundle: .module)
        } footer: {
            Text("library.readOnlyFooter", bundle: .module)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
        if let steps = ExerciseInstructionsProvider.steps(
            for: ExerciseMediaProvider.normalizedKey(for: existing?.name ?? trimmedName)
        ) {
            let preferred = steps.preferred()
            if !preferred.isEmpty {
                Section {
                    ForEach(Array(preferred.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.deltiqOrange)
                                .frame(minWidth: 20, alignment: .leading)
                            Text(step)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                                .listRowBackground(Color.Deltiq.surface)
                        }
                        .listRowBackground(Color.Deltiq.surface)
                    }
                } header: {
                    Text("exercise.detail.instructions.title", bundle: .module)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)
            }
        }
    }

    // MARK: - Save

    private func save() {
        guard !isSaving, !trimmedName.isEmpty else { return }
        isSaving = true

        var insertedTemplate: ExerciseTemplate?
        let originalName: String?
        let originalMuscle: MuscleGroup?
        let originalEquipment: Equipment?
        let originalIsCompound: Bool?
        let originalMediaFilename: String?
        let originalYouTubeURL: String?

        if let existing {
            originalName = existing.name
            originalMuscle = existing.primaryMuscle
            originalEquipment = existing.equipment
            originalIsCompound = existing.isSystemCompound
            originalMediaFilename = existing.customMediaFilename
            originalYouTubeURL = existing.customYouTubeURL
            // Delete old media file if replaced or removed
            if let old = existing.customMediaFilename, old != mediaFilename {
                CustomExerciseMediaStore.delete(filename: old)
            }
            existing.name = trimmedName
            existing.primaryMuscle = muscle
            existing.equipment = equipment
            existing.isSystemCompound = isCompound
            existing.customMediaFilename = mediaFilename
            existing.customYouTubeURL = youtubeURL
        } else {
            originalName = nil; originalMuscle = nil; originalEquipment = nil
            originalIsCompound = nil; originalMediaFilename = nil; originalYouTubeURL = nil
            let template = ExerciseTemplate(
                name: trimmedName,
                equipment: equipment,
                primaryMuscle: muscle,
                isCustom: true,
                isSystemCompound: isCompound,
                isSystemProvided: false
            )
            template.customMediaFilename = mediaFilename
            template.customYouTubeURL = youtubeURL
            modelContext.insert(template)
            insertedTemplate = template
        }

        do {
            try modelContext.save()
        } catch {
            if let insertedTemplate { modelContext.delete(insertedTemplate) }
            if let existing, let originalName, let originalMuscle, let originalEquipment, let originalIsCompound {
                existing.name = originalName
                existing.primaryMuscle = originalMuscle
                existing.equipment = originalEquipment
                existing.isSystemCompound = originalIsCompound
                existing.customMediaFilename = originalMediaFilename
                existing.customYouTubeURL = originalYouTubeURL
            }
            saveErrorMessage = String(localized: "day.editor.save.failed", bundle: .module)
            isSaving = false
            return
        }
        isSaved = true
        dismiss()
    }

    // MARK: - Helpers

    private func handleImport(result: Result<URL, Error>) {
        switch result {
        case .failure:
            mediaError = String(localized: "customExercise.media.importError", bundle: .module)
        case .success(let url):
            do {
                let newFilename = try CustomExerciseMediaStore.import(from: url)
                // Delete previous staged file if replaced before saving
                if let old = mediaFilename, old != existing?.customMediaFilename {
                    CustomExerciseMediaStore.delete(filename: old)
                }
                mediaFilename = newFilename
                youtubeURL = nil
                mediaError = nil
            } catch let err as CustomMediaError {
                mediaError = err.errorDescription
            } catch {
                mediaError = String(localized: "customExercise.media.importError", bundle: .module)
            }
        }
    }

    private func commitYouTubeURL() {
        let trimmed = youtubeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidYouTube(trimmed) else {
            mediaError = String(localized: "customExercise.media.youTubeInvalid", bundle: .module)
            return
        }
        // Delete local media file if switching to YouTube
        if let old = mediaFilename, old != existing?.customMediaFilename {
            CustomExerciseMediaStore.delete(filename: old)
        }
        youtubeURL = trimmed
        mediaFilename = nil
        mediaError = nil
    }

    private func isValidYouTube(_ s: String) -> Bool {
        guard let url = URL(string: s),
              let host = url.host?.lowercased(),
              ["youtube.com", "www.youtube.com", "m.youtube.com"].contains(host) else { return false }
        return url.path.hasPrefix("/shorts/")
    }
}

// MARK: - Custom media fullscreen sheet

@available(iOS 17.0, macOS 14.0, *)
private struct CustomMediaFullscreenSheet: View {
    let filename: String
    let title: String
    @Environment(\.dismiss) private var dismiss

    private var mediaURL: URL { CustomExerciseMediaStore.url(forFilename: filename) }
    private var isGif: Bool { filename.lowercased().hasSuffix(".gif") }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 0)
                mediaContent
                    .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous))
                Spacer(minLength: 0)
            }
            .padding(24)
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(Text(title))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("common.close", bundle: .module)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mediaContent: some View {
        if isGif {
            #if canImport(UIKit)
            GifImageView(url: mediaURL, contentMode: .scaleAspectFit)
                .frame(width: 280, height: 280)
                .background(Color.white)
            #else
            Image(systemName: "photo.fill")
                .frame(width: 280, height: 280)
            #endif
        } else {
            #if canImport(AVKit)
            VideoPlayer(player: AVPlayer(url: mediaURL))
                .frame(height: 300)
            #else
            Image(systemName: "video.fill")
                .frame(height: 300)
            #endif
        }
    }
}
#endif
