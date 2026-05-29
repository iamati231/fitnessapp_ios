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
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 17.0, macOS 14.0, *)
public struct DataImportView: View {

    @Environment(\.modelContext) private var modelContext

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

    enum Phase {
        case ready
        case picked(filename: String)
        case importing
        case finished(result: DataImportResult)
    }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                introCard
                strategyCard
                if case .picked = phase {
                    strategyPickerCard
                }
                actionSection
                if let errorMessage {
                    errorBanner(message: errorMessage)
                }
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        .navigationTitle(Text("settings.dataImport.title", bundle: .module))
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
        DeltiqFormSection(header: String(localized: "settings.dataImport.intro.header", bundle: .module)) {
            DeltiqFormFullRow {
                Text("settings.dataImport.intro.body", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            Text("settings.dataImport.intro.footer", bundle: .module)
        }
    }

    private var strategyCard: some View {
        DeltiqFormSection(header: String(localized: "settings.dataImport.strategy.header", bundle: .module)) {
            DeltiqFormFullRow {
                VStack(alignment: .leading, spacing: 6) {
                    bullet("settings.dataImport.strategy.appendOnly")
                    bullet("settings.dataImport.strategy.duplicates")
                    bullet("settings.dataImport.strategy.errorsLog")
                }
            }
        }
    }

    /// DEL-175: Strategy-Picker erscheint erst NACHDEM eine Datei gewählt
    /// wurde — vorher wäre der Picker bedeutungslos. Sortiert: Append-only
    /// (Recommended) als erster Eintrag, Replace zweitens mit deutlichem
    /// Warning-Look bei Auswahl.
    @ViewBuilder
    private var strategyPickerCard: some View {
        DeltiqFormSection(header: String(localized: "settings.dataImport.strategyPicker.header", bundle: .module)) {
            DeltiqFormFullRow {
                Picker(selection: $strategy) {
                    Text("settings.dataImport.strategyPicker.appendOnly", bundle: .module)
                        .tag(DataImportStrategy.appendOnly)
                    Text("settings.dataImport.strategyPicker.replace", bundle: .module)
                        .tag(DataImportStrategy.replace)
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            DeltiqFormFullRow {
                if strategy == .replace {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("settings.dataImport.strategyPicker.replaceWarning", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("settings.dataImport.strategyPicker.appendOnlyDescription", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                .foregroundStyle(.primary)
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
            DeltiqFormSection(header: String(localized: "settings.dataImport.picked.header", bundle: .module)) {
                DeltiqFormFullRow {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.zipper")
                            .foregroundStyle(.secondary)
                        Text(filename)
                            .font(.callout.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                }
                DeltiqFormFullRow {
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
                        HStack {
                            Spacer()
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
                            .font(.body.weight(.semibold))
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(strategy == .replace ? .red : Color.deltiqOrange)
                }
            }

        case .importing:
            DeltiqFormSection(header: nil) {
                DeltiqFormFullRow {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("settings.dataImport.importing", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }

        case .finished(let result):
            resultSection(result: result)
        }
    }

    private var pickButton: some View {
        DeltiqFormSection(header: nil) {
            DeltiqFormFullRow {
                Button {
                    showFilePicker = true
                } label: {
                    HStack {
                        Spacer()
                        Label {
                            Text("settings.dataImport.action.pick", bundle: .module)
                        } icon: {
                            Image(systemName: "folder.badge.plus")
                        }
                        .font(.body.weight(.semibold))
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.deltiqOrange)
            }
        }
    }

    @ViewBuilder
    private func resultSection(result: DataImportResult) -> some View {
        DeltiqFormSection(header: String(localized: "settings.dataImport.result.header", bundle: .module)) {
            DeltiqFormFullRow {
                VStack(alignment: .leading, spacing: 8) {
                    resultLine(
                        labelKey: "settings.dataImport.result.imported",
                        countText: String(result.totalImported),
                        color: .green,
                        icon: "checkmark.circle.fill"
                    )
                    resultLine(
                        labelKey: "settings.dataImport.result.skipped",
                        countText: String(result.totalSkipped),
                        color: .secondary,
                        icon: "minus.circle.fill"
                    )
                    if result.errorRows > 0 {
                        resultLine(
                            labelKey: "settings.dataImport.result.errors",
                            countText: String(result.errorRows),
                            color: .red,
                            icon: "exclamationmark.triangle.fill"
                        )
                    }
                }
            }
            // Pro-File-Breakdown (klein, monospaced — debugging-freundlich,
            // aber unaufdringlich)
            DeltiqFormFullRow {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(filesInResult(result), id: \.self) { file in
                        HStack {
                            Text(file).font(.caption2.monospaced()).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(
                                format: String(localized: "settings.dataImport.result.fileSummary", bundle: .module),
                                result.imported[file] ?? 0,
                                result.skipped[file] ?? 0
                            ))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            if result.errorsCSV != nil {
                DeltiqFormFullRow {
                    Button {
                        prepareAndShareErrorsCSV(result: result)
                    } label: {
                        HStack {
                            Spacer()
                            Label {
                                Text("settings.dataImport.action.shareErrors", bundle: .module)
                            } icon: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .font(.body.weight(.semibold))
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
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
            Text(countText).font(.callout.bold()).foregroundStyle(.primary)
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Logic

    private func filesInResult(_ r: DataImportResult) -> [String] {
        let keys = Set(r.imported.keys).union(r.skipped.keys)
        return keys.sorted()
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
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
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
        phase = .importing

        let ctx = modelContext
        Task {
            do {
                let zipData = try Data(contentsOf: url)
                // ModelContext ist nicht Sendable — also bleibt der Service
                // auf dem aktuellen Actor (Main). Bei sehr großen Imports
                // (z.B. mehrere Jahre History) wird die UI hier kurz hängen;
                // das ist eine bewusst pragmatische Wahl, weil SwiftData
                // sonst eigene Threads bräuchte. ProgressView spinnt
                // während dieser Zeit.
                let result = try DataImportService.performImport(
                    zipData: zipData,
                    context: ctx,
                    strategy: strategy
                )
                await MainActor.run {
                    self.phase = .finished(result: result)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.phase = .ready
                    self.pickedURL = nil
                }
            }
        }
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
