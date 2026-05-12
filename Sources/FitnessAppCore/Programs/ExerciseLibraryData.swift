import Foundation

/// Seed library of exercise templates. `LibrarySeeder` (in `FitnessAppData`) reads
/// this list on first app launch and writes one `ExerciseTemplate` row per spec.
///
/// Idempotency: the seeder checks for existing rows before inserting, so editing
/// this list does NOT auto-update existing installs. New entries are picked up;
/// modified or removed entries require a manual user library reset.
public enum ExerciseLibraryData {

    public static let all: [ExerciseTemplateSpec] = [
        // ── BARBELL · CHEST ────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Bankdrücken",                     equipment: .barbell, primaryMuscle: .chest,      isSystemCompound: true),
        ExerciseTemplateSpec(name: "Schrägbankdrücken (aufwärts)",  equipment: .barbell, primaryMuscle: .chest),
        ExerciseTemplateSpec(name: "Schrägbankdrücken (abwärts)",   equipment: .barbell, primaryMuscle: .chest),
        ExerciseTemplateSpec(name: "Enges Bankdrücken",               equipment: .barbell, primaryMuscle: .triceps),

        // ── BARBELL · BACK ─────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kreuzheben (konventionell)",       equipment: .barbell, primaryMuscle: .back,       difficultyLevel: .advanced, isSystemCompound: true),
        ExerciseTemplateSpec(name: "Sumo-Kreuzheben",                  equipment: .barbell, primaryMuscle: .hamstrings, difficultyLevel: .advanced),
        ExerciseTemplateSpec(name: "Rudern vorgebeugt",                equipment: .barbell, primaryMuscle: .back,       isSystemCompound: true),
        ExerciseTemplateSpec(name: "Pendlay Row",                      equipment: .barbell, primaryMuscle: .back),
        ExerciseTemplateSpec(name: "T-Bar Rudern",                     equipment: .barbell, primaryMuscle: .back),

        // ── BARBELL · SHOULDERS ────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Schulterdrücken (stehend)",       equipment: .barbell, primaryMuscle: .shoulders,  isSystemCompound: true),
        ExerciseTemplateSpec(name: "Push Press",                       equipment: .barbell, primaryMuscle: .shoulders,  difficultyLevel: .advanced),
        ExerciseTemplateSpec(name: "Nackendrücken",                   equipment: .barbell, primaryMuscle: .shoulders,  difficultyLevel: .advanced),
        ExerciseTemplateSpec(name: "Langhantel Shrug",                 equipment: .barbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner),

        // ── BARBELL · LEGS ─────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kniebeuge",                        equipment: .barbell, primaryMuscle: .quads,      isSystemCompound: true),
        ExerciseTemplateSpec(name: "Front Squat",                      equipment: .barbell, primaryMuscle: .quads,      difficultyLevel: .advanced),
        ExerciseTemplateSpec(name: "Zercher Squat",                    equipment: .barbell, primaryMuscle: .quads,      difficultyLevel: .advanced),
        ExerciseTemplateSpec(name: "Rumänisches Kreuzheben",          equipment: .barbell, primaryMuscle: .hamstrings),
        ExerciseTemplateSpec(name: "Hip Thrust (LH)",                  equipment: .barbell, primaryMuscle: .glutes),
        ExerciseTemplateSpec(name: "Ausfallschritte (LH)",             equipment: .barbell, primaryMuscle: .quads),
        ExerciseTemplateSpec(name: "Good Morning",                     equipment: .barbell, primaryMuscle: .hamstrings, difficultyLevel: .advanced),
        ExerciseTemplateSpec(name: "Wadenheben (stehend, LH)",         equipment: .barbell, primaryMuscle: .calves),

        // ── BARBELL · ARMS ─────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Langhantel Curl",                  equipment: .barbell, primaryMuscle: .biceps),
        ExerciseTemplateSpec(name: "Reverse Curl",                     equipment: .barbell, primaryMuscle: .biceps),
        ExerciseTemplateSpec(name: "Skull Crusher",                    equipment: .barbell, primaryMuscle: .triceps),

        // ── DUMBBELL · CHEST ───────────────────────────────────────────────
        ExerciseTemplateSpec(name: "KH-Bankdrücken",                  equipment: .dumbbell, primaryMuscle: .chest),
        ExerciseTemplateSpec(name: "KH-Schrägbankdrücken (aufwärts)", equipment: .dumbbell, primaryMuscle: .chest),
        ExerciseTemplateSpec(name: "KH-Flyes (flach)",                 equipment: .dumbbell, primaryMuscle: .chest,      difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "KH-Flyes (Schrägbank)",           equipment: .dumbbell, primaryMuscle: .chest,      difficultyLevel: .beginner),

        // ── DUMBBELL · BACK ────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "KH-Rudern einarmig",               equipment: .dumbbell, primaryMuscle: .back),
        ExerciseTemplateSpec(name: "Chest Supported Row (KH)",         equipment: .dumbbell, primaryMuscle: .back),
        ExerciseTemplateSpec(name: "KH-Pullover",                      equipment: .dumbbell, primaryMuscle: .back),

        // ── DUMBBELL · SHOULDERS ───────────────────────────────────────────
        ExerciseTemplateSpec(name: "KH-Schulterdrücken",              equipment: .dumbbell, primaryMuscle: .shoulders),
        ExerciseTemplateSpec(name: "Seitheben",                        equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Frontheben",                       equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Reverse Flyes (KH)",               equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "KH-Shrug",                         equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner),

        // ── DUMBBELL · LEGS ────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Goblet Squat",                     equipment: .dumbbell, primaryMuscle: .quads,      difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "KH-Ausfallschritte",               equipment: .dumbbell, primaryMuscle: .quads),
        ExerciseTemplateSpec(name: "Bulgarische Kniebeuge (KH)",       equipment: .dumbbell, primaryMuscle: .quads),
        ExerciseTemplateSpec(name: "KH-Romanian Deadlift",             equipment: .dumbbell, primaryMuscle: .hamstrings),
        ExerciseTemplateSpec(name: "Step-Up (KH)",                     equipment: .dumbbell, primaryMuscle: .quads,      difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "KH-Hip Thrust",                    equipment: .dumbbell, primaryMuscle: .glutes,     difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "KH-Wadenheben",                    equipment: .dumbbell, primaryMuscle: .calves,     difficultyLevel: .beginner),

        // ── DUMBBELL · ARMS ────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "KH-Curl",                          equipment: .dumbbell, primaryMuscle: .biceps,     difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Hammer Curl",                      equipment: .dumbbell, primaryMuscle: .biceps,     difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Schrägbank Curl",                 equipment: .dumbbell, primaryMuscle: .biceps),
        ExerciseTemplateSpec(name: "Konzentrations Curl",              equipment: .dumbbell, primaryMuscle: .biceps,     difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "KH Overhead Trizep Extension",     equipment: .dumbbell, primaryMuscle: .triceps),
        ExerciseTemplateSpec(name: "Trizep Kickback (KH)",             equipment: .dumbbell, primaryMuscle: .triceps),

        // ── BODYWEIGHT · UPPER ─────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Klimmzüge (weit)",                equipment: .bodyweight, primaryMuscle: .back),
        ExerciseTemplateSpec(name: "Klimmzüge (eng/Chin-up)",         equipment: .bodyweight, primaryMuscle: .back),
        ExerciseTemplateSpec(name: "Australian Pull-ups",              equipment: .bodyweight, primaryMuscle: .back),
        ExerciseTemplateSpec(name: "Handtuch-Rudern (Türrahmen)",     equipment: .bodyweight, primaryMuscle: .back,      difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Liegestütze",                     equipment: .bodyweight, primaryMuscle: .chest,     difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Diamant-Liegestütze",             equipment: .bodyweight, primaryMuscle: .triceps),
        ExerciseTemplateSpec(name: "Breite Liegestütze",              equipment: .bodyweight, primaryMuscle: .chest),
        ExerciseTemplateSpec(name: "Dips (Brust)",                     equipment: .bodyweight, primaryMuscle: .chest),
        ExerciseTemplateSpec(name: "Dips (Trizeps)",                   equipment: .bodyweight, primaryMuscle: .triceps),
        ExerciseTemplateSpec(name: "Pike Liegestütze",                equipment: .bodyweight, primaryMuscle: .shoulders),
        ExerciseTemplateSpec(name: "Handstand-Liegestütze",           equipment: .bodyweight, primaryMuscle: .shoulders, difficultyLevel: .advanced),

        // ── BODYWEIGHT · LOWER ─────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kniebeuge (BW)",                   equipment: .bodyweight, primaryMuscle: .quads,     difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Jump Squat",                       equipment: .bodyweight, primaryMuscle: .quads),
        ExerciseTemplateSpec(name: "Ausfallschritte (BW)",             equipment: .bodyweight, primaryMuscle: .quads,     difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Box Jump",                         equipment: .bodyweight, primaryMuscle: .quads),
        ExerciseTemplateSpec(name: "Wall Sit",                         equipment: .bodyweight, primaryMuscle: .quads,     difficultyLevel: .beginner, isTimeBased: true),
        ExerciseTemplateSpec(name: "Nordic Curls",                     equipment: .bodyweight, primaryMuscle: .hamstrings),
        ExerciseTemplateSpec(name: "Glute Bridge (BW)",                equipment: .bodyweight, primaryMuscle: .glutes,    difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Hip Thrust (BW)",                  equipment: .bodyweight, primaryMuscle: .glutes,    difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Wadenheben (BW)",                  equipment: .bodyweight, primaryMuscle: .calves,    difficultyLevel: .beginner),

        // ── BODYWEIGHT · CORE ──────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Plank",                            equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isTimeBased: true),
        ExerciseTemplateSpec(name: "Seitstütz",                       equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isTimeBased: true),
        ExerciseTemplateSpec(name: "Mountain Climbers",                equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isTimeBased: true),
        ExerciseTemplateSpec(name: "Burpees",                          equipment: .bodyweight, primaryMuscle: .core,      isTimeBased: true),
        ExerciseTemplateSpec(name: "Sit-ups",                          equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Beinstrecker liegend",             equipment: .bodyweight, primaryMuscle: .core),
        ExerciseTemplateSpec(name: "Russian Twists",                   equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Hanging Leg Raises",               equipment: .bodyweight, primaryMuscle: .core),

        // ── MACHINE / CABLE · CHEST ────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kabel Crossover",                  equipment: .cable,    primaryMuscle: .chest),
        ExerciseTemplateSpec(name: "Pec Deck (Butterfly)",             equipment: .machine,  primaryMuscle: .chest,       difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Brust-Drückmaschine",             equipment: .machine,  primaryMuscle: .chest,       difficultyLevel: .beginner),

        // ── MACHINE / CABLE · BACK ─────────────────────────────────────────
        ExerciseTemplateSpec(name: "Latzug (weit)",                    equipment: .machine,  primaryMuscle: .back,        difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Latzug (eng)",                     equipment: .machine,  primaryMuscle: .back,        difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Kabelrudern sitzend",              equipment: .cable,    primaryMuscle: .back,        difficultyLevel: .beginner),

        // ── MACHINE / CABLE · SHOULDERS ────────────────────────────────────
        ExerciseTemplateSpec(name: "Kabel Seitheben",                  equipment: .cable,    primaryMuscle: .shoulders,   difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Face Pull",                        equipment: .cable,    primaryMuscle: .shoulders),
        ExerciseTemplateSpec(name: "Schulterdrück-Maschine",          equipment: .machine,  primaryMuscle: .shoulders,   difficultyLevel: .beginner),

        // ── MACHINE / CABLE · ARMS ─────────────────────────────────────────
        ExerciseTemplateSpec(name: "Trizep Pushdown (Kabel)",          equipment: .cable,    primaryMuscle: .triceps),
        ExerciseTemplateSpec(name: "Overhead Trizep Extension (Kabel)", equipment: .cable,   primaryMuscle: .triceps),
        ExerciseTemplateSpec(name: "Preacher Curl (Maschine)",         equipment: .machine,  primaryMuscle: .biceps,      difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Kabel Curl",                       equipment: .cable,    primaryMuscle: .biceps,      difficultyLevel: .beginner),

        // ── MACHINE / CABLE · LEGS ─────────────────────────────────────────
        ExerciseTemplateSpec(name: "Beinpresse",                       equipment: .machine,  primaryMuscle: .quads,       difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Beinstrecker",                     equipment: .machine,  primaryMuscle: .quads,       difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Beinbeuger liegend",               equipment: .machine,  primaryMuscle: .hamstrings,  difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Hack Squat",                       equipment: .machine,  primaryMuscle: .quads),
        ExerciseTemplateSpec(name: "Smith Machine Squat",              equipment: .machine,  primaryMuscle: .quads),
        ExerciseTemplateSpec(name: "Wadenpresse (sitzend)",            equipment: .machine,  primaryMuscle: .calves,      difficultyLevel: .beginner),

        // ── MACHINE / CABLE · CORE ─────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kabel Crunch",                     equipment: .cable,    primaryMuscle: .core,        difficultyLevel: .beginner),

        // ── RESISTANCE BAND ────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Band Pull-Aparts",                 equipment: .band,     primaryMuscle: .back,        difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Banded Squats",                    equipment: .band,     primaryMuscle: .quads,       difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Band Curls",                       equipment: .band,     primaryMuscle: .biceps,      difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Banded Hip Thrust",                equipment: .band,     primaryMuscle: .glutes,      difficultyLevel: .beginner),

        // ── KETTLEBELL ─────────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kettlebell Swing",                 equipment: .kettlebell, primaryMuscle: .glutes),
        ExerciseTemplateSpec(name: "Turkish Get-Up",                   equipment: .kettlebell, primaryMuscle: .core,      difficultyLevel: .advanced),
        ExerciseTemplateSpec(name: "Kettlebell Goblet Squat",          equipment: .kettlebell, primaryMuscle: .quads,     difficultyLevel: .beginner),
        ExerciseTemplateSpec(name: "Kettlebell Snatch",                equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced),
        ExerciseTemplateSpec(name: "Kettlebell Clean & Press",         equipment: .kettlebell, primaryMuscle: .shoulders),
        ExerciseTemplateSpec(name: "Kettlebell Halo",                  equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .beginner)
    ]
}
