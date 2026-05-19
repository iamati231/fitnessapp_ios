# Deltiq — Translation Source-of-Truth

**Gesamt: 445 Keys im String Catalog + 195 noch hartkodierte Strings im Code.**

## Coverage-Status (Catalog)

| Sprache | Übersetzt | Fehlt |
|---|---|---|
| 🇩🇪 Deutsch (DE) | **445 / 445** (100%) | 0 |
| 🇬🇧 English (EN) | **445 / 445** (100%) | 0 |
| 🇹🇷 Türkçe (TR) | **445 / 445** (100%) | 0 |

Wenn du EN/TR aktualisierst:
- Per Xcode: öffne `Sources/FitnessAppUI/Resources/Localizable.xcstrings`, Apple's String-Catalog-Editor markiert „needs translation" automatisch.
- Per CSV-Export aus dieser Tabelle → ChatGPT / DeepL → zurück in die xcstrings importieren.
- Per direktem JSON-Edit (vorsichtig, JSON-Syntax muss valide bleiben).

Quelle: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`

Tabellenformat: leere EN/TR-Spalten brauchen Übersetzung. Plural-Keys sind separat aufgelistet — die haben one/other-Varianten.


## `active.*`  (4 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `active.action.discard` | Verwerfen | Discard | Sil |
| `active.action.save` | Training speichern | Save workout | Antrenmanı Kaydet |
| `active.confirm.discard.title` | Training verwerfen? | Discard workout? | Antrenmanı silmek istiyor musun? |
| `active.confirm.finish.title` | Training abschließen? | Finish workout? | Antrenmanı bitirelim mi? |

## `coaching.*`  (20 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `coaching.cnsOverloaded.analytical.hybrid` | Akkumulierte ZNS-Last über Schwelle. Heute kein high-intensity Cardio + keine schweren Compounds. Skill-Work und Mobility sind okay. | Accumulated CNS load over threshold. Skip high-intensity cardio and heavy compounds today. Skill work and mobility are fine. | Birikmiş MSS yükü eşiğin üzerinde. Bugün yüksek yoğunluklu kardiyo ve ağır temel hareketlere ara ver. Teknik çalışması ve mobilite uygundur. |
| `coaching.cnsOverloaded.analytical.hypertrophy` | CNS-Score erhöht. Hypertrophie-Reize sind noch produktiv, aber Pause Compound-Lifts und fokussiere Maschinen-Isolation. | CNS load elevated. Hypertrophy stimuli are still productive, but pause compound lifts and focus on machine isolation. | MSS yükü artmış. Hipertrofi uyarıları hâlâ verimli, ancak temel hareketlere ara ver ve makineli izolasyona odaklan. |
| `coaching.cnsOverloaded.analytical.strength` | ZNS-Belastung >90%. Schwere 1RM-Versuche sind heute statistisch ineffizient. Reduziere die Intensität. | CNS load >90%. Heavy 1RM attempts are statistically inefficient today. Reduce intensity. | MSS yükü %90 üzerinde. Bugün ağır 1RM denemeleri istatistiksel olarak verimsiz. Yoğunluğu azalt. |
| `coaching.cnsOverloaded.motivating.hypertrophy` | Du hast extrem hart gearbeitet! Gönn deinem Nervensystem etwas Ruhe und fokussiere dich heute auf leichte Isolationsübungen. | You've worked incredibly hard! Give your nervous system some rest and focus on light isolation exercises today. | Çok sıkı çalıştın! Bugün sinir sistemine biraz dinlenme ver ve hafif izolasyon hareketlerine odaklan. |
| `coaching.cnsOverloaded.strict.hybrid` | Rote Zone. Dein Nervensystem ist durch. Keine schweren Kettlebell-Swings heute. Mach Mobility oder mach Pause. | Red zone. Your nervous system is fried. No heavy kettlebell swings today. Mobility work — or rest. | Kırmızı bölge. Sinir sistemin bitik. Bugün ağır kettlebell swing yok. Mobilite ya da dinlen. |
| `coaching.newPR.analytical.hybrid` | Leistungssteigerung erkannt. Neues Volumen-PR im Functional-Zirkel erreicht. Progression verläuft nach Plan. | Performance increase detected. New volume PR achieved in the functional circuit. Progression is on track. | Performans artışı tespit edildi. Fonksiyonel devrede yeni hacim PR'ı. İlerleme plan dahilinde. |
| `coaching.newPR.analytical.hypertrophy` | Neuer Volumen-PR registriert. Progressiver Overload greift — beim nächsten Mikro-Zyklus +1 Set oder +2 Wdh planen. | New volume PR logged. Progressive overload is working — plan +1 set or +2 reps for the next micro-cycle. | Yeni hacim PR'ı kaydedildi. Aşamalı yüklenme işliyor — bir sonraki mikro döngüde +1 set veya +2 tekrar planla. |
| `coaching.newPR.analytical.strength` | Neuer Top-Set-PR. Estimated 1RM aktualisiert. Trainingsmaxima werden im Hintergrund neu kalibriert. | New top-set PR. Estimated 1RM updated. Training maxes are being recalibrated in the background. | Yeni en üst set PR'ı. Tahmini 1RM güncellendi. Antrenman maksimumları arka planda yeniden hesaplanıyor. |
| `coaching.newPR.motivating.strength` | Unglaubliche Leistung! Neuer PR auf der Stange. Genau so funktioniert progressiver Overload — feier deinen Erfolg! | Incredible performance! New PR on the bar. That's how progressive overload works — celebrate your win! | Muhteşem performans! Barda yeni PR. Aşamalı yüklenme tam olarak böyle çalışır — başarını kutla! |
| `coaching.newPR.strict.hypertrophy` | Neuer PR. Gut. Aber werd nicht übermütig — die Technik muss auch im nächsten Zyklus zu 100% sitzen. Weiterarbeiten. | New PR. Good. But don't get cocky — technique still has to be 100% in the next cycle. Keep working. | Yeni PR. İyi. Ama kibre kapılma — sonraki döngüde de teknik %100 oturmalı. Çalışmaya devam. |
| `coaching.plateauDetected.analytical.hybrid` | Plateau über 3+ Wochen. Reiz-Wechsel: Tempo, ROM oder Übungs-Substitut — danach 5–7 Tage Deload. | Plateau over 3+ weeks. Switch the stimulus: tempo, ROM, or exercise substitute — then a 5–7 day deload. | 3+ haftadır plato. Uyarıyı değiştir: tempo, hareket aralığı veya hareket değişimi — ardından 5–7 günlük deload. |
| `coaching.plateauDetected.analytical.hypertrophy` | Stagnation seit 3 Wochen erkannt. Eine Anpassung der Übungsauswahl oder eine Deload-Woche wird empfohlen. | Stagnation detected for 3 weeks. Adjusting exercise selection or a deload week is recommended. | 3 haftalık durağanlık tespit edildi. Hareket seçimini değiştirmek veya bir deload haftası önerilir. |
| `coaching.plateauDetected.analytical.strength` | Top-Set-Progression flacht ab. Variante einbauen (Pin Press, Block Pull) oder Deload-Woche, dann zurück zum Haupt-Lift. | Top-set progression is flattening. Add a variant (pin press, block pull) or take a deload week, then return to the main lift. | En üst set ilerlemesi düzleşiyor. Varyant ekle (pin press, block pull) veya deload haftası al, sonra ana harekete dön. |
| `coaching.plateauDetected.motivating.hybrid` | Völlig normal, mal auf der Stelle zu treten! Lass uns den Reiz ändern — probier ein neues Movement-Pattern aus. | Totally normal to hit a wall every now and then! Let's change the stimulus — try a new movement pattern. | Arada bir duraklamak son derece normal! Hadi uyarıyı değiştirelim — yeni bir hareket kalıbı dene. |
| `coaching.plateauDetected.strict.strength` | Du hängst fest. Entweder isst du zu wenig, schläfst zu schlecht, oder dein Plan braucht einen Reset. Zeit für einen Deload. | You're stuck. Either you're under-eating, under-sleeping, or your plan needs a reset. Time for a deload. | Sıkıştın. Ya yeterince yemiyorsun, ya uyumuyorsun, ya da planının sıfırlanması gerekiyor. Deload zamanı. |
| `coaching.restDay.analytical.hybrid` | Ruhetag im Plan. Optional ein lockerer Aerob-Block (Z2, 30–45 Min) zur aktiven Erholung — sonst Pause. | Rest day in your plan. Optional easy aerobic block (Z2, 30–45 min) for active recovery — otherwise, take it off. | Planında dinlenme günü. İsteğe bağlı kolay aerobik blok (Z2, 30–45 dk) aktif iyileşme için — yoksa tamamen dinlen. |
| `coaching.restDay.analytical.hypertrophy` | Regenerationsphase aktiv. Muskelproteinsynthese läuft. Nächstes Training ist für morgen angesetzt. | Recovery phase active. Muscle protein synthesis is running. Your next workout is scheduled for tomorrow. | İyileşme aşaması aktif. Kas protein sentezi devam ediyor. Sonraki antrenman yarın için planlandı. |
| `coaching.restDay.analytical.strength` | Recovery-Tag. Dein ZNS arbeitet jetzt — das nächste 1RM wird heute, nicht im Gym, vorbereitet. | Recovery day. Your CNS is working now — your next 1RM is prepared today, not in the gym. | İyileşme günü. MSS şu an çalışıyor — sonraki 1RM bugün hazırlanır, salonda değil. |
| `coaching.restDay.motivating.hybrid` | Du hast dir eine Pause verdient! Ein leichter Mobility-Flow oder Spaziergang ist heute perfekt für deine aktive Erholung. | You've earned a break! A light mobility flow or a walk is perfect for active recovery today. | Bir mola hak ettin! Bugün hafif bir mobilite akışı veya yürüyüş aktif iyileşme için ideal. |
| `coaching.restDay.strict.strength` | Heute wird nicht trainiert. Du wirst in der Pause stärker, nicht unter der Hantel. Bleib aus dem Gym. | No training today. You get stronger on rest days, not under the barbell. Stay out of the gym. | Bugün antrenman yok. Halterin altında değil, dinlenme günlerinde güçlenirsin. Salona girme. |

## `common.*`  (4 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `common.cancel` | Abbrechen | Cancel | İptal |
| `common.discard` | Verwerfen | Discard | Sil |
| `common.done` | Fertig | Done | Bitti |
| `common.save` | Speichern | Save | Kaydet |

## `dashboard.*`  (52 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `dashboard.action.adHoc.a11y` | Spontanes Workout starten — leere Session ohne Plan-Anbindung | Start a spontaneous workout — empty session without plan attachment | Spontane antrenman başlat — plana bağlı olmayan boş oturum |
| `dashboard.action.adHoc.primary` | Spontanes Workout starten | Start spontaneous workout | Spontane antrenman başlat |
| `dashboard.action.adHoc.secondary` | Vom Plan abweichen — Spontanes Workout | Skip the plan — spontaneous workout | Plandan sap — spontane antrenman |
| `dashboard.action.resumeRunning` | Laufendes Training fortsetzen | Resume running workout | Devam eden antrenmanı sürdür |
| `dashboard.action.startDirect` | Direkt starten | Start now | Hemen başlat |
| `dashboard.cardioChart.legend` | min/km · niedriger = besser | min/km · lower = better | dk/km · daha düşük = daha iyi |
| `dashboard.cardioChart.title` | Cardio-Pace-Trend | Cardio Pace Trend | Kardiyo Tempo Trendi |
| `dashboard.compoundChart.empty.hint` | Sobald du eine Compound-Übung in zwei Sessions geloggt hast, erscheint hier der Trend. | Once you log a compound lift across two sessions, the trend will appear here. | Bir temel hareketi iki farklı oturumda kaydettiğinde, trend burada görünür. |
| `dashboard.compoundChart.empty.title` | Noch zu wenig Daten | Not enough data yet | Henüz yeterli veri yok |
| `dashboard.compoundChart.legend` | Geschätztes 1RM | Estimated 1RM | Tahmini 1RM |
| `dashboard.compoundChart.title` | Compound-Lift-Trend | Compound Lift Trend | Temel Hareket Trendi |
| `dashboard.goal.line` | Ziel %@ kg | Goal %@ kg | Hedef %@ kg |
| `dashboard.heatmap.legend` | Sätze | Sets | Set |
| `dashboard.heatmap.title` | Muskel-Heatmap (Woche) | Muscle Heatmap (week) | Kas Isı Haritası (hafta) |
| `dashboard.history.empty` | Noch keine Trainings — starte oben dein erstes. | No workouts yet — start your first one above. | Henüz antrenman yok — yukarıdan ilkini başlat. |
| `dashboard.history.title` | Trainingsverlauf | Workout History | Antrenman Geçmişi |
| `dashboard.newMeasurement` | Neue Messung | New Measurement | Yeni Ölçüm |
| `dashboard.openSession.cancel` | Abbrechen | Cancel | İptal |
| `dashboard.openSession.dayName.unknown` | Unbekannt | Unknown | Bilinmiyor |
| `dashboard.openSession.discardAndStart` | Altes verwerfen & Neu starten | Discard old & start new | Eskiyi sil ve yeni başlat |
| `dashboard.openSession.message.fallback` | Es gibt bereits eine offene Trainings-Session. | There's already an open training session. | Halihazırda açık bir antrenman oturumu var. |
| `dashboard.openSession.message.withInfo` | Es läuft noch eine Session vom %1$@ (%2$@). Was möchtest du tun? | A session is still running from %1$@ (%2$@). What would you like to do? | %1$@ tarihinden kalan bir oturum hâlâ aktif (%2$@). Ne yapmak istersin? |
| `dashboard.openSession.resume` | Altes fortsetzen | Resume old | Eskisini sürdür |
| `dashboard.openSession.title` | Laufende Session | Active session | Aktif oturum |
| `dashboard.plan.checkoffRestDay` | Tag im Plan abhaken | Check off day in plan | Günü planda işaretle |
| `dashboard.plan.checkoffRestDay.a11y` | Ruhetag im Plan abhaken, um morgen den nächsten Trainingstag anzuzeigen | Check off rest day in plan to show tomorrow's next workout day | Dinlenme gününü planda işaretle, yarınki sonraki antrenman günü görünsün |
| `dashboard.plan.nextWorkout` | Nächstes Training | Next workout | Sıradaki antrenman |
| `dashboard.plan.noActivePlan` | Kein aktiver Plan | No active plan | Aktif plan yok |
| `dashboard.plan.noActivePlan.hint` | Lege im Plan-Tab deinen ersten Trainings-Plan an. | Set up your first training plan in the Plan tab. | İlk antrenman planını Plan sekmesinden oluştur. |
| `dashboard.plan.planEmpty` | Plan noch leer | Plan still empty | Plan henüz boş |
| `dashboard.plan.planEmpty.hint` | Füge deinem aktiven Plan im Plan-Tab Tage und Übungen hinzu. | Add days and exercises to your active plan in the Plan tab. | Plan sekmesinden aktif planına gün ve hareket ekle. |
| `dashboard.plan.restDay` | Heute ist Ruhetag. Zeit zur Erholung! | Today is a rest day. Time to recover! | Bugün dinlenme günü. İyileşme zamanı! |
| `dashboard.plan.tabShortcut` | Plan-Tab | Plan tab | Plan sekmesi |
| `dashboard.plan.todayRestDay` | Heute: Ruhetag | Today: rest day | Bugün: dinlenme günü |
| `dashboard.recent.empty.hint` | Starte oben dein erstes Training. | Start your first workout above. | İlk antrenmanını yukarıdan başlat. |
| `dashboard.recent.empty.title` | Noch keine Trainingseinheiten | No training sessions yet | Henüz antrenman yok |
| `dashboard.recent.title` | Letzte Workouts | Recent Workouts | Son Antrenmanlar |
| `dashboard.recent.viewAll` | Alle anzeigen | Show all | Tümünü göster |
| `dashboard.title` | Dashboard | Dashboard | Panel |
| `dashboard.trend.empty` | Trag deine erste Messung ein, um den Trend zu sehen. | Log your first measurement to see the trend. | Trendi görmek için ilk ölçümünü kaydet. |
| `dashboard.trend.emptyDescription` | Tippe auf '+' oben rechts, um deinen ersten Wert einzutragen. | Tap '+' at the top right to enter your first value. | İlk değeri girmek için sağ üstteki '+' simgesine dokun. |
| `dashboard.trend.emptyTitle` | Noch keine Messungen | No measurements yet | Henüz ölçüm yok |
| `dashboard.trend.forecast.legend` | Prognose 4 / 8 W. | Forecast 4 / 8 w. | Tahmin 4 / 8 hf. |
| `dashboard.trend.insufficient` | %lld von 3 nötigen Messungen — Linear-Regression startet ab 3 Werten über mind. 1 Woche. | %lld of 3 required measurements — linear regression starts at 3 values over at least 1 week. | %lld / 3 gerekli ölçüm — doğrusal regresyon en az 1 hafta üzerinden 3 değerle başlar. |
| `dashboard.trend.needMore` | Mehr Werte über mind. 1 Woche für eine Prognose nötig. | More values over at least 1 week needed for a forecast. | Tahmin için en az 1 hafta boyunca daha fazla değer gerekli. |
| `dashboard.trend.title` | Gewichts-Trend | Weight Trend | Kilo Trendi |
| `dashboard.trend.unstable` | Werte schwanken stark — Prognose ausgeblendet, bis sich der Trend stabilisiert. | Values fluctuating heavily — forecast hidden until the trend stabilises. | Değerler büyük dalgalanmalar gösteriyor — trend kararlı hale gelene kadar tahmin gizli. |
| `dashboard.trophy.empty` | Noch keine PRs — beende ein Workout, um den ersten zu setzen. | No PRs yet — finish a workout to set your first one. | Henüz PR yok — ilkini kaydetmek için bir antrenmanı tamamla. |
| `dashboard.trophy.title` | Trophy Room | Trophy Room | Kupa Odası |
| `dashboard.weeklySummary.distance` | Distanz | Distance | Mesafe |
| `dashboard.weeklySummary.title` | Diese Woche | This Week | Bu Hafta |
| `dashboard.weeklySummary.volume` | Volumen | Volume | Hacim |

## `dashboardSettings.*`  (8 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `dashboardSettings.empty` | Alle Widgets deaktiviert. Tippe ein '+' weiter unten, um wieder welche einzublenden. | All widgets are off. Tap '+' below to bring some back. | Tüm widget'lar kapalı. Geri eklemek için aşağıdan '+' simgesine dokun. |
| `dashboardSettings.entry` | Dashboard anpassen | Customize Dashboard | Panoyu Özelleştir |
| `dashboardSettings.entry.subtitle` | Widgets ein-/ausblenden und umsortieren | Toggle widgets on/off and reorder | Widget'ları aç/kapat ve sırala |
| `dashboardSettings.section.active` | Reihenfolge & Sichtbarkeit | Order & Visibility | Sıralama ve Görünürlük |
| `dashboardSettings.section.active.footer` | Halten + ziehen zum Umsortieren. Toggle aus, um ein Widget zu deaktivieren. | Press and drag to reorder. Toggle off to deactivate a widget. | Sıralamak için basılı tutup sürükle. Devre dışı bırakmak için kapat. |
| `dashboardSettings.section.inactive` | Inaktive Widgets | Inactive Widgets | Pasif Widget'lar |
| `dashboardSettings.section.inactive.footer` | Tippe das '+' um ein Widget wieder ans Ende der Liste zu setzen. | Tap '+' to append a widget back to the active list. | Bir widget'ı tekrar aktif listenin sonuna eklemek için '+' simgesine dokun. |
| `dashboardSettings.title` | Dashboard anpassen | Customize Dashboard | Panoyu Özelleştir |

## `day_intensity.*`  (3 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `day_intensity.heavy` | Schwer | Heavy | Ağır |
| `day_intensity.light` | Leicht | Light | Hafif |
| `day_intensity.normal` | Normal | Normal | Normal |

## `day_type.*`  (13 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `day_type.arms` | Arme | Arms | Kol |
| `day_type.back` | Rücken | Back | Sırt |
| `day_type.cardio` | Cardio / Run | Cardio / Run | Kardiyo / Koşu |
| `day_type.chest` | Brust | Chest | Göğüs |
| `day_type.custom` | Custom | Custom | Özel |
| `day_type.full_body` | Ganzkörper | Full Body | Tüm Vücut |
| `day_type.legs` | Beine | Legs | Bacak |
| `day_type.lower` | Unterkörper | Lower | Alt Vücut |
| `day_type.pull` | Pull | Pull | Pull |
| `day_type.push` | Push | Push | Push |
| `day_type.rest` | Ruhetag | Rest | Dinlenme Günü |
| `day_type.shoulders` | Schultern | Shoulders | Omuz |
| `day_type.upper` | Oberkörper | Upper | Üst Vücut |

## `difficulty.*`  (3 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `difficulty.advanced` | Profi | Advanced | İleri |
| `difficulty.beginner` | Anfänger | Beginner | Başlangıç |
| `difficulty.intermediate` | Fortgeschritten | Intermediate | Orta |

## `environment.*`  (3 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `environment.gym` | Gym | Gym | Spor Salonu |
| `environment.home_gym` | Home-Gym | Home Gym | Ev Salonu |
| `environment.no_equipment` | Ohne Equipment | No Equipment | Ekipmansız |

## `equipment.*`  (7 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `equipment.band` | Widerstandsband | Resistance Band | Direnç Bandı |
| `equipment.barbell` | Langhantel | Barbell | Halter |
| `equipment.bodyweight` | Körpergewicht | Bodyweight | Vücut Ağırlığı |
| `equipment.cable` | Kabel | Cable | Kablo |
| `equipment.dumbbell` | Kurzhantel | Dumbbell | Dambıl |
| `equipment.kettlebell` | Kettlebell | Kettlebell | Kettlebell |
| `equipment.machine` | Maschine | Machine | Makine |

## `exercise.*`  (120 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `exercise.name.australianPullup` | Australian Pull-ups | Australian Pull-up | Australian Pull-up |
| `exercise.name.backWidows` | Back Widows | Back Widows | Back Widows |
| `exercise.name.bandCurl` | Band Curls | Band Curl | Band Curl |
| `exercise.name.bandPullApart` | Band Pull-Aparts | Band Pull-Apart | Band Pull-Apart |
| `exercise.name.bandedHipThrust` | Banded Hip Thrust | Banded Hip Thrust | Banded Hip Thrust |
| `exercise.name.bandedSquat` | Banded Squats | Banded Squat | Banded Squat |
| `exercise.name.barbellCurl` | Bizeps-Curl (LH) | Barbell Curl | Barbell Curl |
| `exercise.name.barbellHipThrust` | Hip Thrust (LH) | Barbell Hip Thrust | Barbell Hip Thrust |
| `exercise.name.barbellLunge` | Ausfallschritte (LH) | Barbell Lunge | Barbell Lunge |
| `exercise.name.barbellShrug` | Shrug (LH) | Barbell Shrug | Barbell Shrug |
| `exercise.name.barbellStandingCalfRaise` | Wadenheben (stehend, LH) | Standing Calf Raise (Barbell) | Standing Calf Raise (Barbell) |
| `exercise.name.barbellrow` | Langhantelrudern | Barbell Row | Barbell Row |
| `exercise.name.behindNeckPress` | Nackendrücken | Behind-the-Neck Press | Behind-the-Neck Press |
| `exercise.name.benchpress` | Bankdrücken | Bench Press | Bench Press |
| `exercise.name.bicepcurl` | Bizeps-Curls | Bicep Curl | Bicep Curl |
| `exercise.name.bodyweightCalfRaise` | Wadenheben (BW) | Bodyweight Calf Raise | Vücut Ağırlığı Calf Raise |
| `exercise.name.bodyweightHipThrust` | Hip Thrust (BW) | Bodyweight Hip Thrust | Vücut Ağırlığı Hip Thrust |
| `exercise.name.bodyweightLunge` | Ausfallschritte (BW) | Bodyweight Lunge | Vücut Ağırlığı Lunge |
| `exercise.name.bodyweightSquat` | Kniebeuge (BW) | Bodyweight Squat | Vücut Ağırlığı Squat |
| `exercise.name.boxJump` | Box Jump | Box Jump | Box Jump |
| `exercise.name.bulgarianSplitSquatDB` | Bulgarische Kniebeuge (KH) | Bulgarian Split Squat (DB) | Bulgarian Split Squat (DB) |
| `exercise.name.burpee` | Burpees | Burpees | Burpee |
| `exercise.name.cableCrossover` | Kabel Crossover | Cable Crossover | Cable Crossover |
| `exercise.name.cableCrunch` | Kabel Crunch | Cable Crunch | Cable Crunch |
| `exercise.name.cableCurl` | Kabel Curl | Cable Curl | Cable Curl |
| `exercise.name.cableLateralRaise` | Kabel Seitheben | Cable Lateral Raise | Cable Lateral Raise |
| `exercise.name.cableOverheadTricepExtension` | Trizepsstrecker über Kopf (Kabel) | Cable Overhead Tricep Extension | Cable Overhead Tricep Extension |
| `exercise.name.chestDip` | Dips (Brust) | Chest Dip | Chest Dip |
| `exercise.name.chestPressMachine` | Brustdrücken (Maschine) | Chest Press Machine | Chest Press Machine |
| `exercise.name.chestSupportedRowDB` | Chest Supported Row (KH) | Chest-Supported Row (DB) | Chest-Supported Row (DB) |
| `exercise.name.closeGripBenchPress` | Enges Bankdrücken | Close-Grip Bench Press | Close-Grip Bench Press |
| `exercise.name.concentrationCurl` | Konzentrations-Curl (KH) | Concentration Curl | Concentration Curl |
| `exercise.name.crunch` | Crunches (BW) | Crunches | Karın Mekik |
| `exercise.name.cycling` | Radfahren (outdoor) | Cycling (Outdoor) | Bisiklet (Açık Hava) |
| `exercise.name.deadlift` | Kreuzheben | Deadlift | Deadlift |
| `exercise.name.declineBenchPress` | Schrägbankdrücken (abwärts) | Decline Bench Press | Decline Bench Press |
| `exercise.name.diamondPushup` | Diamant-Liegestütze | Diamond Push-up | Elmas Şınav |
| `exercise.name.dumbbellBenchPress` | Bankdrücken (KH) | Dumbbell Bench Press | Dumbbell Bench Press |
| `exercise.name.dumbbellCalfRaise` | Wadenheben (KH) | Dumbbell Calf Raise | Dumbbell Calf Raise |
| `exercise.name.dumbbellFlyFlat` | Flyes flach (KH) | Dumbbell Fly (Flat) | Dumbbell Fly (Flat) |
| `exercise.name.dumbbellFlyIncline` | Flyes Schrägbank (KH) | Dumbbell Fly (Incline) | Dumbbell Fly (Incline) |
| `exercise.name.dumbbellHipThrust` | Hip Thrust (KH) | Dumbbell Hip Thrust | Dumbbell Hip Thrust |
| `exercise.name.dumbbellInclineBenchPress` | Schrägbankdrücken aufwärts (KH) | Dumbbell Incline Bench Press | Dumbbell Incline Bench Press |
| `exercise.name.dumbbellLunge` | Ausfallschritte (KH) | Dumbbell Lunge | Dumbbell Lunge |
| `exercise.name.dumbbellOverheadTricepExtension` | Trizepsstrecker über Kopf (KH) | Dumbbell Overhead Tricep Extension | Dumbbell Overhead Tricep Extension |
| `exercise.name.dumbbellPullover` | Pullover (KH) | Dumbbell Pullover | Dumbbell Pullover |
| `exercise.name.dumbbellRDL` | Rumänisches Kreuzheben (KH) | Dumbbell Romanian Deadlift | Dumbbell Romanian Deadlift |
| `exercise.name.dumbbellRowOneArm` | Rudern einarmig (KH) | One-Arm Dumbbell Row | One-Arm Dumbbell Row |
| `exercise.name.dumbbellShoulderPress` | Schulterdrücken (KH) | Dumbbell Shoulder Press | Dumbbell Shoulder Press |
| `exercise.name.dumbbellShrug` | Shrug (KH) | Dumbbell Shrug | Dumbbell Shrug |
| `exercise.name.dumbbellTricepKickback` | Trizepskickback (KH) | Dumbbell Tricep Kickback | Dumbbell Tricep Kickback |
| `exercise.name.elliptical` | Crosstrainer | Elliptical | Eliptik Bisiklet |
| `exercise.name.facePull` | Face Pull | Face Pull | Face Pull |
| `exercise.name.frontRaise` | Frontheben | Front Raise | Front Raise |
| `exercise.name.frontSquat` | Front Squat | Front Squat | Front Squat |
| `exercise.name.gluteBridge` | Glute Bridge (BW) | Glute Bridge | Glute Bridge |
| `exercise.name.gobletSquat` | Goblet Squat | Goblet Squat | Goblet Squat |
| `exercise.name.goodMorning` | Good Morning | Good Morning | Good Morning |
| `exercise.name.hackSquat` | Hack Squat | Hack Squat | Hack Squat |
| `exercise.name.hammerCurl` | Hammer Curl | Hammer Curl | Hammer Curl |
| `exercise.name.handstandPushup` | Handstand-Liegestütze | Handstand Push-up | Amuda Kalkarak Şınav |
| `exercise.name.hangingLegRaise` | Hanging Leg Raises | Hanging Leg Raises | Asılı Bacak Kaldırma |
| `exercise.name.inclineBenchPress` | Schrägbankdrücken (aufwärts) | Incline Bench Press | Incline Bench Press |
| `exercise.name.inclineDumbbellCurl` | Schrägbank-Curl (KH) | Incline Dumbbell Curl | Incline Dumbbell Curl |
| `exercise.name.jumpSquat` | Jump Squat | Jump Squat | Jump Squat |
| `exercise.name.kettlebellCleanAndPress` | Kettlebell Clean & Press | Kettlebell Clean & Press | Kettlebell Clean & Press |
| `exercise.name.kettlebellGobletSquat` | Kettlebell Goblet Squat | Kettlebell Goblet Squat | Kettlebell Goblet Squat |
| `exercise.name.kettlebellHalo` | Kettlebell Halo | Kettlebell Halo | Kettlebell Halo |
| `exercise.name.kettlebellSnatch` | Kettlebell Snatch | Kettlebell Snatch | Kettlebell Snatch |
| `exercise.name.kettlebellSwing` | Kettlebell Swing | Kettlebell Swing | Kettlebell Swing |
| `exercise.name.latPulldownClose` | Latzug (eng) | Lat Pulldown (Close) | Lat Pulldown (Close) |
| `exercise.name.lateralRaise` | Seitheben | Lateral Raise | Lateral Raise |
| `exercise.name.latpulldown` | Latzug | Lat Pulldown | Lat Pulldown |
| `exercise.name.legExtension` | Beinstrecker | Leg Extension | Leg Extension |
| `exercise.name.legpress` | Beinpresse | Leg Press | Leg Press |
| `exercise.name.lyingLegCurl` | Beinbeuger liegend | Lying Leg Curl | Lying Leg Curl |
| `exercise.name.lyingLegExtension` | Beinstrecker liegend | Lying Leg Extension | Yatarak Bacak Açma |
| `exercise.name.lyingLegRaise` | Beinheben (liegend) | Lying Leg Raise | Yatarak Bacak Kaldırma |
| `exercise.name.mountainClimber` | Mountain Climbers | Mountain Climbers | Mountain Climbers |
| `exercise.name.nordicCurl` | Nordic Curls | Nordic Curl | Nordic Curl |
| `exercise.name.overheadpress` | Schulterdrücken | Overhead Press | Overhead Press |
| `exercise.name.pecDeck` | Pec Deck (Butterfly) | Pec Deck (Butterfly) | Pec Deck (Butterfly) |
| `exercise.name.pendlayRow` | Pendlay Row | Pendlay Row | Pendlay Row |
| `exercise.name.pikePushup` | Pike Liegestütze | Pike Push-up | Pike Şınav |
| `exercise.name.plank` | Unterarmstütz (Plank) | Plank | Plank |
| `exercise.name.preacherCurl` | Preacher Curl (Maschine) | Preacher Curl (Machine) | Preacher Curl (Machine) |
| `exercise.name.pullup` | Klimmzüge | Pull-Up | Pull-Up |
| `exercise.name.pushPress` | Push Press | Push Press | Push Press |
| `exercise.name.pushup` | Liegestütze | Push-up | Şınav |
| `exercise.name.rest` | Pause | Rest | Dinlenme |
| `exercise.name.reverseCurl` | Reverse Curl | Reverse Curl | Reverse Curl |
| `exercise.name.reverseFlyDB` | Reverse Flyes (KH) | Reverse Fly (DB) | Reverse Fly (DB) |
| `exercise.name.romanianDeadlift` | Rumänisches Kreuzheben | Romanian Deadlift | Romanian Deadlift |
| `exercise.name.rowingMachine` | Rudermaschine | Rowing Machine | Kürek Makinesi |
| `exercise.name.run` | Lauf | Run | Koşu |
| `exercise.name.russianTwist` | Russian Twists | Russian Twists | Russian Twist |
| `exercise.name.seatedCableRow` | Kabelrudern sitzend | Seated Cable Row | Seated Cable Row |
| `exercise.name.seatedCalfRaise` | Wadenpresse (sitzend) | Seated Calf Raise | Seated Calf Raise |
| `exercise.name.shoulderPressMachine` | Schulterdrücken (Maschine) | Shoulder Press Machine | Shoulder Press Machine |
| `exercise.name.sidePlank` | Seitstütz | Side Plank | Yan Plank |
| `exercise.name.sissySquat` | Sissy Squats (BW) | Sissy Squat | Sissy Squat |
| `exercise.name.situp` | Sit-ups | Sit-ups | Mekik |
| `exercise.name.skullCrusher` | Skull Crusher | Skull Crusher | Skull Crusher |
| `exercise.name.smithMachineSquat` | Smith Machine Squat | Smith Machine Squat | Smith Machine Squat |
| `exercise.name.squat` | Kniebeuge | Back Squat | Back Squat |
| `exercise.name.stairStepper` | Stepper | Stair Stepper | Stepper |
| `exercise.name.stationaryBike` | Fahrradergometer | Stationary Bike | Kondisyon Bisikleti |
| `exercise.name.stepUpDB` | Step-Up (KH) | Step-Up (DB) | Step-Up (DB) |
| `exercise.name.sumoDeadlift` | Sumo-Kreuzheben | Sumo Deadlift | Sumo Deadlift |
| `exercise.name.swimming` | Schwimmen | Swimming | Yüzme |
| `exercise.name.tBarRow` | T-Bar Rudern | T-Bar Row | T-Bar Row |
| `exercise.name.towelRowDoorframe` | Handtuch-Rudern (Türrahmen) | Towel Row (Doorframe) | Havlu Sırt Çekişi (Kapı Kasası) |
| `exercise.name.treadmill` | Laufband | Treadmill | Koşu Bandı |
| `exercise.name.tricepDip` | Dips (Trizeps) | Tricep Dip | Tricep Dip |
| `exercise.name.tricepPushdown` | Trizeps-Drücken | Triceps Pushdown | Triceps Pushdown |
| `exercise.name.turkishGetUp` | Turkish Get-Up | Turkish Get-Up | Türk Kalkışı |
| `exercise.name.wallSit` | Wall Sit | Wall Sit | Wall Sit |
| `exercise.name.widePullup` | Klimmzüge (weit) | Wide Pull-up | Wide Pull-up |
| `exercise.name.widePushup` | Breite Liegestütze | Wide Push-up | Geniş Şınav |
| `exercise.name.zercherSquat` | Zercher Squat | Zercher Squat | Zercher Squat |

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
| `metric.ffmi` | FFMI | FFMI | FFMI |
| `metric.kfaNavy` | KFA Navy | Body Fat (Navy) | Yağ Oranı (Navy) |
| `metric.weeklyDelta.suffix` | / Wo. | / wk. | / hf. |
| `metric.weight` | Gewicht | Weight | Ağırlık |

## `misc.*`  (1 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `%lld von %lld nötigen Messungen` | %lld von %lld nötigen Messungen | %lld of %lld required measurements | %lld / %lld gerekli ölçüm |

## `muscle.*`  (10 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `muscle.back` | Rücken | Back | Sırt |
| `muscle.biceps` | Bizeps | Biceps | Pazı |
| `muscle.calves` | Waden | Calves | Baldır |
| `muscle.chest` | Brust | Chest | Göğüs |
| `muscle.core` | Core | Core | Merkez |
| `muscle.glutes` | Gesäß | Glutes | Kalça |
| `muscle.hamstrings` | Hamstrings | Hamstrings | Hamstring |
| `muscle.quads` | Quadrizeps | Quadriceps | Quadriceps |
| `muscle.shoulders` | Schultern | Shoulders | Omuz |
| `muscle.triceps` | Trizeps | Triceps | Triseps |

## `onboarding.*`  (13 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `onboarding.action.create` | Profil anlegen | Create profile | Profil Oluştur |
| `onboarding.coaching.title` | Dein Coaching-Stil | Your coaching style | Koçluk tarzın |
| `onboarding.field.birthdate` | Geburtsdatum | Birth date | Doğum Tarihi |
| `onboarding.field.environment` | Trainingsort | Training Location | Antrenman Yeri |
| `onboarding.field.goal_weight` | Zielgewicht (kg, optional) | Goal weight (kg, optional) | Hedef Kilo (kg, isteğe bağlı) |
| `onboarding.field.height` | Größe (cm) | Height (cm) | Boy (cm) |
| `onboarding.field.sex` | Geschlecht | Sex | Cinsiyet |
| `onboarding.intro.body` | Für akkurate Berechnungen (BMI, KFA, FFMI, BMR) brauchen wir Sex, Alter und Größe. Alle Werte kannst du später unter Profil ändern. | For accurate calculations (BMI, body-fat, FFMI, BMR) we need sex, age, and height. You can change everything later in your profile. | Doğru hesaplamalar (BKİ, yağ oranı, FFMI, BMR) için cinsiyet, yaş ve boya ihtiyacımız var. Tüm değerleri sonradan Profil altında değiştirebilirsin. |
| `onboarding.intro.title` | Lass uns starten | Let's get started | Hadi başlayalım |
| `onboarding.section.body` | Körpermaße | Body Measurements | Vücut Ölçüleri |
| `onboarding.section.goals` | Ziel & Training | Goals & Training | Hedef & Antrenman |
| `onboarding.section.profile` | Profil | Profile | Profil |
| `onboarding.title` | Willkommen | Welcome | Hoş Geldin |

## `plan.*`  (58 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `plan.day.arms` | Arme | Arms | Kol |
| `plan.day.back` | Rücken | Back | Sırt |
| `plan.day.benchDay` | Tag 2 – Bankdrück-Tag | Day 2 - Bench Day | Gün 2 - Bench Günü |
| `plan.day.chest` | Brust | Chest | Göğüs |
| `plan.day.chestBackA` | Brust & Rücken A | Chest & Back A | Göğüs & Sırt A |
| `plan.day.chestBackB` | Brust & Rücken B | Chest & Back B | Göğüs & Sırt B |
| `plan.day.deadliftDay` | Tag 3 – Kreuzhebe-Tag | Day 3 - Deadlift Day | Gün 3 - Deadlift Günü |
| `plan.day.easyRun` | Easy Run | Easy Run | Kolay Koşu |
| `plan.day.fatBurnA` | Fatburn A | Fat Burn A | Yağ Yakım A |
| `plan.day.fatBurnB` | Fatburn B | Fat Burn B | Yağ Yakım B |
| `plan.day.fatBurnC` | Fatburn C | Fat Burn C | Yağ Yakım C |
| `plan.day.fullBodyA` | Ganzkörper A | Full Body A | Tüm Vücut A |
| `plan.day.fullBodyB` | Ganzkörper B | Full Body B | Tüm Vücut B |
| `plan.day.fullBodyC` | Ganzkörper C | Full Body C | Tüm Vücut C |
| `plan.day.fullBodyHIIT` | Ganzkörper HIIT | Full Body HIIT | Tüm Vücut HIIT |
| `plan.day.intervals` | Intervalle | Intervals | İnterval |
| `plan.day.legs` | Beine | Legs | Bacak |
| `plan.day.legsA` | Beine A | Legs A | Bacak A |
| `plan.day.legsB` | Beine B | Legs B | Bacak B |
| `plan.day.longRun` | Long Run | Long Run | Uzun Koşu |
| `plan.day.lowerAStrength` | Unterkörper A (Kraft) | Lower A (Strength) | Alt Vücut A (Güç) |
| `plan.day.lowerAndCore` | Unterkörper & Core | Lower & Core | Alt Vücut & Merkez |
| `plan.day.lowerBVolume` | Unterkörper B (Volumen) | Lower B (Volume) | Alt Vücut B (Hacim) |
| `plan.day.pullA` | Pull A | Pull A | Pull A |
| `plan.day.pullAndLegs` | Pull & Beine | Pull & Legs | Pull & Bacak |
| `plan.day.pullB` | Pull B | Pull B | Pull B |
| `plan.day.pushA` | Push A | Push A | Push A |
| `plan.day.pushAndCore` | Push & Core | Push & Core | Push & Merkez |
| `plan.day.pushB` | Push B | Push B | Push B |
| `plan.day.shoulders` | Schultern | Shoulders | Omuz |
| `plan.day.shouldersArmsA` | Schultern & Arme A | Shoulders & Arms A | Omuz & Kol A |
| `plan.day.shouldersArmsB` | Schultern & Arme B | Shoulders & Arms B | Omuz & Kol B |
| `plan.day.squatDay` | Tag 1 – Kniebeuge-Tag | Day 1 - Squat Day | Gün 1 - Squat Günü |
| `plan.day.strengthFullBodyA` | Strength Ganzkörper A | Strength Full Body A | Güç Tüm Vücut A |
| `plan.day.strengthFullBodyB` | Strength Ganzkörper B | Strength Full Body B | Güç Tüm Vücut B |
| `plan.day.strengthLegs` | Strength Legs | Strength Legs | Güç Bacak |
| `plan.day.strengthLegsLight` | Strength Legs (Light) | Strength Legs (Light) | Güç Bacak (Hafif) |
| `plan.day.strengthPull` | Strength Pull | Strength Pull | Güç Pull |
| `plan.day.strengthPush` | Strength Push | Strength Push | Güç Push |
| `plan.day.upperAStrength` | Oberkörper A (Kraft) | Upper A (Strength) | Üst Vücut A (Güç) |
| `plan.day.upperAndPower` | Oberkörper & Explosivität | Upper & Power | Üst Vücut & Patlayıcı Güç |
| `plan.day.upperBVolume` | Oberkörper B (Volumen) | Upper B (Volume) | Üst Vücut B (Hacim) |
| `plan.day.workoutA` | Workout A | Workout A | Antrenman A |
| `plan.day.workoutB` | Workout B | Workout B | Antrenman B |
| `plan.template.arnoldSplit` | Arnold Split | Arnold Split | Arnold Split |
| `plan.template.bodyweightMastery` | Bodyweight Mastery | Bodyweight Mastery | Vücut Ağırlığı Ustası |
| `plan.template.broSplit` | Bro-Split | Bro Split | Bro Split |
| `plan.template.fatBurnFullBody` | Fatburn Ganzkörper | Fat Burn Full Body | Yağ Yakım Tüm Vücut |
| `plan.template.footballAthletic` | Fussball Athletik | Football Athletics | Futbol Atletik |
| `plan.template.fullBody3x` | Ganzkörper 3x | Full Body 3x | Tüm Vücut 3x |
| `plan.template.homeGymHero` | Home Gym Hero | Home Gym Hero | Ev Salonu Kahramanı |
| `plan.template.hybridBalanced` | Hybrid Athlete — Balanced | Hybrid Athlete — Balanced | Hibrit Atlet — Dengeli |
| `plan.template.hybridBeginner` | Hybrid Athlete — Beginner | Hybrid Athlete — Beginner | Hibrit Atlet — Başlangıç |
| `plan.template.hybridPerformance` | Hybrid Athlete — Performance | Hybrid Athlete — Performance | Hibrit Atlet — Performans |
| `plan.template.powerlifting3x5` | Powerlifting 3x5 | Powerlifting 3x5 | Powerlifting 3x5 |
| `plan.template.powerlifting5x5` | Powerlifting 5x5 | Powerlifting 5x5 | Powerlifting 5x5 |
| `plan.template.pushPullLegs` | Push-Pull-Legs | Push-Pull-Legs | Push-Pull-Legs |
| `plan.template.upperLower` | Upper-Lower-Split | Upper-Lower Split | Üst-Alt Vücut Bölünmüş |

## `settings.*`  (12 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `settings.action.reset` | App zurücksetzen | Reset App | Uygulamayı Sıfırla |
| `settings.confirm.reset.action` | Alles löschen | Delete everything | Her şeyi sil |
| `settings.confirm.reset.message` | Profil, alle Messungen, Pläne und Workout-Sessions gehen UNWIDERRUFLICH verloren. Die App startet danach im Onboarding. | Profile, all measurements, plans, and workouts will be IRRECOVERABLY lost. The app will start in onboarding. | Profil, tüm ölçümler, planlar ve antrenman oturumları GERİ ALINAMAZ şekilde silinecek. Uygulama ardından tekrar onboarding'den başlayacak. |
| `settings.confirm.reset.title` | App wirklich zurücksetzen? | Really reset the app? | Uygulamayı gerçekten sıfırlamak istiyor musun? |
| `settings.preferences.units` | Einheiten | Units | Birimler |
| `settings.preferences.units.imperial` | Imperial (lbs / in) | Imperial (lbs / in) | İmperial (lbs / in) |
| `settings.preferences.units.metric` | Metrisch (kg / cm) | Metric (kg / cm) | Metrik (kg / cm) |
| `settings.section.about` | Über | About | Hakkında |
| `settings.section.danger_zone` | Daten-Management | Data Management | Veri Yönetimi |
| `settings.section.preferences` | Präferenzen | Preferences | Tercihler |
| `settings.section.profile_goals` | Profil & Ziele | Profile & Goals | Profil & Hedefler |
| `settings.title` | Einstellungen | Settings | Ayarlar |

## `sex.*`  (2 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `sex.female` | Weiblich | Female | Kadın |
| `sex.male` | Männlich | Male | Erkek |

## `summary.*`  (2 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `summary.action.finish` | Speichern & zum Dashboard | Save & to dashboard | Kaydet ve Panele Dön |
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
| `trophy.kind.estimated1RM` | 1RM | 1RM | 1RM |
| `trophy.kind.heaviestWeight` | Max-Gewicht | Top Weight | Maks. Ağırlık |
| `trophy.kind.maxHoldSeconds` | Bestzeit | Best Hold | En İyi Süre |
| `trophy.kind.maxReps` | Max Wdh. | Max Reps | Maks. Tekrar |
| `trophy.title` | Trophy Room | Trophy Room | Rekor Odası |

## `widget.*`  (10 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `widget.cardioPace.name` | Cardio-Pace-Trend | Cardio Pace Trend | Kardiyo Tempo Trendi |
| `widget.coachingInsight.name` | Coaching-Insight | Coaching Insight | Koçluk İçgörüsü |
| `widget.compoundLifts.name` | Compound-Lift-Trend | Compound Lift Trend | Temel Hareket Trendi |
| `widget.muscleHeatmap.name` | Muskel-Heatmap | Muscle Heatmap | Kas Isı Haritası |
| `widget.nextWorkout.name` | Nächstes Training | Next Workout | Sıradaki Antrenman |
| `widget.recentWorkouts.name` | Letzte Workouts | Recent Workouts | Son Antrenmanlar |
| `widget.trophyRoom.name` | Trophy Room | Trophy Room | Kupa Odası |
| `widget.weeklyVolume.name` | Diese Woche | This Week | Bu Hafta |
| `widget.weightTrend.name` | Gewichts-Trend | Weight Trend | Kilo Trendi |
| `widget.workoutHistory.name` | Trainingsverlauf | Workout History | Antrenman Geçmişi |


---

## 🔢 Plural-Keys (one/other-Varianten)

Diese Keys haben Plural-Varianten — beide Formen sind übersetzt.


### `%lld Rekorde`

| Sprache | one | other |
|---|---|---|
| Deutsch | %lld Rekord | %lld Rekorde |
| English | %lld record | %lld records |
| Türkçe | %lld rekor | %lld rekor |

### `%lld Übungen — %@`

| Sprache | one | other |
|---|---|---|
| Deutsch | %lld Übung — %@ | %lld Übungen — %@ |
| English | %lld exercise — %@ | %lld exercises — %@ |
| Türkçe |  |  |


---

# 🚧 Hartkodierte deutsche Strings (noch nicht im Catalog)

Stand: 195 hartkodierte deutsche Strings über 24 Dateien gefunden (per Heuristik — false positives möglich, beim Refactor wird jede Stelle nochmal geprüft).

Diese Strings müssen in einem späteren i18n-Sweep (DEL-073 Phase 2-4) nach `Localizable.xcstrings` migriert werden:

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
| 1003 | Workout beenden |  |  |
| 1009 | Abbrechen |  |  |
| 1025 | Verwendete Ausrüstung |  |  |
| 1070 | Dein Workout |  |  |
| 1099 | Wie hat sich das Training angefühlt? |  |  |
| 1101 | Die App nutzt das fuer die Progression: Wenn du am Limit warst, halten wir das Gewicht stabil — kein Zwangs-Plus. |  |  |
| 1130 | Kein Gewichts-Plus im nächsten Workout |  |  |
| 1159 | Workout speichern |  |  |

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
| 206 | Ausrüstung & Schuhe |  |  |
| 219 | Die DB speichert immer metrisch. Diese Einstellung steuert nur die Anzeige in Eingabe-Feldern, im Hantel-Rechner und auf den Karten. |  |  |
| 238 | Greift in alle Views der App. 'System' folgt der iOS-Einstellung. |  |  |
| 268 | Wird beim Ablauf des Pausen-Timers ausgeloest. Vibrations-Toggle hat auf iPads keine Wirkung. 'PR-Feiern' steuert Save-Screen-Popups, Live-Activity-Headline und lokale Benachrichtigungen — die Bestleistungen werden trotzdem im Trophy-Room gespeichert. |  |  |
| 284 | Wenn aus, werden Warmup- und Cooldown-Übungen während der Session ausgeblendet. Die Templates und deine Plan-Editierung bleiben unverändert — der Toggle wirkt nur auf den Live-Workout-Flow. Warmups sind ohnehin nie Pflicht: der „Workout speichern“-Button bleibt immer klickbar, auch wenn du sie nicht abhakst. |  |  |
| 356 | Lokale Benachrichtigungen — keine Server-Verbindung. Tippen auf eine Erinnerung öffnet direkt den passenden Tab. |  |  |
| 411 | Bei aktivierter Verbindung wird im Messwerte-Formular das letzte Waagen-Gewicht vorausgefüllt. Beim Speichern werden Gewicht, KFA und Magere Masse zurück nach Apple Health geschrieben. |  |  |
| 441 | Nicht verfügbar |  |  |
| 454 | In iOS-Einstellungen öffnen |  |  |
| 492 | Löscht Profil, Messungen, Pläne, Trainings-Templates und Workout-Sessions vollständig. Die Apple-Health-Daten bleiben erhalten — die löscht du in der Health-App selber. |  |  |

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
