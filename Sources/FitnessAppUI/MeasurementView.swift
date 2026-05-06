#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth

/// Entry form for a new body measurement.
///
/// Reads the singleton `UserBodyProfile` from the SwiftData context (height, sex, age),
/// lets the user enter weight + circumferences, and shows ALL derived metrics
/// (BMI, Navy/Deurenberg KFA, FFM, FFMI, BMR) live as the user types. Saving inserts
/// a `BodyMeasurement` row with all derived fields populated via
/// `BodyMeasurement.makeDerived` — no double-bookkeeping between UI state and storage.
///
/// **Apple Health integration**: when authorized, the view auto-fills the weight from
/// the latest HealthKit body-mass sample on appear, and after saving writes weight +
/// body-fat % + lean body mass back to HealthKit. Auto-fill only fires when the user
/// hasn't typed a weight yet — never overrides manual entry.
@available(iOS 17.0, macOS 14.0, *)
public struct MeasurementView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitController.self) private var healthKit

    @Query private var profiles: [UserBodyProfile]

    @State private var weightKg: Double?
    @State private var neckCm:   Double?
    @State private var waistCm:  Double?
    @State private var hipCm:    Double?

    @State private var lastSavedAt: Date?
    /// Set to true once the auto-fill task ran for THIS view appearance. Prevents the
    /// task from clobbering user-typed values if the @Query updates while the view
    /// is on screen.
    @State private var didAttemptHealthKitAutofill = false
    /// True when the current `weightKg` value came from HealthKit (auto-fill or
    /// manual pull). Reset as soon as the user types — at that point the value
    /// is "theirs" again and the badge would be misleading.
    @State private var weightCameFromHealth = false
    /// Snapshot of the value we wrote into `weightKg` from HealthKit. Lets the
    /// `onChange` discriminate between "user typed" (new value differs from
    /// snapshot → drop the badge) and "we just programmatically set the field"
    /// (new value matches → keep the badge).
    @State private var lastHealthFilledWeight: Double?

    public init() {}

    public var body: some View {
        Form {
            if let profile = profiles.first {
                profileSection(profile)
                measurementsSection(forProfile: profile)
                healthKitSection
                derivedSection(forProfile: profile)
                actionsSection(forProfile: profile)
            } else {
                ContentUnavailableView(
                    "Kein Profil",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Lege erst dein Profil im Onboarding an, danach koennen wir Messwerte berechnen.")
                )
            }
        }
        .navigationTitle("Neue Messung")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            // Refresh status (covers permission changes via Settings while backgrounded).
            await healthKit.refreshAuthorizationStatus()
            await tryAutoFillFromHealthKit()
        }
    }

    // MARK: Sections

    private func profileSection(_ profile: UserBodyProfile) -> some View {
        Section("Profil (Single Source of Truth)") {
            LabeledContent("Groesse",
                value: profile.heightCm.formattedTwoDecimals + " cm")
            LabeledContent("Alter",
                value: "\(ageYears(for: profile)) Jahre")
            LabeledContent("Sex",
                value: profile.profile == .male ? "Maennlich" : "Weiblich")
            if let goal = profile.goalWeightKg {
                LabeledContent("Zielgewicht",
                    value: goal.formattedTwoDecimals + " kg")
            }
        }
    }

    private func measurementsSection(forProfile profile: UserBodyProfile) -> some View {
        Section("Messwerte") {
            decimalField("Gewicht (kg)", value: $weightKg)
                .onChange(of: weightKg) { _, newValue in
                    // Drop the "from Health" badge ONLY when the new value
                    // differs from what we programmatically wrote — otherwise
                    // we'd nuke the badge during the auto-fill itself.
                    if weightCameFromHealth, newValue != lastHealthFilledWeight {
                        weightCameFromHealth = false
                        lastHealthFilledWeight = nil
                    }
                }
            if weightCameFromHealth, weightKg != nil {
                Label("Aus Apple Health uebernommen", systemImage: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.pink)
                    .listRowSeparator(.hidden)
            }
            decimalField("Hals (cm)",    value: $neckCm)
            decimalField("Taille (cm)",  value: $waistCm)
            // Hip is REQUIRED for Navy KFA on female profiles. Keep it visible for males
            // anyway — Android stores it for general progress tracking even when unused.
            decimalField("Huefte (cm)" + (profile.profile == .female ? " *" : ""),
                         value: $hipCm)
            if profile.profile == .female {
                Text("* Huefte ist Pflicht fuer Navy KFA bei weiblichem Profil.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var healthKitSection: some View {
        Section {
            if !healthKit.isAvailable {
                Label("Apple Health auf diesem Geraet nicht verfuegbar.",
                      systemImage: "heart.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                switch healthKit.authorizationStatus {
                case .notDetermined:
                    Button {
                        Task { await healthKit.requestAuthorization() }
                    } label: {
                        Label("Apple Health verbinden", systemImage: "heart.fill")
                    }
                case .sharingAuthorized:
                    HStack {
                        Label("Verbunden", systemImage: "heart.fill")
                            .foregroundStyle(.pink)
                        Spacer()
                        if let lastSync = healthKit.lastSyncDate {
                            Text("Sync \(lastSync.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    Button {
                        Task { await pullLatestWeightFromHealth() }
                    } label: {
                        Label("Aktuelles Gewicht aus Apple Health", systemImage: "arrow.down.circle")
                    }
                case .sharingDenied:
                    Label("Apple Health blockiert. Aendere die Berechtigung in den iOS-Einstellungen.",
                          systemImage: "heart.slash")
                        .font(.caption)
                        .foregroundStyle(.orange)
                case .unavailable:
                    Label("Apple Health nicht verfuegbar.",
                          systemImage: "heart.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Apple Health")
        } footer: {
            if healthKit.authorizationStatus == .sharingAuthorized {
                Text("Bei Verbindung wird das aktuellste Waagen-Gewicht beim Oeffnen vorausgefuellt. Beim Speichern werden Gewicht, KFA und FFM zurueck nach Apple Health geschrieben.")
                    .font(.footnote)
            }
        }
    }

    private func derivedSection(forProfile profile: UserBodyProfile) -> some View {
        Section("Live-Auswertung") {
            if let derived = derivedMetrics(for: profile) {
                metricRow("BMI", value: derived.bmi)
                navyRow(derived.navyBodyFatPct, profileSex: profile.profile)
                metricRow("KFA Deurenberg", value: derived.deurenbergBodyFatPct, suffix: " %")
                metricRow("Fettfreie Masse", value: derived.fatFreeMassKg, suffix: " kg")
                metricRow("FFMI", value: derived.ffmi)
                metricRow("Norm. FFMI", value: derived.normalizedFfmi)
                metricRow("BMR", value: derived.bmr, suffix: " kcal")
            } else {
                Text("Trage Gewicht ein, um die Auswertung zu sehen.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func actionsSection(forProfile profile: UserBodyProfile) -> some View {
        Section {
            Button {
                save(profile: profile)
            } label: {
                Label("Messung speichern", systemImage: "tray.and.arrow.down")
            }
            .disabled(!canSave)

            if let lastSavedAt {
                Text("Zuletzt gespeichert: \(lastSavedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Row helpers

    /// Displays a single derived metric. ALWAYS truncates to 2 decimals before
    /// formatting — that's the app-wide invariant (no cosmetic round-up).
    private func metricRow(_ label: String, value: Double, suffix: String = "") -> some View {
        LabeledContent(label, value: value.truncated(to: 2).formattedTwoDecimals + suffix)
    }

    private func navyRow(_ navy: Double?, profileSex: BodyFormulaProfile) -> some View {
        HStack {
            Text("KFA Navy")
            Spacer()
            if let navy {
                Text(navy.truncated(to: 2).formattedTwoDecimals + " %")
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
            } else {
                Text(profileSex == .female
                     ? "Hals/Taille/Huefte erforderlich"
                     : "Hals/Taille erforderlich")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func decimalField(_ label: String, value: Binding<Double?>) -> some View {
        TextField(label, value: value, format: .number, prompt: Text(label))
            .decimalKeyboard()
    }

    // MARK: Domain glue

    private func ageYears(for profile: UserBodyProfile) -> Int {
        Calendar.current.dateComponents([.year], from: profile.birthDate, to: Date()).year ?? 0
    }

    /// Calls into FitnessAppCore's pure formulas. Returns nil while inputs are still
    /// incomplete (no weight, or zero height — which would also break BMI).
    private func derivedMetrics(for profile: UserBodyProfile) -> DerivedBodyMetrics? {
        guard let weightKg, weightKg > 0, profile.heightCm > 0 else { return nil }
        return BodyCalculations.computeDerivedFields(
            weightKg: weightKg,
            heightCm: profile.heightCm,
            ageYears: ageYears(for: profile),
            profile: profile.profile,
            neckCm: neckCm,
            waistCm: waistCm,
            hipCm: hipCm
        )
    }

    private var canSave: Bool {
        guard let weightKg, weightKg > 0 else { return false }
        return profiles.first != nil
    }

    private func save(profile: UserBodyProfile) {
        guard let weightKg else { return }
        let measurement = BodyMeasurement.makeDerived(
            ageYears: ageYears(for: profile),
            weightKg: weightKg,
            heightCm: profile.heightCm,
            profile: profile.profile,
            neckCm: neckCm,
            waistCm: waistCm,
            hipCm: hipCm
        )
        modelContext.insert(measurement)
        lastSavedAt = measurement.date

        // Best-effort Apple Health sync. No UI feedback on failure here — the next
        // open of this screen surfaces it via `healthKit.lastError` if needed.
        // Body-fat preference: prefer the user-selected value (e.g., navy when valid),
        // fall back to deurenberg so HealthKit never gets a Navy-failed nil.
        let bodyFatPct = measurement.selectedBodyFatPct
            ?? measurement.navyBodyFatPct
            ?? measurement.deurenbergBodyFatPct
        Task { @MainActor in
            await healthKit.saveMeasurement(
                weightKg: measurement.weightKg,
                bodyFatPct: bodyFatPct,
                fatFreeMassKg: measurement.fatFreeMassKg,
                date: measurement.date
            )
        }

        // Reset entry fields — keep height/age (they belong to the profile, not the form).
        self.weightKg = nil
        self.neckCm   = nil
        self.waistCm  = nil
        self.hipCm    = nil
    }

    // MARK: HealthKit auto-fill

    /// Pulls the latest weight from HealthKit and pre-fills the form field — but
    /// ONLY if the user hasn't typed anything yet. Skips silently when permissions
    /// aren't granted or HealthKit is unavailable.
    private func tryAutoFillFromHealthKit() async {
        guard !didAttemptHealthKitAutofill else { return }
        didAttemptHealthKitAutofill = true

        guard healthKit.authorizationStatus == .sharingAuthorized,
              weightKg == nil,
              let kg = await healthKit.latestWeightKg()
        else { return }

        // Re-check user input now that the await may have introduced a typing window.
        if weightKg == nil {
            // Set the snapshot BEFORE the binding so onChange's comparison
            // sees the matching value and doesn't drop the badge.
            lastHealthFilledWeight = kg
            weightCameFromHealth = true
            weightKg = kg
        }
    }

    /// Manual override pull — overwrites whatever the user typed. Triggered from the
    /// "Aktuelles Gewicht aus Apple Health"-button, so the overwrite is intentional.
    private func pullLatestWeightFromHealth() async {
        guard let kg = await healthKit.latestWeightKg() else { return }
        lastHealthFilledWeight = kg
        weightCameFromHealth = true
        weightKg = kg
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Maennliches Profil") {
    NavigationStack {
        MeasurementView()
    }
    .modelContainer(PreviewSeed.maleProfileContainer)
    .environment(HealthKitController())
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Weibliches Profil") {
    NavigationStack {
        MeasurementView()
    }
    .modelContainer(PreviewSeed.femaleProfileContainer)
    .environment(HealthKitController())
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Kein Profil (Empty State)") {
    NavigationStack {
        MeasurementView()
    }
    .modelContainer(PreviewSeed.emptyContainer)
    .environment(HealthKitController())
}
#endif
#endif
