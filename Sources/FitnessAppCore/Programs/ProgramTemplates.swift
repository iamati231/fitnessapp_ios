import Foundation

/// All shipped program templates. Order = display order in the picker.
///
/// **Weekday convention conversion**: the source `ProgramTemplates.kt` uses
/// 1 = Monday, ..., 7 = Sunday. Foundation's `Calendar` uses 1 = Sunday,
/// 2 = Monday, ..., 7 = Saturday. Numbers below are already converted —
/// don't blindly copy back from the Android source.
public enum ProgramTemplates {

    // MARK: - 1. Ganzkörper 3× (Beginner / Re-Entry)

    private static let fullBody = ProgramTemplate(
        id: "full_body",
        name: "Ganzkörper 3x",
        tagline: "3 Tage · Anfänger & Re-Einstieg",
        descriptionText: "Höchste Trainingsfrequenz pro Muskelgruppe. Laut Forschung optimal für Anfänger und Wiedereinstieg — maximales Signal für Muskelwachstum.",
        focus: "Anfänger / Allgemein",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Ganzkörper A", type: .fullBody, weekday: 2, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 3, repsMin: 5,  repsMax: 8,  restSeconds: 180),
                ExerciseSpec(name: "Bankdrücken",                 sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 150),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Langhantel Curl",              sets: 2, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Trizep Pushdown (Kabel)",      sets: 2, repsMin: 10, repsMax: 15, restSeconds: 75)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 3, exercises: []),
            DaySpec(name: "Ganzkörper B", type: .fullBody, weekday: 4, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 3, repsMin: 4,  repsMax: 6,  restSeconds: 180),
                ExerciseSpec(name: "KH-Schrägbankdrücken (aufwärts)", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Latzug (weit)",                sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "KH-Schulterdrücken",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Hammer Curl",                  sets: 2, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Dips (Trizeps)",               sets: 2, repsMin: 8,  repsMax: 12, restSeconds: 75)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 5, exercises: []),
            DaySpec(name: "Ganzkörper C", type: .fullBody, weekday: 6, exercises: [
                ExerciseSpec(name: "Front Squat",                  sets: 3, repsMin: 6,  repsMax: 8,  restSeconds: 150),
                ExerciseSpec(name: "Hip Thrust (LH)",              sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Kabelrudern sitzend",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Seitheben",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Schrägbank Curl",             sets: 2, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Skull Crusher",                sets: 2, repsMin: 8,  repsMax: 12, restSeconds: 75)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 7, exercises: []),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.strengthtraining.traditional"
    )

    // MARK: - 2. Fatburn Ganzkörper

    private static let fatLossFullBody = ProgramTemplate(
        id: "fat_loss_fullbody",
        name: "Fatburn Ganzkörper",
        tagline: "3 Tage · Fatburn & Kondition",
        descriptionText: "Effektiver Ganzkörperplan für maximalen Kalorienverbrauch. Kurze Pausen (60s) halten die Herzfrequenz oben — kombiniert mit einem Cardio-Finisher am Ende jeder Einheit.",
        focus: "Fatburn",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Fatburn A", type: .fullBody, weekday: 2, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Bankdrücken",                 sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Langhantel Curl",              sets: 2, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Skull Crusher",                sets: 2, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Cardio / Laufband",            sets: 1, repsMin: 15, repsMax: 15, restSeconds: 0, targetRir: 0, isCardio: true)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 3, exercises: []),
            DaySpec(name: "Fatburn B", type: .fullBody, weekday: 4, exercises: [
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "KH-Schrägbankdrücken (aufwärts)", sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Latzug (weit)",                sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "KH-Schulterdrücken",          sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Hammer Curl",                  sets: 2, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Trizep Pushdown (Kabel)",      sets: 2, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Cardio / Fahrradergometer",    sets: 1, repsMin: 15, repsMax: 15, restSeconds: 0, targetRir: 0, isCardio: true)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 5, exercises: []),
            DaySpec(name: "Fatburn C", type: .fullBody, weekday: 6, exercises: [
                ExerciseSpec(name: "Hip Thrust (LH)",              sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Kabelrudern sitzend",          sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "KH-Bankdrücken",              sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Seitheben",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Beinbeuger liegend",           sets: 2, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Schrägbank Curl",             sets: 2, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Cardio / Stepper",             sets: 1, repsMin: 15, repsMax: 15, restSeconds: 0, targetRir: 0, isCardio: true)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 7, exercises: []),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .gym,
        iconSystemName: "flame.fill"
    )

    // MARK: - 3. Home Gym Hero (Dumbbell-only)

    private static let homeGymHero = ProgramTemplate(
        id: "home_gym_hero",
        name: "Home Gym Hero",
        tagline: "3 Tage · Muskelaufbau mit Kurzhanteln",
        descriptionText: "Effektiver Ganzkörperplan komplett mit Kurzhanteln. Ideal für das Training zuhause — kein Fitnessstudio nötig.",
        focus: "Hypertrophie",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Ganzkörper A", type: .fullBody, weekday: 2, exercises: [
                ExerciseSpec(name: "Goblet Squat",                 sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "KH-Bankdrücken",              sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "KH-Rudern einarmig",           sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "KH-Romanian Deadlift",         sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Seitheben",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 3, exercises: []),
            DaySpec(name: "Ganzkörper B", type: .fullBody, weekday: 4, exercises: [
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "KH-Schrägbankdrücken (aufwärts)", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Chest Supported Row (KH)",     sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "KH-Schulterdrücken",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Hammer Curl",                  sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "KH Overhead Trizep Extension", sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 5, exercises: []),
            DaySpec(name: "Ganzkörper C", type: .fullBody, weekday: 6, exercises: [
                ExerciseSpec(name: "KH-Romanian Deadlift",         sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "KH-Flyes (flach)",             sets: 3, repsMin: 12, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "KH-Pullover",                  sets: 3, repsMin: 10, repsMax: 15, restSeconds: 90),
                ExerciseSpec(name: "KH-Ausfallschritte",           sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "KH-Curl",                      sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Trizep Kickback (KH)",         sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 7, exercises: []),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .homeGym,
        iconSystemName: "house.fill"
    )

    // MARK: - 4. Bodyweight Mastery (No Equipment)

    private static let bodyweightMastery = ProgramTemplate(
        id: "bodyweight_mastery",
        name: "Bodyweight Mastery",
        tagline: "3 Tage · Funktionelles Training ohne Geräte",
        descriptionText: "Komplettes Körpergewichtstraining ohne ein einziges Gerät. Kürzere Pausen und isometrische Übungen sorgen für maximalen Trainingsreiz.",
        focus: "Funktionelle Fitness",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Push & Core", type: .push, weekday: 2, exercises: [
                ExerciseSpec(name: "Liegestütze",                 sets: 4, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Pike Liegestütze",            sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 60),
                ExerciseSpec(name: "Dips (Trizeps)",               sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 60),
                ExerciseSpec(name: "Plank",                        sets: 3, repsMin: 30, repsMax: 45, restSeconds: 60, targetRir: 3.0),
                ExerciseSpec(name: "Mountain Climbers",            sets: 3, repsMin: 20, repsMax: 30, restSeconds: 60)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 3, exercises: []),
            DaySpec(name: "Pull & Beine", type: .fullBody, weekday: 4, exercises: [
                ExerciseSpec(name: "Handtuch-Rudern (Türrahmen)", sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 75),
                ExerciseSpec(name: "Kniebeuge (BW)",               sets: 4, repsMin: 15, repsMax: 20, restSeconds: 60),
                ExerciseSpec(name: "Ausfallschritte (BW)",         sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60),
                ExerciseSpec(name: "Hip Thrust (BW)",              sets: 3, repsMin: 15, repsMax: 20, restSeconds: 60),
                ExerciseSpec(name: "Seitstütz",                   sets: 3, repsMin: 20, repsMax: 30, restSeconds: 60, targetRir: 3.0)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 5, exercises: []),
            DaySpec(name: "Ganzkörper HIIT", type: .fullBody, weekday: 6, exercises: [
                ExerciseSpec(name: "Burpees",                      sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Breite Liegestütze",          sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Jump Squat",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Mountain Climbers",            sets: 3, repsMin: 20, repsMax: 30, restSeconds: 60),
                ExerciseSpec(name: "Plank",                        sets: 3, repsMin: 30, repsMax: 45, restSeconds: 60, targetRir: 3.0)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 7, exercises: []),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .noEquipment,
        iconSystemName: "figure.run"
    )

    // MARK: - 5. Push-Pull-Legs (6 days)

    private static let pushPullLegs = ProgramTemplate(
        id: "push_pull_legs",
        name: "Push-Pull-Legs",
        tagline: "6 Tage · Hypertrophie + Kraft",
        descriptionText: "Wissenschaftlich optimierter Split. Jede Muskelgruppe wird 2x pro Woche trainiert – ideal für intermediäre Sportler laut Meta-Analysen.",
        focus: "Hypertrophie",
        daysPerWeek: 6,
        days: [
            DaySpec(name: "Push A", type: .push, weekday: 2, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 4, repsMin: 4,  repsMax: 6,  restSeconds: 180),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 6,  repsMax: 8,  restSeconds: 120),
                ExerciseSpec(name: "Schrägbankdrücken (aufwärts)", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Seitheben",                    sets: 4, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Trizep Pushdown (Kabel)",      sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "KH Overhead Trizep Extension", sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75)
            ]),
            DaySpec(name: "Pull A", type: .pull, weekday: 3, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 3, repsMin: 4,  repsMax: 6,  restSeconds: 180),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 4, repsMin: 6,  repsMax: 8,  restSeconds: 120),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120),
                ExerciseSpec(name: "Face Pull",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Langhantel Curl",              sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Hammer Curl",                  sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75)
            ]),
            DaySpec(name: "Beine A", type: .legs, weekday: 4, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 4, repsMin: 6,  repsMax: 8,  restSeconds: 180),
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 4, repsMin: 8,  repsMax: 10, restSeconds: 120),
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Beinbeuger liegend",           sets: 3, repsMin: 10, repsMax: 15, restSeconds: 90),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 4, repsMin: 12, repsMax: 20, restSeconds: 60)
            ]),
            DaySpec(name: "Push B", type: .push, weekday: 5, exercises: [
                ExerciseSpec(name: "KH-Schrägbankdrücken (aufwärts)", sets: 4, repsMin: 8, repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "KH-Schulterdrücken",          sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Pec Deck (Butterfly)",         sets: 3, repsMin: 12, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Kabel Seitheben",              sets: 4, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Overhead Trizep Extension (Kabel)", sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Dips (Trizeps)",               sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90)
            ]),
            DaySpec(name: "Pull B", type: .pull, weekday: 6, exercises: [
                ExerciseSpec(name: "Latzug (weit)",                sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Kabelrudern sitzend",          sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "KH-Rudern einarmig",           sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Reverse Flyes (KH)",           sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Kabel Curl",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Schrägbank Curl",             sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75)
            ]),
            DaySpec(name: "Beine B", type: .legs, weekday: 7, exercises: [
                ExerciseSpec(name: "Front Squat",                  sets: 4, repsMin: 6,  repsMax: 8,  restSeconds: 180),
                ExerciseSpec(name: "Hip Thrust (LH)",              sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Beinpresse",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 90),
                ExerciseSpec(name: "Nordic Curls",                 sets: 3, repsMin: 4,  repsMax: 8,  restSeconds: 120),
                ExerciseSpec(name: "Beinstrecker",                 sets: 3, repsMin: 12, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Wadenpresse (sitzend)",        sets: 4, repsMin: 12, repsMax: 20, restSeconds: 60)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.strengthtraining.functional"
    )

    // MARK: - 6. Upper-Lower-Split (4 days)

    private static let upperLower = ProgramTemplate(
        id: "upper_lower",
        name: "Upper-Lower-Split",
        tagline: "4 Tage · Kraft & Hypertrophie",
        descriptionText: "Optimale Balance zwischen Frequenz und Volumen. Laut Studienlage der effektivste Split für Kraft- und Muskelaufbau bei Intermediären.",
        focus: "Kraft + Hypertrophie",
        daysPerWeek: 4,
        days: [
            DaySpec(name: "Oberkörper A (Kraft)", type: .upper, weekday: 2, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 4, repsMin: 3,  repsMax: 5,  restSeconds: 180),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 4, repsMin: 4,  repsMax: 6,  restSeconds: 150),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 5,  repsMax: 7,  restSeconds: 120),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 5,  repsMax: 8,  restSeconds: 120),
                ExerciseSpec(name: "Langhantel Curl",              sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 75),
                ExerciseSpec(name: "Skull Crusher",                sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 75)
            ]),
            DaySpec(name: "Unterkörper A (Kraft)", type: .lower, weekday: 3, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 4, repsMin: 3,  repsMax: 5,  restSeconds: 210),
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 3, repsMin: 6,  repsMax: 8,  restSeconds: 150),
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 90),
                ExerciseSpec(name: "Beinbeuger liegend",           sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 4, repsMin: 10, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 4, exercises: []),
            DaySpec(name: "Oberkörper B (Volumen)", type: .upper, weekday: 5, exercises: [
                ExerciseSpec(name: "KH-Schrägbankdrücken (aufwärts)", sets: 4, repsMin: 8, repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Kabelrudern sitzend",          sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Pec Deck (Butterfly)",         sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Latzug (weit)",                sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Seitheben",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Hammer Curl",                  sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Trizep Pushdown (Kabel)",      sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Unterkörper B (Volumen)", type: .lower, weekday: 6, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 3, repsMin: 3,  repsMax: 5,  restSeconds: 210),
                ExerciseSpec(name: "Beinpresse",                   sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Hip Thrust (LH)",              sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Nordic Curls",                 sets: 3, repsMin: 4,  repsMax: 8,  restSeconds: 120),
                ExerciseSpec(name: "Beinstrecker",                 sets: 3, repsMin: 12, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Wadenpresse (sitzend)",        sets: 4, repsMin: 12, repsMax: 20, restSeconds: 60)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 7, exercises: []),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.cooldown"
    )

    // MARK: - 7. Arnold Split (6 days)

    private static let arnoldSplit = ProgramTemplate(
        id: "arnold_split",
        name: "Arnold Split",
        tagline: "6 Tage · Bodybuilding",
        descriptionText: "Arnold Schwarzeneggers Trainingsansatz: Antagonisten (Brust+Rücken) werden gemeinsam trainiert für maximalen Pump und Dichte.",
        focus: "Hypertrophie",
        daysPerWeek: 6,
        days: [
            DaySpec(name: "Brust & Rücken A", type: .upper, weekday: 2, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 150),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 120),
                ExerciseSpec(name: "KH-Flyes (flach)",             sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120),
                ExerciseSpec(name: "Kabel Crossover",              sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Kabelrudern sitzend",          sets: 3, repsMin: 10, repsMax: 12, restSeconds: 75)
            ]),
            DaySpec(name: "Schultern & Arme A", type: .upper, weekday: 3, exercises: [
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 120),
                ExerciseSpec(name: "Seitheben",                    sets: 4, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Langhantel Curl",              sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Skull Crusher",                sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Hammer Curl",                  sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Trizep Pushdown (Kabel)",      sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Beine A", type: .legs, weekday: 4, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 180),
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Beinpresse",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 90),
                ExerciseSpec(name: "Beinstrecker",                 sets: 3, repsMin: 12, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 4, repsMin: 12, repsMax: 20, restSeconds: 60)
            ]),
            DaySpec(name: "Brust & Rücken B", type: .upper, weekday: 5, exercises: [
                ExerciseSpec(name: "Schrägbankdrücken (aufwärts)", sets: 4, repsMin: 8, repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "KH-Rudern einarmig",           sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Pec Deck (Butterfly)",         sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Latzug (weit)",                sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Brust-Drückmaschine",         sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Face Pull",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Schultern & Arme B", type: .upper, weekday: 6, exercises: [
                ExerciseSpec(name: "KH-Schulterdrücken",          sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Kabel Seitheben",              sets: 4, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Kabel Curl",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "KH Overhead Trizep Extension", sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Konzentrations Curl",          sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Overhead Trizep Extension (Kabel)", sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Beine B", type: .legs, weekday: 7, exercises: [
                ExerciseSpec(name: "Front Squat",                  sets: 4, repsMin: 6,  repsMax: 8,  restSeconds: 180),
                ExerciseSpec(name: "Hip Thrust (LH)",              sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Beinbeuger liegend",           sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Wadenpresse (sitzend)",        sets: 4, repsMin: 12, repsMax: 20, restSeconds: 60)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.arms.open"
    )

    // MARK: - 8. Bro-Split (5 days)

    private static let broSplit = ProgramTemplate(
        id: "bro_split",
        name: "Bro-Split",
        tagline: "5 Tage · Hypertrophie",
        descriptionText: "Klassischer Bodybuilding-Split mit hohem Volumen pro Muskelgruppe. Jede Muskelgruppe wird einmal pro Woche mit maximaler Erschöpfung trainiert.",
        focus: "Hypertrophie",
        daysPerWeek: 5,
        days: [
            DaySpec(name: "Brust", type: .chest, weekday: 2, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 150),
                ExerciseSpec(name: "Schrägbankdrücken (aufwärts)", sets: 4, repsMin: 8, repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "KH-Flyes (Schrägbank)",       sets: 3, repsMin: 10, repsMax: 15, restSeconds: 90),
                ExerciseSpec(name: "Kabel Crossover",              sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Dips (Brust)",                 sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 90)
            ]),
            DaySpec(name: "Rücken", type: .back, weekday: 3, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 4, repsMin: 4,  repsMax: 6,  restSeconds: 180),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 120),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120),
                ExerciseSpec(name: "Kabelrudern sitzend",          sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "KH-Rudern einarmig",           sets: 3, repsMin: 10, repsMax: 12, restSeconds: 90)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 4, exercises: []),
            DaySpec(name: "Schultern", type: .shoulders, weekday: 5, exercises: [
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 120),
                ExerciseSpec(name: "Seitheben",                    sets: 4, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Face Pull",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Frontheben",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "Reverse Flyes (KH)",           sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Arme", type: .arms, weekday: 6, exercises: [
                ExerciseSpec(name: "Langhantel Curl",              sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Hammer Curl",                  sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Schrägbank Curl",             sets: 3, repsMin: 10, repsMax: 15, restSeconds: 75),
                ExerciseSpec(name: "Skull Crusher",                sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 90),
                ExerciseSpec(name: "Trizep Pushdown (Kabel)",      sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60),
                ExerciseSpec(name: "KH Overhead Trizep Extension", sets: 3, repsMin: 10, repsMax: 15, restSeconds: 60)
            ]),
            DaySpec(name: "Beine", type: .legs, weekday: 7, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 180),
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 4, repsMin: 8,  repsMax: 12, restSeconds: 120),
                ExerciseSpec(name: "Beinpresse",                   sets: 3, repsMin: 10, repsMax: 15, restSeconds: 120),
                ExerciseSpec(name: "Beinbeuger liegend",           sets: 3, repsMin: 10, repsMax: 15, restSeconds: 90),
                ExerciseSpec(name: "Beinstrecker",                 sets: 3, repsMin: 12, repsMax: 15, restSeconds: 90),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 4, repsMin: 12, repsMax: 20, restSeconds: 60)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.flexibility"
    )

    // MARK: - 9. Powerlifting 5×5 (3 days)

    private static let powerlifting5x5 = ProgramTemplate(
        id: "powerlifting_5x5",
        name: "Powerlifting 5x5",
        tagline: "3 Tage · Kraft & Masse",
        descriptionText: "Das bewährteste Kraft-Programm für Anfänger & Fortgeschrittene. Progressive Überlastung mit den Grundübungen — wissenschaftlich und praktisch belegt.",
        focus: "Kraft",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Workout A", type: .fullBody, weekday: 2, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 210),
                ExerciseSpec(name: "Bankdrücken",                 sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 180),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 150)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 3, exercises: []),
            DaySpec(name: "Workout B", type: .fullBody, weekday: 4, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 210),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 180),
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 1, repsMin: 5,  repsMax: 5,  restSeconds: 210)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 5, exercises: []),
            DaySpec(name: "Workout A", type: .fullBody, weekday: 6, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 210),
                ExerciseSpec(name: "Bankdrücken",                 sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 180),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 5, repsMin: 5,  repsMax: 5,  restSeconds: 150)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 7, exercises: []),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .gym,
        iconSystemName: "scalemass.fill"
    )

    // MARK: - 10. Powerlifting 3×5 (3 days)

    private static let powerlifting3x5 = ProgramTemplate(
        id: "powerlifting_3x5",
        name: "Powerlifting 3x5",
        tagline: "3 Tage · Maximalkraft",
        descriptionText: "Dreier-Frequenz auf die Grundübungen Kniebeuge, Bankdrücken und Kreuzheben. Jede Session dreht sich um eine primäre Wettkampfübung mit schweren 3x5-Sätzen.",
        focus: "Kraft",
        daysPerWeek: 3,
        days: [
            DaySpec(name: "Tag 1 – Kniebeuge-Tag", type: .fullBody, weekday: 2, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 240, targetRir: 1.5),
                ExerciseSpec(name: "Bankdrücken",                 sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 210, targetRir: 1.5),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 150, targetRir: 2.5)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 3, exercises: []),
            DaySpec(name: "Tag 2 – Bankdrück-Tag", type: .fullBody, weekday: 4, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 240, targetRir: 1.5),
                ExerciseSpec(name: "Kniebeuge",                    sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 180, targetRir: 2.5),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 5,  repsMax: 8,  restSeconds: 150, targetRir: 2.5)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 5, exercises: []),
            DaySpec(name: "Tag 3 – Kreuzhebe-Tag", type: .fullBody, weekday: 6, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 240, targetRir: 1.5),
                ExerciseSpec(name: "Front Squat",                  sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 180, targetRir: 2.5),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 180, targetRir: 2.5)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 7, exercises: []),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .gym,
        iconSystemName: "dumbbell.fill"
    )

    // MARK: - 11. Fußball Athletik (2 days)

    private static let footballAthletic = ProgramTemplate(
        id: "football_athletic",
        name: "Fussball Athletik",
        tagline: "2 Tage · Kraft & Explosivität",
        descriptionText: "Athletik-Programm für Mannschaftssportler: Maximalkraft und Schnellkraft in zwei kompakten Einheiten pro Woche — ideal als Ergänzung zum Vereinstraining.",
        focus: "Athletik",
        daysPerWeek: 2,
        days: [
            DaySpec(name: "Ruhetag", type: .rest, weekday: 2, exercises: []),
            DaySpec(name: "Unterkörper & Core", type: .legs, weekday: 3, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 150, targetRir: 2.5),
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 8,  repsMax: 8,  restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Nordic Curls",                 sets: 3, repsMin: 5,  repsMax: 8,  restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 4, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 2.5),
                ExerciseSpec(name: "Plank",                        sets: 3, repsMin: 30, repsMax: 45, restSeconds: 60,  targetRir: 3.5)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 4, exercises: []),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 5, exercises: []),
            DaySpec(name: "Oberkörper & Explosivität", type: .upper, weekday: 6, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Seitstütz",                   sets: 3, repsMin: 20, repsMax: 30, restSeconds: 60,  targetRir: 3.5),
                ExerciseSpec(name: "Box Jump",                     sets: 3, repsMin: 5,  repsMax: 5,  restSeconds: 120, targetRir: 3.5)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 7, exercises: []),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .gym,
        iconSystemName: "soccerball"
    )

    // MARK: - 12. Hybrid Athlete — Beginner (DEL-055)

    /// 4-Tage-Plan fuer Einsteiger ins Concurrent Training (Kraft + Laufen).
    /// 2 Kraft-Tage mit Ganzkoerper-Compounds, 2 Lauf-Tage (1 Easy, 1 Long).
    /// Strength-RIR bewusst bei 2.5–3 → Sicherheitsabstand zum Versagen,
    /// damit am Folgetag das Laufen nicht abgekratzt wird.
    private static let hybridBeginner = ProgramTemplate(
        id: "hybrid_beginner",
        name: "Hybrid Athlete — Beginner",
        tagline: "4 Tage · Kraft + Laufen Einstieg",
        descriptionText: "Concurrent-Training light: zwei Ganzkörper-Strength-Einheiten + zwei lockere Lauf-Tage pro Woche. RIR-Puffer schützt den Laufmotor, kein zerstörendes Versagens-Training.",
        focus: "Hybrid & Athletik",
        daysPerWeek: 4,
        days: [
            DaySpec(name: "Strength Ganzkörper A", type: .fullBody, weekday: 2, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 3, repsMin: 6,  repsMax: 8,  restSeconds: 150, targetRir: 2.5),
                ExerciseSpec(name: "Bankdrücken",                 sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Plank",                        sets: 3, repsMin: 30, repsMax: 45, restSeconds: 60,  targetRir: 3.0)
            ]),
            DaySpec(name: "Easy Run", type: .cardio, weekday: 3, exercises: [
                // DEL-058: Cardio mit targetDistanceKm + targetDurationMinutes.
                // repsMin/repsMax bleiben 1/1 — sind im Cardio-Branch der UI
                // unsichtbar, aber der Builder erwartet sie als Pflichtfelder.
                ExerciseSpec(name: "Easy Run",                     sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 5.0, targetDurationMinutes: 30)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 4, exercises: []),
            DaySpec(name: "Strength Ganzkörper B", type: .fullBody, weekday: 5, exercises: [
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                ExerciseSpec(name: "KH-Schulterdrücken",          sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Latzug (weit)",                sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "KH-Curl",                      sets: 2, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
            ]),
            DaySpec(name: "Long Run", type: .cardio, weekday: 6, exercises: [
                ExerciseSpec(name: "Long Run",                     sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 8.0, targetDurationMinutes: 50)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 7, exercises: []),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.run"
    )

    // MARK: - 13. Hybrid Athlete — Balanced (DEL-055)

    /// 5-Tage-Plan: 3 Strength + 2 Run. Klassische "Hybrid"-Balance fuer
    /// Fortgeschrittene, die Kraft UND Ausdauer parallel halten/steigern wollen.
    private static let hybridBalanced = ProgramTemplate(
        id: "hybrid_balanced",
        name: "Hybrid Athlete — Balanced",
        tagline: "5 Tage · Kraft + Ausdauer in Balance",
        descriptionText: "Drei fokussierte Strength-Einheiten (Push/Pull/Legs-Light) plus zwei strategisch platzierte Lauf-Tage. RIR-Puffer 2–3 verhindert systemische Erschöpfung — bleibt Trainings-vertrāglich.",
        focus: "Hybrid & Athletik",
        daysPerWeek: 5,
        days: [
            DaySpec(name: "Strength Push", type: .push, weekday: 2, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 4, repsMin: 6,  repsMax: 8,  restSeconds: 150, targetRir: 2.5),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Schrägbankdrücken (aufwärts)", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Trizep Pushdown (Kabel)",      sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
            ]),
            DaySpec(name: "Easy Run", type: .cardio, weekday: 3, exercises: [
                ExerciseSpec(name: "Easy Run",                     sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 6.0, targetDurationMinutes: 35)
            ]),
            DaySpec(name: "Strength Pull", type: .pull, weekday: 4, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 3, repsMin: 5,  repsMax: 6,  restSeconds: 180, targetRir: 3.0),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 3, repsMin: 8,  repsMax: 12, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "KH-Curl",                      sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
            ]),
            DaySpec(name: "Long Run", type: .cardio, weekday: 5, exercises: [
                ExerciseSpec(name: "Long Run",                     sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 12.0, targetDurationMinutes: 70)
            ]),
            DaySpec(name: "Strength Legs (Light)", type: .legs, weekday: 6, exercises: [
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 2.0),
                ExerciseSpec(name: "Plank",                        sets: 3, repsMin: 30, repsMax: 60, restSeconds: 60,  targetRir: 3.0)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 7, exercises: []),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.mixed.cardio"
    )

    // MARK: - 14. Hybrid Athlete — Performance (DEL-055)

    /// 6-Tage-Plan: 3 Strength + 3 Run (inkl. Intervall-Einheit). Ambitioniert,
    /// fuer User, die wissen was sie tun (z.B. Hyrox-/Triathlon-Vorbereitung).
    /// Strength-RIR konservativ 2.5 — der Volumen-Stress ueber 6 Tage ist hoch
    /// genug, da darf man am Stahl nicht auch noch ans Limit gehen.
    private static let hybridPerformance = ProgramTemplate(
        id: "hybrid_performance",
        name: "Hybrid Athlete — Performance",
        tagline: "6 Tage · Wettkampf-Hybrid",
        descriptionText: "Sechs Trainingstage: drei Strength-Einheiten (Push/Pull/Legs) + drei Läufe (Easy, Intervalle, Long Run). Strength-RIR konservativ 2.5, damit der Gesamt-Volumen-Stress trainings-vertraglich bleibt.",
        focus: "Hybrid & Athletik",
        daysPerWeek: 6,
        days: [
            DaySpec(name: "Strength Push", type: .push, weekday: 2, exercises: [
                ExerciseSpec(name: "Bankdrücken",                 sets: 4, repsMin: 5,  repsMax: 8,  restSeconds: 180, targetRir: 2.5),
                ExerciseSpec(name: "Schulterdrücken (stehend)",   sets: 3, repsMin: 6,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                ExerciseSpec(name: "Schrägbankdrücken (aufwärts)", sets: 3, repsMin: 8, repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Seitheben",                    sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 1.5),
                ExerciseSpec(name: "Trizep Pushdown (Kabel)",      sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
            ]),
            DaySpec(name: "Easy Run", type: .cardio, weekday: 3, exercises: [
                ExerciseSpec(name: "Easy Run",                     sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 8.0, targetDurationMinutes: 45)
            ]),
            DaySpec(name: "Strength Pull", type: .pull, weekday: 4, exercises: [
                ExerciseSpec(name: "Kreuzheben (konventionell)",   sets: 3, repsMin: 4,  repsMax: 6,  restSeconds: 210, targetRir: 3.0),
                ExerciseSpec(name: "Klimmzüge (weit)",            sets: 4, repsMin: 6,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Rudern vorgebeugt",            sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "KH-Curl",                      sets: 3, repsMin: 10, repsMax: 12, restSeconds: 60,  targetRir: 1.0)
            ]),
            DaySpec(name: "Intervalle", type: .cardio, weekday: 5, exercises: [
                // Intervall-Einheit: kurze Distanz, hohe Intensitaet — wir
                // setzen nur Dauer als Placeholder, Distanz traegt der User
                // selbst ein (variiert je nach Splits).
                ExerciseSpec(name: "Intervalle",                   sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDurationMinutes: 30)
            ]),
            DaySpec(name: "Strength Legs", type: .legs, weekday: 6, exercises: [
                ExerciseSpec(name: "Kniebeuge",                    sets: 4, repsMin: 5,  repsMax: 8,  restSeconds: 180, targetRir: 2.5),
                ExerciseSpec(name: "Rumänisches Kreuzheben",      sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 150, targetRir: 2.5),
                ExerciseSpec(name: "Bulgarische Kniebeuge (KH)",   sets: 3, repsMin: 8,  repsMax: 10, restSeconds: 120, targetRir: 2.5),
                ExerciseSpec(name: "Wadenheben (stehend, LH)",     sets: 3, repsMin: 12, repsMax: 15, restSeconds: 60,  targetRir: 2.0)
            ]),
            DaySpec(name: "Long Run", type: .cardio, weekday: 7, exercises: [
                ExerciseSpec(name: "Long Run",                     sets: 1, repsMin: 1, repsMax: 1, restSeconds: 0, targetRir: 0, isCardio: true, targetDistanceKm: 15.0, targetDurationMinutes: 85)
            ]),
            DaySpec(name: "Ruhetag", type: .rest, weekday: 1, exercises: [])
        ],
        targetEnvironment: .gym,
        iconSystemName: "figure.run.circle.fill"
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
        hybridPerformance
    ]
}
