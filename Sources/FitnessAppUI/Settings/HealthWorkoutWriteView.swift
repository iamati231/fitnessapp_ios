// Trainings nach Apple Health schreiben + Export frueherer Trainings.
//
// Aufbau (von oben nach unten):
//   1. Einleitung: was Deltiq schreibt und was nicht (keine Kalorien/Puls).
//   2. Zugriff: Zustand der Trainings-Schreibberechtigung. Bestandsnutzer, die
//      Apple Health vor Ergaenzung dieses Typs verbunden haben, sehen den
//      Dialog sonst nie wieder - hier kann er nutzer-ausgeloest nachgeholt
//      werden.
//   3. Schalter: Krafttraining (Vorgabe an) / Cardio (Vorgabe aus). Apple kennt
//      nur EINE Berechtigung "Trainings"; was davon geschrieben wird, stellt
//      der Nutzer hier ein. Der Cardio-Schalter fragt zusaetzlich die
//      Distanz-Freigabe an.
//   4. Fruehere Trainings: Pruefen (Dry-Run) -> Auswahl + Zahlen -> Bestaetigung
//      -> Schreiben mit Fortschritt/Abbrechen -> Ergebnis.
//
// Die Logik (Planung, Abgleich, Schreib-Schleife) lebt in
// `WorkoutHealthExportService`; die Entscheidungen in Core
// (`HealthWorkoutPlanner`). Diese View haelt nur den Zustand.

#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 17.0, macOS 14.0, *)
public struct HealthWorkoutWriteView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HealthKitController.self) private var healthKit

    @AppStorage(HealthWritePreferences.strengthEnabledKey)
    private var strengthEnabled: Bool = HealthWritePreferences.defaultStrengthEnabled
    @AppStorage(HealthWritePreferences.cardioEnabledKey)
    private var cardioEnabled: Bool = HealthWritePreferences.defaultCardioEnabled

    /// Die Anfrage lief, der Status ist aber unveraendert `.notDetermined`:
    /// Der Dialog wurde nicht beantwortet (abgebrochen) oder iOS hat ihn nicht
    /// gezeigt. Der Hinweistext deckt beides ab: erneut tippen oder in der
    /// Health-App erlauben.
    @State private var requestShowedNoDialog = false

    @State private var exportPhase: ExportPhase = .idle
    @State private var exportTask: Task<Void, Never>?
    @State private var exportStrength = HealthWritePreferences.defaultStrengthEnabled
    @State private var exportCardio = HealthWritePreferences.defaultCardioEnabled
    @State private var showConfirm = false

    private enum ExportPhase {
        case idle
        case checking
        case ready(WorkoutHealthExportService.Preparation)
        case exporting(done: Int, total: Int)
        case finished(WorkoutHealthExportService.Outcome)
        case failed(ExportFailure)
    }

    private enum ExportFailure {
        case deviceLocked
        case generic
        case storeFallback
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "settings.healthWrite.title", bundle: .module),
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 18) {
                introCard
                if healthKit.isAvailable {
                    accessCard
                    switchesCard
                    exportCard
                } else {
                    unavailableCard
                }
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .deltiqSwipeBackEnabled()
        .task {
            await healthKit.refreshAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
        .onDisappear {
            exportTask?.cancel()
            discardPreview()
            setIdleTimer(disabled: false)
        }
        .confirmationDialog(
            Text("settings.healthWrite.confirmTitle", bundle: .module),
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button {
                startExport()
            } label: {
                Text("settings.healthWrite.confirmAction", bundle: .module)
            }
            Button(role: .cancel) {
            } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            Text("settings.healthWrite.confirmMessage", bundle: .module)
        }
    }

    // MARK: - Einleitung / Nicht verfuegbar

    private var introCard: some View {
        DeltiqSection(String(localized: "settings.healthWrite.introHeader", bundle: .module).uppercased()) {
            bodyText(String(localized: "settings.healthWrite.introBody", bundle: .module))
        }
    }

    private var unavailableCard: some View {
        DeltiqSection(String(localized: "settings.healthWrite.accessHeader", bundle: .module).uppercased()) {
            bodyText(String(localized: "measurement.healthkit.unavailable", bundle: .module))
        }
    }

    // MARK: - Zugriff

    private var accessCard: some View {
        DeltiqSection(String(localized: "settings.healthWrite.accessHeader", bundle: .module).uppercased()) {
            accessContent
        }
    }

    @ViewBuilder
    private var accessContent: some View {
        switch healthKit.workoutWriteAuthorization.workout {
        case .sharingAuthorized:
            DeltiqControlRow(
                icon: "checkmark.circle",
                label: String(localized: "settings.healthWrite.accessGranted", bundle: .module),
                showsDivider: false
            ) {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.Deltiq.success)
            }
        case .notDetermined:
            DeltiqControlRow(
                icon: "heart",
                label: String(localized: "settings.healthWrite.accessNone", bundle: .module),
                showsDivider: false
            ) {
                EmptyView()
            }
            Button {
                requestAccess()
            } label: {
                Label {
                    Text("settings.healthWrite.accessButton", bundle: .module)
                } icon: {
                    Image(systemName: "heart.text.square")
                }
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()
            .padding(14)
            if requestShowedNoDialog {
                hintRow(String(localized: "settings.healthWrite.accessNoDialog", bundle: .module))
            } else {
                hintRow(String(localized: "settings.healthWrite.accessHint", bundle: .module))
            }
        case .sharingDenied:
            DeltiqControlRow(
                icon: "heart.slash",
                label: String(localized: "settings.healthWrite.accessDeniedLabel", bundle: .module),
                showsDivider: false
            ) {
                EmptyView()
            }
            hintRow(String(localized: "settings.healthWrite.accessDenied", bundle: .module))
            openIOSSettingsButton
        case .unavailable:
            EmptyView()
        }
    }

    @ViewBuilder
    private var openIOSSettingsButton: some View {
        #if os(iOS)
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            DeltiqRow(
                icon: "gear",
                label: String(localized: "settings.health.openIOSSettings", bundle: .module),
                showsDivider: false
            )
        }
        .buttonStyle(.plain)
        #endif
    }

    private func requestAccess() {
        Task { @MainActor in
            let before = healthKit.workoutWriteAuthorization.workout
            let after = await healthKit.requestWorkoutWriteAuthorization(includeDistance: cardioEnabled)
            requestShowedNoDialog = (before == .notDetermined && after.workout == .notDetermined)
        }
    }

    // MARK: - Schalter

    private var switchesCard: some View {
        DeltiqSection(String(localized: "settings.healthWrite.switchesHeader", bundle: .module).uppercased()) {
            DeltiqControlRow(
                icon: "dumbbell",
                label: String(localized: "settings.healthWrite.strengthLabel", bundle: .module),
                showsDivider: false
            ) {
                Toggle(isOn: $strengthEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .accessibilityLabel(Text("settings.healthWrite.strengthLabel", bundle: .module))
            }
            hintRow(String(localized: "settings.healthWrite.strengthFooter", bundle: .module))

            DeltiqControlRow(
                icon: "figure.run",
                label: String(localized: "settings.healthWrite.cardioLabel", bundle: .module),
                showsDivider: false
            ) {
                Toggle(isOn: $cardioEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .accessibilityLabel(Text("settings.healthWrite.cardioLabel", bundle: .module))
                    .onChange(of: cardioEnabled) { _, enabled in
                        cardioToggled(enabled)
                    }
            }
            hintRow(String(localized: "settings.healthWrite.cardioFooter", bundle: .module))
            if cardioEnabled && distanceDenied {
                hintRow(String(localized: "settings.healthWrite.distanceMissing", bundle: .module))
            }
            if cardioEnabled && distanceUndecided {
                Button {
                    requestDistance()
                } label: {
                    Label {
                        Text("settings.healthWrite.distanceButton", bundle: .module)
                    } icon: {
                        Image(systemName: "figure.walk")
                    }
                }
                .buttonStyle(.plain)
                .deltiqSecondaryButtonStyle()
                .padding(14)
            }
        }
    }

    /// Trainings sind freigegeben, die Distanz wurde verweigert: nur die
    /// Health-App kann das noch aendern.
    private var distanceDenied: Bool {
        let authorization = healthKit.workoutWriteAuthorization
        return authorization.workout == .sharingAuthorized && authorization.distance == .sharingDenied
    }

    /// Trainings sind freigegeben, die Distanz wurde nie angefragt (z.B. weil
    /// Trainings ueber Onboarding/Messung statt ueber diesen Bildschirm
    /// freigegeben wurden): Deltiq kann sie selbst anfragen.
    private var distanceUndecided: Bool {
        let authorization = healthKit.workoutWriteAuthorization
        return authorization.workout == .sharingAuthorized && authorization.distance == .notDetermined
    }

    private func requestDistance() {
        Task { @MainActor in
            await healthKit.requestWorkoutWriteAuthorization(includeDistance: true)
        }
    }

    /// Einschalten von Cardio fragt die Distanz-Freigabe nach - aber nur, wenn
    /// Trainings schon freigegeben sind (sonst erledigt "Zugriff erlauben"
    /// beides in einem Dialog).
    private func cardioToggled(_ enabled: Bool) {
        guard enabled, healthKit.workoutWriteAuthorization.workout == .sharingAuthorized else { return }
        Task { @MainActor in
            await healthKit.requestWorkoutWriteAuthorization(includeDistance: true)
        }
    }

    // MARK: - Fruehere Trainings

    private var exportCard: some View {
        DeltiqSection(String(localized: "settings.healthWrite.exportHeader", bundle: .module).uppercased()) {
            exportContent
        }
    }

    @ViewBuilder
    private var exportContent: some View {
        if healthKit.workoutWriteAuthorization.workout != .sharingAuthorized {
            bodyText(String(localized: "settings.healthWrite.exportNeedsAccess", bundle: .module))
        } else {
            switch exportPhase {
            case .idle:
                idleContent
            case .checking:
                checkingContent
            case .ready(let preparation):
                readyContent(preparation)
            case .exporting(let done, let total):
                exportingContent(done: done, total: total)
            case .finished(let outcome):
                finishedContent(outcome)
            case .failed(let failure):
                failedContent(failure)
            }
        }
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            bodyText(String(localized: "settings.healthWrite.exportIntro", bundle: .module))
            checkButton
        }
    }

    private var checkButton: some View {
        Button {
            startCheck()
        } label: {
            Label {
                Text("settings.healthWrite.exportCheck", bundle: .module)
            } icon: {
                Image(systemName: "magnifyingglass")
            }
        }
        .buttonStyle(.plain)
        .deltiqSecondaryButtonStyle()
        .padding(14)
    }

    private var checkingContent: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Color.deltiqOrange)
            Text("settings.healthWrite.exportChecking", bundle: .module)
                .font(.callout)
                .foregroundStyle(Color.primary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func readyContent(_ preparation: WorkoutHealthExportService.Preparation) -> some View {
        let strengthCount = preparation.count(.strength)
        let cardioCount = preparation.count(.cardio)
        let selectedCount = (exportStrength ? strengthCount : 0) + (exportCardio ? cardioCount : 0)
        let strengthToggleLabel = String(
            format: String(localized: "settings.healthWrite.previewStrengthToggle", bundle: .module),
            strengthCount
        )
        let cardioToggleLabel = String(
            format: String(localized: "settings.healthWrite.previewCardioToggle", bundle: .module),
            cardioCount
        )

        DeltiqControlRow(
            icon: "dumbbell",
            label: strengthToggleLabel
        ) {
            Toggle(isOn: $exportStrength) { EmptyView() }
                .tint(Color.deltiqOrange)
                .accessibilityLabel(Text(strengthToggleLabel))
        }
        DeltiqControlRow(
            icon: "figure.run",
            label: cardioToggleLabel,
            showsDivider: false
        ) {
            Toggle(isOn: $exportCardio) { EmptyView() }
                .tint(Color.deltiqOrange)
                .accessibilityLabel(Text(cardioToggleLabel))
        }
        if exportCardio && preparation.exportsDistance && distanceDenied {
            hintRow(String(localized: "settings.healthWrite.distanceMissing", bundle: .module))
        }

        VStack(alignment: .leading, spacing: 4) {
            Text(String(
                format: String(localized: "settings.healthWrite.previewAlready", bundle: .module),
                preparation.alreadyInHealth.count
            ))
            if preparation.notExportable > 0 {
                Text(String(
                    format: String(localized: "settings.healthWrite.previewNotExportable", bundle: .module),
                    preparation.notExportable
                ))
            }
            Text(String(
                format: String(localized: "settings.healthWrite.previewVisible", bundle: .module),
                preparation.visibleWorkouts,
                preparation.visibleOwnWorkouts
            ))
        }
        .font(.caption)
        .foregroundStyle(Color.Deltiq.textSecondary)
        .padding(.horizontal, 14)
        .padding(.top, 8)

        hintRow(String(localized: "settings.healthWrite.previewBlindWarning", bundle: .module))

        if selectedCount > 0 {
            Button {
                showConfirm = true
            } label: {
                Label {
                    Text(pluralized("settings.healthWrite.exportStart", count: selectedCount))
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .buttonStyle(.plain)
            .deltiqButtonStyle()
            .padding(14)
        } else {
            bodyText(String(localized: "settings.healthWrite.previewNothing", bundle: .module))
        }
    }

    private func exportingContent(done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("settings.healthWrite.exporting", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(Color.primary)
                Spacer()
                Text("\(done) / \(total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            if total > 0 {
                ProgressView(value: Double(done), total: Double(total))
                    .tint(Color.deltiqOrange)
                    .accessibilityValue(Text("\(done) / \(total)"))
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Color.deltiqOrange)
            }
            Text("settings.healthWrite.exportingHint", bundle: .module)
                .font(.caption)
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                exportTask?.cancel()
            } label: {
                Text("common.cancel", bundle: .module)
            }
            .buttonStyle(.plain)
            .deltiqSecondaryButtonStyle()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func finishedContent(_ outcome: WorkoutHealthExportService.Outcome) -> some View {
        let handled = outcome.written + outcome.alreadyInHealth + outcome.notExportable
            + outcome.failed + outcome.unverified
        VStack(alignment: .leading, spacing: 8) {
            if handled == 0 && !outcome.wasCancelled && outcome.stopReason == nil {
                Text("settings.healthWrite.previewNothing", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(Color.primary)
            }
            if outcome.written > 0 {
                resultLine("settings.healthWrite.resultWritten", outcome.written,
                           Color.Deltiq.success, "checkmark.circle.fill")
            }
            if outcome.alreadyInHealth > 0 {
                resultLine("settings.healthWrite.resultAlready", outcome.alreadyInHealth,
                           Color.Deltiq.textSecondary, "minus.circle.fill")
            }
            if outcome.notExportable > 0 {
                resultLine("settings.healthWrite.resultNotExportable", outcome.notExportable,
                           Color.Deltiq.textSecondary, "minus.circle.fill")
            }
            if outcome.unverified > 0 {
                resultLine("settings.healthWrite.resultUnverified", outcome.unverified,
                           Color.Deltiq.textSecondary, "questionmark.circle.fill")
            }
            if outcome.failed > 0 {
                resultLine("settings.healthWrite.resultFailed", outcome.failed,
                           Color.Deltiq.error, "exclamationmark.triangle.fill")
            }
            if outcome.withoutDistance > 0 {
                Text(String(
                    format: String(localized: "settings.healthWrite.resultWithoutDistance", bundle: .module),
                    outcome.withoutDistance
                ))
                .font(.caption)
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            if outcome.wasCancelled {
                Text(String(
                    format: String(localized: "settings.healthWrite.resultCancelled", bundle: .module),
                    outcome.processed,
                    outcome.total
                ))
                .font(.callout)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            }
            if let reason = outcome.stopReason {
                Text(stopText(reason))
                    .font(.callout)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)

        Button {
            exportPhase = .idle
        } label: {
            Text("settings.healthWrite.resultDone", bundle: .module)
        }
        .buttonStyle(.plain)
        .deltiqSecondaryButtonStyle()
        .padding(14)
    }

    private func stopText(_ reason: WorkoutHealthExportService.StopReason) -> String {
        switch reason {
        case .notAuthorized:
            return String(localized: "settings.healthWrite.stopNotAuthorized", bundle: .module)
        case .deviceLocked:
            return String(localized: "settings.healthWrite.stopDeviceLocked", bundle: .module)
        case .tooManyFailures:
            return String(localized: "settings.healthWrite.stopTooManyFailures", bundle: .module)
        }
    }

    @ViewBuilder
    private func failedContent(_ failure: ExportFailure) -> some View {
        errorBanner(failureText(failure))
            .padding(14)
        Button {
            exportPhase = .idle
        } label: {
            Text("settings.healthWrite.exportRetry", bundle: .module)
        }
        .buttonStyle(.plain)
        .deltiqSecondaryButtonStyle()
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private func failureText(_ failure: ExportFailure) -> String {
        switch failure {
        case .deviceLocked:
            return String(localized: "settings.healthWrite.errorLocked", bundle: .module)
        case .generic:
            return String(localized: "settings.healthWrite.errorGeneric", bundle: .module)
        case .storeFallback:
            return String(localized: "settings.healthWrite.errorStoreFallback", bundle: .module)
        }
    }

    // MARK: - Export-Ablauf

    /// Phase 1: Lese-Freigabe fuer den Abgleich anfragen (Sheet nur, falls noch
    /// unentschieden), dann planen und mit Health abgleichen. Schreibt nichts.
    private func startCheck() {
        if case .fellBackAfterGroupStoreFailure = SharedStore.health {
            exportPhase = .failed(.storeFallback)
            return
        }
        exportPhase = .checking
        exportTask = Task { @MainActor in
            await healthKit.requestWorkoutReadAuthorization()
            do {
                let preparation = try await WorkoutHealthExportService.prepare(
                    healthKit: healthKit,
                    context: modelContext
                )
                // In den Hintergrund gewechselt oder den Bildschirm verlassen,
                // waehrend geprueft wurde: kein veraltetes Ergebnis anzeigen.
                if Task.isCancelled {
                    exportPhase = .idle
                    exportTask = nil
                    return
                }
                exportStrength = strengthEnabled
                exportCardio = cardioEnabled
                if preparation.toWrite.isEmpty {
                    // Nichts zu schreiben: schon in Health erkannte Trainings
                    // nur noch als behandelt markieren.
                    let outcome = await WorkoutHealthExportService.execute(
                        preparation,
                        categories: [],
                        healthKit: healthKit,
                        context: modelContext,
                        progress: { _, _ in }
                    )
                    exportPhase = .finished(outcome)
                } else {
                    exportPhase = .ready(preparation)
                }
            } catch let error as HealthKitError {
                if case .databaseInaccessible = error {
                    exportPhase = .failed(.deviceLocked)
                } else {
                    exportPhase = .failed(.generic)
                }
            } catch {
                exportPhase = .failed(.generic)
            }
            exportTask = nil
        }
    }

    /// Phase 2: die gewaehlten Kategorien schreiben.
    private func startExport() {
        guard case .ready(let preparation) = exportPhase else { return }
        var categories: Set<HealthWorkoutCategory> = []
        if exportStrength { categories.insert(.strength) }
        if exportCardio { categories.insert(.cardio) }
        let total = preparation.toWrite.filter { categories.contains($0.plan.category) }.count
        // Laeufe/Spaziergaenge mit km im Export? Dann vor dem Schreiben die
        // Distanz-Freigabe anfragen (nur, wenn sie noch unentschieden ist): ein
        // spaeter nachgeholtes Distanz-Sample waere nicht mehr moeglich, weil
        // die Trainings danach als behandelt gelten.
        let needsDistance = preparation.toWrite.contains {
            categories.contains($0.plan.category) && $0.plan.distanceKm != nil
        }

        exportPhase = .exporting(done: 0, total: total)
        setIdleTimer(disabled: true)
        exportTask = Task { @MainActor in
            if needsDistance && distanceUndecided {
                await healthKit.requestWorkoutWriteAuthorization(includeDistance: true)
            }
            let outcome = await WorkoutHealthExportService.execute(
                preparation,
                categories: categories,
                healthKit: healthKit,
                context: modelContext,
                progress: { done, total in
                    exportPhase = .exporting(done: done, total: total)
                }
            )
            exportPhase = .finished(outcome)
            exportTask = nil
            setIdleTimer(disabled: false)
        }
    }

    /// In den Hintergrund (Sperre, App-Wechsel): den Export beenden; das
    /// laufende Training wird noch fertig geschrieben, der Rest folgt beim
    /// naechsten Lauf. Eine offene Vorschau wird verworfen — sie haelt den
    /// Abgleich mit Health von VOR dem Wechsel (z.B. vor einer Leseerlaubnis in
    /// der Health-App) und muss neu geprueft werden. Bei Rueckkehr den Status
    /// auffrischen (z.B. nach Aenderungen in der Health-App).
    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if exportTask == nil {
                Task { await healthKit.refreshAuthorizationStatus() }
            }
        case .background:
            exportTask?.cancel()
            discardPreview()
        default:
            break
        }
    }

    /// Verwirft eine noch nicht bestaetigte Vorschau (Zurueck auf "Pruefen").
    private func discardPreview() {
        if case .ready = exportPhase {
            exportPhase = .idle
            showConfirm = false
        }
    }

    private func setIdleTimer(disabled: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }

    // MARK: - Bausteine

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(Color.Deltiq.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
    }

    /// Muster wie `SettingsView.hintRow`: Inline-Caption am Fuss einer Zeile.
    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    private func resultLine(_ labelKey: String.LocalizationValue, _ count: Int, _ color: Color, _ icon: String) -> some View {
        HStack {
            Label {
                Text(String(localized: labelKey, bundle: .module))
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
            .font(.callout)
            Spacer()
            Text(String(count)).font(.callout.bold()).foregroundStyle(Color.primary)
        }
    }

    private func errorBanner(_ message: String) -> some View {
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

    /// Manuelles `.one`/`.other` wie in den anderen Views (siehe
    /// `PlansListView.pluralizedCount`); das Basis-Key-Literal steht an der
    /// Aufrufstelle im Code.
    private func pluralized(_ baseKey: String, count: Int) -> String {
        let suffix = count == 1 ? "one" : "other"
        let key = String.LocalizationValue(stringLiteral: "\(baseKey).\(suffix)")
        let raw = String(localized: key, bundle: .module)
        return raw.replacingOccurrences(of: "%lld", with: "\(count)")
    }
}
#endif
