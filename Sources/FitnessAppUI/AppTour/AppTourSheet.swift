#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// Kombiniertes Sheet für die optionale App-Einführungstour.
///
/// Startet optional mit einer Einladungsseite (Post-Onboarding-Pfad) oder
/// direkt beim ersten Schritt (Einstellungen-Neustart). Keine fixen UI-Koordinaten
/// oder fragile Element-Highlights — robuste Erklärungsansichten mit Icon, Titel
/// und Beschreibung. Änderungen an Nutzerdaten finden nicht statt.
@available(iOS 17.0, macOS 14.0, *)
public struct AppTourSheet: View {

    /// ob die Einladungsseite vor Schritt 1 gezeigt wird (Post-Onboarding)
    /// oder direkt mit Schritt 0 begonnen wird (Neustart via Einstellungen).
    let showInvitation: Bool
    let onDismiss: () -> Void

    @State private var phase: Phase = .invitation
    @Environment(\.dismiss) private var dismiss

    public init(showInvitation: Bool, onDismiss: @escaping () -> Void) {
        self.showInvitation = showInvitation
        self.onDismiss = onDismiss
        _phase = State(initialValue: showInvitation ? .invitation : .step(0))
    }

    enum Phase: Equatable {
        case invitation
        case step(Int)
    }

    private var stepCount: Int { TourContent.steps.count }

    public var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .invitation:
                    invitationPage
                case .step(let index):
                    stepPage(index: index)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        handleDismiss()
                    } label: {
                        Text("tour.skip", bundle: .module)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Einladungsseite

    private var invitationPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.deltiqOrange)

                VStack(spacing: 10) {
                    Text("tour.invitation.title", bundle: .module)
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("tour.invitation.message", bundle: .module)
                        .font(.body)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .step(0)
                    }
                } label: {
                    Text("tour.invitation.start", bundle: .module)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.deltiqOrange)

                Button {
                    handleDismiss()
                } label: {
                    Text("tour.invitation.later", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Deltiq.background.ignoresSafeArea())
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Tourschritt

    private func stepPage(index: Int) -> some View {
        let step = TourContent.steps[index]
        return VStack(spacing: 0) {
            // Fortschrittsbalken
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { i in
                    Capsule()
                        .fill(i <= index ? Color.deltiqOrange : Color.secondary.opacity(0.2))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 4)

            Spacer()

            VStack(spacing: 28) {
                Image(systemName: step.systemImage)
                    .font(.system(size: 60))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.deltiqOrange)

                VStack(spacing: 12) {
                    Text(step.titleKey, bundle: .module)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text(step.descriptionKey, bundle: .module)
                        .font(.body)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Schrittanzeige und Navigation
            VStack(spacing: 16) {
                Text(
                    String(
                        format: String(localized: "tour.step.progress", bundle: .module),
                        index + 1,
                        stepCount
                    )
                )
                .font(.caption)
                .foregroundStyle(Color.Deltiq.textSecondary)

                HStack(spacing: 16) {
                    if index > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                phase = .step(index - 1)
                            }
                        } label: {
                            Text("tour.step.back", bundle: .module)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    if index < stepCount - 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                phase = .step(index + 1)
                            }
                        } label: {
                            Text("tour.step.next", bundle: .module)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.deltiqOrange)
                    } else {
                        Button {
                            handleDismiss()
                        } label: {
                            Text("tour.step.finish", bundle: .module)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.deltiqOrange)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Deltiq.background.ignoresSafeArea())
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func handleDismiss() {
        dismiss()
        onDismiss()
    }
}

// MARK: - Tourinhalte

/// Die 6 Tour-Schritte. Erklärt nur tatsächlich vorhandene Funktionen.
enum TourContent {

    struct Step {
        let systemImage: String
        let titleKey: LocalizedStringKey
        let descriptionKey: LocalizedStringKey
    }

    static let steps: [Step] = [
        Step(
            systemImage: "chart.line.uptrend.xyaxis",
            titleKey: "tour.step.dashboard.title",
            descriptionKey: "tour.step.dashboard.description"
        ),
        Step(
            systemImage: "list.bullet.rectangle.portrait",
            titleKey: "tour.step.training.title",
            descriptionKey: "tour.step.training.description"
        ),
        Step(
            systemImage: "fork.knife",
            titleKey: "tour.step.nutrition.title",
            descriptionKey: "tour.step.nutrition.description"
        ),
        Step(
            systemImage: "calendar.badge.plus",
            titleKey: "tour.step.mealplan.title",
            descriptionKey: "tour.step.mealplan.description"
        ),
        Step(
            systemImage: "ruler",
            titleKey: "tour.step.progress.title",
            descriptionKey: "tour.step.progress.description"
        ),
        Step(
            systemImage: "gearshape",
            titleKey: "tour.step.settings.title",
            descriptionKey: "tour.step.settings.description"
        ),
    ]
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Einladung") {
    AppTourSheet(showInvitation: true) {}
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Neustart (kein Einladungs-Screen)") {
    AppTourSheet(showInvitation: false) {}
}
#endif
#endif
