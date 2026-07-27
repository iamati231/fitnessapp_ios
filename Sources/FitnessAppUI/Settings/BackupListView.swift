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

    @State private var generations: [BackupService.Generation] = []
    @State private var pendingRestore: BackupService.Generation?
    @State private var isWorking = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        List {
            introSection
            if generations.isEmpty {
                emptySection
            } else {
                generationsSection
            }
            actionSection
        }
        .navigationTitle(Text("backups.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
    }

    // MARK: Sections

    private var introSection: some View {
        Section {
            Text("backups.intro", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var emptySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("backups.empty.title", bundle: .module)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .font(.headline)
                Text("backups.empty.description", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var generationsSection: some View {
        Section {
            ForEach(generations) { generation in
                row(for: generation)
            }
        }
    }

    @ViewBuilder
    private func row(for generation: BackupService.Generation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.dateText(generation.createdAt))
                .font(.body.weight(.semibold))
            HStack(spacing: 6) {
                Text(Self.reasonText(generation.reason))
                Text("·")
                Text(Self.sizeText(generation.byteCount))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        // Wiederherstellen ist destruktiv und darf nicht versehentlich per Tap
        // auf die Zeile passieren — bewusst nur ueber Swipe bzw. Kontextmenue.
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                delete(generation)
            } label: {
                Text("backups.delete.action", bundle: .module)
            }
            Button {
                pendingRestore = generation
            } label: {
                Text("backups.restore.action", bundle: .module)
            }
            .tint(Color.deltiqOrange)
        }
        .contextMenu {
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
                delete(generation)
            } label: {
                Label {
                    Text("backups.delete.action", bundle: .module)
                } icon: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        Section {
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
                    if isWorking { ProgressView() }
                }
            }
            .disabled(isWorking)

            if isWorking {
                Text("backups.restore.running", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let resultMessage {
                Text(resultMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } footer: {
            Text("backups.footer", bundle: .module)
        }
    }

    // MARK: Aktionen

    private func reload() {
        generations = (try? BackupService.listGenerations()) ?? []
    }

    private func createNow() {
        isWorking = true
        resultMessage = nil
        errorMessage = nil
        do {
            try BackupService.createBackup(context: modelContext, reason: .manual)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    private func delete(_ generation: BackupService.Generation) {
        try? BackupService.delete(generation)
        reload()
    }

    /// Wiederherstellen = Replace-Import des gewaehlten ZIPs.
    ///
    /// Reihenfolge ist bewusst: ZUERST der Restore-Point des jetzigen Stands,
    /// dann der Import. Faellt der Import um, ist der Ausgangszustand
    /// gesichert; waehlt der User versehentlich einen zu alten Stand, kann er
    /// ueber die `preImport`-Generation zurueck. Der Importer selbst validiert
    /// vor dem Wipe (DEL-183), ein kaputtes ZIP kann also nichts loeschen.
    private func restore(_ generation: BackupService.Generation) {
        isWorking = true
        resultMessage = nil
        errorMessage = nil
        do {
            try BackupService.createBackup(context: modelContext, reason: .preImport)
            let data = try Data(contentsOf: generation.url)
            let result = try DataImportService.performImport(
                zipData: data,
                context: modelContext,
                strategy: .replace
            )
            resultMessage = String(
                format: String(localized: "backups.restore.done", bundle: .module),
                result.totalImported, result.totalSkipped
            )
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
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
