#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Seeds the `ExerciseTemplate` library with the canonical entries from
/// `ExerciseLibraryData`. Idempotent: skips if any template already exists.
///
/// Called from `RootView.task` on every app launch (cheap — one fetch-count
/// query), from the onboarding as a safety net and right after "App
/// zuruecksetzen" (which deletes all templates). New users get the full
/// library on first start; existing users with hand-added custom templates
/// aren't disturbed.
@MainActor
public enum LibrarySeeder {

    /// Returns true if the library was actually seeded (was empty before),
    /// false if it was already populated.
    ///
    /// DEL-190: Idempotenz-Check zählt NUR System-Templates
    /// (`isCustom == false`). Vorher wurde `FetchDescriptor<ExerciseTemplate>()`
    /// ohne Predicate verwendet — also ALLE Templates inkl. Custom. Effekt:
    /// sobald der User eine eigene Übung anlegt (oder via Daten-Import 3
    /// Custom-Templates reinkommen), ist `existing > 0` und der Seeder
    /// verweigert das Seeding der System-Library für immer. Resultat: leere
    /// "Übungsbibliothek" bis auf die Custom-Einträge. Mit dem Predicate
    /// re-seedet der Seeder die System-Library, sobald sie fehlt — Custom-
    /// Templates blockieren das nicht mehr.
    @discardableResult
    public static func seedIfNeeded(in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<ExerciseTemplate>(
            predicate: #Predicate { $0.isCustom == false }
        )
        // Bugfix (Geraetetest): ein fehlgeschlagener Fetch (`try?` → nil →
        // `?? 0`) wurde bisher wie "Bibliothek ist leer" behandelt und hat
        // bei JEDEM App-Start die komplette ~229-Eintraege-Library erneut
        // eingefuegt — sichtbar als 8-fache Dubletten nach 8 Starts. Ein
        // echter Fetch-Fehler darf niemals als "leer" interpretiert werden;
        // im Zweifel nichts tun, der naechste Start versucht es erneut.
        let existing: Int
        do {
            existing = try context.fetchCount(descriptor)
        } catch {
            return false
        }
        guard existing == 0 else { return false }

        for spec in ExerciseLibraryData.all {
            let template = ExerciseTemplate(
                name: spec.name,
                equipment: spec.equipment,
                primaryMuscle: spec.primaryMuscle,
                isCustom: false,
                difficultyLevel: spec.difficultyLevel,
                isSystemCompound: spec.isSystemCompound,
                isTimeBased: spec.isTimeBased,
                // DEL-080: Cardio-Flag aus Spec propagieren, sodass Ad-Hoc-
                // Cardio-Einheiten (Freier Lauf, Radfahren, ...) korrekt
                // klassifiziert in den Picker landen.
                isCardio: spec.isCardio,
                // DEL-098: Belastungsfaktoren aus der Spec uebernehmen,
                // sodass der spaetere Recovery-Score schon vom ersten
                // Workout an mit sinnvollen Werten rechnen kann.
                systemicFatigueFactor: spec.systemicFatigueFactor,
                localMuscleDamageFactor: spec.localMuscleDamageFactor,
                cnsDemandFactor: spec.cnsDemandFactor,
                axialLoadFactor: spec.axialLoadFactor,
                technicalComplexityFactor: spec.technicalComplexityFactor,
                recoveryClass: spec.recoveryClass,
                // DEL-111: i18n-Lookup-Key + isSystemProvided-Flag.
                // Beide propagieren aus der Spec — Library-Eintraege
                // mit annotiertem Key bekommen multilinguale Anzeige,
                // alle anderen fallen auf das deutsche `name` zurueck.
                localizationKey: spec.localizationKey,
                isSystemProvided: true
            )
            context.insert(template)
        }
        return true
    }

    /// README 2.35: One-Shot-Backfill fuer NEUE System-Library-Eintraege.
    ///
    /// `seedIfNeeded` seedet nur ein KOMPLETT leeres System-Library-Set
    /// (siehe dortiger Kommentar) - jeder Bestandsnutzer, der die App schon
    /// vor einem neu hinzugekommenen `ExerciseLibraryData.all`-Eintrag
    /// gestartet hat, bekommt diesen neuen Eintrag NIE in die persistierte
    /// `ExerciseTemplate`-Tabelle. `ExerciseLibraryPickerSheet`/
    /// `ExerciseLibraryView` fragen aber genau diese Tabelle ab (nicht
    /// `ExerciseLibraryData.all` direkt) - ohne diesen Backfill waere ein
    /// neuer Eintrag fuer alle Bestandsnutzer dauerhaft unsichtbar im
    /// Picker. Konkreter Ausloeser: die "Lauf-Intervall"/"Rad-Intervall"-
    /// Eintraege aus README 2.35 (Ad-Hoc-Zeitformat-Start, 43b) - generisch
    /// gehalten, damit jede kuenftige Library-Erweiterung automatisch
    /// nachzieht, statt denselben Bug bei der naechsten neuen Uebung zu
    /// wiederholen.
    ///
    /// Strategie: Diff zwischen `ExerciseLibraryData.all`-Namen und den
    /// bereits persistierten System-Template-Namen (`isCustom == false`);
    /// jeder fehlende Name wird als neues `ExerciseTemplate` nachgezogen -
    /// identischer Konstruktions-Code wie `seedIfNeeded`s Schleife.
    ///
    /// Idempotent: nach dem ersten erfolgreichen Pass ist die Differenzmenge
    /// leer, der Fetch bleibt aber (wie bei den anderen Backfills) guenstig
    /// genug fuer jeden App-Start. Auf einem frischen Install laeuft
    /// `seedIfNeeded` VOR diesem Aufruf und hat bereits alle Namen inseriert,
    /// die Differenzmenge ist dann ebenfalls leer.
    ///
    /// Returns: Anzahl der nachgezogenen Eintraege.
    @discardableResult
    public static func backfillNewLibraryEntriesIfNeeded(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<ExerciseTemplate>(
            predicate: #Predicate { $0.isCustom == false }
        )
        // Bugfix (Geraetetest): wie bei `seedIfNeeded` — ein fehlgeschlagener
        // Fetch darf nicht als "keine Namen vorhanden" gelten, sonst wuerde
        // JEDER Library-Eintrag faelschlich als "fehlt noch" erneut eingefuegt.
        let existingTemplates: [ExerciseTemplate]
        do {
            existingTemplates = try context.fetch(descriptor)
        } catch {
            return 0
        }
        let existingNames = Set(existingTemplates.map(\.name))

        var updated = 0
        for spec in ExerciseLibraryData.all where !existingNames.contains(spec.name) {
            let template = ExerciseTemplate(
                name: spec.name,
                equipment: spec.equipment,
                primaryMuscle: spec.primaryMuscle,
                isCustom: false,
                difficultyLevel: spec.difficultyLevel,
                isSystemCompound: spec.isSystemCompound,
                isTimeBased: spec.isTimeBased,
                isCardio: spec.isCardio,
                systemicFatigueFactor: spec.systemicFatigueFactor,
                localMuscleDamageFactor: spec.localMuscleDamageFactor,
                cnsDemandFactor: spec.cnsDemandFactor,
                axialLoadFactor: spec.axialLoadFactor,
                technicalComplexityFactor: spec.technicalComplexityFactor,
                recoveryClass: spec.recoveryClass,
                localizationKey: spec.localizationKey,
                isSystemProvided: true
            )
            context.insert(template)
            updated += 1
        }
        return updated
    }

    /// Bugfix (Geraetetest nach Settings-Epic Phase 6): behebt bereits
    /// entstandene Dubletten. `seedIfNeeded`/`backfillNewLibraryEntriesIfNeeded`
    /// interpretierten einen fehlgeschlagenen Fetch bisher faelschlich als
    /// "Bibliothek leer/Eintrag fehlt" und fuegten die komplette System-
    /// Library bei JEDEM App-Start erneut ein — auf einem betroffenen Geraet
    /// sichtbar als z.B. 8-fach wiederholtes "Bankdruecken" in der
    /// Uebungsbibliothek. Diese Migration raeumt den entstandenen Bestand auf,
    /// unabhaengig davon ob die Ursache (oben) schon behoben ist.
    ///
    /// Gruppiert alle System-Templates (`isCustom == false`) case-insensitiv
    /// nach `name` und behaelt pro Gruppe genau EINEN Eintrag — bevorzugt
    /// den mit gesetztem `localizationKey` (deterministische Wahl, falls sich
    /// Duplikate je unterscheiden sollten; im Normalfall sind alle Kopien
    /// identisch, da sie aus derselben `ExerciseLibraryData`-Spec stammen).
    /// Custom-Templates (`isCustom == true`) sind nie betroffen — Nutzer
    /// koennen bewusst mehrere eigene Uebungen mit gleichem Namen anlegen.
    ///
    /// Sicher bzgl. bestehender Referenzen: `Exercise`/`ExerciseLog`/
    /// `PersonalRecordEntry` speichern `exerciseTemplateID` als reinen
    /// UUID-Scalar-Wert (KEIN `@Relationship`, siehe `ExerciseTemplate.id`-
    /// Dokumentation) — PR-/Verlaufs-Gruppierung vergleicht nur diesen
    /// gespeicherten Wert, ohne die lebende `ExerciseTemplate`-Zeile erneut
    /// aufzuloesen. Loeschen ueberzaehliger Duplikate kann also keine
    /// bestehende Historie brechen. Sollte eine bereits adoptierte Exercise
    /// zufaellig auf die ID eines geloeschten Duplikats zeigen, heilt
    /// `ExerciseTemplateIDBackfill.runIfNeeded` das beim naechsten Lauf
    /// automatisch (Konsistenz-Check dort).
    ///
    /// Idempotent: nach dem ersten Durchlauf hat jede Namensgruppe genau
    /// einen Eintrag, der Gruppierungs-Schritt findet dann nichts mehr.
    ///
    /// Returns: Anzahl der geloeschten Duplikate.
    @discardableResult
    public static func deduplicateTemplatesIfNeeded(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<ExerciseTemplate>(
            predicate: #Predicate { $0.isCustom == false }
        )
        let systemTemplates: [ExerciseTemplate]
        do {
            systemTemplates = try context.fetch(descriptor)
        } catch {
            return 0
        }
        guard systemTemplates.count > 1 else { return 0 }

        var byName: [String: [ExerciseTemplate]] = [:]
        for template in systemTemplates {
            byName[template.name.lowercased(), default: []].append(template)
        }

        var removed = 0
        for group in byName.values where group.count > 1 {
            // Mit gesetztem localizationKey zuerst — deterministisch, falls
            // sich Duplikate je unterscheiden sollten.
            let sorted = group.sorted { lhs, rhs in
                (lhs.localizationKey != nil ? 0 : 1) < (rhs.localizationKey != nil ? 0 : 1)
            }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                removed += 1
            }
        }
        return removed
    }

    /// DEL-051: One-Shot-Backfill der Snapshot-Felder auf vorhandenen
    /// `ExerciseLog`-Eintraegen. Bestand aus den Pre-DEL-051-Versionen hat
    /// `exerciseNameSnapshot == nil` — `resolvedExerciseName` fallback'ed
    /// zwar auf `log.exercise?.name`, aber sobald eine Plan-Uebung jemals
    /// geloescht/getauscht wird, sind die Logs ohne Live-Referenz orphan
    /// UND ohne Snapshot. Dieser Pass schreibt die Snapshots EINMALIG auf
    /// alle bestehenden Logs nach, solange die Exercise noch da ist.
    ///
    /// Idempotent: ueberspringt Logs, die bereits einen Snapshot tragen, und
    /// orphan-Logs ohne erreichbare Exercise. Wird einmal pro App-Launch
    /// aus `RootView.task` aufgerufen — cheap genug, der FetchDescriptor
    /// erlaubt einen Filter auf nil-Snapshot, sodass der Bulk-Run nach dem
    /// ersten erfolgreichen Backfill leer durchlaeuft.
    ///
    /// Returns: Anzahl der nachgezogenen Eintraege (fuer Logging/Telemetry).
    @discardableResult
    public static func backfillLogSnapshotsIfNeeded(in context: ModelContext) -> Int {
        let pendingDescriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate { $0.exerciseNameSnapshot == nil }
        )
        let pending = (try? context.fetch(pendingDescriptor)) ?? []
        var updated = 0
        for log in pending {
            guard let exercise = log.exercise else { continue }
            log.exerciseNameSnapshot       = exercise.name
            log.exerciseIsCardioSnapshot   = exercise.isCardio
            log.exerciseIsTimeBasedSnapshot = exercise.isTimeBased
            updated += 1
        }
        return updated
    }

    /// DEL-123: One-Shot-Backfill der `localizationKey`-Felder auf vorhandenen
    /// `TrainingPlan` + `TrainingDay`-Eintraegen. Pre-DEL-123-Daten haben den
    /// Key nicht — die Plan-Listen zeigen deutsche Strings im EN/TR-Modus.
    ///
    /// Strategie: konservatives Matching ueber `plan.programType` -> Template-
    /// Lookup. Nur wenn `plan.name` noch exakt der Template-DE-Name ist
    /// (also der User den Plan NICHT manuell umbenannt hat), schreiben wir
    /// den `localizationKey` rein. User-Custom-Renamen bleiben unangetastet
    /// und rendern weiter den User-getippten String.
    ///
    /// Day-Level: das gleiche Muster ueber `day.name == daySpec.name`. Rest-
    /// Tage (type == .rest mit Auto-Erzeugung) bekommen pauschal
    /// `day.restDay.title` falls sie noch den deutschen Default tragen.
    ///
    /// Idempotent: ueberspringt alle Plaene + Tage, die bereits einen Key
    /// tragen. Bei einem Cold-Start nach der ersten erfolgreichen Migration
    /// laeuft die Funktion praktisch leer durch.
    ///
    /// Returns: Anzahl der gesetzten Plan-Keys (Day-Updates implizit).
    @discardableResult
    public static func backfillPlanLocalizationKeysIfNeeded(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<TrainingPlan>(
            predicate: #Predicate { $0.localizationKey == nil }
        )
        let pending = (try? context.fetch(descriptor)) ?? []
        guard !pending.isEmpty else { return 0 }

        // Templates per programType-ID indexieren — O(1)-Lookup fuer den
        // typischen Fall (geadoptierte System-Templates).
        let templatesByID = Dictionary(
            uniqueKeysWithValues: ProgramTemplates.all.map { ($0.id, $0) }
        )

        var updated = 0
        for plan in pending {
            guard let template = templatesByID[plan.programType] else {
                continue   // Custom-Plan ohne Template-Origin — Skip
            }
            // Konservatives Match: nur wenn der User den Plan-Namen NICHT
            // veraendert hat, propagieren wir den localizationKey.
            // Custom-Rename ist erkennbar daran, dass plan.name vom
            // Template-Default abweicht.
            guard plan.name == template.name else { continue }
            plan.localizationKey = template.localizationKey
            updated += 1

            // DaySpec-Index aufbauen und Tag-Namen matchen
            let daySpecsByName = Dictionary(
                uniqueKeysWithValues: template.days.map { ($0.name, $0) }
            )
            for day in plan.days where day.localizationKey == nil {
                if day.type == .rest && day.name == "Ruhetag" {
                    day.localizationKey = "day.restDay.title"
                } else if let spec = daySpecsByName[day.name] {
                    day.localizationKey = spec.localizationKey
                }
            }
        }
        return updated
    }

    /// DEL-125: One-Shot-Backfill der `customName`-Felder auf SwiftData-Modellen.
    ///
    /// Pre-DEL-125 wurde der USER-Override direkt ins `name`-Feld geschrieben.
    /// Dadurch haben User-renamte Eintraege ihren custom Wert in `name` —
    /// gleichzeitig stoert das die Library/Template-Lookup-Logik, die ueber
    /// den deutschen System-Namen matcht.
    ///
    /// Strategie: konservativer Sweep. Pro Modell wird gecheckt, ob `name`
    /// dem System-Default entspricht. Wenn ja → nichts tun (User hat nicht
    /// umbenannt). Wenn nein → User hat umbenannt → `customName = name`
    /// setzen. `name` bleibt wie es ist (kein Restore moeglich ohne den
    /// urspruenglichen Template-Wert zu kennen, aber das ist OK — der
    /// Library-Lookup fuer Custom-Names schlaegt sowieso fehl und faellt
    /// zurueck auf raw name; mit customName-Override wird das nie sichtbar).
    ///
    /// Idempotent: filtert auf `customName == nil`. Nach erstem Erfolg leer.
    ///
    /// Returns: Anzahl der Eintraege mit gesetztem customName (Exercise +
    /// Plan + Day insgesamt).
    @discardableResult
    public static func backfillCustomNamesIfNeeded(in context: ModelContext) -> Int {
        var updated = 0

        // ─── Exercises ───────────────────────────────────────────────
        let libraryNames = Set(ExerciseLibraryData.all.map { $0.name })
        let exDescriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.customName == nil }
        )
        let pendingExercises = (try? context.fetch(exDescriptor)) ?? []
        for exercise in pendingExercises {
            // System-Default = jeder Name, der im Library-Katalog steht.
            // Wenn der Name NICHT in der Library ist, hat der User entweder
            // umbenannt ODER eine Custom-Uebung selbst angelegt — beide Faelle
            // sollen ihren Namen in customName festhalten.
            if !libraryNames.contains(exercise.name) {
                exercise.customName = exercise.name
                updated += 1
            }
        }

        // ─── Plans ───────────────────────────────────────────────────
        let templatesByID = Dictionary(
            uniqueKeysWithValues: ProgramTemplates.all.map { ($0.id, $0) }
        )
        let planDescriptor = FetchDescriptor<TrainingPlan>(
            predicate: #Predicate { $0.customName == nil }
        )
        let pendingPlans = (try? context.fetch(planDescriptor)) ?? []
        for plan in pendingPlans {
            let isSystemDefault: Bool = {
                guard let template = templatesByID[plan.programType] else {
                    // Custom-Plan ohne Template-Origin: nur der noch
                    // unbenannte Leer-Plan traegt einen System-Namen. Ohne
                    // diese Ausnahme wuerde sein deutscher Name beim naechsten
                    // Start als `customName` festgeschrieben und der
                    // Katalog-Schluessel waere wirkungslos.
                    return plan.localizationKey == TrainingPlan.blankPlanLocalizationKey
                        && plan.name == TrainingPlan.blankPlanName
                }
                return plan.name == template.name
            }()
            if !isSystemDefault {
                plan.customName = plan.name
                updated += 1
            }
        }

        // ─── Days ────────────────────────────────────────────────────
        let dayDescriptor = FetchDescriptor<TrainingDay>(
            predicate: #Predicate { $0.customName == nil }
        )
        let pendingDays = (try? context.fetch(dayDescriptor)) ?? []
        for day in pendingDays {
            // System-Defaults sind die DaySpec-Namen aus dem Template +
            // unser Auto-Rest-Day "Ruhetag". Alles andere ist Custom.
            let isSystemDefault: Bool = {
                if day.type == .rest && day.name == "Ruhetag" { return true }
                guard let plan = day.plan,
                      let template = templatesByID[plan.programType] else { return false }
                return template.days.contains { $0.name == day.name }
            }()
            if !isSystemDefault {
                day.customName = day.name
                updated += 1
            }
        }

        return updated
    }

    /// DEL-150: One-Shot-Backfill fuer spontane (ad-hoc) Workouts.
    ///
    /// Vor DEL-150 wurde der ephemere `TrainingDay` einer spontanen Session
    /// mit hartcodiertem DE-`name` ("Spontanes Workout") und OHNE
    /// `localizationKey` angelegt. Folge: im Trainingsverlauf erschien der
    /// Titel auf TR/EN-iPhones weiterhin deutsch (z.B. "Spontanes Workout"
    /// statt "Anlık Antrenman").
    ///
    /// Strategie: fuer jede ad-hoc-Session mit lebender Day-Reference ohne
    /// `localizationKey` wird `session.adHoc.dayName` gesetzt, sodass
    /// `TrainingDay.displayName` den Key in die aktuelle Locale resolved.
    /// Zusaetzlich wird der stale `dayName`-Snapshot genullt — die
    /// Day-Reference ist die Source-of-Truth fuer den Titel, und wenn der Day
    /// jemals nullified wird, soll der generische i18n-Fallback greifen statt
    /// des eingefrorenen deutschen Strings.
    ///
    /// Der Name-Guard ("Spontanes Workout"/"Spontanes Training") schuetzt
    /// gegen versehentliches Ueberschreiben — ad-hoc-Tage tragen immer einen
    /// dieser Auto-Defaults.
    ///
    /// Idempotent: filtert auf `day.localizationKey == nil`. Nach dem ersten
    /// erfolgreichen Pass laeuft die Funktion leer durch.
    ///
    /// Returns: Anzahl der reparierten Sessions.
    @discardableResult
    public static func backfillAdHocDayLocalizationIfNeeded(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isAdHoc == true }
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        var updated = 0
        for session in sessions {
            guard let day = session.day, day.localizationKey == nil else { continue }
            if day.name == "Spontanes Workout" || day.name == "Spontanes Training" {
                day.localizationKey = "session.adHoc.dayName"
                session.dayName = nil
                updated += 1
            }
        }
        return updated
    }

    /// DEL-163: One-Shot-Backfill der Custom-Exercise-Metadaten. Vor DEL-163
    /// kopierte der Adopt-Pfad (`addExercise(from:)`) Muskel + Equipment NICHT
    /// vom Template auf die `Exercise` — bereits adoptierte Custom-Uebungen
    /// haben daher `primaryMuscleRaw == nil` und fallen im Editor auf
    /// Brust/Koerpergewicht zurueck.
    ///
    /// Strategie: jede Exercise ohne Muskel-Override mit einem passenden
    /// CUSTOM-Template (Match ueber Name) bekommt Muskel + Equipment aus dem
    /// Template nachgezogen. System-Uebungen (kein Custom-Template-Match)
    /// bleiben unangetastet — sie loesen ihren Muskel ueber den Library-Lookup.
    ///
    /// Idempotent: filtert auf `primaryMuscleRaw == nil`. Nach erstem Erfolg
    /// laeuft die Funktion leer durch.
    @discardableResult
    public static func backfillCustomExerciseMetadataIfNeeded(in context: ModelContext) -> Int {
        let exDescriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.primaryMuscleRaw == nil }
        )
        let pending = (try? context.fetch(exDescriptor)) ?? []
        guard !pending.isEmpty else { return 0 }

        let tplDescriptor = FetchDescriptor<ExerciseTemplate>(
            predicate: #Predicate { $0.isCustom == true }
        )
        let customTemplates = (try? context.fetch(tplDescriptor)) ?? []
        guard !customTemplates.isEmpty else { return 0 }
        let byName = Dictionary(
            customTemplates.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var updated = 0
        for exercise in pending {
            guard let template = byName[exercise.name] else { continue }
            exercise.primaryMuscleRaw = template.primaryMuscle.rawValue
            exercise.equipmentRaw = template.equipment.rawValue
            updated += 1
        }
        return updated
    }
}
#endif
