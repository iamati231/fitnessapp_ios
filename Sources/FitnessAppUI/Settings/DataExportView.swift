// DEL-173: Daten-Export UI (Phase 1 — Export only).
//
// User-Flow:
//   1. SettingsView → Tap "Daten exportieren (CSV)"
//   2. DataExportView öffnet sich als NavigationLink-Push
//   3. Status-Initial: Übersicht, was im Export drin ist
//   4. Tap "Export starten" → Loading-State (~Sekunden bei großen Datenmengen)
//   5. Bei Erfolg: Share-Sheet rauf, User teilt das ZIP per AirDrop / Files /
//      Mail / Messenger / iCloud Drive (alle Standard-iOS-Ziele)
//   6. Bei Fehler: rote Alert mit Beschreibung
//
// **Threading**: Der Export läuft in einem `Task.detached` — sonst blockiert
// das Fetchen + CSV-Serialisieren bei großen History-Dumps den Main-Thread
// für mehrere Sekunden und die ProgressView friert ein.

#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 17.0, macOS 14.0, *)
public struct DataExportView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// DEL-177: Letzter erfolgreicher Export als UTC-Timestamp
    /// (`Date.timeIntervalSince1970`). 0 = nie. Wird vom Dashboard gelesen,
    /// um nach 30 Tagen einen sanften Backup-Reminder einzublenden.
    /// AppStorage statt Profil-Property, damit die Migration leichtgewichtig
    /// bleibt und der Reminder auch dann funktioniert, wenn der User noch
    /// kein Profil angelegt hat (Edge-Case nach App-Wipe).
    @AppStorage("lastDataExportAt") private var lastDataExportAt: Double = 0

    @State private var phase: Phase = .ready
    @State private var temporaryFileURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    enum Phase {
        case ready
        case exporting
        case finished(bundle: DataExportBundle)
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: direkt von SettingsView gepusht (kein
            // eigener Zwischen-Hub) - Eyebrow zeigt den Tab, selbes Muster wie
            // DashboardSettingsView/ExerciseLibraryView.
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "settings.dataExport.title", bundle: .module),
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 18) {
                introCard
                contentsCard
                actionCard
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
        #if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            if let url = temporaryFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        #endif
    }

    // MARK: - Sections

    private var introCard: some View {
        DeltiqSection(String(localized: "settings.dataExport.intro.header", bundle: .module).uppercased()) {
            Text("settings.dataExport.intro.body", bundle: .module)
                .font(.callout)
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            hintRow(String(localized: "settings.dataExport.intro.footer", bundle: .module))
        }
    }

    private var contentsCard: some View {
        DeltiqSection(String(localized: "settings.dataExport.contents.header", bundle: .module).uppercased()) {
            VStack(alignment: .leading, spacing: 6) {
                bullet("settings.dataExport.contents.profile")
                bullet("settings.dataExport.contents.measurements")
                bullet("settings.dataExport.contents.workouts")
                bullet("settings.dataExport.contents.plans")
                bullet("settings.dataExport.contents.records")
                bullet("settings.dataExport.contents.gear")
                bullet("settings.dataExport.contents.custom")
                bullet("settings.dataExport.contents.settings")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func bullet(_ key: String.LocalizationValue) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
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
    private var actionCard: some View {
        switch phase {
        case .ready:
            DeltiqSection {
                Button {
                    startExport()
                } label: {
                    Label {
                        Text("settings.dataExport.action.start", bundle: .module)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.plain)
                .deltiqButtonStyle()
                .padding(14)
            }
        case .exporting:
            DeltiqSection {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("settings.dataExport.exporting", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        case .finished(let bundle):
            DeltiqSection(String(localized: "settings.dataExport.finished.header", bundle: .module).uppercased()) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(format: String(localized: "settings.dataExport.finished.summary", bundle: .module), bundle.totalRows))
                        .font(.callout)
                        .foregroundStyle(Color.primary)
                    Text(bundle.suggestedFilename)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)

                Button {
                    showShareSheet = true
                } label: {
                    Label {
                        Text("settings.dataExport.action.share", bundle: .module)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.plain)
                .deltiqButtonStyle()
                .padding(14)
            }
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

    // MARK: - Export logic

    private func startExport() {
        errorMessage = nil
        phase = .exporting

        // Wir snapshotten den modelContext-Pointer (Sendable-Workaround
        // entfällt, weil ModelContext seinerseits an den Main-Thread bzw.
        // den eigenen Container gebunden ist). Bei iOS 17 ist `ModelContext`
        // tatsächlich kein Sendable — also bleibt die Fetch-Operation auf
        // dem Main-Thread, der teure Teil (CSV-Strings bauen + ZIP-Stream)
        // läuft via `await Task.detached`. Das Fetch-Latency ist im Sub-100ms-
        // Bereich; das Ausreizen wird erst beim Logs-Dump knapp.
        let ctx = modelContext
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"

        Task {
            do {
                // Fetch + Build hängen am ModelContext, also auf dem aktuellen
                // Actor. SwiftData fetched sehr schnell, der CSV-Bau ist CPU-
                // bound — kein I/O — und das ZIP-Schreiben ist in-memory.
                // Gesamt bei einem typischen User unter 1 s, bei power-User
                // mit Jahren History ~3-5 s. Acceptable für ein einmaliges
                // Export-Click.
                let bundle = try DataExportService.makeExport(context: ctx, appVersion: appVersion)
                let url = try writeToTempFile(bundle: bundle)

                // DEL-228: Das ZIP zusätzlich dauerhaft als Backup-Generation
                // hinterlegen. Vorher war ein manueller Export flüchtig — die
                // Datei lag nur im Caches-Ordner für das Share-Sheet, und wenn
                // der User sie nicht selbst irgendwohin schob (oder das Sheet
                // abbrach), war sie beim nächsten Aufräumen von iOS weg. Kein
                // erneuter Export nötig: `store` nimmt das schon gebaute
                // Bundle. Fehler hier dürfen den Export-Flow nicht kippen —
                // das Teilen funktioniert auch ohne die Generation.
                _ = try? BackupService.store(bundle: bundle, reason: .manual)

                await MainActor.run {
                    self.temporaryFileURL = url
                    self.phase = .finished(bundle: bundle)
                    // DEL-177: Backup-Reminder-Timestamp setzen. Dashboard
                    // checkt diesen Wert; bei > 30 Tagen Distanz wird die
                    // soft-coaching .backupOverdue-Message gezündet.
                    self.lastDataExportAt = Date().timeIntervalSince1970
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.phase = .ready
                }
            }
        }
    }

    /// Schreibt das ZIP in den temporären Caches-Ordner — UIActivityVC kann
    /// nur File-URLs teilen, keine Data-Blobs. Beim nächsten App-Start
    /// räumt iOS Caches selbständig auf, deshalb kein Cleanup nötig.
    private func writeToTempFile(bundle: DataExportBundle) throws -> URL {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let exportDir = cachesDir.appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        let url = exportDir.appendingPathComponent(bundle.suggestedFilename)
        // Überschreiben falls aus einem früheren Lauf noch da.
        try? FileManager.default.removeItem(at: url)
        try bundle.data.write(to: url)
        return url
    }
}

// MARK: - ShareSheet wrapper

#if os(iOS)
/// Dünner UIKit-Wrapper. Reicht völlig für Files/AirDrop/Mail-Targets — und
/// alles, was wir hier brauchen, ist "User wählt ein Ziel, iOS macht den
/// Rest". Kein eigener Sharing-State.
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#endif
