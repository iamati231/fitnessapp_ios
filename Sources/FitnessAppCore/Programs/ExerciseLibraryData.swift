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
        // DEL-098: Bench Press = klassischer Compound, hoher Brust-Schaden +
        // moderater systemic Hit (kein axialer Loading-Stress wie Squat).
        ExerciseTemplateSpec(name: "Bankdrücken",                     equipment: .barbell, primaryMuscle: .chest,      isSystemCompound: true,
                             systemicFatigueFactor: 0.55, localMuscleDamageFactor: 0.60, cnsDemandFactor: 0.55, axialLoadFactor: 0.20, technicalComplexityFactor: 0.50, recoveryClass: .high,
                             localizationKey: "exercise.name.benchpress"),
        ExerciseTemplateSpec(name: "Schrägbankdrücken (aufwärts)",  equipment: .barbell, primaryMuscle: .chest, localizationKey: "exercise.name.inclineBenchPress"),
        ExerciseTemplateSpec(name: "Schrägbankdrücken (abwärts)",   equipment: .barbell, primaryMuscle: .chest, localizationKey: "exercise.name.declineBenchPress"),
        ExerciseTemplateSpec(name: "Enges Bankdrücken",               equipment: .barbell, primaryMuscle: .triceps, localizationKey: "exercise.name.closeGripBenchPress"),

        // ── BARBELL · BACK ─────────────────────────────────────────────────
        // DEL-098: Deadlift = systemic-king. Hoechste Axial-Load aller Lifts.
        ExerciseTemplateSpec(name: "Kreuzheben (konventionell)",       equipment: .barbell, primaryMuscle: .back,       difficultyLevel: .advanced, isSystemCompound: true,
                             systemicFatigueFactor: 0.95, localMuscleDamageFactor: 0.75, cnsDemandFactor: 0.95, axialLoadFactor: 1.00, technicalComplexityFactor: 0.80, recoveryClass: .extreme,
                             localizationKey: "exercise.name.deadlift"),
        ExerciseTemplateSpec(name: "Sumo-Kreuzheben",                  equipment: .barbell, primaryMuscle: .hamstrings, difficultyLevel: .advanced,
                             systemicFatigueFactor: 0.90, localMuscleDamageFactor: 0.75, cnsDemandFactor: 0.90, axialLoadFactor: 0.95, technicalComplexityFactor: 0.75, recoveryClass: .extreme,
                             localizationKey: "exercise.name.sumoDeadlift"),
        ExerciseTemplateSpec(name: "Rudern vorgebeugt",                equipment: .barbell, primaryMuscle: .back,       isSystemCompound: true,
                             localizationKey: "exercise.name.barbellrow"),
        ExerciseTemplateSpec(name: "Pendlay Row",                      equipment: .barbell, primaryMuscle: .back, localizationKey: "exercise.name.pendlayRow"),
        ExerciseTemplateSpec(name: "T-Bar Rudern",                     equipment: .barbell, primaryMuscle: .back, localizationKey: "exercise.name.tBarRow"),

        // ── BARBELL · SHOULDERS ────────────────────────────────────────────
        // DEL-098: Overhead Press = moderater Compound mit axialer Komponente
        // (vertikale Kette), aber leichter als Squat/DL.
        ExerciseTemplateSpec(name: "Schulterdrücken (stehend)",       equipment: .barbell, primaryMuscle: .shoulders,  isSystemCompound: true,
                             systemicFatigueFactor: 0.60, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.55, axialLoadFactor: 0.55, technicalComplexityFactor: 0.55, recoveryClass: .high,
                             localizationKey: "exercise.name.overheadpress"),
        ExerciseTemplateSpec(name: "Push Press",                       equipment: .barbell, primaryMuscle: .shoulders,  difficultyLevel: .advanced, localizationKey: "exercise.name.pushPress"),
        ExerciseTemplateSpec(name: "Nackendrücken",                   equipment: .barbell, primaryMuscle: .shoulders,  difficultyLevel: .advanced, localizationKey: "exercise.name.behindNeckPress"),
        ExerciseTemplateSpec(name: "Shrug (LH)",                 equipment: .barbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner, localizationKey: "exercise.name.barbellShrug"),

        // ── BARBELL · LEGS ─────────────────────────────────────────────────
        // DEL-098: Back Squat = grosser Compound, fast so systemic wie Deadlift.
        ExerciseTemplateSpec(name: "Kniebeuge",                        equipment: .barbell, primaryMuscle: .quads,      isSystemCompound: true,
                             systemicFatigueFactor: 0.90, localMuscleDamageFactor: 0.80, cnsDemandFactor: 0.85, axialLoadFactor: 0.95, technicalComplexityFactor: 0.75, recoveryClass: .extreme,
                             localizationKey: "exercise.name.squat"),
        ExerciseTemplateSpec(name: "Front Squat",                      equipment: .barbell, primaryMuscle: .quads,      difficultyLevel: .advanced,
                             systemicFatigueFactor: 0.85, localMuscleDamageFactor: 0.80, cnsDemandFactor: 0.80, axialLoadFactor: 0.90, technicalComplexityFactor: 0.80, recoveryClass: .high,
                             localizationKey: "exercise.name.frontSquat"),
        ExerciseTemplateSpec(name: "Zercher Squat",                    equipment: .barbell, primaryMuscle: .quads,      difficultyLevel: .advanced, localizationKey: "exercise.name.zercherSquat"),
        ExerciseTemplateSpec(name: "Rumänisches Kreuzheben",          equipment: .barbell, primaryMuscle: .hamstrings,
                             systemicFatigueFactor: 0.75, localMuscleDamageFactor: 0.80, cnsDemandFactor: 0.65, axialLoadFactor: 0.80, technicalComplexityFactor: 0.65, recoveryClass: .high,
                             localizationKey: "exercise.name.romanianDeadlift"),
        ExerciseTemplateSpec(name: "Hip Thrust (LH)",                  equipment: .barbell, primaryMuscle: .glutes, localizationKey: "exercise.name.barbellHipThrust"),
        ExerciseTemplateSpec(name: "Ausfallschritte (LH)",             equipment: .barbell, primaryMuscle: .quads, localizationKey: "exercise.name.barbellLunge"),
        ExerciseTemplateSpec(name: "Good Morning",                     equipment: .barbell, primaryMuscle: .hamstrings, difficultyLevel: .advanced, localizationKey: "exercise.name.goodMorning"),
        ExerciseTemplateSpec(name: "Wadenheben (stehend, LH)",         equipment: .barbell, primaryMuscle: .calves, localizationKey: "exercise.name.barbellStandingCalfRaise"),

        // ── BARBELL · ARMS ─────────────────────────────────────────────────
        // DEL-098: Curls = klassische Isolation. Sehr niedrige systemic-/CNS-
        // Last, kein axialer Belastung. Lokale Belastung etwas hoeher (Bizeps-
        // DOMS), aber im Vergleich zu Compounds ist alles trivial.
        ExerciseTemplateSpec(name: "Bizeps-Curl (LH)",                  equipment: .barbell, primaryMuscle: .biceps,
                             systemicFatigueFactor: 0.15, localMuscleDamageFactor: 0.35, cnsDemandFactor: 0.10, axialLoadFactor: 0.00, technicalComplexityFactor: 0.15, recoveryClass: .low,
                             localizationKey: "exercise.name.barbellCurl"),
        ExerciseTemplateSpec(name: "Reverse Curl",                     equipment: .barbell, primaryMuscle: .biceps, localizationKey: "exercise.name.reverseCurl"),
        ExerciseTemplateSpec(name: "Skull Crusher",                    equipment: .barbell, primaryMuscle: .triceps, localizationKey: "exercise.name.skullCrusher"),

        // ── DUMBBELL · CHEST ───────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Bankdrücken (KH)",                  equipment: .dumbbell, primaryMuscle: .chest, localizationKey: "exercise.name.dumbbellBenchPress"),
        ExerciseTemplateSpec(name: "Schrägbankdrücken aufwärts (KH)", equipment: .dumbbell, primaryMuscle: .chest, localizationKey: "exercise.name.dumbbellInclineBenchPress"),
        ExerciseTemplateSpec(name: "Flyes flach (KH)",                 equipment: .dumbbell, primaryMuscle: .chest,      difficultyLevel: .beginner, localizationKey: "exercise.name.dumbbellFlyFlat"),
        ExerciseTemplateSpec(name: "Flyes Schrägbank (KH)",           equipment: .dumbbell, primaryMuscle: .chest,      difficultyLevel: .beginner, localizationKey: "exercise.name.dumbbellFlyIncline"),

        // ── DUMBBELL · BACK ────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Rudern einarmig (KH)",               equipment: .dumbbell, primaryMuscle: .back, localizationKey: "exercise.name.dumbbellRowOneArm"),
        ExerciseTemplateSpec(name: "Chest Supported Row (KH)",         equipment: .dumbbell, primaryMuscle: .back, localizationKey: "exercise.name.chestSupportedRowDB"),
        ExerciseTemplateSpec(name: "Pullover (KH)",                      equipment: .dumbbell, primaryMuscle: .back, localizationKey: "exercise.name.dumbbellPullover"),

        // ── DUMBBELL · SHOULDERS ───────────────────────────────────────────
        ExerciseTemplateSpec(name: "Schulterdrücken (KH)",              equipment: .dumbbell, primaryMuscle: .shoulders, localizationKey: "exercise.name.dumbbellShoulderPress"),
        // README 2.9 Phase 6: gedaempfte KH-Variante des barbell "Push Press"
        // fuer crossfitWeighted "EMOM Ganzkörper" - dieselbe Explosiv-aus-den-
        // Beinen-Mechanik, nur mit Kurzhanteln statt Langhantel.
        ExerciseTemplateSpec(name: "Push Press (KH)",                  equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .advanced, localizationKey: "exercise.name.dumbbellPushPress"),
        ExerciseTemplateSpec(name: "Seitheben",                        equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner, localizationKey: "exercise.name.lateralRaise"),
        ExerciseTemplateSpec(name: "Frontheben",                       equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner, localizationKey: "exercise.name.frontRaise"),
        ExerciseTemplateSpec(name: "Reverse Flyes (KH)",               equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner, localizationKey: "exercise.name.reverseFlyDB"),
        ExerciseTemplateSpec(name: "Shrug (KH)",                         equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner, localizationKey: "exercise.name.dumbbellShrug"),

        // ── DUMBBELL · LEGS ────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Goblet Squat",                     equipment: .dumbbell, primaryMuscle: .quads,      difficultyLevel: .beginner, localizationKey: "exercise.name.gobletSquat"),
        ExerciseTemplateSpec(name: "Ausfallschritte (KH)",               equipment: .dumbbell, primaryMuscle: .quads, localizationKey: "exercise.name.dumbbellLunge"),
        ExerciseTemplateSpec(name: "Bulgarische Kniebeuge (KH)",       equipment: .dumbbell, primaryMuscle: .quads, localizationKey: "exercise.name.bulgarianSplitSquatDB"),
        ExerciseTemplateSpec(name: "Rumänisches Kreuzheben (KH)",             equipment: .dumbbell, primaryMuscle: .hamstrings, localizationKey: "exercise.name.dumbbellRDL"),
        // README 2.9 Phase 6: KH-Pendant zum barbell "Kreuzheben (konven-
        // tionell)" (primaryMuscle .back, gleiche Konvention) - fuer
        // crossfitWeighted "Grundlagen-AMRAP", zugaenglicher als die
        // Langhantel-Variante.
        ExerciseTemplateSpec(name: "Kreuzheben (KH)",                  equipment: .dumbbell, primaryMuscle: .back,       difficultyLevel: .beginner, localizationKey: "exercise.name.dumbbellDeadlift"),
        ExerciseTemplateSpec(name: "Step-Up (KH)",                     equipment: .dumbbell, primaryMuscle: .quads,      difficultyLevel: .beginner, localizationKey: "exercise.name.stepUpDB"),
        // README 2.9 Phase 6: Kniebeuge-in-Drueck-Kombolift (crossfitWeighted
        // "Auf Zeit: Thruster & Burpees") - genug systemic/CNS-Last fuer
        // explizite DEL-098-Faktoren wie andere grosse Compounds. KEIN
        // isSystemCompound trotzdem - das Flag ist laut
        // testSystemCompoundsAreBarbellLiftsOnly ausschliesslich fuer
        // Langhantel-Lifts reserviert (aendert die Progressions-
        // Schrittweite), ein Dumbbell-Thruster faellt nicht darunter.
        ExerciseTemplateSpec(name: "Thruster (KH)",                    equipment: .dumbbell, primaryMuscle: .quads,      difficultyLevel: .intermediate,
                             systemicFatigueFactor: 0.70, localMuscleDamageFactor: 0.60, cnsDemandFactor: 0.65, axialLoadFactor: 0.45, technicalComplexityFactor: 0.55, recoveryClass: .high,
                             localizationKey: "exercise.name.dumbbellThruster"),
        ExerciseTemplateSpec(name: "Hip Thrust (KH)",                    equipment: .dumbbell, primaryMuscle: .glutes,     difficultyLevel: .beginner, localizationKey: "exercise.name.dumbbellHipThrust"),
        ExerciseTemplateSpec(name: "Wadenheben (KH)",                    equipment: .dumbbell, primaryMuscle: .calves,     difficultyLevel: .beginner, localizationKey: "exercise.name.dumbbellCalfRaise"),

        // ── DUMBBELL · ARMS ────────────────────────────────────────────────
        // DEL-098: Isolations-Curls = niedrige Recovery-Klasse.
        ExerciseTemplateSpec(name: "Bizeps-Curl (KH)",                          equipment: .dumbbell, primaryMuscle: .biceps,     difficultyLevel: .beginner,
                             systemicFatigueFactor: 0.15, localMuscleDamageFactor: 0.35, cnsDemandFactor: 0.10, axialLoadFactor: 0.00, technicalComplexityFactor: 0.15, recoveryClass: .low,
                             localizationKey: "exercise.name.bicepcurl"),
        ExerciseTemplateSpec(name: "Hammer Curl",                      equipment: .dumbbell, primaryMuscle: .biceps,     difficultyLevel: .beginner,
                             systemicFatigueFactor: 0.15, localMuscleDamageFactor: 0.35, cnsDemandFactor: 0.10, axialLoadFactor: 0.00, technicalComplexityFactor: 0.15, recoveryClass: .low,
                             localizationKey: "exercise.name.hammerCurl"),
        ExerciseTemplateSpec(name: "Schrägbank-Curl (KH)",                 equipment: .dumbbell, primaryMuscle: .biceps, localizationKey: "exercise.name.inclineDumbbellCurl"),
        ExerciseTemplateSpec(name: "Konzentrations-Curl (KH)",              equipment: .dumbbell, primaryMuscle: .biceps,     difficultyLevel: .beginner, localizationKey: "exercise.name.concentrationCurl"),
        ExerciseTemplateSpec(name: "Trizepsstrecker über Kopf (KH)",     equipment: .dumbbell, primaryMuscle: .triceps, localizationKey: "exercise.name.dumbbellOverheadTricepExtension"),
        ExerciseTemplateSpec(name: "Trizepskickback (KH)",             equipment: .dumbbell, primaryMuscle: .triceps, localizationKey: "exercise.name.dumbbellTricepKickback"),

        // ── BODYWEIGHT · UPPER ─────────────────────────────────────────────
        // DEL-098: Pull-Ups = mittlerer Compound, kein axialer Loading-Stress
        // (Last haengt am Griff statt auf der Wirbelsaeule).
        ExerciseTemplateSpec(name: "Klimmzüge (weit)",                equipment: .bodyweight, primaryMuscle: .back,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.65, cnsDemandFactor: 0.45, axialLoadFactor: 0.10, technicalComplexityFactor: 0.45, recoveryClass: .medium,
                             localizationKey: "exercise.name.widePullup"),
        ExerciseTemplateSpec(name: "Klimmzüge (eng/Chin-up)",         equipment: .bodyweight, primaryMuscle: .back,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.65, cnsDemandFactor: 0.45, axialLoadFactor: 0.10, technicalComplexityFactor: 0.45, recoveryClass: .medium,
                             localizationKey: "exercise.name.pullup"),
        // README 2.9 Phase 6: neutraler/ueberhandgriff Standard-Klimmzug ohne
        // Griff-Qualifier - genutzt in den CrossFit-Bodyweight-Templates
        // (Cindy Rx). Gleiche DEL-098-Faktoren wie die beiden Griff-Varianten
        // oben, da dieselbe Bewegung.
        ExerciseTemplateSpec(name: "Klimmzüge",                        equipment: .bodyweight, primaryMuscle: .back,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.65, cnsDemandFactor: 0.45, axialLoadFactor: 0.10, technicalComplexityFactor: 0.45, recoveryClass: .medium,
                             localizationKey: "exercise.name.pullupStandard"),
        ExerciseTemplateSpec(name: "Australian Pull-ups",              equipment: .bodyweight, primaryMuscle: .back, localizationKey: "exercise.name.australianPullup"),
        ExerciseTemplateSpec(name: "Handtuch-Rudern (Türrahmen)",     equipment: .bodyweight, primaryMuscle: .back,      difficultyLevel: .beginner, localizationKey: "exercise.name.towelRowDoorframe"),
        ExerciseTemplateSpec(name: "Liegestütze",                     equipment: .bodyweight, primaryMuscle: .chest,     difficultyLevel: .beginner, localizationKey: "exercise.name.pushup"),
        // README 2.9 Phase 6: Knie-Regression fuer Cindy (Scaled) - genutzt
        // statt der vollen Liegestuetz-Variante fuer Einsteiger.
        ExerciseTemplateSpec(name: "Liegestütze (Knie)",              equipment: .bodyweight, primaryMuscle: .chest,     difficultyLevel: .beginner, localizationKey: "exercise.name.kneePushup"),
        ExerciseTemplateSpec(name: "Diamant-Liegestütze",             equipment: .bodyweight, primaryMuscle: .triceps, localizationKey: "exercise.name.diamondPushup"),
        ExerciseTemplateSpec(name: "Breite Liegestütze",              equipment: .bodyweight, primaryMuscle: .chest, localizationKey: "exercise.name.widePushup"),
        ExerciseTemplateSpec(name: "Dips (Brust)",                     equipment: .bodyweight, primaryMuscle: .chest, localizationKey: "exercise.name.chestDip"),
        ExerciseTemplateSpec(name: "Dips (Trizeps)",                   equipment: .bodyweight, primaryMuscle: .triceps, localizationKey: "exercise.name.tricepDip"),
        ExerciseTemplateSpec(name: "Pike Liegestütze",                equipment: .bodyweight, primaryMuscle: .shoulders, localizationKey: "exercise.name.pikePushup"),
        ExerciseTemplateSpec(name: "Handstand-Liegestütze",           equipment: .bodyweight, primaryMuscle: .shoulders, difficultyLevel: .advanced, localizationKey: "exercise.name.handstandPushup"),
        // Rear-Delt-Isolation ohne Equipment — Bauchlage, Arme zur Seite, Schulter-
        // blaetter zusammenziehen. Beste BW-Alternative zu Face Pulls / Reverse Flys.
        ExerciseTemplateSpec(name: "Back Widows",                      equipment: .bodyweight, primaryMuscle: .shoulders, difficultyLevel: .beginner, localizationKey: "exercise.name.backWidows"),

        // ── BODYWEIGHT · LOWER ─────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kniebeuge (BW)",                   equipment: .bodyweight, primaryMuscle: .quads,     difficultyLevel: .beginner, localizationKey: "exercise.name.bodyweightSquat"),
        ExerciseTemplateSpec(name: "Jump Squat",                       equipment: .bodyweight, primaryMuscle: .quads, localizationKey: "exercise.name.jumpSquat"),
        ExerciseTemplateSpec(name: "Ausfallschritte (BW)",             equipment: .bodyweight, primaryMuscle: .quads,     difficultyLevel: .beginner, localizationKey: "exercise.name.bodyweightLunge"),
        // README 2.9 Phase 6: plyometrische Variante fuer den EMOM-Intensitaets-
        // Tag (crossfitBodyweightRx) - gleiches Muster wie "Jump Squat" direkt
        // darunter (keine explizite Difficulty/Faktoren-Ueberschreibung).
        ExerciseTemplateSpec(name: "Gesprungene Ausfallschritte",      equipment: .bodyweight, primaryMuscle: .quads, localizationKey: "exercise.name.jumpingLunges"),
        ExerciseTemplateSpec(name: "Box Jump",                         equipment: .bodyweight, primaryMuscle: .quads, localizationKey: "exercise.name.boxJump"),
        // DEL-098: Wall Sit = isometrische Quad-Belastung. Lokales DOMS hoch,
        // CNS / systemic eher niedrig (kein Bewegungsablauf, keine schweren
        // Lasten).
        ExerciseTemplateSpec(name: "Wall Sit",                         equipment: .bodyweight, primaryMuscle: .quads,     difficultyLevel: .beginner, isTimeBased: true,
                             systemicFatigueFactor: 0.35, localMuscleDamageFactor: 0.70, cnsDemandFactor: 0.20, axialLoadFactor: 0.15, technicalComplexityFactor: 0.10, recoveryClass: .low,
                             localizationKey: "exercise.name.wallSit"),
        // Beste BW-Quad-Isolation — als Substitute fuer Beinstrecker (Maschine).
        ExerciseTemplateSpec(name: "Sissy Squats (BW)",                equipment: .bodyweight, primaryMuscle: .quads,     difficultyLevel: .advanced, localizationKey: "exercise.name.sissySquat"),
        ExerciseTemplateSpec(name: "Nordic Curls",                     equipment: .bodyweight, primaryMuscle: .hamstrings, localizationKey: "exercise.name.nordicCurl"),
        ExerciseTemplateSpec(name: "Glute Bridge (BW)",                equipment: .bodyweight, primaryMuscle: .glutes,    difficultyLevel: .beginner, localizationKey: "exercise.name.gluteBridge"),
        ExerciseTemplateSpec(name: "Hip Thrust (BW)",                  equipment: .bodyweight, primaryMuscle: .glutes,    difficultyLevel: .beginner, localizationKey: "exercise.name.bodyweightHipThrust"),
        ExerciseTemplateSpec(name: "Wadenheben (BW)",                  equipment: .bodyweight, primaryMuscle: .calves,    difficultyLevel: .beginner, localizationKey: "exercise.name.bodyweightCalfRaise"),

        // ── BODYWEIGHT · CORE ──────────────────────────────────────────────
        // DEL-098: Iso-Core wie Plank / Seitstuetz = analog zu Wall Sit. Burpees
        // sind eine Outlier — hohe systemic Cost wegen voller Bewegungskette.
        ExerciseTemplateSpec(name: "Plank",                            equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isTimeBased: true,
                             systemicFatigueFactor: 0.25, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.15, axialLoadFactor: 0.10, technicalComplexityFactor: 0.10, recoveryClass: .low,
                             localizationKey: "exercise.name.plank"),
        ExerciseTemplateSpec(name: "Seitstütz",                       equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isTimeBased: true,
                             systemicFatigueFactor: 0.25, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.15, axialLoadFactor: 0.10, technicalComplexityFactor: 0.15, recoveryClass: .low,
                             localizationKey: "exercise.name.sidePlank"),
        ExerciseTemplateSpec(name: "Mountain Climbers",                equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isTimeBased: true,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.40, cnsDemandFactor: 0.30, axialLoadFactor: 0.10, technicalComplexityFactor: 0.20, recoveryClass: .medium,
                             localizationKey: "exercise.name.mountainClimber"),
        ExerciseTemplateSpec(name: "Burpees",                          equipment: .bodyweight, primaryMuscle: .core,      isTimeBased: true,
                             systemicFatigueFactor: 0.75, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.50, axialLoadFactor: 0.20, technicalComplexityFactor: 0.40, recoveryClass: .high,
                             localizationKey: "exercise.name.burpee"),
        // Standard-Substitutes fuer Kabel-Crunches und haengendes Beinheben.
        ExerciseTemplateSpec(name: "Crunches (BW)",                    equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, localizationKey: "exercise.name.crunch"),
        ExerciseTemplateSpec(name: "Beinheben (liegend)",              equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, localizationKey: "exercise.name.lyingLegRaise"),
        ExerciseTemplateSpec(name: "Sit-ups",                          equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, localizationKey: "exercise.name.situp"),
        ExerciseTemplateSpec(name: "Beinstrecker liegend",             equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.lyingLegExtension"),
        ExerciseTemplateSpec(name: "Russian Twists",                   equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, localizationKey: "exercise.name.russianTwist"),
        ExerciseTemplateSpec(name: "Hanging Leg Raises",               equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.hangingLegRaise"),

        // ── MACHINE / CABLE · CHEST ────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kabel Crossover",                  equipment: .cable,    primaryMuscle: .chest, localizationKey: "exercise.name.cableCrossover"),
        ExerciseTemplateSpec(name: "Pec Deck (Butterfly)",             equipment: .machine,  primaryMuscle: .chest,       difficultyLevel: .beginner, localizationKey: "exercise.name.pecDeck"),
        ExerciseTemplateSpec(name: "Brustdrücken (Maschine)",             equipment: .machine,  primaryMuscle: .chest,       difficultyLevel: .beginner, localizationKey: "exercise.name.chestPressMachine"),

        // ── MACHINE / CABLE · BACK ─────────────────────────────────────────
        ExerciseTemplateSpec(name: "Latzug (weit)",                    equipment: .machine,  primaryMuscle: .back,        difficultyLevel: .beginner,
                             localizationKey: "exercise.name.latpulldown"),
        ExerciseTemplateSpec(name: "Latzug (eng)",                     equipment: .machine,  primaryMuscle: .back,        difficultyLevel: .beginner, localizationKey: "exercise.name.latPulldownClose"),
        ExerciseTemplateSpec(name: "Kabelrudern sitzend",              equipment: .cable,    primaryMuscle: .back,        difficultyLevel: .beginner, localizationKey: "exercise.name.seatedCableRow"),

        // ── MACHINE / CABLE · SHOULDERS ────────────────────────────────────
        ExerciseTemplateSpec(name: "Kabel Seitheben",                  equipment: .cable,    primaryMuscle: .shoulders,   difficultyLevel: .beginner, localizationKey: "exercise.name.cableLateralRaise"),
        ExerciseTemplateSpec(name: "Face Pull",                        equipment: .cable,    primaryMuscle: .shoulders, localizationKey: "exercise.name.facePull"),
        ExerciseTemplateSpec(name: "Schulterdrücken (Maschine)",          equipment: .machine,  primaryMuscle: .shoulders,   difficultyLevel: .beginner, localizationKey: "exercise.name.shoulderPressMachine"),

        // ── MACHINE / CABLE · ARMS ─────────────────────────────────────────
        ExerciseTemplateSpec(name: "Trizepsdrücken (Kabel)",          equipment: .cable,    primaryMuscle: .triceps, localizationKey: "exercise.name.tricepPushdown"),
        ExerciseTemplateSpec(name: "Trizepsstrecker über Kopf (Kabel)", equipment: .cable,   primaryMuscle: .triceps, localizationKey: "exercise.name.cableOverheadTricepExtension"),
        ExerciseTemplateSpec(name: "Preacher Curl (Maschine)",         equipment: .machine,  primaryMuscle: .biceps,      difficultyLevel: .beginner, localizationKey: "exercise.name.preacherCurl"),
        ExerciseTemplateSpec(name: "Kabel Curl",                       equipment: .cable,    primaryMuscle: .biceps,      difficultyLevel: .beginner, localizationKey: "exercise.name.cableCurl"),

        // ── MACHINE / CABLE · LEGS ─────────────────────────────────────────
        ExerciseTemplateSpec(name: "Beinpresse",                       equipment: .machine,  primaryMuscle: .quads,       difficultyLevel: .beginner,
                             localizationKey: "exercise.name.legpress"),
        ExerciseTemplateSpec(name: "Beinstrecker",                     equipment: .machine,  primaryMuscle: .quads,       difficultyLevel: .beginner, localizationKey: "exercise.name.legExtension"),
        ExerciseTemplateSpec(name: "Beinbeuger liegend",               equipment: .machine,  primaryMuscle: .hamstrings,  difficultyLevel: .beginner, localizationKey: "exercise.name.lyingLegCurl"),
        ExerciseTemplateSpec(name: "Hack Squat",                       equipment: .machine,  primaryMuscle: .quads, localizationKey: "exercise.name.hackSquat"),
        ExerciseTemplateSpec(name: "Smith Machine Squat",              equipment: .machine,  primaryMuscle: .quads, localizationKey: "exercise.name.smithMachineSquat"),
        ExerciseTemplateSpec(name: "Wadenpresse (sitzend)",            equipment: .machine,  primaryMuscle: .calves,      difficultyLevel: .beginner, localizationKey: "exercise.name.seatedCalfRaise"),

        // ── MACHINE / CABLE · CORE ─────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kabel Crunch",                     equipment: .cable,    primaryMuscle: .core,        difficultyLevel: .beginner, localizationKey: "exercise.name.cableCrunch"),

        // ── RESISTANCE BAND ────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Band Pull-Aparts",                 equipment: .band,     primaryMuscle: .back,        difficultyLevel: .beginner, localizationKey: "exercise.name.bandPullApart"),
        ExerciseTemplateSpec(name: "Banded Squats",                    equipment: .band,     primaryMuscle: .quads,       difficultyLevel: .beginner, localizationKey: "exercise.name.bandedSquat"),
        ExerciseTemplateSpec(name: "Band Curls",                       equipment: .band,     primaryMuscle: .biceps,      difficultyLevel: .beginner, localizationKey: "exercise.name.bandCurl"),
        ExerciseTemplateSpec(name: "Banded Hip Thrust",                equipment: .band,     primaryMuscle: .glutes,      difficultyLevel: .beginner, localizationKey: "exercise.name.bandedHipThrust"),

        // ── KETTLEBELL ─────────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kettlebell Swing",                 equipment: .kettlebell, primaryMuscle: .glutes, localizationKey: "exercise.name.kettlebellSwing"),
        ExerciseTemplateSpec(name: "Turkish Get-Up",                   equipment: .kettlebell, primaryMuscle: .core,      difficultyLevel: .advanced, localizationKey: "exercise.name.turkishGetUp"),
        ExerciseTemplateSpec(name: "Kettlebell Goblet Squat",          equipment: .kettlebell, primaryMuscle: .quads,     difficultyLevel: .beginner, localizationKey: "exercise.name.kettlebellGobletSquat"),
        ExerciseTemplateSpec(name: "Kettlebell Snatch",                equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellSnatch"),
        ExerciseTemplateSpec(name: "Kettlebell Clean & Press",         equipment: .kettlebell, primaryMuscle: .shoulders, localizationKey: "exercise.name.kettlebellCleanAndPress"),
        ExerciseTemplateSpec(name: "Kettlebell Halo",                  equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .beginner, localizationKey: "exercise.name.kettlebellHalo"),
        // DEL-171: KB-Ergänzungen, damit die hybridBalanced/Beginner/Performance-
        // Templates eine vollwertige kettlebellOnly-Variante bekommen.
        ExerciseTemplateSpec(name: "Kettlebell Floor Press",           equipment: .kettlebell, primaryMuscle: .chest,     difficultyLevel: .intermediate, localizationKey: "exercise.name.kettlebellFloorPress"),
        ExerciseTemplateSpec(name: "Kettlebell Row einarmig",          equipment: .kettlebell, primaryMuscle: .back,      difficultyLevel: .intermediate, localizationKey: "exercise.name.kettlebellRowSingleArm"),
        ExerciseTemplateSpec(name: "Kettlebell RDL",                   equipment: .kettlebell, primaryMuscle: .hamstrings, difficultyLevel: .intermediate, localizationKey: "exercise.name.kettlebellRDL"),
        ExerciseTemplateSpec(name: "Kettlebell Push Press",            equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced,    localizationKey: "exercise.name.kettlebellPushPress"),
        ExerciseTemplateSpec(name: "Kettlebell Suitcase Carry",        equipment: .kettlebell, primaryMuscle: .core,      difficultyLevel: .beginner, isTimeBased: true, localizationKey: "exercise.name.kettlebellSuitcaseCarry"),
        // Übungen der CrossFit-/Kettlebell-Trainingspläne (README 2.9 Phase 6),
        // die bisher nur in `ProgramTemplates` als roher Name standen, ohne
        // Library-Match — jetzt offiziell im Catalog, gleiches Muster wie
        // die "Cardio · Hybrid-Plan-Lifts"-Promotion oben (DEL-116).
        ExerciseTemplateSpec(name: "Kettlebell Kreuzheben",            equipment: .kettlebell, primaryMuscle: .back,      difficultyLevel: .beginner, localizationKey: "exercise.name.kettlebellDeadlift"),
        ExerciseTemplateSpec(name: "Kettlebell Overhead Press",        equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .beginner, localizationKey: "exercise.name.kettlebellOverheadPress"),
        ExerciseTemplateSpec(name: "Kettlebell Front Squat",           equipment: .kettlebell, primaryMuscle: .quads,     difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellFrontSquat"),
        // Unilaterale Snatch-Variante fuer EMOM-Wechsel Links/Rechts pro
        // Minute (kettlebellAdvanced Tag 1) — dieselbe Bewegung wie das
        // bestehende "Kettlebell Snatch", nur seitengetrennt als eigene
        // Uebung, weil ein Tag im Datenmodell keine Seiten-Alternation kennt.
        ExerciseTemplateSpec(name: "Kettlebell Snatch (Links)",        equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellSnatchLeft"),
        ExerciseTemplateSpec(name: "Kettlebell Snatch (Rechts)",       equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellSnatchRight"),

        // ── CARDIO (DEL-080 — Ad-Hoc-Optionen fuer Hybrid-/freie Trainings) ─
        // Alle `isCardio: true` damit der DayEditor beim Picker-Pick die
        // Uebung automatisch korrekt klassifiziert. `primaryMuscle: .core`
        // ist ein Notbehelf — Cardio bedient den gesamten Koerper, aber
        // das MuscleGroup-Enum hat keinen "Ganzkoerper"-Eintrag.
        // DEL-098: Cardio = moderater systemic Cost (Kreislauf-Belastung),
        // niedriger CNS-Hit (kein neuronaler Stress wie schwere Compounds).
        // Rudermaschine bekommt etwas hoeheren local-Damage (Lat-/Beine-Mix).
        ExerciseTemplateSpec(name: "Freier Lauf",                      equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.55, localMuscleDamageFactor: 0.45, cnsDemandFactor: 0.30, axialLoadFactor: 0.20, technicalComplexityFactor: 0.10, recoveryClass: .medium,
                             localizationKey: "exercise.name.run"),
        ExerciseTemplateSpec(name: "Laufband",                         equipment: .machine,    primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.55, localMuscleDamageFactor: 0.45, cnsDemandFactor: 0.30, axialLoadFactor: 0.20, technicalComplexityFactor: 0.10, recoveryClass: .medium,
                             localizationKey: "exercise.name.treadmill"),
        ExerciseTemplateSpec(name: "Radfahren (outdoor)",              equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.55, localMuscleDamageFactor: 0.35, cnsDemandFactor: 0.25, axialLoadFactor: 0.10, technicalComplexityFactor: 0.10, recoveryClass: .medium,
                             localizationKey: "exercise.name.cycling"),
        ExerciseTemplateSpec(name: "Fahrradergometer",                 equipment: .machine,    primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.30, cnsDemandFactor: 0.20, axialLoadFactor: 0.05, technicalComplexityFactor: 0.05, recoveryClass: .medium,
                             localizationKey: "exercise.name.stationaryBike"),
        ExerciseTemplateSpec(name: "Rudermaschine",                    equipment: .machine,    primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.65, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.35, axialLoadFactor: 0.20, technicalComplexityFactor: 0.25, recoveryClass: .medium,
                             localizationKey: "exercise.name.rowingMachine"),
        ExerciseTemplateSpec(name: "Crosstrainer",                     equipment: .machine,    primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.45, localMuscleDamageFactor: 0.30, cnsDemandFactor: 0.20, axialLoadFactor: 0.05, technicalComplexityFactor: 0.05, recoveryClass: .medium,
                             localizationKey: "exercise.name.elliptical"),
        ExerciseTemplateSpec(name: "Stepper",                          equipment: .machine,    primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.40, cnsDemandFactor: 0.20, axialLoadFactor: 0.10, technicalComplexityFactor: 0.05, recoveryClass: .medium,
                             localizationKey: "exercise.name.stairStepper"),
        ExerciseTemplateSpec(name: "Schwimmen",                        equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.55, localMuscleDamageFactor: 0.35, cnsDemandFactor: 0.25, axialLoadFactor: 0.05, technicalComplexityFactor: 0.30, recoveryClass: .medium,
                             localizationKey: "exercise.name.swimming"),
        // ── CARDIO · HYBRID-PLAN-LIFTS (DEL-116) ───────────────────────────
        // DEL-116: Promoted aus den ProgramTemplates-Orphans. Vorher waren
        // "Easy Run", "Long Run", "Intervalle", "Gehen / Einlaufen" inline
        // ExerciseSpec(name:) Strings in Hybrid-Plan-Templates ohne Library-
        // Match — landeten als rohes DE in Exercise.name. Jetzt offiziell
        // im Catalog mit Multi-Locale-Display.
        ExerciseTemplateSpec(name: "Easy Run",                         equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.40, cnsDemandFactor: 0.25, axialLoadFactor: 0.20, technicalComplexityFactor: 0.10, recoveryClass: .medium,
                             localizationKey: "exercise.name.easyRun"),
        ExerciseTemplateSpec(name: "Long Run",                         equipment: .bodyweight, primaryMuscle: .core,      isCardio: true,
                             systemicFatigueFactor: 0.70, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.35, axialLoadFactor: 0.25, technicalComplexityFactor: 0.10, recoveryClass: .high,
                             localizationKey: "exercise.name.longRun"),
        ExerciseTemplateSpec(name: "Intervalle",                       equipment: .bodyweight, primaryMuscle: .core,      isCardio: true,
                             systemicFatigueFactor: 0.75, localMuscleDamageFactor: 0.50, cnsDemandFactor: 0.55, axialLoadFactor: 0.20, technicalComplexityFactor: 0.20, recoveryClass: .high,
                             localizationKey: "exercise.name.intervals"),
        ExerciseTemplateSpec(name: "Gehen / Einlaufen",                equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.15, localMuscleDamageFactor: 0.10, cnsDemandFactor: 0.05, axialLoadFactor: 0.05, technicalComplexityFactor: 0.05, recoveryClass: .low,
                             localizationKey: "exercise.name.warmupWalk"),
        // README 2.35 (43a/43b): eigene `isTimeBased`-Cardio-Eintraege fuer
        // die einzelne, wiederholte Cardio-Uebung, die ein Lauf-/Rad-Tag mit
        // Zeitformat (AMRAP/EMOM/Auf Zeit) braucht - `repsMin`/`repsMax`
        // tragen dann Sekunden statt Wiederholungen (siehe Doc-Kommentar
        // `isTimeBased` oben), genau der Mechanismus, den `TimedWorkoutPlayerView`
        // schon fuer Bodyweight-Holds (z.B. Plank im EMOM) benutzt - hier nur
        // mit einer Lauf-/Rad-Bewegung statt einer Kraft-Uebung. Faktoren an
        // "Intervalle"/"Radfahren (outdoor)" angelehnt, leicht haerter (Intervall-
        // Charakter).
        ExerciseTemplateSpec(name: "Lauf-Intervall",                   equipment: .bodyweight, primaryMuscle: .core,      isTimeBased: true, isCardio: true,
                             systemicFatigueFactor: 0.75, localMuscleDamageFactor: 0.50, cnsDemandFactor: 0.55, axialLoadFactor: 0.20, technicalComplexityFactor: 0.20, recoveryClass: .high,
                             localizationKey: "exercise.name.runInterval"),
        ExerciseTemplateSpec(name: "Rad-Intervall",                    equipment: .bodyweight, primaryMuscle: .core,      isTimeBased: true, isCardio: true,
                             systemicFatigueFactor: 0.65, localMuscleDamageFactor: 0.40, cnsDemandFactor: 0.35, axialLoadFactor: 0.10, technicalComplexityFactor: 0.15, recoveryClass: .high,
                             localizationKey: "exercise.name.cyclingInterval"),

        // ── DEL-162: Bibliotheks-Erweiterung (verbreitete Standardübungen) ──
        // Heavy-Compounds (DL-/Squat-Varianten + Olympic-Lifts) tragen explizite
        // DEL-098-Faktoren + isSystemCompound, damit DayAnalysis sie korrekt als
        // systemisch schwer einstuft. Accessory-/Iso-/Hold-Übungen nutzen die
        // moderaten Defaults (kein nil → keine PR-/Day-Analysis-Regression).

        // Barbell Compounds
        ExerciseTemplateSpec(name: "Deficit-Kreuzheben", equipment: .barbell, primaryMuscle: .back, difficultyLevel: .advanced, isSystemCompound: true,
                             systemicFatigueFactor: 0.95, localMuscleDamageFactor: 0.78, cnsDemandFactor: 0.95, axialLoadFactor: 1.00, technicalComplexityFactor: 0.85, recoveryClass: .extreme,
                             localizationKey: "exercise.name.deficitDeadlift"),
        ExerciseTemplateSpec(name: "Trap-Bar-Kreuzheben", equipment: .barbell, primaryMuscle: .back, difficultyLevel: .intermediate, isSystemCompound: true,
                             systemicFatigueFactor: 0.88, localMuscleDamageFactor: 0.72, cnsDemandFactor: 0.85, axialLoadFactor: 0.90, technicalComplexityFactor: 0.55, recoveryClass: .extreme,
                             localizationKey: "exercise.name.trapBarDeadlift"),
        ExerciseTemplateSpec(name: "Box Squat", equipment: .barbell, primaryMuscle: .quads, difficultyLevel: .intermediate, isSystemCompound: true,
                             systemicFatigueFactor: 0.85, localMuscleDamageFactor: 0.75, cnsDemandFactor: 0.80, axialLoadFactor: 0.90, technicalComplexityFactor: 0.60, recoveryClass: .high,
                             localizationKey: "exercise.name.boxSquat"),
        ExerciseTemplateSpec(name: "Reißen (Snatch)", equipment: .barbell, primaryMuscle: .shoulders, difficultyLevel: .advanced, isSystemCompound: true,
                             systemicFatigueFactor: 0.90, localMuscleDamageFactor: 0.65, cnsDemandFactor: 0.98, axialLoadFactor: 0.85, technicalComplexityFactor: 0.98, recoveryClass: .extreme,
                             localizationKey: "exercise.name.snatch"),
        ExerciseTemplateSpec(name: "Umsetzen & Stoßen", equipment: .barbell, primaryMuscle: .shoulders, difficultyLevel: .advanced, isSystemCompound: true,
                             systemicFatigueFactor: 0.92, localMuscleDamageFactor: 0.68, cnsDemandFactor: 0.98, axialLoadFactor: 0.90, technicalComplexityFactor: 0.98, recoveryClass: .extreme,
                             localizationKey: "exercise.name.cleanAndJerk"),

        // Barbell / Dumbbell Press-Varianten
        ExerciseTemplateSpec(name: "Floor Press", equipment: .barbell, primaryMuscle: .chest, difficultyLevel: .intermediate, localizationKey: "exercise.name.floorPress"),
        ExerciseTemplateSpec(name: "Z-Press", equipment: .barbell, primaryMuscle: .shoulders, difficultyLevel: .advanced, localizationKey: "exercise.name.zPress"),
        ExerciseTemplateSpec(name: "Tate Press", equipment: .dumbbell, primaryMuscle: .triceps, difficultyLevel: .intermediate, localizationKey: "exercise.name.tatePress"),
        ExerciseTemplateSpec(name: "Hex Press (Squeeze Press)", equipment: .dumbbell, primaryMuscle: .chest, difficultyLevel: .intermediate, localizationKey: "exercise.name.hexPress"),

        // Rows
        ExerciseTemplateSpec(name: "Meadows Row", equipment: .barbell, primaryMuscle: .back, difficultyLevel: .intermediate, localizationKey: "exercise.name.meadowsRow"),
        ExerciseTemplateSpec(name: "Renegade Row", equipment: .dumbbell, primaryMuscle: .back, difficultyLevel: .advanced, localizationKey: "exercise.name.renegadeRow"),
        ExerciseTemplateSpec(name: "Inverted Row", equipment: .bodyweight, primaryMuscle: .back, difficultyLevel: .beginner, localizationKey: "exercise.name.invertedRow"),

        // Cable
        ExerciseTemplateSpec(name: "Cable Pull-Through", equipment: .cable, primaryMuscle: .glutes, difficultyLevel: .beginner, localizationKey: "exercise.name.cablePullThrough"),
        ExerciseTemplateSpec(name: "Cable Woodchopper", equipment: .cable, primaryMuscle: .core, difficultyLevel: .intermediate, localizationKey: "exercise.name.cableWoodchopper"),
        ExerciseTemplateSpec(name: "Bayesian Curl", equipment: .cable, primaryMuscle: .biceps, difficultyLevel: .intermediate, localizationKey: "exercise.name.bayesianCurl"),
        ExerciseTemplateSpec(name: "Reverse Cable Fly", equipment: .cable, primaryMuscle: .shoulders, difficultyLevel: .beginner, localizationKey: "exercise.name.reverseCableFly"),
        ExerciseTemplateSpec(name: "Latzug (neutraler Griff)", equipment: .cable, primaryMuscle: .back, difficultyLevel: .beginner, localizationKey: "exercise.name.neutralGripLatPulldown"),

        // Machine
        ExerciseTemplateSpec(name: "Beincurl sitzend", equipment: .machine, primaryMuscle: .hamstrings, difficultyLevel: .beginner, localizationKey: "exercise.name.seatedLegCurl"),
        ExerciseTemplateSpec(name: "Beincurl stehend", equipment: .machine, primaryMuscle: .hamstrings, difficultyLevel: .beginner, localizationKey: "exercise.name.standingLegCurl"),
        ExerciseTemplateSpec(name: "Wadenpresse (Beinpresse)", equipment: .machine, primaryMuscle: .calves, difficultyLevel: .beginner, localizationKey: "exercise.name.calfPressLegPress"),
        ExerciseTemplateSpec(name: "Klimmzug (assistiert)", equipment: .machine, primaryMuscle: .back, difficultyLevel: .beginner, localizationKey: "exercise.name.assistedPullUp"),
        ExerciseTemplateSpec(name: "Dip (assistiert)", equipment: .machine, primaryMuscle: .triceps, difficultyLevel: .beginner, localizationKey: "exercise.name.assistedDip"),

        // Bodyweight / Calisthenics
        ExerciseTemplateSpec(name: "Pistol Squat", equipment: .bodyweight, primaryMuscle: .quads, difficultyLevel: .advanced, localizationKey: "exercise.name.pistolSquat"),
        ExerciseTemplateSpec(name: "Muscle-Up", equipment: .bodyweight, primaryMuscle: .back, difficultyLevel: .advanced, localizationKey: "exercise.name.muscleUp"),
        ExerciseTemplateSpec(name: "Reverse Nordic Curl", equipment: .bodyweight, primaryMuscle: .quads, difficultyLevel: .intermediate, localizationKey: "exercise.name.reverseNordicCurl"),
        ExerciseTemplateSpec(name: "Medizinball-Slam", equipment: .bodyweight, primaryMuscle: .core, difficultyLevel: .intermediate, localizationKey: "exercise.name.medicineBallSlam"),
        ExerciseTemplateSpec(name: "Tibialis Raise", equipment: .bodyweight, primaryMuscle: .calves, difficultyLevel: .beginner, localizationKey: "exercise.name.tibialisRaise"),

        // Forearm / Neck Isolation
        ExerciseTemplateSpec(name: "Handgelenk-Curl", equipment: .dumbbell, primaryMuscle: .biceps, difficultyLevel: .beginner, localizationKey: "exercise.name.wristCurl"),
        ExerciseTemplateSpec(name: "Handgelenk-Curl (umgekehrt)", equipment: .dumbbell, primaryMuscle: .biceps, difficultyLevel: .beginner, localizationKey: "exercise.name.reverseWristCurl"),
        ExerciseTemplateSpec(name: "Nacken-Curl", equipment: .bodyweight, primaryMuscle: .shoulders, difficultyLevel: .beginner, localizationKey: "exercise.name.neckCurl"),
        ExerciseTemplateSpec(name: "Nacken-Extension", equipment: .bodyweight, primaryMuscle: .shoulders, difficultyLevel: .beginner, localizationKey: "exercise.name.neckExtension"),

        // Time-Based Holds
        ExerciseTemplateSpec(name: "Dragon Flag", equipment: .bodyweight, primaryMuscle: .core, difficultyLevel: .advanced, isTimeBased: true, localizationKey: "exercise.name.dragonFlag"),
        ExerciseTemplateSpec(name: "L-Sit", equipment: .bodyweight, primaryMuscle: .core, difficultyLevel: .advanced, isTimeBased: true, localizationKey: "exercise.name.lSit"),
        ExerciseTemplateSpec(name: "Copenhagen Plank", equipment: .bodyweight, primaryMuscle: .core, difficultyLevel: .intermediate, isTimeBased: true, localizationKey: "exercise.name.copenhagenPlank"),

        // Loaded Carries / Conditioning (zeitbasiert)
        ExerciseTemplateSpec(name: "Farmer's Walk", equipment: .dumbbell, primaryMuscle: .back, difficultyLevel: .intermediate, isTimeBased: true, localizationKey: "exercise.name.farmersWalk"),
        ExerciseTemplateSpec(name: "Sandbag Carry", equipment: .bodyweight, primaryMuscle: .core, difficultyLevel: .intermediate, isTimeBased: true, localizationKey: "exercise.name.sandbagCarry"),
        ExerciseTemplateSpec(name: "Sled Push", equipment: .machine, primaryMuscle: .quads, difficultyLevel: .intermediate, isTimeBased: true, localizationKey: "exercise.name.sledPush"),
        ExerciseTemplateSpec(name: "Sled Pull", equipment: .machine, primaryMuscle: .back, difficultyLevel: .intermediate, isTimeBased: true, localizationKey: "exercise.name.sledPull"),
        ExerciseTemplateSpec(name: "Battle Ropes", equipment: .bodyweight, primaryMuscle: .shoulders, difficultyLevel: .intermediate, isTimeBased: true, localizationKey: "exercise.name.battleRopes"),
    ]

    /// Alternative-Mapping fuer den Environment-Swap (DEL-022). Bei einem
    /// Plan-Wechsel von z.B. `.gym` zu `.homeGym` oder `.noEquipment` ersetzt
    /// der PlanEditor jede Uebung durch die Alternative aus diesem Mapping.
    ///
    /// Schema: `[Quell-Uebungsname: [Ziel-Environment: Alternative-Uebungsname]]`
    /// — Ziel-Namen MUESSEN in `Self.all` existieren, damit der Swap eine
    /// vollwertige Uebung mit den richtigen `isCardio`/`isTimeBased`-Flags
    /// anlegen kann.
    ///
    /// **Fallback**: Wenn fuer eine Quell-Uebung kein Mapping fuer das
    /// Ziel-Environment existiert, laesst der PlanEditor die Uebung
    /// unveraendert stehen (mit Warn-Indicator). User entscheidet selbst,
    /// ob er sie behalten, manuell ersetzen oder loeschen will.
    public static let alternatives: [String: [EnvironmentType: String]] = [
        // ── CHEST ──────────────────────────────────────────────────────────
        "Bankdrücken": [
            .homeGym:     "Bankdrücken (KH)",
            .noEquipment: "Liegestütze"
        ],
        "Schrägbankdrücken (aufwärts)": [
            .homeGym:     "Schrägbankdrücken aufwärts (KH)",
            .noEquipment: "Pike Liegestütze"
        ],
        "Schrägbankdrücken (abwärts)": [
            .homeGym:     "Bankdrücken (KH)",
            .noEquipment: "Dips (Brust)"
        ],
        "Bankdrücken (KH)": [
            .noEquipment: "Liegestütze"
        ],
        "Flyes flach (KH)": [
            .noEquipment: "Breite Liegestütze"
        ],

        // ── BACK ───────────────────────────────────────────────────────────
        "Kreuzheben (konventionell)": [
            .homeGym:     "Rumänisches Kreuzheben (KH)",
            .noEquipment: "Glute Bridge (BW)"
        ],
        "Rumänisches Kreuzheben": [
            .homeGym:     "Rumänisches Kreuzheben (KH)",
            .noEquipment: "Nordic Curls"
        ],
        "Rudern vorgebeugt": [
            .homeGym:     "Rudern einarmig (KH)",
            .noEquipment: "Klimmzüge"
        ],
        "Pendlay Row": [
            .homeGym:     "Rudern einarmig (KH)",
            .noEquipment: "Australian Pull-ups"
        ],
        "Rudern einarmig (KH)": [
            .noEquipment: "Australian Pull-ups"
        ],

        // ── SHOULDERS ──────────────────────────────────────────────────────
        "Schulterdrücken (stehend)": [
            .homeGym:     "Schulterdrücken (KH)",
            .noEquipment: "Pike Liegestütze"
        ],
        "Push Press": [
            .homeGym:     "Schulterdrücken (KH)",
            .noEquipment: "Handstand-Liegestütze"
        ],
        "Nackendrücken": [
            .homeGym:     "Schulterdrücken (KH)",
            .noEquipment: "Pike Liegestütze"
        ],
        "Schulterdrücken (KH)": [
            .noEquipment: "Pike Liegestütze"
        ],

        // ── LEGS · QUADS ───────────────────────────────────────────────────
        "Kniebeuge": [
            .homeGym:     "Goblet Squat",
            .noEquipment: "Kniebeuge (BW)"
        ],
        "Front Squat": [
            .homeGym:     "Goblet Squat",
            .noEquipment: "Bulgarische Kniebeuge (KH)"
        ],
        "Goblet Squat": [
            .noEquipment: "Kniebeuge (BW)"
        ],
        "Bulgarische Kniebeuge (KH)": [
            .noEquipment: "Ausfallschritte (BW)"
        ],
        "Ausfallschritte (LH)": [
            .homeGym:     "Ausfallschritte (KH)",
            .noEquipment: "Ausfallschritte (BW)"
        ],
        "Ausfallschritte (KH)": [
            .noEquipment: "Ausfallschritte (BW)"
        ],

        // ── LEGS · HAMSTRINGS / GLUTES ────────────────────────────────────
        "Hip Thrust (LH)": [
            .homeGym:     "Banded Hip Thrust",
            .noEquipment: "Hip Thrust (BW)"
        ],
        "Good Morning": [
            .homeGym:     "Rumänisches Kreuzheben (KH)",
            .noEquipment: "Nordic Curls"
        ],

        // ── CALVES ─────────────────────────────────────────────────────────
        "Wadenheben (stehend, LH)": [
            .homeGym:     "Wadenheben (BW)",
            .noEquipment: "Wadenheben (BW)"
        ],

        // ── ARMS ───────────────────────────────────────────────────────────
        "Bizeps-Curl (LH)": [
            .homeGym:     "Band Curls",
            .noEquipment: "Klimmzüge (eng/Chin-up)"
        ],
        "Skull Crusher": [
            .homeGym:     "Diamant-Liegestütze",
            .noEquipment: "Diamant-Liegestütze"
        ],
        "Enges Bankdrücken": [
            .homeGym:     "Diamant-Liegestütze",
            .noEquipment: "Diamant-Liegestütze"
        ],

        // ── MACHINES · CHEST ────────────────────────────────────────────────
        "Brustpresse (Maschine)": [
            .homeGym:     "Bankdrücken (KH)",
            .noEquipment: "Liegestütze"
        ],
        "Cable Crossover": [
            .homeGym:     "Flyes flach (KH)",
            .noEquipment: "Breite Liegestütze"
        ],
        "Flys (Maschine / Butterfly)": [
            .homeGym:     "Flyes flach (KH)",
            .noEquipment: "Breite Liegestütze"
        ],

        // ── MACHINES / CABLES · BACK ────────────────────────────────────────
        "Latzug (breit)": [
            .homeGym:     "Klimmzüge (weit)",
            .noEquipment: "Australian Pull-ups"
        ],
        "Latzug (eng)": [
            .homeGym:     "Klimmzüge (eng/Chin-up)",
            .noEquipment: "Australian Pull-ups"
        ],
        "Rudern (Maschine)": [
            .homeGym:     "Rudern einarmig (KH)",
            .noEquipment: "Australian Pull-ups"
        ],

        // ── MACHINES / CABLES · SHOULDERS ──────────────────────────────────
        "Seitheben (Kabel)": [
            .homeGym:     "Seitheben",
            .noEquipment: "Pike Liegestütze"
        ],
        "Face Pulls": [
            .homeGym:     "Reverse Flyes (KH)",
            .noEquipment: "Back Widows"
        ],
        "Reverse Flys (Maschine)": [
            .homeGym:     "Reverse Flyes (KH)",
            .noEquipment: "Back Widows"
        ],
        "Schulterdrücken (Maschine)": [
            .homeGym:     "Schulterdrücken (KH)",
            .noEquipment: "Pike Liegestütze"
        ],

        // ── MACHINES · LEGS (QUADS) ────────────────────────────────────────
        "Beinpresse": [
            .homeGym:     "Goblet Squat",
            .noEquipment: "Kniebeuge (BW)"
        ],
        // DEL-091: Beinstrecker -> Sissy Squats war fuer Anfaenger im
        // Urlaubs-Modus gefaehrlich (extreme Knie-Belastung). "Ausfallschritte
        // (BW)" als sichere Verbund-Variante, trifft die Quads aehnlich
        // einseitig ohne Knie-Trauma-Risiko.
        "Beinstrecker (Maschine)": [
            .homeGym:     "Goblet Squat",
            .noEquipment: "Ausfallschritte (BW)"
        ],
        "Beinstrecker": [
            .homeGym:     "Goblet Squat",
            .noEquipment: "Ausfallschritte (BW)"
        ],
        "Hackenschmidt-Kniebeuge (Maschine)": [
            .homeGym:     "Ausfallschritte (KH)",
            .noEquipment: "Kniebeuge (BW)"
        ],

        // ── MACHINES · LEGS (HAMSTRINGS / GLUTES) ──────────────────────────
        "Beinbeuger (sitzend)": [
            .homeGym:     "Rumänisches Kreuzheben (KH)",
            .noEquipment: "Nordic Curls"
        ],
        "Beinbeuger (liegend)": [
            .homeGym:     "Rumänisches Kreuzheben (KH)",
            .noEquipment: "Nordic Curls"
        ],
        "Hip Thrust (Maschine)": [
            .homeGym:     "Banded Hip Thrust",
            .noEquipment: "Hip Thrust (BW)"
        ],

        // ── CABLES · ARMS ──────────────────────────────────────────────────
        "Trizeps-Drücken (Kabel)": [
            .homeGym:     "Trizepskickback (KH)",
            .noEquipment: "Diamant-Liegestütze"
        ],
        "Trizeps-Drücken über Kopf (Kabel)": [
            .homeGym:     "Trizepsstrecker über Kopf (KH)",
            .noEquipment: "Dips (Trizeps)"
        ],
        "Bizepscurls (Kabel)": [
            .homeGym:     "Hammer Curl",
            .noEquipment: "Klimmzüge (eng/Chin-up)"
        ],
        "Preacher Curls": [
            .homeGym:     "Konzentrations-Curl (KH)",
            .noEquipment: "Klimmzüge (eng/Chin-up)"
        ],

        // ── CABLES · CORE ──────────────────────────────────────────────────
        "Crunches (Kabel)": [
            .homeGym:     "Crunches (BW)",
            .noEquipment: "Crunches (BW)"
        ],
        // DEL-091: alternativer Name fuer denselben Lift (Templates nutzen
        // unterschiedliche Schreibweisen — wir mappen beide).
        "Kabel Crunch": [
            .homeGym:     "Crunches (BW)",
            .noEquipment: "Crunches (BW)"
        ],
        "Beinheben (hängend)": [
            .homeGym:     "Beinheben (liegend)",
            .noEquipment: "Beinheben (liegend)"
        ],

        // ── DEL-091: Fehlende Cable-Exercises aus den Plan-Templates ───────
        // Diese Lifts waren bisher `.keep` (Sackgasse) im Migrator — der
        // User landete im Urlaubs-Modus mit unveraenderten Kabel-Uebungen.
        "Kabelrudern sitzend": [
            .homeGym:     "Rudern einarmig (KH)",
            .noEquipment: "Australian Pull-ups"
        ],
        "Face Pull": [
            .homeGym:     "Reverse Flyes (KH)",
            .noEquipment: "Back Widows"
        ],
        "Kabel Seitheben": [
            .homeGym:     "Seitheben",
            .noEquipment: "Pike Liegestütze"
        ],
        "Kabel Curl": [
            .homeGym:     "Hammer Curl",
            .noEquipment: "Klimmzüge (eng/Chin-up)"
        ],
        "Trizepsdrücken (Kabel)": [
            .homeGym:     "Trizepskickback (KH)",
            .noEquipment: "Diamant-Liegestütze"
        ],
        "Trizepsstrecker über Kopf (Kabel)": [
            .homeGym:     "Trizepsstrecker über Kopf (KH)",
            .noEquipment: "Dips (Trizeps)"
        ],
        "Brustdrücken (Maschine)": [
            .homeGym:     "Bankdrücken (KH)",
            .noEquipment: "Liegestütze"
        ],
        "Pec Deck (Butterfly)": [
            .homeGym:     "Flyes flach (KH)",
            .noEquipment: "Breite Liegestütze"
        ],
        "Wadenpresse (sitzend)": [
            .homeGym:     "Wadenheben (BW)",
            .noEquipment: "Wadenheben (BW)"
        ],
        "Latzug (weit)": [
            .homeGym:     "Klimmzüge (weit)",
            .noEquipment: "Australian Pull-ups"
        ],

        // ── DEL-091: Symmetrische HomeGym → NoEquipment Pfade ──────────────
        // KH-Uebungen muessen einen klaren BW-Pfad haben, wenn der User
        // von HomeGym in den No-Equipment-Modus wechselt.
        "Hammer Curl": [
            .noEquipment: "Klimmzüge (eng/Chin-up)"
        ],
        "Bizeps-Curl (KH)": [
            .noEquipment: "Klimmzüge (eng/Chin-up)"
        ],
        "Schrägbankdrücken aufwärts (KH)": [
            .noEquipment: "Pike Liegestütze"
        ],
        "Flyes Schrägbank (KH)": [
            .noEquipment: "Breite Liegestütze"
        ],
        "Chest Supported Row (KH)": [
            .noEquipment: "Australian Pull-ups"
        ],
        "Pullover (KH)": [
            .noEquipment: "Australian Pull-ups"
        ],
        "Reverse Flyes (KH)": [
            .noEquipment: "Back Widows"
        ],
        "Rumänisches Kreuzheben (KH)": [
            .noEquipment: "Nordic Curls"
        ],
        // (DEL-091: "Bulgarische Kniebeuge (KH)" steht bereits in
        // LEGS · QUADS oben — Dictionary-Duplikat vermieden.)
        "Hip Thrust (KH)": [
            .noEquipment: "Hip Thrust (BW)"
        ],
        "Wadenheben (KH)": [
            .noEquipment: "Wadenheben (BW)"
        ],
        "Konzentrations-Curl (KH)": [
            .noEquipment: "Klimmzüge (eng/Chin-up)"
        ],
        "Schrägbank-Curl (KH)": [
            .noEquipment: "Klimmzüge (eng/Chin-up)"
        ],
        "Trizepsstrecker über Kopf (KH)": [
            .noEquipment: "Dips (Trizeps)"
        ],
        "Trizepskickback (KH)": [
            .noEquipment: "Diamant-Liegestütze"
        ]
    ]

    /// Resolves the best alternative for `exerciseName` in `environment`. Returns:
    ///   - `.swap(spec)`: a different exercise should replace the old one
    ///   - `.keep`: no mapping exists, leave the exercise in place (user will see
    ///     a Warn-Indicator in the UI)
    ///   - `.stayCompatible`: the exercise is already compatible with the target
    ///     environment, no swap needed
    public static func resolveAlternative(
        forExerciseName name: String,
        targetEnvironment env: EnvironmentType
    ) -> AlternativeResolution {
        // Find the source spec to check its native equipment.
        let sourceSpec = all.first { $0.name == name }
        if let sourceSpec, isCompatible(sourceSpec, with: env) {
            return .stayCompatible
        }

        guard let altName = alternatives[name]?[env],
              let altSpec = all.first(where: { $0.name == altName })
        else {
            return .keep
        }
        return .swap(altSpec)
    }

    /// Whether an exercise's native equipment is doable in the target environment.
    /// Pragmatic-loose: `.bodyweight` works everywhere, `.band` works in home-
    /// gym + noEquipment, etc. Anything else is gym-only.
    private static func isCompatible(
        _ spec: ExerciseTemplateSpec,
        with env: EnvironmentType
    ) -> Bool {
        isEquipment(spec.equipment, compatibleWith: env)
    }

    /// Publiche Variante derselben Check — wird von der UI fuer Bottom-Up-
    /// Konflikt-Detection benutzt (DEL-048): "Diese Maschinen-Uebung passt
    /// nicht zum Bodyweight-Plan — willst du den Plan auf Gym umstellen?"
    public static func isEquipment(
        _ equipment: Equipment,
        compatibleWith env: EnvironmentType
    ) -> Bool {
        switch env {
        case .gym:
            return true   // gym has everything
        case .homeGym:
            return [.bodyweight, .dumbbell, .kettlebell, .band].contains(equipment)
        case .noEquipment:
            return equipment == .bodyweight
        }
    }
}

/// Result of an alternative lookup. Surfaces the three real cases as distinct
/// values so the UI can decide separately (swap → silent, keep → warning,
/// stayCompatible → no-op).
public enum AlternativeResolution: Equatable {
    case swap(ExerciseTemplateSpec)
    case keep
    case stayCompatible
}
