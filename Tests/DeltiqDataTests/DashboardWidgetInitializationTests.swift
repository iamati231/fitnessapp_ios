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

    // 6. setEnduranceModality aktiviert Coach (WP-D): runCoachCard landet an Index 1,
    //    raceProgressCard an Index 0.
    func testEnablingCoachingViaSetEnduranceModalityInsertsRunCoachCardAtIndex1() throws {
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
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets.first, .raceProgressCard,
                       "Nach Aktivieren via setEnduranceModality soll raceProgressCard ganz oben stehen")
        XCTAssertEqual(widgets.dropFirst().first, .runCoachCard,
                       "Nach Aktivieren via setEnduranceModality soll runCoachCard an Index 1 stehen")
    }

    // 7. WP-D top-3-Check: runCoachCard wird nicht verschoben wenn bereits in ersten drei Slots.
    func testRunCoachCardNotMovedWhenAlreadyInTop3() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        // Manuell runCoachCard an Position 2 legen
        var order: [DashboardWidgetType] = [.nextWorkout, .nutrition, .runCoachCard, .weeklyVolume]
        profile.activeDashboardWidgets = order
        let savedRaw = profile.activeDashboardWidgetsRaw

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        XCTAssertTrue(profile.cardioCoachingEnabled)
        // raceProgressCard wird oben eingefuegt, runCoachCard bleibt an ihrer bestehenden Position (nicht verschoben)
        let widgets = profile.activeDashboardWidgets
        XCTAssertTrue(widgets.prefix(3).contains(.runCoachCard),
                      "runCoachCard war bereits in top-3 und bleibt dort")
    }

    // 8. Karte nach Verschieben: naechstes Re-Enable bringt sie wieder an Index 1.
    func testReEnableAfterMoveRestoresRunCoachCardToIndex1() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        // Erster Enable: raceProgressCard an 0, runCoachCard an 1
        profile.setEnduranceModality(.running, runCoachEnabled: true)
        XCTAssertEqual(profile.activeDashboardWidgets.first, .raceProgressCard)
        XCTAssertEqual(profile.activeDashboardWidgets.dropFirst().first, .runCoachCard)

        // User verschiebt runCoachCard ans Ende
        var order = profile.activeDashboardWidgets.filter { $0 != .runCoachCard }
        order.append(.runCoachCard)
        profile.activeDashboardWidgets = order
        XCTAssertFalse(profile.activeDashboardWidgets.prefix(3).contains(.runCoachCard))

        // Deaktivieren + Reaktivieren: runCoachCard wieder an Index 1
        profile.setEnduranceModality(.running, runCoachEnabled: false)
        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets.first, .raceProgressCard,
                       "Re-Enable soll raceProgressCard an Position 0 setzen")
        XCTAssertEqual(widgets.dropFirst().first, .runCoachCard,
                       "Re-Enable soll runCoachCard an Index 1 zurueckbringen wenn sie ausserhalb top-3 war")
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

    // MARK: - Dashboard-Fix "doppelte Coach-Karten" / eigenstaendiger Widget-Typ

    // 10. Neues Profil mit aktiviertem Lauf-Coaching enthaelt BEIDE Karten.
    func testNewProfileWithCardioEnabledHasBothCoachCards() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: true
        )
        container.mainContext.insert(profile)
        XCTAssertTrue(profile.activeDashboardWidgets.contains(.runCoachCard))
        XCTAssertTrue(profile.activeDashboardWidgets.contains(.raceProgressCard))
    }

    // 11. User deaktiviert NUR die neue Karte - Einstellung bleibt bestehen,
    //     auch nach Aus-/Wieder-Einschalten des Coachings (Ticket: "bis eine
    //     neue Aenderung nicht wieder aktiviert").
    func testManuallyDisablingOnlyRaceProgressCardSurvivesCardioToggle() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: true
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = profile.activeDashboardWidgets.filter { $0 != .raceProgressCard }
        let savedRaw = profile.activeDashboardWidgetsRaw

        profile.cardioCoachingEnabled = false
        profile.cardioCoachingEnabled = true
        XCTAssertEqual(profile.activeDashboardWidgetsRaw, savedRaw)
        XCTAssertFalse(profile.activeDashboardWidgets.contains(.raceProgressCard))
        XCTAssertTrue(profile.activeDashboardWidgets.contains(.runCoachCard))
    }

    // 12. setEnduranceModality aktiviert Coach (WP-D): raceProgressCard zuerst, runCoachCard an Index 1.
    func testEnablingCoachingViaSetEnduranceModalityInsertsBothCardsAtTop() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        XCTAssertEqual(Array(profile.activeDashboardWidgets.prefix(2)), [.raceProgressCard, .runCoachCard],
                       "WP-D: raceProgressCard an 0, runCoachCard an 1")
    }
}
#endif
