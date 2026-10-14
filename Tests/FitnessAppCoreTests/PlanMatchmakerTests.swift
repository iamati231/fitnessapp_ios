import XCTest
@testable import FitnessAppCore

/// DEL-090: Tests fuer den Quiz-Score-Algorithmus.
final class PlanMatchmakerTests: XCTestCase {

    private let allTemplates = ProgramTemplates.all

    /// Hauptbeispiel aus dem Ticket: "Athletischer werden + Fortgeschritten +
    /// 5 Tage + Gym" → Top-Match sollte Hybrid Balanced sein.
    func testHybridBalancedTopMatchForAthletischFortgeschritten5DayGym() {
        let answers = QuizAnswers(
            goal: .hybrid,
            experience: .intermediate,
            preferredDays: 5,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        XCTAssertEqual(ranked.first?.id, "hybrid_balanced")
    }

    /// Powerlifting-User mit 3 Tagen Gym → 5x5 oder 3x5 sollten oben sein.
    func testPowerlifting3DayTopMatchIsAPowerliftingProgram() {
        let answers = QuizAnswers(
            goal: .strength,
            experience: .intermediate,
            preferredDays: 3,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        let topID = ranked.first?.id ?? ""
        XCTAssertTrue(topID.contains("powerlifting"),
                      "Top-Match sollte ein Powerlifting-Plan sein, ist: \(topID)")
    }

    /// User mit kleiner Trainings-Zeit (2 Tage) → Plaene mit daysPerWeek > 2
    /// fliegen raus. Top sollte 2-Tage-Plan oder 1-Tage-Plan sein.
    func testKOMaxDaysFiltersOutLongerPlans() {
        let answers = QuizAnswers(
            goal: .hybrid,
            experience: .intermediate,
            preferredDays: 2,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        for plan in ranked {
            XCTAssertLessThanOrEqual(plan.daysPerWeek, 2,
                                     "\(plan.name) hat \(plan.daysPerWeek) Tage > 2 — Hard-Filter hat versagt")
        }
    }

    /// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// §3): `.noEquipment` akzeptiert jetzt wie `.homeGym` auch Home-Gym-
    /// getaggte Templates — reines Gym bleibt aber in JEDEM Fall
    /// ausgeschlossen ("Ein Gym-Plan darf nicht allein deshalb zugelassen
    /// werden, weil eine Kurzhantel vorhanden ist"). Vor Phase 6 war dieser
    /// Test strenger (nur `.noEquipment` durfte durchkommen) — die Lockerung
    /// ist eine bewusste Verhaltensaenderung, siehe die positiven/negativen
    /// Gegenproben unten (`testNoEquipmentWithConfirmed...`).
    func testKOEnvFiltersOutGymPlansButAllowsHomeGym() {
        let answers = QuizAnswers(
            goal: .functional,
            experience: .beginner,
            preferredDays: 3,
            environment: .noEquipment
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        for plan in ranked {
            XCTAssertNotEqual(plan.targetEnvironment, .gym,
                           "\(plan.name) ist .gym, sollte fuer noEquipment-User raus")
        }
    }

    /// Positiv-Fall Pflicht-Test 8: ein `.noEquipment`-User mit bestaetigt
    /// VORHANDENEN Kurzhanteln soll ein Home-Gym-getaggtes Template finden,
    /// das tatsaechlich NUR Kurzhanteln braucht — "nicht nur durch den
    /// Ortsfilter ausgeschlossen" (Vorgabe woertlich). Synthetisches
    /// Template statt eines Katalog-Eintrags: `home_gym_hero` (einziges
    /// echtes Kurzhantel-Home-Gym-Template) braucht zusaetzlich eine Bank
    /// ("Bankdrücken (KH)") und waere damit kein sauberer Beleg fuer GENAU
    /// diese Kombination.
    func testNoEquipmentWithConfirmedDumbbellsDiscoversCompatibleHomeGymTemplate() {
        let dumbbellOnlyHomeGymDay = DaySpec(
            name: "Ganzkörper", type: .fullBody, sequenceIndex: 1,
            exercises: [
                ExerciseSpec(name: "Schulterdrücken (KH)", sets: 3, repsMin: 8, repsMax: 12),
                ExerciseSpec(name: "Rumänisches Kreuzheben (KH)", sets: 3, repsMin: 10, repsMax: 12)
            ]
        )
        let template = ProgramTemplate(
            id: "test_dumbbell_only_homegym", name: "Test", tagline: "Test", descriptionText: "Test", focus: "Test",
            daysPerWeek: 1, days: [dumbbellOnlyHomeGymDay], targetEnvironment: .homeGym
        )
        var profile = UserEquipmentProfile()
        profile.availability[.dumbbell] = .available
        profile.counts[.dumbbell] = 2
        profile.confirmRemainingAsUnavailable()
        let answers = QuizAnswers(
            goal: .hypertrophy, experience: .beginner, preferredDays: 3, environment: .noEquipment,
            equipmentProfile: profile
        )
        let result = PlanMatchmaker.rankPlansDetailed(for: answers, templates: [template])
        XCTAssertFalse(result.isFallback)
        XCTAssertTrue(result.templates.contains { $0.id == "test_dumbbell_only_homegym" },
                      "Mit bestaetigten 2 Kurzhanteln ist dieses Home-Gym-Template fuer einen noEquipment-User ausfuehrbar und darf nicht allein wegen des Ortstags fehlen")
    }

    /// Gegenprobe/Sicherheitsnetz zu oben: ein `.noEquipment`-User, der
    /// ausdruecklich "Nur Koerpergewicht" bestaetigt hat, darf dasselbe
    /// Home-Gym-Template weiterhin NICHT angeboten bekommen — die Lockerung
    /// von `envMatches` darf niemals die orthogonale, praezise
    /// `equipmentMatches`-Pruefung aushebeln.
    func testNoEquipmentConfirmedBodyweightOnlyStillExcludesHomeGymTemplateNeedingDumbbells() {
        let dumbbellOnlyHomeGymDay = DaySpec(
            name: "Ganzkörper", type: .fullBody, sequenceIndex: 1,
            exercises: [ExerciseSpec(name: "Schulterdrücken (KH)", sets: 3, repsMin: 8, repsMax: 12)]
        )
        let template = ProgramTemplate(
            id: "test_dumbbell_only_homegym_2", name: "Test", tagline: "Test", descriptionText: "Test", focus: "Test",
            daysPerWeek: 1, days: [dumbbellOnlyHomeGymDay], targetEnvironment: .homeGym
        )
        var profile = UserEquipmentProfile()
        profile.confirmRemainingAsUnavailable()
        let answers = QuizAnswers(
            goal: .hypertrophy, experience: .beginner, preferredDays: 3, environment: .noEquipment,
            equipmentProfile: profile
        )
        let result = PlanMatchmaker.rankPlansDetailed(for: answers, templates: [template])
        XCTAssertFalse(result.templates.contains { $0.id == "test_dumbbell_only_homegym_2" },
                       "Bestaetigt 'nur Koerpergewicht' muss ein Kurzhantel-Template weiterhin ausschliessen")
    }

    /// Pflicht-Test 7: Widerstandsband analog zu den Kurzhanteln oben — echte
    /// Katalog-Uebungen ("Band Pull-Aparts"/"Banded Squats"), die
    /// ausschliesslich `.resistanceBand` verlangen.
    func testNoEquipmentWithConfirmedResistanceBandDiscoversCompatibleHomeGymTemplate() {
        let bandOnlyDay = DaySpec(
            name: "Ganzkörper", type: .fullBody, sequenceIndex: 1,
            exercises: [
                ExerciseSpec(name: "Band Pull-Aparts", sets: 3, repsMin: 15, repsMax: 20),
                ExerciseSpec(name: "Banded Squats", sets: 3, repsMin: 15, repsMax: 20)
            ]
        )
        let template = ProgramTemplate(
            id: "test_band_only_homegym", name: "Test", tagline: "Test", descriptionText: "Test", focus: "Test",
            daysPerWeek: 1, days: [bandOnlyDay], targetEnvironment: .homeGym
        )
        var profile = UserEquipmentProfile()
        profile.availability[.resistanceBand] = .available
        profile.confirmRemainingAsUnavailable()
        let answers = QuizAnswers(
            goal: .hypertrophy, experience: .beginner, preferredDays: 3, environment: .noEquipment,
            equipmentProfile: profile
        )
        let result = PlanMatchmaker.rankPlansDetailed(for: answers, templates: [template])
        XCTAssertFalse(result.isFallback)
        XCTAssertTrue(result.templates.contains { $0.id == "test_band_only_homegym" },
                      "Mit bestaetigtem Widerstandsband ist dieses Template fuer einen noEquipment-User ausfuehrbar")
    }

    /// Home-Gym-User → kein reines Gym-Programm sollte durchkommen, aber
    /// Bodyweight-Plaene (.noEquipment) bleiben drin.
    func testHomeGymUserAcceptsHomeGymAndBodyweight() {
        let answers = QuizAnswers(
            goal: .hypertrophy,
            experience: .beginner,
            preferredDays: 3,
            environment: .homeGym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        for plan in ranked {
            XCTAssertNotEqual(plan.targetEnvironment, .gym,
                              "\(plan.name) ist .gym, sollte fuer HomeGym-User raus")
        }
    }

    /// Ergebnis-Sortierung: Goal-Match (+3) schlaegt Experience-Match (+2)
    /// schlaegt exakte Day-Count (+1). Plan mit Goal + Experience + exakter
    /// Day-Count rankt hoeher als Plan mit nur Goal.
    func testScoreOrderingMostMatchesFirst() {
        let answers = QuizAnswers(
            goal: .strength,
            experience: .intermediate,
            preferredDays: 3,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        XCTAssertFalse(ranked.isEmpty)
        // Top-Plan muss mindestens das Goal teilen.
        XCTAssertTrue(ranked.first!.targetGoals.contains(.strength),
                      "Top-Match muss das User-Goal beruehren")
    }

    /// Fix "Doppelte Abnehmen-Semantik": eine fruehere Phase-2-Fassung hatte
    /// Templates mit `.fatloss` getaggt, waehrend Quiz/Persistenz `.weightLoss`
    /// nutzten — zwei Enum-Faelle fuer dieselbe Sache, Abnehmen-User bekamen
    /// dadurch NIE einen Ziel-Matchbonus. `.fatloss` ist entfernt, alle
    /// Templates taggen jetzt `.weightLoss`.
    func testWeightLossGoalGetsTemplateMatchBonusAndTopsWithFatburnPlan() {
        let answers = QuizAnswers(
            goal: .weightLoss,
            experience: .beginner,
            preferredDays: 3,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        XCTAssertFalse(ranked.isEmpty)
        XCTAssertTrue(ranked.contains { $0.targetGoals.contains(.weightLoss) },
                      "Mindestens ein Template muss .weightLoss tragen und so den Zielbonus bekommen")
        XCTAssertEqual(ranked.first?.id, "fat_loss_fullbody",
                       "Top-Match fuer Abnehmen sollte das Fatburn-Ganzkoerper-Template sein, ist: \(ranked.first?.id ?? "nil")")
    }

    // MARK: Fix "doppeltes Onboarding" — Persona-Tests (ExperienceTrack statt Quiz)

    /// Persona "Abnehmen, 3 Tage, Gym, Starter" -> Ganzkoerper-Plan
    /// (Fatburn-Ganzkoerper). `experienceTrack` nutzt hier den echten
    /// Pfad ueber `asExperienceLevel`, nicht eine hart eingesetzte
    /// `ExperienceLevel` — so wie es die Onboarding-UI jetzt tut.
    func testStarterWeightLossThreeDaysGymTopsWithFullBodyPlan() {
        let track = ExperienceTrack.starter
        let answers = QuizAnswers(
            goal: .weightLoss,
            experience: track.asExperienceLevel,
            preferredDays: 3,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: track)
        XCTAssertEqual(ranked.first?.id, "fat_loss_fullbody")
    }

    /// Persona "Muskelaufbau, 5 Tage, Gym, Erfahren" -> Split-Plan (Bro
    /// Split ist das einzige Template mit genau 5 Tagen, das zusaetzlich
    /// Hypertrophie UND Intermediate/Advanced traegt).
    func testExperiencedHypertrophyFiveDaysGymTopsWithSplitPlan() {
        let track = ExperienceTrack.experienced
        let answers = QuizAnswers(
            goal: .hypertrophy,
            experience: track.asExperienceLevel,
            preferredDays: 5,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: track)
        XCTAssertEqual(ranked.first?.id, "bro_split")
    }

    /// Harter Filter: ein Starter sieht `arnold_split` (reiner Expertenplan,
    /// `targetExperience: [.advanced]`) ueberhaupt nicht in der Liste, auch
    /// nicht weit hinten — unabhaengig vom Score.
    func testStarterNeverSeesExpertOnlyPlans() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .beginner, preferredDays: 6, environment: .gym)
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: .starter)
        XCTAssertFalse(ranked.contains { $0.id == "arnold_split" })
    }

    /// Ohne `experienceTrack` (Default `nil`, z.B. bestehende Aufrufer) bleibt
    /// der reine Expertenplan weiterhin sichtbar — der harte Filter ist
    /// optional, kein globales Verhalten.
    func testExpertOnlyPlanStaysVisibleWithoutExperienceTrack() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .beginner, preferredDays: 6, environment: .gym)
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        XCTAssertTrue(ranked.contains { $0.id == "arnold_split" })
    }

    // MARK: Fix "Badge fast ueberall" — matchReasons

    func testMatchReasonsAreTrueOnlyForActualMatches() {
        let answers = QuizAnswers(
            goal: .strength, experience: .intermediate, preferredDays: 3, environment: .gym,
            equipmentPreferences: [.barbell]
        )
        guard let template = allTemplates.first(where: { $0.id == "powerlifting_3x5" }) else {
            return XCTFail("powerlifting_3x5 template not found")
        }
        let reasons = PlanMatchmaker.matchReasons(for: template, answers: answers)
        XCTAssertTrue(reasons.goalMatch, "powerlifting_3x5 tags .strength")
        XCTAssertTrue(reasons.daysMatch, "powerlifting_3x5 runs 3 days")
        XCTAssertTrue(reasons.levelMatch, "powerlifting_3x5 tags .intermediate")
        XCTAssertTrue(reasons.equipmentMatch, "Nutzer hat Equipment-Praeferenzen gepflegt")
    }

    /// Equipment ist bereits ein harter K.O.-Filter — das Badge ist nur dann
    /// aussagekraeftig, wenn der Nutzer ueberhaupt Praeferenzen gepflegt hat
    /// (leeres Set = "nicht gepflegt", siehe `QuizAnswers.equipmentPreferences`).
    func testMatchReasonsEquipmentMatchIsFalseWithoutMaintainedPreferences() {
        let answers = QuizAnswers(goal: .strength, experience: .intermediate, preferredDays: 3, environment: .gym)
        guard let template = allTemplates.first(where: { $0.id == "powerlifting_3x5" }) else {
            return XCTFail("powerlifting_3x5 template not found")
        }
        let reasons = PlanMatchmaker.matchReasons(for: template, answers: answers)
        XCTAssertFalse(reasons.equipmentMatch, "leeres Equipment-Set heisst 'nicht gepflegt', kein Treffer")
    }

    func testMatchReasonsAreFalseWhenNothingMatches() {
        // powerlifting_3x5 tagt targetGoals: [.strength], targetExperience:
        // [.intermediate, .advanced], daysPerWeek: 3 — .weightLoss/.beginner/6
        // treffen keins davon.
        let answers = QuizAnswers(goal: .weightLoss, experience: .beginner, preferredDays: 6, environment: .gym)
        guard let template = allTemplates.first(where: { $0.id == "powerlifting_3x5" }) else {
            return XCTFail("powerlifting_3x5 template not found")
        }
        let reasons = PlanMatchmaker.matchReasons(for: template, answers: answers)
        XCTAssertFalse(reasons.goalMatch, "powerlifting_3x5 tags only .strength, not .weightLoss")
        XCTAssertFalse(reasons.daysMatch, "powerlifting_3x5 runs 3 days, not 6")
        XCTAssertFalse(reasons.levelMatch, "powerlifting_3x5 does not tag .beginner")
    }

    // MARK: Fix "doppeltes Onboarding" — Fallback respektiert ExperienceTrack

    /// Der Fallback-Pfad (alles rausgefiltert) muss den experienceTrack-
    /// Filter weiterhin respektieren: `crossfit_bodyweight_rx` ist
    /// `.noEquipment` aber `targetExperience: [.advanced]` — ein Starter im
    /// Fallback darf ihn nicht vorgeschlagen bekommen.
    func testFallbackRespectsExperienceTrackWhenPossible() {
        // Extremfilter wie testFallbackProducesBodyweightPlansWhenAllFiltered,
        // zusaetzlich als Starter.
        let answers = QuizAnswers(goal: .strength, experience: .advanced, preferredDays: 2, environment: .noEquipment)
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: .starter)
        XCTAssertFalse(ranked.isEmpty, "Fallback sollte weiterhin mindestens einen Plan liefern")
        XCTAssertFalse(ranked.contains { $0.id == "crossfit_bodyweight_rx" },
                       "crossfit_bodyweight_rx ist reiner Expertenplan, darf im Starter-Fallback nicht auftauchen")
        XCTAssertTrue(ranked.allSatisfy { $0.targetEnvironment == .noEquipment })
    }

    /// Smart-Onboarding-Epic Phase 4: "auch im Fallback bestaetigte
    /// Equipment-Grenzen respektieren". `crossfit_bodyweight_rx` ist zwar
    /// `.noEquipment`-getaggt, braucht aber tatsaechlich eine Klimmzugstange
    /// ("Klimmzüge") — sein eigenes Geschwister-Template
    /// `crossfit_bodyweight_scaled` ersetzt genau diese Uebung durch
    /// Handtuch-Rudern. Ein Nutzer mit bestaetigt FEHLENDER Klimmzugstange
    /// darf `crossfit_bodyweight_rx` deshalb auch im Fallback-Pfad nicht
    /// vorgeschlagen bekommen.
    func testFallbackRespectsConfirmedMissingPullUpBarEvenForNoEquipmentTemplates() {
        var profile = UserEquipmentProfile()
        profile.confirmRemainingAsUnavailable()
        let answers = QuizAnswers(
            goal: .strength, experience: .advanced, preferredDays: 1, environment: .noEquipment,
            equipmentProfile: profile
        )
        let result = PlanMatchmaker.rankPlansDetailed(for: answers, templates: allTemplates)
        XCTAssertTrue(result.isFallback, "Vorbedingung: 1 Tag + Advanced ohne Track muss die Hard-Filter leerlaufen lassen")
        XCTAssertFalse(result.templates.contains { $0.id == "crossfit_bodyweight_rx" },
                        "Braucht eine bestaetigt fehlende Klimmzugstange — darf auch im Fallback nicht erscheinen")
        XCTAssertTrue(result.templates.contains { $0.id == "crossfit_bodyweight_scaled" },
                       "Das klimmzugstangen-freie Geschwister-Template bleibt ein gueltiger Fallback-Kandidat")
    }

    /// Gegenprobe: eine bestaetigt VORHANDENE Klimmzugstange laesst
    /// `crossfit_bodyweight_rx` im selben Extremfilter weiterhin zu.
    func testFallbackAllowsPullUpBarTemplateWhenConfirmedAvailable() {
        var profile = UserEquipmentProfile()
        profile.availability[.pullUpBar] = .available
        profile.confirmRemainingAsUnavailable()
        let answers = QuizAnswers(
            goal: .strength, experience: .advanced, preferredDays: 1, environment: .noEquipment,
            equipmentProfile: profile
        )
        let result = PlanMatchmaker.rankPlansDetailed(for: answers, templates: allTemplates)
        XCTAssertTrue(result.templates.contains { $0.id == "crossfit_bodyweight_rx" })
    }

    /// Fallback: Extrem-Filter "Strength + No-Equipment + 2 Tage" wuerde
    /// nichts treffen → wir liefern wenigstens die BW-Plaene zurueck.
    func testFallbackProducesBodyweightPlansWhenAllFiltered() {
        let answers = QuizAnswers(
            goal: .strength,
            experience: .advanced,
            preferredDays: 2,
            environment: .noEquipment
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        XCTAssertFalse(ranked.isEmpty, "Fallback sollte mindestens einen BW-Plan liefern")
        XCTAssertTrue(ranked.allSatisfy { $0.targetEnvironment == .noEquipment })
    }

    // MARK: - UX-Fix "Empfehlung wirkt immer gleich" — Persona-Matrix
    //
    // Reproduzierbare Faelle aus ONBOARDING_MATCHING_AND_UX_FIX.md, VOR dem
    // eigentlichen Fix angelegt (wie dort explizit gefordert), um den echten
    // Status quo zu dokumentieren statt eine vermutete Ursache blind zu
    // fixen. Jeder Fall prueft Top-1 UND (wo sinnvoll) `matchReasons`.

    /// Starter, Gym, Muskelaufbau, 3 Tage -> einfacher Ganzkoerperplan ist
    /// laut Spec RICHTIG (keine kuenstliche Vielfalt fuer Starter erzwingen).
    func testPersonaStarterHypertrophyThreeDaysGymTopsWithSimpleFullBody() {
        let track = ExperienceTrack.starter
        let answers = QuizAnswers(
            goal: .hypertrophy,
            experience: track.asExperienceLevel,
            preferredDays: 3,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: track)
        XCTAssertEqual(ranked.first?.id, "full_body",
                        "Starter+Hypertrophie+3 Tage sollte der einfache Ganzkoerperplan sein, ist: \(ranked.first?.id ?? "nil")")
        let reasons = PlanMatchmaker.matchReasons(for: ranked.first!, answers: answers)
        XCTAssertTrue(reasons.goalMatch && reasons.daysMatch && reasons.levelMatch)
    }

    /// Returner, Gym, Kraft, 3 Tage -> ein wiedereinstiegs-tauglicher,
    /// kraftfokussierter Plan (Powerlifting 5x5 ist das einzige Template mit
    /// .strength + Beginner/Intermediate-Tag bei 3 Tagen). Keine Phase-4-
    /// Rampe wird hier vorgetaeuscht - nur Kandidat + Begruendung.
    func testPersonaReturnerStrengthThreeDaysGymTopsWithBeginnerFriendlyStrengthPlan() {
        let track = ExperienceTrack.returner
        let answers = QuizAnswers(
            goal: .strength,
            experience: track.asExperienceLevel,
            preferredDays: 3,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: track)
        XCTAssertEqual(ranked.first?.id, "powerlifting_5x5",
                        "Returner+Kraft+3 Tage sollte der Einsteiger/Intermediate-Kraftplan sein, ist: \(ranked.first?.id ?? "nil")")
    }

    /// Experienced, Gym, Muskelaufbau, 5 Tage -> Split-Plan, NIEMALS
    /// "Ganzkoerper 3x" als Top 1 (Duplikat zu
    /// `testExperiencedHypertrophyFiveDaysGymTopsWithSplitPlan` oben, hier
    /// bewusst nochmal explizit als Teil der zusammenhaengenden Persona-
    /// Matrix aus dem UX-Fix-Dokument gefuehrt).
    func testPersonaExperiencedHypertrophyFiveDaysGymNeverTopsWithFullBody() {
        let track = ExperienceTrack.experienced
        let answers = QuizAnswers(
            goal: .hypertrophy,
            experience: track.asExperienceLevel,
            preferredDays: 5,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: track)
        XCTAssertNotEqual(ranked.first?.id, "full_body")
        XCTAssertEqual(ranked.first?.id, "bro_split")
    }

    /// Experienced, Gym, Kraft, 4 Tage -> Upper-Lower-Split (einziges
    /// 4-Tage-Template mit .strength-Tag) vor 3-Tage-Ganzkoerper.
    func testPersonaExperiencedStrengthFourDaysGymTopsWithFourDaySplit() {
        let track = ExperienceTrack.experienced
        let answers = QuizAnswers(
            goal: .strength,
            experience: track.asExperienceLevel,
            preferredDays: 4,
            environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: track)
        XCTAssertEqual(ranked.first?.id, "upper_lower",
                        "Experienced+Kraft+4 Tage sollte der 4-Tage-Split sein, ist: \(ranked.first?.id ?? "nil")")
        XCTAssertNotEqual(ranked.first?.id, "full_body")
    }

    /// Experienced, Home-Gym, 3 Tage -> ein passender Home-Gym- oder
    /// Ganzkoerperplan DARF gewinnen (Spec: "keine kuenstliche Vielfalt
    /// erzwingen" bei 2-3 Tagen) - Pruefung zielt nur auf Environment-
    /// Korrektheit (kein reines .gym-Template) und ein nicht-leeres Ergebnis.
    func testPersonaExperiencedHomeGymThreeDaysAllowsFullBodyOrHomeGymPlan() {
        let track = ExperienceTrack.experienced
        let answers = QuizAnswers(
            goal: .hypertrophy,
            experience: track.asExperienceLevel,
            preferredDays: 3,
            environment: .homeGym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: track)
        XCTAssertFalse(ranked.isEmpty)
        XCTAssertNotEqual(ranked.first?.targetEnvironment, .gym,
                           "Home-Gym-User sollte kein reines .gym-Template als Top-Match bekommen")
    }

    /// No Equipment, 3 Tage -> Bodyweight-Plan (Environment-Hard-Filter).
    func testPersonaNoEquipmentThreeDaysTopsWithBodyweightPlan() {
        let answers = QuizAnswers(
            goal: .functional,
            experience: .beginner,
            preferredDays: 3,
            environment: .noEquipment
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: .starter)
        XCTAssertFalse(ranked.isEmpty)
        XCTAssertEqual(ranked.first?.targetEnvironment, .noEquipment)
    }

    // MARK: - UX-Fix Punkt 5 — rankPlansDetailed.isFallback

    /// Normalfall: `isFallback` ist `false`, solange die Hard-Filter nicht
    /// ALLES rausgefiltert haben.
    func testRankPlansDetailedIsNotFallbackForNormalMatch() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .intermediate, preferredDays: 3, environment: .gym)
        let result = PlanMatchmaker.rankPlansDetailed(for: answers, templates: allTemplates)
        XCTAssertFalse(result.isFallback)
        XCTAssertEqual(result.templates.first?.id, "full_body")
    }

    /// Extremfilter (wie `testFallbackProducesBodyweightPlansWhenAllFiltered`)
    /// -> `isFallback` ist `true`. Die UI nutzt das, um statt "Empfohlen fuer
    /// dich" transparent "Beste verfuegbare Option mit deinen Angaben" zu
    /// zeigen (Epic Problem 1, Punkt 5).
    func testRankPlansDetailedFlagsFallback() {
        let answers = QuizAnswers(goal: .strength, experience: .advanced, preferredDays: 2, environment: .noEquipment)
        let result = PlanMatchmaker.rankPlansDetailed(for: answers, templates: allTemplates)
        XCTAssertTrue(result.isFallback)
        XCTAssertFalse(result.templates.isEmpty)
    }

    /// `rankPlans` (die bestehende einfache Schnittstelle) bleibt
    /// unveraendert identisch zu `rankPlansDetailed(...).templates`.
    func testRankPlansMatchesRankPlansDetailedTemplates() {
        let answers = QuizAnswers(goal: .hybrid, experience: .intermediate, preferredDays: 5, environment: .gym)
        let simple = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates)
        let detailed = PlanMatchmaker.rankPlansDetailed(for: answers, templates: allTemplates)
        XCTAssertEqual(simple, detailed.templates)
    }

    // MARK: - Plan-Katalog-Audit (PLAN_CATALOG_AUDIT_AND_MATCHING.md) — Regressionen

    /// Reproduktion Befund 1+8 (`docs/PLAN_CATALOG_AUDIT.md`): ein Gym-Nutzer
    /// mit NUR Maschinen/Kabelzug (keine Langhantel/Kurzhantel) darf
    /// `push_pull_legs` (braucht laut Audit 40 Langhantel- + 30
    /// Kurzhantel-Saetze/Woche) nicht als passend angezeigt bekommen — vor
    /// dem Fix liess `equipmentMatches` jedes Template ohne
    /// `equipmentVariants` ungeprueft durch.
    func testMachineOnlyGymUserDoesNotMatchBarbellHeavyPushPullLegs() {
        let answers = QuizAnswers(
            goal: .hypertrophy, experience: .advanced, preferredDays: 6, environment: .gym,
            equipmentPreferences: [.machine, .cable]
        )
        let result = PlanMatchmaker.rankPlansDetailed(for: answers, templates: allTemplates)
        XCTAssertFalse(result.templates.contains { $0.id == "push_pull_legs" },
                        "push_pull_legs braucht echte Langhanteln/Kurzhanteln, die der Nutzer nicht hat")
    }

    /// Gegenprobe zum vorigen Test: mit einem vollstaendigen Equipment-Set
    /// bleibt `push_pull_legs` weiterhin erreichbar — der neue Equipment-
    /// Check blockiert nur, wenn tatsaechlich etwas fehlt.
    func testFullyEquippedGymUserStillMatchesPushPullLegs() {
        let answers = QuizAnswers(
            goal: .hypertrophy, experience: .advanced, preferredDays: 6, environment: .gym,
            equipmentPreferences: [.barbell, .dumbbell, .cable, .machine, .bodyweight]
        )
        let result = PlanMatchmaker.rankPlansDetailed(for: answers, templates: allTemplates)
        XCTAssertTrue(result.templates.contains { $0.id == "push_pull_legs" })
    }

    /// Reproduktion Befund 2: das Equipment-Badge darf fuer ein Template, das
    /// tatsaechlich NICHT zum gepflegten Equipment passt, nicht mehr
    /// anzeigen — vorher reichte "ueberhaupt irgendeine Praeferenz gepflegt".
    func testMatchReasonsEquipmentMatchIsFalseWhenTemplateActuallyNeedsMoreEquipment() {
        let answers = QuizAnswers(
            goal: .hypertrophy, experience: .advanced, preferredDays: 6, environment: .gym,
            equipmentPreferences: [.machine, .cable]
        )
        guard let template = allTemplates.first(where: { $0.id == "push_pull_legs" }) else {
            return XCTFail("push_pull_legs template not found")
        }
        let reasons = PlanMatchmaker.matchReasons(for: template, answers: answers)
        XCTAssertFalse(reasons.equipmentMatch,
                        "Nutzer hat zwar Praeferenzen gepflegt, aber push_pull_legs braucht Langhantel/Kurzhantel, die fehlen")
    }

    /// `requiredEquipment(for:)` leitet das Equipment korrekt aus den
    /// referenzierten Uebungen her und ignoriert `.bodyweight` als
    /// Anforderung (dafuer muss niemand etwas besitzen).
    func testRequiredEquipmentDerivesFromExercisesAndIgnoresBodyweight() {
        guard let pushPullLegs = allTemplates.first(where: { $0.id == "push_pull_legs" }) else {
            return XCTFail("push_pull_legs template not found")
        }
        let required = PlanMatchmaker.requiredEquipment(for: pushPullLegs)
        XCTAssertTrue(required.contains(.barbell))
        XCTAssertTrue(required.contains(.dumbbell))
        XCTAssertTrue(required.contains(.cable))
        XCTAssertTrue(required.contains(.machine))
        XCTAssertFalse(required.contains(.bodyweight), "Bodyweight ist keine Beschaffungs-Anforderung")
    }

    /// Reproduktion Befund 3 + Regression Nr. 6 aus der Vorgabe: ein Starter
    /// mit 6 frei verfuegbaren Tagen darf keinen reinen Intermediate/Advanced-
    /// Plan wie Push-Pull-Legs automatisch vorgeschlagen bekommen, nur weil
    /// `.intermediate` im Tag steht — `.beginner` muss explizit vorhanden sein.
    func testStarterWithSixFreeDaysDoesNotGetHighVolumeIntermediatePPL() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .beginner, preferredDays: 6, environment: .gym)
        let result = PlanMatchmaker.rankPlansDetailed(for: answers, templates: allTemplates, experienceTrack: .starter)
        XCTAssertFalse(result.templates.contains { $0.id == "push_pull_legs" })
        XCTAssertFalse(result.templates.contains { $0.id == "upper_lower" })
        XCTAssertFalse(result.templates.contains { $0.id == "bro_split" })
        XCTAssertFalse(result.templates.contains { $0.id == "powerlifting_3x5" })
    }

    /// Regression Nr. 3 aus der Vorgabe: bei 6 Tagen ist Push-Pull-Legs ein
    /// gueltiger Kandidat fuer Erfahrene — kein impliziter Ausschluss nur
    /// weil Arnold Split ebenfalls 6 Tage hat (der Tage-Bonus ist entfernt,
    /// siehe `ExperienceTrackTests`).
    func testExperiencedSixDaysHypertrophyIncludesPushPullLegsAsCandidate() {
        let track = ExperienceTrack.experienced
        let answers = QuizAnswers(
            goal: .hypertrophy, experience: track.asExperienceLevel, preferredDays: 6, environment: .gym
        )
        let ranked = PlanMatchmaker.rankPlans(for: answers, templates: allTemplates, experienceTrack: track)
        XCTAssertTrue(ranked.contains { $0.id == "push_pull_legs" })
    }

    // MARK: - Szenario 8 (PLAN_MATCHING_AND_EQUIPMENT_COMBINED.md)

    /// Direkter Unit-Test fuer `goalIsSupportedButNotPrimaryFocus`: nur
    /// `.weightLoss` qualifiziert, und nur Templates mit echtem Hypertrophie-
    /// /Kraft-Fokus — keine pauschale Freigabe (Epic-Vorgabe) und kein
    /// Zusatzpunkt fuer Funktional-/Zirkel-Ziele, die bereits ueber den
    /// Primaerfokus-Term zaehlen, falls selbst `.weightLoss`-getaggt.
    func testGoalIsSupportedButNotPrimaryFocusOnlyForWeightLossWithStrengthOrHypertrophyFocus() {
        let upperLower = allTemplates.first { $0.id == "upper_lower" }!      // [.hypertrophy, .strength]
        let crossfitWeighted = allTemplates.first { $0.id == "crossfit_weighted" }! // [.functional, .weightLoss]

        XCTAssertTrue(
            PlanMatchmaker.goalIsSupportedButNotPrimaryFocus(.weightLoss, of: upperLower),
            "Kraft-/Hypertrophie-Split unterstuetzt Abnehmen inhaltlich (Kaloriendefizit)"
        )
        XCTAssertFalse(
            PlanMatchmaker.goalIsSupportedButNotPrimaryFocus(.weightLoss, of: crossfitWeighted),
            "Hat bereits einen echten .weightLoss-Tag -> zaehlt ueber den Primaerfokus-Term, nicht hier"
        )
        XCTAssertFalse(
            PlanMatchmaker.goalIsSupportedButNotPrimaryFocus(.hypertrophy, of: upperLower),
            "Nur fuer .weightLoss aktiv — kein analoger Unterstuetzungs-Gedanke fuer andere Ziele"
        )
        XCTAssertFalse(
            PlanMatchmaker.goalIsSupportedButNotPrimaryFocus(.weightLoss, of: allTemplates.first { $0.id == "kettlebell_beginner" }!),
            "Funktionales Zirkel-Programm ohne Hypertrophie-/Kraft-Fokus bekommt keinen Support-Punkt"
        )
    }

    /// Woertliche Reproduktion von Szenario 8: "regelmaessig trainiert,
    /// Abnehmen, Gym, 4 Tage" durfte auf einem echten Geraet "CrossFit mit
    /// Gewichten" als Top-Empfehlung liefern, mit Upper-Lower (einzigem
    /// Kandidaten mit exakt 4 Tagen) komplett ausserhalb der gezeigten
    /// Alternativen. Fix: Upper-Lower muss jetzt vor allen praeferenz-
    /// getriebenen Zirkel-/CrossFit-Templates ranken, CrossFit darf nicht
    /// mehr die Top-Position belegen.
    func testScenario8ExperiencedWeightLossGymFourDaysRanksStrengthSplitAboveCircuitPreferencePrograms() {
        let track = ExperienceTrack.experienced
        let answers = QuizAnswers(
            goal: .weightLoss,
            experience: track.asExperienceLevel,
            preferredDays: 4,
            environment: .gym
        )
        let result = PlanMatchmaker.rankPlansDetailed(for: answers, templates: allTemplates, experienceTrack: track)
        XCTAssertFalse(result.isFallback)

        let ids = result.templates.map(\.id)
        guard let upperLowerRank = ids.firstIndex(of: "upper_lower") else {
            return XCTFail("upper_lower muss als Kandidat auftauchen (4 Tage, Gym, Erfahren)")
        }
        XCTAssertNotEqual(ids.first, "crossfit_weighted",
                           "CrossFit darf bei 'Abnehmen' nicht automatisch die Top-Empfehlung sein — das ist eine Trainingspraeferenz, keine Zielkonsequenz")
        if let crossfitRank = ids.firstIndex(of: "crossfit_weighted") {
            XCTAssertLessThan(upperLowerRank, crossfitRank,
                               "Ein zu den Tagen exakt passender Kraft-Split darf nicht hinter einem CrossFit-Programm ohne explizite Praeferenz liegen")
        }
        if let kettlebellRank = ids.firstIndex(of: "kettlebell_beginner") {
            XCTAssertLessThan(upperLowerRank, kettlebellRank,
                               "Ein zu den Tagen exakt passender Kraft-Split darf nicht hinter einem Kettlebell-Zirkel-Programm ohne explizite Praeferenz liegen")
        }
    }

    // MARK: - resolvedDays (PLAN_EQUIPMENT_MATCHING_AUDIT.md 5.4)

    /// Gemeinsame Quelle fuer Vorschau (`TemplatePreviewView.orderedDays`)
    /// und tatsaechliche Instanziierung (`ProgramInstantiator.instantiate`)
    /// — vorher duplizierte Logik, die auseinanderlaufen konnte (Fix siehe
    /// Audit-Dokument). Direkter Test gegen das echte Katalog-Template
    /// `hybrid_balanced`, das eine `.dumbbellOnly`-Variante hat.
    func testResolvedDaysUsesBaseVariantWithoutEquipmentPreferences() {
        let template = allTemplates.first { $0.id == "hybrid_balanced" }!
        let days = template.resolvedDays(forUserEquipment: [])
        XCTAssertEqual(days.first?.exercises.first?.name, "Bankdrücken",
                       "Leeres Equipment-Set -> Basis-/Barbell-Variante (bestehendes Verhalten)")
    }

    func testResolvedDaysUsesBaseVariantWhenBarbellGymSatisfied() {
        let template = allTemplates.first { $0.id == "hybrid_balanced" }!
        let days = template.resolvedDays(forUserEquipment: [.barbell, .dumbbell, .machine])
        XCTAssertEqual(days.first?.exercises.first?.name, "Bankdrücken")
    }

    func testResolvedDaysSwitchesToDumbbellVariantWhenBarbellMissing() {
        let template = allTemplates.first { $0.id == "hybrid_balanced" }!
        let days = template.resolvedDays(forUserEquipment: [.dumbbell])
        XCTAssertEqual(days.first?.exercises.first?.name, "Bankdrücken (KH)",
                       "Ohne Langhantel muss dieselbe Variante gewaehlt werden wie beim Instanziieren — das war der Vorschau/Instanziierung-Bug aus Abschnitt 5.4")
    }

    func testResolvedDaysFallsBackToBaseWhenNoVariantFitsAndTemplateHasNoVariants() {
        let template = allTemplates.first { $0.id == "upper_lower" }! // keine equipmentVariants
        let days = template.resolvedDays(forUserEquipment: [.dumbbell])
        XCTAssertEqual(days, template.days, "Ohne equipmentVariants bleibt es immer bei der Basis-Liste")
    }

    // MARK: - Vor Phase 4 (PLAN_EQUIPMENT_MATCHING_AUDIT.md): "bestaetigt leer" vs. "unbekannt"

    /// Direkte Antwort auf die Rueckfrage, ob "Nur Koerpergewicht bestaetigt"
    /// und "Ausstattung unbekannt" im Matcher beide als "kein Filter" gelten:
    /// NEIN. `[]` (nicht gepflegt) nimmt den fruehen Ausstieg in
    /// `equipmentMatches` und laesst jedes Template durch. `{.bodyweight}`
    /// (das `UserEquipmentProfile.legacyEquipmentPreferences` nach einer
    /// "Nur Koerpergewicht"-Bestaetigung liefert, siehe
    /// `EquipmentRequirementTests.testLegacyEquipmentPreferencesAlwaysIncludesBodyweight`)
    /// ist NICHT leer und durchlaeuft die echte Pruefung — geprueft sowohl
    /// fuer den aus Uebungen hergeleiteten Pfad (`push_pull_legs`, keine
    /// `equipmentVariants`) als auch den `equipmentVariants`-Pfad
    /// (`hybrid_balanced`: keines der vier `EquipmentProfile`-Anforderungs-
    /// Sets ist mit reinem Koerpergewicht erreichbar).
    func testEmptyEquipmentIsNoFilterButConfirmedBodyweightOnlyActuallyFilters() {
        let unknown = QuizAnswers(
            goal: .hypertrophy, experience: .advanced, preferredDays: 6, environment: .gym,
            equipmentPreferences: []
        )
        let confirmedBodyweightOnly = QuizAnswers(
            goal: .hypertrophy, experience: .advanced, preferredDays: 6, environment: .gym,
            equipmentPreferences: [.bodyweight]
        )

        let unknownResult = PlanMatchmaker.rankPlansDetailed(for: unknown, templates: allTemplates)
        XCTAssertTrue(unknownResult.templates.contains { $0.id == "push_pull_legs" },
                      "Unbekannte Ausstattung ist 'nicht gepflegt' -> kein Equipment-Filter (hergeleiteter Pfad)")
        XCTAssertTrue(unknownResult.templates.contains { $0.id == "hybrid_balanced" },
                      "Unbekannte Ausstattung ist 'nicht gepflegt' -> kein Equipment-Filter (Variant-Pfad)")

        let bodyweightResult = PlanMatchmaker.rankPlansDetailed(for: confirmedBodyweightOnly, templates: allTemplates)
        XCTAssertFalse(bodyweightResult.templates.contains { $0.id == "push_pull_legs" },
                       "Bestaetigtes 'Nur Koerpergewicht' ist NICHT leer und muss Langhantel/Kurzhantel-Anforderungen durchsetzen")
        XCTAssertFalse(bodyweightResult.templates.contains { $0.id == "hybrid_balanced" },
                       "Keine der vier EquipmentProfile-Varianten ist mit reinem Koerpergewicht erreichbar")
    }
}
