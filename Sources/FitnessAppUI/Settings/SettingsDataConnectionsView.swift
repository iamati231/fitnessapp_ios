#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth
#if canImport(UIKit)
import UIKit
#endif

/// Settings-Epic Phase 3 (docs/SETTINGS_UX_AUDIT.md, Teil 3): Gruppe
/// "Daten & Verbindungen" — Apple Health (Status/Verbinden/Sync/Import/
/// Schreiben) und Datenportabilität (Export/Backups/Import). Reine
/// Verschiebung aus `SettingsView.swift` — Logik, `@AppStorage`-Keys und
/// Verhalten unveraendert; "App zuruecksetzen" bleibt bewusst auf der
/// obersten Settings-Seite, nicht hier (siehe `SettingsView.dangerZoneSection`).
@available(iOS 17.0, macOS 14.0, *)
public struct SettingsDataConnectionsView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitController.self) private var healthKit

    @AppStorage("pref_healthkit_workout_import") private var externalWorkoutImportEnabled: Bool = false
    @AppStorage(HealthWritePreferences.strengthEnabledKey)
    private var healthWriteStrengthEnabled: Bool = HealthWritePreferences.defaultStrengthEnabled
    @AppStorage(HealthWritePreferences.cardioEnabledKey)
    private var healthWriteCardioEnabled: Bool = HealthWritePreferences.defaultCardioEnabled

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "settings.group.dataConnections", bundle: .module),
                onBack: { dismiss() }
            )
            ScrollView {
                VStack(spacing: 18) {
                    healthKitSection
                    privacySection
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
        .deltiqSwipeBackEnabled()
    }

    // MARK: Sections

    private var healthKitSection: some View {
        DeltiqSection(String(localized: "profile.section.health", bundle: .module).uppercased()) {
            healthKitStatusRow
            if healthKit.authorizationStatus == .sharingDenied {
                openHealthAppButton
            }
            if let lastSync = healthKit.lastSyncDate {
                DeltiqControlRow(
                    label: String(localized: "settings.health.lastSync", bundle: .module)
                ) {
                    Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
            DeltiqControlRow(
                icon: "figure.run.circle",
                label: String(localized: "settings.health.workoutImport", bundle: .module),
                showsDivider: healthKit.isAvailable
            ) {
                Toggle(isOn: $externalWorkoutImportEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .disabled(!healthKit.isAvailable)
                    .onChange(of: externalWorkoutImportEnabled) { _, enabled in
                        guard enabled else { return }
                        Task {
                            await healthKit.requestWorkoutReadAuthorization()
                            await ExternalWorkoutImportService.syncExternalWorkouts(
                                healthKit: healthKit,
                                context: modelContext
                            )
                        }
                    }
            }
            if healthKit.isAvailable {
                NavigationLink {
                    HealthWorkoutWriteView()
                } label: {
                    DeltiqRow(
                        icon: "heart.text.square",
                        label: String(localized: "settings.healthWrite.row", bundle: .module),
                        value: healthWriteValue,
                        showsChevron: true,
                        showsDivider: false
                    )
                }
            }
            hintRow(
                [
                    String(localized: "settings.health.footer", bundle: .module),
                    String(localized: "settings.health.workoutImport.footer", bundle: .module)
                ].joined(separator: "\n")
            )
        }
    }

    private var healthWriteValue: String {
        guard healthKit.workoutWriteAuthorization.workout == .sharingAuthorized else {
            return String(localized: "settings.healthWrite.valueNoAccess", bundle: .module)
        }
        switch (healthWriteStrengthEnabled, healthWriteCardioEnabled) {
        case (true, true):
            return String(localized: "settings.healthWrite.valueBoth", bundle: .module)
        case (true, false):
            return String(localized: "settings.healthWrite.valueStrength", bundle: .module)
        case (false, true):
            return String(localized: "settings.healthWrite.valueCardio", bundle: .module)
        case (false, false):
            return String(localized: "settings.healthWrite.valueOff", bundle: .module)
        }
    }

    @ViewBuilder
    private var healthKitStatusRow: some View {
        switch healthKit.authorizationStatus {
        case .sharingAuthorized:
            DeltiqControlRow(icon: "heart.fill", label: String(localized: "onboarding.health.connected", bundle: .module)) {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.Deltiq.success)
            }
        case .notDetermined:
            DeltiqControlRow(icon: "heart", label: String(localized: "settings.health.notSetup", bundle: .module)) {
                Button {
                    Task { await healthKit.requestAuthorization() }
                } label: {
                    Text("settings.health.connect", bundle: .module)
                }
                .font(.system(size: 14, weight: .semibold))
                .tint(Color.deltiqOrange)
                .disabled(!healthKit.isAvailable)
            }
        case .sharingDenied:
            DeltiqControlRow(icon: "heart.slash", label: String(localized: "settings.health.denied", bundle: .module)) {
                EmptyView()
            }
        case .unavailable:
            DeltiqControlRow(icon: "heart.slash", label: String(localized: "settings.health.unavailable", bundle: .module), showsDivider: false) {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var openHealthAppButton: some View {
        #if os(iOS)
        Button {
            HealthAppLink.open()
        } label: {
            DeltiqRow(icon: "heart.text.square", label: String(localized: "settings.healthWrite.openHealthApp", bundle: .module), showsDivider: false)
        }
        .buttonStyle(.plain)
        #endif
    }

    private var privacySection: some View {
        DeltiqSection(String(localized: "settings.section.privacy", bundle: .module).uppercased()) {
            NavigationLink {
                DataExportView()
            } label: {
                DeltiqRow(
                    icon: "square.and.arrow.up.on.square",
                    label: String(localized: "settings.privacy.dataExport", bundle: .module),
                    showsChevron: true
                )
            }
            NavigationLink {
                BackupListView()
            } label: {
                DeltiqRow(
                    icon: "clock.arrow.circlepath",
                    label: String(localized: "settings.privacy.backups", bundle: .module),
                    showsChevron: true
                )
            }
            NavigationLink {
                DataImportView()
            } label: {
                DeltiqRow(
                    icon: "square.and.arrow.down.on.square",
                    label: String(localized: "settings.privacy.dataImport", bundle: .module),
                    showsChevron: true,
                    showsDivider: false
                )
            }
            hintRow(String(localized: "settings.privacy.footer", bundle: .module))
        }
    }

    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }
}
#endif
