// DEL-174: Daten-Import UI (Phase 2 — Import-Flow).
//
// User-Flow:
//   1. SettingsView → Tap "Daten importieren (CSV)"
//   2. DataImportView öffnet sich → erklärt Append-only-Strategie
//   3. "ZIP auswählen" → fileImporter (UTType.zip)
//   4. Confirm-Dialog: "Bestehende Daten bleiben unangetastet — nur fehlende
//      Zeilen werden ergänzt. Fortfahren?"
//   5. Import läuft → ProgressView
//   6. Result: Zähler für Imported / Skipped / Errors pro Datei
//   7. Wenn errors > 0: "Fehlerprotokoll teilen"-Button (errors.csv)
//
// **Wichtig**: Der Import läuft auf dem ModelContext des Main-Actors —
// SwiftData ist nicht Sendable. Heavy parsing+insert kann mehrere Sekunden
// dauern; in der Zwischenzeit zeigen wir eine ProgressView.

#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppActivities
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

@available(iOS 17.0, macOS 14.0, *)
public struct DataImportView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .ready
    @State private var pickedURL: URL?
    @State private var showFilePicker = false
    @State private var showConfirmDialog = false
    @State private var showReplaceConfirmDialog = false
    @State private var errorMessage: String?
    @State private var errorsCSVURL: URL?
    @State private var showShareSheet = false

    // DEL-175: Append-only ist Default. Replace ist destruktiv — wir
    // verlangen einen zusätzlichen "ja wirklich"-Confirm-Dialog bevor wir
    // löschen.
    @State private var strategy: DataImportStrategy = .appendOnly

    // DEL-176: Live-Progress-Tick aus dem ImportService. Wird vor jeder
    // Phase aktualisiert; UI bindet daran eine ProgressView + den
    // lokalisierten Phasennamen.
    @State private var importProgress: ImportProgress?

    /// DEL-226: Ergebnis des Trockenlaufs zur ausgewaehlten Datei. `nil`
    /// solange nichts gewaehlt ist; `previewFailed` wenn die Datei kein
    /// gueltiges Backup ist — dann muss der Import-Button gesperrt bleiben,
    /// statt den User in einen Fehlschlag laufen zu lassen.
    @State private var preview: DataImportPreview?
    @State private var previewFailed = false
    /// Datensaetze, die aktuell in der App liegen — Vergleichsgroesse fuer die
    /// Vorschau. Bewusst nur die drei Zahlen, die der User wiedererkennt.
    @State private var currentRecordCount: Int = 0

    enum Phase {
        case ready
        case picked(filename: String)
        case importing
        case finished(result: DataImportResult)
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: direkt von SettingsView gepusht (kein
            // eigener Zwischen-Hub) - Eyebrow zeigt den Tab, selbes Muster wie
            // DashboardSettingsView/ExerciseLibraryView.
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "settings.dataImport.title", bundle: .module),
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 18) {
                introCard
                strategyCard
                if case .picked = phase {
                    // DEL-226: Vorschau VOR dem Strategie-Picker — erst
                    // wissen, was in der Datei steckt, dann entscheiden, wie
                    // aggressiv importiert wird.
                    previewCard
                    strategyPickerCard
                }
                actionSection
                if let errorMessage {
                    errorBanner(message: errorMessage)
                }
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Bug-Fix: .navigationBarBackButtonHidden(true) nimmt auf iOS die
        // Swipe-Back-Geste als Nebenwirkung mit runter - siehe
        // deltiqSwipeBackEnabled()-Dokumentation in Theme.swift.
        .deltiqSwipeBackEnabled()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.zip],
            allowsMultipleSelection: false
        ) { result in
            handlePickerResult(result)
        }
        // Default-Confirm — milder Ton, .appendOnly
        .confirmationDialog(
            Text("settings.dataImport.confirm.title", bundle: .module),
            isPresented: $showConfirmDialog,
            titleVisibility: .visible
        ) {
            Button {
                runImport()
            } label: {
                Text("settings.dataImport.confirm.action", bundle: .module)
            }
            Button(role: .cancel) {
                // phase bleibt .picked, User kann's nochmal versuchen
            } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            Text("settings.dataImport.confirm.message", bundle: .module)
        }
        // DEL-175: destruktiver Confirm für .replace — eigener Dialog mit
        // Warning-Ton, .destructive role auf dem Confirm-Button damit iOS
        // ihn rot rendert.
        .confirmationDialog(
            Text("settings.dataImport.replaceConfirm.title", bundle: .module),
            isPresented: $showReplaceConfirmDialog,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                runImport()
            } label: {
                Text("settings.dataImport.replaceConfirm.action", bundle: .module)
            }
            Button(role: .cancel) {} label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            Text("settings.dataImport.replaceConfirm.message", bundle: .module)
        }
        #if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            if let url = errorsCSVURL {
                ImportShareSheet(activityItems: [url])
            }
        }
        #endif
    }

    // MARK: - Sections

    private var introCard: some View {
        DeltiqSection(String(localized: "settings.dataImport.intro.header", bundle: .module).uppercased()) {
            Text("settings.dataImport.intro.body", bundle: .module)
                .font(.callout)
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            hintRow(String(localized: "settings.dataImport.intro.footer", bundle: .module))
        }
    }

    private var strategyCard: some View {
        DeltiqSection(String(localized: "settings.dataImport.strategy.header", bundle: .module).uppercased()) {
            VStack(alignment: .leading, spacing: 6) {
                bullet("settings.dataImport.strategy.appendOnly")
                bullet("settings.dataImport.strategy.duplicates")
                bullet("settings.dataImport.strategy.errorsLog")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    /// DEL-175: Strategy-Picker erscheint erst NACHDEM eine Datei gewählt
    /// wurde — vorher wäre der Picker bedeutungslos. Sortiert: Append-only
    /// (Recommended) als erster Eintrag, Replace zweitens mit deutlichem
    /// Warning-Look bei Auswahl.
    @ViewBuilder
    private var strategyPickerCard: some View {
        DeltiqSection(String(localized: "settings.dataImport.strategyPicker.header", bundle: .module).uppercased()) {
            DeltiqSegmentedPicker(
                options: [
                    DeltiqSegmentedOption(
                        DataImportStrategy.appendOnly,
                        label: String(localized: "settings.dataImport.strategyPicker.appendOnly", bundle: .module)
                    ),
                    DeltiqSegmentedOption(
                        DataImportStrategy.replace,
                        label: String(localized: "settings.dataImport.strategyPicker.replace", bundle: .module)
                    )
                ],
                selection: $strategy
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if strategy == .replace {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.Deltiq.error)
                    Text("settings.dataImport.strategyPicker.replaceWarning", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.Deltiq.error.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            } else {
                hintRow(String(localized: "settings.dataImport.strategyPicker.appendOnlyDescription", bundle: .module))
            }
        }
    }

    @ViewBuilder
    private func bullet(_ key: String.LocalizationValue) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "shield.fill")
                .foregroundStyle(Color.deltiqOrange)
                .font(.caption.weight(.bold))
            Text(String(localized: key, bundle: .module))
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        switch phase {
        case .ready:
            pickButton

        case .picked(let filename):
            DeltiqSection(String(localized: "settings.dataImport.picked.header", bundle: .module).uppercased()) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.zipper")
                        .foregroundStyle(Color.Deltiq.textSecondary)
                    Text(filename)
                        .font(.callout.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)

                Button {
                    // DEL-175: je nach Strategy einen anderen
                    // Confirm-Dialog präsentieren. Replace bekommt den
                    // destruktiven Warning-Dialog.
                    if strategy == .replace {
                        showReplaceConfirmDialog = true
                    } else {
                        showConfirmDialog = true
                    }
                } label: {
                    Label {
                        Text(strategy == .replace
                             ? "settings.dataImport.action.startReplace"
                             : "settings.dataImport.action.start",
                             bundle: .module)
                    } icon: {
                        Image(systemName: strategy == .replace
                              ? "arrow.triangle.2.circlepath"
                              : "square.and.arrow.down")
                    }
                }
                .buttonStyle(.plain)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                // Replace ist destruktiv -> Rot statt Akzent-Orange, gleiche
                // Ausnahme wie SettingsView.dangerZoneSection (Color.Deltiq.error
                // ist echte, nicht-redundante Warn-Info, kein Marken-Akzent).
                .background(strategy == .replace ? Color.Deltiq.error : Color.deltiqOrange)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(14)
                // DEL-226: Nicht startbar, solange der Trockenlauf laeuft
                // oder die Datei als unlesbar erkannt wurde. Vorher fuehrte
                // ein kaputtes ZIP erst nach dem Tap in einen Fehler —
                // beim Replace-Pfad war das der Moment maximaler Nervosität.
                .disabled(previewFailed || preview == nil)
            }

        case .importing:
            // DEL-176: Live-Progress-Card statt nur Spinner. Bei großen
            // Backups (Jahre History) braucht der Import sichtbar Sekunden
            // — der User soll sehen, dass die App nicht hängt.
            DeltiqSection(String(localized: "settings.dataImport.importing.header", bundle: .module).uppercased()) {
                VStack(alignment: .leading, spacing: 10) {
                    // Phase-Text (lokalisiert) + N / M Counter
                    HStack {
                        Text(progressPhaseLabel)
                            .font(.callout)
                            .foregroundStyle(Color.primary)
                        Spacer()
                        if let p = importProgress, p.filesTotal > 0 {
                            Text("\(p.filesCompleted) / \(p.filesTotal)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        }
                    }
                    // Linear-Progress: animiert sich smooth auf die
                    // neue fraction. Bei unbekanntem Total (wipe-Phase)
                    // zeigen wir indeterminate.
                    if let p = importProgress, p.filesTotal > 0 {
                        ProgressView(value: p.fraction)
                            .tint(Color.deltiqOrange)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(Color.deltiqOrange)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }

        case .finished(let result):
            resultSection(result: result)
        }
    }

    private var pickButton: some View {
        DeltiqSection {
            Button {
                showFilePicker = true
            } label: {
                Label {
                    Text("settings.dataImport.action.pick", bundle: .module)
                } icon: {
                    Image(systemName: "folder.badge.plus")
                }
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()
            .padding(14)
        }
    }

    @ViewBuilder
    private func resultSection(result: DataImportResult) -> some View {
        DeltiqSection(String(localized: "settings.dataImport.result.header", bundle: .module).uppercased()) {
            VStack(alignment: .leading, spacing: 8) {
                resultLine(
                    labelKey: "settings.dataImport.result.imported",
                    countText: String(result.totalImported),
                    color: Color.Deltiq.success,
                    icon: "checkmark.circle.fill"
                )
                resultLine(
                    labelKey: "settings.dataImport.result.skipped",
                    countText: String(result.totalSkipped),
                    color: Color.Deltiq.textSecondary,
                    icon: "minus.circle.fill"
                )
                if result.errorRows > 0 {
                    resultLine(
                        labelKey: "settings.dataImport.result.errors",
                        countText: String(result.errorRows),
                        color: Color.Deltiq.error,
                        icon: "exclamationmark.triangle.fill"
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle()
                .fill(Color.Deltiq.divider)
                .frame(height: 1)

            // Pro-File-Breakdown (klein, monospaced — debugging-freundlich,
            // aber unaufdringlich). DEL-199: Byte-Größen-Anzeige aus der
            // DEL-185-Debug-Phase wieder entfernt.
            VStack(alignment: .leading, spacing: 4) {
                ForEach(filesInResult(result), id: \.self) { file in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(file).font(.caption2.monospaced()).foregroundStyle(Color.Deltiq.textSecondary)
                        Spacer()
                        Text(String(
                            format: String(localized: "settings.dataImport.result.fileSummary", bundle: .module),
                            result.imported[file] ?? 0,
                            result.skipped[file] ?? 0
                        ))
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.Deltiq.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if result.errorsCSV != nil {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)

                Button {
                    prepareAndShareErrorsCSV(result: result)
                } label: {
                    Label {
                        Text("settings.dataImport.action.shareErrors", bundle: .module)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.plain)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.Deltiq.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.Deltiq.error.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(14)
            }

            // DEL-199: Das DEL-187-Inline-Diagnose-Panel ist wieder ausgebaut
            // — es war Notfall-Werkzeug während der DEL-188-Parser-Jagd.
            // Echte Row-Errors bleiben über den Share-Button oben zugänglich.
        }
    }

    @ViewBuilder
    private func resultLine(labelKey: String.LocalizationValue, countText: String, color: Color, icon: String) -> some View {
        HStack {
            Label {
                Text(String(localized: labelKey, bundle: .module))
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
            .font(.callout)
            Spacer()
            Text(countText).font(.callout.bold()).foregroundStyle(Color.primary)
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.Deltiq.error)
            Text(message)
                .font(.callout)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.Deltiq.error.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// DEL-106-Muster (siehe SettingsView.hintRow): Inline-Caption am Fuss einer Section.
    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    // MARK: - Logic

    private func filesInResult(_ r: DataImportResult) -> [String] {
        let keys = Set(r.imported.keys).union(r.skipped.keys)
        return keys.sorted()
    }


    /// DEL-176: Mappt den Service-`phase`-Identifier auf einen lokalisierten
    /// Anzeigetext. Service liefert stable identifiers ("workouts.csv",
    /// "wipe", "save"); die Sprach-Verantwortung liegt in der UI.
    private var progressPhaseLabel: String {
        guard let p = importProgress else {
            return String(localized: "settings.dataImport.importing", bundle: .module)
        }
        let key: String.LocalizationValue
        switch p.phase {
        case "wipe":                  key = "settings.dataImport.progress.wipe"
        case "save":                  key = "settings.dataImport.progress.save"
        case "profile.csv":           key = "settings.dataImport.progress.profile"
        case "settings.csv":          key = "settings.dataImport.progress.settings"
        case "gear.csv":              key = "settings.dataImport.progress.gear"
        case "custom_exercises.csv":  key = "settings.dataImport.progress.customExercises"
        case "plans.csv":             key = "settings.dataImport.progress.plans"
        case "measurements.csv":      key = "settings.dataImport.progress.measurements"
        case "water_log.csv":         key = "settings.dataImport.progress.waterLog"
        case "plan_days.csv":         key = "settings.dataImport.progress.planDays"
        case "workouts.csv":          key = "settings.dataImport.progress.workouts"
        case "plan_exercises.csv":    key = "settings.dataImport.progress.planExercises"
        case "workout_sets.csv":      key = "settings.dataImport.progress.workoutSets"
        case "personal_records.csv":  key = "settings.dataImport.progress.personalRecords"
        default:                      key = "settings.dataImport.importing"
        }
        return String(localized: key, bundle: .module)
    }

    /// DEL-226: Was steckt in der gewaehlten Datei?
    @ViewBuilder
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("import.preview.title", bundle: .module)
                    .font(.headline)
            } icon: {
                Image(systemName: "doc.text.magnifyingglass")
            }

            if previewFailed {
                Text("import.preview.unreadable", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(Color.Deltiq.error)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let preview {
                Text(String(
                    format: String(localized: "import.preview.exportedAt", bundle: .module),
                    preview.exportedAt
                ))
                .font(.caption)
                .foregroundStyle(Color.Deltiq.textSecondary)

                Text(String(
                    format: String(localized: "import.preview.comparison", bundle: .module),
                    preview.totalRows, currentRecordCount
                ))
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

                // Aufschluesselung pro Datei — das ist der eigentliche "Diff":
                // der User erkennt an den Zahlen, ob es das Backup ist, das er
                // gemeint hat.
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(preview.nonEmptyFiles, id: \.name) { entry in
                        HStack {
                            Text(fileLabel(entry.name))
                                .font(.caption)
                                .foregroundStyle(Color.Deltiq.textSecondary)
                            Spacer()
                            Text("\(entry.rows)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.primary)
                        }
                    }
                }
                .padding(.top, 2)

                if preview.containsActivePlan {
                    Label {
                        Text("import.preview.activePlanWarning", bundle: .module)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
                Label {
                    Text("import.preview.restorePointNote", bundle: .module)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .font(.caption)
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                ProgressView()
            }
        }
        .deltiqCardStyle()
    }

    private func handlePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Security-scoped resource: bei Files-Picker MUSS man Access
            // explizit anfordern — sonst kann der App-Sandbox den Read nicht
            // durchführen.
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }

            // Datei sofort in Caches kopieren — die Security-Scope-URL kann
            // beim Sheet-Dismiss invalidiert werden, eine lokale Kopie ist
            // robuster für den späteren Import-Run.
            do {
                let cacheURL = try copyToCaches(sourceURL: url)
                pickedURL = cacheURL
                phase = .picked(filename: url.lastPathComponent)
                errorMessage = nil
                // DEL-226: Trockenlauf direkt beim Auswaehlen. Der Import war
                // bis hierher ein Sprung ins Dunkle — der User erfuhr erst
                // NACH dem Schreiben, was in der Datei stand. Bei der
                // replace-Strategie ist das der Moment, in dem der eigene
                // Bestand schon weg ist. Schreibt nichts, prueft aber genau
                // wie ein echter Import.
                loadPreview(from: cacheURL)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    /// DEL-226: Trockenlauf. Nutzt exakt dieselbe Entpack- und
    /// Validierungs-Strecke wie der echte Import (`DataImportService.preview`
    /// und `performImport` teilen `extractAndValidate`), schreibt aber nichts.
    private func loadPreview(from url: URL) {
        preview = nil
        previewFailed = false
        do {
            let data = try Data(contentsOf: url)
            preview = try DataImportService.preview(zipData: data)
            currentRecordCount = countCurrentRecords()
        } catch {
            // Kein Fehler-Banner: die Vorschau-Karte sagt selbst, dass die
            // Datei nicht lesbar ist, und der Import-Button bleibt gesperrt.
            previewFailed = true
        }
    }

    /// Vergleichsgroesse "was habe ich jetzt". Bewusst die Zeilen, die auch im
    /// Backup als Datensaetze zaehlen, damit die beiden Zahlen in der Vorschau
    /// vergleichbar sind.
    private func countCurrentRecords() -> Int {
        var total = 0
        total += (try? modelContext.fetchCount(FetchDescriptor<WorkoutSession>())) ?? 0
        total += (try? modelContext.fetchCount(FetchDescriptor<ExerciseLog>())) ?? 0
        total += (try? modelContext.fetchCount(FetchDescriptor<BodyMeasurement>())) ?? 0
        total += (try? modelContext.fetchCount(FetchDescriptor<WaterEntry>())) ?? 0
        total += (try? modelContext.fetchCount(FetchDescriptor<PersonalRecordEntry>())) ?? 0
        total += (try? modelContext.fetchCount(FetchDescriptor<TrainingPlan>())) ?? 0
        total += (try? modelContext.fetchCount(FetchDescriptor<TrainingDay>())) ?? 0
        total += (try? modelContext.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        total += (try? modelContext.fetchCount(FetchDescriptor<Gear>())) ?? 0
        return total
    }

    /// Lesbarer Name einer CSV-Datei fuer die Vorschau. Fallback ist der
    /// Dateiname selbst — eine kuenftige, hier noch unbekannte Datei
    /// verschwindet dadurch nicht aus der Liste.
    private func fileLabel(_ filename: String) -> String {
        let stem = filename.replacingOccurrences(of: ".csv", with: "")
        let known = [
            "profile", "measurements", "water_log", "plans", "plan_days",
            "plan_exercises", "workouts", "workout_sets", "personal_records",
            "gear", "custom_exercises", "settings",
        ]
        guard known.contains(stem) else { return filename }
        switch stem {
        case "profile":           return String(localized: "import.file.profile", bundle: .module)
        case "measurements":      return String(localized: "import.file.measurements", bundle: .module)
        case "water_log":         return String(localized: "import.file.water_log", bundle: .module)
        case "plans":             return String(localized: "import.file.plans", bundle: .module)
        case "plan_days":         return String(localized: "import.file.plan_days", bundle: .module)
        case "plan_exercises":    return String(localized: "import.file.plan_exercises", bundle: .module)
        case "workouts":          return String(localized: "import.file.workouts", bundle: .module)
        case "workout_sets":      return String(localized: "import.file.workout_sets", bundle: .module)
        case "personal_records":  return String(localized: "import.file.personal_records", bundle: .module)
        case "gear":              return String(localized: "import.file.gear", bundle: .module)
        case "custom_exercises":  return String(localized: "import.file.custom_exercises", bundle: .module)
        case "settings":          return String(localized: "import.file.settings", bundle: .module)
        default:                  return filename
        }
    }

    private func copyToCaches(sourceURL: URL) throws -> URL {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let importsDir = cachesDir.appendingPathComponent("imports", isDirectory: true)
        try FileManager.default.createDirectory(at: importsDir, withIntermediateDirectories: true)
        let dst = importsDir.appendingPathComponent(sourceURL.lastPathComponent)
        try? FileManager.default.removeItem(at: dst)
        try FileManager.default.copyItem(at: sourceURL, to: dst)
        return dst
    }

    private func runImport() {
        guard let url = pickedURL else { return }
        errorMessage = nil
        importProgress = nil
        phase = .importing

        let ctx = modelContext
        Task {
            do {
                // DEL-226: Restore-Point VOR jedem Import — auch bei
                // appendOnly. Der Rueckweg fehlte genau in dem Vorfall, der
                // diesem Ticket zugrunde liegt: der Import loeschte den
                // Bestand und es gab keinen Stand von gestern. `try?`, weil
                // ein fehlgeschlagener Restore-Point den Import nicht
                // blockieren soll — dann steht in der Vorschau-Notiz zwar ein
                // Versprechen, das nicht eingehalten wurde, aber ein
                // erzwungener Abbruch waere fuer den User schlimmer als ein
                // Import ohne Netz.
                _ = try? BackupService.createBackup(context: ctx, reason: .preImport)

                let zipData = try Data(contentsOf: url)
                // DEL-176: progressHandler ist @Sendable; wir reichen
                // Updates über einen MainActor-Hop an unseren @State weiter.
                // Der Service läuft synchron auf demselben Actor wie ctx
                // (Main bei SwiftData iOS-17), aber wir nehmen den
                // MainActor.run-Wrap als Defensive — falls Apple den Actor
                // mal explizit macht.
                let result = try DataImportService.performImport(
                    zipData: zipData,
                    context: ctx,
                    strategy: strategy,
                    progressHandler: { tick in
                        Task { @MainActor in
                            self.importProgress = tick
                        }
                    }
                )
                // Nachgetragene Laeufe aus einer Sicherung vor dem Dauer-Fix
                // (1-2 Min statt der eingetragenen Laufzeit) nachziehen.
                SessionDurationRepair.repairAfterImport(in: ctx)
                // DEL-209: Importierte Reminder-Präferenzen sofort beim
                // System anmelden — sonst greifen sie erst beim naechsten
                // App-Start (RootView gleicht dann ab). Der Scheduler prüft
                // die Notification-Permission selbst.
                await rescheduleImportedReminders()
                await MainActor.run {
                    // Ersetzen loescht alle Trainings: Ein noch laufender Zeitformat-Lauf
                    // (stilles Hintergrund-Audio + Live Activity) hat danach keine Session.
                    if strategy == .replace {
                        TimedWorkoutBackground.shared.endAll()
                    }
                    self.phase = .finished(result: result)
                    self.importProgress = nil
                    // DEL-216: Import kann heutige Wasser-Einträge geändert
                    // haben — Home-Screen-Widget sofort aktualisieren.
                    #if canImport(WidgetKit)
                    WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.waterWidgetKind)
                    #endif
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.phase = .ready
                    self.pickedURL = nil
                    self.importProgress = nil
                }
            }
        }
    }

    /// DEL-209: Wendet die frisch importierten Reminder-Präferenzen aufs
    /// System an (Wasser + Messung). Liest direkt aus UserDefaults — die
    /// settings.csv-Werte sind zu diesem Zeitpunkt bereits geschrieben.
    private func rescheduleImportedReminders() async {
        // Gemeinsame Logik (inkl. Vorgabewerte fuer fehlende Keys) liegt in
        // `ReminderPreferencesApplier` — dieselbe wird nach dem Onboarding
        // und bei jedem App-Start benutzt.
        await ReminderPreferencesApplier.applyStoredSchedules()
    }

    private func prepareAndShareErrorsCSV(result: DataImportResult) {
        guard let data = result.errorsCSV else { return }
        do {
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let url = cachesDir.appendingPathComponent("import-errors.csv")
            try? FileManager.default.removeItem(at: url)
            try data.write(to: url)
            errorsCSVURL = url
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - ShareSheet wrapper (duplicate-free naming vs Export view)

#if os(iOS)
private struct ImportShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#endif
