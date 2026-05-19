# Deltiq — Translation Source-of-Truth

**Gesamt: 815 Keys im String Catalog + 0 noch hartkodierte Strings im Code.**

## Coverage-Status (Catalog)

| Sprache | Übersetzt | Fehlt |
|---|---|---|
| 🇩🇪 Deutsch (DE) | **815 / 815** (100%) | 0 |
| 🇬🇧 English (EN) | **815 / 815** (100%) | 0 |
| 🇹🇷 Türkçe (TR) | **815 / 815** (100%) | 0 |

Wenn du EN/TR aktualisierst:
- Per Xcode: öffne `Sources/FitnessAppUI/Resources/Localizable.xcstrings`, Apple's String-Catalog-Editor markiert „needs translation" automatisch.
- Per CSV-Export aus dieser Tabelle → ChatGPT / DeepL → zurück in die xcstrings importieren.
- Per direktem JSON-Edit (vorsichtig, JSON-Syntax muss valide bleiben).

Quelle: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`

Tabellenformat: leere EN/TR-Spalten brauchen Übersetzung. Plural-Keys sind separat aufgelistet — die haben one/other-Varianten.


## `active.*`  (26 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `active.action.discard` | Verwerfen | Discard | Sil |
| `active.action.save` | Training speichern | Save workout | Antrenmanı Kaydet |
| `active.addExercise` | Übung | Exercise | Hareket |
| `active.addExerciseCTA` | Übung hinzufügen | Add Exercise | Hareket Ekle |
| `active.confirm.discard.title` | Training verwerfen? | Discard workout? | Antrenmanı silmek istiyor musun? |
| `active.confirm.finish.title` | Training abschließen? | Finish workout? | Antrenmanı bitirelim mi? |
| `active.discard.cta` | Workout abbrechen | Discard Workout | Antrenmanı Sil |
| `active.discard.message` | Die Session und alle %lld bisher geloggten Sätze gehen verloren. | The session and all %lld logged sets will be lost. | Oturum ve şimdiye kadar kaydedilen %lld set kaybolacak. |
| `active.empty.adhoc.message` | Such dir aus der Library eine Übung — alles weitere passiert wie im Plan-Workout. | Pick an exercise from the library — everything else works like a plan workout. | Kütüphaneden bir hareket seç — gerisi plan antrenmanı gibi çalışır. |
| `active.empty.adhoc.title` | Dein Workout ist noch leer | Your workout is empty | Antrenmanın henüz boş |
| `active.empty.session.message` | Vermutlich wurde der Plan-Tag nach dem Start geleert. Du kannst die Session verwerfen oder ohne Sätze beenden. | The plan day was likely emptied after starting. Discard the session or finish without sets. | Plan günü başlatıldıktan sonra muhtemelen boşaltıldı. Oturumu silebilir veya setsiz bitirebilirsin. |
| `active.empty.session.title` | Diese Session hat keine Übungen. | This session has no exercises. | Bu oturumda hareket yok. |
| `active.finish.feeling.message` | Die App nutzt das für die Progression: Wenn du am Limit warst, halten wir das Gewicht stabil — kein Zwangs-Plus. | We use this for progression: when you were at the limit, we keep the weight stable — no forced increase. | Bunu ilerleme için kullanırız: limitteydiysen ağırlığı sabit tutarız — zorla artırma yok. |
| `active.finish.feeling.noProgression` | Kein Gewichts-Plus im nächsten Workout | No weight increase next workout | Sonraki antrenmanda ağırlık artışı yok |
| `active.finish.feeling.title` | Wie hat sich das Training angefühlt? | How did the workout feel? | Antrenman nasıl hissettirdi? |
| `active.finish.gear` | Verwendete Ausrüstung | Gear Used | Kullanılan Ekipman |
| `active.finish.save` | Workout speichern | Save Workout | Antrenmanı Kaydet |
| `active.finish.summary` | Dein Workout | Your Workout | Antrenmanın |
| `active.finish.title` | Workout beenden | Finish Workout | Antrenmanı Bitir |
| `active.interference.dismiss` | Banner schließen | Dismiss banner | Banner'ı kapat |
| `active.interference.message` | Erwäge heute, dein Ziel-RIR bei Beinübungen um +1 zu erhöhen, um dein ZNS nicht zu überlasten. | Consider raising your target RIR on leg exercises by +1 today to avoid overloading your CNS. | MSS'ni aşırı yüklemekten kaçınmak için bugün bacak hareketlerinde hedef RIR'ı +1 artırmayı düşün. |
| `active.interference.title` | Du hattest gestern eine harte Einheit | You had a hard session yesterday | Dün zorlu bir antrenmanın vardı |
| `active.placeholder.subtext` | Set-Logging mit Vorgaben & Rest-Timer • Live Activities folgen im Xcode-Target. | Set logging with targets & rest timer • Live Activities arrive in the Xcode target. | Hedefli set kaydı ve dinlenme zamanlayıcısı • Live Activities Xcode hedefinde gelir. |
| `active.summary.duration` | Dauer | Duration | Süre |
| `active.summary.sets` | Sätze | Sets | Set |
| `active.summary.volume` | Volumen | Volume | Hacim |

## `barbell.*`  (2 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `barbell.loading.empty` | Keine Aufladung — bleib bei der leeren Stange. | No plates needed — keep the empty bar. | Plaka yok — boş barı bırak. |
| `barbell.loading.title` | Hantel-Aufladung | Barbell Loading | Halter Yükleme |

## `calc.*`  (53 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `calc.1rm.input.footer` | Gültig für 1-36 Reps. Bei sehr hohen Reps wird die Schätzung unzuverlässig — die Formeln liefern nur für den Hypertrophie- bis Kraft-Bereich (~1-12 Reps) brauchbare Werte. | Valid for 1-36 reps. Estimates get unreliable at very high reps — formulas work best in the hypertrophy-to-strength range (~1-12 reps). | 1-36 tekrar için geçerli. Çok yüksek tekrarlarda tahmin güvenilmez olur — formüller hipertrofi-güç aralığında (~1-12 tekrar) en iyi sonucu verir. |
| `calc.1rm.percentages.footer` | Rep-Hints sind Faustwerte. Effektive Reps hängen vom Trainings-Status und der Bewegung ab. | Rep hints are rules of thumb. Actual reps depend on training status and the lift. | Tekrar ipuçları yaklaşık değerlerdir. Gerçek tekrar; antrenman durumuna ve harekete bağlıdır. |
| `calc.1rm.reps` | Wiederholungen | Reps | Tekrar |
| `calc.1rm.repsHint` | ~ %lld Reps | ~ %lld reps | ~ %lld tekrar |
| `calc.1rm.row.average` | Mittelwert | Average | Ortalama |
| `calc.1rm.section.estimate` | Geschätztes 1RM | Estimated 1RM | Tahmini 1RM |
| `calc.1rm.section.input` | Eingabe | Input | Giriş |
| `calc.1rm.section.percentages` | Trainings-Last (vom Mittelwert-1RM) | Training Load (from average 1RM) | Antrenman Yükü (ortalama 1RM'den) |
| `calc.1rm.tableEmpty` | Tabelle erscheint, sobald 1RM berechnet ist. | Table shows up once the 1RM is calculated. | 1RM hesaplandığında tablo görünür. |
| `calc.1rm.weightLabel` | Gewicht (%@) | Weight (%@) | Ağırlık (%@) |
| `calc.1rm.weightPlaceholder` | z.B. 100 | e.g. 100 | örn. 100 |
| `calc.1rm.weightRequired` | Trag Gewicht > 0 ein. | Enter weight > 0. | Ağırlık > 0 gir. |
| `calc.index.1rm.subtitle` | Epley + Brzycki + Mittelwert, plus Trainings-%-Tabelle. | Epley + Brzycki + average, plus a training-% table. | Epley + Brzycki + ortalama, artı antrenman % tablosu. |
| `calc.index.1rm.title` | 1RM-Rechner | 1RM Calculator | 1RM Hesaplayıcı |
| `calc.index.footer` | Alle Rechner nutzen die gleiche Domain-Logik (FitnessAppCore) wie der Rest der App — Werte sind 1:1 mit Dashboard und MeasurementView. | All calculators use the same domain logic (FitnessAppCore) as the rest of the app — values match dashboard and measurement view 1:1. | Tüm hesaplayıcılar uygulamanın geri kalanıyla aynı domain mantığını (FitnessAppCore) kullanır — değerler panel ve ölçüm görünümü ile birebir eşleşir. |
| `calc.index.plate.subtitle` | Welche Plates für dein Zielgewicht — mit Inventar-Cap und visualer Stange. | Which plates for your target weight — with inventory cap and visual bar. | Hedef ağırlığın için hangi plakalar — envanter sınırı ve görsel barla. |
| `calc.index.plate.title` | Hantel-Rechner | Plate Calculator | Plaka Hesaplayıcı |
| `calc.index.tdee.subtitle` | BMR + TDEE aus deinem Profil und Aktivitäts-Level. | BMR + TDEE from your profile and activity level. | Profil ve aktivite seviyenden BMR + TDEE. |
| `calc.index.tdee.title` | Kalorien-Rechner | Calorie Calculator | Kalori Hesaplayıcı |
| `calc.index.title` | Rechner | Calculators | Hesaplayıcılar |
| `calc.index.water.subtitle` | Tagesziel = Gewicht × 35 ml. Mit Quick-Add. | Daily goal = weight × 35 ml. With quick-add. | Günlük hedef = kilo × 35 ml. Hızlı ekleme ile. |
| `calc.index.water.title` | Wasser-Tracker | Water Tracker | Su Takipçisi |
| `calc.plate.bar` | Stange (%@) | Bar (%@) | Bar (%@) |
| `calc.plate.loaded` | Geladen gesamt | Total Loaded | Yüklenen Toplam |
| `calc.plate.maxBar` | Maximal %1$@ %2$@ Stange. | Max %1$@ %2$@ bar. | Maks. %1$@ %2$@ bar. |
| `calc.plate.maxTarget` | Maximal %1$@ %2$@ Zielgewicht. | Max %1$@ %2$@ target weight. | Maks. %1$@ %2$@ hedef ağırlık. |
| `calc.plate.perSide` | Pro Seite | Per Side | Tarafa |
| `calc.plate.resetInventory` | Inventar zurücksetzen | Reset Inventory | Envanteri Sıfırla |
| `calc.plate.section.input` | Zielgewicht & Stange | Target & Bar | Hedef & Bar |
| `calc.plate.section.inventory` | Inventar pro Seite | Inventory Per Side | Tarafa Envanter |
| `calc.plate.section.results` | Ergebnis | Result | Sonuç |
| `calc.plate.shortOfTarget` | Mit deinem Inventar nur %1$@ %2$@ erreichbar (%3$@). | Only %1$@ %2$@ reachable with your inventory (%3$@). | Envanterinle sadece %1$@ %2$@ ulaşılabilir (%3$@). |
| `calc.plate.target` | Zielgewicht (%@) | Target Weight (%@) | Hedef Ağırlık (%@) |
| `calc.plate.unit` | Einheit | Unit | Birim |
| `calc.plate.unit.footer` | App-weit umschaltbar. DB speichert immer metrisch — nur die Anzeige ändert sich. | Switchable app-wide. DB always stores metric — only the display changes. | Uygulama genelinde değiştirilebilir. Veritabanı her zaman metrik kaydeder — sadece görünüm değişir. |
| `calc.tdee.activity` | Aktivität | Activity | Aktivite |
| `calc.tdee.age` | Alter | Age | Yaş |
| `calc.tdee.bmrKatch` | BMR (Katch-McArdle) | BMR (Katch-McArdle) | BMR (Katch-McArdle) |
| `calc.tdee.bmrMifflin` | BMR (Mifflin-St-Jeor) | BMR (Mifflin-St-Jeor) | BMR (Mifflin-St-Jeor) |
| `calc.tdee.bulk` | Bulk (+300) | Bulk (+300) | Bulk (+300) |
| `calc.tdee.cut` | Cut (-500) | Cut (-500) | Cut (-500) |
| `calc.tdee.height` | Größe | Height | Boy |
| `calc.tdee.maintenance` | Erhaltung | Maintenance | Koruma |
| `calc.tdee.noProfile.message` | Lege erst dein Profil im Onboarding an. | Set up your profile in onboarding first. | Önce profilini başlangıçta oluştur. |
| `calc.tdee.noProfile.title` | Kein Profil | No profile | Profil yok |
| `calc.tdee.section.input` | Aktuelles Gewicht & Aktivität | Current Weight & Activity | Mevcut Kilo & Aktivite |
| `calc.tdee.section.profile` | Aus deinem Profil | From your profile | Profilinden |
| `calc.tdee.section.results` | Energiebedarf | Energy Needs | Enerji İhtiyacı |
| `calc.tdee.tdee` | TDEE | TDEE | TDEE |
| `calc.tdee.title` | Kalorien-Rechner | Calorie Calculator | Kalori Hesaplayıcı |
| `calc.tdee.weightLabel` | Gewicht (kg) | Weight (kg) | Ağırlık (kg) |
| `calc.tdee.weightPlaceholder` | z.B. %@ | e.g. %@ | örn. %@ |
| `calc.tdee.weightRequired` | Trag dein aktuelles Gewicht ein. | Enter your current weight. | Mevcut kilonu gir. |

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

## `common.*`  (9 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `common.add` | Hinzufügen | Add | Ekle |
| `common.back` | Zurück | Back | Geri |
| `common.cancel` | Abbrechen | Cancel | İptal |
| `common.close` | Schließen | Close | Kapat |
| `common.delete` | Löschen | Delete | Sil |
| `common.discard` | Verwerfen | Discard | Sil |
| `common.done` | Fertig | Done | Bitti |
| `common.edit` | Bearbeiten | Edit | Düzenle |
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

## `day.*`  (24 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `day.editor.equipmentConflict.justAdd` | Nur Übung hinzufügen | Add exercise only | Sadece hareketi ekle |
| `day.editor.equipmentConflict.message` | „%1$@" erfordert Equipment, das in %2$@-Plänen normalerweise nicht verfügbar ist. Möchtest du den Plan-Typ entsprechend anpassen? | "%1$@" requires equipment that's not normally available in %2$@ plans. Want to adjust the plan type? | "%1$@" %2$@ planlarında genellikle bulunmayan ekipman gerektirir. Plan tipini değiştirmek ister misin? |
| `day.editor.equipmentConflict.switchPlan` | Plan auf %@ umstellen | Switch plan to %@ | Planı %@ olarak değiştir |
| `day.editor.equipmentConflict.title` | Equipment-Konflikt | Equipment Conflict | Ekipman Çakışması |
| `day.editor.exercises.editHint` | Tippe eine Übung an um sie zu bearbeiten. „Bearbeiten" oben rechts aktiviert die Drag-Handles zum Umsortieren — Superset-Partner werden automatisch mit verschoben. | Tap an exercise to edit. "Edit" top-right enables drag handles for reordering — superset partners move together. | Düzenlemek için bir harekete dokun. Sağ üstteki "Düzenle" sıralama tutamaçlarını etkinleştirir — süperset eşleri birlikte hareket eder. |
| `day.editor.exercises.empty` | Noch keine Übungen. | No exercises yet. | Henüz hareket yok. |
| `day.editor.exercises.restDayEmpty` | Ruhetag — keine Übungen. | Rest day — no exercises. | Dinlenme günü — hareket yok. |
| `day.editor.field.name` | Name | Name | Ad |
| `day.editor.field.nextIntensity` | Nächste Intensität | Next Intensity | Sonraki Yoğunluk |
| `day.editor.field.type` | Typ | Type | Tip |
| `day.editor.field.weekday` | Wochentag | Weekday | Gün |
| `day.editor.section.exercises` | Übungen | Exercises | Hareketler |
| `day.editor.section.info` | Tag-Info | Day Info | Gün Bilgisi |
| `day.editor.start` | Training starten | Start Workout | Antrenmanı Başlat |
| `day.editor.start.hintEmpty` | Füge erst mindestens eine Übung hinzu, dann kannst du das Training starten. | Add at least one exercise first to start the workout. | Antrenmanı başlatmak için önce en az bir hareket ekle. |
| `day.editor.superset.link` | Verbinden | Link | Bağla |
| `day.editor.superset.unlink` | Trennen | Unlink | Ayır |
| `day.editor.templateLocked.exercises` | Template-Plan — Übungen sind festgelegt. Du kannst sie ansehen, aber nicht hinzufügen, entfernen oder umsortieren. | Template plan — exercises are fixed. You can view them but not add, remove, or reorder. | Şablon plan — hareketler sabit. Görüntüleyebilirsin ama ekleyemez, kaldıramaz veya sıralayamazsın. |
| `day.editor.templateLocked.footer` | Dieser Tag gehört zu einem vorgefertigten Plan-Template und kann strukturell nicht bearbeitet werden. Du kannst aber die Trainings-Intensität anpassen. | This day belongs to a built-in plan template and can't be edited structurally. You can adjust training intensity though. | Bu gün hazır bir plan şablonuna ait ve yapısal olarak düzenlenemez. Ancak antrenman yoğunluğunu ayarlayabilirsin. |
| `day.editor.untitled` | Tag | Day | Gün |
| `day.restDay.complete` | Ruhetag abschließen | Complete Rest Day | Dinlenme Gününü Tamamla |
| `day.restDay.complete.footer` | Markiert den Ruhetag als erledigt — kein leerer Eintrag in der History, aber der Plan-Pointer rückt zum nächsten echten Training. | Marks the rest day as done — no empty history entry, but the plan pointer advances to the next real training day. | Dinlenme gününü tamamlandı olarak işaretler — geçmişte boş kayıt olmaz ama plan işaretçisi bir sonraki gerçek antrenmana ilerler. |
| `day.restDay.heroMessage` | Regeneration ist Teil des Plans. Hak den Tag ab, wenn du durch bist — dein Plan-Pointer springt automatisch zum nächsten echten Training. | Recovery is part of the plan. Check off the day when you're done — your plan pointer jumps to the next real training day automatically. | Toparlanma planın bir parçasıdır. Bitince günü işaretle — plan işaretçisi otomatik olarak bir sonraki gerçek antrenman gününe atlar. |
| `day.restDay.title` | Ruhetag | Rest Day | Dinlenme Günü |

## `dayPicker.*`  (3 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `dayPicker.prompt` | Wähle exakt %lld Tage, an denen du trainieren möchtest. | Choose exactly %lld days you want to train. | Antrenman yapmak istediğin tam olarak %lld gün seç. |
| `dayPicker.startPlan` | Plan starten | Start Plan | Planı Başlat |
| `dayPicker.title` | Trainingstage wählen | Choose Training Days | Antrenman Günleri |

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

## `editor.*`  (5 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `editor.exercise.distanceKm` | Distanz (km) | Distance (km) | Mesafe (km) |
| `editor.exercise.rest` | Pause | Rest | Mola |
| `editor.exercise.sets` | Sätze | Sets | Set |
| `editor.exercise.smartOff` | Aus = das Gewicht wird nie automatisch geändert. Du behältst die volle Kontrolle. | Off = weight never auto-adjusts. You stay in full control. | Kapalı = ağırlık asla otomatik değişmez. Kontrol sende. |
| `editor.exercise.templateLocked` | Template-Übung — Name und Cardio/Zeit-Flags sind festgelegt. | Template exercise — name and cardio/time flags are fixed. | Şablon hareket — ad ve kardiyo/süre bayrakları sabit. |

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

## `exercise.*`  (124 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `exercise.name.australianPullup` | Australian Pull-ups | Australian Pull-Up | Australian Pull-Up |
| `exercise.name.backWidows` | Back Widows | Back Widow | Back Widow |
| `exercise.name.bandCurl` | Band Curls | Band Curls | Band Curls |
| `exercise.name.bandPullApart` | Band Pull-Aparts | Band Pull-Aparts | Band Pull-Aparts |
| `exercise.name.bandedHipThrust` | Banded Hip Thrust | Banded Hip Thrust | Banded Hip Thrust |
| `exercise.name.bandedSquat` | Banded Squats | Banded Squats | Banded Squats |
| `exercise.name.barbellCurl` | Bizeps-Curl (LH) | Barbell Curl | Barbell Curl |
| `exercise.name.barbellHipThrust` | Hip Thrust (LH) | Barbell Hip Thrust | Barbell Hip Thrust |
| `exercise.name.barbellLunge` | Ausfallschritte (LH) | Barbell Lunges | Barbell Lunges |
| `exercise.name.barbellShrug` | Shrug (LH) | Barbell Shrug | Barbell Shrug |
| `exercise.name.barbellStandingCalfRaise` | Wadenheben (stehend, LH) | Standing Calf Raise (Barbell) | Standing Calf Raise |
| `exercise.name.barbellrow` | Rudern vorgebeugt | Bent-Over Row | Bent-Over Row |
| `exercise.name.behindNeckPress` | Nackendrücken | Behind-the-Neck Press | Behind-the-Neck Press |
| `exercise.name.benchpress` | Bankdrücken | Bench Press | Bench Press |
| `exercise.name.bicepcurl` | Bizeps-Curl (KH) | Dumbbell Curl | Dumbbell Curl |
| `exercise.name.bodyweightCalfRaise` | Wadenheben (BW) | Bodyweight Calf Raise | Bodyweight Calf Raise |
| `exercise.name.bodyweightHipThrust` | Hip Thrust (BW) | Bodyweight Hip Thrust | Bodyweight Hip Thrust |
| `exercise.name.bodyweightLunge` | Ausfallschritte (BW) | Bodyweight Lunges | Bodyweight Lunges |
| `exercise.name.bodyweightSquat` | Kniebeuge (BW) | Bodyweight Squat | Bodyweight Squat |
| `exercise.name.boxJump` | Box Jump | Box Jump | Box Jump |
| `exercise.name.bulgarianSplitSquatDB` | Bulgarische Kniebeuge (KH) | Dumbbell Bulgarian Split Squat | Dumbbell Bulgarian Split Squat |
| `exercise.name.burpee` | Burpees | Burpees | Burpees |
| `exercise.name.cableCrossover` | Kabel Crossover | Cable Crossover | Cable Crossover |
| `exercise.name.cableCrunch` | Kabel Crunch | Cable Crunch | Cable Crunch |
| `exercise.name.cableCurl` | Kabel Curl | Cable Curl | Cable Curl |
| `exercise.name.cableLateralRaise` | Kabel Seitheben | Cable Lateral Raise | Cable Lateral Raise |
| `exercise.name.cableOverheadTricepExtension` | Trizepsstrecker über Kopf (Kabel) | Cable Overhead Triceps Extension | Cable Overhead Triceps Extension |
| `exercise.name.chestDip` | Dips (Brust) | Chest Dips | Chest Dips |
| `exercise.name.chestPressMachine` | Brustdrücken (Maschine) | Machine Chest Press | Machine Chest Press |
| `exercise.name.chestSupportedRowDB` | Chest Supported Row (KH) | Chest-Supported Dumbbell Row | Chest-Supported Dumbbell Row |
| `exercise.name.closeGripBenchPress` | Enges Bankdrücken | Close-Grip Bench Press | Close-Grip Bench Press |
| `exercise.name.concentrationCurl` | Konzentrations-Curl (KH) | Concentration Curl | Concentration Curl |
| `exercise.name.crunch` | Crunches (BW) | Crunches | Mekik |
| `exercise.name.cycling` | Radfahren (outdoor) | Outdoor Cycling | Bisiklet |
| `exercise.name.deadlift` | Kreuzheben (konventionell) | Conventional Deadlift | Conventional Deadlift |
| `exercise.name.declineBenchPress` | Schrägbankdrücken (abwärts) | Decline Bench Press | Decline Bench Press |
| `exercise.name.diamondPushup` | Diamant-Liegestütze | Diamond Push-Up | Diamond Push-Up |
| `exercise.name.dumbbellBenchPress` | Bankdrücken (KH) | Dumbbell Bench Press | Dumbbell Bench Press |
| `exercise.name.dumbbellCalfRaise` | Wadenheben (KH) | Dumbbell Calf Raise | Dumbbell Calf Raise |
| `exercise.name.dumbbellFlyFlat` | Flyes flach (KH) | Flat Dumbbell Fly | Flat Dumbbell Fly |
| `exercise.name.dumbbellFlyIncline` | Flyes Schrägbank (KH) | Incline Dumbbell Fly | Incline Dumbbell Fly |
| `exercise.name.dumbbellHipThrust` | Hip Thrust (KH) | Dumbbell Hip Thrust | Dumbbell Hip Thrust |
| `exercise.name.dumbbellInclineBenchPress` | Schrägbankdrücken aufwärts (KH) | Incline Dumbbell Bench Press | Incline Dumbbell Bench Press |
| `exercise.name.dumbbellLunge` | Ausfallschritte (KH) | Dumbbell Lunges | Dumbbell Lunges |
| `exercise.name.dumbbellOverheadTricepExtension` | Trizepsstrecker über Kopf (KH) | Overhead Dumbbell Triceps Extension | Overhead Dumbbell Triceps Extension |
| `exercise.name.dumbbellPullover` | Pullover (KH) | Dumbbell Pullover | Dumbbell Pullover |
| `exercise.name.dumbbellRDL` | Rumänisches Kreuzheben (KH) | Dumbbell Romanian Deadlift | Dumbbell Romanian Deadlift |
| `exercise.name.dumbbellRowOneArm` | Rudern einarmig (KH) | One-Arm Dumbbell Row | One-Arm Dumbbell Row |
| `exercise.name.dumbbellShoulderPress` | Schulterdrücken (KH) | Dumbbell Shoulder Press | Dumbbell Shoulder Press |
| `exercise.name.dumbbellShrug` | Shrug (KH) | Dumbbell Shrug | Dumbbell Shrug |
| `exercise.name.dumbbellTricepKickback` | Trizepskickback (KH) | Dumbbell Triceps Kickback | Dumbbell Triceps Kickback |
| `exercise.name.easyRun` | Easy Run | Easy Run | Kolay Koşu |
| `exercise.name.elliptical` | Crosstrainer | Elliptical | Eliptik |
| `exercise.name.facePull` | Face Pull | Face Pull | Face Pull |
| `exercise.name.frontRaise` | Frontheben | Front Raise | Front Raise |
| `exercise.name.frontSquat` | Front Squat | Front Squat | Front Squat |
| `exercise.name.gluteBridge` | Glute Bridge (BW) | Glute Bridge | Glute Bridge |
| `exercise.name.gobletSquat` | Goblet Squat | Goblet Squat | Goblet Squat |
| `exercise.name.goodMorning` | Good Morning | Good Morning | Good Morning |
| `exercise.name.hackSquat` | Hack Squat | Hack Squat | Hack Squat |
| `exercise.name.hammerCurl` | Hammer Curl | Hammer Curl | Hammer Curl |
| `exercise.name.handstandPushup` | Handstand-Liegestütze | Handstand Push-Up | Handstand Push-Up |
| `exercise.name.hangingLegRaise` | Hanging Leg Raises | Hanging Leg Raise | Hanging Leg Raise |
| `exercise.name.inclineBenchPress` | Schrägbankdrücken (aufwärts) | Incline Bench Press | Incline Bench Press |
| `exercise.name.inclineDumbbellCurl` | Schrägbank-Curl (KH) | Incline Dumbbell Curl | Incline Dumbbell Curl |
| `exercise.name.intervals` | Intervalle | Intervals | İnterval |
| `exercise.name.jumpSquat` | Jump Squat | Jump Squat | Jump Squat |
| `exercise.name.kettlebellCleanAndPress` | Kettlebell Clean & Press | Kettlebell Clean & Press | Kettlebell Clean & Press |
| `exercise.name.kettlebellGobletSquat` | Kettlebell Goblet Squat | Kettlebell Goblet Squat | Kettlebell Goblet Squat |
| `exercise.name.kettlebellHalo` | Kettlebell Halo | Kettlebell Halo | Kettlebell Halo |
| `exercise.name.kettlebellSnatch` | Kettlebell Snatch | Kettlebell Snatch | Kettlebell Snatch |
| `exercise.name.kettlebellSwing` | Kettlebell Swing | Kettlebell Swing | Kettlebell Swing |
| `exercise.name.latPulldownClose` | Latzug (eng) | Close-Grip Lat Pulldown | Close-Grip Lat Pulldown |
| `exercise.name.lateralRaise` | Seitheben | Lateral Raise | Lateral Raise |
| `exercise.name.latpulldown` | Latzug (weit) | Wide-Grip Lat Pulldown | Wide-Grip Lat Pulldown |
| `exercise.name.legExtension` | Beinstrecker | Leg Extension | Leg Extension |
| `exercise.name.legpress` | Beinpresse | Leg Press | Leg Press |
| `exercise.name.longRun` | Long Run | Long Run | Uzun Koşu |
| `exercise.name.lyingLegCurl` | Beinbeuger liegend | Lying Leg Curl | Lying Leg Curl |
| `exercise.name.lyingLegExtension` | Beinstrecker liegend | Lying Leg Extension | Lying Leg Extension |
| `exercise.name.lyingLegRaise` | Beinheben (liegend) | Lying Leg Raise | Lying Leg Raise |
| `exercise.name.mountainClimber` | Mountain Climbers | Mountain Climbers | Mountain Climbers |
| `exercise.name.nordicCurl` | Nordic Curls | Nordic Curl | Nordic Curl |
| `exercise.name.overheadpress` | Schulterdrücken (stehend) | Standing Overhead Press | Standing Overhead Press |
| `exercise.name.pecDeck` | Pec Deck (Butterfly) | Pec Deck | Pec Deck |
| `exercise.name.pendlayRow` | Pendlay Row | Pendlay Row | Pendlay Row |
| `exercise.name.pikePushup` | Pike Liegestütze | Pike Push-Up | Pike Push-Up |
| `exercise.name.plank` | Plank | Plank | Plank |
| `exercise.name.preacherCurl` | Preacher Curl (Maschine) | Machine Preacher Curl | Machine Preacher Curl |
| `exercise.name.pullup` | Klimmzüge (eng/Chin-up) | Chin-Up | Barfiks (Chin-Up) |
| `exercise.name.pushPress` | Push Press | Push Press | Push Press |
| `exercise.name.pushup` | Liegestütze | Push-Up | Şınav |
| `exercise.name.rest` | Pause | Rest | Dinlenme |
| `exercise.name.reverseCurl` | Reverse Curl | Reverse Curl | Reverse Curl |
| `exercise.name.reverseFlyDB` | Reverse Flyes (KH) | Dumbbell Reverse Fly | Dumbbell Reverse Fly |
| `exercise.name.romanianDeadlift` | Rumänisches Kreuzheben | Romanian Deadlift | Romanian Deadlift |
| `exercise.name.rowingMachine` | Rudermaschine | Rowing Machine | Kürek Ergometresi |
| `exercise.name.run` | Freier Lauf | Outdoor Run | Koşu |
| `exercise.name.russianTwist` | Russian Twists | Russian Twist | Russian Twist |
| `exercise.name.seatedCableRow` | Kabelrudern sitzend | Seated Cable Row | Seated Cable Row |
| `exercise.name.seatedCalfRaise` | Wadenpresse (sitzend) | Seated Calf Press | Seated Calf Press |
| `exercise.name.shoulderPressMachine` | Schulterdrücken (Maschine) | Machine Shoulder Press | Machine Shoulder Press |
| `exercise.name.sidePlank` | Seitstütz | Side Plank | Side Plank |
| `exercise.name.sissySquat` | Sissy Squats (BW) | Sissy Squat | Sissy Squat |
| `exercise.name.situp` | Sit-ups | Sit-Up | Sit-Up |
| `exercise.name.skullCrusher` | Skull Crusher | Skull Crusher | Skull Crusher |
| `exercise.name.smithMachineSquat` | Smith Machine Squat | Smith Machine Squat | Smith Machine Squat |
| `exercise.name.squat` | Kniebeuge | Back Squat | Back Squat |
| `exercise.name.stairStepper` | Stepper | Stair Stepper | Stepper |
| `exercise.name.stationaryBike` | Fahrradergometer | Exercise Bike | Egzersiz Bisikleti |
| `exercise.name.stepUpDB` | Step-Up (KH) | Dumbbell Step-Up | Dumbbell Step-Up |
| `exercise.name.sumoDeadlift` | Sumo-Kreuzheben | Sumo Deadlift | Sumo Deadlift |
| `exercise.name.swimming` | Schwimmen | Swimming | Yüzme |
| `exercise.name.tBarRow` | T-Bar Rudern | T-Bar Row | T-Bar Row |
| `exercise.name.towelRowDoorframe` | Handtuch-Rudern (Türrahmen) | Towel Row (Doorframe) | Towel Row |
| `exercise.name.treadmill` | Laufband | Treadmill | Koşu Bandı |
| `exercise.name.tricepDip` | Dips (Trizeps) | Triceps Dips | Triceps Dips |
| `exercise.name.tricepPushdown` | Trizepsdrücken (Kabel) | Cable Triceps Pushdown | Cable Triceps Pushdown |
| `exercise.name.turkishGetUp` | Turkish Get-Up | Turkish Get-Up | Türk Kalkışı |
| `exercise.name.wallSit` | Wall Sit | Wall Sit | Wall Sit |
| `exercise.name.warmupWalk` | Gehen / Einlaufen | Warm-Up Walk | Isınma Yürüyüşü |
| `exercise.name.widePullup` | Klimmzüge (weit) | Wide-Grip Pull-Up | Wide-Grip Pull-Up |
| `exercise.name.widePushup` | Breite Liegestütze | Wide Push-Up | Wide Push-Up |
| `exercise.name.zercherSquat` | Zercher Squat | Zercher Squat | Zercher Squat |

## `gear.*`  (19 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `gear.editor.distance.footer` | Laufschuhe verlieren nach ~600–800 km ihre Dämpfung. Bei Erreichen des Maximums warnt die App. | Running shoes lose cushioning after ~600–800 km. The app warns when you hit the max. | Koşu ayakkabıları ~600–800 km sonra yastıklamasını kaybeder. Maks. ulaşıldığında uygulama uyarır. |
| `gear.editor.field.currentKm` | Bisherige km | Current km | Mevcut km |
| `gear.editor.field.maxKm` | Max. km | Max km | Maks. km |
| `gear.editor.field.name` | Name (z.B. Nike Pegasus 40) | Name (e.g. Nike Pegasus 40) | Ad (örn. Nike Pegasus 40) |
| `gear.editor.field.type` | Typ | Type | Tip |
| `gear.editor.section.distance` | Distanz | Distance | Mesafe |
| `gear.editor.section.general` | Allgemein | General | Genel |
| `gear.editor.title.edit` | Bearbeiten | Edit | Düzenle |
| `gear.editor.title.new` | Neue Ausrüstung | New Gear | Yeni Ekipman |
| `gear.editor.toggle.active` | Aktiv (im Picker anbieten) | Active (show in picker) | Aktif (seçicide göster) |
| `gear.editor.type.bike` | Fahrrad | Bike | Bisiklet |
| `gear.editor.type.shoe` | Laufschuh | Shoe | Ayakkabı |
| `gear.inactive` | INAKTIV | INACTIVE | PASİF |
| `gear.list.empty.cta` | Schuh anlegen | Add Shoe | Ayakkabı Ekle |
| `gear.list.empty.description` | Lege deine Laufschuhe an, damit die App deine Kilometer automatisch trackt. | Add your running shoes so the app tracks your kilometers automatically. | Koşu ayakkabılarını ekle, uygulama kilometreni otomatik takip etsin. |
| `gear.list.empty.title` | Noch keine Ausrüstung | No gear yet | Henüz ekipman yok |
| `gear.list.footer` | Cardio-Workouts buchen ihre Distanz automatisch auf den im Finish-Sheet ausgewählten Schuh. | Cardio workouts log distance to the shoe selected in the finish sheet. | Kardiyo antrenmanları, bitiş sayfasında seçilen ayakkabıya mesafe ekler. |
| `gear.list.title` | Ausrüstung | Gear | Ekipman |
| `gear.needsReplacement` | Schuh erneuern — Dämpfung erschöpft. | Replace shoe — cushioning depleted. | Ayakkabıyı değiştir — yastıklama tükendi. |

## `history.*`  (2 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `history.empty.description` | Beende dein erstes Training, um deine Historie zu sehen. | Finish your first workout to see your history. | Geçmişini görmek için ilk antrenmanını bitir. |
| `history.empty.title` | Noch keine Workouts | No workouts yet | Henüz antrenman yok |

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

## `onboarding.*`  (44 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `onboarding.action.create` | Profil anlegen | Create profile | Profil Oluştur |
| `onboarding.body.weightInitial` | Wird im Hintergrund als initiale Messung gespeichert. | Saved in the background as your initial measurement. | Arka planda ilk ölçüm olarak kaydedilir. |
| `onboarding.body.weightRequired` | Pflichtfeld — wird als erste Messung gespeichert. | Required — saved as your first measurement. | Zorunlu — ilk ölçüm olarak kaydedilir. |
| `onboarding.body.weightZero` | Gewicht muss > 0 sein. | Weight must be > 0. | Kilo > 0 olmalı. |
| `onboarding.coaching.title` | Dein Coaching-Stil | Your coaching style | Koçluk tarzın |
| `onboarding.environment.footnote1` | Trainingsort filtert Plan-Empfehlungen und die Equipment-Auswahl beim Übungs-Tausch. | Training location filters plan recommendations and equipment options when swapping exercises. | Antrenman yeri plan önerilerini ve hareket değiştirirken ekipman seçeneklerini filtreler. |
| `onboarding.environment.footnote2` | Hybrid- oder reine Lauf-Athleten wählen ihren Strength-Ort — die Hybrid-Pläne enthalten ihre Run-Tage unabhängig davon. | Hybrid or pure running athletes pick their strength location — Hybrid plans include run days regardless. | Hibrit veya saf koşu sporcuları güç antrenman yerini seçer — Hibrit planlar koşu günlerini her durumda içerir. |
| `onboarding.field.birthdate` | Geburtsdatum | Birth date | Doğum Tarihi |
| `onboarding.field.environment` | Trainingsort | Training Location | Antrenman Yeri |
| `onboarding.field.goalWeightKg` | Zielgewicht (kg, optional) | Goal Weight (kg, optional) | Hedef Kilo (kg, opsiyonel) |
| `onboarding.field.goal_weight` | Zielgewicht (kg, optional) | Goal weight (kg, optional) | Hedef Kilo (kg, isteğe bağlı) |
| `onboarding.field.height` | Größe (cm) | Height (cm) | Boy (cm) |
| `onboarding.field.heightCm` | Größe (cm) | Height (cm) | Boy (cm) |
| `onboarding.field.sex` | Geschlecht | Sex | Cinsiyet |
| `onboarding.field.weightCurrentKg` | Aktuelles Gewicht (kg) | Current Weight (kg) | Mevcut Kilo (kg) |
| `onboarding.goal.subtitle` | Wir kalibrieren Insights, Recovery-Hinweise und Coaching-Botschaften entsprechend. | We calibrate insights, recovery hints, and coaching messages accordingly. | Öngörüleri, toparlanma ipuçlarını ve koçluk mesajlarını buna göre ayarlarız. |
| `onboarding.goal.title` | Was ist dein primärer Fokus? | What's your primary focus? | Birincil odağın ne? |
| `onboarding.health.connected` | Verbunden | Connected | Bağlı |
| `onboarding.health.denied` | Apple Health-Berechtigung verweigert. Aktiviere sie später in iOS-Einstellungen → Datenschutz → Apple Health → Deltiq. | Apple Health permission denied. Enable it later in iOS Settings → Privacy → Apple Health → Deltiq. | Apple Health izni reddedildi. iOS Ayarlar → Gizlilik → Apple Health → Deltiq'ten etkinleştirebilirsin. |
| `onboarding.health.intro` | Wenn du Apple Health verbindest, ziehen wir Alter, Geschlecht, Größe und Gewicht aus deinem Profil — du musst nichts doppelt tippen. Diesen Schritt kannst du auch überspringen. | Connect Apple Health and we'll pull age, sex, height, and weight from your profile — no double-entry. You can also skip this step. | Apple Health'i bağlarsan yaş, cinsiyet, boy ve kilonu profilinden çekeriz — iki kere yazmana gerek yok. Bu adımı atlayabilirsin. |
| `onboarding.health.loading` | Lade … | Loading … | Yükleniyor … |
| `onboarding.health.pull` | Daten aus Apple Health übernehmen | Import from Apple Health | Apple Health'ten Al |
| `onboarding.health.pulled` | Daten übernommen — du kannst sie im nächsten Schritt prüfen. | Data imported — review in the next step. | Veriler alındı — bir sonraki adımda kontrol edebilirsin. |
| `onboarding.health.title` | Apple Health verbinden | Connect Apple Health | Apple Health'i Bağla |
| `onboarding.health.unavailable` | Apple Health ist auf diesem Gerät nicht verfügbar. | Apple Health is not available on this device. | Apple Health bu cihazda kullanılamıyor. |
| `onboarding.intro.body` | Für akkurate Berechnungen (BMI, KFA, FFMI, BMR) brauchen wir Sex, Alter und Größe. Alle Werte kannst du später unter Profil ändern. | For accurate calculations (BMI, body-fat, FFMI, BMR) we need sex, age, and height. You can change everything later in your profile. | Doğru hesaplamalar (BKİ, yağ oranı, FFMI, BMR) için cinsiyet, yaş ve boya ihtiyacımız var. Tüm değerleri sonradan Profil altında değiştirebilirsin. |
| `onboarding.intro.title` | Lass uns starten | Let's get started | Hadi başlayalım |
| `onboarding.notif.footnote` | Beide nutzen lokale Notifications. Beim Aktivieren fragt iOS einmalig nach der Berechtigung. | Both use local notifications. iOS asks once for permission when enabled. | Her ikisi de yerel bildirimleri kullanır. Etkinleştirildiğinde iOS bir kez izin ister. |
| `onboarding.notif.measurement` | Mess-Erinnerung | Measurement Reminder | Ölçüm Hatırlatıcısı |
| `onboarding.notif.section` | Benachrichtigungen | Notifications | Bildirimler |
| `onboarding.notif.water` | Wasser-Erinnerung | Water Reminder | Su Hatırlatıcısı |
| `onboarding.plan.footnote` | Templates sind nach deinem Trainingsort gefiltert (%@). Auch ohne Plan starten ist okay. | Templates are filtered by your training location (%@). Starting without a plan is fine too. | Şablonlar antrenman yerine göre filtrelendi (%@). Plansız başlamak da mümkün. |
| `onboarding.plan.noTemplates` | Keine Templates für '%@'. Du kannst trotzdem ohne Plan starten und später einen eigenen anlegen. | No templates for '%@'. You can still start without a plan and create your own later. | '%@' için şablon yok. Plansız başlayıp sonradan kendi planını oluşturabilirsin. |
| `onboarding.plan.quizCard.footnote` | Empfohlen, wenn du nicht weißt, welcher Plan zu dir passt. Du kannst stattdessen auch direkt aus der Liste unten wählen. | Recommended if you're not sure which plan fits. You can also pick directly from the list below. | Hangi planın sana uygun olduğundan emin değilsen önerilir. Aşağıdaki listeden de doğrudan seçebilirsin. |
| `onboarding.plan.quizCard.subtitle` | 4 kurze Fragen — wir matchen dich auf den passenden Plan. | 4 quick questions — we match you to the right plan. | 4 kısa soru — sana uygun planı eşleştiririz. |
| `onboarding.plan.quizCard.title` | Plan finden lassen | Find a Plan | Plan Bul |
| `onboarding.plan.recommended` | Empfohlen | Recommended | Önerilen |
| `onboarding.plan.section` | Trainingsplan für %@ | Plans for %@ | %@ için Plan |
| `onboarding.section.body` | Körpermaße | Body Measurements | Vücut Ölçüleri |
| `onboarding.section.goals` | Ziel & Training | Goals & Training | Hedef & Antrenman |
| `onboarding.section.profile` | Profil | Profile | Profil |
| `onboarding.title` | Willkommen | Welcome | Hoş Geldin |
| `onboarding.tone.subtitle` | Wir passen Tonfall und Feedback an deinen Stil an. Lässt sich später ändern. | We adapt tone and feedback to your style. Changeable later. | Ton ve geri bildirimi tarzına uyarlarız. Sonradan değiştirilebilir. |
| `onboarding.tone.title` | Wie soll dein Coach klingen? | How should your coach sound? | Koçun nasıl bir ses tonu olsun? |

## `picker.*`  (8 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `picker.exercise.filterFor` | Nur Übungen für %@ | Only %@ exercises | Sadece %@ hareketleri |
| `picker.exercise.filterHint` | Wenn aus, siehst du auch Übungen, die zu deinem Plan-Typ nicht passen. Die App fragt dann beim Hinzufügen nach, ob du den Plan umstellen willst. | When off, you also see exercises that don't fit your plan type. The app asks when adding whether to switch the plan. | Kapalıyken plan tipine uymayan hareketleri de görürsün. Eklerken plan değişimi sorulur. |
| `picker.exercise.libraryEmpty` | Bibliothek ist leer — leg oben deine erste eigene Übung an. | Library is empty — create your first custom exercise above. | Kütüphane boş — yukarıdan ilk özel hareketini oluştur. |
| `picker.exercise.namePlaceholder` | Name (z.B. Bankdrücken) | Name (e.g. Bench Press) | Ad (örn. Bench Press) |
| `picker.exercise.title` | Übung wählen | Choose Exercise | Hareket Seç |
| `picker.plan.adoptFootnote` | Beim Übernehmen wird eine Tiefkopie für deine eigene Bibliothek angelegt — Tage, Übungen, Sätze sind danach frei editierbar. | Adopting creates a deep copy in your library — days, exercises, and sets are then freely editable. | Plan alındığında kütüphanende derin kopya oluşturulur — günler, hareketler ve setler özgürce düzenlenebilir. |
| `picker.plan.filterFootnote` | Gefiltert nach deinem Trainingsort (%@). Im Profil anpassen, wenn du auch andere Pläne sehen willst. | Filtered by your training location (%@). Adjust in profile to see other plans. | Antrenman yerine göre filtrelendi (%@). Diğer planları görmek için profilden ayarla. |
| `picker.plan.title` | Programm wählen | Choose Program | Program Seç |

## `plan.*`  (101 Keys)

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
| `plan.dayNumberLabel` | Tag %lld | Day %lld | Gün %lld |
| `plan.template.arnoldSplit` | Arnold Split | Arnold Split | Arnold Split |
| `plan.template.arnoldSplit.description` | Arnold Schwarzeneggers Trainingsansatz: Antagonisten (Brust+Rücken) werden gemeinsam trainiert für maximalen Pump und Dichte. | Arnold Schwarzenegger's training approach: antagonist muscles (chest + back) are trained together for maximum pump and density. | Arnold Schwarzenegger'in antrenman yaklaşımı: antagonist kaslar (göğüs + sırt) maksimum pump ve yoğunluk için birlikte çalıştırılır. |
| `plan.template.arnoldSplit.focus` | Hypertrophie | Hypertrophy | Hipertrofi |
| `plan.template.arnoldSplit.tagline` | 6 Tage · Bodybuilding | 6 Days · Bodybuilding | 6 Gün · Vücut Geliştirme |
| `plan.template.bodyweightMastery` | Bodyweight Mastery | Bodyweight Mastery | Bodyweight Mastery |
| `plan.template.bodyweightMastery.description` | Komplettes Körpergewichtstraining ohne ein einziges Gerät. Kürzere Pausen und isometrische Übungen sorgen für maximalen Trainingsreiz. | Complete bodyweight training without a single piece of equipment. Shorter rest periods and isometric exercises maximize training stimulus. | Tek bir ekipman olmadan komple vücut ağırlığı antrenmanı. Kısa molalar ve izometrik hareketler maksimum antrenman uyarısı sağlar. |
| `plan.template.bodyweightMastery.focus` | Funktionelle Fitness | Functional Fitness | Fonksiyonel Fitness |
| `plan.template.bodyweightMastery.tagline` | 3 Tage · Funktionelles Training ohne Geräte | 3 Days · Functional Training, No Equipment | 3 Gün · Ekipmansız Fonksiyonel Antrenman |
| `plan.template.broSplit` | Bro-Split | Bro-Split | Bro-Split |
| `plan.template.broSplit.description` | Klassischer Bodybuilding-Split mit hohem Volumen pro Muskelgruppe. Jede Muskelgruppe wird einmal pro Woche mit maximaler Erschöpfung trainiert. | Classic bodybuilding split with high volume per muscle group. Each muscle group is trained once per week to maximum exhaustion. | Kas grubu başına yüksek hacimli klasik vücut geliştirme bölünmesi. Her kas grubu haftada bir kez maksimum yorgunluğa kadar çalıştırılır. |
| `plan.template.broSplit.focus` | Hypertrophie | Hypertrophy | Hipertrofi |
| `plan.template.broSplit.tagline` | 5 Tage · Hypertrophie | 5 Days · Hypertrophy | 5 Gün · Hipertrofi |
| `plan.template.fatBurnFullBody` | Fatburn Ganzkörper | Fat Loss Full Body | Yağ Yakımı Tüm Vücut |
| `plan.template.fatBurnFullBody.description` | Effektiver Ganzkörperplan für maximalen Kalorienverbrauch. Kurze Pausen (60s) halten die Herzfrequenz oben — kombiniert mit einem Cardio-Finisher am Ende jeder Einheit. | Effective full-body plan for maximum calorie burn. Short rest periods (60s) keep heart rate elevated — combined with a cardio finisher at the end of each session. | Maksimum kalori yakımı için etkili tüm vücut planı. Kısa molalar (60s) kalp atış hızını yüksek tutar — her seansın sonunda kardiyo finisher ile birleştirilir. |
| `plan.template.fatBurnFullBody.focus` | Fatburn | Fat Loss | Yağ Yakımı |
| `plan.template.fatBurnFullBody.tagline` | 3 Tage · Fatburn & Kondition | 3 Days · Fat Burn & Conditioning | 3 Gün · Yağ Yakımı & Kondisyon |
| `plan.template.footballAthletic` | Fussball Athletik | Football Athletic | Futbol Atletik |
| `plan.template.footballAthletic.description` | Athletik-Programm für Mannschaftssportler: Maximalkraft und Schnellkraft in zwei kompakten Einheiten pro Woche — ideal als Ergänzung zum Vereinstraining. | Athletics program for team-sport athletes: maximum strength and power in two compact sessions per week — ideal as a complement to club training. | Takım sporcuları için atletik program: haftada iki kompakt seansta maksimum güç ve patlayıcı kuvvet — kulüp antrenmanına ideal tamamlayıcı. |
| `plan.template.footballAthletic.focus` | Athletik | Athletics | Atletik |
| `plan.template.footballAthletic.tagline` | 2 Tage · Kraft & Explosivität | 2 Days · Strength & Explosiveness | 2 Gün · Güç & Patlayıcılık |
| `plan.template.fullBody3x` | Ganzkörper 3x | Full Body 3x | Tüm Vücut 3x |
| `plan.template.fullBody3x.description` | Höchste Trainingsfrequenz pro Muskelgruppe. Laut Forschung optimal für Anfänger und Wiedereinstieg — maximales Signal für Muskelwachstum. | Highest training frequency per muscle group. Research-backed as optimal for beginners and re-entry — maximum signal for muscle growth. | Kas grubu başına en yüksek antrenman frekansı. Araştırmalar başlangıç ve yeniden başlama için ideal olduğunu gösteriyor — kas gelişimi için maksimum sinyal. |
| `plan.template.fullBody3x.focus` | Anfänger / Allgemein | Beginner / General | Başlangıç / Genel |
| `plan.template.fullBody3x.tagline` | 3 Tage · Anfänger & Re-Einstieg | 3 Days · Beginner & Re-Entry | 3 Gün · Başlangıç & Yeniden Başlama |
| `plan.template.homeGymHero` | Home Gym Hero | Home Gym Hero | Home Gym Hero |
| `plan.template.homeGymHero.description` | Effektiver Ganzkörperplan komplett mit Kurzhanteln. Ideal für das Training zuhause — kein Fitnessstudio nötig. | Effective full-body plan using only dumbbells. Ideal for training at home — no gym required. | Sadece dambıllarla etkili tüm vücut planı. Evde antrenman için ideal — salon gerekmez. |
| `plan.template.homeGymHero.focus` | Hypertrophie | Hypertrophy | Hipertrofi |
| `plan.template.homeGymHero.tagline` | 3 Tage · Muskelaufbau mit Kurzhanteln | 3 Days · Muscle Building with Dumbbells | 3 Gün · Dambıl ile Kas Gelişimi |
| `plan.template.hybridBalanced` | Hybrid Athlete — Balanced | Hybrid Athlete — Balanced | Hybrid Athlete — Balanced |
| `plan.template.hybridBalanced.description` | Drei fokussierte Strength-Einheiten (Push/Pull/Legs-Light) plus zwei strategisch platzierte Lauf-Tage. RIR-Puffer 2–3 verhindert systemische Erschöpfung — bleibt Trainings-vertrāglich. | Three focused strength sessions (Push/Pull/Legs-Light) plus two strategically placed run days. RIR buffer of 2–3 prevents systemic fatigue — stays training-compatible. | Üç odaklı güç seansı (Push/Pull/Hafif Bacak) artı iki stratejik konumlandırılmış koşu günü. RIR tamponu 2–3 sistemik yorgunluğu önler — antrenmana uyumlu kalır. |
| `plan.template.hybridBalanced.focus` | Hybrid & Athletik | Hybrid & Athletics | Hibrit & Atletik |
| `plan.template.hybridBalanced.tagline` | 5 Tage · Kraft + Ausdauer in Balance | 5 Days · Strength + Endurance Balanced | 5 Gün · Güç + Dayanıklılık Dengesi |
| `plan.template.hybridBeginner` | Hybrid Athlete — Beginner | Hybrid Athlete — Beginner | Hybrid Athlete — Beginner |
| `plan.template.hybridBeginner.description` | Concurrent-Training light: zwei Ganzkörper-Strength-Einheiten + zwei lockere Lauf-Tage pro Woche. RIR-Puffer schützt den Laufmotor, kein zerstörendes Versagens-Training. | Concurrent training light: two full-body strength sessions + two easy run days per week. RIR buffer protects the running engine — no destructive failure training. | Hafif eşzamanlı antrenman: haftada iki tüm vücut güç seansı + iki kolay koşu günü. RIR tamponu koşu motorunu korur — yıkıcı başarısızlık antrenmanı yok. |
| `plan.template.hybridBeginner.focus` | Hybrid & Athletik | Hybrid & Athletics | Hibrit & Atletik |
| `plan.template.hybridBeginner.tagline` | 4 Tage · Kraft + Laufen Einstieg | 4 Days · Strength + Running Intro | 4 Gün · Güç + Koşuya Giriş |
| `plan.template.hybridPerformance` | Hybrid Athlete — Performance | Hybrid Athlete — Performance | Hybrid Athlete — Performance |
| `plan.template.hybridPerformance.description` | Sechs Trainingstage: drei Strength-Einheiten (Push/Pull/Legs) + drei Läufe (Easy, Intervalle, Long Run). Strength-RIR konservativ 2.5, damit der Gesamt-Volumen-Stress trainings-vertraglich bleibt. | Six training days: three strength sessions (Push/Pull/Legs) + three runs (Easy, Intervals, Long Run). Conservative RIR of 2.5 on strength to keep total volume stress training-compatible. | Altı antrenman günü: üç güç seansı (Push/Pull/Bacak) + üç koşu (Kolay, İnterval, Uzun Koşu). Toplam hacim stresinin antrenmana uyumlu kalması için güçte ihtiyatlı RIR 2.5. |
| `plan.template.hybridPerformance.focus` | Hybrid & Athletik | Hybrid & Athletics | Hibrit & Atletik |
| `plan.template.hybridPerformance.tagline` | 6 Tage · Wettkampf-Hybrid | 6 Days · Competitive Hybrid | 6 Gün · Rekabetçi Hibrit |
| `plan.template.powerlifting3x5` | Powerlifting 3x5 | Powerlifting 3x5 | Powerlifting 3x5 |
| `plan.template.powerlifting3x5.description` | Dreier-Frequenz auf die Grundübungen Kniebeuge, Bankdrücken und Kreuzheben. Jede Session dreht sich um eine primäre Wettkampfübung mit schweren 3x5-Sätzen. | Triple frequency on the core lifts: squat, bench press, and deadlift. Each session focuses on one primary competition lift with heavy 3x5 sets. | Temel hareketler (squat, bench press, deadlift) için üçlü frekans. Her seans ağır 3x5 setleriyle bir ana yarışma hareketine odaklanır. |
| `plan.template.powerlifting3x5.focus` | Kraft | Strength | Güç |
| `plan.template.powerlifting3x5.tagline` | 3 Tage · Maximalkraft | 3 Days · Maximum Strength | 3 Gün · Maksimal Güç |
| `plan.template.powerlifting5x5` | Powerlifting 5x5 | Powerlifting 5x5 | Powerlifting 5x5 |
| `plan.template.powerlifting5x5.description` | Das bewährteste Kraft-Programm für Anfänger & Fortgeschrittene. Progressive Überlastung mit den Grundübungen — wissenschaftlich und praktisch belegt. | The most proven strength program for beginners and intermediates. Progressive overload with the main lifts — scientifically and practically validated. | Başlangıç ve orta seviye için en kanıtlanmış güç programı. Temel hareketlerle aşamalı yüklenme — bilimsel ve pratik olarak doğrulanmış. |
| `plan.template.powerlifting5x5.focus` | Kraft | Strength | Güç |
| `plan.template.powerlifting5x5.tagline` | 3 Tage · Kraft & Masse | 3 Days · Strength & Mass | 3 Gün · Güç & Kütle |
| `plan.template.pushPullLegs` | Push-Pull-Legs | Push-Pull-Legs | Push-Pull-Legs |
| `plan.template.pushPullLegs.description` | Wissenschaftlich optimierter Split. Jede Muskelgruppe wird 2x pro Woche trainiert – ideal für intermediäre Sportler laut Meta-Analysen. | Scientifically optimized split. Each muscle group trained 2x per week — ideal for intermediate lifters per meta-analyses. | Bilimsel olarak optimize edilmiş split. Her kas grubu haftada 2 kez çalıştırılır — meta-analizlere göre orta seviye sporcular için ideal. |
| `plan.template.pushPullLegs.focus` | Hypertrophie | Hypertrophy | Hipertrofi |
| `plan.template.pushPullLegs.tagline` | 6 Tage · Hypertrophie + Kraft | 6 Days · Hypertrophy + Strength | 6 Gün · Hipertrofi + Güç |
| `plan.template.upperLower` | Upper-Lower-Split | Upper-Lower Split | Upper-Lower Split |
| `plan.template.upperLower.description` | Optimale Balance zwischen Frequenz und Volumen. Laut Studienlage der effektivste Split für Kraft- und Muskelaufbau bei Intermediären. | Optimal balance between frequency and volume. Studies show this is the most effective split for strength and muscle building at the intermediate level. | Frekans ve hacim arasında optimal denge. Çalışmalar bunun orta seviyede güç ve kas gelişimi için en etkili split olduğunu gösteriyor. |
| `plan.template.upperLower.focus` | Kraft + Hypertrophie | Strength + Hypertrophy | Güç + Hipertrofi |
| `plan.template.upperLower.tagline` | 4 Tage · Kraft & Hypertrophie | 4 Days · Strength & Hypertrophy | 4 Gün · Güç & Hipertrofi |

## `planEditor.*`  (26 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `planEditor.days.add.training` | Trainingstag | Training Day | Antrenman Günü |
| `planEditor.days.empty.template` | Template hat keine Trainings-Tage konfiguriert (sollte nicht passieren). | Template has no training days configured (shouldn't happen). | Şablonun antrenman günleri yok (olmamalı). |
| `planEditor.days.empty.user` | Noch keine Trainings-Tage. Tippe '+' oben rechts um deinen ersten Tag anzulegen. | No training days yet. Tap '+' top-right to add your first day. | Henüz antrenman günü yok. İlk gününü eklemek için sağ üstteki '+' simgesine dokun. |
| `planEditor.days.footer.template` | Template — Tage sind festgelegt. Tippe einen Tag an, um die Übungen zu sehen. | Template — days are fixed. Tap a day to see its exercises. | Şablon — günler sabit. Hareketleri görmek için bir güne dokun. |
| `planEditor.days.footer.user` | Sortiert nach Wochentag (Mo-So). „Bearbeiten" oben rechts aktiviert den Drag-Mode — die Wochentage rotieren entsprechend mit, du musst sie nicht einzeln umstellen. | Sorted by weekday (Mon-Sun). "Edit" top-right enables drag mode — weekdays rotate accordingly, no manual reshuffle needed. | Hafta gününe göre sıralandı (Pzt-Pzr). Sağ üstteki "Düzenle" sürükleme modunu etkinleştirir — hafta günleri uygun şekilde döner, tek tek değiştirmen gerekmez. |
| `planEditor.envRestore.message` | Wir haben gespeicherte Original-Übungen aus einem früheren Equipment-Wechsel gefunden. Möchtest du diese wiederherstellen (inkl. der letzten Arbeitsgewichte aus der Historie), statt das aktuelle Setup neu anzupassen? | We found saved original exercises from a previous equipment change. Restore them (with the last working weights from history) instead of re-adapting the current setup? | Önceki bir ekipman değişikliğinden orijinal hareketler bulduk. Mevcut kurulumu yeniden uyarlamak yerine bunları (geçmişten son çalışma ağırlıklarıyla) geri yüklemek ister misin? |
| `planEditor.envSwap.adapt` | Übungen anpassen | Adapt Exercises | Hareketleri Uyarla |
| `planEditor.envSwap.justEnv` | Nur Trainingsort ändern | Change Location Only | Sadece Yeri Değiştir |
| `planEditor.envSwap.message` | Sollen die Übungen an deinen neuen Trainingsort angepasst werden? Übungen ohne passende Alternative bleiben im Plan und brauchen manuelle Anpassung. | Adapt exercises to the new training location? Exercises without a matching alternative stay in the plan and need manual adjustment. | Hareketler yeni antrenman yerine uyarlansın mı? Uygun alternatifi olmayan hareketler planda kalır ve manuel ayarlama gerektirir. |
| `planEditor.field.weeks` | Wochen | Weeks | Hafta |
| `planEditor.globalSync.allPlans` | Für alle anpassen | Adjust All | Hepsi için Ayarla |
| `planEditor.globalSync.message` | Du hast mehrere aktive Pläne. Soll dein globaler Trainingsort und deine anderen aktiven Pläne ebenfalls auf %@ geändert werden? | You have multiple active plans. Should your global training location and other active plans also switch to %@? | Birden çok aktif planın var. Genel antrenman yerin ve diğer aktif planların da %@ olarak değişsin mi? |
| `planEditor.globalSync.thisOnly` | Nur für diesen Plan | This Plan Only | Sadece Bu Plan |
| `planEditor.globalSync.title` | Auch andere Pläne anpassen? | Adjust Other Plans Too? | Diğer Planlar da Ayarlansın mı? |
| `planEditor.progressRIR.0` | RIR ≤ 0 (zum Versagen) | RIR ≤ 0 (to failure) | RIR ≤ 0 (yenilgiye) |
| `planEditor.progressRIR.1` | RIR ≤ 1 | RIR ≤ 1 | RIR ≤ 1 |
| `planEditor.progressRIR.2` | RIR ≤ 2 | RIR ≤ 2 | RIR ≤ 2 |
| `planEditor.progressRIR.3` | RIR ≤ 3 | RIR ≤ 3 | RIR ≤ 3 |
| `planEditor.progressRIR.auto` | Auto (pro Übung) | Auto (per exercise) | Otomatik (hareket başına) |
| `planEditor.progressRIR.label` | Progressions-Ziel-RIR | Progression Target RIR | İlerleme Hedef RIR |
| `planEditor.section.info` | Plan-Info | Plan Info | Plan Bilgisi |
| `planEditor.section.settings` | Einstellungen | Settings | Ayarlar |
| `planEditor.section.trainingDays` | Trainings-Tage | Training Days | Antrenman Günleri |
| `planEditor.template.banner.subtitle` | Struktur ist festgelegt. Du kannst Trainingsort und Wochen anpassen, aber Name/Tage/Übungen nicht ändern. | Structure is fixed. You can adjust training location and weeks, but not name/days/exercises. | Yapı sabit. Antrenman yerini ve haftaları ayarlayabilirsin ama ad/günler/hareketleri değiştiremezsin. |
| `planEditor.template.banner.title` | Template-Plan | Template Plan | Şablon Plan |
| `planEditor.toggle.setActive` | Als aktiven Plan setzen | Set as Active Plan | Aktif Plan Olarak Ayarla |

## `plans.*`  (12 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `plans.active.hint` | Tippe auf das Banner, um mit der Session weiterzumachen oder sie zu beenden. | Tap the banner to resume or end the session. | Banner'a dokunarak oturuma devam et veya bitir. |
| `plans.active.title` | Laufendes Training | Active Workout | Aktif Antrenman |
| `plans.activeBadge` | Aktiv | Active | Aktif |
| `plans.create.empty` | Leerer Plan | Empty Plan | Boş Plan |
| `plans.create.emptyShort` | Leer | Empty | Boş |
| `plans.create.fromTemplate` | Aus Template anlegen | From Template | Şablondan Oluştur |
| `plans.create.fromTemplateShort` | Aus Template | From Template | Şablondan |
| `plans.duplicate` | Duplizieren | Duplicate | Çoğalt |
| `plans.empty.hint` | Lege deinen ersten Trainings-Plan an — Tage, Übungen, Sätze. Der Plan ist die Grundlage für jede Session. | Create your first training plan — days, exercises, sets. The plan is the foundation of every session. | İlk antrenman planını oluştur — günler, hareketler, setler. Plan, her oturumun temelidir. |
| `plans.empty.title` | Noch kein Plan | No plans yet | Henüz plan yok |
| `plans.list.title` | Pläne | Plans | Planlar |
| `plans.new` | Neuer Plan | New Plan | Yeni Plan |

## `profile.*`  (25 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `profile.body.footerOk` | Alle Berechnungen lesen Höhe metrisch aus dieser Quelle. | All calculations read height metrically from this source. | Tüm hesaplamalar boyu metrik olarak bu kaynaktan okur. |
| `profile.body.heightPlaceholder` | z.B. 180 | e.g. 180 | örn. 180 |
| `profile.body.plausible` | Plausibel: %1$lld–%2$lld cm. | Plausible: %1$lld–%2$lld cm. | Makul: %1$lld–%2$lld cm. |
| `profile.coaching.footer` | Steuert Tonfall und Inhalt der Coaching-Insights auf dem Dashboard. Lässt sich jederzeit ändern. | Drives tone and content of coaching insights on the dashboard. Changeable any time. | Paneldeki koçluk öngörülerinin tonunu ve içeriğini yönlendirir. Her zaman değiştirilebilir. |
| `profile.coaching.goal` | Trainingsziel | Training Goal | Antrenman Hedefi |
| `profile.coaching.tone` | Coaching-Stil | Coaching Style | Koçluk Tarzı |
| `profile.envRestore.adjustNew` | Nein, neu anpassen | No, Re-Adjust | Hayır, Yeniden Uyarla |
| `profile.envRestore.confirm` | Ja, wiederherstellen | Yes, Restore | Evet, Geri Yükle |
| `profile.envRestore.message` | Wir haben Original-Übungen aus einem früheren Equipment-Wechsel gespeichert. Möchtest du diese in deinen Plänen wiederherstellen (inkl. der letzten Arbeitsgewichte)? | We saved original exercises from a previous equipment change. Restore them in your plans (with the last working weights)? | Önceki bir ekipman değişikliğinden orijinal hareketleri kaydettik. Bunları planlarına geri yüklemek ister misin (son çalışma ağırlıklarıyla)? |
| `profile.envRestore.title` | Ursprüngliche Übungen wiederherstellen? | Restore Original Exercises? | Orijinal Hareketler Geri Yüklensin mi? |
| `profile.envSwap.confirm` | Ja, Pläne anpassen | Yes, Adjust Plans | Evet, Planları Ayarla |
| `profile.envSwap.keep` | Nein, so lassen | No, Keep As-Is | Hayır, Olduğu Gibi Bırak |
| `profile.envSwap.message` | Du hast deinen Trainingsort auf %@ geändert. Sollen deine bestehenden Trainingspläne automatisch an das dort verfügbare Equipment angepasst werden? | You changed your training location to %@. Should existing plans be auto-adjusted to the equipment available there? | Antrenman yerini %@ olarak değiştirdin. Mevcut planlar oradaki ekipmana otomatik uyarlanmalı mı? |
| `profile.envSwap.title` | Trainingsort geändert | Training Location Changed | Antrenman Yeri Değişti |
| `profile.goal.footer` | Das Zielgewicht erscheint als grüne Linie im Dashboard-Trend-Chart. Trainingsort filtert später Plan-Empfehlungen. | Goal weight shows as a green line in the dashboard trend chart. Training location filters plan recommendations. | Hedef kilo, panel trend grafiğinde yeşil çizgi olarak görünür. Antrenman yeri plan önerilerini filtreler. |
| `profile.goal.weightPlaceholder` | z.B. 75 | e.g. 75 | örn. 75 |
| `profile.health.denied` | Berechtigung verweigert. Aktiviere sie in iOS-Einstellungen → Datenschutz → Apple Health → Deltiq. | Permission denied. Enable it in iOS Settings → Privacy → Apple Health → Deltiq. | İzin reddedildi. iOS Ayarlar → Gizlilik → Apple Health → Deltiq'ten etkinleştir. |
| `profile.health.footer` | Pre-fill von Geburtsdatum, Geschlecht und Größe aus dem Apple-Health-Profil. Manuelle Eingaben werden NICHT überschrieben, wenn sie schon plausible Werte haben. | Pre-fills date of birth, sex, and height from Apple Health. Manual entries are NOT overwritten if they already have plausible values. | Apple Health profilinden doğum tarihi, cinsiyet ve boyu önceden doldurur. Manuel girişler makul değer içeriyorsa ÜZERİNE YAZILMAZ. |
| `profile.health.pull` | Aus Apple Health übernehmen | Import from Apple Health | Apple Health'ten Al |
| `profile.health.pulled` | Aus Apple Health übernommen: %@ | Imported from Apple Health: %@ | Apple Health'ten alındı: %@ |
| `profile.person.footer` | Sex steuert die Navy/Deurenberg-Formeln; das Alter geht in Mifflin-St-Jeor-BMR und Deurenberg ein. | Sex drives the Navy/Deurenberg formulas; age feeds into Mifflin-St-Jeor BMR and Deurenberg. | Cinsiyet Navy/Deurenberg formüllerini etkiler; yaş Mifflin-St-Jeor BMR ve Deurenberg'e dahil olur. |
| `profile.section.body` | Körpermasse | Body Metrics | Vücut Ölçüleri |
| `profile.section.coach` | Coach | Coach | Koç |
| `profile.section.health` | Apple Health | Apple Health | Apple Health |
| `profile.section.person` | Person | Person | Kişi |

## `quiz.*`  (3 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `quiz.result.choose` | Diesen Plan wählen | Choose This Plan | Bu Planı Seç |
| `quiz.result.topMatch` | TOP EMPFEHLUNG FÜR DICH | TOP MATCH FOR YOU | SENİN İÇİN EN İYİ EŞLEŞME |
| `quiz.title` | Plan finden | Find a Plan | Plan Bul |

## `rest.*`  (1 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `rest.skip` | Pause überspringen | Skip rest | Molayı atla |

## `session.*`  (6 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `session.recovery.dayName.unknown` | Unbekannt | Unknown | Bilinmiyor |
| `session.recovery.discardAndRestart` | Verwerfen & neu starten | Discard & Restart | Sil ve Yeniden Başlat |
| `session.recovery.message.fallback` | Es gibt bereits ein angefangenes Training. | There's already an active session. | Zaten devam eden bir oturum var. |
| `session.recovery.message.withInfo` | Es gibt bereits ein angefangenes Training (%1$@, gestartet %2$@). Was möchtest du tun? | There's already an active session (%1$@, started %2$@). What would you like to do? | Zaten devam eden bir oturum var (%1$@, başlatıldı %2$@). Ne yapmak istersin? |
| `session.recovery.resume` | Fortsetzen | Continue | Devam et |
| `session.recovery.saveAndRestart` | Speichern & neu starten | Save & Restart | Kaydet ve Yeniden Başlat |

## `set.*`  (2 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `set.lockedHint` | Beende oder stoppe die laufende Übung zuerst. | Finish or stop the active exercise first. | Önce aktif hareketi bitir ya da durdur. |
| `set.numberLabel` | Satz %lld | Set %lld | Set %lld |

## `settings.*`  (51 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `settings.about.bundle` | Bundle | Bundle | Bundle |
| `settings.about.version` | Version | Version | Sürüm |
| `settings.action.reset` | App zurücksetzen | Reset App | Uygulamayı Sıfırla |
| `settings.appearance.dark` | Dunkel | Dark | Koyu |
| `settings.appearance.footer` | Greift in alle Views der App. 'System' folgt der iOS-Einstellung. | Applies to all views. 'System' follows iOS settings. | Tüm görünümlerde geçerli. 'Sistem' iOS ayarını izler. |
| `settings.appearance.light` | Hell | Light | Açık |
| `settings.appearance.section` | Erscheinungsbild | Appearance | Görünüm |
| `settings.appearance.system` | System | System | Sistem |
| `settings.confirm.reset.action` | Alles löschen | Delete everything | Her şeyi sil |
| `settings.confirm.reset.message` | Profil, alle Messungen, Pläne und Workout-Sessions gehen UNWIDERRUFLICH verloren. Die App startet danach im Onboarding. | Profile, all measurements, plans, and workouts will be IRRECOVERABLY lost. The app will start in onboarding. | Profil, tüm ölçümler, planlar ve antrenman oturumları GERİ ALINAMAZ şekilde silinecek. Uygulama ardından tekrar onboarding'den başlayacak. |
| `settings.confirm.reset.title` | App wirklich zurücksetzen? | Really reset the app? | Uygulamayı gerçekten sıfırlamak istiyor musun? |
| `settings.dangerZone.footer` | Löscht Profil, Messungen, Pläne, Trainings-Templates und Workout-Sessions vollständig. Die Apple-Health-Daten bleiben erhalten — die löscht du in der Health-App selber. | Deletes profile, measurements, plans, training templates, and workout sessions completely. Apple Health data is preserved — delete that from the Health app. | Profil, ölçümler, planlar, antrenman şablonları ve antrenman oturumlarını tamamen siler. Apple Health verileri korunur — onları Health uygulamasından silersin. |
| `settings.health.connect` | Verbinden | Connect | Bağla |
| `settings.health.denied` | Berechtigung verweigert | Permission denied | İzin reddedildi |
| `settings.health.footer` | Bei aktivierter Verbindung wird im Messwerte-Formular das letzte Waagen-Gewicht vorausgefüllt. Beim Speichern werden Gewicht, KFA und Magere Masse zurück nach Apple Health geschrieben. | When connected, the measurement form prefills your last scale weight. Saving writes weight, body fat %, and lean mass back to Apple Health. | Bağlıyken ölçüm formu son tartı kilonu önceden doldurur. Kaydetme; kilo, yağ oranı ve yağsız kütleyi Apple Health'e yazar. |
| `settings.health.lastSync` | Letzter Sync | Last Sync | Son Senkronizasyon |
| `settings.health.notSetup` | Nicht eingerichtet | Not set up | Kurulmadı |
| `settings.health.openIOSSettings` | In iOS-Einstellungen öffnen | Open iOS Settings | iOS Ayarlarını Aç |
| `settings.health.unavailable` | Nicht verfügbar | Not available | Kullanılamıyor |
| `settings.preferences.gear` | Ausrüstung & Schuhe | Gear & Shoes | Ekipman & Ayakkabı |
| `settings.preferences.units` | Einheiten | Units | Birimler |
| `settings.preferences.units.imperial` | Imperial (lbs / in) | Imperial (lbs / in) | İmperial (lbs / in) |
| `settings.preferences.units.metric` | Metrisch (kg / cm) | Metric (kg / cm) | Metrik (kg / cm) |
| `settings.profile.goal` | Ziel %@ | Goal %@ | Hedef %@ |
| `settings.profile.missing` | Kein Profil vorhanden — App neu starten oder zurücksetzen. | No profile — restart or reset the app. | Profil yok — uygulamayı yeniden başlat ya da sıfırla. |
| `settings.profile.years` | %lld Jahre | %lld years | %lld yaş |
| `settings.reminders.every1h` | Jede Stunde | Every hour | Her saat |
| `settings.reminders.every2h` | Alle 2 Stunden | Every 2 hours | Her 2 saat |
| `settings.reminders.every3h` | Alle 3 Stunden | Every 3 hours | Her 3 saat |
| `settings.reminders.every4h` | Alle 4 Stunden | Every 4 hours | Her 4 saat |
| `settings.reminders.footer` | Lokale Benachrichtigungen — keine Server-Verbindung. Tippen auf eine Erinnerung öffnet direkt den passenden Tab. | Local notifications — no server connection. Tapping a reminder opens the matching tab. | Yerel bildirimler — sunucu bağlantısı yok. Bir hatırlatıcıya dokunmak doğru sekmeyi açar. |
| `settings.reminders.frequency` | Häufigkeit | Frequency | Sıklık |
| `settings.reminders.hour` | %lld:00 Uhr | %lld:00 | %lld:00 |
| `settings.reminders.measurement` | Messung erinnern | Measurement reminder | Ölçüm hatırlat |
| `settings.reminders.section` | Erinnerungen | Reminders | Hatırlatıcılar |
| `settings.reminders.time` | Uhrzeit | Time | Saat |
| `settings.reminders.water` | Wasser erinnern | Water reminder | Su hatırlat |
| `settings.section.about` | Über | About | Hakkında |
| `settings.section.danger_zone` | Daten-Management | Data Management | Veri Yönetimi |
| `settings.section.preferences` | Präferenzen | Preferences | Tercihler |
| `settings.section.profile_goals` | Profil & Ziele | Profile & Goals | Profil & Hedefler |
| `settings.timer.footer` | Wird beim Ablauf des Pausen-Timers ausgelöst. Vibrations-Toggle hat auf iPads keine Wirkung. 'PR-Feiern' steuert Save-Screen-Popups, Live-Activity-Headline und lokale Benachrichtigungen — die Bestleistungen werden trotzdem im Trophy-Room gespeichert. | Fires when the rest timer ends. Vibration has no effect on iPads. 'Celebrate PRs' drives save-screen popups, Live Activity headlines, and local notifications — PRs are saved to the Trophy Room either way. | Mola zamanlayıcısı bittiğinde tetiklenir. Titreşim iPad'lerde etkisizdir. 'PR'ı Kutla' kaydetme ekranı pencerelerini, Live Activity başlıklarını ve yerel bildirimleri yönlendirir — PR'lar her durumda Kupa Odası'na kaydedilir. |
| `settings.timer.haptics` | Vibrieren | Vibrate | Titret |
| `settings.timer.prCelebrations` | PR-Feiern | Celebrate PRs | PR'ı Kutla |
| `settings.timer.section` | Pausen-Timer-Feedback | Rest Timer Feedback | Mola Zamanlayıcı Geri Bildirimi |
| `settings.timer.sound` | Ton abspielen | Play sound | Ses çal |
| `settings.title` | Einstellungen | Settings | Ayarlar |
| `settings.units.footer` | Die DB speichert immer metrisch. Diese Einstellung steuert nur die Anzeige in Eingabe-Feldern, im Hantel-Rechner und auf den Karten. | DB always stores metric. This setting only changes display in inputs, the plate calculator, and cards. | Veritabanı her zaman metrik kaydeder. Bu ayar sadece giriş alanlarında, plaka hesabında ve kartlarda görünümü değiştirir. |
| `settings.workout.footer` | Wenn aus, werden Warmup- und Cooldown-Übungen während der Session ausgeblendet. Die Templates und deine Plan-Editierung bleiben unverändert — der Toggle wirkt nur auf den Live-Workout-Flow. Warmups sind ohnehin nie Pflicht: der „Workout speichern"-Button bleibt immer klickbar, auch wenn du sie nicht abhakst. | When off, warmup and cooldown exercises are hidden during the session. Templates and plan editing remain unchanged — only the live workout flow is affected. Warmups are never mandatory: 'Save Workout' stays tappable even if you skip them. | Kapalıyken oturum sırasında ısınma ve soğuma hareketleri gizlenir. Şablonlar ve plan düzenleme değişmez — yalnızca canlı antrenman akışı etkilenir. Isınmalar zorunlu değildir: 'Antrenmanı Kaydet' onları atlasan bile aktif kalır. |
| `settings.workout.section` | Workout-Verhalten | Workout Behavior | Antrenman Davranışı |
| `settings.workout.showWarmups` | Warmup & Cooldown anzeigen | Show warmup & cooldown | Isınma & Soğuma Göster |

## `sex.*`  (2 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `sex.female` | Weiblich | Female | Kadın |
| `sex.male` | Männlich | Male | Erkek |

## `summary.*`  (16 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `summary.action.finish` | Speichern & zum Dashboard | Save & to dashboard | Kaydet ve Panele Dön |
| `summary.date` | Datum | Date | Tarih |
| `summary.detailTitle` | Workout-Detail | Workout Details | Antrenman Detayı |
| `summary.duration` | Dauer | Duration | Süre |
| `summary.durationMinutes` | %lld Min | %lld min | %lld dk |
| `summary.editTitle` | Workout bearbeiten | Edit Workout | Antrenmanı Düzenle |
| `summary.finishFooter` | Die Session ist bereits gespeichert. Der Button schließt die Zusammenfassung und bringt dich zurück aufs Dashboard. | Session is already saved. The button closes the summary and returns you to the dashboard. | Oturum zaten kaydedildi. Buton özeti kapatır ve seni panele döndürür. |
| `summary.hero.title` | Workout abgeschlossen | Workout completed | Antrenman Tamamlandı |
| `summary.note.footer` | Tauchen später in der History pro Session auf — gut für Form-Cues und Verletzungs-Tracking. | Show up later in history per session — useful for form cues and injury tracking. | Geçmişte oturum başına görünür — form ipuçları ve sakatlık takibi için faydalı. |
| `summary.note.label` | Notiz | Note | Not |
| `summary.note.placeholder` | Wie war's? Schmerzen, Pump, Performance ... | How was it? Pain, pump, performance ... | Nasıldı? Ağrı, pump, performans ... |
| `summary.prFooter` | Erkannt durch Vergleich mit allen vorherigen abgeschlossenen Sessions. Cardio bleibt aussen vor — andere Metrik-Domäne. | Detected by comparing all previous completed sessions. Cardio excluded — different metric domain. | Tüm önceki tamamlanan oturumlar ile karşılaştırarak tespit edildi. Kardiyo dahil değil — farklı metrik. |
| `summary.progressionFooter` | Ziel erreicht? Die App passt das Gewicht fürs nächste Workout automatisch an. Änderbar pro Übung im Editor. | Target hit? The app adjusts the weight for next workout automatically. Adjustable per exercise in the editor. | Hedefe ulaşıldı mı? Uygulama bir sonraki antrenman için ağırlığı otomatik ayarlar. Editörde hareket başına düzenlenebilir. |
| `summary.setsEmpty` | Keine Sätze geloggt. | No sets logged. | Set kaydedilmedi. |
| `summary.setsHeader` | Sätze | Sets | Setler |
| `summary.title` | Zusammenfassung | Summary | Özet |

## `tab.*`  (5 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `tab.calculators` | Rechner | Tools | Araçlar |
| `tab.dashboard` | Dashboard | Dashboard | Panel |
| `tab.measurement` | Messung | Measurement | Ölçüm |
| `tab.more` | Mehr | More | Daha Fazla |
| `tab.plan` | Plan | Plan | Plan |

## `trophy.*`  (18 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `trophy.action.detect` | Aus History detektieren | Detect from history | Geçmişten tespit et |
| `trophy.action.rebuild` | Aus History neu berechnen | Rebuild from history | Geçmişten yeniden hesapla |
| `trophy.empty.cta.detect` | Aus History detektieren | Detect from History | Geçmişten Tespit Et |
| `trophy.empty.description.firstWorkout` | Beende dein erstes Training, um deinen ersten PR aufzustellen. | Finish your first workout to set your first PR. | İlk PR'ını koymak için ilk antrenmanını bitir. |
| `trophy.empty.description.hasWorkouts` | Du hast bereits Workouts, aber noch keine Rekorde gespeichert. Klick unten, um sie aus deiner History zu detektieren. | You have workouts but no records saved yet. Tap below to detect them from your history. | Antrenmanların var ama henüz kayıtlı rekor yok. Geçmişinden tespit etmek için aşağıya dokun. |
| `trophy.empty.title` | Noch keine Rekorde | No records yet | Henüz rekor yok |
| `trophy.kind.bestSet` | Bestsatz | Best Set | En İyi Set |
| `trophy.kind.estimated1RM` | 1RM | 1RM | 1RM |
| `trophy.kind.heaviestWeight` | Max-Gewicht | Top Weight | Maks. Ağırlık |
| `trophy.kind.maxHoldSeconds` | Bestzeit | Best Hold | En İyi Süre |
| `trophy.kind.maxReps` | Max Wdh. | Max Reps | Maks. Tekrar |
| `trophy.rebuild.confirm.cta` | Neu berechnen | Recompute | Yeniden hesapla |
| `trophy.rebuild.confirm.message` | Setzt alle gespeicherten Rekorde zurück und detektiert sie aus deiner kompletten History neu. Nützlich nach gelöschten Sessions. | Resets all saved records and re-detects them from your complete history. Useful after deleted sessions. | Tüm kayıtlı rekorları sıfırlar ve geçmişinden yeniden tespit eder. Silinen oturumlardan sonra faydalı. |
| `trophy.rebuild.confirm.title` | Trophy Room neu berechnen? | Recompute Trophy Room? | Kupa Odası yeniden hesaplansın mı? |
| `trophy.rebuild.menu` | Aus History neu berechnen | Recompute from history | Geçmişten yeniden hesapla |
| `trophy.singleEntry` | Nur ein %@-Eintrag — Trend ab 2 Rekorden. | Only one %@ entry — trend starts at 2 records. | Sadece bir %@ kaydı — trend 2 rekordan başlar. |
| `trophy.title` | Trophy Room | Trophy Room | Rekor Odası |
| `trophy.totalRecords` | %lld Rekorde gesamt | %lld records total | Toplam %lld rekor |

## `water.*`  (8 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `water.empty` | Trag deinen ersten Schluck mit den Buttons oben ein. | Log your first sip with the buttons above. | İlk yudumu yukarıdaki butonlarla kaydet. |
| `water.goalReached` | Tagesziel erreicht | Daily goal reached | Günlük hedef ulaşıldı |
| `water.heroFooter` | Tagesziel = Gewicht × 35 ml. Quelle: %@. | Daily goal = weight × 35 ml. Source: %@. | Günlük hedef = kilo × 35 ml. Kaynak: %@. |
| `water.ofTotal` | ml von %lld | ml of %lld | ml / %lld |
| `water.quickAdd.section` | Schnell-Eintrag | Quick Add | Hızlı Ekle |
| `water.remainingToGoal` | %lld ml bis zum Ziel | %lld ml to goal | Hedefe %lld ml |
| `water.resetToday` | Heute zurücksetzen | Reset Today | Bugünü Sıfırla |
| `water.title` | Wasser | Water | Su |

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

## `workout.*`  (4 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `workout.allSetsDone` | Alle Sätze erledigt | All sets done | Tüm setler tamam |
| `workout.detail.cardio` | Cardio • %llds Pause | Cardio • %llds rest | Kardiyo • %llds mola |
| `workout.detail.reps` | %1$lld Sätze • %2$@ Wdh • %3$llds Pause | %1$lld sets • %2$@ reps • %3$llds rest | %1$lld set • %2$@ tekrar • %3$llds mola |
| `workout.detail.seconds` | %1$lld Sätze • %2$@ Sek • %3$llds Pause | %1$lld sets • %2$@ sec • %3$llds rest | %1$lld set • %2$@ sn • %3$llds mola |


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

Stand: 0 hartkodierte deutsche Strings über 0 Dateien gefunden (per Heuristik — false positives möglich, beim Refactor wird jede Stelle nochmal geprüft).

Diese Strings müssen in einem späteren i18n-Sweep (DEL-073 Phase 2-4) nach `Localizable.xcstrings` migriert werden:

1. Active Workout (ActiveWorkoutView, ExerciseCard, SetRow, WorkoutSummaryView)
2. Plan-Editor (PlanEditorView, DayEditorView, ProgramTemplatePickerView)
3. Library (ExerciseLibraryData, Domain-Enum-Labels)

