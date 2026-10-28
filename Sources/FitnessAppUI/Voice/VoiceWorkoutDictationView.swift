#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Flow B: Dictate a complete workout after training.
/// Creates an ad-hoc WorkoutSession; nothing is saved until "Speichern".
@available(iOS 17.0, macOS 14.0, *)
struct VoiceWorkoutDictationView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let parser = VoiceWorkoutParser()
    #if canImport(Speech) && canImport(AVFoundation)
    @State private var recognizer = LiveSpeechRecognizer()
    #endif

    // MARK: - State

    private enum Phase { case input, recording, finalizing, parsed([VoiceDraftSet]), saving, error(String) }
    @State private var phase: Phase = .input
    @State private var inputText = ""
    @State private var liveTranscript = ""
    @State private var drafts: [VoiceDraftSet] = []
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .input:
                        inputView
                    case .recording:
                        recordingView
                    case .finalizing:
                        ProgressView().padding()
                    case .parsed:
                        draftListView
                    case .saving:
                        ProgressView().padding()
                    case .error(let msg):
                        errorView(msg)
                    }
                    if let err = saveError {
                        Text(err).foregroundStyle(Color.Deltiq.error).font(.caption)
                    }
                }
                .padding()
            }
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(Text("voice.workout.title", bundle: .module))
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
                if case .parsed = phase {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            saveWorkout()
                        } label: {
                            Text(isSaving
                                 ? String(localized: "common.saving", bundle: .module)
                                 : String(localized: "voice.workout.save", bundle: .module))
                        }
                        .disabled(isSaving || drafts.isEmpty)
                    }
                }
            }
        }
        .onDisappear { stopRecordingIfNeeded() }
    }

    // MARK: - Sub-Views

    private var inputView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("voice.workout.hint", bundle: .module)
                .foregroundStyle(Color.Deltiq.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button {
                startRecording()
            } label: {
                Label(String(localized: "voice.single.start", bundle: .module), systemImage: "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .deltiqButtonStyle()

            Divider()

            Text("voice.workout.orText", bundle: .module)
                .font(.caption)
                .foregroundStyle(Color.Deltiq.textSecondary)

            TextEditor(text: $inputText)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color.Deltiq.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                parseDrafts(from: inputText)
            } label: {
                Text("voice.workout.parse", bundle: .module).frame(maxWidth: .infinity)
            }
            .deltiqButtonStyle()
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var recordingView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 12, height: 12)
                Text("voice.single.recording", bundle: .module).foregroundStyle(Color.red)
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

    private var draftListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("voice.workout.preview.title", bundle: .module)
                    .font(.headline)
                Spacer()
                Button {
                    drafts = []
                    phase = .input
                } label: {
                    Label(String(localized: "voice.workout.reparse", bundle: .module), systemImage: "arrow.counterclockwise")
                        .font(.caption)
                }
                .foregroundStyle(Color.deltiqOrange)
            }

            ForEach($drafts) { $draft in
                DraftSetRow(draft: $draft, onDelete: {
                    drafts.removeAll { $0.id == draft.id }
                })
            }

            if drafts.isEmpty {
                Text("voice.workout.empty", bundle: .module)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(Color.Deltiq.error)
            Text(message).multilineTextAlignment(.center)
            Button { phase = .input } label: {
                Text("voice.tryAgain", bundle: .module).frame(maxWidth: .infinity)
            }
            .deltiqButtonStyle()
        }
    }

    // MARK: - Recording

    private func startRecording() {
        #if canImport(Speech) && canImport(AVFoundation)
        let rec = recognizer
        rec.onTranscriptionUpdate = { text in DispatchQueue.main.async { liveTranscript = text } }
        rec.onFinished = { text in
            DispatchQueue.main.async {
                liveTranscript = ""
                let t = text ?? ""
                inputText = t
                if !t.isEmpty { parseDrafts(from: t) } else { phase = .input }
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
                guard granted else { phase = .error(String(localized: "voice.error.permissionDenied", bundle: .module)); return }
                do {
                    try rec.startRecording()
                    phase = .recording
                } catch {
                    phase = .error(error.localizedDescription)
                }
            }
        }
        #else
        phase = .input
        #endif
    }

    private func stopRecordingManually() {
        #if canImport(Speech) && canImport(AVFoundation)
        phase = .finalizing
        recognizer.stopRecording()
        #endif
    }

    private func stopRecordingIfNeeded() {
        #if canImport(Speech) && canImport(AVFoundation)
        recognizer.cancelRecording()
        #endif
    }

    private func parseDrafts(from text: String) {
        drafts = parser.parseWorkout(text)
        phase = .parsed(drafts)
    }

    // MARK: - Save

    private func saveWorkout() {
        guard !drafts.isEmpty, !isSaving else { return }
        isSaving = true
        saveError = nil

        let now = Date()
        let session = WorkoutSession(
            startTime: now,
            endTime: now,
            isAdHoc: true
        )
        modelContext.insert(session)

        // Group by exercise name for setIndex counting
        var insertedLogs: [ExerciseLog] = []
        var setsByExercise: [String: Int] = [:]

        do {
            for draft in drafts {
                let name = draft.exerciseName ?? ""
                let spec = ExerciseLibraryData.byName[name]
                let idx = setsByExercise[name, default: 0]
                setsByExercise[name] = idx + 1

                let weight = draft.weightKg ?? 0.0
                let reps = draft.isTimeBased
                    ? (draft.durationSeconds ?? 0)
                    : (draft.reps ?? 0)

                let log = ExerciseLog(
                    date: now,
                    setIndex: idx,
                    weight: weight,
                    reps: reps,
                    rir: 0,
                    exercise: nil,
                    session: session,
                    durationSeconds: draft.isTimeBased ? draft.durationSeconds : nil
                )
                log.exerciseNameSnapshot = name.isEmpty ? nil : name
                log.exerciseIsTimeBasedSnapshot = spec?.isTimeBased ?? draft.isTimeBased
                log.exerciseIsCardioSnapshot = spec?.isCardio ?? false
                modelContext.insert(log)
                insertedLogs.append(log)
            }

            let exerciseCount = Set(drafts.compactMap { $0.exerciseName }).count
            session.recomputeTotals(exerciseCount: exerciseCount)
            session.finalizeTiming(endingAt: now)
            session.isCompleted = true

            try modelContext.save()
            dismiss()
        } catch {
            // Rollback: delete all inserted objects
            for log in insertedLogs { modelContext.delete(log) }
            modelContext.delete(session)
            try? modelContext.save()
            saveError = error.localizedDescription
            isSaving = false
        }
    }
}

// MARK: - DraftSetRow

@available(iOS 17.0, macOS 14.0, *)
private struct DraftSetRow: View {
    @Binding var draft: VoiceDraftSet
    let onDelete: () -> Void

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var durationText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                exerciseField
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(Color.Deltiq.error)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 12) {
                if draft.isTimeBased {
                    numericField(label: String(localized: "voice.single.duration", bundle: .module),
                                 text: $durationText,
                                 isMissing: draft.durationSeconds == nil)
                    .onChange(of: durationText) { _, v in draft.durationSeconds = Int(v) }
                } else {
                    numericField(label: String(localized: "voice.single.weight", bundle: .module),
                                 text: $weightText,
                                 isMissing: draft.weightKg == nil)
                    .onChange(of: weightText) { _, v in draft.weightKg = Double(v.replacingOccurrences(of: ",", with: ".")) }

                    numericField(label: String(localized: "voice.single.reps", bundle: .module),
                                 text: $repsText,
                                 isMissing: draft.reps == nil)
                    .onChange(of: repsText) { _, v in draft.reps = Int(v) }
                }
            }
        }
        .padding(12)
        .background(Color.Deltiq.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(draft.hasMissingFields ? Color.Deltiq.error.opacity(0.4) : Color.Deltiq.divider, lineWidth: 1)
        )
        .onAppear {
            if let w = draft.weightKg { weightText = String(format: "%.2g", w) }
            if let r = draft.reps { repsText = "\(r)" }
            if let d = draft.durationSeconds { durationText = "\(d)" }
        }
    }

    private var exerciseField: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("voice.single.exercise", bundle: .module).font(.caption).foregroundStyle(Color.Deltiq.textSecondary)
                if draft.isExerciseAmbiguous {
                    Image(systemName: "questionmark.circle").font(.caption2).foregroundStyle(Color.Deltiq.error)
                }
            }
            TextField(String(localized: "voice.single.exercise.placeholder", bundle: .module),
                      text: Binding(
                        get: { draft.exerciseName ?? "" },
                        set: { draft.exerciseName = $0.isEmpty ? nil : $0 }
                      ))
            .font(.body.weight(.medium))
        }
    }

    private func numericField(label: String, text: Binding<String>, isMissing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(label).font(.caption).foregroundStyle(Color.Deltiq.textSecondary)
                if isMissing {
                    Image(systemName: "exclamationmark.circle").font(.caption2).foregroundStyle(Color.Deltiq.error)
                }
            }
            TextField("–", text: text)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .frame(maxWidth: 80)
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    VoiceWorkoutDictationView()
        .modelContainer(PreviewSeed.workoutContainer)
}
#endif

#endif // canImport(SwiftUI) && canImport(SwiftData)
