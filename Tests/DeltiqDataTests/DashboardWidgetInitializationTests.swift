#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// WP-D-Korrektur: Testet, dass setEnduranceModality ausschliesslich runCoachCard
/// positioniert und raceProgressCard sowie alle anderen Widgets unveraendert laesst.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class DashboardWidgetInitializationTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Profil-Initialisierung

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

    // MARK: - WP-D: setEnduranceModality AUS→EIN (nur runCoachCard positionieren)

    // 6. WP-D AUS→EIN: runCoachCard wird an Index 1 eingefuegt; raceProgressCard bleibt unveraendert.
    func testEnablingCoachingViaSetEnduranceModalityInsertsRunCoachCardAtIndex1() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.nextWorkout, .nutrition, .weeklyVolume]

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        XCTAssertTrue(profile.cardioCoachingEnabled)
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets[1], .runCoachCard,
                       "WP-D soll runCoachCard an Index 1 einfuegen")
        XCTAssertEqual(widgets[0], .nextWorkout,
                       "Index 0 muss unveraendert bleiben")
        XCTAssertFalse(widgets.contains(.raceProgressCard),
                       "WP-D darf raceProgressCard nicht einfuegen")
    }

    // 7. WP-D: Leere Widget-Liste → runCoachCard an Index 0.
    func testEnablingCoachingWithEmptyWidgetListInsertsRunCoachCardAtIndex0() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = []

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets.count, 1)
        XCTAssertEqual(widgets[0], .runCoachCard,
                       "Bei leerer Liste soll runCoachCard an Index 0 stehen")
    }

    // 8. WP-D: runCoachCard bereits an Index 0 → Position bleibt unveraendert.
    func testRunCoachCardAtIndex0NotMovedByWPD() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.runCoachCard, .nextWorkout, .nutrition]

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets[0], .runCoachCard,
                       "runCoachCard war an Index 0 und muss dort bleiben")
        XCTAssertEqual(widgets.filter { $0 == .runCoachCard }.count, 1)
    }

    // 9. WP-D: runCoachCard bereits an Index 1 → Position bleibt unveraendert.
    func testRunCoachCardAtIndex1NotMovedByWPD() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.nextWorkout, .runCoachCard, .nutrition]

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets[1], .runCoachCard,
                       "runCoachCard war an Index 1 und muss dort bleiben")
        XCTAssertEqual(widgets.filter { $0 == .runCoachCard }.count, 1)
    }

    // 10. WP-D: runCoachCard bereits an Index 2 → exakte Positionspruefung, nicht nur contains().
    func testRunCoachCardAtIndex2NotMovedByWPD() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.nextWorkout, .nutrition, .runCoachCard, .weeklyVolume]

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        // Exakte Positionspruefung — prefix(3).contains() wuerde auch nach einer
        // Verschiebung zu Index 0 oder 1 bestehen.
        XCTAssertEqual(widgets[2], .runCoachCard,
                       "runCoachCard war an Index 2 und muss dort bleiben (exakte Positionspruefung)")
        XCTAssertEqual(widgets.filter { $0 == .runCoachCard }.count, 1)
    }

    // 11. WP-D: runCoachCard ausserhalb der ersten drei Positionen → Einfuegung an Index 1.
    func testRunCoachCardOutsideTop3MovedToIndex1ByWPD() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.nextWorkout, .nutrition, .weeklyVolume, .runCoachCard]

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets[1], .runCoachCard,
                       "runCoachCard war ausserhalb top-3 und soll an Index 1 verschoben werden")
        XCTAssertEqual(widgets.filter { $0 == .runCoachCard }.count, 1)
    }

    // 12. WP-D: Mehrere runCoachCard-Eintraege (ausserhalb top-3) → exakt einer bleibt, an Index 1.
    func testDuplicateRunCoachCardsDeduplicatedToIndex1ByWPD() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.nextWorkout, .nutrition, .weeklyVolume, .runCoachCard, .runCoachCard]

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets.filter { $0 == .runCoachCard }.count, 1,
                       "Genau ein runCoachCard-Eintrag muss verbleiben")
        XCTAssertEqual(widgets[1], .runCoachCard)
    }

    // 13. WP-D: Vorhandene raceProgressCard bleibt an ihrer Position unveraendert.
    func testExistingRaceProgressCardPositionPreservedByWPD() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.raceProgressCard, .nextWorkout, .nutrition, .weeklyVolume]

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets[0], .raceProgressCard,
                       "raceProgressCard muss an ihrer urspruenglichen Position bleiben")
        XCTAssertEqual(widgets[1], .runCoachCard)
    }

    // 14. WP-D: Fehlende raceProgressCard wird durch WP-D nicht eingefuegt.
    func testMissingRaceProgressCardNotInsertedByWPD() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.nextWorkout, .nutrition, .weeklyVolume]
        XCTAssertFalse(profile.activeDashboardWidgets.contains(.raceProgressCard))

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        XCTAssertFalse(profile.activeDashboardWidgets.contains(.raceProgressCard),
                       "WP-D darf raceProgressCard nicht einfuegen wenn sie fehlt")
    }

    // 15. WP-D: AUS→AUS — kein Neuordnen.
    func testAusToAusNoReordering() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        let initial: [DashboardWidgetType] = [.nextWorkout, .nutrition, .weeklyVolume]
        profile.activeDashboardWidgets = initial

        profile.setEnduranceModality(.running, runCoachEnabled: false)
        XCTAssertEqual(profile.activeDashboardWidgets, initial,
                       "AUS→AUS: Reihenfolge muss unveraendert bleiben")
    }

    // 16. WP-D: EIN→AUS — kein Neuordnen.
    func testEinToAusNoReordering() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.nextWorkout, .nutrition, .weeklyVolume]

        // AUS→EIN: runCoachCard wird eingefuegt
        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let stateAfterEnable = profile.activeDashboardWidgets

        // EIN→AUS: Reihenfolge bleibt unveraendert
        profile.setEnduranceModality(.running, runCoachEnabled: false)
        XCTAssertEqual(profile.activeDashboardWidgets, stateAfterEnable,
                       "EIN→AUS: Reihenfolge muss unveraendert bleiben")
    }

    // 17. WP-D: EIN→EIN — kein Neuordnen.
    func testEinToEinNoReordering() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.nextWorkout, .nutrition, .weeklyVolume]

        // AUS→EIN: runCoachCard wird eingefuegt
        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let stateAfterFirstEnable = profile.activeDashboardWidgets

        // EIN→EIN: zweites Enable darf nichts aendern
        profile.setEnduranceModality(.running, runCoachEnabled: true)
        XCTAssertEqual(profile.activeDashboardWidgets, stateAfterFirstEnable,
                       "EIN→EIN: Reihenfolge muss unveraendert bleiben")
    }

    // 18. WP-D: Andere Widgets behalten ihre relative Reihenfolge.
    func testOtherWidgetsRelativeOrderPreservedByWPD() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.nextWorkout, .nutrition, .weeklyVolume]

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        let withoutCoach = widgets.filter { $0 != .runCoachCard }
        XCTAssertEqual(withoutCoach, [.nextWorkout, .nutrition, .weeklyVolume],
                       "Relative Reihenfolge aller anderen Widgets muss erhalten bleiben")
    }

    // MARK: - Karten-Toggle (EIN/AUS via cardioCoachingEnabled direkt)

    // 19. Eine benutzerdefinierte Widget-Reihenfolge bleibt unveraendert beim Cardio-Toggle.
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

    // 20. Neues Profil mit aktiviertem Lauf-Coaching enthaelt BEIDE Karten.
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

    // 21. User deaktiviert NUR raceProgressCard - Einstellung bleibt beim Coaching-Toggle.
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

    // MARK: - WP-D Duplikat-Bereinigung innerhalb top-3

    // 23. runCoachCard an Index 2 und Duplikat am Ende: Index 2 bleibt, genau ein Eintrag.
    func testRunCoachCardAtIndex2WithDuplicateAtEnd() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.nextWorkout, .nutrition, .runCoachCard, .weeklyVolume, .runCoachCard]

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets[2], .runCoachCard,
                       "runCoachCard war an Index 2 — muss dort bleiben (Duplikat entfernt)")
        XCTAssertEqual(widgets.filter { $0 == .runCoachCard }.count, 1,
                       "Genau ein runCoachCard-Eintrag muss verbleiben")
    }

    // 24. runCoachCard an Index 0 und Duplikat ausserhalb top-3: Index 0 bleibt, genau ein Eintrag.
    func testRunCoachCardAtIndex0WithDuplicateOutsideTop3() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.runCoachCard, .nextWorkout, .nutrition, .weeklyVolume, .runCoachCard]

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets[0], .runCoachCard,
                       "runCoachCard war an Index 0 — muss dort bleiben (Duplikat entfernt)")
        XCTAssertEqual(widgets.filter { $0 == .runCoachCard }.count, 1,
                       "Genau ein runCoachCard-Eintrag muss verbleiben")
    }

    // 25. runCoachCard an Index 1 und mehrere Duplikate: Index 1 bleibt, genau ein Eintrag.
    func testRunCoachCardAtIndex1WithMultipleDuplicates() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.nextWorkout, .runCoachCard, .nutrition, .runCoachCard, .weeklyVolume, .runCoachCard]

        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets[1], .runCoachCard,
                       "runCoachCard war an Index 1 — muss dort bleiben (Duplikate entfernt)")
        XCTAssertEqual(widgets.filter { $0 == .runCoachCard }.count, 1,
                       "Genau ein runCoachCard-Eintrag muss verbleiben")
    }

    // 22. WP-D Re-Enable: runCoachCard kommt zurueck an Index 1 (raceProgressCard unveraendert).
    func testReEnableAfterMoveRestoresRunCoachCardToIndex1() throws {
        let container = try makeContainer()
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 760_000_000),
            heightCm: 172, profile: .male,
            cardioCoachingEnabled: false
        )
        container.mainContext.insert(profile)
        profile.activeDashboardWidgets = [.nextWorkout, .nutrition, .weeklyVolume]

        // Erster Enable: runCoachCard an Index 1
        profile.setEnduranceModality(.running, runCoachEnabled: true)
        XCTAssertEqual(profile.activeDashboardWidgets[1], .runCoachCard)

        // User verschiebt runCoachCard ans Ende
        var order = profile.activeDashboardWidgets.filter { $0 != .runCoachCard }
        order.append(.runCoachCard)
        profile.activeDashboardWidgets = order
        XCTAssertFalse(profile.activeDashboardWidgets.prefix(3).contains(.runCoachCard))

        // Deaktivieren + Reaktivieren: runCoachCard wieder an Index 1
        profile.setEnduranceModality(.running, runCoachEnabled: false)
        profile.setEnduranceModality(.running, runCoachEnabled: true)
        let widgets = profile.activeDashboardWidgets
        XCTAssertEqual(widgets[1], .runCoachCard,
                       "Re-Enable soll runCoachCard an Index 1 zurueckbringen wenn sie ausserhalb top-3 war")
        XCTAssertFalse(widgets.contains(.raceProgressCard),
                       "WP-D darf raceProgressCard nicht einfuegen")
    }
}
#endif
