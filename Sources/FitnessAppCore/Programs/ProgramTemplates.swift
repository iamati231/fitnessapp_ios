import Foundation

/// All shipped program templates. Order = display order in the picker.
///
/// DEL-088 (Rolling Days): Templates enthalten NUR Trainings-Tage, sortiert
/// nach `sequenceIndex` (1, 2, 3, ...). Der `ProgramInstantiator` mappt
/// diese Sequenz beim Adopt auf vom User gewaehlte Apple-Calendar-Wochentage
/// und fuellt die restlichen Wochentage mit `DayType.rest` automatisch auf.
public enum ProgramTemplates {

    // MARK: - 1. Ganzkörper 3× (Beginner / Re-Entry)

    private static let fullBody = ProgramTemplate(
        id: "full_body",
        name: "Ganzkörper 3x",
        localizationKey: "plan.template.fullBody3x.name",
        tagline: "3 Tage · Anfänger & Re-Einstieg",
        taglineKey: "plan.template.fullBody3x.tagline",
        descriptionText: "Höchste Trainingsfrequenz pro Muskelgruppe. Laut Forschung optimal für Anfänger und Wiedereinstieg — maximales Signal für Muskelwachstum.",
        descriptionKey: "plan.template.fullBody3x.description",
        focus: "Anfänger / Allgemein",
        focusKey: "plan.template.fullBody3x.focus",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Ganzkörper A", localizationKey: "plan.day.fullBodyA", type: .fullBody, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 3, repsMin: 5,  repsMax: 8,  restSeconds: 180),
                ExerciseSpec(name: "Bankdrücken",                 sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 150),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Bizeps-Curl (LH)",              sets: 2, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Trizepsdrücken (Kabel)",      sets: 2, repsMin: 10, repsMax: 15, restSeconds: 75)
            ]),
            DaySpec(name: "Ganzkörper B", localizationKey: "plan.day.fullBodyB", type: .fullBody, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 3, repsMin: 4,  repsMax: 6,  restSeconds: 180),
                ExerciseSpec(name: "Schrägbankdrücken aufwärts (KH)", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Latzug (weit)",                sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Schulterdrücken (KH)",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Hammer Curl",                  sets: 2, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Dips (Trizeps)",               sets: 2, repsMin: 8,  repsMax: 12, restSeconds: 75)
            ]),
            DaySpec(name: "Ganzkörper C", localizationKey: "plan.day.fullBodyC", type: .fullBody, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Front Squat",                  sets: 3, repsMin: 6,  repsMax: 8,  restSeconds: 150),
                ExerciseSpec(name: "Hip Thrust (LH)",              sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Kabelrudern sitzend",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Seitheben",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Schrägbank-Curl (KH)",             sets: 2, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Skull Crusher",                sets: 2, repsMin: 8,  repsMax: 12, restSeconds: 75)
            ])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.strengthtraining.traditional",
        targetExperience: [.beginner, .intermediate],
        targetGoals: [.hypertrophy, .functional]
    )

    // MARK: - 2. Fatburn Ganzkörper

    private static let fatLossFullBody = ProgramTemplate(
        // DEL-169: Evidence-Rework. Vorher als "Fatburn"-Plan mit kurzen
        // 60-Sekunden-Pausen und 12–15-Reps-Mythik verpackt. Jetzt ehrlich
        // gerahmt als Cut-Phase / Defizit-Plan — Fettverlust kommt aus der
        // Kalorienbilanz, das Training erhaelt Muskel + Kraft im Defizit.
        // Rep-Ranges + Pausen folgen Standard-Hypertrophie-Evidenz
        // (Compounds 6–12 mit 120–180 s, Iso 8–15 mit 60–90 s).
        id: "fat_loss_fullbody",
        name: "Fatburn Ganzkörper",
        localizationKey: "plan.template.fatBurnFullBody.name",
        tagline: "3 Tage · Muskelerhalt im Defizit",
        taglineKey: "plan.template.fatBurnFullBody.tagline",
        descriptionText: "Fettverlust kommt aus dem Kaloriendefizit — dieser Plan schützt Muskel und Kraft im Cut: solides Hypertrophie-Volumen bei moderaten Lasten plus ein Cardio-Finisher pro Einheit. Reps und Pausen folgen Standard-Hypertrophie (6–12 bzw. 8–15, 60–180 s Pause), kein 'hohe Wdh = Fett weg'-Mythos.",
        descriptionKey: "plan.template.fatBurnFullBody.description",
        focus: "Defizit-Phase",
        focusKey: "plan.template.fatBurnFullBody.focus",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Fatburn A", localizationKey: "plan.day.fatBurnA", type: .fullBody, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 3, repsMin: 6,  repsMax: 12, restSeconds: 150),
                ExerciseSpec(name: "Bankdrücken",                 sets: 3, repsMin: 6,  repsMax: 12, restSeconds: 150),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 3, repsMin: 6,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Bizeps-Curl (LH)",              sets: 2, repsMin: 8,  repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Skull Crusher",                sets: 2, repsMin: 8,  repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Laufband",            sets: 1, repsMin: 15, repsMax: 15, restSeconds: 0, targetRir: 0, isCardio: true)
            ]),
            DaySpec(name: "Fatburn B", localizationKey: "plan.day.fatBurnB", type: .fullBody, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 3, repsMin: 6,  repsMax: 12, restSeconds: 150),
                ExerciseSpec(name: "Schrägbankdrücken aufwärts (KH)", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Latzug (weit)",                sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Schulterdrücken (KH)",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Hammer Curl",                  sets: 2, repsMin: 8,  repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Trizepsdrücken (Kabel)",      sets: 2, repsMin: 8,  repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Fahrradergometer",    sets: 1, repsMin: 15, repsMax: 15, restSeconds: 0, targetRir: 0, isCardio: true)
            ]),
            DaySpec(name: "Fatburn C", localizationKey: "plan.day.fatBurnC", type: .fullBody, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Hip Thrust (LH)",              sets: 3, repsMin: 6,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Kabelrudern sitzend",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Bankdrücken (KH)",              sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Seitheben",                    sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Beinbeuger liegend",           sets: 2, repsMin: 8,  repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Schrägbank-Curl (KH)",             sets: 2, repsMin: 8,  repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Stepper",             sets: 1, repsMin: 15, repsMax: 15, restSeconds: 0, targetRir: 0, isCardio: true)
            ])
        ],
        targetEnvironment: .gym,
        iconSystemName: "flame.fill",
        targetExperience: [.beginner, .intermediate],
        targetGoals: [.fatloss, .hypertrophy]
    )

    // MARK: - 3. Home Gym Hero (Dumbbell-only)

    private static let homeGymHero = ProgramTemplate(
        id: "home_gym_hero",
        name: "Home Gym Hero",
        localizationKey: "plan.template.homeGymHero.name",
        tagline: "3 Tage · Muskelaufbau mit Kurzhanteln",
        taglineKey: "plan.template.homeGymHero.tagline",
        descriptionText: "Effektiver Ganzkörperplan komplett mit Kurzhanteln. Ideal für das Training zuhause — kein Fitnessstudio nötig.",
        descriptionKey: "plan.template.homeGymHero.description",
        focus: "Hypertrophie",
        focusKey: "plan.template.homeGymHero.focus",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Ganzkörper A", localizationKey: "plan.day.fullBodyA", type: .fullBody, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Goblet Squat",                 sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Bankdrücken (KH)",              sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Rudern einarmig (KH)",           sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Rumänisches Kreuzheben (KH)",         sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Seitheben",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Ganzkörper B", localizationKey: "plan.day.fullBodyB", type: .fullBody, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Schrägbankdrücken aufwärts (KH)", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Chest Supported Row (KH)",     sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Schulterdrücken (KH)",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Hammer Curl",                  sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Trizepsstrecker über Kopf (KH)", sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Ganzkörper C", localizationKey: "plan.day.fullBodyC", type: .fullBody, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Rumänisches Kreuzheben (KH)",         sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Flyes flach (KH)",             sets: 3, repsMin: 12, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Pullover (KH)",                  sets: 3, repsMin: 10, repsMax: 15, restSeconds: 90),
                ExerciseSpec(name: "Ausfallschritte (KH)",           sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Bizeps-Curl (KH)",                      sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Trizepskickback (KH)",         sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60)
            ])
        ],
        targetEnvironment: .homeGym,
        iconSystemName: "house.fill",
        targetExperience: [.beginner, .intermediate],
        targetGoals: [.hypertrophy]
    )

    // MARK: - 4. Bodyweight Mastery (No Equipment)

    private static let bodyweightMastery = ProgramTemplate(
        id: "bodyweight_mastery",
        name: "Bodyweight Mastery",
        localizationKey: "plan.template.bodyweightMastery.name",
        tagline: "3 Tage · Funktionelles Training ohne Geräte",
        taglineKey: "plan.template.bodyweightMastery.tagline",
        descriptionText: "Komplettes Körpergewichtstraining ohne ein einziges Gerät. Kürzere Pausen und isometrische Übungen sorgen für maximalen Trainingsreiz.",
        descriptionKey: "plan.template.bodyweightMastery.description",
        focus: "Funktionelle Fitness",
        focusKey: "plan.template.bodyweightMastery.focus",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Push & Core", localizationKey: "plan.day.pushAndCore", type: .push, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Liegestütze",                 sets: 4, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Pike Liegestütze",            sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 60),
                ExerciseSpec(name: "Dips (Trizeps)",               sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 60),
                ExerciseSpec(name: "Plank",                        sets: 3, repsMin: 30, repsMax: 45, restSeconds: 60, targetRir: 3.0),
                ExerciseSpec(name: "Mountain Climbers",            sets: 3, repsMin: 20, repsMax: 30, restSeconds: 60)
            ]),
            DaySpec(name: "Pull & Beine", localizationKey: "plan.day.pullAndLegs", type: .fullBody, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Handtuch-Rudern (Türrahmen)", sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 75),
                ExerciseSpec(name: "Kniebeuge (BW)",               sets: 4, repsMin: 15, repsMax: 20, restSeconds: 60),
                ExerciseSpec(name: "Ausfallschritte (BW)",         sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60),
                ExerciseSpec(name: "Hip Thrust (BW)",              sets: 3, repsMin: 15, repsMax: 20, restSeconds: 60),
                ExerciseSpec(name: "Seitstütz",                   sets: 3, repsMin: 20, repsMax: 30, restSeconds: 60, targetRir: 3.0)
            ]),
            DaySpec(name: "Ganzkörper HIIT", localizationKey: "plan.day.fullBodyHIIT", type: .fullBody, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Burpees",                      sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Breite Liegestütze",          sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Jump Squat",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Mountain Climbers",            sets: 3, repsMin: 20, repsMax: 30, restSeconds: 60),
                ExerciseSpec(name: "Plank",                        sets: 3, repsMin: 30, repsMax: 45, restSeconds: 60, targetRir: 3.0)
            ])
        ],
        targetEnvironment: .noEquipment,
        iconSystemName: "figure.run",
        targetExperience: [.beginner, .intermediate],
        targetGoals: [.functional, .fatloss]
    )

    // MARK: - 5. Push-Pull-Legs (6 days)

    private static let pushPullLegs = ProgramTemplate(
        id: "push_pull_legs",
        name: "Push-Pull-Legs",
        localizationKey: "plan.template.pushPullLegs.name",
        tagline: "6 Tage · Hypertrophie + Kraft",
        taglineKey: "plan.template.pushPullLegs.tagline",
        descriptionText: "Wissenschaftlich optimierter Split. Jede Muskelgruppe wird 2x pro Woche trainiert – ideal für intermediäre Sportler laut Meta-Analysen.",
        descriptionKey: "plan.template.pushPullLegs.description",
        focus: "Hypertrophie",
        focusKey: "plan.template.pushPullLegs.focus",
        daysPerWeek: 6,
        days: [
            DaySpec(name: "Push A", localizationKey: "plan.day.pushA", type: .push, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 4, repsMin: 4,  repsMax: 6,  restSeconds: 180),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 6,  repsMax: 8,  restSeconds: 120),
                ExerciseSpec(name: "Schrägbankdrücken (aufwärts)", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Seitheben",                    sets: 4, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Trizepsdrücken (Kabel)",      sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Trizepsstrecker über Kopf (KH)", sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75)
            ]),
            DaySpec(name: "Pull A", localizationKey: "plan.day.pullA", type: .pull, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 3, repsMin: 4,  repsMax: 6,  restSeconds: 180),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 4, repsMin: 6,  repsMax: 8,  restSeconds: 120),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120),
                ExerciseSpec(name: "Face Pull",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Bizeps-Curl (LH)",              sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Hammer Curl",                  sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75)
            ]),
            DaySpec(name: "Beine A", localizationKey: "plan.day.legsA", type: .legs, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 4, repsMin: 6,  repsMax: 8,  restSeconds: 180),
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 4, repsMin: 8,  repsMax: 10, restSeconds: 120),
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Beinbeuger liegend",           sets: 3, repsMin: 10, repsMax: 15, restSeconds: 90),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 4, repsMin: 12, repsMax: 20, restSeconds: 60)
            ]),
            DaySpec(name: "Push B", localizationKey: "plan.day.pushB", type: .push, sequenceIndex: 4, exercises: [
                ExerciseSpec(name: "Schrägbankdrücken aufwärts (KH)", sets: 4, repsMin: 8, repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Schulterdrücken (KH)",          sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Pec Deck (Butterfly)",         sets: 3, repsMin: 12, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Kabel Seitheben",              sets: 4, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Trizepsstrecker über Kopf (Kabel)", sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Dips (Trizeps)",               sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90)
            ]),
            DaySpec(name: "Pull B", localizationKey: "plan.day.pullB", type: .pull, sequenceIndex: 5, exercises: [
                ExerciseSpec(name: "Latzug (weit)",                sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Kabelrudern sitzend",          sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Rudern einarmig (KH)",           sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Reverse Flyes (KH)",           sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Kabel Curl",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Schrägbank-Curl (KH)",             sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75)
            ]),
            DaySpec(name: "Beine B", localizationKey: "plan.day.legsB", type: .legs, sequenceIndex: 6, exercises: [
                ExerciseSpec(name: "Front Squat",                  sets: 4, repsMin: 6,  repsMax: 8,  restSeconds: 180),
                ExerciseSpec(name: "Hip Thrust (LH)",              sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Beinpresse",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 90),
                ExerciseSpec(name: "Nordic Curls",                 sets: 3, repsMin: 4,  repsMax: 8,  restSeconds: 120),
                ExerciseSpec(name: "Beinstrecker",                 sets: 3, repsMin: 12, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Wadenpresse (sitzend)",        sets: 4, repsMin: 12, repsMax: 20, restSeconds: 60)
            ])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.strengthtraining.functional",
        targetExperience: [.intermediate, .advanced],
        targetGoals: [.hypertrophy, .strength]
    )

    // MARK: - 6. Upper-Lower-Split (4 days)

    private static let upperLower = ProgramTemplate(
        id: "upper_lower",
        name: "Upper-Lower-Split",
        localizationKey: "plan.template.upperLower.name",
        tagline: "4 Tage · Kraft & Hypertrophie",
        taglineKey: "plan.template.upperLower.tagline",
        descriptionText: "Optimale Balance zwischen Frequenz und Volumen. Laut Studienlage der effektivste Split für Kraft- und Muskelaufbau bei Intermediären.",
        descriptionKey: "plan.template.upperLower.description",
        focus: "Kraft + Hypertrophie",
        focusKey: "plan.template.upperLower.focus",
        daysPerWeek: 4,
        days: [
            DaySpec(name: "Oberkörper A (Kraft)", localizationKey: "plan.day.upperAStrength", type: .upper, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 4, repsMin: 3,  repsMax: 5,  restSeconds: 180),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 4, repsMin: 4,  repsMax: 6,  restSeconds: 150),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 5,  repsMax: 7,  restSeconds: 120),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 5,  repsMax: 8,  restSeconds: 120),
                ExerciseSpec(name: "Bizeps-Curl (LH)",              sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 75),
                ExerciseSpec(name: "Skull Crusher",                sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 75)
            ]),
            DaySpec(name: "Unterkörper A (Kraft)", localizationKey: "plan.day.lowerAStrength", type: .lower, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 4, repsMin: 3,  repsMax: 5,  restSeconds: 210),
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 3, repsMin: 6,  repsMax: 8,  restSeconds: 150),
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 90),
                ExerciseSpec(name: "Beinbeuger liegend",           sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 4, repsMin: 10, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Oberkörper B (Volumen)", localizationKey: "plan.day.upperBVolume", type: .upper, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Schrägbankdrücken aufwärts (KH)", sets: 4, repsMin: 8, repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Kabelrudern sitzend",          sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Pec Deck (Butterfly)",         sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Latzug (weit)",                sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Seitheben",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Hammer Curl",                  sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Trizepsdrücken (Kabel)",      sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Unterkörper B (Volumen)", localizationKey: "plan.day.lowerBVolume", type: .lower, sequenceIndex: 4, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 3, repsMin: 3,  repsMax: 5,  restSeconds: 210),
                ExerciseSpec(name: "Beinpresse",                   sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Hip Thrust (LH)",              sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Nordic Curls",                 sets: 3, repsMin: 4,  repsMax: 8,  restSeconds: 120),
                ExerciseSpec(name: "Beinstrecker",                 sets: 3, repsMin: 12, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Wadenpresse (sitzend)",        sets: 4, repsMin: 12, repsMax: 20, restSeconds: 60)
            ])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.cooldown",
        targetExperience: [.intermediate, .advanced],
        targetGoals: [.hypertrophy, .strength]
    )

    // MARK: - 7. Arnold Split (6 days)

    private static let arnoldSplit = ProgramTemplate(
        id: "arnold_split",
        name: "Arnold Split",
        localizationKey: "plan.template.arnoldSplit.name",
        tagline: "6 Tage · Bodybuilding",
        taglineKey: "plan.template.arnoldSplit.tagline",
        descriptionText: "Arnold Schwarzeneggers Trainingsansatz: Antagonisten (Brust+Rücken) werden gemeinsam trainiert für maximalen Pump und Dichte.",
        descriptionKey: "plan.template.arnoldSplit.description",
        focus: "Hypertrophie",
        focusKey: "plan.template.arnoldSplit.focus",
        daysPerWeek: 6,
        days: [
            // DEL-089 Arnold-Split RIR: Hypertrophie-Plan, daher Iso-Lifts
            // (Curls, Seitheben, Flyes) auf 0–0.5 — Compounds bleiben mit
            // moderaten 1.5–2 (Verletzungsschutz, hoher Wochen-Volumen).
            DaySpec(name: "Brust & Rücken A", localizationKey: "plan.day.chestBackA", type: .upper, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 150, targetRir: 1.5),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 1.5),
                ExerciseSpec(name: "Flyes flach (KH)",             sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75,  targetRir: 0.5),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 1.0),
                ExerciseSpec(name: "Kabel Crossover",              sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 0),
                ExerciseSpec(name: "Kabelrudern sitzend",          sets: 3, repsMin: 10, repsMax: 12, restSeconds: 75,  targetRir: 0.5)
            ]),
            DaySpec(name: "Schultern & Arme A", localizationKey: "plan.day.shouldersArmsA", type: .upper, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 1.5),
                ExerciseSpec(name: "Seitheben",                    sets: 4, repsMin: 10, repsMax: 15, restSeconds: 60,  targetRir: 0),
                ExerciseSpec(name: "Bizeps-Curl (LH)",              sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90,  targetRir: 0.5),
                ExerciseSpec(name: "Skull Crusher",                sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90,  targetRir: 0.5),
                ExerciseSpec(name: "Hammer Curl",                  sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60,  targetRir: 0),
                ExerciseSpec(name: "Trizepsdrücken (Kabel)",      sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60,  targetRir: 0)
            ]),
            DaySpec(name: "Beine A", localizationKey: "plan.day.legsA", type: .legs, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 180, targetRir: 1.5),
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 1.5),
                ExerciseSpec(name: "Beinpresse",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 90,  targetRir: 1.0),
                ExerciseSpec(name: "Beinstrecker",                 sets: 3, repsMin: 12, repsMax: 15, restSeconds: 75,  targetRir: 0),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 4, repsMin: 12, repsMax: 20, restSeconds: 60,  targetRir: 0)
            ]),
            DaySpec(name: "Brust & Rücken B", localizationKey: "plan.day.chestBackB", type: .upper, sequenceIndex: 4, exercises: [
                ExerciseSpec(name: "Schrägbankdrücken (aufwärts)", sets: 4, repsMin: 8, repsMax: 12, restSeconds: 120, targetRir: 1.5),
                ExerciseSpec(name: "Rudern einarmig (KH)",           sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90,  targetRir: 1.0),
                ExerciseSpec(name: "Pec Deck (Butterfly)",         sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 0.5),
                ExerciseSpec(name: "Latzug (weit)",                sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90,  targetRir: 0.5),
                ExerciseSpec(name: "Brustdrücken (Maschine)",         sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75,  targetRir: 0.5),
                ExerciseSpec(name: "Face Pull",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 0.5)
            ]),
            DaySpec(name: "Schultern & Arme B", localizationKey: "plan.day.shouldersArmsB", type: .upper, sequenceIndex: 5, exercises: [
                ExerciseSpec(name: "Schulterdrücken (KH)",          sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90,  targetRir: 1.0),
                ExerciseSpec(name: "Kabel Seitheben",              sets: 4, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 0),
                ExerciseSpec(name: "Kabel Curl",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60,  targetRir: 0),
                ExerciseSpec(name: "Trizepsstrecker über Kopf (KH)", sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75,  targetRir: 0),
                ExerciseSpec(name: "Konzentrations-Curl (KH)",          sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60,  targetRir: 0),
                ExerciseSpec(name: "Trizepsstrecker über Kopf (Kabel)", sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60, targetRir: 0)
            ]),
            DaySpec(name: "Beine B", localizationKey: "plan.day.legsB", type: .legs, sequenceIndex: 6, exercises: [
                ExerciseSpec(name: "Front Squat",                  sets: 4, repsMin: 6,  repsMax: 8,  restSeconds: 180, targetRir: 1.5),
                ExerciseSpec(name: "Hip Thrust (LH)",              sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90,  targetRir: 1.0),
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90,  targetRir: 1.0),
                ExerciseSpec(name: "Beinbeuger liegend",           sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75,  targetRir: 0.5),
                ExerciseSpec(name: "Wadenpresse (sitzend)",        sets: 4, repsMin: 12, repsMax: 20, restSeconds: 60,  targetRir: 0)
            ])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.arms.open",
        targetExperience: [.advanced],
        targetGoals: [.hypertrophy]
    )

    // MARK: - 8. Bro-Split (5 days)

    private static let broSplit = ProgramTemplate(
        id: "bro_split",
        name: "Bro-Split",
        localizationKey: "plan.template.broSplit.name",
        tagline: "5 Tage · Hypertrophie",
        taglineKey: "plan.template.broSplit.tagline",
        descriptionText: "Klassischer Bodybuilding-Split mit hohem Volumen pro Muskelgruppe. Jede Muskelgruppe wird einmal pro Woche mit maximaler Erschöpfung trainiert.",
        descriptionKey: "plan.template.broSplit.description",
        focus: "Hypertrophie",
        focusKey: "plan.template.broSplit.focus",
        daysPerWeek: 5,
        days: [
            // DEL-089 RIR-Refinement: Bro-Split ist ein Hypertrophie-Plan.
            // Compounds (Bench, Squat, Deadlift) bleiben bei moderaten RIR 1.5–2
            // (Verletzungsschutz), Isolation (Curls, Seitheben, Flyes) gehen
            // jetzt explizit auf 0–0.5 → Progression triggert sauber ohne
            // dass kleine Muskeln in einer Hypertrophie-Sackgasse landen.
            DaySpec(name: "Brust", localizationKey: "plan.day.chest", type: .chest, sequenceIndex: 1, exercises: [
                // DEL-087: Warmup — Rotatoren + leichte Aktivierung vor
                // schwerem Bankdruecken.
                ExerciseSpec(name: "Face Pull",                    sets: 2, repsMin: 12, repsMax: 15, restSeconds: 45, targetRir: 3, role: .warmup),
                ExerciseSpec(name: "Bankdrücken",                 sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 150, targetRir: 1.5),
                ExerciseSpec(name: "Schrägbankdrücken (aufwärts)", sets: 4, repsMin: 8, repsMax: 12, restSeconds: 120, targetRir: 1.5),
                ExerciseSpec(name: "Flyes Schrägbank (KH)",       sets: 3, repsMin: 10, repsMax: 15, restSeconds: 90,  targetRir: 0.5),
                ExerciseSpec(name: "Kabel Crossover",              sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 0.5),
                ExerciseSpec(name: "Dips (Brust)",                 sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90,  targetRir: 1.0)
            ]),
            DaySpec(name: "Rücken", localizationKey: "plan.day.back", type: .back, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 4, repsMin: 4,  repsMax: 6,  restSeconds: 180, targetRir: 2.0),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 1.5),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 1.0),
                ExerciseSpec(name: "Kabelrudern sitzend",          sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90,  targetRir: 0.5),
                ExerciseSpec(name: "Rudern einarmig (KH)",           sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90,  targetRir: 0.5)
            ]),
            DaySpec(name: "Schultern", localizationKey: "plan.day.shoulders", type: .shoulders, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 1.5),
                ExerciseSpec(name: "Seitheben",                    sets: 4, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 0),
                ExerciseSpec(name: "Face Pull",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 0.5),
                ExerciseSpec(name: "Frontheben",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60,  targetRir: 0),
                ExerciseSpec(name: "Reverse Flyes (KH)",           sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 0)
            ]),
            DaySpec(name: "Arme", localizationKey: "plan.day.arms", type: .arms, sequenceIndex: 4, exercises: [
                ExerciseSpec(name: "Bizeps-Curl (LH)",              sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90,  targetRir: 0.5),
                ExerciseSpec(name: "Hammer Curl",                  sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75,  targetRir: 0),
                ExerciseSpec(name: "Schrägbank-Curl (KH)",             sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75,  targetRir: 0),
                ExerciseSpec(name: "Skull Crusher",                sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90,  targetRir: 0.5),
                ExerciseSpec(name: "Trizepsdrücken (Kabel)",      sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 0),
                ExerciseSpec(name: "Trizepsstrecker über Kopf (KH)", sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60,  targetRir: 0)
            ]),
            DaySpec(name: "Beine", localizationKey: "plan.day.legs", type: .legs, sequenceIndex: 5, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 180, targetRir: 1.5),
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 1.5),
                ExerciseSpec(name: "Beinpresse",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 120, targetRir: 1.0),
                ExerciseSpec(name: "Beinbeuger liegend",           sets: 3, repsMin: 10, repsMax: 15, restSeconds: 90,  targetRir: 0.5),
                ExerciseSpec(name: "Beinstrecker",                 sets: 3, repsMin: 12, repsMax: 15, restSeconds: 90,  targetRir: 0),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 4, repsMin: 12, repsMax: 20, restSeconds: 60,  targetRir: 0)
            ])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.flexibility",
        targetExperience: [.intermediate, .advanced],
        targetGoals: [.hypertrophy]
    )

    // MARK: - 9. Powerlifting 5×5 (3 days)

    private static let powerlifting5x5 = ProgramTemplate(
        id: "powerlifting_5x5",
        name: "Powerlifting 5x5",
        localizationKey: "plan.template.powerlifting5x5.name",
        tagline: "3 Tage · Kraft & Masse",
        taglineKey: "plan.template.powerlifting5x5.tagline",
        descriptionText: "Das bewährteste Kraft-Programm für Anfänger & Fortgeschrittene. Progressive Überlastung mit den Grundübungen — wissenschaftlich und praktisch belegt.",
        descriptionKey: "plan.template.powerlifting5x5.description",
        focus: "Kraft",
        focusKey: "plan.template.powerlifting5x5.focus",
        daysPerWeek: 3,
        days: [
            // DEL-087: Warmup-Saetze fuer die schweren 5x5 Working-Sets.
            // Face Pulls bereiten die Schultern auf Bank vor (Rotatoren-
            // Aktivierung); leichtere Squats / Bank-Saetze als Ramp-Up.
            // Alle Warmup-Sätze tragen `role: .warmup` — sie werden vom
            // Progressions-Algorithmus geskippt und im UI grau gerendert.
            DaySpec(name: "Workout A", localizationKey: "plan.day.workoutA", type: .fullBody, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Face Pull",                    sets: 2, repsMin: 12, repsMax: 15, restSeconds: 45, targetRir: 3, role: .warmup),
                ExerciseSpec(name: "Kniebeuge",                    sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 210),
                ExerciseSpec(name: "Bankdrücken",                 sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 180),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 150)
            ]),
            DaySpec(name: "Workout B", localizationKey: "plan.day.workoutB", type: .fullBody, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Face Pull",                    sets: 2, repsMin: 12, repsMax: 15, restSeconds: 45, targetRir: 3, role: .warmup),
                ExerciseSpec(name: "Kniebeuge",                    sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 210),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 180),
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 1, repsMin: 5,  repsMax: 5,  restSeconds: 210)
            ]),
            DaySpec(name: "Workout A", localizationKey: "plan.day.workoutA", type: .fullBody, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Face Pull",                    sets: 2, repsMin: 12, repsMax: 15, restSeconds: 45, targetRir: 3, role: .warmup),
                ExerciseSpec(name: "Kniebeuge",                    sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 210),
                ExerciseSpec(name: "Bankdrücken",                 sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 180),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 150)
            ])
        ],
        targetEnvironment: .gym,
        iconSystemName: "scalemass.fill",
        targetExperience: [.beginner, .intermediate],
        targetGoals: [.strength]
    )

    // MARK: - 10. Powerlifting 3×5 (3 days)

    private static let powerlifting3x5 = ProgramTemplate(
        id: "powerlifting_3x5",
        name: "Powerlifting 3x5",
        localizationKey: "plan.template.powerlifting3x5.name",
        tagline: "3 Tage · Maximalkraft",
        taglineKey: "plan.template.powerlifting3x5.tagline",
        descriptionText: "Dreier-Frequenz auf die Grundübungen Kniebeuge, Bankdrücken und Kreuzheben. Jede Session dreht sich um eine primäre Wettkampfübung mit schweren 3x5-Sätzen.",
        descriptionKey: "plan.template.powerlifting3x5.description",
        focus: "Kraft",
        focusKey: "plan.template.powerlifting3x5.focus",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Tag 1 – Kniebeuge-Tag", localizationKey: "plan.day.squatDay", type: .fullBody, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 240, targetRir: 1.5),
                ExerciseSpec(name: "Bankdrücken",                 sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 210, targetRir: 1.5),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 150, targetRir: 2.5)
            ]),
            DaySpec(name: "Tag 2 – Bankdrück-Tag", localizationKey: "plan.day.benchDay", type: .fullBody, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 240, targetRir: 1.5),
                ExerciseSpec(name: "Kniebeuge",                    sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 180, targetRir: 2.5),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 5,  repsMax: 8,  restSeconds: 150, targetRir: 2.5)
            ]),
            DaySpec(name: "Tag 3 – Kreuzhebe-Tag", localizationKey: "plan.day.deadliftDay", type: .fullBody, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 240, targetRir: 1.5),
                ExerciseSpec(name: "Front Squat",                  sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 180, targetRir: 2.5),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 180, targetRir: 2.5)
            ])
        ],
        targetEnvironment: .gym,
        iconSystemName: "dumbbell.fill",
        targetExperience: [.intermediate, .advanced],
        targetGoals: [.strength]
    )

    // MARK: - 11. Fußball Athletik (2 days)

    private static let footballAthletic = ProgramTemplate(
        id: "football_athletic",
        name: "Fussball Athletik",
        localizationKey: "plan.template.footballAthletic.name",
        tagline: "2 Tage · Kraft & Explosivität",
        taglineKey: "plan.template.footballAthletic.tagline",
        descriptionText: "Athletik-Programm für Mannschaftssportler: Maximalkraft und Schnellkraft in zwei kompakten Einheiten pro Woche — ideal als Ergänzung zum Vereinstraining.",
        descriptionKey: "plan.template.footballAthletic.description",
        focus: "Athletik",
        focusKey: "plan.template.footballAthletic.focus",
        daysPerWeek: 2,
        days: [
            DaySpec(name: "Unterkörper & Core", localizationKey: "plan.day.lowerAndCore", type: .legs, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 150, targetRir: 2.5),
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 8,  repsMax: 8,  restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Nordic Curls",                 sets: 3, repsMin: 5,  repsMax: 8,  restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 4, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 2.5),
                ExerciseSpec(name: "Plank",                        sets: 3, repsMin: 30, repsMax: 45, restSeconds: 60,  targetRir: 3.5)
            ]),
            DaySpec(name: "Oberkörper & Explosivität", localizationKey: "plan.day.upperAndPower", type: .upper, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Seitstütz",                   sets: 3, repsMin: 20, repsMax: 30, restSeconds: 60,  targetRir: 3.5),
                ExerciseSpec(name: "Box Jump",                     sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 120, targetRir: 3.5)
            ])
        ],
        targetEnvironment: .gym,
        iconSystemName: "soccerball",
        targetExperience: [.intermediate],
        targetGoals: [.hybrid, .strength]
    )

    // MARK: - 12. Hybrid Athlete — Beginner (DEL-055)

    /// 4-Tage-Plan fuer Einsteiger ins Concurrent Training (Kraft + Laufen).
    /// 2 Kraft-Tage mit Ganzkoerper-Compounds, 2 Lauf-Tage (1 Easy, 1 Long).
    /// Strength-RIR bewusst bei 2.5–3 → Sicherheitsabstand zum Versagen,
    /// damit am Folgetag das Laufen nicht abgekratzt wird.
    private static let hybridBeginner = ProgramTemplate(
        id: "hybrid_beginner",
        name: "Hybrid Athlete — Beginner",
        localizationKey: "plan.template.hybridBeginner.name",
        tagline: "4 Tage · Kraft + Laufen Einstieg",
        taglineKey: "plan.template.hybridBeginner.tagline",
        descriptionText: "Concurrent-Training light: zwei Ganzkörper-Strength-Einheiten + zwei lockere Lauf-Tage pro Woche. RIR-Puffer schützt den Laufmotor, kein zerstörendes Versagens-Training.",
        descriptionKey: "plan.template.hybridBeginner.description",
        focus: "Hybrid & Athletik",
        focusKey: "plan.template.hybridBeginner.focus",
        daysPerWeek: 4,
        days: [
            DaySpec(name: "Strength Ganzkörper A", localizationKey: "plan.day.strengthFullBodyA", type: .fullBody, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 3, repsMin: 6,  repsMax: 8,  restSeconds: 150, targetRir: 2.5),
                ExerciseSpec(name: "Bankdrücken",                 sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Plank",                        sets: 3, repsMin: 30, repsMax: 45, restSeconds: 60,  targetRir: 3.0)
            ]),
            DaySpec(name: "Easy Run", localizationKey: "plan.day.easyRun", type: .cardio, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Easy Run",                     sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 5.0, targetDurationMinutes: 30)
            ]),
            DaySpec(name: "Strength Ganzkörper B", localizationKey: "plan.day.strengthFullBodyB", type: .fullBody, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                ExerciseSpec(name: "Schulterdrücken (KH)",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Latzug (weit)",                sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Bizeps-Curl (KH)",                      sets: 2, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
            ]),
            DaySpec(name: "Long Run", localizationKey: "plan.day.longRun", type: .cardio, sequenceIndex: 4, exercises: [
                ExerciseSpec(name: "Long Run",                     sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 8.0, targetDurationMinutes: 50)
            ])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.run",
        targetExperience: [.beginner, .intermediate],
        targetGoals: [.hybrid],
        // DEL-172: Dumbbell-Only-Variante. Cardio-Tage unverändert; Strength-
        // Compounds auf KH-Versionen umgemappt (Goblet/KH-Bench/KH-Row).
        equipmentVariants: [
            EquipmentVariant(profile: .dumbbellOnly, days: [
                DaySpec(name: "Strength Ganzkörper A", localizationKey: "plan.day.strengthFullBodyA", type: .fullBody, sequenceIndex: 1, exercises: [
                    ExerciseSpec(name: "Goblet Squat",                 sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Bankdrücken (KH)",              sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Rudern einarmig (KH)",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90,  targetRir: 2.5),
                    ExerciseSpec(name: "Plank",                         sets: 3, repsMin: 30, repsMax: 45, restSeconds: 60,  targetRir: 3.0)
                ]),
                DaySpec(name: "Easy Run", localizationKey: "plan.day.easyRun", type: .cardio, sequenceIndex: 2, exercises: [
                    ExerciseSpec(name: "Easy Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 5.0, targetDurationMinutes: 30)
                ]),
                DaySpec(name: "Strength Ganzkörper B", localizationKey: "plan.day.strengthFullBodyB", type: .fullBody, sequenceIndex: 3, exercises: [
                    ExerciseSpec(name: "Rumänisches Kreuzheben (KH)",   sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Schulterdrücken (KH)",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Chest Supported Row (KH)",      sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Bizeps-Curl (KH)",              sets: 2, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
                ]),
                DaySpec(name: "Long Run", localizationKey: "plan.day.longRun", type: .cardio, sequenceIndex: 4, exercises: [
                    ExerciseSpec(name: "Long Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 8.0, targetDurationMinutes: 50)
                ])
            ]),
            // DEL-171: Kettlebell-Only-Variante. Cardio-Tage unverändert.
            EquipmentVariant(profile: .kettlebellOnly, days: [
                DaySpec(name: "Strength Ganzkörper A", localizationKey: "plan.day.strengthFullBodyA", type: .fullBody, sequenceIndex: 1, exercises: [
                    ExerciseSpec(name: "Kettlebell Goblet Squat",       sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Floor Press",        sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Row einarmig",       sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90,  targetRir: 2.5),
                    ExerciseSpec(name: "Plank",                         sets: 3, repsMin: 30, repsMax: 45, restSeconds: 60,  targetRir: 3.0)
                ]),
                DaySpec(name: "Easy Run", localizationKey: "plan.day.easyRun", type: .cardio, sequenceIndex: 2, exercises: [
                    ExerciseSpec(name: "Easy Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 5.0, targetDurationMinutes: 30)
                ]),
                DaySpec(name: "Strength Ganzkörper B", localizationKey: "plan.day.strengthFullBodyB", type: .fullBody, sequenceIndex: 3, exercises: [
                    ExerciseSpec(name: "Kettlebell RDL",                sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Push Press",         sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Swing",              sets: 3, repsMin: 12, repsMax: 15, restSeconds: 90,  targetRir: 2.0),
                    ExerciseSpec(name: "Kettlebell Halo",               sets: 2, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.5)
                ]),
                DaySpec(name: "Long Run", localizationKey: "plan.day.longRun", type: .cardio, sequenceIndex: 4, exercises: [
                    ExerciseSpec(name: "Long Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 8.0, targetDurationMinutes: 50)
                ])
            ])
        ]
    )

    // MARK: - 13. Hybrid Athlete — Balanced (DEL-055)

    /// 5-Tage-Plan: 3 Strength + 2 Run. Klassische "Hybrid"-Balance fuer
    /// Fortgeschrittene, die Kraft UND Ausdauer parallel halten/steigern wollen.
    private static let hybridBalanced = ProgramTemplate(
        id: "hybrid_balanced",
        name: "Hybrid Athlete — Balanced",
        localizationKey: "plan.template.hybridBalanced.name",
        tagline: "5 Tage · Kraft + Ausdauer in Balance",
        taglineKey: "plan.template.hybridBalanced.tagline",
        descriptionText: "Drei fokussierte Strength-Einheiten (Push/Pull/Legs-Light) plus zwei strategisch platzierte Lauf-Tage. RIR-Puffer 2–3 verhindert systemische Erschöpfung — bleibt Trainings-vertrāglich.",
        descriptionKey: "plan.template.hybridBalanced.description",
        focus: "Hybrid & Athletik",
        focusKey: "plan.template.hybridBalanced.focus",
        daysPerWeek: 5,
        days: [
            DaySpec(name: "Strength Push", localizationKey: "plan.day.strengthPush", type: .push, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 4, repsMin: 6,  repsMax: 8,  restSeconds: 150, targetRir: 2.5),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Schrägbankdrücken (aufwärts)", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Trizepsdrücken (Kabel)",      sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
            ]),
            DaySpec(name: "Easy Run", localizationKey: "plan.day.easyRun", type: .cardio, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Easy Run",                     sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 6.0, targetDurationMinutes: 35)
            ]),
            DaySpec(name: "Strength Pull", localizationKey: "plan.day.strengthPull", type: .pull, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 3, repsMin: 5,  repsMax: 6,  restSeconds: 180, targetRir: 3.0),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Bizeps-Curl (KH)",                      sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
            ]),
            DaySpec(name: "Long Run", localizationKey: "plan.day.longRun", type: .cardio, sequenceIndex: 4, exercises: [
                ExerciseSpec(name: "Long Run",                     sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 12.0, targetDurationMinutes: 70)
            ]),
            DaySpec(name: "Strength Legs (Light)", localizationKey: "plan.day.strengthLegsLight", type: .legs, sequenceIndex: 5, exercises: [
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 2.0),
                ExerciseSpec(name: "Plank",                        sets: 3, repsMin: 30, repsMax: 60, restSeconds: 60,  targetRir: 3.0)
            ])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.mixed.cardio",
        targetExperience: [.intermediate, .advanced],
        targetGoals: [.hybrid],
        // DEL-170: Equipment-Varianten. Cardio-Tage bleiben unverändert (gleiche
        // Distanzen/Dauer). Strength-Tage werden auf die jeweilige Implement-
        // Familie umgemappt. RIR-Puffer + Volumen bleiben strukturell identisch
        // zur Barbell-Variante, damit die Concurrent-Logik nicht kippt.
        equipmentVariants: [
            // ── Dumbbell-Only (Home-Gym ohne Rack) ─────────────────────────
            EquipmentVariant(profile: .dumbbellOnly, days: [
                DaySpec(name: "Strength Push", localizationKey: "plan.day.strengthPush", type: .push, sequenceIndex: 1, exercises: [
                    ExerciseSpec(name: "Bankdrücken (KH)",                sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                    ExerciseSpec(name: "Schulterdrücken (KH)",            sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Schrägbankdrücken aufwärts (KH)", sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Trizepsstrecker über Kopf (KH)",  sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
                ]),
                DaySpec(name: "Easy Run", localizationKey: "plan.day.easyRun", type: .cardio, sequenceIndex: 2, exercises: [
                    ExerciseSpec(name: "Easy Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 6.0, targetDurationMinutes: 35)
                ]),
                DaySpec(name: "Strength Pull", localizationKey: "plan.day.strengthPull", type: .pull, sequenceIndex: 3, exercises: [
                    ExerciseSpec(name: "Rumänisches Kreuzheben (KH)",     sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                    ExerciseSpec(name: "Rudern einarmig (KH)",            sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Chest Supported Row (KH)",        sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Bizeps-Curl (KH)",                sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
                ]),
                DaySpec(name: "Long Run", localizationKey: "plan.day.longRun", type: .cardio, sequenceIndex: 4, exercises: [
                    ExerciseSpec(name: "Long Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 12.0, targetDurationMinutes: 70)
                ]),
                DaySpec(name: "Strength Legs (Light)", localizationKey: "plan.day.strengthLegsLight", type: .legs, sequenceIndex: 5, exercises: [
                    ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",      sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Rumänisches Kreuzheben (KH)",     sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Ausfallschritte (KH)",            sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 2.0),
                    ExerciseSpec(name: "Plank",                           sets: 3, repsMin: 30, repsMax: 60, restSeconds: 60,  targetRir: 3.0)
                ])
            ]),
            // ── Kettlebell-Only (DEL-171) ─────────────────────────────────
            // Reine KB-Variante mit Floor Press / Row / RDL / Push Press —
            // erfordert die DEL-171 Library-Erweiterung. Cardio-Tage bleiben
            // unverändert; Strength-RIR-Puffer 2.5 wie bei der Barbell-Basis.
            EquipmentVariant(profile: .kettlebellOnly, days: [
                DaySpec(name: "Strength Push", localizationKey: "plan.day.strengthPush", type: .push, sequenceIndex: 1, exercises: [
                    ExerciseSpec(name: "Kettlebell Floor Press",          sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Push Press",           sets: 3, repsMin: 6,  repsMax: 8,  restSeconds: 150, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Clean & Press",        sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Halo",                 sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 2.0)
                ]),
                DaySpec(name: "Easy Run", localizationKey: "plan.day.easyRun", type: .cardio, sequenceIndex: 2, exercises: [
                    ExerciseSpec(name: "Easy Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 6.0, targetDurationMinutes: 35)
                ]),
                DaySpec(name: "Strength Pull", localizationKey: "plan.day.strengthPull", type: .pull, sequenceIndex: 3, exercises: [
                    ExerciseSpec(name: "Kettlebell RDL",                  sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Row einarmig",         sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Swing",                sets: 3, repsMin: 12, repsMax: 15, restSeconds: 90,  targetRir: 2.0),
                    ExerciseSpec(name: "Kettlebell Suitcase Carry",       sets: 3, repsMin: 30, repsMax: 60, restSeconds: 60,  targetRir: 2.0)
                ]),
                DaySpec(name: "Long Run", localizationKey: "plan.day.longRun", type: .cardio, sequenceIndex: 4, exercises: [
                    ExerciseSpec(name: "Long Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 12.0, targetDurationMinutes: 70)
                ]),
                DaySpec(name: "Strength Legs (Light)", localizationKey: "plan.day.strengthLegsLight", type: .legs, sequenceIndex: 5, exercises: [
                    ExerciseSpec(name: "Kettlebell Goblet Squat",         sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell RDL",                  sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Swing",                sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 2.0),
                    ExerciseSpec(name: "Plank",                           sets: 3, repsMin: 30, repsMax: 60, restSeconds: 60,  targetRir: 3.0)
                ])
            ])
        ]
    )

    // MARK: - 14. Hybrid Athlete — Performance (DEL-055)

    /// 6-Tage-Plan: 3 Strength + 3 Run (inkl. Intervall-Einheit). Ambitioniert,
    /// fuer User, die wissen was sie tun (z.B. Hyrox-/Triathlon-Vorbereitung).
    /// Strength-RIR konservativ 2.5 — der Volumen-Stress ueber 6 Tage ist hoch
    /// genug, da darf man am Stahl nicht auch noch ans Limit gehen.
    private static let hybridPerformance = ProgramTemplate(
        id: "hybrid_performance",
        name: "Hybrid Athlete — Performance",
        localizationKey: "plan.template.hybridPerformance.name",
        tagline: "6 Tage · Wettkampf-Hybrid",
        taglineKey: "plan.template.hybridPerformance.tagline",
        descriptionText: "Sechs Trainingstage: drei Strength-Einheiten (Push/Pull/Legs) + drei Läufe (Easy, Intervalle, Long Run). Strength-RIR konservativ 2.5, damit der Gesamt-Volumen-Stress trainings-vertraglich bleibt.",
        descriptionKey: "plan.template.hybridPerformance.description",
        focus: "Hybrid & Athletik",
        focusKey: "plan.template.hybridPerformance.focus",
        daysPerWeek: 6,
        days: [
            DaySpec(name: "Strength Push", localizationKey: "plan.day.strengthPush", type: .push, sequenceIndex: 1, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 4, repsMin: 5,  repsMax: 8,  restSeconds: 180, targetRir: 2.5),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                ExerciseSpec(name: "Schrägbankdrücken (aufwärts)", sets: 3, repsMin: 8, repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Seitheben",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 1.5),
                ExerciseSpec(name: "Trizepsdrücken (Kabel)",      sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
            ]),
            DaySpec(name: "Easy Run", localizationKey: "plan.day.easyRun", type: .cardio, sequenceIndex: 2, exercises: [
                ExerciseSpec(name: "Gehen / Einlaufen",            sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDurationMinutes: 5, role: .warmup),
                ExerciseSpec(name: "Easy Run",                     sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 8.0, targetDurationMinutes: 45)
            ]),
            DaySpec(name: "Strength Pull", localizationKey: "plan.day.strengthPull", type: .pull, sequenceIndex: 3, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 3, repsMin: 4,  repsMax: 6,  restSeconds: 210, targetRir: 3.0),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Bizeps-Curl (KH)",                      sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
            ]),
            DaySpec(name: "Intervalle", localizationKey: "plan.day.intervals", type: .cardio, sequenceIndex: 4, exercises: [
                ExerciseSpec(name: "Intervalle",                   sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDurationMinutes: 30)
            ]),
            DaySpec(name: "Strength Legs", localizationKey: "plan.day.strengthLegs", type: .legs, sequenceIndex: 5, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 4, repsMin: 5,  repsMax: 8,  restSeconds: 180, targetRir: 2.5),
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 2.0)
            ]),
            DaySpec(name: "Long Run", localizationKey: "plan.day.longRun", type: .cardio, sequenceIndex: 6, exercises: [
                ExerciseSpec(name: "Long Run",                     sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 15.0, targetDurationMinutes: 85)
            ])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.run.circle.fill",
        targetExperience: [.advanced],
        targetGoals: [.hybrid],
        // DEL-172: Dumbbell-Only-Variante. Strength-Tage auf KH umgemappt.
        // Wadenheben (LH) → Farmer's Walk (timeBased Carry) als KH-realistischer
        // Posterior-Chain-Ersatz; alles andere via existierende KH-Versionen
        // aus der Library.
        equipmentVariants: [
            EquipmentVariant(profile: .dumbbellOnly, days: [
                DaySpec(name: "Strength Push", localizationKey: "plan.day.strengthPush", type: .push, sequenceIndex: 1, exercises: [
                    ExerciseSpec(name: "Bankdrücken (KH)",              sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                    ExerciseSpec(name: "Schulterdrücken (KH)",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Schrägbankdrücken aufwärts (KH)", sets: 3, repsMin: 8, repsMax: 10, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Seitheben",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 1.5),
                    ExerciseSpec(name: "Trizepsstrecker über Kopf (KH)", sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
                ]),
                DaySpec(name: "Easy Run", localizationKey: "plan.day.easyRun", type: .cardio, sequenceIndex: 2, exercises: [
                    ExerciseSpec(name: "Gehen / Einlaufen",            sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDurationMinutes: 5, role: .warmup),
                    ExerciseSpec(name: "Easy Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 8.0, targetDurationMinutes: 45)
                ]),
                DaySpec(name: "Strength Pull", localizationKey: "plan.day.strengthPull", type: .pull, sequenceIndex: 3, exercises: [
                    ExerciseSpec(name: "Rumänisches Kreuzheben (KH)",   sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 180, targetRir: 2.5),
                    ExerciseSpec(name: "Rudern einarmig (KH)",          sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Chest Supported Row (KH)",      sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Bizeps-Curl (KH)",              sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
                ]),
                DaySpec(name: "Intervalle", localizationKey: "plan.day.intervals", type: .cardio, sequenceIndex: 4, exercises: [
                    ExerciseSpec(name: "Intervalle", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDurationMinutes: 30)
                ]),
                DaySpec(name: "Strength Legs", localizationKey: "plan.day.strengthLegs", type: .legs, sequenceIndex: 5, exercises: [
                    ExerciseSpec(name: "Goblet Squat",                 sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 150, targetRir: 2.5),
                    ExerciseSpec(name: "Rumänisches Kreuzheben (KH)",   sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                    ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Farmer's Walk",                 sets: 3, repsMin: 30, repsMax: 60, restSeconds: 60,  targetRir: 2.0)
                ]),
                DaySpec(name: "Long Run", localizationKey: "plan.day.longRun", type: .cardio, sequenceIndex: 6, exercises: [
                    ExerciseSpec(name: "Long Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 15.0, targetDurationMinutes: 85)
                ])
            ]),
            // ── Kettlebell-Only (DEL-171) ─────────────────────────────────
            // 6-Tage-KB-Variante. Push enthält Turkish Get-Up als technische
            // Stabi-Komponente (passend für Performance-Zielgruppe). Cardio-
            // Tage bleiben unverändert; Strength-RIR 2.5 wie bei der Basis.
            EquipmentVariant(profile: .kettlebellOnly, days: [
                DaySpec(name: "Strength Push", localizationKey: "plan.day.strengthPush", type: .push, sequenceIndex: 1, exercises: [
                    ExerciseSpec(name: "Kettlebell Floor Press",          sets: 4, repsMin: 5,  repsMax: 8,  restSeconds: 180, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Push Press",           sets: 3, repsMin: 6,  repsMax: 8,  restSeconds: 150, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Clean & Press",        sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Turkish Get-Up",                  sets: 3, repsMin: 3,  repsMax: 5,  restSeconds: 90,  targetRir: 2.0),
                    ExerciseSpec(name: "Kettlebell Halo",                 sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.5)
                ]),
                DaySpec(name: "Easy Run", localizationKey: "plan.day.easyRun", type: .cardio, sequenceIndex: 2, exercises: [
                    ExerciseSpec(name: "Gehen / Einlaufen",            sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDurationMinutes: 5, role: .warmup),
                    ExerciseSpec(name: "Easy Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 8.0, targetDurationMinutes: 45)
                ]),
                DaySpec(name: "Strength Pull", localizationKey: "plan.day.strengthPull", type: .pull, sequenceIndex: 3, exercises: [
                    ExerciseSpec(name: "Kettlebell RDL",                  sets: 3, repsMin: 5,  repsMax: 8,  restSeconds: 180, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Row einarmig",         sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Swing",                sets: 3, repsMin: 12, repsMax: 15, restSeconds: 90,  targetRir: 2.0),
                    ExerciseSpec(name: "Kettlebell Suitcase Carry",       sets: 3, repsMin: 30, repsMax: 60, restSeconds: 60,  targetRir: 2.0)
                ]),
                DaySpec(name: "Intervalle", localizationKey: "plan.day.intervals", type: .cardio, sequenceIndex: 4, exercises: [
                    ExerciseSpec(name: "Intervalle", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDurationMinutes: 30)
                ]),
                DaySpec(name: "Strength Legs", localizationKey: "plan.day.strengthLegs", type: .legs, sequenceIndex: 5, exercises: [
                    ExerciseSpec(name: "Kettlebell Goblet Squat",         sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 150, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell RDL",                  sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                    ExerciseSpec(name: "Kettlebell Swing",                sets: 3, repsMin: 12, repsMax: 15, restSeconds: 90,  targetRir: 2.0),
                    ExerciseSpec(name: "Kettlebell Suitcase Carry",       sets: 3, repsMin: 30, repsMax: 60, restSeconds: 60,  targetRir: 2.0)
                ]),
                DaySpec(name: "Long Run", localizationKey: "plan.day.longRun", type: .cardio, sequenceIndex: 6, exercises: [
                    ExerciseSpec(name: "Long Run", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 15.0, targetDurationMinutes: 85)
                ])
            ])
        ]
    )

    // MARK: - 15. CrossFit Bodyweight (Rx)
    //
    // README 2.9 / Nachtrag "Komplette Trainingsplaene Crossfit Kettlebell".
    // Rx + Scaled sind als ZWEI eigenstaendige Templates abgebildet statt
    // eines In-Workout-Toggles (Datenmodell/UI dafuer existiert nicht -
    // Umfang waere ein eigenes Feature, kein Teil dieser Phase).
    //
    // Tag 3 (Auf Zeit): Original-Leiter 50-40-30-20-10 - das Datenmodell
    // kennt nur gleichmaessige Runden (`Exercise.sets` × `repsMin`), darum
    // approximiert als 5 Runden × 30 Wdh. (gleiche Gesamt-Wiederholungszahl
    // 150 wie die Original-Leiter).

    private static let crossfitBodyweightRx = ProgramTemplate(
        id: "crossfit_bodyweight_rx",
        name: "CrossFit Bodyweight (Rx)",
        localizationKey: "plan.template.crossfitBodyweightRx.name",
        tagline: "3 Tage · Klassische Bodyweight-WODs",
        taglineKey: "plan.template.crossfitBodyweightRx.tagline",
        descriptionText: "Benchmark-WODs nur mit Körpergewicht: ein 20-Minuten-AMRAP, ein Intensitäts-EMOM und eine Auf-Zeit-Rundenleiter. Volle Rx-Bewegungen — Klimmzüge, Liegestütze, Air Squats.",
        descriptionKey: "plan.template.crossfitBodyweightRx.description",
        focus: "CrossFit & Kettlebell",
        focusKey: "plan.template.crossfitBodyweightRx.focus",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Cindy", localizationKey: "plan.day.cindyRx", type: .fullBody, sequenceIndex: 1,
                    exercises: [
                        ExerciseSpec(name: "Klimmzüge",        sets: 1, repsMin: 5,  repsMax: 5),
                        ExerciseSpec(name: "Liegestütze",      sets: 1, repsMin: 10, repsMax: 10),
                        ExerciseSpec(name: "Kniebeuge (BW)",   sets: 1, repsMin: 15, repsMax: 15)
                    ],
                    timeFormat: .amrap, timeCapMinutes: 20),
            DaySpec(name: "EMOM Intensität", localizationKey: "plan.day.emomIntensityRx", type: .fullBody, sequenceIndex: 2,
                    exercises: [
                        ExerciseSpec(name: "Burpees",                       sets: 1, repsMin: 15, repsMax: 15),
                        ExerciseSpec(name: "Gesprungene Ausfallschritte",   sets: 1, repsMin: 20, repsMax: 20)
                    ],
                    timeFormat: .emom, timeCapMinutes: 12),
            DaySpec(name: "Auf Zeit: Sit-ups & Squats", localizationKey: "plan.day.forTimeSitupsSquatsRx", type: .fullBody, sequenceIndex: 3,
                    exercises: [
                        ExerciseSpec(name: "Sit-ups",          sets: 5, repsMin: 30, repsMax: 30),
                        ExerciseSpec(name: "Kniebeuge (BW)",   sets: 5, repsMin: 30, repsMax: 30)
                    ],
                    timeFormat: .forTime)
        ],
        targetEnvironment: .noEquipment,
        iconSystemName: "figure.mixed.cardio",
        targetExperience: [.advanced],
        targetGoals: [.functional, .fatloss]
    )

    // MARK: - 16. CrossFit Bodyweight (Scaled)

    private static let crossfitBodyweightScaled = ProgramTemplate(
        id: "crossfit_bodyweight_scaled",
        name: "CrossFit Bodyweight (Scaled)",
        localizationKey: "plan.template.crossfitBodyweightScaled.name",
        tagline: "3 Tage · Bodyweight-WODs, Einsteiger-Varianten",
        taglineKey: "plan.template.crossfitBodyweightScaled.tagline",
        descriptionText: "Dieselben Benchmark-WODs wie Rx, mit Einsteiger-Bewegungen: Handtuch-Rudern statt Klimmzüge, Liegestütze auf den Knien und eine kürzere Rundenleiter.",
        descriptionKey: "plan.template.crossfitBodyweightScaled.description",
        focus: "CrossFit & Kettlebell",
        focusKey: "plan.template.crossfitBodyweightScaled.focus",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Cindy (Scaled)", localizationKey: "plan.day.cindyScaled", type: .fullBody, sequenceIndex: 1,
                    exercises: [
                        ExerciseSpec(name: "Handtuch-Rudern (Türrahmen)",  sets: 1, repsMin: 5,  repsMax: 5),
                        ExerciseSpec(name: "Liegestütze (Knie)",           sets: 1, repsMin: 10, repsMax: 10),
                        ExerciseSpec(name: "Kniebeuge (BW)",               sets: 1, repsMin: 15, repsMax: 15)
                    ],
                    timeFormat: .amrap, timeCapMinutes: 20),
            DaySpec(name: "EMOM Intensität (Scaled)", localizationKey: "plan.day.emomIntensityScaled", type: .fullBody, sequenceIndex: 2,
                    exercises: [
                        ExerciseSpec(name: "Burpees",              sets: 1, repsMin: 8,  repsMax: 8),
                        ExerciseSpec(name: "Ausfallschritte (BW)", sets: 1, repsMin: 12, repsMax: 12)
                    ],
                    timeFormat: .emom, timeCapMinutes: 12),
            DaySpec(name: "Auf Zeit: Sit-ups & Squats (Scaled)", localizationKey: "plan.day.forTimeSitupsSquatsScaled", type: .fullBody, sequenceIndex: 3,
                    exercises: [
                        ExerciseSpec(name: "Sit-ups",        sets: 3, repsMin: 20, repsMax: 20),
                        ExerciseSpec(name: "Kniebeuge (BW)", sets: 3, repsMin: 20, repsMax: 20)
                    ],
                    timeFormat: .forTime)
        ],
        targetEnvironment: .noEquipment,
        iconSystemName: "figure.mixed.cardio",
        targetExperience: [.beginner],
        targetGoals: [.functional, .fatloss]
    )

    // MARK: - 17. CrossFit mit Gewichten

    private static let crossfitWeighted = ProgramTemplate(
        id: "crossfit_weighted",
        name: "CrossFit mit Gewichten",
        localizationKey: "plan.template.crossfitWeighted.name",
        tagline: "3 Tage · Funktionelle WODs mit Kurzhantel/Kettlebell",
        taglineKey: "plan.template.crossfitWeighted.tagline",
        descriptionText: "Metcon-Workouts mit Zusatzgewicht statt reinem Körpergewicht — die Schwierigkeit steuerst du über das Gewicht, nicht über die Bewegung. Für Einsteiger und Fortgeschrittene.",
        descriptionKey: "plan.template.crossfitWeighted.description",
        focus: "CrossFit & Kettlebell",
        focusKey: "plan.template.crossfitWeighted.focus",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Grundlagen-AMRAP", localizationKey: "plan.day.crossfitWeightedAmrap", type: .fullBody, sequenceIndex: 1,
                    exercises: [
                        ExerciseSpec(name: "Goblet Squat",       sets: 1, repsMin: 10, repsMax: 10),
                        ExerciseSpec(name: "Liegestütze",        sets: 1, repsMin: 10, repsMax: 10),
                        ExerciseSpec(name: "Kreuzheben (KH)",    sets: 1, repsMin: 10, repsMax: 10)
                    ],
                    timeFormat: .amrap, timeCapMinutes: 12),
            DaySpec(name: "EMOM Ganzkörper", localizationKey: "plan.day.crossfitWeightedEmom", type: .fullBody, sequenceIndex: 2,
                    exercises: [
                        ExerciseSpec(name: "Kettlebell Swing",  sets: 1, repsMin: 12, repsMax: 12),
                        ExerciseSpec(name: "Push Press (KH)",   sets: 1, repsMin: 10, repsMax: 10),
                        ExerciseSpec(name: "Plank",              sets: 1, repsMin: 40, repsMax: 40)
                    ],
                    timeFormat: .emom, timeCapMinutes: 15),
            // Original-Leiter 15-12-9 approximiert als 3 Runden × 12 Wdh.
            // (gleiche Gesamt-Wiederholungszahl 36) — selbe Begründung wie
            // bei Cindys Auf-Zeit-Tag oben.
            DaySpec(name: "Auf Zeit: Thruster & Burpees", localizationKey: "plan.day.crossfitWeightedForTime", type: .fullBody, sequenceIndex: 3,
                    exercises: [
                        ExerciseSpec(name: "Thruster (KH)", sets: 3, repsMin: 12, repsMax: 12),
                        ExerciseSpec(name: "Burpees",        sets: 3, repsMin: 12, repsMax: 12)
                    ],
                    timeFormat: .forTime)
        ],
        targetEnvironment: .homeGym,
        iconSystemName: "dumbbell.fill",
        // README 2.19: .intermediate ergaenzt - der Quiz-Default (.intermediate)
        // gab diesem Template sonst 0 statt +2 Erfahrungspunkte, obwohl die
        // Beschreibung "Einsteiger und Fortgeschrittene" beide Enden schon nennt.
        targetExperience: [.beginner, .intermediate, .advanced],
        targetGoals: [.functional, .fatloss]
    )

    // MARK: - 18. Kettlebell Grundlagen (Anfänger)

    private static let kettlebellBeginner = ProgramTemplate(
        id: "kettlebell_beginner",
        name: "Kettlebell Grundlagen",
        localizationKey: "plan.template.kettlebellBeginner.name",
        tagline: "3 Tage · Technik, Kraftausdauer, Stabilität",
        taglineKey: "plan.template.kettlebellBeginner.tagline",
        descriptionText: "Einstieg ins Kettlebell-Training: saubere Grundtechnik bei Deadlift, Goblet Squat und Swing, ergänzt von einem AMRAP-Finisher zum Rundenaufbau.",
        descriptionKey: "plan.template.kettlebellBeginner.description",
        focus: "CrossFit & Kettlebell",
        focusKey: "plan.template.kettlebellBeginner.focus",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Grundlagen-Zirkel", localizationKey: "plan.day.kbFoundationsCircuit", type: .fullBody, sequenceIndex: 1,
                    exercises: [
                        ExerciseSpec(name: "Kettlebell Kreuzheben",       sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                        ExerciseSpec(name: "Kettlebell Goblet Squat",     sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                        ExerciseSpec(name: "Plank",                       sets: 3, repsMin: 30, repsMax: 45, restSeconds: 60)
                    ]),
            DaySpec(name: "Push, Pull & Core", localizationKey: "plan.day.kbPushPullCore", type: .fullBody, sequenceIndex: 2,
                    exercises: [
                        ExerciseSpec(name: "Kettlebell Row einarmig",      sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 60),
                        ExerciseSpec(name: "Kettlebell Overhead Press",    sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 60),
                        ExerciseSpec(name: "Sit-ups",                      sets: 3, repsMin: 15, repsMax: 15, restSeconds: 60)
                    ]),
            DaySpec(name: "Schwung & Ausdauer", localizationKey: "plan.day.kbSwingEndurance", type: .fullBody, sequenceIndex: 3,
                    exercises: [
                        ExerciseSpec(name: "Kettlebell Swing",        sets: 1, repsMin: 15, repsMax: 15),
                        ExerciseSpec(name: "Kettlebell Goblet Squat", sets: 1, repsMin: 10, repsMax: 10),
                        ExerciseSpec(name: "Liegestütze",             sets: 1, repsMin: 5,  repsMax: 5)
                    ],
                    timeFormat: .amrap, timeCapMinutes: 15)
        ],
        targetEnvironment: .homeGym,
        iconSystemName: "figure.strengthtraining.functional",
        // README 2.19: .intermediate ergaenzt - saubere Grundtechnik ist
        // auch fuer Kettlebell-Einsteiger mit anderweitiger Trainingserfahrung
        // relevant, nicht nur fuer komplette Anfaenger.
        targetExperience: [.beginner, .intermediate],
        targetGoals: [.functional, .fatloss]
    )

    // MARK: - 19. Kettlebell Fortgeschritten
    //
    // Tag 1 (Quelle: "Heavy Pull & Core") kombiniert laut Dokument einen
    // Kraft-Block (Turkish Get-Up, 5×2/Seite) MIT einem separaten EMOM-WOD
    // (Snatch links/rechts) - ein Tag hat in diesem Datenmodell aber
    // entweder normale Sätze ODER genau ein Zeitformat, nicht beides. Der
    // WOD-Teil gewinnt (zeigt das neue Feature), der Kraft-Teil entfällt
    // hier bewusst. Tag 3 der Quelle ("Aktive Erholung") ist kein
    // Trainingstag und wird wie jeder andere Rest-Day nicht als eigener
    // DaySpec abgebildet (DEL-088) - der Instantiator füllt ihn beim Adopt
    // automatisch; `daysPerWeek` zählt darum 3 statt der 4 Tage aus der Quelle.

    private static let kettlebellAdvanced = ProgramTemplate(
        id: "kettlebell_advanced",
        name: "Kettlebell Fortgeschritten",
        localizationKey: "plan.template.kettlebellAdvanced.name",
        tagline: "3 Trainingstage · Maximalkraft, Explosivität, Metcon",
        taglineKey: "plan.template.kettlebellAdvanced.tagline",
        descriptionText: "Komplexe Kettlebell-Lifts (Snatch, Clean & Press) für erfahrene Trainierende, ergänzt von einem 20-Minuten-Metcon. Plane zwischen den Einheiten einen Tag aktiver Erholung ein.",
        descriptionKey: "plan.template.kettlebellAdvanced.description",
        focus: "CrossFit & Kettlebell",
        focusKey: "plan.template.kettlebellAdvanced.focus",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Heavy Pull: EMOM Snatch", localizationKey: "plan.day.kbHeavyPullEmom", type: .fullBody, sequenceIndex: 1,
                    exercises: [
                        ExerciseSpec(name: "Kettlebell Snatch (Links)",   sets: 1, repsMin: 6, repsMax: 8),
                        ExerciseSpec(name: "Kettlebell Snatch (Rechts)",  sets: 1, repsMin: 6, repsMax: 8)
                    ],
                    timeFormat: .emom, timeCapMinutes: 10),
            DaySpec(name: "Heavy Push & Squat", localizationKey: "plan.day.kbHeavyPushSquat", type: .fullBody, sequenceIndex: 2,
                    exercises: [
                        ExerciseSpec(name: "Kettlebell Clean & Press",  sets: 6, repsMin: 8,  repsMax: 8,  restSeconds: 120),
                        ExerciseSpec(name: "Kettlebell Front Squat",    sets: 4, repsMin: 10, repsMax: 10, restSeconds: 90),
                        ExerciseSpec(name: "Renegade Row",               sets: 4, repsMin: 12, repsMax: 12, restSeconds: 90)
                    ]),
            DaySpec(name: "Metabolic Conditioning", localizationKey: "plan.day.kbMetcon", type: .fullBody, sequenceIndex: 3,
                    exercises: [
                        ExerciseSpec(name: "Kettlebell Swing",        sets: 1, repsMin: 20, repsMax: 20),
                        ExerciseSpec(name: "Kettlebell Goblet Squat", sets: 1, repsMin: 15, repsMax: 15),
                        ExerciseSpec(name: "Liegestütze",             sets: 1, repsMin: 10, repsMax: 10),
                        ExerciseSpec(name: "Burpees",                  sets: 1, repsMin: 5,  repsMax: 5)
                    ],
                    timeFormat: .amrap, timeCapMinutes: 20)
        ],
        targetEnvironment: .homeGym,
        iconSystemName: "flame.fill",
        targetExperience: [.advanced],
        targetGoals: [.functional, .fatloss]
    )

    // MARK: - 20. Kettlebell Komplexe (Zirkel-Zeitformat)
    //
    // Nutzer-Upload (13. August, zweite Runde): "Athletik beginnt hier - 5
    // Kettlebell-Komplexe". Fuenf eigenstaendige Komplexe statt eines
    // klassischen 3er-Splits, darum `daysPerWeek: 5` statt der ueblichen 3.
    // Vier der fuenf nutzen das neue `.circuit`-Zeitformat (feste
    // Rundenzahl, feste Pause dazwischen) - Komplex 4 ("Seated Control")
    // ist im Original schon ein waschechtes 15-Minuten-AMRAP und braucht
    // keine Uebersetzung. `ExerciseSpec.sets` spiegelt hier ueberall
    // `circuitRounds` (gleiche Konvention wie bei Auf-Zeit, siehe
    // `timedFormatCircuitLabel`), `restSeconds` bleibt unbenutzter Default -
    // die tatsaechliche Pause lebt in `circuitRestSeconds`.
    private static let kettlebellComplexes = ProgramTemplate(
        id: "kettlebell_complexes",
        name: "Kettlebell Komplexe",
        localizationKey: "plan.template.kettlebellComplexes.name",
        tagline: "5 Tage · Ganzkörper-Komplexe für Athletik & Kraftausdauer",
        taglineKey: "plan.template.kettlebellComplexes.tagline",
        descriptionText: "Fünf eigenständige Kettlebell-Komplexe für Ganzkörper-Athletik - von rundenbasierten Ganzkörper- und Explosivitäts-Komplexen bis zu einem AMRAP-Finisher für die Körpermitte. Moderates Gewicht wählen, saubere Technik vor Tempo.",
        descriptionKey: "plan.template.kettlebellComplexes.description",
        focus: "CrossFit & Kettlebell",
        focusKey: "plan.template.kettlebellComplexes.focus",
        daysPerWeek: 5,
        days: [
            DaySpec(name: "Ganzkörper-Komplex", localizationKey: "plan.day.kbComplexFullBody", type: .fullBody, sequenceIndex: 1,
                    exercises: [
                        ExerciseSpec(name: "Kettlebell Clean to Front Squat", sets: 5, repsMin: 7,  repsMax: 7),
                        ExerciseSpec(name: "Kettlebell Thruster einarmig",   sets: 5, repsMin: 7,  repsMax: 7),
                        ExerciseSpec(name: "Kettlebell Swing",               sets: 5, repsMin: 7,  repsMax: 7),
                        ExerciseSpec(name: "Kettlebell Row einarmig",        sets: 5, repsMin: 7,  repsMax: 7),
                        ExerciseSpec(name: "Liegestütze auf Kettlebell",     sets: 5, repsMin: 14, repsMax: 14)
                    ],
                    timeFormat: .circuit, circuitRounds: 5, circuitRestSeconds: 90, circuitMode: .fixedReps),
            DaySpec(name: "Schulter & Core", localizationKey: "plan.day.kbComplexShoulderCore", type: .fullBody, sequenceIndex: 2,
                    exercises: [
                        ExerciseSpec(name: "Kettlebell Halo",     sets: 10, repsMin: 2, repsMax: 2),
                        ExerciseSpec(name: "Kettlebell Pullover",  sets: 10, repsMin: 2, repsMax: 2),
                        ExerciseSpec(name: "Kettlebell Halo",     sets: 10, repsMin: 2, repsMax: 2)
                    ],
                    timeFormat: .circuit, circuitRounds: 10, circuitRestSeconds: 90, circuitMode: .toFailure),
            DaySpec(name: "Explosivität", localizationKey: "plan.day.kbComplexExplosive", type: .fullBody, sequenceIndex: 3,
                    exercises: [
                        ExerciseSpec(name: "Kettlebell Snatch",         sets: 5, repsMin: 20, repsMax: 20),
                        ExerciseSpec(name: "Kettlebell Clean & Press",  sets: 5, repsMin: 10, repsMax: 10),
                        ExerciseSpec(name: "Kettlebell Goblet Squat",   sets: 5, repsMin: 10, repsMax: 10),
                        ExerciseSpec(name: "Kettlebell Swing",          sets: 5, repsMin: 20, repsMax: 20)
                    ],
                    timeFormat: .circuit, circuitRounds: 5, circuitRestSeconds: 90, circuitMode: .fixedReps),
            // Einziger Komplex ohne Zirkel - im Original schon ein normales
            // 15-Minuten-AMRAP, exakt das bestehende Zeitformat.
            DaySpec(name: "Seated Control", localizationKey: "plan.day.kbComplexSeatedControl", type: .fullBody, sequenceIndex: 4,
                    exercises: [
                        ExerciseSpec(name: "Kettlebell Uppercut Rotation",     sets: 1, repsMin: 10, repsMax: 10),
                        ExerciseSpec(name: "Kettlebell Halo",                 sets: 1, repsMin: 10, repsMax: 10),
                        ExerciseSpec(name: "Kettlebell Overhead Press",       sets: 1, repsMin: 10, repsMax: 10),
                        ExerciseSpec(name: "Kettlebell Sit-Up (Overhead Hold)", sets: 1, repsMin: 10, repsMax: 10)
                    ],
                    timeFormat: .amrap, timeCapMinutes: 15),
            DaySpec(name: "Kraftausdauer", localizationKey: "plan.day.kbComplexEndurance", type: .fullBody, sequenceIndex: 5,
                    exercises: [
                        ExerciseSpec(name: "Kettlebell Row einarmig",      sets: 5, repsMin: 5,  repsMax: 5),
                        ExerciseSpec(name: "Kettlebell Swing",             sets: 5, repsMin: 5,  repsMax: 5),
                        ExerciseSpec(name: "Kettlebell Thruster einarmig", sets: 5, repsMin: 5,  repsMax: 5),
                        ExerciseSpec(name: "Liegestütze",                  sets: 5, repsMin: 10, repsMax: 10)
                    ],
                    timeFormat: .circuit, circuitRounds: 5, circuitRestSeconds: 90, circuitMode: .fixedReps)
        ],
        targetEnvironment: .homeGym,
        iconSystemName: "figure.highintensity.intervaltraining",
        targetExperience: [.intermediate, .advanced],
        targetGoals: [.functional, .fatloss]
    )

    // MARK: - Display order

    /// Display order in the picker — beginner-friendly programs first, then specialised.
    public static let all: [ProgramTemplate] = [
        fullBody,
        fatLossFullBody,
        homeGymHero,
        bodyweightMastery,
        pushPullLegs,
        upperLower,
        arnoldSplit,
        broSplit,
        powerlifting5x5,
        powerlifting3x5,
        footballAthletic,
        // DEL-055 Hybrid-Familie. Gruppiert via `focus = "Hybrid & Athletik"`,
        // sodass die Picker-UI sie als eigene Section rendern kann.
        hybridBeginner,
        hybridBalanced,
        hybridPerformance,
        // README 2.9 / Nachtrag Crossfit+Kettlebell. Gruppiert via
        // `focus = "CrossFit & Kettlebell"`, gleiches Section-Muster wie
        // die Hybrid-Familie oben.
        crossfitBodyweightRx,
        crossfitBodyweightScaled,
        crossfitWeighted,
        kettlebellBeginner,
        kettlebellAdvanced,
        kettlebellComplexes
    ]
}
