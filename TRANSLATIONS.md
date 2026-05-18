# Deltiq — Translation Source-of-Truth

**Gesamt: 247 Keys im String Catalog + ~195 noch hartkodierte Strings im Code.**

## Coverage-Status (Catalog)

| Sprache | Übersetzt | Fehlt |
|---|---|---|
| 🇩🇪 Deutsch (DE) | **247 / 247** (100%) | 0 |
| 🇬🇧 English (EN) | 170 / 247 (68%) | **77** |
| 🇹🇷 Türkçe (TR) | 105 / 247 (42%) | **142** |

Wenn du EN/TR aktualisierst:
- Per Xcode: öffne `Sources/FitnessAppUI/Resources/Localizable.xcstrings`, Apple's String-Catalog-Editor markiert „needs translation" automatisch.
- Per CSV-Export aus dieser Tabelle → ChatGPT / DeepL → zurück in die xcstrings importieren.
- Per direktem JSON-Edit (vorsichtig, JSON-Syntax muss valide bleiben).

Quelle: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`

Tabellenformat: leere EN/TR-Spalten brauchen Übersetzung. Plural-Keys sind separat aufgelistet — die haben one/other-Varianten.


## `active.*`  (4 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `active.action.discard` | Verwerfen | Discard |  |
| `active.action.save` | Training speichern | Save workout | Antrenmanı Kaydet |
| `active.confirm.discard.title` | Training verwerfen? | Discard workout? |  |
| `active.confirm.finish.title` | Training abschließen? | Finish workout? |  |

## `coaching.*`  (20 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `coaching.cnsOverloaded.analytical.hybrid` | Akkumulierte ZNS-Last über Schwelle. Heute kein high-intensity Cardio + keine schweren Compounds. Skill-Work und Mobility sind okay. |  |  |
| `coaching.cnsOverloaded.analytical.hypertrophy` | CNS-Score erhöht. Hypertrophie-Reize sind noch produktiv, aber Pause Compound-Lifts und fokussiere Maschinen-Isolation. |  |  |
| `coaching.cnsOverloaded.analytical.strength` | ZNS-Belastung >90%. Schwere 1RM-Versuche sind heute statistisch ineffizient. Reduziere die Intensität. |  |  |
| `coaching.cnsOverloaded.motivating.hypertrophy` | Du hast extrem hart gearbeitet! Gönn deinem Nervensystem etwas Ruhe und fokussiere dich heute auf leichte Isolationsübungen. |  |  |
| `coaching.cnsOverloaded.strict.hybrid` | Rote Zone. Dein Nervensystem ist durch. Keine schweren Kettlebell-Swings heute. Mach Mobility oder mach Pause. |  |  |
| `coaching.newPR.analytical.hybrid` | Leistungssteigerung erkannt. Neues Volumen-PR im Functional-Zirkel erreicht. Progression verläuft nach Plan. |  |  |
| `coaching.newPR.analytical.hypertrophy` | Neuer Volumen-PR registriert. Progressiver Overload greift — beim nächsten Mikro-Zyklus +1 Set oder +2 Wdh planen. |  |  |
| `coaching.newPR.analytical.strength` | Neuer Top-Set-PR. Estimated 1RM aktualisiert. Trainingsmaxima werden im Hintergrund neu kalibriert. |  |  |
| `coaching.newPR.motivating.strength` | Unglaubliche Leistung! Neuer PR auf der Stange. Genau so funktioniert progressiver Overload — feier deinen Erfolg! |  |  |
| `coaching.newPR.strict.hypertrophy` | Neuer PR. Gut. Aber werd nicht übermütig — die Technik muss auch im nächsten Zyklus zu 100% sitzen. Weiterarbeiten. |  |  |
| `coaching.plateauDetected.analytical.hybrid` | Plateau über 3+ Wochen. Reiz-Wechsel: Tempo, ROM oder Übungs-Substitut — danach 5–7 Tage Deload. |  |  |
| `coaching.plateauDetected.analytical.hypertrophy` | Stagnation seit 3 Wochen erkannt. Eine Anpassung der Übungsauswahl oder eine Deload-Woche wird empfohlen. |  |  |
| `coaching.plateauDetected.analytical.strength` | Top-Set-Progression flacht ab. Variante einbauen (Pin Press, Block Pull) oder Deload-Woche, dann zurück zum Haupt-Lift. |  |  |
| `coaching.plateauDetected.motivating.hybrid` | Völlig normal, mal auf der Stelle zu treten! Lass uns den Reiz ändern — probier ein neues Movement-Pattern aus. |  |  |
| `coaching.plateauDetected.strict.strength` | Du hängst fest. Entweder isst du zu wenig, schläfst zu schlecht, oder dein Plan braucht einen Reset. Zeit für einen Deload. |  |  |
| `coaching.restDay.analytical.hybrid` | Ruhetag im Plan. Optional ein lockerer Aerob-Block (Z2, 30–45 Min) zur aktiven Erholung — sonst Pause. |  |  |
| `coaching.restDay.analytical.hypertrophy` | Regenerationsphase aktiv. Muskelproteinsynthese läuft. Nächstes Training ist für morgen angesetzt. |  |  |
| `coaching.restDay.analytical.strength` | Recovery-Tag. Dein ZNS arbeitet jetzt — das nächste 1RM wird heute, nicht im Gym, vorbereitet. |  |  |
| `coaching.restDay.motivating.hybrid` | Du hast dir eine Pause verdient! Ein leichter Mobility-Flow oder Spaziergang ist heute perfekt für deine aktive Erholung. |  |  |
| `coaching.restDay.strict.strength` | Heute wird nicht trainiert. Du wirst in der Pause stärker, nicht unter der Hantel. Bleib aus dem Gym. |  |  |

## `common.*`  (4 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `common.cancel` | Abbrechen | Cancel | İptal |
| `common.discard` | Verwerfen | Discard |  |
| `common.done` | Fertig | Done | Bitti |
| `common.save` | Speichern | Save | Kaydet |

## `dashboard.*`  (52 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `dashboard.action.adHoc.a11y` | Spontanes Workout starten — leere Session ohne Plan-Anbindung |  |  |
| `dashboard.action.adHoc.primary` | Spontanes Workout starten |  |  |
| `dashboard.action.adHoc.secondary` | Vom Plan abweichen — Spontanes Workout |  |  |
| `dashboard.action.resumeRunning` | Laufendes Training fortsetzen |  |  |
| `dashboard.action.startDirect` | Direkt starten |  |  |
| `dashboard.cardioChart.legend` | min/km · niedriger = besser |  |  |
| `dashboard.cardioChart.title` | Cardio-Pace-Trend |  |  |
| `dashboard.compoundChart.empty.hint` | Sobald du eine Compound-Übung in zwei Sessions geloggt hast, erscheint hier der Trend. |  |  |
| `dashboard.compoundChart.empty.title` | Noch zu wenig Daten |  |  |
| `dashboard.compoundChart.legend` | Geschätztes 1RM |  |  |
| `dashboard.compoundChart.title` | Compound-Lift-Trend |  |  |
| `dashboard.goal.line` | Ziel %@ kg |  |  |
| `dashboard.heatmap.legend` | Sätze |  |  |
| `dashboard.heatmap.title` | Muskel-Heatmap (Woche) |  |  |
| `dashboard.history.empty` | Noch keine Trainings — starte oben dein erstes. |  |  |
| `dashboard.history.title` | Trainingsverlauf |  |  |
| `dashboard.newMeasurement` | Neue Messung |  |  |
| `dashboard.openSession.cancel` | Abbrechen |  |  |
| `dashboard.openSession.dayName.unknown` | Unbekannt |  |  |
| `dashboard.openSession.discardAndStart` | Altes verwerfen & Neu starten |  |  |
| `dashboard.openSession.message.fallback` | Es gibt bereits eine offene Trainings-Session. |  |  |
| `dashboard.openSession.message.withInfo` | Es läuft noch eine Session vom %1$@ (%2$@). Was möchtest du tun? |  |  |
| `dashboard.openSession.resume` | Altes fortsetzen |  |  |
| `dashboard.openSession.title` | Laufende Session |  |  |
| `dashboard.plan.checkoffRestDay` | Tag im Plan abhaken |  |  |
| `dashboard.plan.checkoffRestDay.a11y` | Ruhetag im Plan abhaken, um morgen den nächsten Trainingstag anzuzeigen |  |  |
| `dashboard.plan.nextWorkout` | Nächstes Training |  |  |
| `dashboard.plan.noActivePlan` | Kein aktiver Plan |  |  |
| `dashboard.plan.noActivePlan.hint` | Lege im Plan-Tab deinen ersten Trainings-Plan an. |  |  |
| `dashboard.plan.planEmpty` | Plan noch leer |  |  |
| `dashboard.plan.planEmpty.hint` | Füge deinem aktiven Plan im Plan-Tab Tage und Übungen hinzu. |  |  |
| `dashboard.plan.restDay` | Heute ist Ruhetag. Zeit zur Erholung! |  |  |
| `dashboard.plan.tabShortcut` | Plan-Tab |  |  |
| `dashboard.plan.todayRestDay` | Heute: Ruhetag |  |  |
| `dashboard.recent.empty.hint` | Starte oben dein erstes Training. |  |  |
| `dashboard.recent.empty.title` | Noch keine Trainingseinheiten |  |  |
| `dashboard.recent.title` | Letzte Workouts |  |  |
| `dashboard.recent.viewAll` | Alle anzeigen |  |  |
| `dashboard.title` | Dashboard |  |  |
| `dashboard.trend.empty` | Trag deine erste Messung ein, um den Trend zu sehen. |  |  |
| `dashboard.trend.emptyDescription` | Tippe auf '+' oben rechts, um deinen ersten Wert einzutragen. |  |  |
| `dashboard.trend.emptyTitle` | Noch keine Messungen |  |  |
| `dashboard.trend.forecast.legend` | Prognose 4 / 8 W. |  |  |
| `dashboard.trend.insufficient` | %lld von 3 nötigen Messungen — Linear-Regression startet ab 3 Werten über mind. 1 Woche. |  |  |
| `dashboard.trend.needMore` | Mehr Werte über mind. 1 Woche für eine Prognose nötig. |  |  |
| `dashboard.trend.title` | Gewichts-Trend |  |  |
| `dashboard.trend.unstable` | Werte schwanken stark — Prognose ausgeblendet, bis sich der Trend stabilisiert. |  |  |
| `dashboard.trophy.empty` | Noch keine PRs — beende ein Workout, um den ersten zu setzen. |  |  |
| `dashboard.trophy.title` | Trophy Room |  |  |
| `dashboard.weeklySummary.distance` | Distanz |  |  |
| `dashboard.weeklySummary.title` | Diese Woche |  |  |
| `dashboard.weeklySummary.volume` | Volumen |  |  |

## `day_intensity.*`  (3 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `day_intensity.heavy` | Schwer | Heavy |  |
| `day_intensity.light` | Leicht | Light |  |
| `day_intensity.normal` | Normal | Normal |  |

## `day_type.*`  (13 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `day_type.arms` | Arme | Arms |  |
| `day_type.back` | Rücken | Back |  |
| `day_type.cardio` | Cardio / Run | Cardio / Run |  |
| `day_type.chest` | Brust | Chest |  |
| `day_type.custom` | Custom | Custom |  |
| `day_type.full_body` | Ganzkörper | Full Body |  |
| `day_type.legs` | Beine | Legs |  |
| `day_type.lower` | Unterkörper | Lower |  |
| `day_type.pull` | Pull | Pull |  |
| `day_type.push` | Push | Push |  |
| `day_type.rest` | Ruhetag | Rest |  |
| `day_type.shoulders` | Schultern | Shoulders |  |
| `day_type.upper` | Oberkörper | Upper |  |

## `difficulty.*`  (3 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `difficulty.advanced` | Profi | Advanced |  |
| `difficulty.beginner` | Anfänger | Beginner |  |
| `difficulty.intermediate` | Fortgeschritten | Intermediate |  |

## `environment.*`  (3 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `environment.gym` | Gym | Gym | Spor Salonu |
| `environment.home_gym` | Home-Gym | Home Gym |  |
| `environment.no_equipment` | Ohne Equipment | No Equipment |  |

## `equipment.*`  (7 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `equipment.band` | Widerstandsband | Resistance Band |  |
| `equipment.barbell` | Langhantel | Barbell |  |
| `equipment.bodyweight` | Körpergewicht | Bodyweight |  |
| `equipment.cable` | Kabel | Cable |  |
| `equipment.dumbbell` | Kurzhantel | Dumbbell |  |
| `equipment.kettlebell` | Kettlebell | Kettlebell |  |
| `equipment.machine` | Maschine | Machine |  |

## `measurement.*`  (80 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `measurement.action.delete` | Messung löschen | Delete Measurement | Ölçümü Sil |
| `measurement.action.done` | Fertig | Done | Tamam |
| `measurement.action.edit` | Bearbeiten | Edit | Düzenle |
| `measurement.action.save` | Messung speichern | Save Measurement | Ölçümü Kaydet |
| `measurement.action.saveEdit` | Änderungen speichern | Save Changes | Değişiklikleri Kaydet |
| `measurement.derived.bmi` | BMI | BMI | BKİ |
| `measurement.derived.bmr` | BMR | BMR | BMR |
| `measurement.derived.deurenberg` | KFA Deurenberg | Body Fat (Deurenberg) | Yağ Oranı (Deurenberg) |
| `measurement.derived.empty` | Trage Gewicht ein, um die Auswertung zu sehen. | Enter your weight to see the analysis. | Analizi görmek için ağırlığı gir. |
| `measurement.derived.fatfree` | Fettfreie Masse | Fat-Free Mass | Yağsız Kütle |
| `measurement.derived.ffmi` | FFMI | FFMI | FFMI |
| `measurement.derived.ffmiNorm` | Norm. FFMI | Norm. FFMI | Norm. FFMI |
| `measurement.derived.navy` | KFA Navy | Body Fat (Navy) | Yağ Oranı (Navy) |
| `measurement.derived.navy.fallback.female` | Hals/Taille/Hüfte erforderlich | Neck/Waist/Hip required | Boyun/Bel/Kalça gerekli |
| `measurement.derived.navy.fallback.male` | Hals/Taille erforderlich | Neck/Waist required | Boyun/Bel gerekli |
| `measurement.empty.description` | Lege erst dein Profil im Onboarding an, danach können wir Messwerte berechnen. | Set up your profile in onboarding first — then we can compute measurements. | Önce onboarding'de profilini oluştur — sonra ölçümleri hesaplayabiliriz. |
| `measurement.empty.title` | Kein Profil | No Profile | Profil Yok |
| `measurement.field.biceps` | Bizeps (cm) | Biceps (cm) | Pazı (cm) |
| `measurement.field.calf` | Wade (cm) | Calf (cm) | Baldır (cm) |
| `measurement.field.chest` | Brust (cm) | Chest (cm) | Göğüs (cm) |
| `measurement.field.hip` | Hüfte (cm) | Hip (cm) | Kalça (cm) |
| `measurement.field.neck` | Halsumfang (cm) | Neck (cm) | Boyun (cm) |
| `measurement.field.shoulder` | Schulter (cm) | Shoulder (cm) | Omuz (cm) |
| `measurement.field.shoulder.full` | Schulterumfang (cm) | Shoulder Circumference (cm) | Omuz Çevresi (cm) |
| `measurement.field.thigh` | Oberschenkel (cm) | Thigh (cm) | Uyluk (cm) |
| `measurement.field.waist` | Taille (cm) | Waist (cm) | Bel (cm) |
| `measurement.field.weight` | Gewicht (kg) | Weight (kg) | Ağırlık (kg) |
| `measurement.healthkit.blocked` | Apple Health blockiert. Ändere die Berechtigung in den iOS-Einstellungen. | Apple Health is blocked. Change the permission in iOS Settings. | Apple Health engellendi. İzni iOS Ayarları'ndan değiştir. |
| `measurement.healthkit.connect` | Apple Health verbinden | Connect Apple Health | Apple Health'e Bağlan |
| `measurement.healthkit.connected` | Verbunden | Connected | Bağlı |
| `measurement.healthkit.footer` | Bei Verbindung wird das aktuellste Waagen-Gewicht beim Öffnen vorausgefüllt. Beim Speichern werden Gewicht, KFA und FFM zurück nach Apple Health geschrieben. | When connected, the most recent scale weight is prefilled on open. On save, weight, body fat, and FFM are written back to Apple Health. | Bağlıyken açılışta en güncel tartı kilosu otomatik doldurulur. Kaydederken ağırlık, yağ oranı ve FFM Apple Health'e geri yazılır. |
| `measurement.healthkit.fromHealth` | Aus Apple Health übernommen | Taken from Apple Health | Apple Health'ten alındı |
| `measurement.healthkit.pullWeight` | Aktuelles Gewicht aus Apple Health | Pull current weight from Apple Health | Apple Health'ten güncel kiloyu al |
| `measurement.healthkit.unavailable` | Apple Health auf diesem Gerät nicht verfügbar. | Apple Health is not available on this device. | Apple Health bu cihazda mevcut değil. |
| `measurement.hint.broadest` | Es sollte an der breitesten Stelle abgenommen werden. | Measure at the widest point. | En geniş noktadan ölçülmelidir. |
| `measurement.hint.neck` | Messen Sie knapp unterhalb des Kehlkopfs, Band waagrecht und leicht anliegend. | Measure just below the larynx, tape horizontal and lightly snug. | Gırtlağın hemen altından, mezura yatay ve hafifçe gergin olacak şekilde ölçün. |
| `measurement.hint.waist.female` | Es sollte an der schmalsten Stelle entnommen werden. | Measure at the narrowest point. | En dar noktadan ölçülmelidir. |
| `measurement.hint.waist.male` | Im Bereich des Bauchnabels. | At the level of the navel. | Göbek hizasından. |
| `measurement.history.empty` | Noch keine Messungen — speichere oben deinen ersten Wert. | No measurements yet — save your first one above. | Henüz ölçüm yok — yukarıdan ilk değerini kaydet. |
| `measurement.history.hint` | Tippe einen Eintrag an, um die Werte zu bearbeiten. | Tap an entry to edit its values. | Değerleri düzenlemek için bir girişe dokun. |
| `measurement.history.older` | Älteste %lld Messungen ausgeblendet. | Older %lld measurements hidden. | En eski %lld ölçüm gizlendi. |
| `measurement.lastSaved.edit` | Zuletzt geändert: %@ | Last changed: %@ | Son değişiklik: %@ |
| `measurement.lastSaved.new` | Zuletzt gespeichert: %@ | Last saved: %@ | Son kayıt: %@ |
| `measurement.profile.age` | Alter | Age | Yaş |
| `measurement.profile.age.unit` | Jahre | Years | Yıl |
| `measurement.profile.goalWeight` | Zielgewicht | Goal Weight | Hedef Kilo |
| `measurement.profile.height` | Größe | Height | Boy |
| `measurement.profile.sex` | Geschlecht | Sex | Cinsiyet |
| `measurement.profile.sex.female` | Weiblich | Female | Kadın |
| `measurement.profile.sex.male` | Männlich | Male | Erkek |
| `measurement.ratio.swr.footer` | Goldener V-Schnitt ~ 1,618 (Schulter ≈ 1,6× Taille). SWR < 1,3 = wenig V-Form, > 1,5 = ausgeprägt. | Golden V-taper ≈ 1.618 (shoulder ≈ 1.6× waist). SWR < 1.3 = little V-shape, > 1.5 = pronounced. | Altın V-kesimi ≈ 1,618 (omuz ≈ 1,6× bel). SWR < 1,3 = az V-şekli, > 1,5 = belirgin. |
| `measurement.ratio.swr.medium` | Mittel | Medium | Orta |
| `measurement.ratio.swr.narrow` | Schmal | Narrow | Dar |
| `measurement.ratio.swr.pronounced` | Ausgeprägt | Pronounced | Belirgin |
| `measurement.ratio.swr.title` | SWR — Schulter/Taille | SWR — Shoulder/Waist | SWR — Omuz/Bel |
| `measurement.ratio.swr.vshape` | V-Shape | V-Shape | V-Şekli |
| `measurement.ratio.whr.borderline` | Grenzwert | Borderline | Sınırda |
| `measurement.ratio.whr.elevated` | Erhöht | Elevated | Yüksek |
| `measurement.ratio.whr.footer` | WHR < 0,80 = gesundes Risikoprofil bei Frauen. > 0,85 = erhöhtes Risiko. | WHR < 0.80 = healthy risk profile for women. > 0.85 = elevated risk. | WHR < 0,80 = kadınlarda sağlıklı risk profili. > 0,85 = artmış risk. |
| `measurement.ratio.whr.healthy` | Gesund | Healthy | Sağlıklı |
| `measurement.ratio.whr.title` | WHR — Taille/Hüfte | WHR — Waist/Hip | WHR — Bel/Kalça |
| `measurement.section.additional` | Weitere Umfänge | Additional Measurements | Ek Ölçümler |
| `measurement.section.additional.footer` | Diese Werte fließen NICHT in die KFA/Navy-Berechnung — sie dienen deinem persönlichen Progress-Tracking. | These values do NOT feed into the body-fat / Navy calculation — they're for your personal progress tracking. | Bu değerler yağ oranı / Navy hesabına dahil edilmez — sadece kişisel ilerlemeni takip etmen için. |
| `measurement.section.core` | Pflichtwerte | Required Values | Zorunlu Değerler |
| `measurement.section.core.footer.female` | Gewicht, Hals, Taille und Hüfte werden für die Navy-KFA-Berechnung benötigt. | Weight, neck, waist, and hip are required for the Navy body-fat calculation. | Navy yağ oranı hesabı için ağırlık, boyun, bel ve kalça gereklidir. |
| `measurement.section.core.footer.male` | Gewicht, Hals und Taille werden für die Navy-KFA-Berechnung benötigt. Schulter optional für das Schulter-zu-Taillen-Verhältnis. | Weight, neck, and waist are required for the Navy body-fat calculation. Shoulder is optional for the shoulder-to-waist ratio. | Navy yağ oranı hesabı için ağırlık, boyun ve bel gereklidir. Omuz, omuz-bel oranı için isteğe bağlıdır. |
| `measurement.section.derived` | Live-Auswertung | Live Analysis | Canlı Analiz |
| `measurement.section.healthkit` | Apple Health | Apple Health | Apple Health |
| `measurement.section.history` | Verlauf | History | Geçmiş |
| `measurement.section.profile` | Profil | Profile | Profil |
| `measurement.section.ratios` | Körper-Proportion | Body Proportion | Vücut Oranı |
| `measurement.title.detail` | Messung | Measurement | Ölçüm |
| `measurement.title.edit` | Messung bearbeiten | Edit Measurement | Ölçümü Düzenle |
| `measurement.title.new` | Neue Messung | New Measurement | Yeni Ölçüm |
| `measurement.validation.field.hip` | Hüfte | Hip | Kalça |
| `measurement.validation.field.neck` | Hals | Neck | Boyun |
| `measurement.validation.field.waist` | Taille | Waist | Bel |
| `measurement.validation.field.weight` | Gewicht | Weight | Ağırlık |
| `measurement.validation.missing.many` | Pflichtfelder noch leer: %@. | Required fields missing: %@. | Zorunlu alanlar eksik: %@. |
| `measurement.validation.missing.one` | Pflichtfeld noch leer: %@. | Required field missing: %@. | Zorunlu alan eksik: %@. |

## `metric.*`  (4 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `metric.ffmi` | FFMI |  |  |
| `metric.kfaNavy` | KFA Navy |  |  |
| `metric.weeklyDelta.suffix` | / Wo. |  |  |
| `metric.weight` | Gewicht |  |  |

## `muscle.*`  (10 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `muscle.back` | Rücken | Back |  |
| `muscle.biceps` | Bizeps | Biceps |  |
| `muscle.calves` | Waden | Calves |  |
| `muscle.chest` | Brust | Chest |  |
| `muscle.core` | Core | Core |  |
| `muscle.glutes` | Gesäß | Glutes |  |
| `muscle.hamstrings` | Hamstrings | Hamstrings |  |
| `muscle.quads` | Quadrizeps | Quadriceps |  |
| `muscle.shoulders` | Schultern | Shoulders |  |
| `muscle.triceps` | Trizeps | Triceps |  |

## `onboarding.*`  (13 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `onboarding.action.create` | Profil anlegen | Create profile | Profil Oluştur |
| `onboarding.coaching.title` | Dein Coaching-Stil | Your coaching style | Koçluk tarzın |
| `onboarding.field.birthdate` | Geburtsdatum | Birth date |  |
| `onboarding.field.environment` | Trainingsort | Training Location |  |
| `onboarding.field.goal_weight` | Zielgewicht (kg, optional) | Goal weight (kg, optional) |  |
| `onboarding.field.height` | Größe (cm) | Height (cm) |  |
| `onboarding.field.sex` | Geschlecht | Sex |  |
| `onboarding.intro.body` | Für akkurate Berechnungen (BMI, KFA, FFMI, BMR) brauchen wir Sex, Alter und Größe. Alle Werte kannst du später unter Profil ändern. | For accurate calculations (BMI, body-fat, FFMI, BMR) we need sex, age, and height. You can change everything later in your profile. |  |
| `onboarding.intro.title` | Lass uns starten | Let's get started |  |
| `onboarding.section.body` | Körpermaße | Body Measurements |  |
| `onboarding.section.goals` | Ziel & Training | Goals & Training |  |
| `onboarding.section.profile` | Profil | Profile |  |
| `onboarding.title` | Willkommen | Welcome | Hoş Geldin |

## `settings.*`  (12 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `settings.action.reset` | App zurücksetzen | Reset App |  |
| `settings.confirm.reset.action` | Alles löschen | Delete everything |  |
| `settings.confirm.reset.message` | Profil, alle Messungen, Pläne und Workout-Sessions gehen UNWIDERRUFLICH verloren. Die App startet danach im Onboarding. | Profile, all measurements, plans, and workouts will be IRRECOVERABLY lost. The app will start in onboarding. |  |
| `settings.confirm.reset.title` | App wirklich zurücksetzen? | Really reset the app? |  |
| `settings.preferences.units` | Einheiten | Units |  |
| `settings.preferences.units.imperial` | Imperial (lbs / in) | Imperial (lbs / in) |  |
| `settings.preferences.units.metric` | Metrisch (kg / cm) | Metric (kg / cm) |  |
| `settings.section.about` | Über | About |  |
| `settings.section.danger_zone` | Daten-Management | Data Management |  |
| `settings.section.preferences` | Präferenzen | Preferences |  |
| `settings.section.profile_goals` | Profil & Ziele | Profile & Goals |  |
| `settings.title` | Einstellungen | Settings | Ayarlar |

## `sex.*`  (2 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `sex.female` | Weiblich | Female | Kadın |
| `sex.male` | Männlich | Male | Erkek |

## `summary.*`  (2 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `summary.action.finish` | Speichern & zum Dashboard | Save & to dashboard |  |
| `summary.hero.title` | Workout abgeschlossen | Workout completed | Antrenman Tamamlandı |

## `tab.*`  (5 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `tab.calculators` | Rechner | Tools | Araçlar |
| `tab.dashboard` | Dashboard | Dashboard | Panel |
| `tab.measurement` | Messung | Measurement | Ölçüm |
| `tab.more` | Mehr | More | Daha Fazla |
| `tab.plan` | Plan | Plan | Plan |

## `trophy.*`  (9 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `trophy.action.detect` | Aus History detektieren | Detect from history | Geçmişten tespit et |
| `trophy.action.rebuild` | Aus History neu berechnen | Rebuild from history | Geçmişten yeniden hesapla |
| `trophy.empty.title` | Noch keine Rekorde | No records yet | Henüz rekor yok |
| `trophy.kind.bestSet` | Bestsatz | Best Set | En İyi Set |
| `trophy.kind.estimated1RM` | 1RM | 1RM |  |
| `trophy.kind.heaviestWeight` | Max-Gewicht | Top Weight | Maks. Ağırlık |
| `trophy.kind.maxHoldSeconds` | Bestzeit | Best Hold | En İyi Süre |
| `trophy.kind.maxReps` | Max Wdh. | Max Reps | Maks. Tekrar |
| `trophy.title` | Trophy Room | Trophy Room | Rekor Odası |


---

## 🔢 Plural-Keys (one/other-Varianten)

Diese Keys haben Plural-Varianten — beide Formen müssen übersetzt werden.


### `%lld Rekorde`

| Sprache | one | other |
|---|---|---|
| Deutsch | %lld Rekord | %lld Rekorde |
| English |  |  |
| Türkçe |  |  |


---

# 🚧 Hartkodierte deutsche Strings (noch nicht im Catalog)

Stand: 195 hartkodierte deutsche Strings über 24 Dateien gefunden (per Heuristik — false positives möglich, deshalb wird beim Refactor jede Stelle nochmal geprüft).

Diese Strings müssen in einem späteren i18n-Sweep (DEL-073 Phase 2-4) nach `Localizable.xcstrings` migriert werden. Reihenfolge per Ticket-Priorität:

1. Active Workout (ActiveWorkoutView, ExerciseCard, SetRow, WorkoutSummaryView)
2. Plan-Editor (PlanEditorView, DayEditorView, ProgramTemplatePickerView)
3. Library (ExerciseLibraryData, Domain-Enum-Labels)


## `OnboardingView.swift`  (23 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 145 | Schließen |  |  |
| 217 | Wenn du Apple Health verbindest, ziehe ich Alter, Geschlecht, Größe und aktuelles Gewicht aus deinem Profil — du musst es nicht doppelt tippen. Du kannst diesen Schritt auch überspringen und alles manuell eingeben. |  |  |
| 223 | Apple Health ist auf diesem Gerät nicht verfügbar. |  |  |
| 251 | Daten übernommen — du kannst sie im nächsten Schritt prüfen und anpassen. |  |  |
| 261 | Daten aus Apple Health übernehmen |  |  |
| 290 | Apple Health-Berechtigung verweigert. Du kannst sie später in iOS-Einstellungen → Datenschutz → Apple Health → Deltiq aktivieren. |  |  |
| 339 | Körperdaten |  |  |
| 342 | Gewicht muss > 0 sein. |  |  |
| 370 | Trainingsort filtert später Plan-Empfehlungen und die Equipment-Auswahl beim Übungs-Tausch. |  |  |
| 371 | Hybrid- oder reine Lauf-Athleten wählen ihren Strength-Ort (z.B. Gym) — die Hybrid-Pläne enthalten ihre Run-Tage unabhängig davon. |  |  |
| 393 | Was ist dein primärer Fokus? |  |  |
| 395 | Wir kalibrieren Insights, Recovery-Hinweise und Coaching-Botschaften entsprechend. |  |  |
| 416 | Wie soll dein Coach klingen? |  |  |
| 418 | Wir passen Tonfall und Feedback an deinen Stil an. Lässt sich später jederzeit ändern. |  |  |
| 496 | Wasser-Erinnerung |  |  |
| 499 | Mess-Erinnerung |  |  |
| 504 | Beide nutzen lokale Notifications. Wenn du sie aktivierst, fragt iOS einmalig nach der Notification-Berechtigung. |  |  |
| 523 | Plan finden lassen |  |  |
| 540 | Empfohlen, wenn du nicht weißt, welcher Plan zu dir passt. Du kannst stattdessen auch direkt aus der Liste unten wählen. |  |  |
| 546 | Keine Templates für '\(environmentLabel)'. Du kannst trotzdem ohne Plan starten und später einen eigenen anlegen. |  |  |
| 564 | Trainingsplan für \(environmentLabel) |  |  |
| 566 | Templates sind nach deinem Trainingsort gefiltert (\(environmentLabel)) — passende Bodyweight-Pläne für 'Ohne Equipment', Hantel-/Maschinen-Pläne für 'Gym'. Optional — auch ohne Plan starten ist okay. |  |  |
| 629 | Zurück |  |  |

## `ActiveWorkoutView.swift`  (20 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 164 | Übung |  |  |
| 227 | Die Session und alle \(loggedSetsCount) bisher geloggten Sätze gehen verloren. |  |  |
| 325 | Du hattest gestern eine harte Einheit |  |  |
| 327 | Erwäge heute, dein Ziel-RIR bei Beinübungen um +1 zu erhöhen, um dein ZNS nicht zu überlasten. |  |  |
| 344 | Banner schließen |  |  |
| 509 | Diese Session hat keine Übungen. |  |  |
| 511 | Vermutlich wurde der Plan-Tag nach dem Start geleert. Du kannst die Session verwerfen oder ohne Sätze beenden. |  |  |
| 542 | Dein Workout ist noch leer |  |  |
| 544 | Such dir aus der Library eine Übung — alles weitere passiert wie im Plan-Workout. |  |  |
| 557 | Übung hinzufügen |  |  |
| 567 | Workout abbrechen |  |  |
| 637 | Set-Logging mit Vorgaben & Rest-Timer • Live Activities folgen im Xcode-Target. |  |  |
| 1001 | Workout beenden |  |  |
| 1007 | Abbrechen |  |  |
| 1023 | Verwendete Ausrüstung |  |  |
| 1068 | Dein Workout |  |  |
| 1097 | Wie hat sich das Training angefühlt? |  |  |
| 1099 | Die App nutzt das fuer die Progression: Wenn du am Limit warst, halten wir das Gewicht stabil — kein Zwangs-Plus. |  |  |
| 1128 | Kein Gewichts-Plus im nächsten Workout |  |  |
| 1157 | Workout speichern |  |  |

## `DayEditorView.swift`  (18 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 96 | Plan auf \(environmentLabel(conflict.requiredEnv)) umstellen |  |  |
| 103 | Nur Übung hinzufügen |  |  |
| 107 | Abbrechen |  |  |
| 138 | Speichern & neu starten |  |  |
| 144 | Abbrechen |  |  |
| 149 | Es gibt bereits ein angefangenes Training. |  |  |
| 172 | Regeneration ist Teil des Plans. Hak den Tag ab, wenn du durch bist — dein Plan-Pointer springt automatisch zum naechsten echten Training. |  |  |
| 186 | Ruhetag abschließen |  |  |
| 240 | Nächste Intensität |  |  |
| 249 | Dieser Tag gehört zu einem vorgefertigten Plan-Template und kann strukturell nicht bearbeitet werden. Du kannst aber die Trainings-Intensität anpassen. |  |  |
| 265 | Ruhetag abschließen |  |  |
| 271 | Markiert den Ruhetag als erledigt — kein leerer Eintrag in der History, aber der Plan-Pointer rückt zum nächsten echten Training. |  |  |
| 281 | Training starten |  |  |
| 289 | Füge erst mindestens eine Übung hinzu, dann kannst du das Training starten. |  |  |
| 348 | Übungen |  |  |
| 354 | Hinzufügen |  |  |
| 361 | Template-Plan — Übungen sind festgelegt. Du kannst sie ansehen, aber nicht hinzufügen, entfernen oder umsortieren. |  |  |
| 364 | Tippe eine Übung an um sie zu bearbeiten. „Bearbeiten“ oben rechts aktiviert die Drag-Handles zum Umsortieren — Superset-Partner werden automatisch mit verschoben. |  |  |

## `ProfileEditorView.swift`  (17 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 112 | Ja, Pläne anpassen |  |  |
| 120 | Du hast deinen Trainingsort auf \(environmentLabel(swap.newEnv)) geändert. Sollen deine bestehenden Trainingspläne automatisch an das dort verfügbare Equipment angepasst werden? |  |  |
| 142 | Wir haben Original-Übungen aus einem früheren Equipment-Wechsel gespeichert. Möchtest du diese in deinen Plänen wiederherstellen (inkl. der letzten Arbeitsgewichte)? |  |  |
| 212 | Apple Health nicht verfügbar. |  |  |
| 224 | Aus Apple Health übernehmen |  |  |
| 229 | Aus Apple Health übernommen: \(healthKitFilledFields.sorted().joined(separator:  |  |  |
| 257 | Pre-fill von Geburtsdatum, Geschlecht und Größe aus dem Apple-Health-Profil. Manuelle Eingaben werden NICHT überschrieben, wenn sie schon plausible Werte haben. |  |  |
| 301 | Männlich |  |  |
| 313 | Geburtsdatum |  |  |
| 318 | Sex steuert die Navy/Deurenberg-Formeln; das Alter geht in Mifflin-St-Jeor-BMR und Deurenberg ein. |  |  |
| 327 | Größe (cm) |  |  |
| 331 | Körpermasse |  |  |
| 338 | Alle Berechnungen lesen Höhe metrisch aus dieser Quelle. |  |  |
| 355 | Ohne Equipment |  |  |
| 360 | Ziel & Training |  |  |
| 362 | Das Zielgewicht erscheint als grüne Linie im Dashboard-Trend-Chart. Trainingsort filtert später Plan-Empfehlungen. |  |  |
| 400 | Steuert Tonfall und Inhalt der Coaching-Insights auf dem Dashboard. Lässt sich jederzeit ändern. |  |  |

## `PlanEditorView.swift`  (17 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 119 | Für alle anpassen |  |  |
| 124 | Nur für diesen Plan |  |  |
| 128 | Abbrechen |  |  |
| 133 | Du hast mehrere aktive Pläne. Soll dein globaler Trainingsort und deine anderen aktiven Pläne ebenfalls auf \(environmentLabel(swap.newEnv)) geändert werden? |  |  |
| 144 | Übungen anpassen |  |  |
| 148 | Nur Trainingsort ändern |  |  |
| 151 | Abbrechen |  |  |
| 157 | Sollen die Übungen an deinen neuen Trainingsort angepasst werden? Übungen ohne passende Alternative bleiben im Plan und brauchen manuelle Anpassung. |  |  |
| 177 | Abbrechen |  |  |
| 182 | Wir haben gespeicherte Original-Übungen aus einem früheren Equipment-Wechsel gefunden. Möchtest du diese wiederherstellen (inkl. der letzten Arbeitsgewichte aus der Historie), statt das aktuelle Setup neu anzupassen? |  |  |
| 292 | Struktur ist festgelegt. Du kannst Trainingsort und Wochen anpassen, aber Name/Tage/Übungen nicht ändern. |  |  |
| 318 | Wochen |  |  |
| 324 | Ohne Equipment |  |  |
| 327 | Als aktiven Plan setzen |  |  |
| 338 | RIR ≤ 0 (zum Versagen) |  |  |
| 381 | Trainings-Tage |  |  |
| 401 | Hinzufügen |  |  |

## `GearListView.swift`  (11 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 25 | Noch keine Ausrüstung |  |  |
| 27 | Lege deine Laufschuhe an, damit die App deine Kilometer automatisch trackt. |  |  |
| 48 | Cardio-Workouts buchen ihre Distanz automatisch auf den im Finish-Sheet ausgewaehlten Schuh. |  |  |
| 53 | Ausrüstung |  |  |
| 62 | Hinzufügen |  |  |
| 114 | Schuh erneuern — Dämpfung erschöpft. |  |  |
| 156 | Aktiv (im Picker anbieten) |  |  |
| 172 | Distanz |  |  |
| 174 | Laufschuhe verlieren nach ~600–800 km ihre Dämpfung. Bei Erreichen des Maximums warnt die App. |  |  |
| 184 | Abbrechen |  |  |
| 187 | Speichern |  |  |

## `SettingsView.swift`  (11 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 123 | Kein Profil vorhanden — App neu starten oder zurücksetzen. |  |  |
| 172 | Ausrüstung & Schuhe |  |  |
| 183 | Die DB speichert immer metrisch. Diese Einstellung steuert nur die Anzeige in Eingabe-Feldern, im Hantel-Rechner und auf den Karten. |  |  |
| 202 | Greift in alle Views der App. 'System' folgt der iOS-Einstellung. |  |  |
| 232 | Wird beim Ablauf des Pausen-Timers ausgeloest. Vibrations-Toggle hat auf iPads keine Wirkung. 'PR-Feiern' steuert Save-Screen-Popups, Live-Activity-Headline und lokale Benachrichtigungen — die Bestleistungen werden trotzdem im Trophy-Room gespeichert. |  |  |
| 248 | Wenn aus, werden Warmup- und Cooldown-Übungen während der Session ausgeblendet. Die Templates und deine Plan-Editierung bleiben unverändert — der Toggle wirkt nur auf den Live-Workout-Flow. Warmups sind ohnehin nie Pflicht: der „Workout speichern“-Button bleibt immer klickbar, auch wenn du sie nicht abhakst. |  |  |
| 320 | Lokale Benachrichtigungen — keine Server-Verbindung. Tippen auf eine Erinnerung öffnet direkt den passenden Tab. |  |  |
| 375 | Bei aktivierter Verbindung wird im Messwerte-Formular das letzte Waagen-Gewicht vorausgefüllt. Beim Speichern werden Gewicht, KFA und Magere Masse zurück nach Apple Health geschrieben. |  |  |
| 405 | Nicht verfügbar |  |  |
| 418 | In iOS-Einstellungen öffnen |  |  |
| 456 | Löscht Profil, Messungen, Pläne, Trainings-Templates und Workout-Sessions vollständig. Die Apple-Health-Daten bleiben erhalten — die löscht du in der Health-App selber. |  |  |

## `PlansListView.swift`  (10 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 45 | Laufendes Training |  |  |
| 47 | Tippe auf das Banner, um mit der Session weiterzumachen oder sie zu beenden. |  |  |
| 77 | Plan |  |  |
| 84 | Aus Template anlegen |  |  |
| 89 | Leerer Plan |  |  |
| 92 | Neuer Plan |  |  |
| 104 | Noch kein Plan |  |  |
| 106 | Lege deinen ersten Trainings-Plan an — Tage, Übungen, Sätze. Der Plan ist die Grundlage für jede Session. |  |  |
| 118 | Aus Template |  |  |
| 238 | Aktiv |  |  |

## `WorkoutSummaryView.swift`  (9 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 110 | Datum |  |  |
| 196 | Erkannt durch Vergleich mit allen vorherigen abgeschlossenen Sessions. Cardio bleibt aussen vor — andere Metrik-Domäne. |  |  |
| 223 | Ziel erreicht? Die App passt das Gewicht fürs nächste Workout automatisch an. Aenderbar pro Übung im Editor. |  |  |
| 289 | Wie war's? Schmerzen, Pump, Performance ... |  |  |
| 298 | Tauchen später in der History pro Session auf — gut für Form-Cues und Verletzungs-Tracking. |  |  |
| 308 | Keine Sätze geloggt. |  |  |
| 374 | Die Session ist bereits gespeichert. Der Button schliesst die Zusammenfassung und bringt dich zurück aufs Dashboard. |  |  |
| 746 | Satz \(log.setIndex + 1) |  |  |
| 764 | Satz \(log.setIndex + 1) |  |  |

## `OneRepMaxView.swift`  (6 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 40 | Gewicht (\(unit)) |  |  |
| 50 | Gültig für 1-36 Reps. Bei sehr hohen Reps wird die Schätzung unzuverlässig — die Formeln liefern nur für den Hypertrophie- bis Kraft-Bereich (~1-12 Reps) brauchbare Werte. |  |  |
| 66 | Trag Gewicht > 0 ein. |  |  |
| 92 | Tabelle erscheint, sobald 1RM berechnet ist. |  |  |
| 97 | Trainings-Last (vom Mittelwert-1RM) |  |  |
| 99 | Rep-Hints sind Faustwerte. Effektive Reps hängen vom Trainings-Status und der Bewegung ab. |  |  |

## `TDEEView.swift`  (6 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 35 | Lege erst dein Profil im Onboarding an. |  |  |
| 60 | Größe |  |  |
| 69 | Gewicht (kg) |  |  |
| 78 | Aktivität |  |  |
| 81 | Aktuelles Gewicht & Aktivität |  |  |
| 113 | Trag dein aktuelles Gewicht ein. |  |  |

## `PRHistoryView.swift`  (6 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 58 | Aus History neu berechnen |  |  |
| 67 | Abbrechen |  |  |
| 72 | Setzt alle gespeicherten Rekorde zurück und detektiert sie aus deiner kompletten History neu. Nützlich nach gelöschten Sessions. |  |  |
| 91 | Noch keine Rekorde |  |  |
| 101 | Aus History detektieren |  |  |
| 324 | Nur ein \(PRKindStyle.shortLabel(chartKind))-Eintrag — Trend ab 2 Rekorden. |  |  |

## `ExerciseEditorView.swift`  (6 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 61 | Template-Uebung — Name und Cardio/Zeit-Flags sind festgelegt. |  |  |
| 76 | Sätze |  |  |
| 102 | Pause |  |  |
| 146 | Fertig |  |  |
| 156 | Distanz (km) |  |  |
| 199 | Aus = das Gewicht wird nie automatisch geaendert. Du behaeltst die volle Kontrolle. |  |  |

## `ExercisePickerView.swift`  (6 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 55 | Übung wählen |  |  |
| 61 | Abbrechen |  |  |
| 76 | Nur Übungen für \(environmentLabel(env)) |  |  |
| 80 | Wenn aus, siehst du auch Übungen, die zu deinem Plan-Typ nicht passen. Die App fragt dann beim Hinzufügen nach, ob du den Plan umstellen willst. |  |  |
| 99 | Name (z.B. Bankdrücken) |  |  |
| 125 | Bibliothek ist leer — leg oben deine erste eigene Übung an. |  |  |

## `OnboardingQuizView.swift`  (5 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 66 | Plan finden |  |  |
| 72 | Abbrechen |  |  |
| 218 | TOP EMPFEHLUNG FÜR DICH |  |  |
| 253 | Diesen Plan wählen |  |  |
| 308 | Zurück |  |  |

## `ProgramTemplatePickerView.swift`  (5 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 53 | Gefiltert nach deinem Trainingsort (\(userEnvironmentLabel)). Im Profil anpassen, wenn du auch andere Plaene sehen willst. |  |  |
| 57 | Programm wählen |  |  |
| 63 | Abbrechen |  |  |
| 268 | Tag \(day.sequenceIndex) |  |  |
| 294 | Beim Übernehmen wird eine Tiefkopie für deine eigene Bibliothek angelegt — Tage, Übungen, Sätze sind danach frei editierbar. |  |  |

## `PlateCalculatorView.swift`  (4 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 45 | Einheit |  |  |
| 51 | App-weit umschaltbar. DB speichert immer metrisch — nur die Anzeige ändert sich. |  |  |
| 102 | Mit deinem Inventar nur \(formatPlate(actualTotal)) \(unit.rawValue) erreichbar (\(formatDelta(targetDelta))). |  |  |
| 118 | Inventar zurücksetzen |  |  |

## `DayPickerSheet.swift`  (4 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 56 | Trainingstage wählen |  |  |
| 62 | Abbrechen |  |  |
| 72 | Wähle exakt \(requiredDayCount) Tage, an denen du trainieren möchtest. |  |  |
| 160 | Plan starten |  |  |

## `SetRow.swift`  (4 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 380 | Satz \(setIndex + 1) |  |  |
| 442 | Beende oder stoppe die laufende Übung zuerst. |  |  |
| 997 | Hantel-Aufladung |  |  |
| 1018 | Keine Aufladung — bleib bei der leeren Stange. |  |  |

## `WaterTrackerView.swift`  (3 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 42 | Heute zurücksetzen |  |  |
| 75 | Tagesziel = Gewicht × 35 ml. Quelle: \(targetSourceLabel). |  |  |
| 145 | Trag deinen ersten Schluck mit den Buttons oben ein. |  |  |

## `CalculatorsView.swift`  (1 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 47 | Alle Rechner nutzen die gleiche Domain-Logik (FitnessAppCore) wie der Rest der App — Werte sind 1:1 mit Dashboard und MeasurementView. |  |  |

## `WorkoutHistoryView.swift`  (1 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 28 | Beende dein erstes Training, um deine Historie zu sehen. |  |  |

## `ExerciseCard.swift`  (1 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 50 | Alle Sätze erledigt |  |  |

## `RestTimerBar.swift`  (1 Strings)

| Line | Deutsch (DE) | EN (übersetzen) | TR (übersetzen) |
|---|---|---|---|
| 91 | Pause überspringen |  |  |
