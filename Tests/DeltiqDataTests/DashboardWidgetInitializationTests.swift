#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// Testet, dass `runCoachCard` nur dann im Standard-Widget-Set eines neuen
/// Profils erscheint, wenn `cardioCoachingEnabled == true`, und dass
/// bestehende Nutzerentscheidungen nie ueberschrieben werden.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class DashboardWidgetInitializationTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // 1. Neues Profil mit aktiviertem Lauf-Coaching enthaelt runCoachCard.
    func testNewProfileWithCardioEnabledHasRunCoachCard() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: true
        )
        container.mainContext.insert(profile)
        XCTAssertTrue(profile.activeDashboardWidgets.contains(.runCoachCard))
    }

    // 2. Neues Profil ohne Lauf-Coaching enthaelt runCoachCard nicht.
    func testNewProfileWithCardioDisabledHasNoRunCoachCard() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        XCTAssertFalse(profile.activeDashboardWidgets.contains(.runCoachCard))
    }

    // 3. Bestehendes Profil mit manuell deaktiviertem runCoachCard behaelt diese Einstellung.
    func testExistingProfileManuallyRemovedRunCoachCardIsPreserved() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: true
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = profile.activeDashboardWidgets.filter { $0 != .runCoachCard }
        let savedRaw = profile.activeDashboardWidgetsRaw

        // Toggling cardioCoachingEnabled darf activeDashboardWidgetsRaw nicht aendern
        profile.cardioCoachingEnabled = false
        XCTAssertEqual(profile.activeDashboardWidgetsRaw, savedRaw)
        profile.cardioCoachingEnabled = true
        XCTAssertEqual(profile.activeDashboardWidgetsRaw, savedRaw)
    }

    // 4. Erneutes Aktivieren von cardioCoachingEnabled aktiviert runCoachCard nicht automatisch.
    func testReenablingCardioDoesNotRestoreRunCoachCard() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        XCTAssertFalse(profile.activeDashboardWidgets.contains(.runCoachCard))

        profile.cardioCoachingEnabled = true
        XCTAssertFalse(profile.activeDashboardWidgets.contains(.runCoachCard))
    }

    // 5. Neues Profil mit Lauf-Coaching: runCoachCard ist an erster Position (ganz oben).
    func testNewProfileWithCardioEnabledHasRunCoachCardFirst() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: true
        )
        container.mainContext.insert(profile)
        XCTAssertEqual(profile.activeDashboardWidgets.first, .runCoachCard,
                       "Neues Profil mit cardioCoachingEnabled soll runCoachCard als erstes Widget haben")
    }

    // 6. setEnduranceModality aktiviert Coach: Widget wird ganz oben eingefuegt
    //    (cardioWidgetUserConfigured == false → kein Veto).
    func testEnablingCoachingViaSetEnduranceModalityInsertsRunCoachCardFirst() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        XCTAssertFalse(profile.activeDashboardWidgets.contains(.runCoachCard))

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        XCTAssertTrue(profile.cardioCoachingEnabled)
        XCTAssertEqual(profile.activeDashboardWidgets.first, .runCoachCard,
                       "Nach erstem Aktivieren via setEnduranceModality soll runCoachCard ganz oben stehen")
    }

    // 7. Wenn cardioWidgetUserConfigured == true, kein Auto-Insert durch setEnduranceModality.
    func testNoAutoInsertWhenUserHasExplicitlyConfiguredWidgets() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.cardioWidgetUserConfigured = true

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        XCTAssertTrue(profile.cardioCoachingEnabled)
        XCTAssertFalse(profile.activeDashboardWidgets.contains(.runCoachCard),
                       "Nach expliziter User-Konfiguration kein Auto-Insert von runCoachCard")
    }

    // 9. Eine benutzerdefinierte Widget-Reihenfolge bleibt unveraendert.
    func testCustomWidgetOrderSurvivesCardioToggle() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: true
        )
        container.mainContext.insert(profile)
        let customOrder: [DashboardWidgetType] = [.nutrition, .nextWorkout, .runCoachCard]
        profile.activeDashboardWidgets = customOrder

        profile.cardioCoachingEnabled = false
        XCTAssertEqual(profile.activeDashboardWidgets, customOrder)
        profile.cardioCoachingEnabled = true
        XCTAssertEqual(profile.activeDashboardWidgets, customOrder)
    }
}
#endif
