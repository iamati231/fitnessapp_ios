#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Flow A: Dictate a single set during an active workout.
/// Opened via the mic button in ActiveWorkoutView. Pre-fills the exercise from
/// the current workout page; user can override. Nothing is saved until "Satz speichern".
@available(iOS 17.0, macOS 14.0, *)
struct VoiceSingleSetSheet: View {

    let session: WorkoutSession
    /// Current exercise shown on screen — pre-fills the exercise field.
    let prefilledExercise: Exercise?
    let onSaved: (_ setIndex: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let parser = VoiceWorkoutParser()
    #if canImport(Speech) && canImport(AVFoundation)
    @State private var recognizer: LiveSpeechRecognizer = LiveSpeechRecognizer()
    #endif
    private let mock = MockSpeechRecognizer()

    // MARK: - State

    private enum Phase { case idle, permissionDenied, recording, finalizing, reviewing(String), draft(VoiceDraftSet), saving, error(String) }
    @State private var phase: Phase = .idle
    @State private var liveTranscript = ""
    @State private var isSaving = false

    // Editable draft fields
    @State private var exerciseName = ""
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var durationText = ""
    @State private var isTimeBased = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .idle:
                        idleView
                    case .permissionDenied:
                        permissionDeniedView
                    case .recording:
                        recordingView
                    case .finalizing:
                        finalizingView
                    case .reviewing(let text):
                        reviewingView(text: text)
                    case .draft:
                        draftFormView
                    case .saving:
                        ProgressView()
                            .padding()
                    case .error(let msg):
                        errorView(msg)
                    }
                }
                .padding()
            }
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(Text("voice.single.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        stopRecordingIfNeeded()
                        dismiss()
                    } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
            }
        }
        .onDisappear { stopRecordingIfNeeded() }
    }

    // MARK: - Sub-Views

    private var idleView: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(Color.deltiqOrange)
            Text("voice.single.hint", bundle: .module)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.Deltiq.textSecondary)
            Button {
                startRecording()
            } label: {
                Label(String(localized: "voice.single.start", bundle: .module), systemImage: "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .deltiqButtonStyle()
            Divider()
            // Manual text entry as fallback
            manualEntrySection
        }
    }

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("voice.single.orManual", bundle: .module)
                .font(.caption)
                .foregroundStyle(Color.Deltiq.textSecondary)
            prefillDraftFromExercise()
            draftFormView
        }
    }

    private var recordingView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 12, height: 12)
                Text("voice.single.recording", bundle: .module)
                    .foregroundStyle(Color.red)
            }
            if !liveTranscript.isEmpty {
                Text(liveTranscript)
                    .font(.body.italic())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .padding(.horizontal)
            }
            Button {
                stopRecordingManually()
            } label: {
                Label(String(localized: "voice.single.stop", bundle: .module), systemImage: "stop.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .deltiqButtonStyle()
        }
    }

    private var finalizingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(String(localized: "common.saving", bundle: .module))
                .foregroundStyle(Color.Deltiq.textSecondary)
        }
        .padding()
    }

    private func reviewingView(text: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("voice.single.transcription", bundle: .module)
                .font(.caption)
                .foregroundStyle(Color.Deltiq.textSecondary)
            Text(text)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.Deltiq.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Button {
                let draft = parser.parseSet(text)
                applyDraft(draft)
                phase = .draft(draft)
            } label: {
                Text("voice.single.parse", bundle: .module).frame(maxWidth: .infinity)
            }
            .deltiqButtonStyle()
            Button {
                phase = .idle
            } label: {
                Text("voice.single.retry", bundle: .module).frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.deltiqOrange)
        }
    }

    private var draftFormView: some View {
        VStack(alignment: .leading, spacing: 16) {
            fieldRow(label: String(localized: "voice.single.exercise", bundle: .module),
                     text: $exerciseName,
                     placeholder: String(localized: "voice.single.exercise.placeholder", bundle: .module),
                     isMissing: exerciseName.isEmpty)

            if isTimeBased {
                fieldRow(label: String(localized: "voice.single.duration", bundle: .module),
                         text: $durationText,
                         placeholder: String(localized: "voice.single.duration.placeholder", bundle: .module),
                         isMissing: durationText.isEmpty)
            } else {
                fieldRow(label: String(localized: "voice.single.weight", bundle: .module),
                         text: $weightText,
                         placeholder: String(localized: "voice.single.weight.placeholder", bundle: .module),
                         isMissing: weightText.isEmpty)
                fieldRow(label: String(localized: "voice.single.reps", bundle: .module),
                         text: $repsText,
                         placeholder: String(localized: "voice.single.reps.placeholder", bundle: .module),
                         isMissing: repsText.isEmpty)
            }

            Toggle(String(localized: "voice.single.timeBased", bundle: .module), isOn: $isTimeBased)
                .tint(Color.deltiqOrange)

            Button {
                saveSet()
            } label: {
                Text(isSaving
                     ? String(localized: "common.saving", bundle: .module)
                     : String(localized: "voice.single.save", bundle: .module))
                    .frame(maxWidth: .infinity)
            }
            .deltiqButtonStyle()
            .disabled(isSaving || !canSave)
        }
    }

    @ViewBuilder
    private func fieldRow(label: String, text: Binding<String>, placeholder: String, isMissing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(Color.Deltiq.textSecondary)
                if isMissing {
                    Text("voice.missing", bundle: .module)
                        .font(.caption2)
                        .foregroundStyle(Color.Deltiq.error)
                }
            }
            TextField(placeholder, text: text)
                .padding(10)
                .background(Color.Deltiq.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isMissing ? Color.Deltiq.error.opacity(0.5) : Color.Deltiq.divider, lineWidth: 1)
                )
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash.fill").font(.largeTitle).foregroundStyle(Color.Deltiq.error)
            Text("voice.error.permissionDenied", bundle: .module).multilineTextAlignment(.center)
            #if os(iOS)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("voice.openSettings", bundle: .module).frame(maxWidth: .infinity)
            }
            .deltiqButtonStyle()
            #endif
            // Still allow manual entry
            draftFormView
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(Color.Deltiq.error)
            Text(message).multilineTextAlignment(.center)
            Button {
                phase = .idle
            } label: {
                Text("voice.tryAgain", bundle: .module).frame(maxWidth: .infinity)
            }
            .deltiqButtonStyle()
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !exerciseName.isEmpty && (isTimeBased ? !durationText.isEmpty : (!weightText.isEmpty && !repsText.isEmpty))
    }

    @discardableResult
    private func prefillDraftFromExercise() -> some View {
        let name = prefilledExercise?.name ?? ""
        if exerciseName.isEmpty, !name.isEmpty { exerciseName = name }
        return EmptyView()
    }

    private func applyDraft(_ draft: VoiceDraftSet) {
        exerciseName = draft.exerciseName ?? prefilledExercise?.name ?? ""
        isTimeBased = draft.isTimeBased
        if let w = draft.weightKg { weightText = String(format: "%.2g", w) }
        if let r = draft.reps { repsText = "\(r)" }
        if let d = draft.durationSeconds { durationText = "\(d)" }
    }

    private func startRecording() {
        #if canImport(Speech) && canImport(AVFoundation)
        let rec = recognizer
        rec.onTranscriptionUpdate = { text in
            DispatchQueue.main.async { liveTranscript = text }
        }
        rec.onFinished = { text in
            DispatchQueue.main.async {
                liveTranscript = ""
                if let t = text, !t.isEmpty {
                    phase = .reviewing(t)
                } else {
                    // No speech recognised — return to idle so user can try again.
                    phase = .idle
                }
            }
        }
        rec.onError = { error in
            DispatchQueue.main.async {
                liveTranscript = ""
                phase = .error(error.localizedDescription)
            }
        }
        rec.requestPermission { granted in
            DispatchQueue.main.async {
                guard granted else { phase = .permissionDenied; return }
                do {
                    try rec.startRecording()
                    phase = .recording
                } catch {
                    phase = .error(error.localizedDescription)
                }
            }
        }
        #else
        // Fallback: jump straight to manual entry
        prefillDraftFromExercise()
        phase = .draft(VoiceDraftSet())
        #endif
    }

    private func stopRecordingManually() {
        #if canImport(Speech) && canImport(AVFoundation)
        phase = .finalizing
        recognizer.stopRecording()
        #endif
    }

    private func stopRecordingIfNeeded() {
        // Cancel (not stop) on dismiss — no callback needed after view is gone.
        #if canImport(Speech) && canImport(AVFoundation)
        recognizer.cancelRecording()
        #endif
    }

    private func saveSet() {
        guard canSave, !isSaving else { return }
        isSaving = true

        let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let reps = Int(repsText) ?? 0
        let duration = Int(durationText)

        // Find next set index for this exercise in session
        let matchingLogs = session.logs.filter { log in
            if let ex = prefilledExercise {
                return log.exercise?.persistentModelID == ex.persistentModelID
            }
            return log.exerciseNameSnapshot?.lowercased() == exerciseName.lowercased()
        }
        let nextIndex = (matchingLogs.map { $0.setIndex }.max() ?? -1) + 1

        let log = ExerciseLog(
            setIndex: nextIndex,
            weight: weight,
            reps: isTimeBased ? (duration ?? 0) : reps,
            rir: 0,
            exercise: prefilledExercise,
            session: session,
            durationSeconds: isTimeBased ? duration : nil
        )
        if prefilledExercise == nil {
            log.exerciseNameSnapshot = exerciseName
        }

        modelContext.insert(log)

        do {
            try modelContext.save()
            onSaved(nextIndex)
            dismiss()
        } catch {
            isSaving = false
            phase = .error(error.localizedDescription)
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
private struct VoiceSingleSetSheetPreviewWrapper: View {
    @Query(sort: \WorkoutSession.startTime, order: .reverse)
    private var sessions: [WorkoutSession]
    var body: some View {
        if let s = sessions.first {
            VoiceSingleSetSheet(session: s, prefilledExercise: nil, onSaved: { _ in })
        } else {
            Text("No session in preview container")
        }
    }
}
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    VoiceSingleSetSheetPreviewWrapper()
        .modelContainer(PreviewSeed.activeSessionContainer)
}
#endif

#endif // canImport(SwiftUI) && canImport(SwiftData)
