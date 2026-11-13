import Foundation

/// Seed library of exercise templates. `LibrarySeeder` (in `DeltiqData`) reads
/// this list on first app launch and writes one `ExerciseTemplate` row per spec.
///
/// Idempotency: the seeder checks for existing rows before inserting, so editing
/// this list does NOT auto-update existing installs. New entries are picked up;
/// modified or removed entries require a manual user library reset.
public enum ExerciseLibraryData {

    /// Plan-Katalog-Audit: Name-Lookup fuer `PlanMatchmaker.requiredEquipment`
    /// (leitet das tatsaechlich benoetigte Equipment eines Templates aus
    /// seinen Uebungen her, statt Templates ohne `equipmentVariants` blind
    /// durchzulassen). `uniquingKeysWith` statt `uniqueKeysWithValues`
    /// bewusst defensiv: ein zukuenftiger Namenskonflikt soll den Matcher nie
    /// zum Absturz bringen (aktuell 229 von 229 Namen eindeutig, siehe
    /// docs/PLAN_CATALOG_AUDIT.md).
    public static let byName: [String: ExerciseTemplateSpec] = Dictionary(
        all.map { ($0.name, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    public static let all: [ExerciseTemplateSpec] = [
        // ── BARBELL · CHEST ────────────────────────────────────────────────
        // DEL-098: Bench Press = klassischer Compound, hoher Brust-Schaden +
        // moderater systemic Hit (kein axialer Loading-Stress wie Squat).
        ExerciseTemplateSpec(name: "Bankdrücken",                     equipment: .barbell, primaryMuscle: .chest,      isSystemCompound: true,
                             systemicFatigueFactor: 0.55, localMuscleDamageFactor: 0.60, cnsDemandFactor: 0.55, axialLoadFactor: 0.20, technicalComplexityFactor: 0.50, recoveryClass: .high,
                             localizationKey: "exercise.name.benchpress",
                             equipmentRequirement: .all([.item(.barbell), .any([.item(.flatBench), .item(.adjustableBench)])])),
        ExerciseTemplateSpec(name: "Schrägbankdrücken (aufwärts)",  equipment: .barbell, primaryMuscle: .chest, localizationKey: "exercise.name.inclineBenchPress",
                             equipmentRequirement: .all([.item(.barbell), .item(.adjustableBench)])),
        ExerciseTemplateSpec(name: "Schrägbankdrücken (abwärts)",   equipment: .barbell, primaryMuscle: .chest, localizationKey: "exercise.name.declineBenchPress",
                             equipmentRequirement: .all([.item(.barbell), .item(.adjustableBench)])),
        ExerciseTemplateSpec(name: "Enges Bankdrücken",               equipment: .barbell, primaryMuscle: .triceps, localizationKey: "exercise.name.closeGripBenchPress",
                             equipmentRequirement: .all([.item(.barbell), .any([.item(.flatBench), .item(.adjustableBench)])])),

        // ── BARBELL · BACK ─────────────────────────────────────────────────
        // DEL-098: Deadlift = systemic-king. Hoechste Axial-Load aller Lifts.
        ExerciseTemplateSpec(name: "Kreuzheben (konventionell)",       equipment: .barbell, primaryMuscle: .back,       difficultyLevel: .advanced, isSystemCompound: true,
                             systemicFatigueFactor: 0.95, localMuscleDamageFactor: 0.75, cnsDemandFactor: 0.95, axialLoadFactor: 1.00, technicalComplexityFactor: 0.80, recoveryClass: .extreme,
                             localizationKey: "exercise.name.deadlift",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Sumo-Kreuzheben",                  equipment: .barbell, primaryMuscle: .hamstrings, difficultyLevel: .advanced,
                             systemicFatigueFactor: 0.90, localMuscleDamageFactor: 0.75, cnsDemandFactor: 0.90, axialLoadFactor: 0.95, technicalComplexityFactor: 0.75, recoveryClass: .extreme,
                             localizationKey: "exercise.name.sumoDeadlift",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Rudern vorgebeugt",                equipment: .barbell, primaryMuscle: .back,       isSystemCompound: true,
                             localizationKey: "exercise.name.barbellrow",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Pendlay Row",                      equipment: .barbell, primaryMuscle: .back, localizationKey: "exercise.name.pendlayRow",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "T-Bar Rudern",                     equipment: .barbell, primaryMuscle: .back, localizationKey: "exercise.name.tBarRow"),

        // ── BARBELL · SHOULDERS ────────────────────────────────────────────
        // DEL-098: Overhead Press = moderater Compound mit axialer Komponente
        // (vertikale Kette), aber leichter als Squat/DL.
        ExerciseTemplateSpec(name: "Schulterdrücken (stehend)",       equipment: .barbell, primaryMuscle: .shoulders,  isSystemCompound: true,
                             systemicFatigueFactor: 0.60, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.55, axialLoadFactor: 0.55, technicalComplexityFactor: 0.55, recoveryClass: .high,
                             localizationKey: "exercise.name.overheadpress",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Nackendrücken",                   equipment: .barbell, primaryMuscle: .shoulders,  difficultyLevel: .advanced, localizationKey: "exercise.name.behindNeckPress",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Shrug (LH)",                 equipment: .barbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner, localizationKey: "exercise.name.barbellShrug",
                             equipmentRequirement: .item(.barbell)),

        // ── BARBELL · LEGS ─────────────────────────────────────────────────
        // DEL-098: Back Squat = grosser Compound, fast so systemic wie Deadlift.
        ExerciseTemplateSpec(name: "Kniebeuge",                        equipment: .barbell, primaryMuscle: .quads,      isSystemCompound: true,
                             systemicFatigueFactor: 0.90, localMuscleDamageFactor: 0.80, cnsDemandFactor: 0.85, axialLoadFactor: 0.95, technicalComplexityFactor: 0.75, recoveryClass: .extreme,
                             localizationKey: "exercise.name.squat",
                             // Audit Worked Example "Barbell Squat": Langhantel
                             // ALLEIN reicht nicht — ohne Rack/Sicherheitsablage
                             // ist das Gewicht nicht sicher aufnehmbar/absetzbar.
                             equipmentRequirement: .all([.item(.barbell), .item(.rack)])),
        ExerciseTemplateSpec(name: "Front Squat",                      equipment: .barbell, primaryMuscle: .quads,      difficultyLevel: .advanced,
                             systemicFatigueFactor: 0.85, localMuscleDamageFactor: 0.80, cnsDemandFactor: 0.80, axialLoadFactor: 0.90, technicalComplexityFactor: 0.80, recoveryClass: .high,
                             localizationKey: "exercise.name.frontSquat",
                             equipmentRequirement: .all([.item(.barbell), .item(.rack)])),
        ExerciseTemplateSpec(name: "Zercher Squat",                    equipment: .barbell, primaryMuscle: .quads,      difficultyLevel: .advanced, localizationKey: "exercise.name.zercherSquat",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Rumänisches Kreuzheben",          equipment: .barbell, primaryMuscle: .hamstrings,
                             systemicFatigueFactor: 0.75, localMuscleDamageFactor: 0.80, cnsDemandFactor: 0.65, axialLoadFactor: 0.80, technicalComplexityFactor: 0.65, recoveryClass: .high,
                             localizationKey: "exercise.name.romanianDeadlift",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Ausfallschritte (LH)",             equipment: .barbell, primaryMuscle: .quads, localizationKey: "exercise.name.barbellLunge",
                             equipmentRequirement: .all([.item(.barbell), .item(.rack)])),
        ExerciseTemplateSpec(name: "Good Morning",                     equipment: .barbell, primaryMuscle: .hamstrings, difficultyLevel: .advanced, localizationKey: "exercise.name.goodMorning",
                             equipmentRequirement: .all([.item(.barbell), .item(.rack)])),
        ExerciseTemplateSpec(name: "Wadenheben (stehend, LH)",         equipment: .barbell, primaryMuscle: .calves, localizationKey: "exercise.name.barbellStandingCalfRaise",
                             equipmentRequirement: .all([.item(.barbell), .item(.rack)])),

        // ── BARBELL · ARMS ─────────────────────────────────────────────────
        // DEL-098: Curls = klassische Isolation. Sehr niedrige systemic-/CNS-
        // Last, kein axialer Belastung. Lokale Belastung etwas hoeher (Bizeps-
        // DOMS), aber im Vergleich zu Compounds ist alles trivial.
        ExerciseTemplateSpec(name: "Bizeps-Curl (LH)",                  equipment: .barbell, primaryMuscle: .biceps,
                             systemicFatigueFactor: 0.15, localMuscleDamageFactor: 0.35, cnsDemandFactor: 0.10, axialLoadFactor: 0.00, technicalComplexityFactor: 0.15, recoveryClass: .low,
                             localizationKey: "exercise.name.barbellCurl",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Reverse Curl",                     equipment: .barbell, primaryMuscle: .biceps, localizationKey: "exercise.name.reverseCurl",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Skull Crusher",                    equipment: .barbell, primaryMuscle: .triceps, localizationKey: "exercise.name.skullCrusher",
                             equipmentRequirement: .all([.item(.barbell), .any([.item(.flatBench), .item(.adjustableBench)])])),

        // ── DUMBBELL · CHEST ───────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Bankdrücken (KH)",                  equipment: .dumbbell, primaryMuscle: .chest, localizationKey: "exercise.name.dumbbellBenchPress",
                             equipmentRequirement: .all([.item(.dumbbell, minimumCount: 2), .any([.item(.flatBench), .item(.adjustableBench)])])),
        // Audit Worked Example "Incline DB Press": zwei passende Kurzhanteln
        // UND eine verstellbare Bank — eine Flachbank reicht fuer "aufwaerts"
        // nicht aus.
        ExerciseTemplateSpec(name: "Schrägbankdrücken aufwärts (KH)", equipment: .dumbbell, primaryMuscle: .chest, localizationKey: "exercise.name.dumbbellInclineBenchPress",
                             equipmentRequirement: .all([.item(.dumbbell, minimumCount: 2), .item(.adjustableBench)])),
        ExerciseTemplateSpec(name: "Flyes flach (KH)",                 equipment: .dumbbell, primaryMuscle: .chest,      difficultyLevel: .beginner, localizationKey: "exercise.name.dumbbellFlyFlat",
                             equipmentRequirement: .all([.item(.dumbbell, minimumCount: 2), .any([.item(.flatBench), .item(.adjustableBench)])])),
        ExerciseTemplateSpec(name: "Flyes Schrägbank (KH)",           equipment: .dumbbell, primaryMuscle: .chest,      difficultyLevel: .beginner, localizationKey: "exercise.name.dumbbellFlyIncline",
                             equipmentRequirement: .all([.item(.dumbbell, minimumCount: 2), .item(.adjustableBench)])),

        // ── DUMBBELL · BACK ────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Rudern einarmig (KH)",               equipment: .dumbbell, primaryMuscle: .back, localizationKey: "exercise.name.dumbbellRowOneArm",
                             equipmentRequirement: .all([.item(.dumbbell), .any([.item(.flatBench), .item(.adjustableBench)])])),
        // Audit Worked Example "Chest-supported DB Row": passende Kurzhanteln
        // UND eine fuer diese Variante passende Schraegbank.
        ExerciseTemplateSpec(name: "Chest Supported Row (KH)",         equipment: .dumbbell, primaryMuscle: .back, localizationKey: "exercise.name.chestSupportedRowDB",
                             equipmentRequirement: .all([.item(.dumbbell, minimumCount: 2), .item(.adjustableBench)])),
        ExerciseTemplateSpec(name: "Pullover (KH)",                      equipment: .dumbbell, primaryMuscle: .back, localizationKey: "exercise.name.dumbbellPullover",
                             equipmentRequirement: .all([.item(.dumbbell), .any([.item(.flatBench), .item(.adjustableBench)])])),

        // ── DUMBBELL · SHOULDERS ───────────────────────────────────────────
        ExerciseTemplateSpec(name: "Schulterdrücken (KH)",              equipment: .dumbbell, primaryMuscle: .shoulders, localizationKey: "exercise.name.dumbbellShoulderPress",
                             equipmentRequirement: .item(.dumbbell)),
        // README 2.9 Phase 6: gedaempfte KH-Variante des barbell "Push Press"
        // fuer crossfitWeighted "EMOM Ganzkörper" - dieselbe Explosiv-aus-den-
        // Beinen-Mechanik, nur mit Kurzhanteln statt Langhantel.
        ExerciseTemplateSpec(name: "Push Press (KH)",                  equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .advanced, localizationKey: "exercise.name.dumbbellPushPress",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Seitheben",                        equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner, localizationKey: "exercise.name.lateralRaise",
                             equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Frontheben",                       equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner, localizationKey: "exercise.name.frontRaise",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Reverse Flyes (KH)",               equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner, localizationKey: "exercise.name.reverseFlyDB",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Shrug (KH)",                         equipment: .dumbbell, primaryMuscle: .shoulders,  difficultyLevel: .beginner, localizationKey: "exercise.name.dumbbellShrug",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),

        // ── DUMBBELL · LEGS ────────────────────────────────────────────────
        // Audit Worked Example "Goblet Squat": Kettlebell ODER Kurzhantel
        // reicht jeweils allein — keine zusaetzliche Bank/Rack-Anforderung.
        ExerciseTemplateSpec(name: "Goblet Squat",                     equipment: .dumbbell, primaryMuscle: .quads,      difficultyLevel: .beginner, localizationKey: "exercise.name.gobletSquat",
                             equipmentRequirement: .any([.item(.kettlebell), .item(.dumbbell)])),
        ExerciseTemplateSpec(name: "Ausfallschritte (KH)",               equipment: .dumbbell, primaryMuscle: .quads, localizationKey: "exercise.name.dumbbellLunge",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Bulgarische Kniebeuge (KH)",       equipment: .dumbbell, primaryMuscle: .quads, localizationKey: "exercise.name.bulgarianSplitSquatDB",
                             equipmentRequirement: .all([.item(.dumbbell), .any([.item(.flatBench), .item(.adjustableBench)])])),
        ExerciseTemplateSpec(name: "Rumänisches Kreuzheben (KH)",             equipment: .dumbbell, primaryMuscle: .hamstrings, localizationKey: "exercise.name.dumbbellRDL",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),
        // README 2.9 Phase 6: KH-Pendant zum barbell "Kreuzheben (konven-
        // tionell)" (primaryMuscle .back, gleiche Konvention) - fuer
        // crossfitWeighted "Grundlagen-AMRAP", zugaenglicher als die
        // Langhantel-Variante.
        ExerciseTemplateSpec(name: "Kreuzheben (KH)",                  equipment: .dumbbell, primaryMuscle: .back,       difficultyLevel: .beginner, localizationKey: "exercise.name.dumbbellDeadlift",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Step-Up (KH)",                     equipment: .dumbbell, primaryMuscle: .quads,      difficultyLevel: .beginner, localizationKey: "exercise.name.stepUpDB",
                             equipmentRequirement: .all([.item(.dumbbell, minimumCount: 2), .any([.item(.flatBench), .item(.adjustableBench)])])),
        // README 2.9 Phase 6: Kniebeuge-in-Drueck-Kombolift (crossfitWeighted
        // "Auf Zeit: Thruster & Burpees") - genug systemic/CNS-Last fuer
        // explizite DEL-098-Faktoren wie andere grosse Compounds. KEIN
        // isSystemCompound trotzdem - das Flag ist laut
        // testSystemCompoundsAreBarbellLiftsOnly ausschliesslich fuer
        // Langhantel-Lifts reserviert (aendert die Progressions-
        // Schrittweite), ein Dumbbell-Thruster faellt nicht darunter.
        ExerciseTemplateSpec(name: "Thruster (KH)",                    equipment: .dumbbell, primaryMuscle: .quads,      difficultyLevel: .intermediate,
                             systemicFatigueFactor: 0.70, localMuscleDamageFactor: 0.60, cnsDemandFactor: 0.65, axialLoadFactor: 0.45, technicalComplexityFactor: 0.55, recoveryClass: .high,
                             localizationKey: "exercise.name.dumbbellThruster",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),

        // ── DUMBBELL · ARMS ────────────────────────────────────────────────
        // DEL-098: Isolations-Curls = niedrige Recovery-Klasse.
        ExerciseTemplateSpec(name: "Bizeps-Curl (KH)",                          equipment: .dumbbell, primaryMuscle: .biceps,     difficultyLevel: .beginner,
                             systemicFatigueFactor: 0.15, localMuscleDamageFactor: 0.35, cnsDemandFactor: 0.10, axialLoadFactor: 0.00, technicalComplexityFactor: 0.15, recoveryClass: .low,
                             localizationKey: "exercise.name.bicepcurl",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Hammer Curl",                      equipment: .dumbbell, primaryMuscle: .biceps,     difficultyLevel: .beginner,
                             systemicFatigueFactor: 0.15, localMuscleDamageFactor: 0.35, cnsDemandFactor: 0.10, axialLoadFactor: 0.00, technicalComplexityFactor: 0.15, recoveryClass: .low,
                             localizationKey: "exercise.name.hammerCurl",
                             equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Schrägbank-Curl (KH)",                 equipment: .dumbbell, primaryMuscle: .biceps, localizationKey: "exercise.name.inclineDumbbellCurl",
                             equipmentRequirement: .all([.item(.dumbbell), .item(.adjustableBench)])),
        ExerciseTemplateSpec(name: "Konzentrations-Curl (KH)",              equipment: .dumbbell, primaryMuscle: .biceps,     difficultyLevel: .beginner, localizationKey: "exercise.name.concentrationCurl",
                             equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Trizepskickback (KH)",             equipment: .dumbbell, primaryMuscle: .triceps, localizationKey: "exercise.name.dumbbellTricepKickback",
                             equipmentRequirement: .item(.dumbbell)),

        // ── BODYWEIGHT · UPPER ─────────────────────────────────────────────
        // DEL-098: Pull-Ups = mittlerer Compound, kein axialer Loading-Stress
        // (Last haengt am Griff statt auf der Wirbelsaeule).
        // Audit Worked Example "Pull-ups": `equipment: .bodyweight` klassifiziert
        // die Uebung (keine Zusatzlast), sagt aber nichts ueber die benoetigte
        // Klimmzugstange aus — genau die Luecke, die `equipmentRequirement`
        // zusaetzlich zum groben `equipment`-Feld schliesst. Bewusst NUR die
        // Stange — keine erfundene "sichere Aufhaengung/Ringe"-Alternative
        // (Audit-Vorgabe).
        ExerciseTemplateSpec(name: "Klimmzüge (weit)",                equipment: .bodyweight, primaryMuscle: .back,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.65, cnsDemandFactor: 0.45, axialLoadFactor: 0.10, technicalComplexityFactor: 0.45, recoveryClass: .medium,
                             localizationKey: "exercise.name.widePullup",
                             equipmentRequirement: .item(.pullUpBar)),
        ExerciseTemplateSpec(name: "Klimmzüge (eng/Chin-up)",         equipment: .bodyweight, primaryMuscle: .back,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.65, cnsDemandFactor: 0.45, axialLoadFactor: 0.10, technicalComplexityFactor: 0.45, recoveryClass: .medium,
                             localizationKey: "exercise.name.pullup",
                             equipmentRequirement: .item(.pullUpBar)),
        // README 2.9 Phase 6: neutraler/ueberhandgriff Standard-Klimmzug ohne
        // Griff-Qualifier - genutzt in den CrossFit-Bodyweight-Templates
        // (Cindy Rx). Gleiche DEL-098-Faktoren wie die beiden Griff-Varianten
        // oben, da dieselbe Bewegung.
        ExerciseTemplateSpec(name: "Klimmzüge",                        equipment: .bodyweight, primaryMuscle: .back,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.65, cnsDemandFactor: 0.45, axialLoadFactor: 0.10, technicalComplexityFactor: 0.45, recoveryClass: .medium,
                             localizationKey: "exercise.name.pullupStandard",
                             equipmentRequirement: .item(.pullUpBar)),
        ExerciseTemplateSpec(name: "Australian Pull-ups",              equipment: .bodyweight, primaryMuscle: .back, localizationKey: "exercise.name.australianPullup",
                             equipmentRequirement: .item(.pullUpBar)),
        ExerciseTemplateSpec(name: "Handtuch-Rudern (Türrahmen)",     equipment: .bodyweight, primaryMuscle: .back,      difficultyLevel: .beginner, localizationKey: "exercise.name.towelRowDoorframe",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Liegestütze",                     equipment: .bodyweight, primaryMuscle: .chest,     difficultyLevel: .beginner, localizationKey: "exercise.name.pushup",
                             equipmentRequirement: .all([])),
        // README 2.9 Phase 6: Knie-Regression fuer Cindy (Scaled) - genutzt
        // statt der vollen Liegestuetz-Variante fuer Einsteiger.
        ExerciseTemplateSpec(name: "Liegestütze (Knie)",              equipment: .bodyweight, primaryMuscle: .chest,     difficultyLevel: .beginner, localizationKey: "exercise.name.kneePushup",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Diamant-Liegestütze",             equipment: .bodyweight, primaryMuscle: .triceps, localizationKey: "exercise.name.diamondPushup",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Breite Liegestütze",              equipment: .bodyweight, primaryMuscle: .chest, localizationKey: "exercise.name.widePushup",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Dips (Brust)",                     equipment: .bodyweight, primaryMuscle: .chest, localizationKey: "exercise.name.chestDip"),
        ExerciseTemplateSpec(name: "Dips (Trizeps)",                   equipment: .bodyweight, primaryMuscle: .triceps, localizationKey: "exercise.name.tricepDip"),
        ExerciseTemplateSpec(name: "Handstand-Liegestütze",           equipment: .bodyweight, primaryMuscle: .shoulders, difficultyLevel: .advanced, localizationKey: "exercise.name.handstandPushup",
                             equipmentRequirement: .all([])),


        // ── BODYWEIGHT · LOWER ─────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Jump Squat",                       equipment: .bodyweight, primaryMuscle: .quads, localizationKey: "exercise.name.jumpSquat",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Ausfallschritte (BW)",             equipment: .bodyweight, primaryMuscle: .quads,     difficultyLevel: .beginner, localizationKey: "exercise.name.bodyweightLunge",
                             equipmentRequirement: .all([])),
        // README 2.9 Phase 6: plyometrische Variante fuer den EMOM-Intensitaets-
        // Tag (crossfitBodyweightRx) - gleiches Muster wie "Jump Squat" direkt
        // darunter (keine explizite Difficulty/Faktoren-Ueberschreibung).
        ExerciseTemplateSpec(name: "Gesprungene Ausfallschritte",      equipment: .bodyweight, primaryMuscle: .quads, localizationKey: "exercise.name.jumpingLunges",
                             equipmentRequirement: .all([])),

        // DEL-098: Wall Sit = isometrische Quad-Belastung. Lokales DOMS hoch,
        // CNS / systemic eher niedrig (kein Bewegungsablauf, keine schweren
        // Lasten).
        // Beste BW-Quad-Isolation — als Substitute fuer Beinstrecker (Maschine).
        ExerciseTemplateSpec(name: "Sissy Squats (BW)",                equipment: .bodyweight, primaryMuscle: .quads,     difficultyLevel: .advanced, localizationKey: "exercise.name.sissySquat",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Glute Bridge (BW)",                equipment: .bodyweight, primaryMuscle: .glutes,    difficultyLevel: .beginner, localizationKey: "exercise.name.gluteBridge",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Wadenheben (BW)",                  equipment: .bodyweight, primaryMuscle: .calves,    difficultyLevel: .beginner, localizationKey: "exercise.name.bodyweightCalfRaise",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Kniebeuge (BW)",                   equipment: .bodyweight, primaryMuscle: .quads,     difficultyLevel: .beginner, localizationKey: "exercise.name.bodyweightSquat",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Pike Liegestütze",                 equipment: .bodyweight, primaryMuscle: .shoulders, difficultyLevel: .beginner, localizationKey: "exercise.name.pikePushup",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Hip Thrust (BW)",                  equipment: .bodyweight, primaryMuscle: .glutes,    difficultyLevel: .beginner, localizationKey: "exercise.name.bodyweightHipThrust",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Beinheben (liegend)",              equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, localizationKey: "exercise.name.lyingLegRaise",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Nordic Curls",                     equipment: .bodyweight, primaryMuscle: .hamstrings, difficultyLevel: .advanced, localizationKey: "exercise.name.nordicCurls",
                             // shortcut: .pullUpBar als Proxy für "Fußfixierung" — kein passenderes EquipmentItem vorhanden
                             equipmentRequirement: .item(.pullUpBar)),

        // ── BODYWEIGHT · CORE ──────────────────────────────────────────────
        // DEL-098: Iso-Core wie Plank / Seitstuetz = analog zu Wall Sit. Burpees
        // sind eine Outlier — hohe systemic Cost wegen voller Bewegungskette.
        ExerciseTemplateSpec(name: "Plank",                            equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isTimeBased: true,
                             systemicFatigueFactor: 0.25, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.15, axialLoadFactor: 0.10, technicalComplexityFactor: 0.10, recoveryClass: .low,
                             localizationKey: "exercise.name.plank",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Seitstütz",                       equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isTimeBased: true,
                             systemicFatigueFactor: 0.25, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.15, axialLoadFactor: 0.10, technicalComplexityFactor: 0.15, recoveryClass: .low,
                             localizationKey: "exercise.name.sidePlank",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Mountain Climbers",                equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isTimeBased: true,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.40, cnsDemandFactor: 0.30, axialLoadFactor: 0.10, technicalComplexityFactor: 0.20, recoveryClass: .medium,
                             localizationKey: "exercise.name.mountainClimber",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Burpees",                          equipment: .bodyweight, primaryMuscle: .core,      isTimeBased: true,
                             systemicFatigueFactor: 0.75, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.50, axialLoadFactor: 0.20, technicalComplexityFactor: 0.40, recoveryClass: .high,
                             localizationKey: "exercise.name.burpee",
                             equipmentRequirement: .all([])),
        // Standard-Substitutes fuer Kabel-Crunches und haengendes Beinheben.
        ExerciseTemplateSpec(name: "Crunches (BW)",                    equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, localizationKey: "exercise.name.crunch",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Sit-ups",                          equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, localizationKey: "exercise.name.situp",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Beinstrecker liegend",             equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.lyingLegExtension",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Russian Twists",                   equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, localizationKey: "exercise.name.russianTwist",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Hanging Leg Raises",               equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.hangingLegRaise",
                             equipmentRequirement: .item(.pullUpBar)),

        // ── MACHINE / CABLE · CHEST ────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kabel Crossover",                  equipment: .cable,    primaryMuscle: .chest, localizationKey: "exercise.name.cableCrossover",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Pec Deck (Butterfly)",             equipment: .machine,  primaryMuscle: .chest,       difficultyLevel: .beginner, localizationKey: "exercise.name.pecDeck",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Brustdrücken (Maschine)",             equipment: .machine,  primaryMuscle: .chest,       difficultyLevel: .beginner, localizationKey: "exercise.name.chestPressMachine",
                             equipmentRequirement: .item(.machineStation)),

        // ── MACHINE / CABLE · BACK ─────────────────────────────────────────
        ExerciseTemplateSpec(name: "Latzug (eng)",                     equipment: .machine,  primaryMuscle: .back,        difficultyLevel: .beginner, localizationKey: "exercise.name.latPulldownClose",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Kabelrudern sitzend",              equipment: .cable,    primaryMuscle: .back,        difficultyLevel: .beginner, localizationKey: "exercise.name.seatedCableRow",
                             equipmentRequirement: .item(.cableStation)),

        // ── MACHINE / CABLE · SHOULDERS ────────────────────────────────────
        ExerciseTemplateSpec(name: "Kabel Seitheben",                  equipment: .cable,    primaryMuscle: .shoulders,   difficultyLevel: .beginner, localizationKey: "exercise.name.cableLateralRaise",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Schulterdrücken (Maschine)",          equipment: .machine,  primaryMuscle: .shoulders,   difficultyLevel: .beginner, localizationKey: "exercise.name.shoulderPressMachine",
                             equipmentRequirement: .item(.machineStation)),

        // ── MACHINE / CABLE · ARMS ─────────────────────────────────────────
        ExerciseTemplateSpec(name: "Trizepsdrücken (Kabel)",          equipment: .cable,    primaryMuscle: .triceps, localizationKey: "exercise.name.tricepPushdown",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Trizepsstrecker über Kopf (Kabel)", equipment: .cable,   primaryMuscle: .triceps, localizationKey: "exercise.name.cableOverheadTricepExtension",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Preacher Curl (Maschine)",         equipment: .machine,  primaryMuscle: .biceps,      difficultyLevel: .beginner, localizationKey: "exercise.name.preacherCurl",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Kabel Curl",                       equipment: .cable,    primaryMuscle: .biceps,      difficultyLevel: .beginner, localizationKey: "exercise.name.cableCurl",
                             equipmentRequirement: .item(.cableStation)),

        // ── MACHINE / CABLE · LEGS ─────────────────────────────────────────
        ExerciseTemplateSpec(name: "Beinpresse",                       equipment: .machine,  primaryMuscle: .quads,       difficultyLevel: .beginner,
                             localizationKey: "exercise.name.legpress",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Beinstrecker",                     equipment: .machine,  primaryMuscle: .quads,       difficultyLevel: .beginner, localizationKey: "exercise.name.legExtension",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Beinbeuger liegend",               equipment: .machine,  primaryMuscle: .hamstrings,  difficultyLevel: .beginner, localizationKey: "exercise.name.lyingLegCurl",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Hack Squat",                       equipment: .machine,  primaryMuscle: .quads, localizationKey: "exercise.name.hackSquat",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Smith Machine Squat",              equipment: .machine,  primaryMuscle: .quads, localizationKey: "exercise.name.smithMachineSquat",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Wadenpresse (sitzend)",            equipment: .machine,  primaryMuscle: .calves,      difficultyLevel: .beginner, localizationKey: "exercise.name.seatedCalfRaise",
                             equipmentRequirement: .item(.machineStation)),

        // ── MACHINE / CABLE · CORE ─────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kabel Crunch",                     equipment: .cable,    primaryMuscle: .core,        difficultyLevel: .beginner, localizationKey: "exercise.name.cableCrunch",
                             equipmentRequirement: .item(.cableStation)),

        // ── RESISTANCE BAND ────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Banded Squats",                    equipment: .band,     primaryMuscle: .quads,       difficultyLevel: .beginner, localizationKey: "exercise.name.bandedSquat",
                             equipmentRequirement: .item(.resistanceBand)),
        ExerciseTemplateSpec(name: "Band Curls",                       equipment: .band,     primaryMuscle: .biceps,      difficultyLevel: .beginner, localizationKey: "exercise.name.bandCurl",
                             equipmentRequirement: .item(.resistanceBand)),

        // ── KETTLEBELL ─────────────────────────────────────────────────────
        ExerciseTemplateSpec(name: "Kettlebell Swing",                 equipment: .kettlebell, primaryMuscle: .glutes, localizationKey: "exercise.name.kettlebellSwing",
                             equipmentRequirement: .item(.kettlebell)),
        ExerciseTemplateSpec(name: "Kettlebell Goblet Squat",          equipment: .kettlebell, primaryMuscle: .quads,     difficultyLevel: .beginner, localizationKey: "exercise.name.kettlebellGobletSquat",
                             equipmentRequirement: .any([.item(.kettlebell), .item(.dumbbell)])),
        ExerciseTemplateSpec(name: "Kettlebell Snatch",                equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellSnatch",
                             equipmentRequirement: .item(.kettlebell)),
        ExerciseTemplateSpec(name: "Kettlebell Clean & Press",         equipment: .kettlebell, primaryMuscle: .shoulders, localizationKey: "exercise.name.kettlebellCleanAndPress",
                             equipmentRequirement: .item(.kettlebell)),

        // DEL-171: KB-Ergänzungen, damit die hybridBalanced/Beginner/Performance-
        // Templates eine vollwertige kettlebellOnly-Variante bekommen.
        // Audit Worked Example "Floor Press": nur die Kettlebell -- bewusst
        // KEINE Bank-Anforderung (das ist der ganze Punkt der Uebung).
        ExerciseTemplateSpec(name: "Kettlebell Floor Press",           equipment: .kettlebell, primaryMuscle: .chest,     difficultyLevel: .intermediate, localizationKey: "exercise.name.kettlebellFloorPress",
                             equipmentRequirement: .item(.kettlebell)),
        ExerciseTemplateSpec(name: "Kettlebell Row einarmig",          equipment: .kettlebell, primaryMuscle: .back,      difficultyLevel: .intermediate, localizationKey: "exercise.name.kettlebellRowSingleArm",
                             equipmentRequirement: .item(.kettlebell)),
        // Übungen der CrossFit-/Kettlebell-Trainingspläne (README 2.9 Phase 6),
        // die bisher nur in `ProgramTemplates` als roher Name standen, ohne
        // Library-Match — jetzt offiziell im Catalog, gleiches Muster wie
        // die "Cardio · Hybrid-Plan-Lifts"-Promotion oben (DEL-116).
        ExerciseTemplateSpec(name: "Kettlebell Front Squat",           equipment: .kettlebell, primaryMuscle: .quads,     difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellFrontSquat",
                             equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        // Unilaterale Snatch-Variante fuer EMOM-Wechsel Links/Rechts pro
        // Minute (kettlebellAdvanced Tag 1) — dieselbe Bewegung wie das
        // bestehende "Kettlebell Snatch", nur seitengetrennt als eigene
        // Uebung, weil ein Tag im Datenmodell keine Seiten-Alternation kennt.
        // Nutzer-Upload (13. August, zweite Runde): 5 Kettlebell-Komplexe
        // ("Athletik beginnt hier") - sechs neue Bewegungen, die noch keine
        // Library-Entsprechung hatten (siehe Kommentare je Zeile fuer die
        // Abgrenzung zu bereits vorhandenen, aehnlichen Eintraegen).

        // Anders als "Pullover (KH)" oben (Kurzhantel, beidhaendig): mit
        // EINER Kettlebell, ansonsten dieselbe Bewegung.
        // Einarmige KB-Variante von "Thruster (KH)" oben (Zweihand-Kurzhantel)
        // - gleiche Faktoren wie dort, ein Komplex mit Kniebeuge+Drueck ist
        // aehnlich fordernd, unabhaengig vom Geraet.
        // Anders als "Sit-ups" oben (Bodyweight): der Overhead-Hold macht es
        // zu einer eigenstaendigen Core-Stabilitaets-Uebung, kein reiner
        // Bodyweight-Bauchmuskel-Move mehr.
        // Anders als "Diamant-Liegestütze" oben (Boden): Haende auf dem
        // Kettlebell-Griff, instabiler als eine feste Bodenflaeche.

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
                             localizationKey: "exercise.name.run",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Laufband",                         equipment: .machine,    primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.55, localMuscleDamageFactor: 0.45, cnsDemandFactor: 0.30, axialLoadFactor: 0.20, technicalComplexityFactor: 0.10, recoveryClass: .medium,
                             localizationKey: "exercise.name.treadmill",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Radfahren (outdoor)",              equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.55, localMuscleDamageFactor: 0.35, cnsDemandFactor: 0.25, axialLoadFactor: 0.10, technicalComplexityFactor: 0.10, recoveryClass: .medium,
                             localizationKey: "exercise.name.cycling",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Fahrradergometer",                 equipment: .machine,    primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.30, cnsDemandFactor: 0.20, axialLoadFactor: 0.05, technicalComplexityFactor: 0.05, recoveryClass: .medium,
                             localizationKey: "exercise.name.stationaryBike",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Crosstrainer",                     equipment: .machine,    primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.45, localMuscleDamageFactor: 0.30, cnsDemandFactor: 0.20, axialLoadFactor: 0.05, technicalComplexityFactor: 0.05, recoveryClass: .medium,
                             localizationKey: "exercise.name.elliptical",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Stepper",                          equipment: .machine,    primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.40, cnsDemandFactor: 0.20, axialLoadFactor: 0.10, technicalComplexityFactor: 0.05, recoveryClass: .medium,
                             localizationKey: "exercise.name.stairStepper",
                             equipmentRequirement: .item(.machineStation)),
        // ── CARDIO · HYBRID-PLAN-LIFTS (DEL-116) ───────────────────────────
        // DEL-116: Promoted aus den ProgramTemplates-Orphans. Vorher waren
        // "Easy Run", "Long Run", "Intervalle", "Gehen / Einlaufen" inline
        // ExerciseSpec(name:) Strings in Hybrid-Plan-Templates ohne Library-
        // Match — landeten als rohes DE in Exercise.name. Jetzt offiziell
        // im Catalog mit Multi-Locale-Display.
        ExerciseTemplateSpec(name: "Easy Run",                         equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.50, localMuscleDamageFactor: 0.40, cnsDemandFactor: 0.25, axialLoadFactor: 0.20, technicalComplexityFactor: 0.10, recoveryClass: .medium,
                             localizationKey: "exercise.name.easyRun",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Long Run",                         equipment: .bodyweight, primaryMuscle: .core,      isCardio: true,
                             systemicFatigueFactor: 0.70, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.35, axialLoadFactor: 0.25, technicalComplexityFactor: 0.10, recoveryClass: .high,
                             localizationKey: "exercise.name.longRun",
                             equipmentRequirement: .all([])),
        // DEL-PhaseA: eigene Uebung fuer die Tempo-Zone des Laufcoachings —
        // "Long Run" bleibt fuer Hybrid-Plan-Langlaeufe; neue Plaene nutzen
        // "Tempo Run" (→ "Tempolauf" DE) damit Name und Tages-Titel uebereinstimmen.
        ExerciseTemplateSpec(name: "Tempo Run",                        equipment: .bodyweight, primaryMuscle: .core,      isCardio: true,
                             systemicFatigueFactor: 0.70, localMuscleDamageFactor: 0.55, cnsDemandFactor: 0.40, axialLoadFactor: 0.25, technicalComplexityFactor: 0.15, recoveryClass: .high,
                             localizationKey: "exercise.name.tempoRun",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Intervalle",                       equipment: .bodyweight, primaryMuscle: .core,      isCardio: true,
                             systemicFatigueFactor: 0.75, localMuscleDamageFactor: 0.50, cnsDemandFactor: 0.55, axialLoadFactor: 0.20, technicalComplexityFactor: 0.20, recoveryClass: .high,
                             localizationKey: "exercise.name.intervals",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Gehen / Einlaufen",                equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner, isCardio: true,
                             systemicFatigueFactor: 0.15, localMuscleDamageFactor: 0.10, cnsDemandFactor: 0.05, axialLoadFactor: 0.05, technicalComplexityFactor: 0.05, recoveryClass: .low,
                             localizationKey: "exercise.name.warmupWalk",
                             equipmentRequirement: .all([])),
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
                             localizationKey: "exercise.name.runInterval",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Rad-Intervall",                    equipment: .bodyweight, primaryMuscle: .core,      isTimeBased: true, isCardio: true,
                             systemicFatigueFactor: 0.65, localMuscleDamageFactor: 0.40, cnsDemandFactor: 0.35, axialLoadFactor: 0.10, technicalComplexityFactor: 0.15, recoveryClass: .high,
                             localizationKey: "exercise.name.cyclingInterval",
                             equipmentRequirement: .all([])),

        // ── DEL-162: Bibliotheks-Erweiterung (verbreitete Standardübungen) ──
        // Heavy-Compounds (DL-/Squat-Varianten + Olympic-Lifts) tragen explizite
        // DEL-098-Faktoren + isSystemCompound, damit DayAnalysis sie korrekt als
        // systemisch schwer einstuft. Accessory-/Iso-/Hold-Übungen nutzen die
        // moderaten Defaults (kein nil → keine PR-/Day-Analysis-Regression).

        // Barbell Compounds
        ExerciseTemplateSpec(name: "Trap-Bar-Kreuzheben", equipment: .barbell, primaryMuscle: .back, difficultyLevel: .intermediate, isSystemCompound: true,
                             systemicFatigueFactor: 0.88, localMuscleDamageFactor: 0.72, cnsDemandFactor: 0.85, axialLoadFactor: 0.90, technicalComplexityFactor: 0.55, recoveryClass: .extreme,
                             localizationKey: "exercise.name.trapBarDeadlift"),

        // Barbell / Dumbbell Press-Varianten
        ExerciseTemplateSpec(name: "Tate Press", equipment: .dumbbell, primaryMuscle: .triceps, difficultyLevel: .intermediate, localizationKey: "exercise.name.tatePress",
                             equipmentRequirement: .all([.item(.dumbbell, minimumCount: 2), .any([.item(.flatBench), .item(.adjustableBench)])])),

        // Rows
        ExerciseTemplateSpec(name: "Inverted Row", equipment: .bodyweight, primaryMuscle: .back, difficultyLevel: .beginner, localizationKey: "exercise.name.invertedRow"),

        // Cable
        ExerciseTemplateSpec(name: "Cable Pull-Through", equipment: .cable, primaryMuscle: .glutes, difficultyLevel: .beginner, localizationKey: "exercise.name.cablePullThrough",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Cable Woodchopper", equipment: .cable, primaryMuscle: .core, difficultyLevel: .intermediate, localizationKey: "exercise.name.cableWoodchopper",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Reverse Cable Fly", equipment: .cable, primaryMuscle: .shoulders, difficultyLevel: .beginner, localizationKey: "exercise.name.reverseCableFly",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Latzug (neutraler Griff)", equipment: .cable, primaryMuscle: .back, difficultyLevel: .beginner, localizationKey: "exercise.name.neutralGripLatPulldown",
                             equipmentRequirement: .item(.cableStation)),

        // Machine
        ExerciseTemplateSpec(name: "Beincurl sitzend", equipment: .machine, primaryMuscle: .hamstrings, difficultyLevel: .beginner, localizationKey: "exercise.name.seatedLegCurl",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Beincurl stehend", equipment: .machine, primaryMuscle: .hamstrings, difficultyLevel: .beginner, localizationKey: "exercise.name.standingLegCurl",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Wadenpresse (Beinpresse)", equipment: .machine, primaryMuscle: .calves, difficultyLevel: .beginner, localizationKey: "exercise.name.calfPressLegPress",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Klimmzug (assistiert)", equipment: .machine, primaryMuscle: .back, difficultyLevel: .beginner, localizationKey: "exercise.name.assistedPullUp",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Dip (assistiert)", equipment: .machine, primaryMuscle: .triceps, difficultyLevel: .beginner, localizationKey: "exercise.name.assistedDip",
                             equipmentRequirement: .item(.machineStation)),

        // Bodyweight / Calisthenics
        ExerciseTemplateSpec(name: "Pistol Squat", equipment: .bodyweight, primaryMuscle: .quads, difficultyLevel: .advanced, localizationKey: "exercise.name.pistolSquat",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Muscle-Up", equipment: .bodyweight, primaryMuscle: .back, difficultyLevel: .advanced, localizationKey: "exercise.name.muscleUp",
                             equipmentRequirement: .item(.pullUpBar)),
        ExerciseTemplateSpec(name: "Medizinball-Slam", equipment: .bodyweight, primaryMuscle: .core, difficultyLevel: .intermediate, localizationKey: "exercise.name.medicineBallSlam"),

        // Forearm / Neck Isolation
        ExerciseTemplateSpec(name: "Handgelenk-Curl", equipment: .dumbbell, primaryMuscle: .biceps, difficultyLevel: .beginner, localizationKey: "exercise.name.wristCurl",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Handgelenk-Curl (umgekehrt)", equipment: .dumbbell, primaryMuscle: .biceps, difficultyLevel: .beginner, localizationKey: "exercise.name.reverseWristCurl",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),

        // Time-Based Holds
        ExerciseTemplateSpec(name: "L-Sit", equipment: .bodyweight, primaryMuscle: .core, difficultyLevel: .advanced, isTimeBased: true, localizationKey: "exercise.name.lSit",
                             equipmentRequirement: .all([])),

        // Loaded Carries / Conditioning (zeitbasiert)
        ExerciseTemplateSpec(name: "Farmer's Walk", equipment: .dumbbell, primaryMuscle: .back, difficultyLevel: .intermediate, isTimeBased: true, localizationKey: "exercise.name.farmersWalk",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Battle Ropes", equipment: .bodyweight, primaryMuscle: .shoulders, difficultyLevel: .intermediate, isTimeBased: true, localizationKey: "exercise.name.battleRopes"),

        // ── NEU (GIF-Abgleich): Equipment-Varianten + Olympic-Lift-Ergaenzung ──
        // Aus dem Uebungs-GIF-Datensatz identifizierte Luecken, deren GIF
        // eindeutig zuordenbar ist (siehe exercise_gif_overrides.json).
        ExerciseTemplateSpec(name: "Arnold Press (KH)", equipment: .dumbbell, primaryMuscle: .shoulders, localizationKey: "exercise.name.dumbbellArnoldPress",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Arnold Press (Kettlebell)", equipment: .kettlebell, primaryMuscle: .shoulders, localizationKey: "exercise.name.kettlebellArnoldPress",
                             equipmentRequirement: .item(.kettlebell)),
        ExerciseTemplateSpec(name: "Ausfallschritt rückwärts (KH)", equipment: .dumbbell, primaryMuscle: .quads, localizationKey: "exercise.name.dumbbellReverseLunge",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Ausfallschritt rückwärts (LH)", equipment: .barbell, primaryMuscle: .quads, localizationKey: "exercise.name.barbellReverseLunge",
                             equipmentRequirement: .all([.item(.barbell), .item(.rack)])),
        ExerciseTemplateSpec(name: "Seitlicher Ausfallschritt (LH)", equipment: .barbell, primaryMuscle: .quads, localizationKey: "exercise.name.barbellLateralLunge",
                             equipmentRequirement: .all([.item(.barbell), .item(.rack)])),
        ExerciseTemplateSpec(name: "Kettlebell Windmill", equipment: .kettlebell, primaryMuscle: .core, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellWindmill",
                             equipmentRequirement: .item(.kettlebell)),
        ExerciseTemplateSpec(name: "Kettlebell Pistol Squat", equipment: .kettlebell, primaryMuscle: .quads, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellPistolSquat",
                             equipmentRequirement: .item(.kettlebell)),
        ExerciseTemplateSpec(name: "Kettlebell Bent Press", equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellBentPress",
                             equipmentRequirement: .item(.kettlebell)),
        // DEL-098: Power Clean = Zug-Teil des Clean & Jerk ohne Stoßen —
        // Faktoren analog "Umsetzen & Stoßen", leicht reduziert (kein Jerk).
        ExerciseTemplateSpec(name: "Power Clean", equipment: .barbell, primaryMuscle: .shoulders, difficultyLevel: .advanced, isSystemCompound: true,
                             systemicFatigueFactor: 0.85, localMuscleDamageFactor: 0.65, cnsDemandFactor: 0.92, axialLoadFactor: 0.85, technicalComplexityFactor: 0.90, recoveryClass: .extreme,
                             localizationKey: "exercise.name.powerClean",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Low-Bar-Kniebeuge (LH)", equipment: .barbell, primaryMuscle: .quads, difficultyLevel: .advanced,
                             systemicFatigueFactor: 0.88, localMuscleDamageFactor: 0.78, cnsDemandFactor: 0.80, axialLoadFactor: 0.95, technicalComplexityFactor: 0.75, recoveryClass: .high,
                             localizationKey: "exercise.name.lowBarBackSquat",
                             equipmentRequirement: .all([.item(.barbell), .item(.rack)])),
        ExerciseTemplateSpec(name: "Hack Squat (LH)", equipment: .barbell, primaryMuscle: .quads, localizationKey: "exercise.name.barbellHackSquat",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Hack Squat (Smith)", equipment: .machine, primaryMuscle: .quads, localizationKey: "exercise.name.smithHackSquat",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Reverse Crunch", equipment: .bodyweight, primaryMuscle: .core, difficultyLevel: .beginner, localizationKey: "exercise.name.reverseCrunch",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Kabel Reverse Crunch", equipment: .cable, primaryMuscle: .core, localizationKey: "exercise.name.cableReverseCrunch",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Handgelenk-Curl (LH)", equipment: .barbell, primaryMuscle: .biceps, difficultyLevel: .beginner, localizationKey: "exercise.name.barbellWristCurl",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Handgelenk-Curl (Kabel)", equipment: .cable, primaryMuscle: .biceps, difficultyLevel: .beginner, localizationKey: "exercise.name.cableWristCurl",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Band Pull-Through", equipment: .band, primaryMuscle: .glutes, difficultyLevel: .beginner, localizationKey: "exercise.name.bandPullThrough",
                             equipmentRequirement: .item(.resistanceBand)),
        ExerciseTemplateSpec(name: "Burpee mit Kurzhanteln", equipment: .dumbbell, primaryMuscle: .core, isTimeBased: true, localizationKey: "exercise.name.dumbbellBurpee",
                             equipmentRequirement: .item(.dumbbell, minimumCount: 2)),

        // ── NEU (GIF-Overrides Runde 3): Praezisions-Varianten fuer per
        // FORCE_NO_GIF ausgeschlossene Eintraege + eigene Tiefensuche-Treffer.
        // Die jeweils abgeloeste Uebung bleibt unveraendert und ohne GIF.
        // DEL-098: `isSystemCompound` ist exklusiv fuer die kanonischen 5
        // Langhantel-Lifts reserviert (steuert die Compound-Progressions-
        // Schrittweite) — das JSON-Feld "compound" (jede Mehrgelenk-
        // Uebung) ist ein anderes Konzept und wird hier bewusst NICHT
        // auf dieses Flag uebertragen, siehe testSystemCompoundsAreBarbellLiftsOnly.
        ExerciseTemplateSpec(name: "Liegendes Bein-Hüft-Heben", equipment: .bodyweight, primaryMuscle: .core, difficultyLevel: .beginner, localizationKey: "exercise.name.lyingLegHipRaise",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Innere Brustpresse (Maschine)", equipment: .machine, primaryMuscle: .chest, difficultyLevel: .beginner, localizationKey: "exercise.name.machineInnerChestPress",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Sitzender Kabel-Crunch", equipment: .cable, primaryMuscle: .core, difficultyLevel: .beginner, localizationKey: "exercise.name.cableSeatedCrunch",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Kabel Cross-Over (Variation)", equipment: .cable, primaryMuscle: .chest, localizationKey: "exercise.name.cableCrossOverVariation",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Kettlebell Schulterdrücken sitzend", equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .beginner, localizationKey: "exercise.name.kettlebellSeatedPress",
                             equipmentRequirement: .item(.kettlebell)),
        // Audit Worked Example "Double Kettlebell Push Press": zwei Kettlebells
        // noetig, eine reicht nicht fuer die beidarmige Variante.
        ExerciseTemplateSpec(name: "Kettlebell Doppel-Push-Press", equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellDoublePushPress",
                             equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Kettlebell Thruster", equipment: .kettlebell, primaryMuscle: .quads, difficultyLevel: .intermediate, localizationKey: "exercise.name.kettlebellThruster",
                             equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Latzug an der Kabelstange", equipment: .cable, primaryMuscle: .back, difficultyLevel: .beginner, localizationKey: "exercise.name.cableBarLateralPulldown",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Kettlebell Plyo-Liegestütze", equipment: .kettlebell, primaryMuscle: .chest, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellPlyoPushUp",
                             equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Kabel Reverse Fly liegend", equipment: .cable, primaryMuscle: .shoulders, difficultyLevel: .beginner, localizationKey: "exercise.name.cableSupineReverseFly",
                             equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Schulterdrücken (Smith Machine)", equipment: .machine, primaryMuscle: .shoulders, difficultyLevel: .beginner, localizationKey: "exercise.name.smithShoulderPress",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Sitzendes Trizepsstrecken (KH)", equipment: .dumbbell, primaryMuscle: .triceps, localizationKey: "exercise.name.dumbbellSeatedTricepsExtension",
                             equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Kettlebell Turkish Get-Up (Squat-Stil)", equipment: .kettlebell, primaryMuscle: .core, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellTurkishGetUpSquatStyle",
                             equipmentRequirement: .item(.kettlebell)),
        ExerciseTemplateSpec(name: "Sitzendes Wadenheben (KH)", equipment: .dumbbell, primaryMuscle: .calves, difficultyLevel: .beginner, localizationKey: "exercise.name.dumbbellSeatedCalfRaise",
                             equipmentRequirement: .item(.dumbbell)),
        // Abschnitt 3: eigene Volltext-Tiefensuche, je ein eindeutiger
        // Einzel-Kandidat mit abweichendem Equipment.
        ExerciseTemplateSpec(name: "Renegade Row (Kettlebell)", equipment: .kettlebell, primaryMuscle: .back, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellRenegadeRow",
                             equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Latzug eng (Band)", equipment: .band, primaryMuscle: .back, difficultyLevel: .beginner, localizationKey: "exercise.name.bandCloseGripPulldown",
                             equipmentRequirement: .item(.resistanceBand)),

        // ── NEU (GIF-Overrides Runde 4, GIF_TIEFENSUCHE): weitere
        // Equipment-/Griff-/Haltungs-Varianten aus der Volltext-Tiefensuche,
        // alle per Standbild gesichtet. Originale bleiben unveraendert.
        ExerciseTemplateSpec(name: "Beinheben auf Flachbank", equipment: .bodyweight, primaryMuscle: .core, difficultyLevel: .beginner, localizationKey: "exercise.name.lyingLegRaiseFlatBench",
                             equipmentRequirement: .any([.item(.flatBench), .item(.adjustableBench)])),
        ExerciseTemplateSpec(name: "Wand-Sitz mit Marschieren", equipment: .bodyweight, primaryMuscle: .quads, difficultyLevel: .beginner, isTimeBased: true, localizationKey: "exercise.name.marchSitWall",
                             equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Gehen am Laufband (Steigung)", equipment: .machine, primaryMuscle: .core, difficultyLevel: .beginner, isCardio: true, localizationKey: "exercise.name.walkingInclineTreadmill",
                             equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Schulterdrücken stehend (LH, enger Griff)", equipment: .barbell, primaryMuscle: .shoulders, localizationKey: "exercise.name.barbellStandingCloseGripMilitaryPress",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Kettlebell Push Press einarmig", equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellOneArmPushPress",
                             equipmentRequirement: .item(.kettlebell)),
        ExerciseTemplateSpec(name: "Kettlebell Schulterdrücken stehend (zwei Kettlebells)", equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .beginner, localizationKey: "exercise.name.kettlebellTwoArmMilitaryPress",
                             equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Floor Press einarmig (LH)", equipment: .barbell, primaryMuscle: .triceps, difficultyLevel: .advanced, localizationKey: "exercise.name.barbellOneArmFloorPress",
                             equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Kettlebell Clean & Jerk einarmig", equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced, localizationKey: "exercise.name.kettlebellOneArmCleanAndJerk",
                             equipmentRequirement: .item(.kettlebell)),

        // ── DEL-NEW: Kettlebell-Erweiterung + Standard-Übungen ──────────────
        // Kettlebell
        ExerciseTemplateSpec(name: "Kettlebell Advanced Windmill",              equipment: .kettlebell, primaryMuscle: .core,      difficultyLevel: .advanced,     localizationKey: "exercise.name.kettlebellAdvancedWindmill"),
        ExerciseTemplateSpec(name: "Kettlebell Alternating Hang Clean",         equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced,     localizationKey: "exercise.name.kettlebellAlternatingHangClean"),
        ExerciseTemplateSpec(name: "Kettlebell Alternating Press",              equipment: .kettlebell, primaryMuscle: .shoulders,                                  localizationKey: "exercise.name.kettlebellAlternatingPress"),
        ExerciseTemplateSpec(name: "Kettlebell Alternating Press Liegend",      equipment: .kettlebell, primaryMuscle: .chest,                                     localizationKey: "exercise.name.kettlebellAlternatingPressLying"),
        ExerciseTemplateSpec(name: "Kettlebell Alternating Row",                equipment: .kettlebell, primaryMuscle: .back,                                      localizationKey: "exercise.name.kettlebellAlternatingRow"),
        ExerciseTemplateSpec(name: "Kettlebell Bottoms-Up Clean",               equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced,     localizationKey: "exercise.name.kettlebellBottomsUpClean"),
        ExerciseTemplateSpec(name: "Kettlebell Double Hang Clean",              equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced,     localizationKey: "exercise.name.kettlebellDoubleHangClean",   equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Kettlebell Double Jerk",                    equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced,     localizationKey: "exercise.name.kettlebellDoubleJerk",        equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Kettlebell Double Snatch",                  equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .advanced,     localizationKey: "exercise.name.kettlebellDoubleSnatch",      equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Kettlebell Double Windmill",                equipment: .kettlebell, primaryMuscle: .core,      difficultyLevel: .advanced,     localizationKey: "exercise.name.kettlebellDoubleWindmill",    equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Kettlebell Figure 8",                       equipment: .kettlebell, primaryMuscle: .core,      difficultyLevel: .intermediate, localizationKey: "exercise.name.kettlebellFigure8"),
        ExerciseTemplateSpec(name: "Kettlebell Hang Clean",                     equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .intermediate, localizationKey: "exercise.name.kettlebellHangClean"),
        ExerciseTemplateSpec(name: "Kettlebell Lunge mit Durchreichen",         equipment: .kettlebell, primaryMuscle: .quads,     difficultyLevel: .intermediate, localizationKey: "exercise.name.kettlebellLungePassing"),
        ExerciseTemplateSpec(name: "Kettlebell Seesaw Press",                   equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .intermediate, localizationKey: "exercise.name.kettlebellSeesawPress",       equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Kettlebell Two Arm Clean",                  equipment: .kettlebell, primaryMuscle: .shoulders, difficultyLevel: .intermediate, localizationKey: "exercise.name.kettlebellTwoArmClean",       equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Kettlebell Rudern (beide Arme)",            equipment: .kettlebell, primaryMuscle: .back,                                      localizationKey: "exercise.name.kettlebellRowBothArms",       equipmentRequirement: .item(.kettlebell, minimumCount: 2)),
        ExerciseTemplateSpec(name: "Kettlebell Schulterdrücken Sitzend (beide Arme)", equipment: .kettlebell, primaryMuscle: .shoulders,                           localizationKey: "exercise.name.kettlebellSeatedPressDoubleArm", equipmentRequirement: .item(.kettlebell, minimumCount: 2)),

        // Barbell
        ExerciseTemplateSpec(name: "Schulterdrücken (LH, sitzend)",            equipment: .barbell,    primaryMuscle: .shoulders, localizationKey: "exercise.name.barbellSeatedShoulderPress",  equipmentRequirement: .all([.item(.barbell), .item(.adjustableBench)])),
        ExerciseTemplateSpec(name: "Upright Row (LH)",                          equipment: .barbell,    primaryMuscle: .shoulders, localizationKey: "exercise.name.barbellUprightRow",            equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Pullover (LH)",                             equipment: .barbell,    primaryMuscle: .back,      localizationKey: "exercise.name.barbellPullover",              equipmentRequirement: .all([.item(.barbell), .item(.flatBench)])),

        // Dumbbell

        // Cable
        ExerciseTemplateSpec(name: "Hammer Curl Kabel (Seil)",                  equipment: .cable,      primaryMuscle: .biceps,    localizationKey: "exercise.name.cableRopeHammerCurl"),
        ExerciseTemplateSpec(name: "Kabelzug Tiefrudern",                       equipment: .cable,      primaryMuscle: .back,      localizationKey: "exercise.name.cableLowRow"),
        ExerciseTemplateSpec(name: "Kabelzug Schulterdrücken",                  equipment: .cable,      primaryMuscle: .shoulders, localizationKey: "exercise.name.cableShoulderPress"),
        ExerciseTemplateSpec(name: "Kabelzug Rudern (stehend)",                 equipment: .cable,      primaryMuscle: .back,      localizationKey: "exercise.name.cableStandingRow"),
        ExerciseTemplateSpec(name: "Kabelzug Frontheben",                       equipment: .cable,      primaryMuscle: .shoulders, localizationKey: "exercise.name.cableFrontRaise"),
        ExerciseTemplateSpec(name: "Kabelzug Latissimus Strecken",              equipment: .cable,      primaryMuscle: .back,      localizationKey: "exercise.name.cableLatStretch"),
        ExerciseTemplateSpec(name: "Kabelzug Rudern EZ",                        equipment: .cable,      primaryMuscle: .back,      localizationKey: "exercise.name.cableEZRow"),

        // Bodyweight / Plyometrics
        ExerciseTemplateSpec(name: "3/4 Sit-Up",                                 equipment: .bodyweight, primaryMuscle: .core,      difficultyLevel: .beginner,    localizationKey: "exercise.name.threeQuarterSitUp"),

        // Kettlebell (Programm-Template-Referenzen)
    // ── NEU: 90 Übungen aus uebungen.txt + exercises-gifs ──────────────
        ExerciseTemplateSpec(name: "Kabelzug Flyes unten", equipment: .cable, primaryMuscle: .chest, localizationKey: "exercise.name.cableLowFly", equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Kabelzug Flyes stehend", equipment: .cable, primaryMuscle: .chest, localizationKey: "exercise.name.cableStandingFly", equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Liegestütz abwärts", equipment: .bodyweight, primaryMuscle: .chest, localizationKey: "exercise.name.declinePushUp", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Liegestütz aufwärts", equipment: .bodyweight, primaryMuscle: .chest, localizationKey: "exercise.name.inclinePushUp", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Dips Brust (Stange)", equipment: .bodyweight, primaryMuscle: .chest, localizationKey: "exercise.name.chestDipBar", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Dips weiter Griff (Brust)", equipment: .bodyweight, primaryMuscle: .chest, localizationKey: "exercise.name.wideGripChestDip", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Rudern einarmig vorgebeugt (LH)", equipment: .barbell, primaryMuscle: .back, localizationKey: "exercise.name.barbellOneArmBentOverRow", equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Latzug voll (Kabel)", equipment: .cable, primaryMuscle: .back, localizationKey: "exercise.name.cableLatPulldownFull", equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Latzug (Kabel)", equipment: .cable, primaryMuscle: .back, localizationKey: "exercise.name.cablePulldown", equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Klimmzug Supinationsgriff", equipment: .bodyweight, primaryMuscle: .back, localizationKey: "exercise.name.reverseGripPullUp", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "TRX Rudern", equipment: .bodyweight, primaryMuscle: .back, localizationKey: "exercise.name.suspendedRow", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Latzug vorn (Maschine)", equipment: .machine, primaryMuscle: .back, localizationKey: "exercise.name.leverFrontPulldown", equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Hyperextension", equipment: .bodyweight, primaryMuscle: .back, localizationKey: "exercise.name.hyperextension", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Smith Press stehend", equipment: .machine, primaryMuscle: .shoulders, localizationKey: "exercise.name.smithStandingMilitaryPress", equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Seitheben einarmig (KH)", equipment: .dumbbell, primaryMuscle: .shoulders, localizationKey: "exercise.name.dumbbellOneArmLateralRaise", equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Hinteres Seitheben (KH)", equipment: .dumbbell, primaryMuscle: .shoulders, localizationKey: "exercise.name.dumbbellRearFly", equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Reverse Flyes Schräg (KH)", equipment: .dumbbell, primaryMuscle: .shoulders, localizationKey: "exercise.name.dumbbellInclineRearLateralRaise", equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Einarmiges Overhead Carry (KH)", equipment: .dumbbell, primaryMuscle: .shoulders, localizationKey: "exercise.name.dumbbellSingleArmOverheadCarry", equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Reverse Flyes Maschine", equipment: .machine, primaryMuscle: .shoulders, localizationKey: "exercise.name.leverSeatedReverseFly", equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Bizeps-Curl alternierend (LH)", equipment: .barbell, primaryMuscle: .biceps, localizationKey: "exercise.name.barbellAlternateBicepsCurl", equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Bizeps-Curl Schräg vorgebeugt (LH)", equipment: .barbell, primaryMuscle: .biceps, localizationKey: "exercise.name.barbellProneInclineCurl", equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Bizeps-Curl alternierend (KH)", equipment: .dumbbell, primaryMuscle: .biceps, localizationKey: "exercise.name.dumbbellAlternateBicepsCurl", equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Bizeps-Curl sitzend (KH)", equipment: .dumbbell, primaryMuscle: .biceps, localizationKey: "exercise.name.dumbbellSeatedBicepCurl", equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Cross-Body Hammer Curl (KH)", equipment: .dumbbell, primaryMuscle: .biceps, localizationKey: "exercise.name.dumbbellCrossBodyHammerCurl", equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Skull Crusher enger Griff (LH)", equipment: .barbell, primaryMuscle: .triceps, localizationKey: "exercise.name.barbellSkullCrusherCloseGrip", equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Trizeps Overhead Extension sitzend (LH)", equipment: .barbell, primaryMuscle: .triceps, localizationKey: "exercise.name.barbellSeatedTricepsExtension", equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Trizeps Overhead Extension stehend (LH)", equipment: .barbell, primaryMuscle: .triceps, localizationKey: "exercise.name.barbellStandingTricepsExtension", equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Trizepsdrücken Stange (Kabel)", equipment: .cable, primaryMuscle: .triceps, localizationKey: "exercise.name.cablePushdownBar", equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Trizepsdrücken Seil (Kabel)", equipment: .cable, primaryMuscle: .triceps, localizationKey: "exercise.name.cablePushdownRope", equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Trizeps Overhead Seil (Kabel)", equipment: .cable, primaryMuscle: .triceps, localizationKey: "exercise.name.cableOverheadTricepsExtRope", equipmentRequirement: .item(.cableStation)),
        ExerciseTemplateSpec(name: "Trizeps Extension stehend (KH)", equipment: .dumbbell, primaryMuscle: .triceps, localizationKey: "exercise.name.dumbbellStandingTricepsExt", equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Skull Crusher (KH)", equipment: .dumbbell, primaryMuscle: .triceps, localizationKey: "exercise.name.dumbbellLyingTricepsExt", equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Handgelenk-Curl einarmig (KH)", equipment: .dumbbell, primaryMuscle: .biceps, localizationKey: "exercise.name.dumbbellOneArmWristCurl", equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Handgelenk-Roller", equipment: .bodyweight, primaryMuscle: .biceps, localizationKey: "exercise.name.wristRoller", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Kniebeuge tief (LH)", equipment: .barbell, primaryMuscle: .quads, localizationKey: "exercise.name.barbellFullSquat", equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Front-Kniebeuge Clean-Griff (LH)", equipment: .barbell, primaryMuscle: .quads, localizationKey: "exercise.name.barbellCleanGripFrontSquat", equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Walking Ausfallschritt", equipment: .bodyweight, primaryMuscle: .quads, localizationKey: "exercise.name.walkingLunge", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Split Squat", equipment: .bodyweight, primaryMuscle: .quads, localizationKey: "exercise.name.splitSquat", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Beinpresse 45°", equipment: .machine, primaryMuscle: .quads, localizationKey: "exercise.name.sled45LegPress", equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Beinpresse 45° weiter Stand", equipment: .machine, primaryMuscle: .quads, localizationKey: "exercise.name.sled45LegWidePress", equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Glute Bridge (auf Bank)", equipment: .bodyweight, primaryMuscle: .glutes, localizationKey: "exercise.name.gluteBridgeBench", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Einbeiniges Kreuzheben (KH)", equipment: .dumbbell, primaryMuscle: .hamstrings, localizationKey: "exercise.name.dumbbellSingleLegDeadlift", equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "Steifbeiniges Kreuzheben (LH)", equipment: .barbell, primaryMuscle: .hamstrings, localizationKey: "exercise.name.barbellStraightLegDeadlift", equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Overhead Kniebeuge (LH)", equipment: .barbell, primaryMuscle: .quads, localizationKey: "exercise.name.barbellOverheadSquat", equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Steifbeiniges Kreuzheben (KH)", equipment: .dumbbell, primaryMuscle: .hamstrings, localizationKey: "exercise.name.dumbbellStiffLegDeadlift", equipmentRequirement: .item(.dumbbell)),
        ExerciseTemplateSpec(name: "TRX Split Squat", equipment: .bodyweight, primaryMuscle: .quads, localizationKey: "exercise.name.suspendedSplitSquat", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Wadenheben (Stufe)", equipment: .bodyweight, primaryMuscle: .calves, localizationKey: "exercise.name.stairCaseCalfRaise", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Wadenpresse 45°", equipment: .machine, primaryMuscle: .calves, localizationKey: "exercise.name.sled45CalfPress", equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Wadenpresse Schrägpresse", equipment: .machine, primaryMuscle: .calves, localizationKey: "exercise.name.sledCalfPressLegPress", equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Wadenheben Esel", equipment: .bodyweight, primaryMuscle: .calves, localizationKey: "exercise.name.donkeyCalfRaise", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Dead Bug", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.deadBug", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Russian Twist (gewichtet)", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.weightedRussianTwist", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Beinheben gestreckt (hängend)", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.hangingStraightLegRaise", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Beinheben senkrecht (Dips-Stange)", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.verticalLegRaise", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Beinheben gestreckt (Stütz)", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.captainsChairStraightLegRaise", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Plank mit Rotation", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.frontPlankWithTwist", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Schräger Seitstütz", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.inclineSidePlank", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Plank (gewichtet)", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.weightedFrontPlank", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Crunch schräg", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.crossBodyCrunch", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Fahrradcrunch (Band)", equipment: .band, primaryMuscle: .core, localizationKey: "exercise.name.bandBicycleCrunch", equipmentRequirement: .item(.resistanceBand)),
        ExerciseTemplateSpec(name: "Jackknife Sit-up", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.jackknifeSitUp", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Rollout stehend", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.standingWheelRollout", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Rollout (LH)", equipment: .barbell, primaryMuscle: .core, localizationKey: "exercise.name.barbellRollout", equipmentRequirement: .item(.barbell)),
        ExerciseTemplateSpec(name: "Body Saw (Rolle)", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.rollerBodySaw", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Butt-Ups", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.buttUps", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Beinheben sitzend", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.seatedLegRaise", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Hängender Pike", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.hangingPike", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "TRX Fallout", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.suspendedAbdominalFallout", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Seilspringen", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.jumpRope", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Crosstrainer (Rad)", equipment: .machine, primaryMuscle: .core, localizationKey: "exercise.name.cycleCrossTrainer", equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Ergometer leicht", equipment: .machine, primaryMuscle: .core, localizationKey: "exercise.name.stationaryBikeWalk", equipmentRequirement: .item(.machineStation)),
        ExerciseTemplateSpec(name: "Bärenkrabbeln", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.bearCrawl", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Skater-Sprünge", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.skaterHops", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Hampelmann", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.starJump", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Knieheben an der Wand", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.highKneeAgainstWall", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Oberschenkel-Dehnung", equipment: .bodyweight, primaryMuscle: .hamstrings, localizationKey: "exercise.name.hamstringStretch", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Wadendehnung (an der Wand)", equipment: .bodyweight, primaryMuscle: .calves, localizationKey: "exercise.name.calfStretchWall", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Wadendehnung Schritt (an der Wand)", equipment: .bodyweight, primaryMuscle: .calves, localizationKey: "exercise.name.calfPushStretchWall", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Hüftbeuger-Dehnung (Ball)", equipment: .bodyweight, primaryMuscle: .quads, localizationKey: "exercise.name.hipFlexorStretchBall", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Lat-Dehnung (kniend)", equipment: .bodyweight, primaryMuscle: .back, localizationKey: "exercise.name.kneelingLatStretch", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Brust-Dehnung (Ball)", equipment: .bodyweight, primaryMuscle: .chest, localizationKey: "exercise.name.chestStretchBall", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Trizeps-Dehnung", equipment: .bodyweight, primaryMuscle: .triceps, localizationKey: "exercise.name.overheadTricepsStretch", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Nacken-Dehnung seitlich", equipment: .bodyweight, primaryMuscle: .back, localizationKey: "exercise.name.neckSideStretch", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Piriformis-Dehnung sitzend", equipment: .bodyweight, primaryMuscle: .glutes, localizationKey: "exercise.name.seatedPiriformisStretch", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Läufer-Dehnung", equipment: .bodyweight, primaryMuscle: .hamstrings, localizationKey: "exercise.name.runnersStretch", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Wirbelsäulen-Dehnung", equipment: .bodyweight, primaryMuscle: .core, localizationKey: "exercise.name.spineStretch", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Brust-Rücken-Dehnung", equipment: .bodyweight, primaryMuscle: .chest, localizationKey: "exercise.name.backPecStretch", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Brust-Dehnung hinter Kopf", equipment: .bodyweight, primaryMuscle: .chest, localizationKey: "exercise.name.behindHeadChestStretch", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Rücken-Dehnung sitzend", equipment: .bodyweight, primaryMuscle: .back, localizationKey: "exercise.name.seatedLowerBackStretch", equipmentRequirement: .all([])),
        ExerciseTemplateSpec(name: "Peroneus-Dehnung", equipment: .bodyweight, primaryMuscle: .calves, localizationKey: "exercise.name.peronealsStretch", equipmentRequirement: .all([])),

    ]

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
            .noEquipment: "Australian Pull-ups"
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
            .noEquipment: "Kniebeuge (BW)"
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
            .homeGym:     "Hip Thrust (BW)",
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
            .noEquipment: "Australian Pull-ups"
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
            .noEquipment: "Handtuch-Rudern (Türrahmen)"
        ],
        "Reverse Flys (Maschine)": [
            .homeGym:     "Reverse Flyes (KH)",
            .noEquipment: "Handtuch-Rudern (Türrahmen)"
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
            .homeGym:     "Hip Thrust (BW)",
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
            .noEquipment: "Australian Pull-ups"
        ],
        "Preacher Curls": [
            .homeGym:     "Konzentrations-Curl (KH)",
            .noEquipment: "Australian Pull-ups"
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
            .noEquipment: "Handtuch-Rudern (Türrahmen)"
        ],
        "Kabel Seitheben": [
            .homeGym:     "Seitheben",
            .noEquipment: "Pike Liegestütze"
        ],
        "Kabel Curl": [
            .homeGym:     "Hammer Curl",
            .noEquipment: "Australian Pull-ups"
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
            .noEquipment: "Handtuch-Rudern (Türrahmen)"
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
              let altSpec = all.first(where: { $0.name == altName }),
              isCompatible(altSpec, with: env)
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
        guard isEquipment(spec.equipment, compatibleWith: env) else { return false }
        // noEquipment hat keine Items — jede nicht-triviale equipmentRequirement schlägt fehl.
        if case .noEquipment = env, let req = spec.equipmentRequirement, req != .all([]) {
            return false
        }
        return true
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
