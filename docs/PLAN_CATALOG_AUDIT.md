# Plan-Katalog-Audit: Eignung und Equipment

Vollständige, lokale Prüfung aller 20 `ProgramTemplates.all`-Einträge (eine frühere externe Durchsicht wurde bei ca. 20.000 Zeichen abgeschnitten und bewertete dadurch nur 6 von 20 Templates vollständig). Die Rohdaten (jede Übung jedes Templates, gejoint gegen `ExerciseLibraryData.all` für Equipment/Muskelgruppe) wurden per Swift-Testlauf empirisch aus dem kompilierten Code gedumpt, nicht von Hand aus dem Quelltext abgetippt — 0 von 102 referenzierten Übungsnamen blieben beim Abgleich unmatched.

## Methodik und Annahmen

- **Arbeitssätze**: nur `role == .workingSet` und `isCardio == false`. Warmup-/Cooldown-Sätze und Cardio-Finisher werden getrennt ausgewiesen.
- **Zeitformat-Tage (AMRAP/EMOM/Circuit/Auf Zeit)**: Die deklarierte `sets`-Zahl pro Übung ist dort eine UI-Konvention (oft = Rundenzahl), **kein** reales Satzmaß. Direkte-Sätze-pro-Muskelgruppe wird deshalb **nur für klassische Satz/Wiederholungs-Tage** berechnet; Zeitformat-Tage werden separat als 'berührte Muskelgruppen' ausgewiesen, ohne Satzzahl.
- **Dauer-Schätzung** (transparent, nicht gemessen):
  - Klassischer Satz: 40s Time-under-Tension + die angegebene restSeconds, je Satz (klassische Satz/Wiederholungs-Tage).
  - AMRAP/EMOM: die hinterlegte `timeCapMinutes`.
  - Auf Zeit ohne Deckel: Annahme 12 Minuten.
  - Circuit: Runden × (Übungen/Runde × 30s + Pause zwischen Runden).
  - Cardio-Finisher ohne Zieldauer: Annahme 10 Minuten.
  - **Diese Zahlen sind Untergrenzen** — reale CrossFit/Kettlebell-Komplex-Sessions enthalten zusätzlich Aufwärmen/Skill-Arbeit, die in den Templates nicht als eigene Übungszeilen modelliert ist.
- **Technische Anforderungen**: `ExerciseTemplateSpec.isSystemCompound` markiert bewusst nur die 5 kanonischen Barbell-Lifts (Kniebeuge, Bankdrücken, Kreuzheben, Schulterdrücken stehend, Rudern vorgebeugt) — andere anspruchsvolle Bewegungen (Front Squat, RDL, Nordic Curls, Kettlebell-Snatch, …) sind NICHT in diesem Flag enthalten und wurden für die Eignungs-Einschätzung zusätzlich händisch geprüft.
- **Muskelgruppen**: `ExerciseTemplateSpec` modelliert nur EINE `primaryMuscle` je Übung — es gibt **keine** sekundäre/indirekte Muskelgruppe im Datenmodell. Indirekte Beteiligung (z. B. vordere Schulter/Trizeps bei Druckübungen) ist unten nur dort erwähnt, wo sie für die Eignungs-Einschätzung relevant ist, und ist fachliche Einordnung meinerseits, nicht aus dem Code abgeleitet.
- **Equipment-Modell-Lücke**: `Equipment` kennt kein 'braucht eine (Schräg-)Bank', 'braucht eine Klimmzugstange/Türrahmen' oder 'braucht Dip-Barren' — ein Dumbbell-Flachbankdrücken ist nur als `equipment: .dumbbell` getaggt, obwohl es physisch eine Bank voraussetzt. Das betrifft die Red Flags zu `home_gym_hero` und `bodyweight_mastery` unten.
- Kategorien je Track/Ziel: ✅ geeignet · 🟡 nur angepasst · ⛔ nicht automatisch empfehlen.

## Red-Flag-Befunde (verifiziert)

| # | Template | Befund | Status |
|---|---|---|---|
| 1 | `full_body` | 5 freie Compound-Lifts (Kniebeuge, Bankdrücken, **konventionelles Kreuzheben**, stehendes Schulterdrücken, Rudern vorgebeugt), 16 Arbeitssätze/Einheit. Kein vereinfachter Anfängerplan — Technikaufwand in 5 Bewegungen gleichzeitig. | **Bestätigt** |
| 2 | `fat_loss_fullbody` | 16 Arbeitssätze + 1 Cardio-Finisher je Einheit (~49 Min./Session). Realistisch nur mit Anpassung für echte Anfänger/Wiedereinsteiger. 'Abnehmen' korrekt als eigenständiges Ziel (nicht Split-Typ) umgesetzt — ein Hypertrophie-Split im Defizit ist ebenso denkbar, siehe Matcher-Abschnitt. | **Bestätigt** |
| 3 | `home_gym_hero` | Equipment-Tag ist durchgehend `dumbbell`, ABER 'Bankdrücken (KH)', 'Schrägbankdrücken aufwärts (KH)' und 'Flyes flach (KH)' setzen physisch eine Flach-/Schrägbank voraus — im `Equipment`-Enum nicht abbildbar. 'Kein Fitnessstudio nötig' verschweigt das. | **Bestätigt** |
| 4 | `bodyweight_mastery` | Eigene Beschreibung sagt 'ohne ein einziges Gerät', enthält aber 'Handtuch-Rudern (Türrahmen)' (braucht einen tragfähigen Türrahmen) und 'Dips (Trizeps)' (braucht Dip-Barren/vergleichbaren Aufbau). | **Bestätigt** |
| 5 | `upper_lower` | Schwere 3-5-Wiederholungsbereiche (Kniebeuge, Kreuzheben) plus Nordic Curls (fortgeschrittene Hamstring-Übung, braucht Fixierung/Partner). `targetExperience` korrekt `[intermediate, advanced]` ohne `beginner` — der Matcher lässt es trotzdem für Starter durch, siehe Matcher-Abschnitt. | **Bestätigt** |
| 6 | `push_pull_legs` | 119 Arbeitssätze/Woche über 6 Tage, 20 direkte Sätze/Woche für Rücken/Schultern — oberes Ende selbst für Intermediate. Beschreibung: 'Wissenschaftlich optimierter Split… ideal für intermediäre Sportler laut Meta-Analysen' — unbelegter Alleinstellungs-/Autoritätsverweis. | **Bestätigt** |
| 7 | `arnold_split` | Korrekt `targetExperience: [advanced]` ohne andere Stufe — Matcher-Hartfilter funktioniert hier bereits richtig. Der pauschale `templateScoreBonus`-Tage-Bonus (`max(0, daysPerWeek-3)`) bevorzugt es zusätzlich nur wegen 6 Tagen, nicht wegen Inhalt — siehe Matcher-Abschnitt. | **Teilweise bestätigt** (Tag korrekt, Scoring-Mechanik fragwürdig) |
| 8 | Übertreibungen in Beschreibungen | `full_body` ('Laut Forschung optimal… maximales Signal'), `push_pull_legs` ('wissenschaftlich optimiert… laut Meta-Analysen'), `upper_lower` ('der effektivste Split'), `powerlifting_5x5` ('Das bewährteste… wissenschaftlich und praktisch belegt') — vier Templates mit unbelegten Superlativen/Autoritätsverweisen in DE-Beschreibungen (EN/TR vermutlich spiegelbildlich, siehe TRANSLATIONS.md separat prüfen). | **Bestätigt (4 von 20 Templates)** |

## Matcher-Regel-Befunde (`PlanMatchmaker.swift`, verifiziert durch Quelltextlesung)

1. **`equipmentMatches` lässt 17 von 20 Templates equipment-ungeprüft durch.** `guard let variants = template.equipmentVariants else { return true }` — nur die 3 `hybrid_*`-Templates haben `equipmentVariants`; die anderen 17 (inkl. `push_pull_legs`, `upper_lower`, `arnold_split`, `bro_split`, `powerlifting_5x5/3x5`, die zusammen 24-44 Barbell-Sätze/Woche benötigen) werden **unabhängig von den tatsächlichen `equipmentPreferences`** als passend akzeptiert, solange die Environment-Stufe passt. Reproduzierbar: Gym + nur `.machine`/`.cable` in `equipmentPreferences` → `push_pull_legs` besteht den Filter trotzdem.
2. **`matchReasons.equipmentMatch` ist nur `!equipmentPreferences.isEmpty`.** Das Badge 'Equipment passend' zeigt für JEDES bestandene Template an, sobald der Nutzer überhaupt irgendeine Equipment-Präferenz gepflegt hat — unabhängig davon, ob DIESES Template dazu passt. In Kombination mit Befund 1 kann das Badge für einen Barbell-Plan erscheinen, obwohl der Nutzer nur Maschinen angegeben hat.
3. **`experienceTrackMatches` lässt reine Intermediate-Pläne für Starter/Returner durch.** Filter: `targetExperience.contains(.beginner) || .contains(.intermediate)`. `push_pull_legs`, `upper_lower`, `bro_split`, `powerlifting_3x5` und `kettlebell_complexes` tragen `[intermediate, advanced]` bzw. `[intermediate, ...]` OHNE `.beginner` — sie bestehen den Starter/Returner-Filter trotzdem, weil `.intermediate` allein reicht. `push_pull_legs` (119 Sätze/Woche, 6 Tage, 5 freie Compounds) kann so aktuell einem echten Anfänger vorgeschlagen werden.
4. **`fallback` prüft weder `preferredDays` noch garantiert den Track-Filter.** Der Fallback-Pfad filtert nur auf `targetEnvironment == .noEquipment` + optional Track, ignoriert aber `daysPerWeek <= preferredDays` komplett — ein Nutzer mit '2 Tage max.' kann im Fallback ein 3-Tage-Template zurückbekommen. Zusätzlich fällt die Track-Filterung bei leerem Ergebnis auf die KOMPLETT ungefilterte Bodyweight-Liste zurück (`filtered.isEmpty ? bodyweight : filtered`), die `crossfit_bodyweight_rx` (rein `advanced`) enthält — ein schmales, aber reales Fenster für einen stillen Experten-Fallback an einen Starter.
5. **`ExperienceTrack.templateScoreBonus` belohnt Tage pauschal statt inhaltlich.** `max(0, daysPerWeek - 3)` bevorzugt JEDES Template mit mehr als 3 Tagen gleich stark, unabhängig vom Inhalt — ein inhaltlich passender 4-Tage-Split bekommt denselben Bonus wie ein technisch anspruchsvoller 6-Tage-Split. Der separate `.advanced`-Tag-Bonus (+1) ist dagegen inhaltlich begründet (gleicht aus, dass Erfahrene nie auf `.advanced` über `asExperienceLevel` gemappt werden) und sollte bestehen bleiben.
6. **Ziel-Unterstützung vs. Primärfokus nicht getrennt.** `fat_loss_fullbody` ist aktuell das einzige Template mit `targetGoals: [weightLoss, ...]` außer den CrossFit/Kettlebell-Programmen — ein Hypertrophie-Split im Kaloriendefizit (z. B. `upper_lower`) wäre für `weightLoss` ebenso geeignet, wird aber nicht gefunden, weil das Scoring rein auf `targetGoals.contains(answers.goal)` basiert statt Ziel-Unterstützung vs. Primärfokus zu unterscheiden.

## Pro-Template-Bewertung

Vollständige Rohdaten (Equipment-Zählung, Muskelgruppen-Sätze, Dauer) in `docs/PLAN_CATALOG_AUDIT.csv`. Hier nur Kernzahlen + Eignungs-Matrix.

### `full_body` — Ganzkörper 3x

3 Tage/Woche · gym · Tags: beginner, intermediate / hypertrophy, functional

**48 Arbeitssätze/Woche** (~16/Session), RIR 2.0–2.0, geschätzt **118 Min./Woche** (~39 Min./Session). Direkte Sätze/Woche je Muskelgruppe: back 12, shoulders 9, quads 6, chest 6, biceps 6, triceps 6, glutes 3.

Equipment: barbell (9×), dumbbell (5×), cable (2×), machine (1×), bodyweight (1×) · Kanonische Compounds: Bankdrücken, Kniebeuge, Kreuzheben (konventionell), Rudern vorgebeugt, Schulterdrücken (stehend)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ⛔ nicht automatisch empfehlen | 5 freie Compound-Lifts (inkl. konv. Kreuzheben, stehendes Drücken) gleichzeitig, 16 Arbeitssätze/Einheit — Technikaufwand für echte Anfänger zu hoch für eine automatische Top-Empfehlung. |
| Returner | 🟡 nur angepasst | Technik ggf. vorhanden, aber nach Pause gehört eine Lastrampe davor, kein sofortiges volles Arbeitsgewicht/Volumen. |
| Intermediate | ✅ geeignet | Klassischer, gut dosierter Ganzkörperplan. |
| Advanced | 🟡 nur angepasst | Strukturell unproblematisch, aber nur 3 Tage/einfache Progression — für echte Fortgeschrittene meist unterstimulierend. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | 🟡 nur angepasst | Reps 4-8, kein reiner Maximalkraft-Fokus. |
| Muskelaufbau | ✅ geeignet | Passendes Volumen/Frequenz. |
| Abnehmen | ⛔ nicht automatisch empfehlen | Kein Defizit-/Cardio-Hinweis — dafür existiert fat_loss_fullbody. |
| Hybrid | ⛔ nicht automatisch empfehlen | Kein Ausdaueranteil. |
| Funktionell | 🟡 nur angepasst | Reine Maschinen/Freihantel-Übungen, wenig Bewegungsvielfalt trotz functional-Tag. |

### `fat_loss_fullbody` — Fatburn Ganzkörper

3 Tage/Woche · gym · Tags: beginner, intermediate / weightLoss, hypertrophy

**48 Arbeitssätze/Woche** (~16/Session), RIR 2.0–2.0, geschätzt **146 Min./Woche** (~49 Min./Session). Direkte Sätze/Woche je Muskelgruppe: chest 9, back 9, shoulders 9, biceps 6, hamstrings 5, triceps 4, quads 3, glutes 3.

Equipment: barbell (8×), dumbbell (6×), machine (5×), cable (2×) · Kanonische Compounds: Bankdrücken, Kniebeuge, Rudern vorgebeugt, Schulterdrücken (stehend)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | 🟡 nur angepasst | 16 Sätze + Cardio-Finisher pro Einheit ist für echte Anfänger ordentliches Volumen. |
| Returner | 🟡 nur angepasst | Gleiche Begründung wie Starter, plus Pausen-Rampe nötig. |
| Intermediate | ✅ geeignet | Ehrlich als Defizit-/Erhaltplan gerahmt, passendes Volumen. |
| Advanced | ⛔ nicht automatisch empfehlen | Zu wenig Reiz/Spezialisierung für Fortgeschrittene. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Kein Kraftfokus. |
| Muskelaufbau | 🟡 nur angepasst | Moderates Volumen, Nebenziel neben Defizit. |
| Abnehmen | ✅ geeignet | Fettverlust korrekt über Kaloriendefizit gerahmt, Training erhält Muskel/Kraft. |
| Hybrid | ⛔ nicht automatisch empfehlen | Kein strukturierter Ausdaueranteil. |
| Funktionell | ⛔ nicht automatisch empfehlen | Reines Hypertrophie-Übungsschema. |

### `home_gym_hero` — Home Gym Hero

3 Tage/Woche · homeGym · Tags: beginner, intermediate / hypertrophy

**53 Arbeitssätze/Woche** (~18/Session), RIR 2.0–2.0, geschätzt **107 Min./Woche** (~36 Min./Session). Direkte Sätze/Woche je Muskelgruppe: quads 10, chest 9, back 9, hamstrings 7, shoulders 6, biceps 6, triceps 6.

Equipment: dumbbell (17×)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | 🟡 nur angepasst | 16-19 Sätze/Einheit ist für echte Anfänger hoch, auch ohne Barbell-Technik. |
| Returner | 🟡 nur angepasst | Gleiche Begründung, plus Pausen-Rampe. |
| Intermediate | ✅ geeignet | Klassischer KH-Hypertrophieplan. |
| Advanced | ⛔ nicht automatisch empfehlen | Zu wenig Frequenz/Spezialisierung für Fortgeschrittene. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Keine schweren Lastbereiche/Tests. |
| Muskelaufbau | 🟡 nur angepasst | Passt inhaltlich, ABER: 'kein Fitnessstudio nötig' verschweigt den Bank-Bedarf (siehe Red Flag) — vor automatischer Empfehlung Equipment-Realitätscheck. |
| Abnehmen | 🟡 nur angepasst | Kein Defizit-Hinweis, Training allein reicht nicht. |
| Hybrid | ⛔ nicht automatisch empfehlen | Kein Ausdaueranteil. |
| Funktionell | ⛔ nicht automatisch empfehlen | Reines Hypertrophie-Schema. |

### `bodyweight_mastery` — Bodyweight Mastery

3 Tage/Woche · noEquipment · Tags: beginner, intermediate / functional, weightLoss

**48 Arbeitssätze/Woche** (~16/Session), RIR 2.0–3.0, geschätzt **82 Min./Woche** (~27 Min./Session). Direkte Sätze/Woche je Muskelgruppe: core 18, quads 10, chest 7, back 4, shoulders 3, triceps 3, glutes 3.

Equipment: bodyweight (15×)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | 🟡 nur angepasst | Dips/Pike-Push-ups/Burpees sind trotz 'Bodyweight=einfach'-Annahme technisch/konditionell fordernd. |
| Returner | 🟡 nur angepasst | Gleiche Begründung plus Pausen-Rampe. |
| Intermediate | ✅ geeignet | Passendes Volumen für reines Körpergewichtstraining. |
| Advanced | ⛔ nicht automatisch empfehlen | Decke bei reinem Bodyweight ohne Zusatzlast schnell erreicht. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Kein Lastprogressions-Konzept. |
| Muskelaufbau | ⛔ nicht automatisch empfehlen | Zu wenig Lastprogression für gezielten Muskelaufbau. |
| Abnehmen | 🟡 nur angepasst | Training allein ersetzt kein Defizit. |
| Hybrid | ⛔ nicht automatisch empfehlen | Kein strukturierter Ausdaueranteil. |
| Funktionell | ✅ geeignet | Bewegungsvielfalt, Rumpf/Ganzkörper-Fokus passt zum Tag. |

### `push_pull_legs` — Push-Pull-Legs

6 Tage/Woche · gym · Tags: intermediate, advanced / hypertrophy, strength

**119 Arbeitssätze/Woche** (~20/Session), RIR 2.0–2.0, geschätzt **281 Min./Woche** (~47 Min./Session). Direkte Sätze/Woche je Muskelgruppe: shoulders 21, back 21, quads 17, chest 14, triceps 12, biceps 12, hamstrings 10, calves 8, glutes 4.

Equipment: barbell (11×), dumbbell (9×), cable (6×), machine (6×), bodyweight (3×) · Kanonische Compounds: Bankdrücken, Kniebeuge, Kreuzheben (konventionell), Rudern vorgebeugt, Schulterdrücken (stehend)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ⛔ nicht automatisch empfehlen | Aktuell vom Matcher-Bug durchlassbar (targetExperience enthält 'intermediate') — inhaltlich klar ungeeignet: 119 Sätze/Woche, 6 Tage, 5 freie Compounds. |
| Returner | ⛔ nicht automatisch empfehlen | Selbst mit vorhandener Technik ist 6x/Woche + dieses Volumen nach einer Pause zu viel ohne Rampe. |
| Intermediate | 🟡 nur angepasst | Oberes Ende des üblichen Intermediate-Volumens (20 direkte Sätze/Woche für Rücken/Schultern) — machbar, aber nicht pauschal 'ideal'. |
| Advanced | ✅ geeignet | Passende Zielgruppe für Frequenz und Volumen. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | 🟡 nur angepasst | Täglicher RIR 2.0 konstant, kein reiner Maximalkraft-Block trotz Tag. |
| Muskelaufbau | ✅ geeignet | Für Fortgeschrittene passendes Volumen/Frequenz. |
| Abnehmen | ⛔ nicht automatisch empfehlen | Kein Defizit-/Cardio-Konzept. |
| Hybrid | ⛔ nicht automatisch empfehlen | Kein Ausdaueranteil. |
| Funktionell | ⛔ nicht automatisch empfehlen | Reiner Maschinen/Freihantel-Split. |

### `upper_lower` — Upper-Lower-Split

4 Tage/Woche · gym · Tags: intermediate, advanced / hypertrophy, strength

**80 Arbeitssätze/Woche** (~20/Session), RIR 2.0–2.0, geschätzt **197 Min./Woche** (~49 Min./Session). Direkte Sätze/Woche je Muskelgruppe: back 17, quads 14, chest 11, hamstrings 9, calves 8, shoulders 6, biceps 6, triceps 6, glutes 3.

Equipment: barbell (10×), machine (6×), dumbbell (4×), bodyweight (2×), cable (2×) · Kanonische Compounds: Bankdrücken, Kniebeuge, Kreuzheben (konventionell), Rudern vorgebeugt, Schulterdrücken (stehend)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ⛔ nicht automatisch empfehlen | Aktuell vom Matcher-Bug durchlassbar — inhaltlich ungeeignet: schwere 3-5-Wiederholungsbereiche + Nordic Curls verlangen vorhandene Technik/Kraftbasis. |
| Returner | ⛔ nicht automatisch empfehlen | Gleiche Begründung, zusätzlich fehlende Lastrampe nach Pause. |
| Intermediate | ✅ geeignet | Klassischer, gut belegter Split für diese Zielgruppe. |
| Advanced | ✅ geeignet | Passt ebenso. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ✅ geeignet | Klare Kraft-Tage mit 3-5 Wiederholungen. |
| Muskelaufbau | ✅ geeignet | Volumen-Tage ergänzen die Kraft-Tage sinnvoll. |
| Abnehmen | ⛔ nicht automatisch empfehlen | Kein Defizit-/Cardio-Konzept. |
| Hybrid | ⛔ nicht automatisch empfehlen | Kein Ausdaueranteil. |
| Funktionell | ⛔ nicht automatisch empfehlen | Reiner Maschinen/Freihantel-Split. |

### `arnold_split` — Arnold Split

6 Tage/Woche · gym · Tags: advanced / hypertrophy

**118 Arbeitssätze/Woche** (~20/Session), RIR 0.0–1.5, geschätzt **257 Min./Woche** (~43 Min./Session). Direkte Sätze/Woche je Muskelgruppe: chest 20, shoulders 19, back 17, quads 17, biceps 13, triceps 13, calves 8, hamstrings 7, glutes 4.

Equipment: barbell (11×), dumbbell (8×), cable (7×), machine (7×), bodyweight (1×) · Kanonische Compounds: Bankdrücken, Kniebeuge, Rudern vorgebeugt, Schulterdrücken (stehend)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ⛔ nicht automatisch empfehlen | Korrekt rein advanced getaggt — Matcher muss das beibehalten. |
| Returner | ⛔ nicht automatisch empfehlen | Gleiches gilt für Wiedereinsteiger. |
| Intermediate | ⛔ nicht automatisch empfehlen | RIR 0-1.5 bei 118 Sätzen/Woche übersteigt übliche Intermediate-Erholungskapazität. |
| Advanced | ✅ geeignet | Hohe Frequenz/geringes RIR passt zur Zielgruppe; der advanced-Tag-Bonus ist hier sachlich begründet (im Gegensatz zum pauschalen Tage-Bonus). |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Kein Kraftfokus, reine Pump-/Hypertrophie-Ausrichtung. |
| Muskelaufbau | ✅ geeignet | Explizite Bodybuilding-Ausrichtung mit hohem Volumen. |
| Abnehmen | ⛔ nicht automatisch empfehlen | Kein Defizit-Konzept. |
| Hybrid | ⛔ nicht automatisch empfehlen | Kein Ausdaueranteil. |
| Funktionell | ⛔ nicht automatisch empfehlen | Reiner Isolations-/Maschinen-Split. |

### `bro_split` — Bro-Split

5 Tage/Woche · gym · Tags: intermediate, advanced / hypertrophy

**92 Arbeitssätze/Woche** (~18/Session), RIR 0.0–2.0, geschätzt **215 Min./Woche** (~43 Min./Session). Direkte Sätze/Woche je Muskelgruppe: chest 17, back 17, shoulders 17, biceps 10, triceps 10, quads 10, hamstrings 7, calves 4.

Equipment: barbell (10×), dumbbell (8×), cable (5×), machine (3×), bodyweight (2×) · Kanonische Compounds: Bankdrücken, Kniebeuge, Kreuzheben (konventionell), Rudern vorgebeugt, Schulterdrücken (stehend)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ⛔ nicht automatisch empfehlen | Hohes Volumen + 1x/Woche pro Muskelgruppe ist für echte Anfänger suboptimal (geringere Frequenz als Evidenz für diese Zielgruppe nahelegt). |
| Returner | ⛔ nicht automatisch empfehlen | Gleiche Begründung plus fehlende Lastrampe. |
| Intermediate | 🟡 nur angepasst | Hohe Einzeltrainingsbelastung (bis 23 Sätze/Einheit), machbar aber nicht pauschal optimal. |
| Advanced | ✅ geeignet | Klassischer Bodybuilding-Split für diese Zielgruppe. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Kein Kraftfokus. |
| Muskelaufbau | ✅ geeignet | Hohes Volumen pro Muskelgruppe passt zum Ziel. |
| Abnehmen | ⛔ nicht automatisch empfehlen | Kein Defizit-Konzept. |
| Hybrid | ⛔ nicht automatisch empfehlen | Kein Ausdaueranteil. |
| Funktionell | ⛔ nicht automatisch empfehlen | Reiner Isolations-Split. |

### `powerlifting_5x5` — Powerlifting 5x5

3 Tage/Woche · gym · Tags: beginner, intermediate / strength

**41 Arbeitssätze/Woche** (~14/Session), RIR 2.0–2.0, geschätzt **162 Min./Woche** (~54 Min./Session). Direkte Sätze/Woche je Muskelgruppe: quads 15, back 11, chest 10, shoulders 5.

Equipment: barbell (9×), cable (3×) · Kanonische Compounds: Bankdrücken, Kniebeuge, Kreuzheben (konventionell), Rudern vorgebeugt, Schulterdrücken (stehend)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ✅ geeignet | Bewährtes, einfaches lineares Einsteiger-Kraftprogramm mit nur 3 Compound-Mustern pro Einheit. |
| Returner | ✅ geeignet | Einfache lineare Progression eignet sich auch für den Wiedereinstieg. |
| Intermediate | 🟡 nur angepasst | Funktioniert als Fortsetzung, lineare Progression stagniert aber typischerweise schneller als bei echten Anfängern. |
| Advanced | ⛔ nicht automatisch empfehlen | Zu basal/wenig spezialisiert für echte Fortgeschrittene. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ✅ geeignet | Klassisches Kraftprogramm. |
| Muskelaufbau | 🟡 nur angepasst | Nebeneffekt der Kraftarbeit, nicht der Fokus. |
| Abnehmen | ⛔ nicht automatisch empfehlen | Kein Defizit-Konzept. |
| Hybrid | ⛔ nicht automatisch empfehlen | Kein Ausdaueranteil. |
| Funktionell | ⛔ nicht automatisch empfehlen | Reines Kraft-Schema. |

### `powerlifting_3x5` — Powerlifting 3x5

3 Tage/Woche · gym · Tags: intermediate, advanced / strength

**27 Arbeitssätze/Woche** (~9/Session), RIR 1.5–2.5, geschätzt **106 Min./Woche** (~35 Min./Session). Direkte Sätze/Woche je Muskelgruppe: quads 9, back 9, chest 6, shoulders 3.

Equipment: barbell (8×), bodyweight (1×) · Kanonische Compounds: Bankdrücken, Kniebeuge, Kreuzheben (konventionell), Rudern vorgebeugt, Schulterdrücken (stehend)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ⛔ nicht automatisch empfehlen | Kein Beginner-Tag gesetzt — Matcher darf 'intermediate'-Tag allein nicht als Freigabe werten. |
| Returner | ⛔ nicht automatisch empfehlen | Gleiche Begründung. |
| Intermediate | ✅ geeignet | Täglich wechselnder Fokus mit submaximalen Zweitsätzen passt zu dieser Zielgruppe. |
| Advanced | ✅ geeignet | Ebenso geeignet. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ✅ geeignet | Klares Maximalkraft-Schema. |
| Muskelaufbau | ⛔ nicht automatisch empfehlen | Zu geringes Volumen (27 Sätze/Woche) für gezielten Muskelaufbau. |
| Abnehmen | ⛔ nicht automatisch empfehlen | Kein Defizit-Konzept. |
| Hybrid | ⛔ nicht automatisch empfehlen | Kein Ausdaueranteil. |
| Funktionell | ⛔ nicht automatisch empfehlen | Reines Kraft-Schema. |

### `football_athletic` — Fussball Athletik

2 Tage/Woche · gym · Tags: intermediate / hybrid, strength

**28 Arbeitssätze/Woche** (~14/Session), RIR 2.5–3.5, geschätzt **66 Min./Woche** (~33 Min./Session). Direkte Sätze/Woche je Muskelgruppe: quads 9, core 6, calves 4, hamstrings 3, chest 3, back 3.

Equipment: bodyweight (5×), barbell (3×), dumbbell (1×) · Kanonische Compounds: Bankdrücken, Kniebeuge

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ⛔ nicht automatisch empfehlen | Box Jumps und Nordic Curls verlangen vorhandene Grundkraft/Landetechnik. |
| Returner | ⛔ nicht automatisch empfehlen | Gleiche Begründung. |
| Intermediate | ✅ geeignet | Passende Ergänzung zum Vereinstraining für diese Zielgruppe. |
| Advanced | 🟡 nur angepasst | Als reines Kraftsport-Programm (ohne Teamsport-Kontext) niedriges Volumen. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | 🟡 nur angepasst | Nur 2 Tage/niedriges Volumen für einen reinen Kraftfokus. |
| Muskelaufbau | ⛔ nicht automatisch empfehlen | Kein Hypertrophie-Volumen. |
| Abnehmen | ⛔ nicht automatisch empfehlen | Kein Defizit-Konzept. |
| Hybrid | ✅ geeignet | Kraft + Explosivität als Ergänzungsprogramm passt zum Tag. |
| Funktionell | 🟡 nur angepasst | Athletik-fokussiert, aber ohne Ausdaueranteil nur teilweise 'funktionell'. |

### `hybrid_beginner` — Hybrid Athlete — Beginner

4 Tage/Woche · gym · Tags: beginner, intermediate / hybrid · Equipment-Varianten: dumbbellOnly, kettlebellOnly

**23 Arbeitssätze/Woche** (~6/Session), RIR 1.0–3.0, geschätzt **139 Min./Woche** (~35 Min./Session). Direkte Sätze/Woche je Muskelgruppe: back 6, quads 3, chest 3, core 3, hamstrings 3, shoulders 3, biceps 2.

Equipment: barbell (4×), bodyweight (3×), dumbbell (2×), machine (1×) · Kanonische Compounds: Bankdrücken, Kniebeuge, Rudern vorgebeugt

| Track | Eignung | Begründung |
|---|---|---|
| Starter | 🟡 nur angepasst | RIR-Puffer 1-3 korrekt vorsichtig, aber Technik in Bankdrücken/Kniebeuge/Rudern bleibt Voraussetzung. |
| Returner | 🟡 nur angepasst | Gleiche Begründung plus Pausen-Rücksicht. |
| Intermediate | ✅ geeignet | Passendes Einstiegs-Volumen in Concurrent-Training. |
| Advanced | ⛔ nicht automatisch empfehlen | Zu geringes Volumen/Frequenz für Fortgeschrittene. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Nicht getaggt, kein Kraftfokus. |
| Muskelaufbau | ⛔ nicht automatisch empfehlen | Nicht getaggt, zu wenig Volumen. |
| Abnehmen | ⛔ nicht automatisch empfehlen | Nicht getaggt, kein Defizit-Konzept. |
| Hybrid | ✅ geeignet | Explizit für concurrent Kraft+Ausdauer konzipiert. |
| Funktionell | ⛔ nicht automatisch empfehlen | Nicht der Fokus dieses Programms. |

### `hybrid_balanced` — Hybrid Athlete — Balanced

5 Tage/Woche · gym · Tags: intermediate, advanced / hybrid · Equipment-Varianten: dumbbellOnly, kettlebellOnly

**37 Arbeitssätze/Woche** (~7/Session), RIR 1.0–3.0, geschätzt **197 Min./Woche** (~39 Min./Session). Direkte Sätze/Woche je Muskelgruppe: back 9, chest 7, shoulders 3, triceps 3, biceps 3, quads 3, hamstrings 3, calves 3, core 3.

Equipment: barbell (7×), bodyweight (4×), dumbbell (2×), cable (1×) · Kanonische Compounds: Bankdrücken, Kreuzheben (konventionell), Rudern vorgebeugt, Schulterdrücken (stehend)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ⛔ nicht automatisch empfehlen | Push/Pull/Legs-Technik plus Laufpensum gleichzeitig ist für Starter zu viel auf einmal. |
| Returner | ⛔ nicht automatisch empfehlen | Gleiche Begründung. |
| Intermediate | ✅ geeignet | Guter Mittelweg aus Split-Struktur und Laufvolumen. |
| Advanced | 🟡 nur angepasst | Für reine Kraft-Fortgeschrittene zu wenig Strength-Fokus, für Hybrid-Fortgeschrittene passend. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Nicht getaggt. |
| Muskelaufbau | ⛔ nicht automatisch empfehlen | Nicht getaggt. |
| Abnehmen | ⛔ nicht automatisch empfehlen | Nicht getaggt. |
| Hybrid | ✅ geeignet | Kernkonzept des Programms. |
| Funktionell | ⛔ nicht automatisch empfehlen | Nicht der Fokus. |

### `hybrid_performance` — Hybrid Athlete — Performance

6 Tage/Woche · gym · Tags: advanced / hybrid · Equipment-Varianten: dumbbellOnly, kettlebellOnly

**42 Arbeitssätze/Woche** (~7/Session), RIR 1.0–3.0, geschätzt **280 Min./Woche** (~47 Min./Session). Direkte Sätze/Woche je Muskelgruppe: back 10, chest 7, quads 7, shoulders 6, triceps 3, biceps 3, hamstrings 3, calves 3.

Equipment: barbell (8×), bodyweight (5×), dumbbell (3×), cable (1×) · Kanonische Compounds: Bankdrücken, Kniebeuge, Kreuzheben (konventionell), Rudern vorgebeugt, Schulterdrücken (stehend)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ⛔ nicht automatisch empfehlen | Korrekt rein advanced getaggt. |
| Returner | ⛔ nicht automatisch empfehlen | Gleiches gilt. |
| Intermediate | ⛔ nicht automatisch empfehlen | 6 Trainingstage + 3 Läufe parallel übersteigt übliche Intermediate-Erholungskapazität. |
| Advanced | ✅ geeignet | Spitzenbelastung für die explizit adressierte Zielgruppe. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Nicht getaggt. |
| Muskelaufbau | ⛔ nicht automatisch empfehlen | Nicht getaggt. |
| Abnehmen | ⛔ nicht automatisch empfehlen | Nicht getaggt. |
| Hybrid | ✅ geeignet | Kernkonzept des Programms. |
| Funktionell | ⛔ nicht automatisch empfehlen | Nicht der Fokus. |

### `crossfit_bodyweight_rx` — CrossFit Bodyweight (Rx)

3 Tage/Woche · noEquipment · Tags: advanced / functional, weightLoss

Zeitformat-Tage (AMRAP/EMOM/Circuit/Auf Zeit) — Arbeitssätze nicht vergleichbar mit klassischem Training. Geschätzte Wochendauer (Untergrenze): **44 Min.** (~15 Min./Session). Berührte Muskelgruppen: back, chest, core, quads.

Equipment: bodyweight (7×)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ⛔ nicht automatisch empfehlen | Korrekt rein advanced getaggt wegen Rx-Bewegungen (Klimmzüge etc.) — Matcher filtert das bereits richtig raus. |
| Returner | ⛔ nicht automatisch empfehlen | Gleiches gilt. |
| Intermediate | ⛔ nicht automatisch empfehlen | Rx-Bewegungen (volle Klimmzüge im AMRAP) setzen bereits vorhandene Kraftbasis voraus. |
| Advanced | ✅ geeignet | Passende Zielgruppe; Dauer-Schätzung ist eine Untergrenze (siehe Methodik). |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Kein Kraftfokus. |
| Muskelaufbau | ⛔ nicht automatisch empfehlen | Kein Hypertrophie-Volumen. |
| Abnehmen | 🟡 nur angepasst | Training allein ersetzt kein Defizit. |
| Hybrid | ⛔ nicht automatisch empfehlen | Nicht explizit als Hybrid getaggt. |
| Funktionell | ✅ geeignet | Klassische CrossFit-Bewegungsmuster. |

### `crossfit_bodyweight_scaled` — CrossFit Bodyweight (Scaled)

3 Tage/Woche · noEquipment · Tags: beginner / functional, weightLoss

Zeitformat-Tage (AMRAP/EMOM/Circuit/Auf Zeit) — Arbeitssätze nicht vergleichbar mit klassischem Training. Geschätzte Wochendauer (Untergrenze): **44 Min.** (~15 Min./Session). Berührte Muskelgruppen: back, chest, core, quads.

Equipment: bodyweight (7×)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ✅ geeignet | Explizit als Scaled-Einstiegsvariante konzipiert (Handtuch-Rudern statt Klimmzüge etc.). |
| Returner | 🟡 nur angepasst | Grundkonzept passt, ggf. zusätzlich skalieren je nach Pausenlänge. |
| Intermediate | ⛔ nicht automatisch empfehlen | Zu einfach skaliert für diese Zielgruppe — Rx-Variante existiert dafür. |
| Advanced | ⛔ nicht automatisch empfehlen | Gleiche Begründung. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Kein Kraftfokus. |
| Muskelaufbau | ⛔ nicht automatisch empfehlen | Kein Hypertrophie-Volumen. |
| Abnehmen | 🟡 nur angepasst | Training allein ersetzt kein Defizit. |
| Hybrid | ⛔ nicht automatisch empfehlen | Nicht explizit getaggt. |
| Funktionell | ✅ geeignet | Eingängige Bewegungsmuster für den Einstieg. |

### `crossfit_weighted` — CrossFit mit Gewichten

3 Tage/Woche · homeGym · Tags: beginner, intermediate, advanced / functional, weightLoss

Zeitformat-Tage (AMRAP/EMOM/Circuit/Auf Zeit) — Arbeitssätze nicht vergleichbar mit klassischem Training. Geschätzte Wochendauer (Untergrenze): **39 Min.** (~13 Min./Session). Berührte Muskelgruppen: back, chest, core, glutes, quads, shoulders.

Equipment: dumbbell (4×), bodyweight (3×), kettlebell (1×)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | 🟡 nur angepasst | Skalierung über Gewicht statt Bewegung macht es breiter nutzbar, Technik bei Thruster/Burpees/Kreuzheben(KH) bleibt aber relevant. |
| Returner | 🟡 nur angepasst | Gleiche Begründung. |
| Intermediate | ✅ geeignet | Guter Mittelweg aus Lastskalierung und Konditionsreiz. |
| Advanced | 🟡 nur angepasst | Als alleiniges Programm für reine Kraft-Fortgeschrittene zu wenig Last. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Kein strukturierter Kraftfokus. |
| Muskelaufbau | ⛔ nicht automatisch empfehlen | Kein Hypertrophie-Volumen. |
| Abnehmen | 🟡 nur angepasst | Training allein ersetzt kein Defizit. |
| Hybrid | ⛔ nicht automatisch empfehlen | Nicht explizit getaggt. |
| Funktionell | ✅ geeignet | Metcon-Format mit Zusatzlast. |

### `kettlebell_beginner` — Kettlebell Grundlagen

3 Tage/Woche · homeGym · Tags: beginner, intermediate / functional, weightLoss

Zeitformat-Tage (AMRAP/EMOM/Circuit/Auf Zeit) — Arbeitssätze nicht vergleichbar mit klassischem Training. Geschätzte Wochendauer (Untergrenze): **45 Min.** (~15 Min./Session). Berührte Muskelgruppen: chest, glutes, quads.

Equipment: kettlebell (6×), bodyweight (3×)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ✅ geeignet | Explizit als Technik-Einstieg konzipiert (Deadlift/Goblet Squat/Swing). |
| Returner | ✅ geeignet | Gleiche Eignung. |
| Intermediate | 🟡 nur angepasst | Guter KB-Einstieg, als alleiniges Hypertrophie-/Kraftprogramm zu wenig. |
| Advanced | ⛔ nicht automatisch empfehlen | Zu basal für Fortgeschrittene. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Kein strukturierter Kraftfokus. |
| Muskelaufbau | ⛔ nicht automatisch empfehlen | Kein Hypertrophie-Volumen. |
| Abnehmen | 🟡 nur angepasst | Training allein ersetzt kein Defizit. |
| Hybrid | ⛔ nicht automatisch empfehlen | Nicht explizit getaggt. |
| Funktionell | ✅ geeignet | Technikfokussierter KB-Einstieg. |

### `kettlebell_advanced` — Kettlebell Fortgeschritten

3 Tage/Woche · homeGym · Tags: advanced / functional, weightLoss

Zeitformat-Tage (AMRAP/EMOM/Circuit/Auf Zeit) — Arbeitssätze nicht vergleichbar mit klassischem Training. Geschätzte Wochendauer (Untergrenze): **63 Min.** (~21 Min./Session). Berührte Muskelgruppen: chest, core, glutes, quads, shoulders.

Equipment: kettlebell (6×), bodyweight (2×), dumbbell (1×)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ⛔ nicht automatisch empfehlen | Korrekt rein advanced getaggt wegen Snatch/Clean & Press-Technik. |
| Returner | ⛔ nicht automatisch empfehlen | Gleiches gilt. |
| Intermediate | ⛔ nicht automatisch empfehlen | Komplexe KB-Lifts setzen bereits vorhandene Technik voraus. |
| Advanced | ✅ geeignet | Passende Zielgruppe. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Kein strukturierter Kraftfokus. |
| Muskelaufbau | ⛔ nicht automatisch empfehlen | Kein Hypertrophie-Volumen. |
| Abnehmen | 🟡 nur angepasst | Training allein ersetzt kein Defizit. |
| Hybrid | ⛔ nicht automatisch empfehlen | Nicht explizit getaggt. |
| Funktionell | ✅ geeignet | Fortgeschrittene KB-Technik. |

### `kettlebell_complexes` — Kettlebell Komplexe

5 Tage/Woche · homeGym · Tags: intermediate, advanced / functional, weightLoss

Zeitformat-Tage (AMRAP/EMOM/Circuit/Auf Zeit) — Arbeitssätze nicht vergleichbar mit klassischem Training. Geschätzte Wochendauer (Untergrenze): **95 Min.** (~19 Min./Session). Berührte Muskelgruppen: back, chest, core, glutes, quads, shoulders, triceps.

Equipment: kettlebell (19×), bodyweight (1×)

| Track | Eignung | Begründung |
|---|---|---|
| Starter | ⛔ nicht automatisch empfehlen | 'Intermediate'-Tag allein ist keine Freigabe: 5x/Woche komplexe KB-Flows (Clean-to-Front-Squat, Snatch) sind technisch anspruchsvoll. |
| Returner | ⛔ nicht automatisch empfehlen | Gleiche Begründung. |
| Intermediate | 🟡 nur angepasst | Technisch fordernd bei hoher Frequenz (5 Tage) — mit Technik-Vorerfahrung machbar. |
| Advanced | ✅ geeignet | Passende Zielgruppe für Frequenz und Komplexität. |

| Ziel | Eignung | Begründung |
|---|---|---|
| Kraft | ⛔ nicht automatisch empfehlen | Kein strukturierter Kraftfokus. |
| Muskelaufbau | ⛔ nicht automatisch empfehlen | Kein klassisches Hypertrophie-Schema. |
| Abnehmen | 🟡 nur angepasst | Training allein ersetzt kein Defizit. |
| Hybrid | ⛔ nicht automatisch empfehlen | Nicht explizit getaggt. |
| Funktionell | ✅ geeignet | Komplexe Ganzkörper-Bewegungsmuster. |

## Noch offen (nächste Schritte)

Dieses Dokument deckt Abschnitt 1+2 der Vorgabe ab (Katalog-Export, inhaltliche Red Flags). Noch zu tun, in getrennten Schritten:
- Abschnitt 3: Eingaben korrigieren (Wochenziel vs. Tage-Obergrenze; ExperienceTrack ≠ Technik-Kompetenz in der Baseline-Check-Anbindung prüfen).
- Abschnitt 4: Die 6 oben benannten Matcher-Befunde tatsächlich beheben (Equipment-Hartfilter auf alle Templates ausweiten, Starter-Filter auf nachgewiesene Eignung statt bloßem `.intermediate`-Tag umstellen, Fallback um Tage-Obergrenze ergänzen, `templateScoreBonus` von pauschalem Tage-Bonus auf inhaltliche Kriterien umstellen, `ScoreBreakdown`-Typ einführen).
- Abschnitt 5: Reproduktionsmatrix + die 8 konkreten Regressionsfälle als Tests.
- Abschnitt 6: Lokalisierungs-Texte der 4 überclaimenden Templates in DE/EN/TR entschärfen; Apple-Build/SwiftData/UI-Tests zusätzlich zu Core.

**Transparenz-Hinweis**: Alle Zahlen in diesem Dokument stammen aus einem automatisierten Dump von `ProgramTemplates.all`/`ExerciseLibraryData.all` auf dem Linux-Sandbox-Toolchain (Core-Logik, keine SwiftUI-Abhängigkeit, daher dort korrekt kompilier- und testbar). Die Eignungs-Einschätzungen je Track/Ziel sind fachliche Bewertung auf Basis dieser Zahlen, kein automatisiert abgeleitetes Urteil — und noch nicht gegen ein echtes Gerät/TestFlight verifiziert.
