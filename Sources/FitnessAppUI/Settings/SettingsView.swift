#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth
import FitnessAppActivities
#if canImport(UIKit)
import UIKit
#endif

/// Settings hub / "Mehr"-Tab. Settings-Epic Phase 3 (docs/SETTINGS_UX_AUDIT.md,
/// Teil 3): gruppierte Navigation statt flacher Sections — jede Gruppe ihre
/// eigene Seite (`SettingsAppExperienceView`/`SettingsLibraryEquipmentView`/
/// `SettingsDataConnectionsView`/`SettingsHelpInfoView`), reine Verschiebung
/// bestehender Inhalte — dieselben `NavigationLink`+`DeltiqRow`-Konventionen
/// wie ueberall sonst, MIT EINER Ausnahme: main-navigation Plan, 2026-10-22,
/// Task 3 (Fix-Runde 1) macht die "Werkzeuge"-Zeile wertbasiert
/// (`NavigationLink(value: CalculatorsRoute.calculators)` statt eines
/// plain `NavigationLink { ... }`) — sie muss per Deep-Link aus der
/// Wasser-Erinnerung direkt bis zum WaterTracker durchgeschaltet werden
/// koennen, die anderen 4 Gruppen-Zeilen brauchen das nicht und bleiben
/// view-basiert.
///
/// UI-Ticket ("Mehr-Informationsarchitektur", 2026-10-24): die 5 Gruppen
/// waren vorher EINER gemeinsamen `DeltiqSection` mit dem Titel
/// "Weitere Einstellungen" untergeordnet — fachlich falsch fuer Werkzeuge
/// (eigenstaendige Rechner) und Bibliothek & Ausruestung (Trainingsinhalt,
/// Uebungsbibliothek), beides keine App-Einstellungen. `groupNavigationSection`
/// baut die 5 Gruppen jetzt als FUENF EIGENSTAENDIGE `DeltiqSection`s ohne
/// gemeinsame Sammelueberschrift - jede mit ihrem eigenen, klaren Namen.
/// Reihenfolge: Werkzeuge, Bibliothek & Ausruestung, App-Einstellungen
/// (umbenannt von "App & Trainingserlebnis" - deckt exakt "Konfiguration des
/// App-Verhaltens" ab, siehe `SettingsAppExperienceView`), Daten &
/// Verbindungen, Hilfe & Informationen. "Profil & Ziele" bleibt wie zuvor nur
/// EIN Eintrag (der Profil-Editor, der auch Koerperdaten + Trainingsort/
/// Ausstattung als eigene Unterseiten traegt) und damit ein direkter Link
/// statt einer eigenen Gruppen-Seite. "App zuruecksetzen" bleibt bewusst auf
/// dieser obersten Seite, ganz unten, separat von allen Gruppen (Vorgabe:
/// gefaehrliche Aktion nicht in einer Gruppen-Unterseite verstecken).
@available(iOS 17.0, macOS 14.0, *)
public struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation
    /// Settings-Epic Phase 5 (Teil 6, Live-Activities bei Reset): dieselbe
    /// Instanz, die `RootView` injiziert (`.environment(restTimerActivity)`)
    /// — `SettingsView` sitzt im selben `MainTabView`-Teilbaum.
    @Environment(RestTimerActivityController.self) private var restTimerActivity

    @Query private var profiles: [UserBodyProfile]

    /// DEL-134: Globaler Reset-Gate-Flag. Wird in `resetApp()` auf true
    /// gesetzt vor der SwiftData-Deletion, RootView checkt ihn und
    /// rendert eine sichere ProgressView statt MainTabView. Ohne den
    /// Flag kann jede View, die @Query auf gleich-zu-loeschende Objekte
    /// hat, mid-render crashen.
    @AppStorage("isResetting") private var isResetting: Bool = false

    /// Nur noch fuer die Profil-Zusammenfassung (Groesse/Gewicht-Einheit)
    /// gebraucht — der editierbare Picker lebt in `SettingsAppExperienceView`.
    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    @State private var showingResetConfirm = false
    @State private var resetErrorMessage: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "settings.title", bundle: .module)
            )

            ScrollView {
                VStack(spacing: 18) {
                    profileSection
                    groupNavigationSection
                    dangerZoneSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .alert(
            Text("settings.reset.errorTitle", bundle: .module),
            isPresented: Binding(
                get: { resetErrorMessage != nil },
                set: { if !$0 { resetErrorMessage = nil } }
            )
        ) {
            Button("OK") { resetErrorMessage = nil }
        } message: {
            Text(resetErrorMessage ?? "")
        }
        .confirmationDialog(
            Text("settings.confirm.reset.title", bundle: .module),
            isPresented: $showingResetConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                Task { await resetApp() }
            } label: {
                Text("settings.confirm.reset.action", bundle: .module)
            }
            Button(role: .cancel) {} label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            Text("settings.confirm.reset.message", bundle: .module)
        }
    }

    // MARK: Sections

    private var profileSection: some View {
        DeltiqSection(String(localized: "settings.section.profile_goals", bundle: .module).uppercased()) {
            profileSectionContent
        }
    }

    @ViewBuilder
    private var profileSectionContent: some View {
        if let profile = profiles.first {
            NavigationLink {
                ProfileEditorView(profile: profile)
            } label: {
                DeltiqRow(
                    icon: "person.crop.circle",
                    label: profileHeadline(profile),
                    subtitle: profileSubtitle(profile),
                    showsChevron: true,
                    showsDivider: false
                )
            }
        } else {
            DeltiqRow(
                label: String(localized: "settings.profile.missing", bundle: .module),
                showsDivider: false
            )
        }
    }

    private func profileHeadline(_ profile: UserBodyProfile) -> String {
        let sex = String(localized: profile.profile == .male ? "sex.male" : "sex.female", bundle: .module)
        let years = String(format: String(localized: "settings.profile.years", bundle: .module), profile.ageYears)
        return "\(sex) • \(years)"
    }

    private func profileSubtitle(_ profile: UserBodyProfile) -> String {
        var parts = [formattedHeight(profile.heightCm)]
        if let goal = profile.goalWeightKg {
            parts.append(String(format: String(localized: "settings.profile.goal", bundle: .module), formattedWeight(goal)))
        }
        parts.append(environmentLabel(profile.environment))
        return parts.joined(separator: " • ")
    }

    /// UI-Ticket ("Mehr-Informationsarchitektur"): die 5 Gruppen-Seiten (siehe
    /// Datei-Kommentar), jede jetzt eine EIGENE `DeltiqSection` statt einer
    /// Zeile unter der entfallenen Sammelueberschrift "Weitere Einstellungen"
    /// — jede Section traegt genau eine Zeile, deshalb `showsDivider: false`
    /// bei allen (keine Trennlinie VOR dem eigenen Kartenrand noetig).
    /// Reihenfolge: Werkzeuge, Bibliothek & Ausruestung, App-Einstellungen,
    /// Daten & Verbindungen, Hilfe & Informationen.
    private var groupNavigationSection: some View {
        Group {
            toolsSection
            libraryEquipmentSection
            appExperienceSection
            dataConnectionsSection
            helpInfoSection
        }
    }

    // main-navigation Plan, 2026-10-22, Task 3, Fix-Runde 1: CalculatorsView
    // zieht vom entfallenen Werkzeuge-Tab eine Ebene tief unter "Mehr" ein.
    // Anders als die anderen 4 Gruppen hier wertbasiert (`NavigationLink(value:)`
    // + `CalculatorsRoute`/`navigationDestination(for:)`, registriert in
    // RootView) statt view-basiert — dieselbe Route-Maschinerie, die der
    // Wassertracker-Deep-Link benutzt. Damit landet jeder Zustand auf diesem
    // Teilpfad zuverlaessig in `toolsPath`, und ein Reset+Append des
    // Deep-Links trifft garantiert exakt den WaterTracker, egal wie der User
    // vorher manuell navigiert hat — kein Mix aus wert- und view-basierten
    // Pushes mehr zwischen SettingsView und WaterTrackerView.
    private var toolsSection: some View {
        DeltiqSection(String(localized: "settings.group.tools", bundle: .module).uppercased()) {
            NavigationLink(value: CalculatorsRoute.calculators) {
                DeltiqRow(
                    icon: "wrench.and.screwdriver",
                    label: String(localized: "settings.group.tools", bundle: .module),
                    showsChevron: true,
                    showsDivider: false
                )
            }
        }
    }

    private var libraryEquipmentSection: some View {
        DeltiqSection(String(localized: "settings.group.libraryEquipment", bundle: .module).uppercased()) {
            NavigationLink {
                SettingsLibraryEquipmentView()
            } label: {
                DeltiqRow(
                    icon: "figure.strengthtraining.traditional",
                    label: String(localized: "settings.group.libraryEquipment", bundle: .module),
                    showsChevron: true,
                    showsDivider: false
                )
            }
        }
    }

    private var appExperienceSection: some View {
        DeltiqSection(String(localized: "settings.group.appExperience", bundle: .module).uppercased()) {
            NavigationLink {
                SettingsAppExperienceView()
            } label: {
                DeltiqRow(
                    icon: "slider.horizontal.3",
                    label: String(localized: "settings.group.appExperience", bundle: .module),
                    showsChevron: true,
                    showsDivider: false
                )
            }
        }
    }

    private var dataConnectionsSection: some View {
        DeltiqSection(String(localized: "settings.group.dataConnections", bundle: .module).uppercased()) {
            NavigationLink {
                SettingsDataConnectionsView()
            } label: {
                DeltiqRow(
                    icon: "icloud",
                    label: String(localized: "settings.group.dataConnections", bundle: .module),
                    showsChevron: true,
                    showsDivider: false
                )
            }
        }
    }

    private var helpInfoSection: some View {
        DeltiqSection(String(localized: "settings.group.helpInfo", bundle: .module).uppercased()) {
            NavigationLink {
                SettingsHelpInfoView()
            } label: {
                DeltiqRow(
                    icon: "questionmark.circle",
                    label: String(localized: "settings.group.helpInfo", bundle: .module),
                    showsChevron: true,
                    showsDivider: false
                )
            }
        }
    }

    /// Abschnitt 1.6: Hinweistext unter einer Zeile, wie es bereits
    /// `DeltiqFormSection`s Footer-Slot vorsah — nur jetzt IN der Karte
    /// als letzte Zeile statt darunter. 12pt, sekundaerer Text, keine
    /// Trennlinie darueber.
    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    private var dangerZoneSection: some View {
        DeltiqSection(String(localized: "settings.section.danger_zone", bundle: .module).uppercased()) {
            Button(role: .destructive) {
                showingResetConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Label {
                        Text("settings.action.reset", bundle: .module)
                    } icon: {
                        Image(systemName: "trash")
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Color.Deltiq.error)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            hintRow(String(localized: "settings.dangerZone.footer", bundle: .module))
        }
    }

    // MARK: Reset

    /// Wipes all SwiftData entities and our `@AppStorage` keys, then resets navigation
    /// so the app re-renders into Onboarding. Apple-Health-Daten bleiben unangetastet
    /// (sind Eigentum des Users in einer separaten Datenbank).
    ///
    /// **Settings-Epic Phase 5 (Befund RS-02):** vor jeder destruktiven
    /// Loeschung steht jetzt eine automatische Vorab-Sicherung — wie beim
    /// Replace-Import (`BackupListView.restore`/`DataImportView.runImport`,
    /// Grund `.preImport`, hier `.preReset`). Schlaegt sie fehl, wird NICHT
    /// trotzdem geloescht: `resetApp` kehrt dann VOR `isResetting = true` und
    /// vor jeder Mutation zurueck, zeigt stattdessen den Fehler. Die neue
    /// Generation landet in `Documents/Backups` — einem von der SwiftData-
    /// Loeschung voellig unabhaengigen Verzeichnis, kann vom nachfolgenden
    /// Reset also nicht mitgeloescht werden.
    ///
    /// **Crash-safe Reset-Pattern** (v0.1.17 DEL-017-Fix): Wir leeren ERST
    /// `navigation.workoutPath` und schicken den Tab auf Dashboard — das raeumt
    /// jede `@Bindable`-Referenz auf gleich zu loeschende Models aus dem
    /// SwiftUI-View-Tree. ERST DANACH stossen wir die Loeschungen via
    /// `DispatchQueue.main.async` an. Synchrones Delete + Save HIER wuerde
    /// SwiftUI mid-render mit halb-leerem Model-Graph konfrontieren und einen
    /// EXC_BREAKPOINT-Crash ausloesen, weil @Bindable/@Query-Subscriber auf
    /// gerade geloeschte UserBodyProfile-Refs zugreifen. Dieser Teil bleibt
    /// bewusst unveraendert (GCD, nicht Swift Concurrency) — er loest ein
    /// spezifisches Render-Timing-Problem, kein generisches Threading-Problem.
    ///
    /// **Per-instance statt batch-delete** (v0.1.13 DEL-006-Fix): SwiftData's
    /// bulk `delete(model:)` baut intern ein NSBatchDeleteRequest und umgeht
    /// die @Relationship-Cascade/Nullify-Regeln → "mandatory OTO nullify
    /// inverse"-Violations. Fetch + delete-each respektiert die Regeln.
    ///
    /// **Settings-Epic Phase 5 (Befund RS-03a):** die 10 Typen, deren
    /// Loeschumfang mit dem destruktiven Replace-Import identisch ist, kommen
    /// jetzt aus der gemeinsamen `UserDataWipe.deleteSharedUserData` (Core).
    /// `ExerciseTemplate` bleibt bewusst SEPARAT: Reset loescht ALLE Templates
    /// (System eingeschlossen) und reseedet sie danach, ein Replace-Import
    /// loescht nur Custom-Templates und laesst die System-Library unberuehrt
    /// — zwei tatsaechlich unterschiedliche Umfaenge, die nicht in eine
    /// gemeinsame Funktion gezwungen werden.
    ///
    /// Neue `@Model`-Typen MUESSEN nach `UserDataWipe` (falls der Reset-Umfang
    /// mit dem Replace-Import uebereinstimmt) oder hier direkt (falls nicht) —
    /// sonst "Geist"-Daten nach dem vermeintlichen Reset.
    private func resetApp() async {
        do {
            _ = try await BackupService.createBackupAsync(context: modelContext, reason: .preReset)
        } catch {
            resetErrorMessage = String(
                format: String(localized: "settings.reset.backupFailed", bundle: .module),
                error.localizedDescription
            )
            return
        }

        // DEL-134: isResetting-Gate. Vorher konnten Views, die zwischen
        // dem Navigation-Reset und dem async-deferred Delete neu rendern,
        // auf SwiftData-Objekte zugreifen, die im naechsten Frame
        // verschwinden — Crash mit "Object was deleted from context"
        // / Dangling-Pointer. Der AppStorage-Flag wird VOR der Deletion
        // gesetzt; RootView checkt ihn und rendert eine ProgressView
        // statt MainTabView, sodass keine Views mehr @Query-Resultate
        // beruehren.
        isResetting = true

        // Ein laufender Zeitformat-Lauf (stilles Hintergrund-Audio + Live Activity)
        // hat danach keinen Player mehr, der ihn beendete - nach einem Tab-Wechsel
        // kam bei dessen Abbau auch kein `onDisappear` mehr. Hier explizit beenden.
        TimedWorkoutBackground.shared.endAll()
        // Settings-Epic Phase 5 (Teil 6): derselbe Fall fuer den Pausen-Timer
        // (Live Activity pro Satz, unabhaengig vom Zeitformat-Lauf oben) —
        // vorher ueberlebte eine laufende Pause-Activity den Reset.
        restTimerActivity.endRestTimer(reason: .skipped)

        // 1) Navigation-State sofort zuruecksetzen — entfernt @Bindable-
        //    References auf gleich-zu-loeschende UserBodyProfile/Plan/Day.
        // Bugfix (Audit): `toolsPath` fehlte hier - ohne Reset konnte die
        // "Werkzeuge"-Unterseite (main-navigation Plan, 2026-10-22, Task 3:
        // gehoert jetzt der Mehr/Settings-Tab-eigenen NavigationStack, kein
        // eigener Tab mehr) nach einem Reset in einer veralteten Detail-
        // Ansicht (z.B. Wassertracker) statt der Uebersicht landen, weil
        // `AppNavigation` als langlebiges @State den Onboarding<->Main-Swap
        // ueberlebt.
        navigation.workoutPath = NavigationPath()
        navigation.toolsPath = NavigationPath()
        navigation.selectedTab = .dashboard

        // 2) AppStorage-Keys sofort wegwerfen (synchron OK, kein Model).
        //    DEL-219: `deload_until` und `lastDataExportAt` kommen dazu. Beide
        //    beschreiben DATEN-Zustand, nicht Praeferenzen — nach einem Wipe
        //    behaupten sie etwas, das es nicht mehr gibt: eine laufende
        //    Deload-Woche (Banner auf einem frischen Account) bzw. ein
        //    Backup, das nie existierte (unterdrueckt den Backup-Hinweis des
        //    Coaches). Echte Praeferenzen (Erscheinungsbild, Coaching-Ton,
        //    Erinnerungen, Chart-Zeitraeume) bleiben absichtlich stehen — der
        //    User loescht seine Daten, nicht seine Einstellungen.
        // DEL-239: Die beiden Absenz-Deload-Keys sind DATEN-Zustand (wann
        // wurde reduziert, bei welcher Luecke wurde abgelehnt) und gehoeren
        // damit hierher — nicht in die SettingsPortability-Whitelist. Nach
        // einem Wipe gibt es keine Trainings-Historie mehr, also auch keine
        // Absenz, auf die sie sich beziehen koennten.
        // Settings-Epic Phase 5 (Befund SV-F01): `weight_unit` NICHT mehr
        // hier — es ist laut `SettingsPortability`-Whitelist eine ECHTE
        // Praeferenz (genau wie Erscheinungsbild/Erinnerungen), widersprach
        // sich also mit dem eigenen Kommentar oben. Reset loescht Daten,
        // nicht Einstellungen.
        // Settings-Epic Phase 6 (Befund SV-F02): `height_unit`/`unit_system`
        // entfernt — tote Keys, werden im ganzen Repo nirgends sonst
        // gelesen oder geschrieben (verifiziert), reine Altlast.
        for key in ["deload_until", "lastDataExportAt",
                    AbsenceDeload.lastAppliedKey, AbsenceDeload.suppressedUntilGapKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 3) Die eigentlichen SwiftData-Loeschungen ans Ende des aktuellen
        //    Render-Cycles schicken. Erst wenn SwiftUI den Tab-Switch
        //    verarbeitet hat (und die alten Subscriber aufgeloest sind),
        //    fahren wir die Deletes durch und savnen — der RootView-@Query
        //    sieht dann das Empty-State und swappt sauber auf Onboarding.
        DispatchQueue.main.async {
            do {
                // Settings-Epic Phase 5 (Befund RS-03a): die 10 mit dem
                // Replace-Import identischen Typen kommen aus der
                // gemeinsamen Core-Funktion — Children-first ordering,
                // Per-instance-Delete respektiert @Relationship-Rules (siehe
                // Doc-Kommentar dort).
                try UserDataWipe.deleteSharedUserData(in: self.modelContext)
                // ExerciseTemplate bleibt reset-spezifisch: ALLE Templates
                // (System eingeschlossen) weg, danach Neu-Seed unten — ein
                // Replace-Import loescht stattdessen nur Custom-Templates
                // (siehe `DataImportService.wipeAllUserData`).
                try UserDataWipe.deleteEach(of: ExerciseTemplate.self, in: self.modelContext)
                try self.modelContext.save()
                // Die System-Uebungsbibliothek gehoert zum frischen Zustand:
                // RootView seedet sie nur beim App-START, ohne das blieben
                // Bibliothek und Uebungs-Picker bis zum naechsten Neustart
                // leer (auch im Onboarding direkt nach dem Reset). `try?`
                // mit Absicht: Das Zuruecksetzen selbst ist gelungen, und
                // scheitert nur das Speichern der Bibliothek, seedet
                // RootView.task sie beim naechsten Start nach.
                _ = LibrarySeeder.seedIfNeeded(in: self.modelContext)
                try? self.modelContext.save()
            } catch {
                self.resetErrorMessage = error.localizedDescription
            }
            // DEL-134: Release-Gate immer (Error-Pfad UND Success-Pfad).
            // RootView swappt dann automatisch zur OnboardingView (weil
            // profiles.isEmpty == true) oder zur ErrorView falls die
            // Error-Message gesetzt wurde.
            self.isResetting = false
        }
    }

    // MARK: Formatters

    /// Always reads cm from DB; converts to inches when the user prefers imperial.
    private func formattedHeight(_ cm: Double) -> String {
        if weightUnitRaw == "lbs" {
            let inches = cm / 2.54
            return "\(inches.truncated(to: 1).formattedTwoDecimals) in"
        }
        return "\(cm.truncated(to: 1).formattedTwoDecimals) cm"
    }

    private func formattedWeight(_ kg: Double) -> String {
        if weightUnitRaw == "lbs" {
            let lbs = WeightUnit.lbs.fromKg(kg)
            return "\(lbs.formattedWeightInput()) lbs"
        }
        return "\(kg.formattedWeightInput()) kg"
    }

    // DEL-118: route durch die zentrale .localizedName-Extension.
    private func environmentLabel(_ env: EnvironmentType) -> String {
        String(localized: env.localizedName)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Mit Profil") {
    NavigationStack {
        SettingsView()
            // Werkzeuge-Zeile ist jetzt wertbasiert (Fix-Runde 1) — ohne diese
            // Registrierung wuerde der Tap im Preview ins Leere laufen.
            .navigationDestination(for: CalculatorsRoute.self) { route in
                switch route {
                case .calculators:
                    CalculatorsView()
                case .waterTracker:
                    WaterTrackerView()
                }
            }
    }
    .modelContainer(PreviewSeed.dashboardContainer)
    .environment(AppNavigation())
    .environment(HealthKitController())
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Ohne Profil") {
    NavigationStack {
        SettingsView()
            .navigationDestination(for: CalculatorsRoute.self) { route in
                switch route {
                case .calculators:
                    CalculatorsView()
                case .waterTracker:
                    WaterTrackerView()
                }
            }
    }
    .modelContainer(PreviewSeed.emptyContainer)
    .environment(AppNavigation())
    .environment(HealthKitController())
}
#endif
#endif
