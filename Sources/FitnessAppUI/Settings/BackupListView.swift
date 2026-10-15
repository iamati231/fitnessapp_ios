// DEL-229: Wiederherstellungs-UI fuer die automatischen Backup-Generationen
// aus DEL-227/228.
//
// Ohne diesen Screen existieren die Backups, sind aber unerreichbar — der
// User muesste die Dateien per Files-App aus dem App-Ordner holen und ueber
// den Import-Flow einspielen. Genau die Huerde, die im Ernstfall
// (Datenverlust, Panik) niemand ueberwindet.
//
// Sicherheitsnetz beim Wiederherstellen: VOR dem Replace-Import wird der
// JETZIGE Stand als `preImport`-Generation gesichert. Damit ist auch ein
// versehentlich gewaehlter, zu alter Stand zurueckholbar — die Lehre aus dem
// Datenverlust im Mai 2026, wo genau dieser Rueckweg fehlte.

#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

@available(iOS 17.0, macOS 14.0, *)
public struct BackupListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var generations: [BackupService.Generation] = []
    @State private var pendingRestore: BackupService.Generation?
    @State private var pendingDelete: BackupService.Generation?
    /// Settings-Epic Phase 5 (Befund BL-08): ersetzt das gemeinsame
    /// `isWorking: Bool` — der Status-Text zeigte vorher IMMER
    /// "Wird wiederhergestellt…", auch waehrend `createNow()` lief.
    @State private var operation: Operation = .idle
    @State private var resultMessage: String?
    @State private var errorMessage: String?
    /// Settings-Epic Phase 5 (Befund BL-03): getrennt von `generations.isEmpty`
    /// — ein echter Ladefehler (Berechtigung, Datentraeger) darf nicht wie
    /// "noch nie gesichert" aussehen.
    @State private var listLoadError: String?

    enum Operation: Equatable {
        case idle
        case creating
        case restoring
        case deleting
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: direkt von SettingsView gepusht (kein
            // eigener Zwischen-Hub) - Eyebrow zeigt den Tab, selbes Muster wie
            // DashboardSettingsView/DataExportView.
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "backups.title", bundle: .module),
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 18) {
                // DEL-234: Notzustand zuerst — wenn die App auf dem Ersatz-Store
                // laeuft, sind alle anderen Angaben auf diesem Screen mit Vorsicht
                // zu lesen und es werden bewusst keine Backups mehr geschrieben.
                unhealthyStoreCard
                introCard
                if let listLoadError {
                    loadErrorCard(listLoadError)
                } else if generations.isEmpty {
                    emptyCard
                } else {
                    generationsCard
                }
                actionCard
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
        .task { reload() }
        .confirmationDialog(
            Text("backups.restore.confirm.title", bundle: .module),
            isPresented: Binding(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                if let target = pendingRestore { restore(target) }
                pendingRestore = nil
            } label: {
                Text("backups.restore.action", bundle: .module)
            }
            Button(role: .cancel) { pendingRestore = nil } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            if let pendingRestore {
                Text(String(
                    format: String(localized: "backups.restore.confirm.message", bundle: .module),
                    Self.dateText(pendingRestore.createdAt)
                ))
            }
        }
        // Settings-Epic Phase 5 (Befund BL-05): Loeschen war vorher ein
        // ungesicherter Tap — jetzt derselbe Bestaetigungs-Dialog wie beim
        // Wiederherstellen.
        .confirmationDialog(
            Text("backups.delete.confirm.title", bundle: .module),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                if let target = pendingDelete { delete(target) }
                pendingDelete = nil
            } label: {
                Text("backups.delete.action", bundle: .module)
            }
            Button(role: .cancel) { pendingDelete = nil } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            if let pendingDelete {
                Text(String(
                    format: String(localized: "backups.delete.confirm.message", bundle: .module),
                    Self.dateText(pendingDelete.createdAt)
                ))
            }
        }
    }

    // MARK: Sections

    /// DEL-234: Sichtbarer Hinweis auf den Ersatz-Datenspeicher. Ohne den
    /// wuerde der User nur bemerken, dass keine neuen Generationen mehr
    /// dazukommen — und das erst, wenn er sie braucht.
    @ViewBuilder
    private var unhealthyStoreCard: some View {
        if case .fellBackAfterGroupStoreFailure = SharedStore.health {
            DeltiqSection {
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text("backups.unhealthy.title", bundle: .module)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(.headline)
                    .foregroundStyle(Color.Deltiq.error)
                    Text("backups.unhealthy.description", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    private var introCard: some View {
        DeltiqSection {
            Text("backups.intro", bundle: .module)
                .font(.footnote)
                .foregroundStyle(Color.Deltiq.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
    }

    private var emptyCard: some View {
        DashboardEmptyState(
            icon: "clock.arrow.circlepath",
            title: "backups.empty.title",
            description: "backups.empty.description"
        )
        .deltiqCardStyle()
    }

    /// Settings-Epic Phase 5 (Befund BL-03): ein echter Lesefehler (Zugriff
    /// entzogen, Datentraeger-Problem) sieht jetzt sichtbar anders aus als
    /// "noch nie gesichert" (`emptyCard`) — sonst verschwinden bestehende
    /// Backups scheinbar spurlos, obwohl sie noch da sind.
    private func loadErrorCard(_ message: String) -> some View {
        DeltiqSection {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("backups.loadError.title", bundle: .module)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.headline)
                .foregroundStyle(Color.Deltiq.error)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    reload()
                } label: {
                    Text("backups.loadError.retry", bundle: .module)
                }
                .font(.caption.weight(.semibold))
                .tint(Color.deltiqOrange)
                .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var generationsCard: some View {
        DeltiqSection {
            ForEach(generations) { generation in
                row(for: generation, showsDivider: generation.id != generations.last?.id)
            }
        }
    }

    /// Wiederherstellen ist destruktiv und darf nicht versehentlich per Tap
    /// auf die Zeile passieren — deshalb ein explizites Menu statt eines
    /// tappable Rows. Ersetzt die List-exklusiven `.swipeActions`/
    /// `.contextMenu`, die ausserhalb einer List nicht mehr greifen.
    private func row(for generation: BackupService.Generation, showsDivider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Self.dateText(generation.createdAt))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    HStack(spacing: 6) {
                        Text(Self.reasonText(generation.reason))
                        Text("·")
                        Text(Self.sizeText(generation.byteCount))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                }
                Spacer()
                Menu {
                    Button {
                        pendingRestore = generation
                    } label: {
                        Label {
                            Text("backups.restore.action", bundle: .module)
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                    Button(role: .destructive) {
                        // Settings-Epic Phase 5 (Befund BL-05): Loeschen
                        // erst nach Bestaetigung, nicht mehr per direktem Tap.
                        pendingDelete = generation
                    } label: {
                        Label {
                            Text("backups.delete.action", bundle: .module)
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        // BL-05 (Phase 6): 32x32pt lag unter dem 44pt-Minimum.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                // BL-05: Label MIT Datum, sonst liest VoiceOver nur "Mehr",
                // ohne zu sagen, fuer welche Sicherung.
                .accessibilityLabel(Text(String(
                    format: String(localized: "backups.actions.menu", bundle: .module),
                    Self.dateText(generation.createdAt)
                )))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private var actionCard: some View {
        DeltiqSection {
            Button {
                createNow()
            } label: {
                HStack {
                    Label {
                        Text("backups.createNow", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                    }
                    Spacer()
                    if operation != .idle { ProgressView() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(operation != .idle)

            // Settings-Epic Phase 5 (Befund BL-08): eigener Text je Operation
            // statt eines gemeinsamen `isWorking`-Flags, das z.B. waehrend
            // `createNow()` faelschlich "Wird wiederhergestellt…" zeigte.
            if let runningLabelKey = operationRunningLabelKey {
                Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                Text(String(localized: runningLabelKey, bundle: .module))
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            if let resultMessage {
                Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                Text(resultMessage)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.success)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            if let errorMessage {
                Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.error)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }

            hintRow(String(localized: "backups.footer", bundle: .module))
        }
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

    /// Settings-Epic Phase 5 (Befund BL-08): ein eigener Text je laufender
    /// Operation statt eines gemeinsamen `isWorking`-Flags.
    private var operationRunningLabelKey: String.LocalizationValue? {
        switch operation {
        case .idle:      nil
        case .creating:  "backups.creating.running"
        case .restoring: "backups.restore.running"
        case .deleting:  "backups.deleting.running"
        }
    }

    // MARK: Aktionen

    private func reload() {
        // Settings-Epic Phase 5 (Befund BL-03): `listGenerations()` wirft
        // jetzt bei einem echten Lesefehler (vorher `try?` -> `[]`, nicht
        // mehr unterscheidbar von "noch nie gesichert").
        do {
            generations = try BackupService.listGenerations()
            listLoadError = nil
        } catch {
            listLoadError = error.localizedDescription
        }
    }

    private func createNow() {
        operation = .creating
        resultMessage = nil
        errorMessage = nil
        let ctx = modelContext
        Task {
            do {
                // Settings-Epic Phase 5 (Befund BL-07): echtes `Task` statt
                // komplett synchronem Aufruf — `createBackupAsync` haelt den
                // Main-Thread waehrend ZIP-Kompression + Schreiben responsiv.
                _ = try await BackupService.createBackupAsync(context: ctx, reason: .manual)
                await MainActor.run {
                    self.reload()
                    self.operation = .idle
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.operation = .idle
                }
            }
        }
    }

    private func delete(_ generation: BackupService.Generation) {
        // Einzelne Datei loeschen ist nahezu instantan — bleibt synchron,
        // zeigt aber jetzt den Fehler statt ihn mit `try?` zu verschlucken
        // (Befund BL-05).
        operation = .deleting
        resultMessage = nil
        errorMessage = nil
        do {
            try BackupService.delete(generation)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
        operation = .idle
    }

    /// Wiederherstellen = Replace-Import des gewaehlten ZIPs.
    ///
    /// Reihenfolge ist bewusst: ZUERST der Restore-Point des jetzigen Stands,
    /// dann der Import. Faellt der Import um, ist der Ausgangszustand
    /// gesichert; waehlt der User versehentlich einen zu alten Stand, kann er
    /// ueber die `preImport`-Generation zurueck. Der Importer selbst validiert
    /// vor dem Wipe (DEL-183), ein kaputtes ZIP kann also nichts loeschen.
    private func restore(_ generation: BackupService.Generation) {
        operation = .restoring
        resultMessage = nil
        errorMessage = nil
        let ctx = modelContext
        Task {
            do {
                try await BackupService.createBackupAsync(context: ctx, reason: .preImport)
                // Reines Datei-I/O auf einer bereits abgeschlossenen ZIP —
                // sicher per `Task.detached`, haelt den Main-Thread waehrend
                // des Lesens einer potenziell grossen Generation responsiv.
                let data = try await Task.detached { try Data(contentsOf: generation.url) }.value
                let result = try await DataImportService.performImport(
                    zipData: data,
                    context: ctx,
                    strategy: .replace
                )
                // Nachgetragene Laeufe aus einer Sicherung vor dem Dauer-Fix
                // (1-2 Min statt der eingetragenen Laufzeit) nachziehen.
                SessionDurationRepair.repairAfterImport(in: ctx)
                await MainActor.run {
                    // Das Ersetzen hat alle Trainings geloescht: Ein noch
                    // laufender Zeitformat-Lauf (stilles Hintergrund-Audio +
                    // Live Activity) hat keine Session mehr.
                    TimedWorkoutBackground.shared.endAll()
                    self.resultMessage = String(
                        format: String(localized: "backups.restore.done", bundle: .module),
                        result.totalImported, result.totalSkipped
                    )
                    self.operation = .idle
                }
                // Die wiederhergestellten Erinnerungs-Schalter (settings.csv) sind
                // jetzt in UserDefaults, die geplanten Benachrichtigungen im System
                // aber noch die alten - gleich abgleichen statt erst beim naechsten
                // Kaltstart.
                await ReminderPreferencesApplier.applyStoredSchedules()
                await MainActor.run { self.reload() }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.operation = .idle
                }
            }
        }
    }

    // MARK: Formatierung

    private static func dateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func reasonText(_ reason: BackupService.Reason) -> String {
        switch reason {
        case .automatic: String(localized: "backups.reason.automatic", bundle: .module)
        case .manual:    String(localized: "backups.reason.manual", bundle: .module)
        case .preImport: String(localized: "backups.reason.preImport", bundle: .module)
        case .preReset:  String(localized: "backups.reason.preReset", bundle: .module)
        }
    }

    private static func sizeText(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    NavigationStack {
        BackupListView()
    }
    .modelContainer(PreviewSeed.dashboardContainer)
}
#endif
#endif
