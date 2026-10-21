import XCTest
@testable import FitnessAppCore

/// Smart-Onboarding-Epic Phase 4 (PLAN_EQUIPMENT_MATCHING_AUDIT.md Abschnitt
/// 13): Regressionstests fuer die praezise, pro-Uebung-basierte Equipment-
/// Pruefung einer kompletten Planvariante (`PlanEquipmentChecker`/
/// `ProgramTemplate.bestEquipmentCheckedVariant`). Deckt genau die sechs vom
/// Auftrag genannten Szenarien ab: nur Koerpergewicht, nur Kettlebells, KH
/// ohne Bank, KH mit Flachbank vs. Schraegbank, Klimmzugstange vorhanden/
/// fehlend, unbekannte Stueckzahl — jeweils mit Auswahl + Begruendung.
final class PlanEquipmentCheckTests: XCTestCase {

    private func day(_ names: [String]) -> [DaySpec] {
        [DaySpec(name: "Test", type: .fullBody, sequenceIndex: 1, exercises: names.map {
            ExerciseSpec(name: $0, sets: 3, repsMin: 8, repsMax: 12)
        })]
    }

    // MARK: - PlanEquipmentChecker: Grundregeln

    func testAllAnnotatedBodyweightExercisesAreAvailableRegardlessOfProfile() {
        let status = PlanEquipmentChecker.check(days: day(["Plank", "Liegestütze", "Sit-ups"]), against: UserEquipmentProfile())
        XCTAssertEqual(status, .available, "Reine Koerpergewichts-Uebungen sind .all([]) annotiert — bestaetigt keine Anforderung, unabhaengig vom Profil")
    }

    func testNotYetAnnotatedExerciseMakesDayUnknownNeverAvailable() {
        // "Box Jump" ist bewusst nicht annotiert (Plyo-Box nicht modelliert,
        // siehe Abdeckungsreport) - muss .unknown liefern, nie .available.
        let status = PlanEquipmentChecker.check(days: day(["Box Jump"]), against: UserEquipmentProfile())
        guard case let .unknown(gaps) = status else {
            return XCTFail("Nicht annotierte Uebung muss .unknown sein, ist: \(status)")
        }
        XCTAssertEqual(gaps.first?.reason, .notAnnotated)
    }

    func testUnknownExerciseNameIsTreatedLikeNotAnnotatedNeverAvailable() {
        let status = PlanEquipmentChecker.check(days: day(["Komplett erfundene Uebung"]), against: UserEquipmentProfile())
        guard case let .unknown(gaps) = status else {
            return XCTFail("Unbekannter Uebungsname darf nie .available liefern, ist: \(status)")
        }
        XCTAssertEqual(gaps.first?.reason, .notAnnotated)
    }

    func testOneDefinitelyMissingExerciseMakesWholeDayUnavailableEvenWithAnUnknownSibling() {
        // "Kniebeuge" (Langhantel+Rack, bestaetigt fehlend) + "Box Jump"
        // (nicht annotiert) im selben Tag -> definitiv unerfuellt gewinnt.
        var profile = UserEquipmentProfile()
        profile.confirmRemainingAsUnavailable()
        let status = PlanEquipmentChecker.check(days: day(["Kniebeuge", "Box Jump"]), against: profile)
        guard case let .unavailable(gaps) = status else {
            return XCTFail("Ein definitiv fehlendes Geraet muss gewinnen, ist: \(status)")
        }
        XCTAssertEqual(gaps.map(\.exerciseName), ["Kniebeuge"], "Nur die definitiv unerfuellte Uebung erscheint als Grund fuer .unavailable")
    }

    // MARK: - Szenario 1: Nur Koerpergewicht

    func testBodyweightOnlyProfileRejectsBarbellExercise() {
        var profile = UserEquipmentProfile()
        profile.confirmRemainingAsUnavailable()
        let status = PlanEquipmentChecker.check(days: day(["Kniebeuge"]), against: profile)
        guard case let .unavailable(gaps) = status else {
            return XCTFail("Bestaetigtes 'Nur Koerpergewicht' darf eine Langhantel-Uebung nie als verfuegbar/unbekannt zeigen, ist: \(status)")
        }
        guard case let .missing(reasons) = gaps.first?.reason else {
            return XCTFail("Erwartet konkrete 'missing'-Gruende")
        }
        // `.all(...)` kurzschliesst beim ERSTEN definitiv unerfuellten Kind
        // (siehe EquipmentRequirementTests.testAllIsDefinitelyUnmetWhenOne...)
        // — hier .barbell, da zuerst in der Liste. Das reicht bereits als
        // konkreter, nachvollziehbarer Grund.
        XCTAssertEqual(reasons.map(\.item), [.barbell])
    }

    /// Auswahl + Begruendung auf Template-Ebene: ein bestaetigter Nur-
    /// Koerpergewicht-Nutzer bekommt fuer `hybrid_balanced` (Basis + zwei
    /// Geraete-Varianten) KEINE als `.available` ausgegeben — die Funktion
    /// zeigt stattdessen transparent die Basis-Variante mit `.unavailable`,
    /// statt eine davon stillschweigend als passend zu behaupten (Punkt 7/8).
    func testBodyweightOnlySelectsNoVariantAsAvailableForHybridBalanced() {
        var profile = UserEquipmentProfile()
        profile.confirmRemainingAsUnavailable()
        let template = ProgramTemplates.all.first { $0.id == "hybrid_balanced" }!
        let checked = template.equipmentCheckedVariants(against: profile)
        XCTAssertTrue(checked.allSatisfy { $0.equipmentStatus.isUnavailable }, "Weder Basis noch Dumbbell- noch Kettlebell-Variante duerfen fuer reines Koerpergewicht passen")

        let best = template.bestEquipmentCheckedVariant(against: profile)
        XCTAssertNil(best.profile, "Ohne jede passende/unklare Variante faellt die Funktion transparent auf die Basis-Variante zurueck")
        XCTAssertTrue(best.equipmentStatus.isUnavailable)
        XCTAssertEqual(best.days, template.days, "Keine stillschweigende Ersatz-Variante — die gezeigten Tage bleiben die (nicht passende) Basis")
    }

    /// Dieselbe Pruefung muss den Hartfilter des Matchers erreichen:
    /// `hybrid_balanced` darf fuer bestaetigtes Nur-Koerpergewicht gar nicht
    /// erst in der Ergebnisliste auftauchen.
    func testBodyweightOnlyExcludesHybridBalancedFromMatcherResults() {
        var profile = UserEquipmentProfile()
        profile.confirmRemainingAsUnavailable()
        let answers = QuizAnswers(goal: .hybrid, experience: .intermediate, preferredDays: 5, environment: .gym, equipmentProfile: profile)
        let result = PlanMatchmaker.rankPlansDetailed(for: answers, templates: ProgramTemplates.all)
        XCTAssertFalse(result.templates.contains { $0.id == "hybrid_balanced" })
    }

    // MARK: - Szenario 2: Nur Kettlebells

    func testKettlebellOnlyProfileSatisfiesSingleKettlebellExercises() {
        var profile = UserEquipmentProfile()
        profile.availability[.kettlebell] = .available
        profile.confirmRemainingAsUnavailable()
        let status = PlanEquipmentChecker.check(days: day(["Kettlebell Swing", "Kettlebell Goblet Squat", "Kettlebell Halo"]), against: profile)
        XCTAssertEqual(status, .available, "Alle drei Uebungen brauchen hoechstens EINE Kettlebell (Default-Stueckzahl 1)")
    }

    /// Auswahl + Begruendung: mit ausschliesslich einer bestaetigten
    /// Kettlebell waehlt `hybrid_balanced` die Kettlebell-Variante als
    /// `.available` — weder die Basis (braucht Langhantel) noch Dumbbell
    /// (braucht Kurzhanteln) kommen infrage.
    func testKettlebellOnlySelectsKettlebellVariantAsAvailableForHybridBalanced() {
        var profile = UserEquipmentProfile()
        profile.availability[.kettlebell] = .available
        profile.confirmRemainingAsUnavailable()
        let template = ProgramTemplates.all.first { $0.id == "hybrid_balanced" }!

        let checked = template.equipmentCheckedVariants(against: profile)
        let base = checked.first { $0.profile == nil }!
        let dumbbellOnly = checked.first { $0.profile == .dumbbellOnly }!
        let kettlebellOnly = checked.first { $0.profile == .kettlebellOnly }!
        XCTAssertTrue(base.equipmentStatus.isUnavailable, "Basis braucht Langhantel+Bank, fehlt komplett")
        XCTAssertTrue(dumbbellOnly.equipmentStatus.isUnavailable, "Dumbbell-Variante braucht Kurzhanteln, fehlen komplett")
        XCTAssertEqual(kettlebellOnly.equipmentStatus, .available)

        let best = template.bestEquipmentCheckedVariant(against: profile)
        XCTAssertEqual(best.profile, .kettlebellOnly, "Auswahl: einzige tatsaechlich passende Variante")
        XCTAssertEqual(best.equipmentStatus, .available, "Begruendung: vollstaendig bestaetigt passend")
        XCTAssertEqual(best.days, kettlebellOnly.days, "Instanziierte Variante (ueber dieselbe Funktion) == die als passend gezeigte Variante")
    }

    // MARK: - Szenario 3: Kurzhantel ohne Bank

    func testDumbbellWithoutAnyBenchRejectsBenchDependentExercise() {
        var profile = UserEquipmentProfile()
        profile.availability[.dumbbell] = .available
        profile.counts[.dumbbell] = 2
        profile.confirmRemainingAsUnavailable()
        let status = PlanEquipmentChecker.check(days: day(["Bankdrücken (KH)"]), against: profile)
        guard case let .unavailable(gaps) = status else {
            return XCTFail("Kurzhantel-Bankdruecken ohne jede Bank darf nicht verfuegbar/unbekannt sein, ist: \(status)")
        }
        guard case let .missing(reasons) = gaps.first?.reason else { return XCTFail("Erwartet 'missing'") }
        XCTAssertEqual(Set(reasons.map(\.item)), [.flatBench, .adjustableBench], "Weder Flach- noch verstellbare Bank bestaetigt vorhanden")
    }

    func testDumbbellWithoutConfirmedBenchIsUnknownNotUnavailable() {
        // Bank nie erfasst (nicht bestaetigt fehlend) -> unbekannt, nicht
        // automatisch "nicht verfuegbar".
        let profile = UserEquipmentProfile(availability: [.dumbbell: .available], counts: [.dumbbell: 2])
        let status = PlanEquipmentChecker.check(days: day(["Bankdrücken (KH)"]), against: profile)
        guard case .unknown = status else {
            return XCTFail("Unbestaetigte Bank-Verfuegbarkeit ist unbekannt, nicht automatisch fehlend, ist: \(status)")
        }
    }

    /// Auswahl + Begruendung: KH vorhanden, Bank bestaetigt fehlend -> auch
    /// die Dumbbell-Variante von `hybrid_balanced` faellt komplett durch
    /// (mehrere ihrer Uebungen brauchen eine Bank), Kettlebell/Basis fehlen
    /// ebenfalls -> transparenter Basis-Fallback mit `.unavailable`.
    func testDumbbellWithoutBenchDoesNotSelectDumbbellVariantForHybridBalanced() {
        var profile = UserEquipmentProfile()
        profile.availability[.dumbbell] = .available
        profile.counts[.dumbbell] = 2
        profile.confirmRemainingAsUnavailable()
        let template = ProgramTemplates.all.first { $0.id == "hybrid_balanced" }!
        let dumbbellOnly = template.equipmentCheckedVariants(against: profile).first { $0.profile == .dumbbellOnly }!
        XCTAssertTrue(dumbbellOnly.equipmentStatus.isUnavailable, "Mehrere Push/Pull/Legs-Uebungen dieser Variante brauchen eine Bank")

        let best = template.bestEquipmentCheckedVariant(against: profile)
        XCTAssertNotEqual(best.profile, .dumbbellOnly, "Darf NICHT als geprueft-passend ausgegeben werden, obwohl Kurzhanteln vorhanden sind")
    }

    // MARK: - Szenario 4: Kurzhantel mit Flachbank vs. Schraegbank

    func testFlatBenchSatisfiesFlatExerciseButNotInclineExercise() {
        var profile = UserEquipmentProfile()
        profile.availability[.dumbbell] = .available
        profile.counts[.dumbbell] = 2
        profile.availability[.flatBench] = .available
        profile.confirmRemainingAsUnavailable()

        XCTAssertEqual(PlanEquipmentChecker.check(days: day(["Bankdrücken (KH)"]), against: profile), .available,
                       "Flachbank reicht fuer eine Flachbank-Uebung")
        guard case .unavailable = PlanEquipmentChecker.check(days: day(["Schrägbankdrücken aufwärts (KH)"]), against: profile) else {
            return XCTFail("Eine reine Flachbank kann nicht inclinen — Schraegbankdruecken muss fehlschlagen")
        }
    }

    func testAdjustableBenchSatisfiesBothFlatAndInclineExercises() {
        var profile = UserEquipmentProfile()
        profile.availability[.dumbbell] = .available
        profile.counts[.dumbbell] = 2
        profile.availability[.adjustableBench] = .available
        profile.confirmRemainingAsUnavailable()

        XCTAssertEqual(PlanEquipmentChecker.check(days: day(["Bankdrücken (KH)"]), against: profile), .available,
                       "Eine verstellbare Bank deckt auch die Flachbank-Anforderung ab")
        XCTAssertEqual(PlanEquipmentChecker.check(days: day(["Schrägbankdrücken aufwärts (KH)"]), against: profile), .available)
    }

    // MARK: - Szenario 5: Klimmzugstange vorhanden/fehlend

    func testPullUpBarAvailableSatisfiesPullupExercise() {
        let profile = UserEquipmentProfile(availability: [.pullUpBar: .available])
        XCTAssertEqual(PlanEquipmentChecker.check(days: day(["Klimmzüge"]), against: profile), .available)
    }

    func testPullUpBarConfirmedMissingRejectsPullupExercise() {
        var profile = UserEquipmentProfile()
        profile.confirmRemainingAsUnavailable()
        guard case let .unavailable(gaps) = PlanEquipmentChecker.check(days: day(["Klimmzüge"]), against: profile) else {
            return XCTFail("Bestaetigt fehlende Klimmzugstange muss die Uebung ausschliessen")
        }
        guard case let .missing(reasons) = gaps.first?.reason else { return XCTFail("Erwartet 'missing'") }
        XCTAssertEqual(reasons.first?.item, .pullUpBar)
    }

    func testPullUpBarUnknownIsUnknownNotAvailable() {
        let status = PlanEquipmentChecker.check(days: day(["Klimmzüge"]), against: UserEquipmentProfile())
        guard case .unknown = status else {
            return XCTFail("Unbestaetigte Klimmzugstange ist unbekannt, nie automatisch verfuegbar")
        }
    }

    // MARK: - Szenario 6: Unbekannte Stückzahl

    func testKettlebellAvailableWithoutCountIsUnknownForDoubleKettlebellExercise() {
        let profile = UserEquipmentProfile(availability: [.kettlebell: .available])
        guard case let .unknown(gaps) = PlanEquipmentChecker.check(days: day(["Kettlebell Front Squat"]), against: profile) else {
            return XCTFail("Kettlebell vorhanden, aber Stueckzahl nie erfasst -> unbekannt, nie 'erfuellt' fuer eine 2er-Anforderung")
        }
        XCTAssertEqual(gaps.first?.exerciseName, "Kettlebell Front Squat")
    }

    func testKettlebellAvailableWithConfirmedCountOfTwoSatisfiesDoubleKettlebellExercise() {
        let profile = UserEquipmentProfile(availability: [.kettlebell: .available], counts: [.kettlebell: 2])
        XCTAssertEqual(PlanEquipmentChecker.check(days: day(["Kettlebell Front Squat"]), against: profile), .available)
    }

    func testKettlebellAvailableWithConfirmedCountOfOneRejectsDoubleKettlebellExercise() {
        let profile = UserEquipmentProfile(availability: [.kettlebell: .available], counts: [.kettlebell: 1])
        guard case let .unavailable(gaps) = PlanEquipmentChecker.check(days: day(["Kettlebell Front Squat"]), against: profile) else {
            return XCTFail("Bestaetigt nur EINE Kettlebell muss eine 2er-Anforderung definitiv verfehlen, nicht nur 'unbekannt'")
        }
        guard case let .missing(reasons) = gaps.first?.reason else { return XCTFail("Erwartet 'missing'") }
        XCTAssertEqual(reasons.first?.knownCount, 1)
    }

    // MARK: - Stabilitaet (Schutz gegen die Phase-1-Vorschau/Instanziierung-Divergenz)

    /// `bestEquipmentCheckedVariant` ist eine reine Funktion ueber Template+
    /// Profil — zwei Aufrufe mit identischen Eingaben (wie Vorschau und
    /// Instanziierung sie je einmal machen) muessen IMMER dasselbe liefern.
    func testBestEquipmentCheckedVariantIsDeterministicAcrossRepeatedCalls() {
        var profile = UserEquipmentProfile()
        profile.availability[.kettlebell] = .available
        profile.confirmRemainingAsUnavailable()
        let template = ProgramTemplates.all.first { $0.id == "hybrid_balanced" }!
        let first = template.bestEquipmentCheckedVariant(against: profile)
        let second = template.bestEquipmentCheckedVariant(against: profile)
        XCTAssertEqual(first, second)
    }
}
