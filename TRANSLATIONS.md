# Deltiq — Translation Source-of-Truth

**Gesamt: 1573 Keys im String Catalog + 0 noch hartkodierte Strings im Code.**

## Coverage-Status (Catalog)

| Sprache | Übersetzt | Fehlt |
|---|---|---|
| 🇩🇪 Deutsch (DE) | **1573 / 1573** (100%) | 0 |
| 🇬🇧 English (EN) | **1573 / 1573** (100%) | 0 |
| 🇹🇷 Türkçe (TR) | **1573 / 1573** (100%) | 0 |

Wenn du EN/TR aktualisierst:
- Per Xcode: öffne `Sources/FitnessAppUI/Resources/Localizable.xcstrings`, Apple's String-Catalog-Editor markiert „needs translation" automatisch.
- Per CSV-Export aus dieser Tabelle → ChatGPT / DeepL → zurück in die xcstrings importieren.
- Per direktem JSON-Edit (vorsichtig, JSON-Syntax muss valide bleiben).

Quelle: `Sources/FitnessAppUI/Resources/Localizable.xcstrings`

Tabellenformat: leere EN/TR-Spalten brauchen Übersetzung. Plural-Keys sind separat aufgelistet — die haben one/other-Varianten.


## `active.*`  (42 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `active.action.discard` | Verwerfen | Discard | Sil |
| `active.action.save` | Training speichern | Save workout | Antrenmanı Kaydet |
| `active.addExercise` | Übung | Exercise | Hareket |
| `active.addExerciseCTA` | Übung hinzufügen | Add Exercise | Hareket Ekle |
| `active.confirm.discard.title` | Training verwerfen? | Discard workout? | Antrenmanı silmek istiyor musun? |
| `active.discard.cta` | Training abbrechen | Discard Workout | Antrenmanı Sil |
| `active.discard.message` | Die Session und alle %lld bisher geloggten Sätze gehen verloren. | The session and all %lld logged sets will be lost. | Oturum ve şimdiye kadar kaydedilen %lld set kaybolacak. |
| `active.empty.adhoc.message` | Such dir aus der Library eine Übung — alles weitere passiert wie im Plan-Training. | Pick an exercise from the library — everything else works like a plan workout. | Kütüphaneden bir hareket seç — gerisi plan antrenmanı gibi çalışır. |
| `active.empty.adhoc.title` | Dein Training ist noch leer | Your workout is empty | Antrenmanın henüz boş |
| `active.empty.session.message` | Vermutlich wurde der Plan-Tag nach dem Start geleert. Du kannst die Session verwerfen oder ohne Sätze beenden. | The plan day was likely emptied after starting. Discard the session or finish without sets. | Plan günü başlatıldıktan sonra muhtemelen boşaltıldı. Oturumu silebilir veya setsiz bitirebilirsin. |
| `active.empty.session.title` | Diese Session hat keine Übungen. | This session has no exercises. | Bu oturumda hareket yok. |
| `active.exercise.edit` | Übung bearbeiten | Edit exercise | Hareketi düzenle |
| `active.exercise.menuAccessibility` | Übungs-Optionen | Exercise options | Hareket seçenekleri |
| `active.exercise.remove` | Übung entfernen | Remove exercise | Hareketi kaldır |
| `active.exercise.removeConfirmCta` | Entfernen | Remove | Kaldır |
| `active.exercise.removeConfirmMessage` | Die bereits geloggten Sätze dieser Übung werden mit entfernt. | The sets already logged for this exercise will be removed too. | Bu hareket için kaydedilmiş setler de kaldırılacak. |
| `active.exercise.removeConfirmTitle` | Übung entfernen? | Remove exercise? | Hareket kaldırılsın mı? |
| `active.finish.feeling.message` | Die App nutzt das für die Progression: Wenn du am Limit warst, halten wir das Gewicht stabil — kein Zwangs-Plus. | We use this for progression: when you were at the limit, we keep the weight stable — no forced increase. | Bunu ilerleme için kullanırız: limitteydiysen ağırlığı sabit tutarız — zorla artırma yok. |
| `active.finish.feeling.noProgression` | Kein Gewichts-Plus im nächsten Training | No weight increase next workout | Sonraki antrenmanda ağırlık artışı yok |
| `active.finish.feeling.title` | Wie hat sich das Training angefühlt? | How did the workout feel? | Antrenman nasıl hissettirdi? |
| `active.finish.gear` | Verwendete Ausrüstung | Gear Used | Kullanılan Ekipman |
| `active.finish.save` | Training speichern | Save Workout | Antrenmanı Kaydet |
| `active.finish.summary` | Dein Training | Your Workout | Antrenmanın |
| `active.finish.title` | Training beenden | Finish Workout | Antrenmanı Bitir |
| `active.interference.dismiss` | Banner schließen | Dismiss banner | Banner'ı kapat |
| `active.interference.message` | Erwäge heute, dein Ziel-RIR bei Beinübungen um +1 zu erhöhen, um dein ZNS nicht zu überlasten. | Consider raising your target RIR on leg exercises by +1 today to avoid overloading your CNS. | MSS'ni aşırı yüklemekten kaçınmak için bugün bacak hareketlerinde hedef RIR'ı +1 artırmayı düşün. |
| `active.interference.title` | Du hattest gestern eine harte Einheit | You had a hard session yesterday | Dün zorlu bir antrenmanın vardı |
| `active.placeholder.subtext` | Set-Logging mit Vorgaben & Rest-Timer • Live Activities folgen im Xcode-Target. | Set logging with targets & rest timer • Live Activities arrive in the Xcode target. | Hedefli set kaydı ve dinlenme zamanlayıcısı • Live Activities Xcode hedefinde gelir. |
| `active.set.add` | Satz hinzufügen | Add set | Set ekle |
| `active.set.previousCardio` | %1$@ in %2$@ | %1$@ in %2$@ | %2$@ içinde %1$@ |
| `active.set.previousFormat` | letztes: %@ | last: %@ | son: %@ |
| `active.set.previousRIR` | RIR %@ | RIR %@ | RIR %@ |
| `active.set.remove` | Satz entfernen | Remove set | Seti kaldır |
| `active.stats.avgPace` | ⌀ Pace | ⌀ Pace | ⌀ Tempo |
| `active.stats.distance` | Distanz | Distance | Mesafe |
| `active.stats.distanceKm` | Distanz km | Distance km | Mesafe km |
| `active.stats.duration` | Dauer | Duration | Süre |
| `active.stats.sets` | Sätze | Sets | Set |
| `active.stats.volumeKg` | Volumen kg | Volume kg | Hacim kg |
| `active.summary.duration` | Dauer | Duration | Süre |
| `active.summary.sets` | Sätze | Sets | Set |
| `active.summary.volume` | Volumen | Volume | Hacim |

## `activity.*`  (10 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `activity.active.description` | 6-7 Trainings pro Woche oder körperlicher Beruf. | 6-7 workouts per week or physical job. | Haftada 6-7 antrenman ya da fiziksel iş. |
| `activity.active.label` | Aktiv (1.725) | Active (1.725) | Aktif (1.725) |
| `activity.light.description` | 1-2 leichte Trainings pro Woche. | 1-2 light workouts per week. | Haftada 1-2 hafif antrenman. |
| `activity.light.label` | Leicht aktiv (1.375) | Lightly Active (1.375) | Az Hareketli (1.375) |
| `activity.moderate.description` | 3-5 Trainings pro Woche (Default für Hobby-Lifter). | 3-5 workouts per week (default for hobby lifters). | Haftada 3-5 antrenman (hobi sporcular için varsayılan). |
| `activity.moderate.label` | Moderat (1.55) | Moderate (1.55) | Orta (1.55) |
| `activity.sedentary.description` | Bürojob, kaum Bewegung neben dem Alltag. | Office job, little movement outside daily routine. | Ofis işi, günlük rutin dışında az hareket. |
| `activity.sedentary.label` | Bürojob (1.2) | Sedentary (1.2) | Hareketsiz (1.2) |
| `activity.veryActive.description` | Tag-täglich intensives Training oder schwere körperliche Arbeit. | Daily intense training or heavy physical labor. | Her gün yoğun antrenman ya da ağır fiziksel iş. |
| `activity.veryActive.label` | Sehr aktiv (1.9) | Very Active (1.9) | Çok Aktif (1.9) |

## `backups.*`  (17 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `backups.createNow` | Jetzt sichern | Back up now | Şimdi yedekle |
| `backups.delete.action` | Löschen | Delete | Sil |
| `backups.empty.description` | Sobald du ein Training aufgezeichnet hast, legt Deltiq beim nächsten Verlassen der App die erste Sicherung an. | Once you've recorded a workout, Deltiq creates the first backup the next time you leave the app. | Bir antrenman kaydettiğinde, Deltiq uygulamadan bir sonraki çıkışında ilk yedeği oluşturur. |
| `backups.empty.title` | Noch keine Backups | No backups yet | Henüz yedek yok |
| `backups.footer` | Du findest die Backups auch in der Dateien-App unter „Auf meinem iPhone → Deltiq → Backups“. Von dort kannst du eine Sicherung nach iCloud Drive ziehen oder auf den Rechner kopieren. Der Ordner ist außerdem im iCloud-Gerätebackup enthalten. | You can also find the backups in the Files app under "On My iPhone → Deltiq → Backups". From there you can move one to iCloud Drive or copy it to a computer. The folder is also included in your iCloud device backup. | Yedekleri Dosyalar uygulamasında „iPhone'umda → Deltiq → Backups" altında da bulabilirsin. Oradan bir yedeği iCloud Drive'a taşıyabilir veya bilgisayara kopyalayabilirsin. Klasör ayrıca iCloud cihaz yedeğine dahildir. |
| `backups.intro` | Deltiq sichert deine Daten automatisch, wenn du die App verlässt — höchstens einmal pro Tag. Die letzten fünf Sicherungen bleiben erhalten und liegen in der Dateien-App. | Deltiq backs up your data automatically when you leave the app — at most once a day. The five most recent backups are kept and stored in the Files app. | Deltiq, uygulamadan çıktığında verilerini otomatik olarak yedekler — günde en fazla bir kez. En son beş yedek saklanır ve Dosyalar uygulamasında bulunur. |
| `backups.reason.automatic` | Automatisch | Automatic | Otomatik |
| `backups.reason.manual` | Manuell | Manual | Manuel |
| `backups.reason.preImport` | Vor einem Import | Before an import | İçe aktarmadan önce |
| `backups.restore.action` | Wiederherstellen | Restore | Geri yükle |
| `backups.restore.confirm.message` | Deine aktuellen Daten werden durch den Stand von %@ ersetzt. Vorher legt Deltiq automatisch eine Sicherung des JETZIGEN Stands an, damit du zurück kannst. | Your current data will be replaced with the backup from %@. Deltiq first saves a backup of your CURRENT data so you can go back. | Mevcut verilerin %@ tarihli yedekle değiştirilecek. Deltiq önce ŞU ANKİ verilerinin bir yedeğini alır, böylece geri dönebilirsin. |
| `backups.restore.confirm.title` | Diesen Stand wiederherstellen? | Restore this backup? | Bu yedek geri yüklensin mi? |
| `backups.restore.done` | %1$lld Datensätze wiederhergestellt, %2$lld übersprungen. | Restored %1$lld records, skipped %2$lld. | %1$lld kayıt geri yüklendi, %2$lld atlandı. |
| `backups.restore.running` | Wird wiederhergestellt … | Restoring … | Geri yükleniyor … |
| `backups.title` | Backups | Backups | Yedekler |
| `backups.unhealthy.description` | Die App konnte ihren gewohnten Datenspeicher nicht öffnen und läuft auf einem Ersatz. Der angezeigte Stand kann veraltet sein. Es werden vorsichtshalber keine neuen Backups angelegt, damit bestehende Sicherungen nicht überschrieben werden. Bitte melde das — starte die App vorher nicht neu und lösche sie nicht. | The app couldn't open its usual data store and is running on a fallback. What you see may be out of date. No new backups are being created, so existing ones stay intact. Please report this — don't reinstall or delete the app first. | Uygulama olağan veri deposunu açamadı ve yedek bir depo üzerinde çalışıyor. Gördüğün veriler güncel olmayabilir. Mevcut yedeklerin bozulmaması için yeni yedek alınmıyor. Lütfen bunu bildir — önce uygulamayı yeniden yükleme veya silme. |
| `backups.unhealthy.title` | Backups angehalten | Backups paused | Yedekler duraklatıldı |

## `barbell.*`  (2 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `barbell.loading.empty` | Keine Aufladung — bleib bei der leeren Stange. | No plates needed — keep the empty bar. | Plaka yok — boş barı bırak. |
| `barbell.loading.title` | Hantel-Aufladung | Barbell Loading | Halter Yükleme |

## `calc.*`  (59 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `calc.index.footer` | Alle Rechner nutzen die gleiche Domain-Logik (FitnessAppCore) wie der Rest der App — Werte sind 1:1 mit Dashboard und MeasurementView. | All calculators use the same domain logic (FitnessAppCore) as the rest of the app — values match dashboard and measurement view 1:1. | Tüm hesaplayıcılar uygulamanın geri kalanıyla aynı domain mantığını (FitnessAppCore) kullanır — değerler panel ve ölçüm görünümü ile birebir eşleşir. |
| `calc.index.oneRm.subtitle` | Epley + Brzycki + Mittelwert, plus Trainings-%-Tabelle. | Epley + Brzycki + average, plus a training-% table. | Epley + Brzycki + ortalama, artı antrenman % tablosu. |
| `calc.index.oneRm.title` | 1RM-Rechner | 1RM Calculator | 1RM Hesaplayıcı |
| `calc.index.plate.subtitle` | Welche Plates für dein Zielgewicht — mit Inventar-Cap und visualer Stange. | Which plates for your target weight — with inventory cap and visual bar. | Hedef ağırlığın için hangi plakalar — envanter sınırı ve görsel barla. |
| `calc.index.plate.title` | Hantel-Rechner | Plate Calculator | Plaka Hesaplayıcı |
| `calc.index.tdee.subtitle` | BMR + TDEE aus deinem Profil und Aktivitäts-Level. | BMR + TDEE from your profile and activity level. | Profil ve aktivite seviyenden BMR + TDEE. |
| `calc.index.tdee.title` | Kalorien-Rechner | Calorie Calculator | Kalori Hesaplayıcı |
| `calc.index.title` | Rechner | Calculators | Hesaplayıcılar |
| `calc.index.water.subtitle` | Tagesziel = Gewicht × 35 ml. Mit Quick-Add. | Daily goal = weight × 35 ml. With quick-add. | Günlük hedef = kilo × 35 ml. Hızlı ekleme ile. |
| `calc.index.water.title` | Wasser-Tracker | Water Tracker | Su Takipçisi |
| `calc.oneRm.input.footer` | Gültig für 1-36 Reps. Bei sehr hohen Reps wird die Schätzung unzuverlässig — die Formeln liefern nur für den Hypertrophie- bis Kraft-Bereich (~1-12 Reps) brauchbare Werte. | Valid for 1-36 reps. Estimates get unreliable at very high reps — formulas work best in the hypertrophy-to-strength range (~1-12 reps). | 1-36 tekrar için geçerli. Çok yüksek tekrarlarda tahmin güvenilmez olur — formüller hipertrofi-güç aralığında (~1-12 tekrar) en iyi sonucu verir. |
| `calc.oneRm.percentages.footer` | Rep-Hints sind Faustwerte. Effektive Reps hängen vom Trainings-Status und der Bewegung ab. | Rep hints are rules of thumb. Actual reps depend on training status and the lift. | Tekrar ipuçları yaklaşık değerlerdir. Gerçek tekrar; antrenman durumuna ve harekete bağlıdır. |
| `calc.oneRm.reps` | Wiederholungen | Reps | Tekrar |
| `calc.oneRm.repsHint` | ~ %lld Reps | ~ %lld reps | ~ %lld tekrar |
| `calc.oneRm.row.average` | Mittelwert | Average | Ortalama |
| `calc.oneRm.section.estimate` | Geschätztes 1RM | Estimated 1RM | Tahmini 1RM |
| `calc.oneRm.section.input` | Eingabe | Input | Giriş |
| `calc.oneRm.section.percentages` | Trainings-Last (vom Mittelwert-1RM) | Training Load (from average 1RM) | Antrenman Yükü (ortalama 1RM'den) |
| `calc.oneRm.tableEmpty` | Tabelle erscheint, sobald 1RM berechnet ist. | Table shows up once the 1RM is calculated. | 1RM hesaplandığında tablo görünür. |
| `calc.oneRm.weightLabel` | Gewicht (%@) | Weight (%@) | Ağırlık (%@) |
| `calc.oneRm.weightPlaceholder` | z.B. 100 | e.g. 100 | örn. 100 |
| `calc.oneRm.weightRequired` | Trag Gewicht > 0 ein. | Enter weight > 0. | Ağırlık > 0 gir. |
| `calc.placeholderExample` | z.B. %@ | e.g. %@ | örn. %@ |
| `calc.plate.bar` | Stange (%@) | Bar (%@) | Bar (%@) |
| `calc.plate.emptyHint.noBar` | Trag das Stangen-Gewicht ein. | Enter the bar weight. | Bar ağırlığını gir. |
| `calc.plate.emptyHint.noInventory` | Mit dem aktuellen Inventar bleibt nichts über der Stange. | With your current inventory, nothing fits above the bar. | Mevcut envanterle barın üzerine yüklenecek bir şey yok. |
| `calc.plate.emptyHint.noTarget` | Trag dein Zielgewicht ein. | Enter your target weight. | Hedef ağırlığını gir. |
| `calc.plate.emptyHint.targetTooLow` | Zielgewicht muss schwerer sein als die Stange. | Target must be heavier than the bar. | Hedef bardan ağır olmalı. |
| `calc.plate.inventoryFooter.kg` | Cap pro Plate: 25/20 kg → 10, alle anderen → 1. Auf 0 setzen, wenn die Plate bei dir fehlt. | Cap per plate: 25/20 kg → 10, all others → 1. Set to 0 if you don't own that plate. | Plaka başına sınır: 25/20 kg → 10, diğerleri → 1. Plaka yoksa 0 olarak ayarla. |
| `calc.plate.inventoryFooter.lbs` | Cap pro Plate: 45/35 lbs → 10, alle anderen → 1. Auf 0 setzen, wenn die Plate bei dir fehlt. | Cap per plate: 45/35 lbs → 10, all others → 1. Set to 0 if you don't own that plate. | Plaka başına sınır: 45/35 lbs → 10, diğerleri → 1. Plaka yoksa 0 olarak ayarla. |
| `calc.plate.inventoryRow.count` | %lld Stk | %lld pcs | %lld adet |
| `calc.plate.loaded` | Geladen gesamt | Total Loaded | Yüklenen Toplam |
| `calc.plate.perSide` | Pro Seite | Per Side | Tarafa |
| `calc.plate.resetInventory` | Inventar zurücksetzen | Reset Inventory | Envanteri Sıfırla |
| `calc.plate.section.input` | Zielgewicht & Stange | Target & Bar | Hedef & Bar |
| `calc.plate.section.inventory` | Inventar pro Seite | Inventory Per Side | Tarafa Envanter |
| `calc.plate.section.results` | Ergebnis | Result | Sonuç |
| `calc.plate.shortOfTarget` | Mit deinem Inventar nur %1$@ %2$@ erreichbar (%3$@). | Only %1$@ %2$@ reachable with your inventory (%3$@). | Envanterinle sadece %1$@ %2$@ ulaşılabilir (%3$@). |
| `calc.plate.target` | Zielgewicht (%@) | Target Weight (%@) | Hedef Ağırlık (%@) |
| `calc.plate.unit.footer` | App-weit umschaltbar. DB speichert immer metrisch — nur die Anzeige ändert sich. | Switchable app-wide. DB always stores metric — only the display changes. | Uygulama genelinde değiştirilebilir. Veritabanı her zaman metrik kaydeder — sadece görünüm değişir. |
| `calc.plate.unit.label` | Einheit | Unit | Birim |
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

## `cardioEquipment.*`  (6 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `cardioEquipment.bikeOutdoor` | Fahrrad (draußen) | Bike (outdoor) | Bisiklet (dışarıda) |
| `cardioEquipment.ergometer` | Ergometer (Heimtrainer) | Ergometer | Kondisyon bisikleti |
| `cardioEquipment.fieldLabel` | Equipment | Equipment | Ekipman |
| `cardioEquipment.none` | Kein Gerät | No equipment | Cihaz yok |
| `cardioEquipment.rowingMachine` | Rudergerät | Rowing machine | Kürek makinesi |
| `cardioEquipment.treadmill` | Laufband | Treadmill | Koşu Bandı |

## `chart.*`  (3 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `chart.timeRange.max` | Max | Max | Tümü |
| `chart.timeRange.oneMonth` | 1M | 1M | 1A |
| `chart.timeRange.threeMonths` | 3M | 3M | 3A |

## `coaching.*`  (216 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `coaching.cnsOverloaded.analytical.hybrid` | Akkumulierte ZNS-Last über Schwelle. Heute kein high-intensity Cardio + keine schweren Compounds. Skill-Work und Mobility sind okay. | Accumulated CNS load over threshold. Skip high-intensity cardio and heavy compounds today. Skill work and mobility are fine. | Birikmiş MSS yükü eşiğin üzerinde. Bugün yüksek yoğunluklu kardiyo ve ağır temel hareketlere ara ver. Teknik çalışması ve mobilite uygundur. |
| `coaching.cnsOverloaded.analytical.hypertrophy` | CNS-Score erhöht. Hypertrophie-Reize sind noch produktiv, aber Pause Compound-Lifts und fokussiere Maschinen-Isolation. | CNS load elevated. Hypertrophy stimuli are still productive, but pause compound lifts and focus on machine isolation. | MSS yükü artmış. Hipertrofi uyarıları hâlâ verimli, ancak temel hareketlere ara ver ve makineli izolasyona odaklan. |
| `coaching.cnsOverloaded.analytical.strength` | ZNS-Belastung >90%. Schwere 1RM-Versuche sind heute statistisch ineffizient. Reduziere die Intensität. | CNS load >90%. Heavy 1RM attempts are statistically inefficient today. Reduce intensity. | MSS yükü %90 üzerinde. Bugün ağır 1RM denemeleri istatistiksel olarak verimsiz. Yoğunluğu azalt. |
| `coaching.cnsOverloaded.analytical.weightLoss` | Deine Belastungswerte sind im roten Bereich. Im Kaloriendefizit ist die Erholungskapazität ohnehin reduziert — heute nur leichte Bewegung. | Your load scores are in the red. In a calorie deficit, recovery capacity is reduced anyway — light movement only today. | Yük değerlerin kırmızı bölgede. Kalori açığında toparlanma kapasitesi zaten düşük — bugün sadece hafif hareket. |
| `coaching.cnsOverloaded.motivating.hypertrophy` | Du hast extrem hart gearbeitet! Gönn deinem Nervensystem etwas Ruhe und fokussiere dich heute auf leichte Isolationsübungen. | You've worked incredibly hard! Give your nervous system some rest and focus on light isolation exercises today. | Çok sıkı çalıştın! Bugün sinir sistemine biraz dinlenme ver ve hafif izolasyon hareketlerine odaklan. |
| `coaching.cnsOverloaded.motivating.weightLoss` | Dein Körper arbeitet gerade doppelt: Defizit UND Erholung. Gönn ihm heute Leichtes — du bist trotzdem auf Kurs! 🌿 | Your body is working double right now: deficit AND recovery. Keep it light today — you're still on track! 🌿 | Vücudun şu an çift mesai yapıyor: açık VE toparlanma. Bugün hafif tut — yine de yoldasın! 🌿 |
| `coaching.cnsOverloaded.strict.hybrid` | Rote Zone. Dein Nervensystem ist durch. Keine schweren Kettlebell-Swings heute. Mach Mobility oder mach Pause. | Red zone. Your nervous system is fried. No heavy kettlebell swings today. Mobility work — or rest. | Kırmızı bölge. Sinir sistemin bitik. Bugün ağır kettlebell swing yok. Mobilite ya da dinlen. |
| `coaching.cnsOverloaded.strict.weightLoss` | ZNS überlastet + Kaloriendefizit = Verletzungsrisiko. Heute hart zu trainieren kostet mehr, als es bringt. Lass es. | Overloaded CNS + calorie deficit = injury risk. Training hard today costs more than it returns. Don't. | Aşırı yüklü MSS + kalori açığı = sakatlık riski. Bugün sert antrenman getirdiğinden fazlasını götürür. Yapma. |
| `coaching.edu.analytical.1` | Hypertrophie braucht 10–20 Sätze pro Muskelgruppe pro Woche — mehr Sätze ≠ mehr Wachstum jenseits dieser Schwelle. | Hypertrophy needs 10–20 sets per muscle group per week. More sets ≠ more growth beyond that threshold. | Hipertrofi haftada kas grubu başına 10–20 set gerektirir. Eşik aşıldıktan sonra daha fazla set ≠ daha fazla büyüme. |
| `coaching.edu.analytical.10` | Eccentric-Phase (Ablassen) baut mehr Muskel auf als Concentric. Ziel: 2–3 Sekunden kontrolliert ablassen. | Eccentrics (lowering) build more muscle than concentrics. Aim for 2–3 controlled seconds down. | Eksentrik (indirme) konsentrikten daha fazla kas inşa eder. Hedef: 2–3 saniye kontrollü iniş. |
| `coaching.edu.analytical.11` | Compound-Lifts liefern hohen ROI: Squat, Bench, Deadlift, OHP, Row decken ~80 % der Hauptmuskeln ab. | Compound lifts deliver high ROI: squat, bench, deadlift, OHP, row cover ~80% of the main muscles. | Bileşik hareketler yüksek ROI: squat, bench, deadlift, OHP, row ana kasların ~%80'ini kapsar. |
| `coaching.edu.analytical.12` | Trainingsintensität > 65 % 1RM ist nötig für Kraftadaption. Darunter trainierst du primär Ausdauer. | Training intensity > 65% 1RM is needed for strength adaptation. Below that, you mostly train endurance. | Kuvvet adaptasyonu için yoğunluk > %65 1RM gerekir. Altında çoğunlukla dayanıklılık çalışırsın. |
| `coaching.edu.analytical.13` | Pause zwischen Sätzen: 2–3 min für Compound-Lifts, 60–90 s für Isolation. Kürzere Pausen ≠ besseres Ergebnis. | Rest between sets: 2–3 min for compounds, 60–90 s for isolation. Shorter rest ≠ better results. | Setler arası dinlenme: bileşik için 2–3 dk, izolasyon için 60–90 sn. Kısa dinlenme ≠ daha iyi sonuç. |
| `coaching.edu.analytical.14` | Aktive Erholung (leichtes Cardio, Mobility) beschleunigt DOMS-Abbau messbar gegenüber kompletter Ruhe. | Active recovery (light cardio, mobility) measurably accelerates DOMS clearance versus complete rest. | Aktif toparlanma (hafif kardiyo, mobilite) DOMS'u tam dinlenmeye göre ölçülebilir şekilde hızlandırır. |
| `coaching.edu.analytical.15` | Trainingsalter zählt: Anfänger gewinnen 1–2 kg Muskel/Monat, Fortgeschrittene 0,2–0,5 kg/Monat. Realistisch bleiben. | Training age matters: beginners gain 1–2 kg muscle/month, advanced 0.2–0.5 kg/month. Stay realistic. | Antrenman yaşı önemli: yeni başlayanlar 1–2 kg kas/ay, ileri seviye 0,2–0,5 kg/ay kazanır. Gerçekçi ol. |
| `coaching.edu.analytical.16` | Der Interferenz-Effekt zwischen Cardio und Kraft ist bei 6+ Stunden Abstand zwischen den Einheiten weitgehend vernachlässigbar. | The interference effect between cardio and strength is largely negligible with 6+ hours between sessions. | Kardiyo ile kuvvet arasındaki interferans etkisi, seanslar arasında 6+ saat varsa büyük ölçüde ihmal edilebilir. |
| `coaching.edu.analytical.17` | Die Muskelproteinsynthese bleibt ~48 Stunden nach einer Einheit erhöht — jede Muskelgruppe 2× pro Woche zu treffen nutzt das aus. | Muscle protein synthesis stays elevated ~48 hours after a session — hitting each muscle twice a week exploits that. | Kas protein sentezi seanstan sonra ~48 saat yüksek kalır — her kas grubunu haftada 2 kez çalıştırmak bundan yararlanır. |
| `coaching.edu.analytical.18` | Koffein wirkt ~45-60 Minuten nach Einnahme am stärksten. Time es auf den Top-Satz, nicht aufs Aufwärmen. | Caffeine peaks ~45-60 minutes after intake. Time it for your top set, not your warm-up. | Kafein alımdan ~45-60 dakika sonra zirve yapar. Zamanlamayı ısınmaya değil, en ağır setine göre yap. |
| `coaching.edu.analytical.19` | Wiederholungen im Tank (RIR) zu tracken ist genauer als RPE — der Schätzfehler sinkt mit Trainingserfahrung. | Tracking reps in reserve (RIR) beats RPE for accuracy — estimation error shrinks with training experience. | Rezervdeki tekrarları (RIR) takip etmek RPE'den daha isabetlidir — tahmin hatası deneyimle azalır. |
| `coaching.edu.analytical.2` | Protein-Sweet-Spot: 1,6–2,2 g pro kg Körpergewicht pro Tag. Mehr bringt im Studienschnitt keinen zusätzlichen Effekt. | Protein sweet spot: 1.6–2.2 g per kg of bodyweight per day. More yields no extra effect on average. | Protein optimum aralığı: günde 1,6–2,2 g/kg vücut ağırlığı. Fazlası ortalamada ekstra etki yapmaz. |
| `coaching.edu.analytical.20` | Exzentrische Phasen von 2-4 Sekunden erhöhen die mechanische Spannung — den primären Hypertrophie-Treiber. | Eccentric phases of 2-4 seconds increase mechanical tension — the primary driver of hypertrophy. | 2-4 saniyelik eksantrik fazlar mekanik gerilimi artırır — hipertrofinin birincil itici gücü. |
| `coaching.edu.analytical.21` | Krafttraining senkt das Verletzungsrisiko im Sport um bis zu zwei Drittel — der am besten belegte Präventionseffekt der Literatur. | Strength training cuts sports injury risk by up to two thirds — the best-documented prevention effect in the literature. | Kuvvet antrenmanı spor yaralanma riskini üçte ikiye kadar azaltır — literatürde en iyi belgelenmiş önleme etkisi. |
| `coaching.edu.analytical.3` | Schlaf ist Trainingsfaktor #1. Unter 6 h sinken Kraft und Hypertrophie messbar — vor Volumen-Erhöhung optimieren. | Sleep is training factor #1. Under 6 hours, strength and hypertrophy measurably decline — fix it before raising volume. | Uyku, antrenman faktörü #1. 6 saatin altında kuvvet ve hipertrofi ölçülebilir şekilde düşer — hacmi artırmadan önce uykuyu düzelt. |
| `coaching.edu.analytical.4` | Vollständige ROM (Bewegungsumfang) baut mehr Muskelmasse auf als Teil-Wiederholungen — auch bei gleichem Volumen. | Full range of motion builds more muscle than partials — even at matched volume. | Tam hareket açıklığı (ROM), eşit hacimde bile kısmi tekrarlardan daha fazla kas inşa eder. |
| `coaching.edu.analytical.5` | Progressive Overload heißt: pro Woche eine Variable steigern — Gewicht, Reps, Sätze ODER ROM. Nicht alles gleichzeitig. | Progressive overload means raising one variable per week: weight, reps, sets, OR ROM — not all at once. | Progresif aşırı yükleme: haftada bir değişkeni artır — ağırlık, tekrar, set ya da ROM. Hepsini birden değil. |
| `coaching.edu.analytical.6` | Cardio direkt nach Krafttraining beeinträchtigt Hypertrophie weniger als davor — wenn beides am selben Tag muss. | Cardio after lifting impairs hypertrophy less than cardio before — when both fall on the same day. | Kuvvet sonrası kardiyo, kuvvet öncesi kardiyodan hipertrofiyi daha az bozar — ikisi aynı günse. |
| `coaching.edu.analytical.7` | Kreatin-Monohydrat: 3–5 g/Tag, kein Loading nötig. Stärkster Einzelnachweis aller Supplements. | Creatine monohydrate: 3–5 g/day, no loading needed. The strongest single-study evidence in all supplements. | Kreatin monohidrat: günde 3–5 g, yüklemeye gerek yok. Tüm takviyeler içinde en güçlü tek-çalışma kanıtı. |
| `coaching.edu.analytical.8` | RIR-Skala: 0 = Versagen, 3+ = noch viele Reps drin. Hypertrophie passiert vor allem an den letzten 5 Reps vor dem Versagen. | RIR scale: 0 = failure, 3+ = many reps left. Hypertrophy happens mostly in the last 5 reps before failure. | RIR ölçeği: 0 = yetmezlik, 3+ = hâlâ tekrar var. Hipertrofi çoğunlukla yetmezlikten önceki son 5 tekrarda olur. |
| `coaching.edu.analytical.9` | Deload-Wochen alle 4–8 Wochen reduzieren ZNS-Müdigkeit. Volumen halbieren, Intensität halten. | Deload weeks every 4–8 weeks reduce CNS fatigue. Halve volume, keep intensity. | Her 4–8 haftada bir deload haftası ZNS yorgunluğunu azaltır. Hacmi yarıya indir, yoğunluğu koru. |
| `coaching.edu.motivating.1` | Du musst nicht motiviert sein — du musst nur anfangen. Motivation kommt während der ersten 5 Minuten. | You don't need motivation — you need to start. Motivation kicks in during the first 5 minutes. | Motive olmana gerek yok — sadece başlamana gerek var. Motivasyon ilk 5 dakikada gelir. |
| `coaching.edu.motivating.10` | Verwandle 'Ich muss' in 'Ich darf'. Trainieren ist ein Privileg, keine Pflicht. | Trade 'I have to' for 'I get to'. Training is a privilege, not a chore. | 'Yapmam lazım'ı 'Yapma fırsatım var'a dönüştür. Antrenman bir ayrıcalık. |
| `coaching.edu.motivating.11` | Du baust nicht nur Muskeln — du baust mentale Resilienz für alles andere. | You're not just building muscle — you're building mental resilience for everything else. | Sadece kas inşa etmiyorsun — diğer her şey için zihinsel dayanıklılık da inşa ediyorsun. |
| `coaching.edu.motivating.12` | Schlechte Tage gibt's. Schlechte Wochen auch. Schlechte Monate sind eine Entscheidung. | Bad days happen. Bad weeks too. Bad months are a decision. | Kötü günler olur. Kötü haftalar da. Kötü aylar bir karardır. |
| `coaching.edu.motivating.13` | Belohnung > Bestrafung. Feier kleine Fortschritte — der Kopf will Wiederholungen, die sich gut anfühlen. | Reward > punishment. Celebrate small progress — the brain wants reps that feel good. | Ödül > ceza. Küçük ilerlemeyi kutla — beyin iyi hissettiren tekrarları ister. |
| `coaching.edu.motivating.14` | Niemand wurde stark, indem er wartete, bis er sich bereit fühlte. Bereit ist man am Ende, nicht am Anfang. | Nobody got strong by waiting until they felt ready. Ready arrives at the end, not the start. | Kimse hazır hissedene kadar bekleyerek güçlü olmadı. Hazır olmak sonda gelir, başta değil. |
| `coaching.edu.motivating.15` | Du musst nicht alles richtig machen — du musst nur weitermachen. Perfektion ist der Feind von Progress. | You don't have to do everything right — just keep going. Perfect is the enemy of progress. | Her şeyi doğru yapmak zorunda değilsin — sadece devam etmek zorundasın. Mükemmel, ilerlemenin düşmanı. |
| `coaching.edu.motivating.16` | Jede Wiederholung ist eine Stimme für die Person, die du werden willst. 🗳️ | Every rep is a vote for the person you want to become. 🗳️ | Her tekrar, olmak istediğin kişi için bir oy. 🗳️ |
| `coaching.edu.motivating.17` | Der Unterschied zwischen gut und großartig? Die letzten zwei Wiederholungen, die keiner sieht. | The difference between good and great? The last two reps nobody sees. | İyi ile harika arasındaki fark? Kimsenin görmediği son iki tekrar. |
| `coaching.edu.motivating.18` | Muskeln wachsen nicht im Gym — sie wachsen im Schlaf. Heute Nacht ist Baustelle! 😴 | Muscles don't grow at the gym — they grow while you sleep. Tonight is construction time! 😴 | Kaslar salonda büyümez — uyurken büyür. Bu gece şantiye zamanı! 😴 |
| `coaching.edu.motivating.19` | Du musst nicht perfekt sein. Du musst nur öfter auftauchen als aufgeben. | You don't have to be perfect. You just have to show up more often than you give up. | Mükemmel olmak zorunda değilsin. Sadece pes ettiğinden daha sık ortaya çıkmalısın. |
| `coaching.edu.motivating.2` | Konsistenz schlägt Intensität. Drei mittelmäßige Wochen sind mehr wert als eine perfekte und zwei verlorene. | Consistency beats intensity. Three average weeks beat one perfect plus two lost ones. | Tutarlılık yoğunluğu yener. Üç ortalama hafta, bir mükemmel ve iki kayıp haftadan değerlidir. |
| `coaching.edu.motivating.20` | Ein Jahr hat 52 Wochen. Schon 3 Einheiten pro Woche sind 156 Termine mit deinem besseren Ich. | A year has 52 weeks. Just 3 sessions a week means 156 appointments with your better self. | Bir yılda 52 hafta var. Haftada sadece 3 seans, daha iyi benliğinle 156 randevu demek. |
| `coaching.edu.motivating.21` | Stark sein ist kein Talent. Es ist eine Gewohnheit — und du baust sie gerade auf. 💪 | Being strong isn't a talent. It's a habit — and you're building it right now. 💪 | Güçlü olmak yetenek değildir. Bir alışkanlıktır — ve sen onu şu an inşa ediyorsun. 💪 |
| `coaching.edu.motivating.3` | Jede absolvierte Einheit ist eine Stimme für deine Identität als jemand, der trainiert. Stimmen summieren sich. | Every completed session is a vote for your identity as someone who trains. Votes add up. | Her antrenman, 'ben antrenman yapan biriyim' kimliğine atılmış bir oydur. Oylar birikir. |
| `coaching.edu.motivating.4` | Heute mies trainiert ist immer noch besser als heute nicht trainiert. Auftauchen ist die halbe Miete. | A bad workout today still beats no workout today. Showing up is half the win. | Bugün kötü antrenman, bugün hiç antrenman yapmamaktan iyidir. Gelmek savaşın yarısıdır. |
| `coaching.edu.motivating.5` | Vergleich tötet Freude. Du-von-gestern ist dein einziger fairer Maßstab. | Comparison kills joy. Yesterday-you is your only fair benchmark. | Karşılaştırma sevinci öldürür. Dünkü sen, tek adil ölçüt. |
| `coaching.edu.motivating.6` | Kleine Siege heute sind die Bausteine großer Veränderungen in 6 Monaten. Geduld ist Disziplin in Zeitlupe. | Small wins today are the building blocks of big change in 6 months. Patience is discipline in slow motion. | Bugünkü küçük zaferler, 6 ay sonraki büyük değişimin yapı taşı. Sabır, ağır çekim disiplindir. |
| `coaching.edu.motivating.7` | Dein Körper kann mehr, als dein Kopf am Anfang glaubt. Vertrau dem Prozess. | Your body can do more than your head believes early on. Trust the process. | Vücudun, başlangıçta zihnin inandığından fazlasını yapabilir. Sürece güven. |
| `coaching.edu.motivating.8` | Plateaus sind keine Niederlagen, sondern Pausen, in denen sich Anpassungen festigen. | Plateaus aren't defeats — they're pauses where adaptations consolidate. | Plato yenilgi değil — adaptasyonların oturduğu duraklamadır. |
| `coaching.edu.motivating.9` | Ein Workout dauert eine Stunde. Der Stolz danach hält 24. | A workout lasts an hour. The pride afterwards lasts 24. | Antrenman bir saat sürer. Sonrasındaki gurur 24 saat. |
| `coaching.edu.strict.1` | Niemand kommt und rettet dich. Manchmal musst du dich selbst aus dem Bett ziehen. | No one's coming to save you. Sometimes you have to drag yourself out of bed. | Kimse seni kurtarmaya gelmiyor. Bazen kendini yataktan sürüklemen gerekir. |
| `coaching.edu.strict.10` | Dein heutiges Ich ist die Summe deiner gestrigen Entscheidungen. Plane das morgige Ich heute. | Today's you is the sum of yesterday's choices. Plan tomorrow's you today. | Bugünkü sen, dünkü kararlarının toplamı. Yarınkini bugün planla. |
| `coaching.edu.strict.11` | Aufwärmen ist Pflicht, kein Bonus. Verletzungen kommen, wenn man Abkürzungen nimmt. | Warming up is mandatory, not a bonus. Injuries come from shortcuts. | Isınma zorunlu, bonus değil. Sakatlık kestirmelerden gelir. |
| `coaching.edu.strict.12` | Wer nicht misst, lügt sich selbst an. Tracke jede Einheit. | If you don't measure, you're lying to yourself. Track every session. | Ölçmüyorsan kendine yalan söylüyorsun. Her antrenmanı kaydet. |
| `coaching.edu.strict.13` | Schlaf, Ernährung, Training. Drei Dinge. Wenn eines fehlt, lügst du dich an, dass du es ernst meinst. | Sleep, nutrition, training. Three things. Miss one and you're not serious — you're pretending. | Uyku, beslenme, antrenman. Üç şey. Biri eksikse ciddi değilsin — sadece numara yapıyorsun. |
| `coaching.edu.strict.14` | Niemand will deine Ausreden hören — auch du selbst nicht. Mach einfach. | Nobody wants to hear your excuses — not even you. Just do it. | Kimse mazeretini duymak istemiyor — sen bile. Sadece yap. |
| `coaching.edu.strict.15` | Du hast genau heute. Das ist die einzige Einheit, die zählt. | You only have today. It's the only session that counts. | Sadece bugün var. Tek sayan antrenman bu. |
| `coaching.edu.strict.16` | Halbe Wiederholungen, halbe Ergebnisse. Volle Range of Motion oder das Gewicht runter. | Half reps, half results. Full range of motion or drop the weight. | Yarım tekrar, yarım sonuç. Tam hareket açıklığı ya da ağırlığı düşür. |
| `coaching.edu.strict.17` | Dein Handy hat zwischen den Sätzen nichts in deiner Hand verloren. Pause heißt Erholung, nicht Scrollen. | Your phone has no business in your hand between sets. Rest means recovery, not scrolling. | Setler arasında telefonun elinde işi yok. Mola toparlanma demek, kaydırma değil. |
| `coaching.edu.strict.18` | Wer sein Training nicht loggt, trainiert auf Verdacht. Verdacht baut keinen Muskel. | If you don't log your training, you're training on a hunch. Hunches don't build muscle. | Antrenmanını kaydetmiyorsan tahminle çalışıyorsun. Tahmin kas yapmaz. |
| `coaching.edu.strict.19` | Das Aufwärmen ist kein Vorschlag. Kalte Muskeln reißen, warme wachsen. | The warm-up is not a suggestion. Cold muscles tear, warm muscles grow. | Isınma bir öneri değildir. Soğuk kas yırtılır, sıcak kas büyür. |
| `coaching.edu.strict.2` | Ausreden sind komfortabel und teuer. Wähle den unbequemen Weg. | Excuses are comfortable and expensive. Pick the uncomfortable path. | Mazeretler konforlu ve pahalı. Konforsuz yolu seç. |
| `coaching.edu.strict.20` | Motivation ist ein Gast, Disziplin wohnt hier. Plane Training wie einen Arzttermin. | Motivation is a guest, discipline lives here. Schedule training like a doctor's appointment. | Motivasyon misafirdir, disiplin burada yaşar. Antrenmanı doktor randevusu gibi planla. |
| `coaching.edu.strict.21` | Beschwer dich nicht über ausbleibende Ergebnisse, wenn Schlaf und Ernährung nicht mitziehen. | Don't complain about missing results if your sleep and your food aren't pulling their weight. | Uykun ve beslenmen üzerine düşeni yapmıyorsa, sonuç yok diye şikâyet etme. |
| `coaching.edu.strict.3` | Komfortzone ist der Ort, an dem Träume sterben. Verlasse sie jeden Tag bewusst. | The comfort zone is where dreams die. Leave it on purpose every day. | Konfor alanı, hayallerin öldüğü yer. Her gün bilinçli olarak terk et. |
| `coaching.edu.strict.4` | Hartes Training ist nicht das Problem. Inkonsistenz ist es. | Hard training isn't the problem. Inconsistency is. | Sert antrenman sorun değil. Tutarsızlık sorun. |
| `coaching.edu.strict.5` | Wenn du keine Zeit hast, hast du die falschen Prioritäten. Punkt. | No time means wrong priorities. Period. | Zamanın yoksa, önceliklerin yanlış. Nokta. |
| `coaching.edu.strict.6` | Schmerz ist temporär. Bedauern ist permanent. | Pain is temporary. Regret is permanent. | Acı geçici. Pişmanlık kalıcı. |
| `coaching.edu.strict.7` | Disziplin heißt: tun, was du gesagt hast, wenn die Stimmung weg ist. | Discipline means doing what you said when the mood is gone. | Disziplin: motivasyon gittiğinde söylediğini yapmaktır. |
| `coaching.edu.strict.8` | Es gibt keine schlechten Tage, nur schwache Reaktionen darauf. | There are no bad days — just weak reactions to them. | Kötü gün yok — sadece zayıf tepkiler var. |
| `coaching.edu.strict.9` | Niemand schuldet dir Ergebnisse. Du musst sie dir verdienen — Satz für Satz. | Nobody owes you results. You earn them — set by set. | Kimse sana sonuç borçlu değil. Set set kazanırsın. |
| `coaching.empty.message` | Aktuell ist keine Warnung oder Aktion nötig — weiter so. | No warning or action needed right now — keep it up. | Şu an uyarı veya işlem gerekmez — böyle devam et. |
| `coaching.empty.title` | Heute kein besonderer Hinweis | No special note today | Bugün özel bir not yok |
| `coaching.goal.hybrid.blurb` | Kraft + Ausdauer + Mobilität — alles fließt zusammen. | Strength + endurance + mobility — all flowing together. | Güç + dayanıklılık + mobilite — hepsi bir arada. |
| `coaching.goal.hybrid.label` | Funktionell / Hybrid | Functional / Hybrid | Fonksiyonel / Hibrit |
| `coaching.goal.hypertrophy.blurb` | Volumen, Pump, sichtbares Muskelwachstum. | Volume, pump, visible muscle growth. | Hacim, pump, görünür kas gelişimi. |
| `coaching.goal.hypertrophy.label` | Muskelaufbau | Muscle Building | Kas Gelişimi |
| `coaching.goal.strength.blurb` | Maximales 1RM, niedrige Reps, schwere Hauptlifts. | Max 1RM, low reps, heavy main lifts. | Maksimum 1RM, düşük tekrar, ağır ana hareketler. |
| `coaching.goal.strength.label` | Maximalkraft | Maximum Strength | Maksimal Güç |
| `coaching.goal.weightLoss.blurb` | Kaloriendefizit, Muskelerhalt, Alltagsbewegung. | Calorie deficit, muscle retention, daily activity. | Kalori açığı, kas koruması, günlük hareket. |
| `coaching.goal.weightLoss.label` | Abnehmen | Weight loss | Kilo verme |
| `coaching.highFatigueYesterday.analytical.hybrid` | Gestern war intensiv. Lockeres Zone-1-Cardio — Recovery-Run oder Radfahren — fördert heute die Durchblutung und beschleunigt den Abtransport von Stoffwechselprodukten. | Yesterday was intense. Easy zone-1 cardio — recovery run or cycling — boosts circulation today and speeds up metabolic clearance. | Dün yoğundu. Hafif zone-1 kardiyo — toparlanma koşusu veya bisiklet — bugün dolaşımı artırır ve metabolik temizliği hızlandırır. |
| `coaching.highFatigueYesterday.analytical.hypertrophy` | Das Volumen gestern war massiv. Die Muskelproteinsynthese arbeitet noch — ein kompletter Rest-Day ist heute die ergiebigste Entscheidung. | Yesterday's volume was massive. Muscle protein synthesis is still working — a full rest day today is the highest-yield decision. | Dünkü hacim devasaydı. Kas protein sentezi hâlâ çalışıyor — bugün tam dinlenme günü en verimli karar. |
| `coaching.highFatigueYesterday.analytical.strength` | Gestern hohe Last. Das ZNS braucht 48-72h für volle Erholung — heute maximal Technik mit leerer Stange oder komplett frei. | High load yesterday. The CNS needs 48-72h to fully recover — today at most bar-only technique work, or fully off. | Dün yüksek yük. MSS tam toparlanma için 48-72 saat ister — bugün en fazla boş barla teknik ya da tamamen izin. |
| `coaching.highFatigueYesterday.analytical.weightLoss` | Gestern war hochvolumig. Aktive Regeneration — ein lockerer Spaziergang — verbrennt heute Kalorien, ohne zusätzlichen Erholungsbedarf zu erzeugen. | Yesterday was high volume. Active recovery — an easy walk — burns calories today without adding recovery debt. | Dün yüksek hacimliydi. Aktif toparlanma — hafif bir yürüyüş — bugün toparlanma borcu eklemeden kalori yakar. |
| `coaching.highFatigueYesterday.motivating.hybrid` | Gestern war intensiv! Ein lockerer Recovery-Run oder eine Radrunde spült heute die schweren Beine frei. 🚴 | Yesterday was intense! An easy recovery run or bike spin will flush those heavy legs today. 🚴 | Dün yoğundu! Hafif bir toparlanma koşusu veya bisiklet turu bugün ağır bacakları açar. 🚴 |
| `coaching.highFatigueYesterday.motivating.hypertrophy` | Dein Volumen gestern war massiv! Muskeln wachsen in der Ruhephase — gönn dir heute einen kompletten Rest-Day. 😴 | Your volume yesterday was massive! Muscles grow during rest — treat yourself to a full rest day today. 😴 | Dünkü hacmin devasaydı! Kaslar dinlenirken büyür — bugün kendine tam bir dinlenme günü hediye et. 😴 |
| `coaching.highFatigueYesterday.motivating.strength` | Gestern ordentlich Last bewegt! Dein Nervensystem lädt gerade nach — morgen kommst du stärker zurück. ⚡ | You moved serious load yesterday! Your nervous system is recharging — you'll come back stronger tomorrow. ⚡ | Dün ciddi yük kaldırdın! Sinir sistemin şarj oluyor — yarın daha güçlü dönersin. ⚡ |
| `coaching.highFatigueYesterday.motivating.weightLoss` | Du hast gestern hart trainiert! Ein leichter Spaziergang heute verbrennt Kalorien UND hilft der Regeneration — doppelter Gewinn. 🚶 | You trained hard yesterday! An easy walk today burns calories AND helps recovery — double win. 🚶 | Dün sıkı çalıştın! Bugün hafif bir yürüyüş hem kalori yakar HEM toparlanmaya yardım eder — çifte kazanç. 🚶 |
| `coaching.highFatigueYesterday.strict.hybrid` | Intensiver Tag gestern. Recovery heißt aktiv: 20 Minuten lockeres Rollen, nicht 'mal schauen' auf der Couch. | Intense day yesterday. Recovery means active: 20 easy minutes rolling, not 'we'll see' on the couch. | Dün yoğun bir gündü. Toparlanma aktif demek: 20 dakika hafif tempo, koltukta 'bakarız' değil. |
| `coaching.highFatigueYesterday.strict.hypertrophy` | Gestern massiv trainiert. Heute trotzdem ins Gym zu rennen wäre Ego, kein Plan — Rest-Day, Punkt. | Massive session yesterday. Running back to the gym today would be ego, not programming — rest day, period. | Dün devasa bir seans. Bugün salona koşmak ego olur, program değil — dinlenme günü, nokta. |
| `coaching.highFatigueYesterday.strict.strength` | Hohe Last gestern. Heute schwer zu heben wäre dumm, nicht hart — das ZNS unterscheidet da sehr genau. | Heavy load yesterday. Lifting heavy today would be foolish, not tough — your CNS knows the difference precisely. | Dün ağır yük. Bugün ağır kaldırmak sertlik değil aptallık olur — MSS bu farkı çok iyi bilir. |
| `coaching.highFatigueYesterday.strict.weightLoss` | Viel Volumen gestern heißt nicht Sofa heute. Geh spazieren — das Defizit kennt keine Ruhetage, dein Training schon. | Big volume yesterday doesn't mean couch today. Go walk — the deficit takes no rest days, your training does. | Dünkü yüksek hacim bugün koltuk demek değil. Yürü — açık tatil yapmaz, antrenmanın yapar. |
| `coaching.morningCardioDone.analytical.hybrid` | Cardio-Komponente erledigt. Fürs Hybrid-Gleichgewicht fehlt heute noch der Kraft-Reiz — eine Abend-Einheit hält beide Systeme in Balance. | Cardio component done. For hybrid balance, today still misses the strength stimulus — an evening session keeps both systems level. | Kardiyo bileşeni tamam. Hibrit denge için bugün kuvvet uyaranı eksik — akşam seansı iki sistemi dengede tutar. |
| `coaching.morningCardioDone.analytical.hypertrophy` | Cardio ist erledigt. Fürs Abend-Krafttraining: Oberkörper-Fokus — die Beine sind vorermüdet und liefern keine sauberen Sätze mehr. | Cardio is done. For tonight's strength work: focus on the upper body — your legs are pre-fatigued and won't deliver clean sets. | Kardiyo tamam. Akşamki kuvvet için: üst vücuda odaklan — bacaklar ön yorgun, temiz set veremez. |
| `coaching.morningCardioDone.analytical.strength` | Cardio heute Morgen registriert. Wenn heute noch schwere Lifts anstehen: Oberkörper bevorzugen und längere Pausen — die Beine sind vorbelastet. | Cardio registered this morning. If heavy lifts are still planned today: favor upper body and take longer rests — the legs are pre-loaded. | Kardiyo bu sabah kaydedildi. Bugün ağır kaldırış varsa: üst vücudu tercih et, molaları uzat — bacaklar ön yüklü. |
| `coaching.morningCardioDone.analytical.weightLoss` | Cardio heute Morgen verbucht. Für den Fettabbau ist Muskelerhalt entscheidend — ein leichtes Ganzkörper-Krafttraining heute schützt die Magermasse im Defizit. | Cardio logged this morning. For weight loss, muscle retention is key — a light full-body strength session today protects lean mass in the deficit. | Kardiyo bu sabah kaydedildi. Yağ kaybında kas koruması kritik — bugün hafif bir tüm vücut kuvvet antrenmanı açıkta yağsız kütleyi korur. |
| `coaching.morningCardioDone.motivating.hybrid` | Cardio-Check! ✅ Dein Hybrid-Ziel braucht auch Kraft — heb heute Abend noch etwas Eisen. | Cardio: check! ✅ Your hybrid goal needs strength too — lift some iron tonight. | Kardiyo: tamam! ✅ Hibrit hedefin kuvvet de ister — bu akşam biraz demir kaldır. |
| `coaching.morningCardioDone.motivating.hypertrophy` | Cardio ist im Kasten! Heute Abend gehört dem Oberkörper — die Beine haben ihren Teil schon geleistet. 💪 | Cardio is in the bag! Tonight belongs to the upper body — your legs already did their part. 💪 | Kardiyo cepte! Bu akşam üst vücudun — bacaklar payına düşeni yaptı. 💪 |
| `coaching.morningCardioDone.motivating.strength` | Cardio-Basis steht! Falls heute noch gehoben wird: Oberkörper rockt, Beine schonen. ⚡ | Cardio base is set! If you lift today: rock the upper body, spare the legs. ⚡ | Kardiyo tabanı hazır! Bugün kaldıracaksan: üst vücut coşsun, bacaklar dinlensin. ⚡ |
| `coaching.morningCardioDone.motivating.weightLoss` | Super Start in den Tag! Wenn du heute noch Energie hast, bau ein leichtes Ganzkörper-Krafttraining ein — so bleiben die Muskeln im Defizit erhalten. 🌅 | Great start to the day! If you have energy left, add a light full-body strength session — it keeps your muscle while you cut. 🌅 | Güne süper başlangıç! Enerjin kaldıysa hafif bir tüm vücut kuvvet antrenmanı ekle — açıkta kasını korur. 🌅 |
| `coaching.morningCardioDone.strict.hybrid` | Halbzeit. Cardio war heute Morgen, Kraft steht noch aus — Hybrid gibt's nicht zum halben Preis. | Halftime. Cardio was this morning, strength is still owed — hybrid doesn't come at half price. | Devre arası. Kardiyo sabahtı, kuvvet hâlâ borç — hibrit yarı fiyata olmaz. |
| `coaching.morningCardioDone.strict.hypertrophy` | Cardio war noch nicht alles. Heute Abend Krafttraining — Oberkörper, die Beine sind durch. Aufbau passiert am Eisen. | Cardio wasn't the whole job. Strength tonight — upper body, the legs are spent. Muscle is built at the iron. | Kardiyo işin tamamı değildi. Akşam kuvvet — üst vücut, bacaklar bitti. Kas demirde yapılır. |
| `coaching.morningCardioDone.strict.strength` | Morgens Cardio ist okay — aber Maximalkraft braucht frische Beine. Heute schwere Squats? Verschieb sie. | Morning cardio is fine — but max strength needs fresh legs. Heavy squats today? Move them. | Sabah kardiyosu tamam — ama maksimal kuvvet taze bacak ister. Bugün ağır squat mı? Ertele. |
| `coaching.morningCardioDone.strict.weightLoss` | Cardio allein macht im Defizit auch Muskeln weg. Heute noch Eisen anfassen — leicht reicht, aber anfassen. | Cardio alone in a deficit burns muscle too. Touch some iron today — light is fine, but touch it. | Açıkta sadece kardiyo kası da eritir. Bugün demire dokun — hafif yeter ama dokun. |
| `coaching.morningStrengthDone.analytical.hybrid` | Kraft ist drin. Mit 6+ Stunden Abstand ist der Interferenz-Effekt minimal — 20-30 Minuten Zone-2-Cardio heute Abend passen perfekt. | Strength is in. With 6+ hours between sessions the interference effect is minimal — 20-30 minutes of zone-2 cardio tonight fits perfectly. | Kuvvet tamam. Seanslar arasında 6+ saat varsa interferans etkisi minimum — bu akşam 20-30 dakika zone-2 kardiyo tam oturur. |
| `coaching.morningStrengthDone.analytical.hypertrophy` | Kraft-Einheit heute Morgen verbucht. Die Muskelproteinsynthese läuft ab jetzt ~48h — Protein verteilen, Erholung priorisieren. | Strength session logged this morning. Muscle protein synthesis runs ~48h from here — spread your protein and prioritize recovery. | Bu sabah kuvvet seansı kaydedildi. Kas protein sentezi şu andan itibaren ~48 saat sürer — proteini yay, toparlanmaya öncelik ver. |
| `coaching.morningStrengthDone.analytical.strength` | Kraft heute Morgen abgehakt. Für Maximalkraft zählt jetzt ZNS-Erholung — leichte Bewegung okay, nichts Intensives mehr. | Strength done this morning. For max strength, CNS recovery is what counts now — light movement is fine, nothing intense. | Kuvvet bu sabah tamamlandı. Maksimal kuvvet için artık MSS toparlanması önemli — hafif hareket olur, yoğun bir şey olmaz. |
| `coaching.morningStrengthDone.analytical.weightLoss` | Kraft ist für heute erledigt. Für den Fettabbau bringt lockere Nachmittags-Aktivität — Spaziergang oder leichte Radtour — extra Kalorienverbrauch, ohne die Erholung zu stören. | Strength is done for today. For fat loss, easy afternoon activity — a walk or light ride — adds calorie burn without hurting recovery. | Bugünlük kuvvet tamam. Yağ kaybı için öğleden sonra hafif aktivite — yürüyüş veya hafif bisiklet — toparlanmayı bozmadan ekstra kalori yakar. |
| `coaching.morningStrengthDone.motivating.hybrid` | Kraft ist drin! Wenn du Zeit hast, mach heute noch 20-30 Minuten lockeres Zone-2-Cardio — dein Hybrid-Motor dankt es dir. 🚴 | Strength is in! If you have time, add 20-30 minutes of easy zone-2 cardio today — your hybrid engine will thank you. 🚴 | Kuvvet tamam! Vaktin varsa bugün 20-30 dakika rahat zone-2 kardiyo ekle — hibrit motorun teşekkür eder. 🚴 |
| `coaching.morningStrengthDone.motivating.hypertrophy` | Guter Pump heute Morgen! Iss genug Protein und ruh dich für den Rest des Tages aus. 💪 | Great pump this morning! Eat enough protein and rest up for the remainder of the day. 💪 | Bu sabah harika bir pump! Yeterince protein ye ve günün geri kalanında dinlen. 💪 |
| `coaching.morningStrengthDone.motivating.strength` | Schwere Arbeit heute Morgen erledigt! Gönn deinem Nervensystem jetzt die Pause, die es für den nächsten PR braucht. ⚡ | Heavy work done this morning! Now give your nervous system the rest it needs for the next PR. ⚡ | Ağır iş bu sabah bitti! Şimdi sinir sistemine bir sonraki PR için ihtiyacı olan molayı ver. ⚡ |
| `coaching.morningStrengthDone.motivating.weightLoss` | Kraft ist erledigt! Für maximalen Fettabbau häng heute Nachmittag noch einen Spaziergang oder eine lockere Radtour dran. 🚶 | Strength: done! For maximum fat burn, add a walk or an easy bike ride this afternoon. 🚶 | Kuvvet tamam! Maksimum yağ yakımı için bu öğleden sonra bir yürüyüş veya hafif bisiklet turu ekle. 🚶 |
| `coaching.morningStrengthDone.strict.hybrid` | Kraft erledigt — halbes Soll. Hybrid heißt beides: 20 Minuten lockeres Cardio heute noch, dann ist der Tag komplett. | Strength done — that's half the job. Hybrid means both: 20 minutes of easy cardio today completes the day. | Kuvvet bitti — işin yarısı. Hibrit ikisi de demek: bugün 20 dakika hafif kardiyo günü tamamlar. |
| `coaching.morningStrengthDone.strict.hypertrophy` | Training war heute Morgen. Jetzt nicht den Aufbau sabotieren: Protein rein, Füße hoch, kein Junk-Cardio. | Training was this morning. Don't sabotage the gains now: protein in, feet up, no junk cardio. | Antrenman bu sabahtı. Şimdi kazanımları sabote etme: protein al, ayakları uzat, gereksiz kardiyo yok. |
| `coaching.morningStrengthDone.strict.strength` | Schwer gehoben heute Morgen — gut. Wer abends nochmal 'ein bisschen was' macht, zahlt es beim nächsten Top-Satz zurück. | Lifted heavy this morning — good. Sneak in 'a little extra' tonight and your next top set will collect the bill. | Bu sabah ağır kaldırdın — güzel. Akşam 'biraz daha' yaparsan faturayı bir sonraki ağır set keser. |
| `coaching.morningStrengthDone.strict.weightLoss` | Kraft war heute Morgen. Das Defizit macht sich nicht von allein — 30 Minuten Spaziergang heute Nachmittag, keine Ausreden. | Strength was this morning. The deficit won't build itself — 30 minutes of walking this afternoon, no excuses. | Kuvvet bu sabahtı. Açık kendiliğinden oluşmaz — öğleden sonra 30 dakika yürüyüş, bahane yok. |
| `coaching.newPR.analytical.hybrid` | Leistungssteigerung erkannt. Neues Volumen-PR im Functional-Zirkel erreicht. Progression verläuft nach Plan. | Performance increase detected. New volume PR achieved in the functional circuit. Progression is on track. | Performans artışı tespit edildi. Fonksiyonel devrede yeni hacim PR'ı. İlerleme plan dahilinde. |
| `coaching.newPR.analytical.hypertrophy` | Neuer Volumen-PR registriert. Progressiver Overload greift — beim nächsten Mikro-Zyklus +1 Set oder +2 Wdh planen. | New volume PR logged. Progressive overload is working — plan +1 set or +2 reps for the next micro-cycle. | Yeni hacim PR'ı kaydedildi. Aşamalı yüklenme işliyor — bir sonraki mikro döngüde +1 set veya +2 tekrar planla. |
| `coaching.newPR.analytical.strength` | Neuer Top-Set-PR. Estimated 1RM aktualisiert. Trainingsmaxima werden im Hintergrund neu kalibriert. | New top-set PR. Estimated 1RM updated. Training maxes are being recalibrated in the background. | Yeni en üst set PR'ı. Tahmini 1RM güncellendi. Antrenman maksimumları arka planda yeniden hesaplanıyor. |
| `coaching.newPR.analytical.weightLoss` | Neue Bestleistung — im Defizit doppelt bemerkenswert, das spricht für gelungenen Muskelerhalt. | New personal record — doubly remarkable in a deficit; that signals successful muscle retention. | Yeni kişisel rekor — açıkta iki kat dikkat çekici; bu başarılı kas koruması demek. |
| `coaching.newPR.motivating.strength` | Unglaubliche Leistung! Neuer PR auf der Stange. Genau so funktioniert progressiver Overload — feier deinen Erfolg! | Incredible performance! New PR on the bar. That's how progressive overload works — celebrate your win! | Muhteşem performans! Barda yeni PR. Aşamalı yüklenme tam olarak böyle çalışır — başarını kutla! |
| `coaching.newPR.motivating.weightLoss` | PR im Defizit?! Du verlierst Gewicht UND wirst stärker — das ist die Königsklasse. 🏆 | A PR while cutting?! Losing weight AND getting stronger — that's elite. 🏆 | Açıktayken PR mi?! Kilo verip güçleniyorsun — bu işin şahı. 🏆 |
| `coaching.newPR.strict.hypertrophy` | Neuer PR. Gut. Aber werd nicht übermütig — die Technik muss auch im nächsten Zyklus zu 100% sitzen. Weiterarbeiten. | New PR. Good. But don't get cocky — technique still has to be 100% in the next cycle. Keep working. | Yeni PR. İyi. Ama kibre kapılma — sonraki döngüde de teknik %100 oturmalı. Çalışmaya devam. |
| `coaching.newPR.strict.weightLoss` | Bestleistung im Defizit. Gut. Beweis erbracht, dass 'keine Energie' meist Kopfsache ist — weiter so. | A record in a deficit. Good. Proof that 'no energy' is mostly mental — keep going. | Açıkta rekor. Güzel. 'Enerjim yok'un çoğunlukla kafada olduğunun kanıtı — devam. |
| `coaching.plateauDetected.analytical.hybrid` | Plateau über 3+ Wochen. Reiz-Wechsel: Tempo, ROM oder Übungs-Substitut — danach 5–7 Tage Deload. | Plateau over 3+ weeks. Switch the stimulus: tempo, ROM, or exercise substitute — then a 5–7 day deload. | 3+ haftadır plato. Uyarıyı değiştir: tempo, hareket aralığı veya hareket değişimi — ardından 5–7 günlük deload. |
| `coaching.plateauDetected.analytical.hypertrophy` | Stagnation seit 3 Wochen erkannt. Eine Anpassung der Übungsauswahl oder eine Deload-Woche wird empfohlen. | Stagnation detected for 3 weeks. Adjusting exercise selection or a deload week is recommended. | 3 haftalık durağanlık tespit edildi. Hareket seçimini değiştirmek veya bir deload haftası önerilir. |
| `coaching.plateauDetected.analytical.strength` | Top-Set-Progression flacht ab. Variante einbauen (Pin Press, Block Pull) oder Deload-Woche, dann zurück zum Haupt-Lift. | Top-set progression is flattening. Add a variant (pin press, block pull) or take a deload week, then return to the main lift. | En üst set ilerlemesi düzleşiyor. Varyant ekle (pin press, block pull) veya deload haftası al, sonra ana harekete dön. |
| `coaching.plateauDetected.analytical.weightLoss` | Stagnation erkannt. Im Defizit normal — prüfe zuerst Schlaf und Protein, bevor du das Defizit vergrößerst. | Plateau detected. Normal in a deficit — check sleep and protein first before deepening the deficit. | Plato tespit edildi. Açıkta normal — açığı büyütmeden önce uyku ve proteini kontrol et. |
| `coaching.plateauDetected.motivating.hybrid` | Völlig normal, mal auf der Stelle zu treten! Lass uns den Reiz ändern — probier ein neues Movement-Pattern aus. | Totally normal to hit a wall every now and then! Let's change the stimulus — try a new movement pattern. | Arada bir duraklamak son derece normal! Hadi uyarıyı değiştirelim — yeni bir hareket kalıbı dene. |
| `coaching.plateauDetected.motivating.weightLoss` | Kleines Plateau — völlig normal beim Abnehmen! Halte Kurs, der Körper zieht meist schubweise nach. 💪 | A small plateau — totally normal when cutting! Stay the course; the body usually catches up in waves. 💪 | Küçük bir plato — kilo verirken gayet normal! Rotanı koru; vücut genelde dalga dalga yetişir. 💪 |
| `coaching.plateauDetected.strict.strength` | Du hängst fest. Entweder isst du zu wenig, schläfst zu schlecht, oder dein Plan braucht einen Reset. Zeit für einen Deload. | You're stuck. Either you're under-eating, under-sleeping, or your plan needs a reset. Time for a deload. | Sıkıştın. Ya yeterince yemiyorsun, ya uyumuyorsun, ya da planının sıfırlanması gerekiyor. Deload zamanı. |
| `coaching.plateauDetected.strict.weightLoss` | Plateau. Bevor du jammerst: Tracking ehrlich? Schlaf da? Schritte drin? Meist liegt's an einem der drei. | Plateau. Before complaining: is your tracking honest? Sleep in place? Steps done? It's usually one of those three. | Plato. Şikâyetten önce: takip dürüst mü? Uyku tamam mı? Adımlar atıldı mı? Genelde bu üçünden biri. |
| `coaching.restDay.analytical.hybrid` | Ruhetag im Plan. Optional ein lockerer Aerob-Block (Z2, 30–45 Min) zur aktiven Erholung — sonst Pause. | Rest day in your plan. Optional easy aerobic block (Z2, 30–45 min) for active recovery — otherwise, take it off. | Planında dinlenme günü. İsteğe bağlı kolay aerobik blok (Z2, 30–45 dk) aktif iyileşme için — yoksa tamamen dinlen. |
| `coaching.restDay.analytical.hypertrophy` | Regenerationsphase aktiv. Muskelproteinsynthese läuft. Nächstes Training ist für morgen angesetzt. | Recovery phase active. Muscle protein synthesis is running. Your next workout is scheduled for tomorrow. | İyileşme aşaması aktif. Kas protein sentezi devam ediyor. Sonraki antrenman yarın için planlandı. |
| `coaching.restDay.analytical.strength` | Recovery-Tag. Dein ZNS arbeitet jetzt — das nächste 1RM wird heute, nicht im Gym, vorbereitet. | Recovery day. Your CNS is working now — your next 1RM is prepared today, not in the gym. | İyileşme günü. MSS şu an çalışıyor — sonraki 1RM bugün hazırlanır, salonda değil. |
| `coaching.restDay.analytical.weightLoss` | Heute ist Ruhetag laut Plan. Im Defizit besonders wichtig — NEAT (Alltagsbewegung) hoch halten, Training pausieren. | Today is a planned rest day. Especially important in a deficit — keep NEAT (daily movement) high, pause training. | Bugün plana göre dinlenme günü. Açıkta özellikle önemli — NEAT'i (günlük hareket) yüksek tut, antrenmana ara ver. |
| `coaching.restDay.motivating.hybrid` | Du hast dir eine Pause verdient! Ein leichter Mobility-Flow oder Spaziergang ist heute perfekt für deine aktive Erholung. | You've earned a break! A light mobility flow or a walk is perfect for active recovery today. | Bir mola hak ettin! Bugün hafif bir mobilite akışı veya yürüyüş aktif iyileşme için ideal. |
| `coaching.restDay.motivating.weightLoss` | Ruhetag! Auch beim Abnehmen gilt: Erholung schützt deine Muskeln. Ein Spaziergang zählt trotzdem. 🌿 | Rest day! Even when cutting: recovery protects your muscle. A walk still counts though. 🌿 | Dinlenme günü! Kilo verirken de geçerli: toparlanma kasını korur. Yine de yürüyüş sayılır. 🌿 |
| `coaching.restDay.strict.strength` | Heute wird nicht trainiert. Du wirst in der Pause stärker, nicht unter der Hantel. Bleib aus dem Gym. | No training today. You get stronger on rest days, not under the barbell. Stay out of the gym. | Bugün antrenman yok. Halterin altında değil, dinlenme günlerinde güçlenirsin. Salona girme. |
| `coaching.restDay.strict.weightLoss` | Ruhetag heißt kein Training — nicht kein Bewegen. 8.000 Schritte gehen trotzdem, das Defizit macht keine Pause. | Rest day means no training — not no moving. Still get your 8,000 steps; the deficit doesn't pause. | Dinlenme günü antrenman yok demek — hareket yok demek değil. Yine de 8.000 adımı at; açık mola vermez. |
| `coaching.soft.backupOverdue.analytical` | Dein letzter Daten-Export ist über 30 Tage her. Ein frisches Backup bewahrt deine Trainings-Historie. | Your last data export was over 30 days ago. A fresh backup keeps your training history safe. | Son veri dışa aktarımının üzerinden 30 günden fazla geçti. Yeni bir yedek antrenman geçmişini güvende tutar. |
| `coaching.soft.backupOverdue.motivating` | All diese PRs verdienen ein Sicherheitsnetz — kurzer CSV-Export und du bist zukunftssicher. 🛡️ | All these PRs deserve a safety net — quick CSV export and you're future-proof. 🛡️ | Tüm bu PR'lar bir güvenlik ağını hak ediyor — hızlı bir CSV dışa aktarımı seni geleceğe hazırlar. 🛡️ |
| `coaching.soft.backupOverdue.strict` | 30+ Tage ohne Backup. Mach's jetzt, bevor ein Handy-Wechsel dich deine Historie kostet. | 30+ days without a backup. Do it now before a phone swap costs you your history. | 30+ gündür yedek yok. Bir telefon değişikliği seni geçmişinden etmeden hemen yap. |
| `coaching.soft.deloadRecommended.analytical` | Deine Trainings-Last ist über drei Wochen um mehr als 20% gestiegen, und die letzten Einheiten fühlten sich schwer an. Die Daten sprechen für eine Deload-Woche: Gewichte um ~40-50% reduzieren, Bewegungen beibehalten. | Your training load has risen over 20% across three weeks, and your last sessions felt heavy. The data points to a deload week: cut weights by ~40-50% and keep the movements. | Antrenman yükün üç haftada %20'den fazla arttı ve son seanslar ağır hissettirdi. Veriler bir deload haftasını işaret ediyor: ağırlıkları ~%40-50 azalt, hareketleri koru. |
| `coaching.soft.deloadRecommended.motivating` | Du hast drei Wochen am Stück Vollgas gegeben — genau so entsteht Fortschritt! Gönn deinem Körper jetzt eine leichte Woche, um die Gains einzusammeln. Deload, erholen, stärker zurückkommen. 💪 | You've been pushing hard for three weeks straight — that's how progress is built! Now give your body a light week to cash in those gains. Deload, recover, come back stronger. 💪 | Üç haftadır aralıksız yükleniyorsun — ilerleme tam böyle olur! Şimdi vücuduna kazanımları toplaması için hafif bir hafta ver. Deload yap, toparlan, daha güçlü dön. 💪 |
| `coaching.soft.deloadRecommended.strict` | Drei Wochen steigende Last und du bewertest die Einheiten als brutal. Erholung ist Teil des Programms — plane jetzt eine Deload-Woche, sonst plant dein Körper sie für dich. | Three weeks of climbing load and you're rating sessions as brutal. Recovery is part of the program — schedule a deload week now, or your body will schedule one for you. | Üç haftadır artan yük ve seansları çok ağır olarak değerlendiriyorsun. Toparlanma programın parçası — şimdi bir deload haftası planla, yoksa vücudun senin yerine planlar. |
| `coaching.soft.hydrationLow.analytical` | Gestern unter 1,5 Liter geloggt. Schon 2% Dehydration kosten messbar Kraft — heute gegensteuern. | Under 1.5 liters logged yesterday. Even 2% dehydration measurably costs strength — counter it today. | Dün 1,5 litrenin altında kayıt. %2 dehidrasyon bile ölçülebilir kuvvet kaybettirir — bugün telafi et. |
| `coaching.soft.hydrationLow.motivating` | Dein Körper ist zu ~60% Wasser — gib ihm heute Nachschub! Jedes Glas zählt. 💧 | Your body is ~60% water — top it up today! Every glass counts. 💧 | Vücudun ~%60 su — bugün takviye et! Her bardak sayılır. 💧 |
| `coaching.soft.hydrationLow.strict` | Gestern zu wenig getrunken. Wasser ist das billigste Supplement, das es gibt — nutze es. | Too little water yesterday. Hydration is the cheapest supplement there is — use it. | Dün çok az su içtin. Su, var olan en ucuz takviyedir — kullan. |
| `coaching.soft.measurementOverdue.analytical` | Deine letzte Körpermessung ist über zwei Wochen her. Trends brauchen Datenpunkte — 30 Sekunden auf der Waage genügen. | Your last body measurement is over two weeks old. Trends need data points — 30 seconds on the scale will do. | Son vücut ölçümün iki haftadan eski. Trendler veri noktası ister — tartıda 30 saniye yeter. |
| `coaching.soft.measurementOverdue.motivating` | Zeit für ein Update! Eine schnelle Messung zeigt dir, was dein Training bewirkt hat. 📊 | Time for an update! A quick measurement shows you what your training has achieved. 📊 | Güncelleme zamanı! Hızlı bir ölçüm antrenmanının ne başardığını gösterir. 📊 |
| `coaching.soft.measurementOverdue.strict` | Über zwei Wochen ohne Messung. Was nicht gemessen wird, wird nicht gemanagt. | Over two weeks without a measurement. What doesn't get measured doesn't get managed. | İki haftadan fazladır ölçüm yok. Ölçülmeyen şey yönetilemez. |
| `coaching.soft.planPreview.analytical` | Plan-Eintrag für heute steht an. Optimaler Zeitpunkt für ein Mobility-Warmup vor den Compound-Lifts. | Today's plan entry is up. Optimal time for a mobility warmup before the compound lifts. | Bugün için plan girdisi mevcut. Bileşik hareketlerden önce mobilite ısınması için ideal zaman. |
| `coaching.soft.planPreview.analytical.1` | Heute steht eine Einheit im Plan. Ein kurzer Blick auf die letzten Gewichte vor dem Start spart Zeit im Gym. | A session is on today's plan. A quick look at your last weights before starting saves time at the gym. | Bugün planında bir seans var. Başlamadan önce son ağırlıklara hızlıca bakmak salonda zaman kazandırır. |
| `coaching.soft.planPreview.analytical.2` | Trainingstag laut Plan. Die beste Leistung kommt ~2-3 Stunden nach der letzten vollen Mahlzeit. | Training day per plan. Peak performance comes ~2-3 hours after your last full meal. | Plana göre antrenman günü. En iyi performans son tam öğünden ~2-3 saat sonra gelir. |
| `coaching.soft.planPreview.motivating` | Heute steht ein Training an. Mach dich gut warm und gib alles für die schweren Sätze! | A workout's on the schedule today. Warm up well and give it your all on the heavy sets! | Bugün bir antrenman var. İyi ısın ve ağır setlerde her şeyini ver! |
| `coaching.soft.planPreview.motivating.1` | Heute ist Trainingstag! Die beste Version von dir wartet im Gym. ⚡ | It's training day! The best version of you is waiting at the gym. ⚡ | Bugün antrenman günü! Senin en iyi versiyonun salonda bekliyor. ⚡ |
| `coaching.soft.planPreview.motivating.2` | Dein Plan ruft! Schon der Gang zum Gym ist der halbe Sieg. | Your plan is calling! Just getting to the gym is half the victory. | Planın seni çağırıyor! Salona gitmek bile zaferin yarısı. |
| `coaching.soft.planPreview.strict` | Heute ist Trainingstag. Kein Aufschub. Punkt. | Today is a training day. No postponing. Period. | Bugün antrenman günü. Erteleme yok. Nokta. |
| `coaching.soft.planPreview.strict.1` | Im Plan steht heute Training. Pläne sind keine Vorschläge. | The plan says training today. Plans are not suggestions. | Planda bugün antrenman yazıyor. Planlar öneri değildir. |
| `coaching.soft.planPreview.strict.2` | Heute Trainingstag. Die Frage ist nicht ob, sondern wann. | Training day. The question isn't if — it's when. | Bugün antrenman günü. Soru 'olup olmayacağı' değil, 'ne zaman'. |
| `coaching.soft.postCardio.analytical` | Erhöhtes Cardio-Volumen gestern registriert. Behalte die systemische Erholung im Auge und meide heute schwere Bein-Isolationsübungen. | Elevated cardio volume detected yesterday. Watch systemic recovery and avoid heavy leg isolation today. | Dün yüksek kardiyo hacmi kaydedildi. Sistemik toparlanmaya dikkat et ve bugün ağır bacak izolasyon hareketlerinden kaçın. |
| `coaching.soft.postCardio.analytical.1` | Die Cardio-Distanz von gestern ist verbucht. Wenn heute Beine anstehen, plane 1-2 Sätze weniger ein — die Glykogenspeicher füllen sich noch. | Yesterday's cardio distance is logged. If legs are on today's plan, schedule 1-2 fewer sets — glycogen stores are still refilling. | Dünkü kardiyo mesafesi kaydedildi. Bugün bacak günüyse 1-2 set az planla — glikojen depoları hâlâ doluyor. |
| `coaching.soft.postCardio.analytical.2` | Cardio-Einheit von gestern registriert. Heute auf Flüssigkeit und Elektrolyte achten — die Regeneration läuft noch. | Cardio session from yesterday registered. Focus on fluids and electrolytes today — recovery is still running. | Dünkü kardiyo seansı kaydedildi. Bugün sıvı ve elektrolitlere dikkat — toparlanma hâlâ sürüyor. |
| `coaching.soft.postCardio.motivating` | Mega Lauf gestern! Wenn die Beine heute noch etwas schwer sind, ist ein leichter Oberkörper-Fokus oder Mobility völlig okay. Bleib dran! | Awesome run yesterday! If your legs feel heavy today, an upper-body or mobility focus is totally fine. Keep it up! | Dün harika bir koşu yaptın! Bacakların bugün ağırsa üst vücut veya mobiliteye odaklan, sorun değil. Devam et! |
| `coaching.soft.postCardio.motivating.1` | Starke Ausdauer-Arbeit gestern! Dein Herz dankt es dir. 🏃 | Strong endurance work yesterday! Your heart thanks you. 🏃 | Dün harika bir dayanıklılık çalışmasıydı! Kalbin sana teşekkür ediyor. 🏃 |
| `coaching.soft.postCardio.motivating.2` | Die Kilometer von gestern zahlen direkt auf deine Grundlagenausdauer ein. Weiter so! | Yesterday's kilometers pay straight into your aerobic base. Keep it rolling! | Dünkü kilometreler doğrudan aerobik tabanına yazıldı. Böyle devam! |
| `coaching.soft.postCardio.strict` | Die Kilometer von gestern sind abgehakt. Ruh dich nicht darauf aus — fokussiere dich auf die heutige Einheit. Keine halben Sachen. | Yesterday's kilometers are done. Don't coast on it — focus on today's session. No half-measures. | Dünkü kilometreler tamam. Üstüne yatma — bugünkü antrenmana odaklan. Yarım iş yok. |
| `coaching.soft.postCardio.strict.1` | Cardio gestern war gut. Aber vergiss nicht: Kilometer ersetzen keine Kniebeugen. | Yesterday's cardio was solid. But remember: kilometers don't replace squats. | Dünkü kardiyo iyiydi. Ama unutma: kilometreler squat'ın yerini tutmaz. |
| `coaching.soft.postCardio.strict.2` | Gestern gelaufen, schön. Heute zählt, was du im Kraftraum daraus machst. | You ran yesterday, fine. Today counts what you make of it in the weight room. | Dün koştun, güzel. Bugün önemli olan ağırlık salonunda bundan ne çıkaracağın. |
| `coaching.soft.postVolume.analytical` | Lokale und systemische Last vom gestrigen Training ist hoch. Muskelproteinsynthese ist aktiv. Heute moderates Training oder aktive Erholung empfohlen. | High local and systemic load from yesterday's session. Muscle protein synthesis is active. Moderate training or active recovery recommended today. | Dünkü antrenmandan lokal ve sistemik yük yüksek. Kas protein sentezi aktif. Bugün orta yoğunlukta antrenman veya aktif toparlanma öneriliyor. |
| `coaching.soft.postVolume.analytical.1` | Über fünf Tonnen Volumen gestern. Protein-Timing in den nächsten 24 Stunden ist jetzt der größte Hebel für die Anpassung. | Over five tonnes moved yesterday. Protein timing in the next 24 hours is now the biggest lever for adaptation. | Dün beş tonun üzerinde hacim. Önümüzdeki 24 saatte protein zamanlaması adaptasyon için en büyük kaldıraç. |
| `coaching.soft.postVolume.analytical.2` | Hohe Volumen-Session gestern verbucht. Die Muskelproteinsynthese läuft ~48 Stunden — Schlaf priorisieren. | High-volume session logged yesterday. Muscle protein synthesis runs ~48 hours — prioritize sleep. | Dün yüksek hacimli seans kaydedildi. Kas protein sentezi ~48 saat sürer — uykuya öncelik ver. |
| `coaching.soft.postVolume.motivating` | Wahnsinn, was du gestern bewegt hast! Gönn deinem Körper heute ausreichend Protein und guten Schlaf, damit die Muskeln wachsen können. | Insane volume yesterday! Give your body enough protein and good sleep today so the muscles can grow. | Dün muazzam bir hacim kaldırdın! Bugün vücuduna yeterli protein ve iyi uyku ver, kasların büyüsün. |
| `coaching.soft.postVolume.motivating.1` | Gestern Tonnen bewegt — wortwörtlich! Dein Körper baut jetzt um. 💪 | You moved tonnes yesterday — literally! Your body is rebuilding right now. 💪 | Dün tonlarca ağırlık kaldırdın — kelimenin tam anlamıyla! Vücudun şu an yeniden inşa ediyor. 💪 |
| `coaching.soft.postVolume.motivating.2` | Was für eine Session gestern! Heute ist Erholung dein bester Trainingspartner. | What a session yesterday! Today, recovery is your best training partner. | Dün ne seanstı ama! Bugün en iyi antrenman ortağın toparlanma. |
| `coaching.soft.postVolume.strict` | Gutes Volumen gestern. Aber Muskeln wachsen nur, wenn du jetzt auch bei der Ernährung diszipliniert bleibst. Mach deine Hausaufgaben. | Good volume yesterday. But muscles only grow if you stay disciplined with nutrition too. Do your homework. | Dün iyi hacim. Ama kaslar ancak beslenmede de disiplinli kalırsan büyür. Ödevini yap. |
| `coaching.soft.postVolume.strict.1` | Gestern viel bewegt. Heute entscheidet sich, ob daraus Muskel wird: essen, schlafen, kein Junk-Volume. | Big numbers yesterday. Today decides whether they become muscle: eat, sleep, no junk volume. | Dün çok iş yaptın. Kas olup olmayacağına bugün karar verilir: ye, uyu, boş hacim yok. |
| `coaching.soft.postVolume.strict.2` | Volumen ist nur die halbe Miete. Die andere Hälfte heißt Regeneration — nimm sie genauso ernst. | Volume is only half the job. The other half is recovery — take it just as seriously. | Hacim işin sadece yarısı. Diğer yarısı toparlanma — onu da aynı ciddiyetle al. |
| `coaching.soft.reEntry.analytical` | Mehrere Tage ohne Training. Detraining-Effekte sind noch minimal. Empfehlung: leichte Wiedereinstiegs-Einheit mit ~70 % der gewohnten Last. | Several days off training. Detraining effects still minimal. Recommendation: a light re-entry session at ~70% of your usual load. | Birkaç gündür antrenman yok. Detraining etkisi henüz minimal. Öneri: olağan yükün ~%70'i ile hafif bir geri dönüş seansı. |
| `coaching.soft.reEntry.analytical.1` | Mehrere Pausentage verbucht. Kraftverlust beginnt erst nach ~2-3 Wochen — ein lockerer Wiedereinstieg reicht völlig. | Several rest days logged. Strength loss only starts after ~2-3 weeks — an easy re-entry session is plenty. | Birkaç dinlenme günü kaydedildi. Kuvvet kaybı ancak ~2-3 hafta sonra başlar — hafif bir dönüş seansı fazlasıyla yeter. |
| `coaching.soft.reEntry.analytical.2` | Nach einer Pause ist der Wiedereinstieg mit ~80-90% der letzten Gewichte der evidenzbasierte Weg. | After a break, re-entering at ~80-90% of your last weights is the evidence-based play. | Aradan sonra son ağırlıkların ~%80-90'ı ile dönmek kanıta dayalı yoldur. |
| `coaching.soft.reEntry.motivating` | Ein paar Tage Pause tun gut. Lust, heute mit einer leichten Einheit wieder reinzukommen? | A few rest days do you good. Up for easing back in with a light session today? | Birkaç gün ara iyi geldi. Bugün hafif bir antrenmanla geri dönmeye ne dersin? |
| `coaching.soft.reEntry.motivating.1` | Pausen gehören dazu — was zählt, ist das Comeback. Heute wäre ein guter Tag dafür! 🌟 | Breaks are part of the journey — what counts is the comeback. Today would be a great day for it! 🌟 | Aralar yolculuğun parçası — önemli olan geri dönüş. Bugün bunun için harika bir gün! 🌟 |
| `coaching.soft.reEntry.motivating.2` | Dein Training vermisst dich! Schon eine kurze Session bringt dich zurück in den Rhythmus. | Your training misses you! Even a short session gets you back in rhythm. | Antrenmanın seni özledi! Kısa bir seans bile seni ritme geri sokar. |
| `coaching.soft.reEntry.strict` | Lange genug pausiert. Jetzt zurück in die Routine. Heute starten. | Long enough off. Back to the routine. Start today. | Yeterince ara verdin. Şimdi rutine geri dön. Bugün başla. |
| `coaching.soft.reEntry.strict.1` | Fünf Tage ohne Training. Motivation folgt der Handlung, nicht umgekehrt — geh einfach hin. | Five days without training. Motivation follows action, not the other way around — just go. | Beş gündür antrenman yok. Motivasyon eylemi takip eder, tersi değil — sadece git. |
| `coaching.soft.reEntry.strict.2` | Die Pause ist lang genug. Der schwerste Satz heute ist der erste Schritt durch die Tür. | The break is long enough. The hardest set today is the first step through the door. | Ara yeterince uzadı. Bugünün en zor seti kapıdan atılan ilk adım. |
| `coaching.soft.streak.analytical` | Trainingsfrequenz hoch in den letzten 7 Tagen. Kumulierte Ermüdung steigt leicht an. Erwäge zeitnah einen Deload- oder Ruhetag. | High training frequency over the last 7 days. Cumulative fatigue is rising. Consider a deload or rest day soon. | Son 7 günde antrenman sıklığı yüksek. Birikmiş yorgunluk hafifçe artıyor. Yakında bir deload veya dinlenme günü düşün. |
| `coaching.soft.streak.analytical.1` | Fünf+ Einheiten in sieben Tagen. Bei dieser Frequenz wird Schlafqualität zum limitierenden Faktor — 7-9 Stunden anpeilen. | Five-plus sessions in seven days. At this frequency, sleep quality becomes the limiting factor — aim for 7-9 hours. | Yedi günde beş+ seans. Bu frekansta uyku kalitesi sınırlayıcı faktör olur — 7-9 saati hedefle. |
| `coaching.soft.streak.analytical.2` | Deine Trainingsfrequenz liegt im obersten Bereich. Konsistenz ist der stärkste Prädiktor für Langzeit-Fortschritt. | Your training frequency is in the top bracket. Consistency is the strongest predictor of long-term progress. | Antrenman frekansın en üst dilimde. Tutarlılık, uzun vadeli ilerlemenin en güçlü göstergesidir. |
| `coaching.soft.streak.motivating` | Toller Rhythmus aktuell! Du bist in einer fantastischen Konsistenz-Phase. Vergiss aber nicht, deinem Körper auch mal einen Ruhetag zu gönnen. | Great rhythm right now! You're on a solid consistency streak. Don't forget to give your body a rest day, though. | Şu an harika bir ritimdesin! Müthiş bir tutarlılık serisindesin. Vücuduna ara sıra dinlenme günü vermeyi unutma. |
| `coaching.soft.streak.motivating.1` | Du warst diese Woche eine Maschine! Diese Konsistenz unterscheidet Träumer von Machern. 🔥 | You've been a machine this week! This consistency separates dreamers from doers. 🔥 | Bu hafta makine gibiydin! Bu tutarlılık hayalperestleri yapanlardan ayırır. 🔥 |
| `coaching.soft.streak.motivating.2` | Fünf Workouts in einer Woche — dein zukünftiges Ich applaudiert schon jetzt. | Five workouts in one week — your future self is already applauding. | Bir haftada beş antrenman — gelecekteki sen şimdiden alkışlıyor. |
| `coaching.soft.streak.strict` | Mehrere Tage durchgezogen. Gut. Aber Routine ist Pflicht, kein Bonus. Lass jetzt nicht nach. | Several days in a row. Good. But routine is duty, not bonus. Don't slack now. | Üst üste birkaç gün. İyi. Ama rutin bir görev, bonus değil. Şimdi gevşeme. |
| `coaching.soft.streak.strict.1` | Hohe Frequenz diese Woche, Respekt. Aber Frequenz ohne Progression ist nur Beschäftigung — prüfe deine Gewichte. | High frequency this week, respect. But frequency without progression is just being busy — check your weights. | Bu hafta yüksek frekans, saygı duyarım. Ama ilerleme olmadan frekans sadece meşguliyettir — ağırlıklarını kontrol et. |
| `coaching.soft.streak.strict.2` | Viel trainiert. Gut. Jetzt halte das drei Monate durch, dann reden wir über Ergebnisse. | You trained a lot. Good. Now keep it up for three months, then we'll talk results. | Çok antrenman yaptın. Güzel. Şimdi bunu üç ay sürdür, sonra sonuçları konuşuruz. |
| `coaching.soft.trainedYesterday.analytical` | Die Session von gestern ist verbucht. Das 24-48h-Fenster entscheidet jetzt über die Anpassung: Protein, Schlaf, leichte Bewegung. | Yesterday's session is logged. The 24-48h window now decides the adaptation: protein, sleep, light movement. | Dünkü seans kaydedildi. Adaptasyonu şimdi 24-48 saatlik pencere belirler: protein, uyku, hafif hareket. |
| `coaching.soft.trainedYesterday.analytical.1` | Gestern trainiert. Wenn heute wieder eine Einheit ansteht: gleiche Muskelgruppen brauchen ~48h, frische dürfen ran. | You trained yesterday. If today brings another session: same muscle groups need ~48h, fresh ones are fair game. | Dün antrenman yaptın. Bugün yine seans varsa: aynı kas grupları ~48 saat ister, dinlenmiş olanlar hazır. |
| `coaching.soft.trainedYesterday.analytical.2` | Das Workout von gestern zahlt aufs Wochen-Volumen ein. Konsistenz schlägt einzelne Großtage — der nächste Baustein zählt am meisten. | Yesterday's workout counts toward your weekly volume. Consistency beats single big days — the next building block matters most. | Dünkü antrenman haftalık hacmine yazıldı. Tutarlılık tek büyük günleri yener — en önemlisi sıradaki yapı taşı. |
| `coaching.soft.trainedYesterday.motivating` | Gestern durchgezogen — stark! Dein Körper arbeitet gerade noch für dich weiter. 💪 | You showed up yesterday — strong! Your body is still working for you right now. 💪 | Dün işi bitirdin — harika! Vücudun şu an hâlâ senin için çalışıyor. 💪 |
| `coaching.soft.trainedYesterday.motivating.1` | Das Training von gestern sitzt! Egal ob heute Pause oder nächste Einheit: du bist im Rhythmus. 🔄 | Yesterday's workout is in the books! Whether today is rest or the next session: you're in rhythm. 🔄 | Dünkü antrenman cepte! Bugün ister dinlenme ister yeni seans: ritmin tam yerinde. 🔄 |
| `coaching.soft.trainedYesterday.motivating.2` | Schon wieder ein Workout im Log von gestern — genau diese Beständigkeit baut den Unterschied. ⭐ | Another workout logged yesterday — this steadiness is what builds the difference. ⭐ | Dünden bir antrenman daha kayıtta — farkı yaratan tam da bu istikrar. ⭐ |
| `coaching.soft.trainedYesterday.strict` | Gestern trainiert, gut. Erholung gehört zum Programm — aber Erholung heißt Schlaf und Essen, nicht Ausreden für morgen. | Trained yesterday, good. Recovery is part of the program — but recovery means sleep and food, not excuses for tomorrow. | Dün antrenman yaptın, güzel. Toparlanma programın parçası — ama toparlanma uyku ve yemek demek, yarın için bahane değil. |
| `coaching.soft.trainedYesterday.strict.1` | Ein Training gestern macht noch keinen Sommer. Heutigen Plan checken, dranbleiben. | One session yesterday doesn't make a summer. Check today's plan, stay on it. | Dünkü tek seans yaz getirmez. Bugünün planına bak, devam et. |
| `coaching.soft.trainedYesterday.strict.2` | Gestern geliefert. Der Körper merkt sich Serien, nicht Einzelleistungen — morgen wieder. | Delivered yesterday. The body remembers streaks, not one-offs — back at it tomorrow. | Dün teslim ettin. Vücut serileri hatırlar, tek seferleri değil — yarın yine. |
| `coaching.soft.volumeRecord.analytical` | Letzte Woche war deine volumenstärkste Woche seit Aufzeichnungsbeginn. Progressive Overload funktioniert — dokumentiert und messbar. | Last week was your highest-volume week on record. Progressive overload is working — documented and measurable. | Geçen hafta kayıtlardaki en yüksek hacimli haftandı. Aşamalı yüklenme işliyor — belgelenmiş ve ölçülebilir. |
| `coaching.soft.volumeRecord.motivating` | NEUER REKORD: deine stärkste Trainingswoche aller Zeiten! So sieht echte Arbeit aus. 🏆 | NEW RECORD: your strongest training week of all time! That's what real work looks like. 🏆 | YENİ REKOR: tüm zamanların en güçlü antrenman haftası! Gerçek emek böyle görünür. 🏆 |
| `coaching.soft.volumeRecord.strict` | Beste Woche deiner Historie. Gut. Rekorde sind dazu da, gebrochen zu werden — der nächste wartet. | Best week in your history. Good. Records exist to be broken — the next one is waiting. | Tarihinin en iyi haftası. Güzel. Rekorlar kırılmak içindir — sıradaki bekliyor. |
| `coaching.tone.analytical.blurb` | Fakten & Daten. Neutrales Feedback zu Load und Progression. | Facts & data. Neutral feedback on load and progression. | Veriler ve gerçekler. Yük ve ilerleme hakkında nötr geri bildirim. |
| `coaching.tone.analytical.label` | Analytisch | Analytical | Analitik |
| `coaching.tone.motivating.blurb` | Positiv & bestärkend. Fokus auf Erfolge und Erholung. | Positive & encouraging. Focus on wins and recovery. | Olumlu ve destekleyici. Başarılara ve iyileşmeye odaklı. |
| `coaching.tone.motivating.label` | Motivierend | Motivating | Motive Edici |
| `coaching.tone.strict.blurb` | Direkt & fordernd. Klartext, wenn du vom Plan abweichst. | Direct & demanding. Plain talk when you deviate from the plan. | Doğrudan ve talepkar. Plandan sapınca net konuşur. |
| `coaching.tone.strict.label` | Streng | Strict | Sıkı |

## `comeback.*`  (11 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `comeback.prompt.amount` | Reduktion | Reduction | Azaltma |
| `comeback.prompt.apply` | Gewichte senken | Lower weights | Ağırlıkları düşür |
| `comeback.prompt.decline` | Nein, volle Last | No, full load | Hayır, tam yük |
| `comeback.prompt.preview.header` | Das ändert sich | What changes | Neler değişiyor |
| `comeback.prompt.preview.more` | und %lld weitere | and %lld more | ve %lld tane daha |
| `comeback.prompt.preview.none` | Bei dieser Reduktion ändert sich auf dem Scheiben-Raster nichts. Wähle einen höheren Wert. | At this reduction nothing changes on the plate increments. Pick a higher value. | Bu azaltmada plaka kademelerinde hiçbir şey değişmiyor. Daha yüksek bir değer seç. |
| `comeback.prompt.rationale` | Kraft hält sich über Wochen gut — was nach einer Pause zuerst nachgibt, sind Sehnen, Technik und die Toleranz für Muskelkater. Etwas weniger Last in den ersten Sessions kostet dich nichts und schützt davor. | Strength holds up well over weeks — what gives first after a break is tendons, technique and your tolerance for soreness. A little less load in the first sessions costs you nothing and protects against that. | Kuvvet haftalarca iyi korunur — molada ilk zayıflayan tendonlar, teknik ve ağrı toleransıdır. İlk seanslarda biraz daha az yük sana hiçbir şeye mal olmaz ve bundan korur. |
| `comeback.prompt.recommended` | %lld %% (empfohlen) | %lld %% (recommended) | %%%lld (önerilen) |
| `comeback.prompt.retest` | Nach so langer Pause ist ein Tastversuch sinnvoller als eine geschätzte Reduktion: geh die ersten Sätze bewusst leicht an und finde deine Last neu. | After a break this long, feeling it out beats a guessed reduction: start the first sets deliberately light and find your load again. | Bu kadar uzun bir moladan sonra tahmini bir azaltma yerine yoklamak daha mantıklı: ilk setlere bilinçli olarak hafif başla ve yükünü yeniden bul. |
| `comeback.prompt.subtitle` | Dein letztes Krafttraining war vor %lld Tagen. Soll ich die Gewichte für den Wiedereinstieg senken? | Your last strength session was %lld days ago. Should I lower the weights for your return? | Son kuvvet antrenmanın %lld gün önceydi. Dönüş için ağırlıkları düşürmemi ister misin? |
| `comeback.prompt.title` | Willkommen zurück | Welcome back | Tekrar hoş geldin |

## `common.*`  (8 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `common.add` | Hinzufügen | Add | Ekle |
| `common.back` | Zurück | Back | Geri |
| `common.cancel` | Abbrechen | Cancel | İptal |
| `common.close` | Schließen | Close | Kapat |
| `common.done` | Fertig | Done | Bitti |
| `common.no` | Nein | No | Hayır |
| `common.save` | Speichern | Save | Kaydet |
| `common.yes` | Ja | Yes | Evet |

## `customExercise.*`  (8 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `customExercise.add` | Hinzufügen | Add | Ekle |
| `customExercise.field.compound` | Grundübung (Compound) | Compound exercise | Bileşik hareket |
| `customExercise.field.equipment` | Equipment | Equipment | Ekipman |
| `customExercise.field.muscle` | Zielmuskel | Target muscle | Hedef kas |
| `customExercise.section.metadata` | Eigenschaften | Attributes | Özellikler |
| `customExercise.section.metadataFooter` | Diese Angaben steuern die Tagesanalyse (Muskel-Fokus, Belastung) und die Progression. | These attributes drive the day analysis (muscle focus, load) and progression. | Bu bilgiler günlük analizi (kas odağı, yük) ve ilerlemeyi belirler. |
| `customExercise.section.name` | Name | Name | Ad |
| `customExercise.title` | Neue Übung | New exercise | Yeni hareket |

## `dashboard.*`  (81 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `dashboard.action.adHoc.a11y` | Spontanes Training starten — leere Session ohne Plan-Anbindung | Start a spontaneous workout — empty session without plan attachment | Spontane antrenman başlat — plana bağlı olmayan boş oturum |
| `dashboard.action.adHoc.primary` | Spontanes Training starten | Start spontaneous workout | Spontane antrenman başlat |
| `dashboard.action.adHoc.secondary` | Vom Plan abweichen — Spontanes Training | Skip the plan — spontaneous workout | Plandan sap — spontane antrenman |
| `dashboard.action.resumeRunning` | Laufendes Training fortsetzen | Resume running workout | Devam eden antrenmanı sürdür |
| `dashboard.action.startDirect` | Direkt starten | Start now | Hemen başlat |
| `dashboard.calendar.a11y` | Trainings-Kalender, %1$lld Trainingstage in diesem Monat, %2$lld-Wochen-Streak | Training calendar, %1$lld workout days this month, %2$lld-week streak | Antrenman takvimi, bu ay %1$lld antrenman günü, %2$lld haftalık seri |
| `dashboard.calendar.streakFormat` | %lld-Wochen-Streak | %lld-week streak | %lld haftalık seri |
| `dashboard.calendar.title` | Trainings-Kalender | Training calendar | Antrenman takvimi |
| `dashboard.cardioChart.legend` | min/km · niedriger = besser | min/km · lower = better | dk/km · daha düşük = daha iyi |
| `dashboard.cardioChart.title` | Cardio-Pace-Trend | Cardio Pace Trend | Kardiyo Tempo Trendi |
| `dashboard.compoundChart.empty.description` | Logge zwei oder mehr Sätze deiner großen Lifts, um die Kurve zu sehen. | Log two or more sets of your main lifts to see the trend. | Eğriyi görmek için ana liftlerinden iki veya daha fazla set kaydet. |
| `dashboard.compoundChart.empty.title` | Noch zu wenig Daten | Not enough data yet | Henüz yeterli veri yok |
| `dashboard.compoundChart.legend` | Geschätztes 1RM · gestrichelt = 4-Wochen-Prognose | Estimated 1RM · dashed = 4-week forecast | Tahmini 1RM · kesik çizgi = 4 haftalık tahmin |
| `dashboard.compoundChart.title` | Compound-Lift-Trend | Compound Lift Trend | Temel Hareket Trendi |
| `dashboard.deload.activeBanner` | Deload-Woche aktiv bis %@ — Arbeitsgewichte um ~50%% reduziert. Trainiere die Bewegungen, lass das Schleifen weg. | Deload week active until %@ — working weights reduced by ~50%%. Train the movements, skip the grind. | Deload haftası %@ tarihine kadar aktif — çalışma ağırlıkları ~%%50 azaltıldı. Hareketleri çalış, kendini ezme. |
| `dashboard.deload.applyButton` | Deload-Woche starten | Start deload week | Deload haftasını başlat |
| `dashboard.deload.endButton` | Deload beenden & Gewichte zurücksetzen | End deload & restore weights | Deload'u bitir ve ağırlıkları geri yükle |
| `dashboard.empty.cta.addMeasurement` | Messung hinzufügen | Add measurement | Ölçüm ekle |
| `dashboard.empty.cta.startWorkout` | Training starten | Start workout | Antrenmana başla |
| `dashboard.exerciseList.showLess` | Weniger anzeigen | Show less | Daha az göster |
| `dashboard.exerciseList.showMore.one` | %lld weitere anzeigen | Show %lld more | %lld tane daha göster |
| `dashboard.exerciseList.showMore.other` | %lld weitere anzeigen | Show %lld more | %lld tane daha göster |
| `dashboard.goal.line` | Ziel %@ kg | Goal %@ kg | Hedef %@ kg |
| `dashboard.greeting.afternoon.generic` | Guten Tag | Good afternoon | İyi günler |
| `dashboard.greeting.afternoon.named` | Guten Tag, %@ | Good afternoon, %@ | İyi günler, %@ |
| `dashboard.greeting.evening.generic` | Guten Abend | Good evening | İyi akşamlar |
| `dashboard.greeting.evening.named` | Guten Abend, %@ | Good evening, %@ | İyi akşamlar, %@ |
| `dashboard.greeting.morning.generic` | Guten Morgen | Good morning | Günaydın |
| `dashboard.greeting.morning.named` | Guten Morgen, %@ | Good morning, %@ | Günaydın, %@ |
| `dashboard.heatmap.a11y.tile` | %1$@, %2$lld Sätze, %3$@ | %1$@, %2$lld sets, %3$@ | %1$@, %2$lld set, %3$@ |
| `dashboard.heatmap.legend` | Sätze | Sets | Set |
| `dashboard.heatmap.title` | Muskel-Heatmap (Woche) | Muscle Heatmap (week) | Kas Isı Haritası (hafta) |
| `dashboard.history.countOnly` | %lld Trainings | %lld workouts | %lld antrenman |
| `dashboard.history.countWithLast` | %1$lld Trainings • zuletzt %2$@ | %1$lld workouts • last %2$@ | %1$lld antrenman • son %2$@ |
| `dashboard.history.empty` | Noch keine Trainings — starte oben dein erstes. | No workouts yet — start your first one above. | Henüz antrenman yok — yukarıdan ilkini başlat. |
| `dashboard.history.emptyDescription` | Starte dein erstes Training, um Verlauf und Fortschritt zu sehen. | Start your first workout to see history and progress. | Geçmiş ve ilerlemeyi görmek için ilk antrenmanına başla. |
| `dashboard.history.emptyTitle` | Noch kein Training gespeichert | No workout saved yet | Henüz kayıtlı antrenman yok |
| `dashboard.history.title` | Trainingsverlauf | Workout History | Antrenman Geçmişi |
| `dashboard.newMeasurement` | Neue Messung | New Measurement | Yeni Ölçüm |
| `dashboard.openSession.cancel` | Abbrechen | Cancel | İptal |
| `dashboard.openSession.dayName.unknown` | Unbekannt | Unknown | Bilinmiyor |
| `dashboard.openSession.discardAndStart` | Altes verwerfen & Neu starten | Discard old & start new | Eskiyi sil ve yeni başlat |
| `dashboard.openSession.message.fallback` | Es gibt bereits eine offene Trainings-Session. | There's already an open training session. | Halihazırda açık bir antrenman oturumu var. |
| `dashboard.openSession.message.withInfo` | Es läuft noch eine Session vom %1$@ (%2$@). Was möchtest du tun? | A session is still running from %1$@ (%2$@). What would you like to do? | %1$@ tarihinden kalan bir oturum hâlâ aktif (%2$@). Ne yapmak istersin? |
| `dashboard.openSession.resume` | Altes fortsetzen | Resume old | Eskisini sürdür |
| `dashboard.openSession.title` | Laufende Session | Active session | Aktif oturum |
| `dashboard.plan.checkoffRestDay.a11y` | Ruhetag im Plan abhaken, um morgen den nächsten Trainingstag anzuzeigen | Check off rest day in plan to show tomorrow's next workout day | Dinlenme gününü planda işaretle, yarınki sonraki antrenman günü görünsün |
| `dashboard.plan.checkoffRestDay.button` | Tag im Plan abhaken | Check off day in plan | Günü planda işaretle |
| `dashboard.plan.currentlyRunning` | Aktuell läuft | Currently running | Şu anda çalışıyor |
| `dashboard.plan.nextWorkout` | Nächstes Training | Next workout | Sıradaki antrenman |
| `dashboard.plan.noActivePlan.hint` | Lege im Plan-Tab deinen ersten Trainings-Plan an. | Set up your first training plan in the Plan tab. | İlk antrenman planını Plan sekmesinden oluştur. |
| `dashboard.plan.noActivePlan.title` | Kein aktiver Plan | No active plan | Aktif plan yok |
| `dashboard.plan.planEmpty.hint` | Füge deinem aktiven Plan im Plan-Tab Tage und Übungen hinzu. | Add days and exercises to your active plan in the Plan tab. | Plan sekmesinden aktif planına gün ve hareket ekle. |
| `dashboard.plan.planEmpty.title` | Plan noch leer | Plan still empty | Plan henüz boş |
| `dashboard.plan.restDay` | Heute ist Ruhetag. Zeit zur Erholung! | Today is a rest day. Time to recover! | Bugün dinlenme günü. İyileşme zamanı! |
| `dashboard.plan.tabShortcut` | Plan-Tab | Plan tab | Plan sekmesi |
| `dashboard.plan.todayRestDay` | Heute: Ruhetag | Today: rest day | Bugün: dinlenme günü |
| `dashboard.recent.empty.description` | Beende dein erstes Training, dann erscheint es hier mit Dauer, Sätzen und Volumen. | Finish your first workout — it appears here with duration, sets, and volume. | İlk antrenmanını tamamla — burada süre, set ve hacimle birlikte görünür. |
| `dashboard.recent.empty.title` | Noch keine Trainingseinheiten | No training sessions yet | Henüz antrenman yok |
| `dashboard.recent.title` | Letzte Trainings | Recent Workouts | Son Antrenmanlar |
| `dashboard.recent.viewAll` | Alle anzeigen | Show all | Tümünü göster |
| `dashboard.resume.caption` | Aktuelles Training fortsetzen | Resume current workout | Devam eden antrenmanı sürdür |
| `dashboard.trend.emptyDescription` | Tippe auf '+' oben rechts, um deinen ersten Wert einzutragen. | Tap '+' at the top right to enter your first value. | İlk değeri girmek için sağ üstteki '+' simgesine dokun. |
| `dashboard.trend.emptyTitle` | Noch keine Messungen | No measurements yet | Henüz ölçüm yok |
| `dashboard.trend.forecast.legend` | Prognose 4 / 8 W. | Forecast 4 / 8 w. | Tahmin 4 / 8 hf. |
| `dashboard.trend.insufficient` | %lld von 3 nötigen Messungen — Linear-Regression startet ab 3 Werten über mind. 1 Woche. | %lld of 3 required measurements — linear regression starts at 3 values over at least 1 week. | %lld / 3 gerekli ölçüm — doğrusal regresyon en az 1 hafta üzerinden 3 değerle başlar. |
| `dashboard.trend.needMore` | Mehr Werte über mind. 1 Woche für eine Prognose nötig. | More values over at least 1 week needed for a forecast. | Tahmin için en az 1 hafta boyunca daha fazla değer gerekli. |
| `dashboard.trend.title` | Gewichts-Trend | Weight Trend | Kilo Trendi |
| `dashboard.trend.unstable` | Werte schwanken stark — Prognose ausgeblendet, bis sich der Trend stabilisiert. | Values fluctuating heavily — forecast hidden until the trend stabilises. | Değerler büyük dalgalanmalar gösteriyor — trend kararlı hale gelene kadar tahmin gizli. |
| `dashboard.trophy.emptyDescription` | Schließe ein Training ab, um deinen ersten Rekord zu setzen. | Finish a workout to set your first record. | İlk rekorunu kaydetmek için bir antrenman tamamla. |
| `dashboard.trophy.emptyTitle` | Noch keine PRs | No PRs yet | Henüz PR yok |
| `dashboard.trophy.recordCount.one` | %lld Rekord | %lld record | %lld rekor |
| `dashboard.trophy.recordCount.other` | %lld Rekorde | %lld records | %lld rekor |
| `dashboard.trophy.title` | Trophy Room | Trophy Room | Kupa Odası |
| `dashboard.volumeChart.empty.description` | Absolviere ein paar Kraft-Sessions und dein wöchentliches Volumen erscheint hier. | Complete some strength sessions and your weekly volume will show up here. | Birkaç kuvvet antrenmanı tamamla, haftalık hacmin burada görünecek. |
| `dashboard.volumeChart.empty.title` | Noch kein Kraft-Volumen | No strength volume yet | Henüz kuvvet hacmi yok |
| `dashboard.volumeChart.legend` | kg pro Woche | kg per week | haftada kg |
| `dashboard.volumeChart.title` | Wochen-Volumen | Weekly volume | Haftalık hacim |
| `dashboard.weeklySummary.distance` | Distanz | Distance | Mesafe |
| `dashboard.weeklySummary.title` | Diese Woche | This Week | Bu Hafta |
| `dashboard.weeklySummary.volume` | Volumen | Volume | Hacim |

## `dashboardSettings.*`  (14 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `dashboardSettings.empty` | Alle Widgets deaktiviert. Tippe ein '+' weiter unten, um wieder welche einzublenden. | All widgets are off. Tap '+' below to bring some back. | Tüm widget'lar kapalı. Geri eklemek için aşağıdan '+' simgesine dokun. |
| `dashboardSettings.entry.subtitle` | Widgets ein-/ausblenden und umsortieren | Toggle widgets on/off and reorder | Widget'ları aç/kapat ve sırala |
| `dashboardSettings.entry.title` | Dashboard anpassen | Customize Dashboard | Panoyu Özelleştir |
| `dashboardSettings.section.active.footer` | Halten + ziehen zum Umsortieren. Toggle aus, um ein Widget zu deaktivieren. | Press and drag to reorder. Toggle off to deactivate a widget. | Sıralamak için basılı tutup sürükle. Devre dışı bırakmak için kapat. |
| `dashboardSettings.section.active.title` | Reihenfolge & Sichtbarkeit | Order & Visibility | Sıralama ve Görünürlük |
| `dashboardSettings.section.hero.empty` | Keine Hero-Karten aktiv — die obere Reihe ist ausgeblendet. | No hero cards active — the top row is hidden. | Aktif üst kart yok — üst satır gizlendi. |
| `dashboardSettings.section.hero.footer` | Bis zu 3 Metriken oben am Dashboard. Per Drag-and-Drop sortieren, per Toggle ausblenden. | Up to 3 metrics at the top of the dashboard. Drag to reorder, toggle to hide. | Panel'in üstünde en fazla 3 metrik. Sıralamak için sürükle, gizlemek için kapat. |
| `dashboardSettings.section.hero.maxReached` | Maximum 3 Hero-Karten gleichzeitig. | Maximum 3 hero cards at a time. | Aynı anda en fazla 3 üst kart. |
| `dashboardSettings.section.hero.title` | Hero-Karten (oben) | Hero Cards (top) | Üst Kartlar |
| `dashboardSettings.section.heroInactive.footer` | Tippe auf das Plus-Icon, um eine Metrik wieder oben einzublenden. | Tap the plus icon to put a metric back at the top. | Bir metriği tekrar yukarı eklemek için artı simgesine dokun. |
| `dashboardSettings.section.heroInactive.title` | Verfügbare Hero-Karten | Available Hero Cards | Kullanılabilir Üst Kartlar |
| `dashboardSettings.section.inactive.footer` | Tippe das '+' um ein Widget wieder ans Ende der Liste zu setzen. | Tap '+' to append a widget back to the active list. | Bir widget'ı tekrar aktif listenin sonuna eklemek için '+' simgesine dokun. |
| `dashboardSettings.section.inactive.title` | Inaktive Widgets | Inactive Widgets | Pasif Widget'lar |
| `dashboardSettings.title` | Dashboard anpassen | Customize Dashboard | Panoyu Özelleştir |

## `day.*`  (55 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `day.analysis.coachNote.balanced` | Ausgewogener Tag mit solidem Reiz und moderater Ermüdung. Gut planbar. | Balanced session with solid stimulus and moderate fatigue. Easy to plan around. | Dengeli bir gün — sağlam uyaran, orta düzey yorgunluk. Planlamak kolay. |
| `day.analysis.coachNote.cardioFocused` | Reiner Cardio-Tag. Halte den Reiz konstant und beobachte die Erholung der Beine bis zum nächsten Krafttag. | Pure cardio day. Keep the stimulus steady and watch leg recovery before the next strength session. | Tamamen kardiyo gün. Uyaranı sabit tut ve bir sonraki güç gününe kadar bacak toparlanmasını gözle. |
| `day.analysis.coachNote.compoundHeavy` | Systemisch fordernder Compound-Tag. Plane danach eher Erholung oder einen leichten Oberkörper-Tag. | Systemically demanding compound day. Plan for recovery or a light upper-body day afterwards. | Sistemik olarak zorlayıcı bir compound günü. Sonrasında toparlanma veya hafif üst vücut günü planla. |
| `day.analysis.coachNote.highLocal` | Hoher lokaler Reiz bei moderater Systemlast — klassischer Hypertrophie-Tag. | High local stimulus with moderate systemic load — classic hypertrophy day. | Yüksek yerel uyaran, orta düzey sistemik yük — klasik hipertrofi günü. |
| `day.analysis.coachNote.lightDeload` | Geringer Reiz — passend für Deload, Technik oder Erhaltung. | Low stimulus — ideal for deload, technique, or maintenance. | Düşük uyaran — deload, teknik veya koruma için ideal. |
| `day.analysis.coachNote.metabolicDensity` | Ein Zeitformat-Tag: Die Belastung kommt hier aus der Dichte, nicht aus dem Gewicht. | A time-format day: the load here comes from density, not from weight. | Bir zaman formatı günü: Buradaki yük ağırlıktan değil, yoğunluktan gelir. |
| `day.analysis.coachNote.metabolicDensity.amrap` | %@ ohne feste Pause. Die Belastung kommt hier aus der Dichte, nicht aus dem Gewicht. | %@ with no fixed rest. The load here comes from density, not weight. | Sabit molasız %@. Buradaki yük ağırlıktan değil, yoğunluktan gelir. |
| `day.analysis.coachNote.metabolicDensity.emom` | %@ im Minutentakt. Die Pause steckt in der Minute selbst, nicht dazwischen. | %@ on the minute. The rest lives inside the minute itself, not between them. | %@ dakika bazında. Mola dakikanın kendi içinde, aralarda değil. |
| `day.analysis.coachNote.metabolicDensity.forTime` | %@ im eigenen Tempo. Die Belastung kommt aus der Dichte, nicht aus dem Gewicht. | %@ at your own pace. The load comes from density, not weight. | %@ kendi temponda. Yük ağırlıktan değil, yoğunluktan gelir. |
| `day.analysis.coachNote.veryHighStress` | Sehr hohe Belastung. Achte danach besonders auf Schlaf und Nahrung — und plane keinen zweiten harten Tag direkt im Anschluss. | Very high load. Pay extra attention to sleep and food afterwards — and don't stack another hard day right after. | Çok yüksek yük. Sonrasında uykuya ve beslenmeye özellikle dikkat et — ve hemen ardına başka bir zor gün koyma. |
| `day.analysis.duration` | Geschätzte Dauer | Estimated Duration | Tahmini Süre |
| `day.analysis.empty` | Füge Übungen hinzu, um die Tagesanalyse zu sehen. | Add exercises to see the day analysis. | Gün analizini görmek için egzersiz ekle. |
| `day.analysis.estimated` | Schätzung | Estimate | Tahmin |
| `day.analysis.load.high` | Hoch | High | Yüksek |
| `day.analysis.load.low` | Leicht | Light | Hafif |
| `day.analysis.load.moderate` | Moderat | Moderate | Orta |
| `day.analysis.load.veryHigh` | Sehr hoch | Very High | Çok Yüksek |
| `day.analysis.loadLabel` | Belastung | Load | Yük |
| `day.analysis.muscleFocus.tier.primary` | Primär | Primary | Birincil |
| `day.analysis.muscleFocus.tier.secondary` | Sekundär | Secondary | İkincil |
| `day.analysis.muscleFocus.tier.tertiary` | Gering | Minor | Az |
| `day.analysis.muscleFocusLabel` | Muskel-Fokus | Muscle Focus | Kas Odağı |
| `day.analysis.recovery` | Regeneration | Recovery | Toparlanma |
| `day.analysis.restDay` | Heute ist Ruhetag. Keine relevante Trainingsbelastung geplant. | Today is a rest day. No relevant training load planned. | Bugün dinlenme günü. Önemli bir antrenman yükü planlanmadı. |
| `day.analysis.systemic` | Systemische Last | Systemic Load | Sistemik Yük |
| `day.analysis.title` | Tagesanalyse | Day Analysis | Gün Analizi |
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
| `day.editor.start.button` | Training starten | Start Workout | Antrenmanı Başlat |
| `day.editor.start.hintEmpty` | Füge erst mindestens eine Übung hinzu, dann kannst du das Training starten. | Add at least one exercise first to start the workout. | Antrenmanı başlatmak için önce en az bir hareket ekle. |
| `day.editor.start.resume` | Training fortsetzen | Resume Workout | Antrenmana Devam Et |
| `day.editor.start.resumeHint` | Eine offene Session zu diesem Tag läuft noch — tippe um sie fortzusetzen. | An open session for this day is still running — tap to resume it. | Bu güne ait açık bir oturum hâlâ çalışıyor — devam etmek için dokun. |
| `day.editor.superset.link` | Verbinden | Link | Bağla |
| `day.editor.superset.unlink` | Trennen | Unlink | Ayır |
| `day.editor.templateLocked.exercises` | Template-Plan — Übungen sind festgelegt. Du kannst sie ansehen, aber nicht hinzufügen, entfernen oder umsortieren. | Template plan — exercises are fixed. You can view them but not add, remove, or reorder. | Şablon plan — hareketler sabit. Görüntüleyebilirsin ama ekleyemez, kaldıramaz veya sıralayamazsın. |
| `day.editor.templateLocked.footer` | Dieser Tag gehört zu einem vorgefertigten Plan-Template und kann strukturell nicht bearbeitet werden. Du kannst aber die Trainings-Intensität anpassen. | This day belongs to a built-in plan template and can't be edited structurally. You can adjust training intensity though. | Bu gün hazır bir plan şablonuna ait ve yapısal olarak düzenlenemez. Ancak antrenman yoğunluğunu ayarlayabilirsin. |
| `day.editor.timedFormat.hintAmrap` | Keine festen Pausen — so viele Runden wie möglich, bis die Zeit um ist. | No fixed rest — as many rounds as possible until time is up. | Sabit mola yok — süre bitene kadar mümkün olduğunca çok tur. |
| `day.editor.timedFormat.hintEmom` | Keine festen Pausen — jede Minute startet neu. | No fixed rest — every minute starts fresh. | Sabit mola yok — her dakika yeniden başlar. |
| `day.editor.timedFormat.hintForTime` | Keine festen Pausen — so schnell wie möglich durcharbeiten. | No fixed rest — work through it as fast as possible. | Sabit mola yok — mümkün olduğunca hızlı bitir. |
| `day.editor.untitled` | Tag | Day | Gün |
| `day.restDay.complete.button` | Ruhetag abschließen | Complete Rest Day | Dinlenme Gününü Tamamla |
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
| `day_type.lower` | Unterkörper | Lower Body | Alt Vücut |
| `day_type.pull` | Pull | Pull | Pull |
| `day_type.push` | Push | Push | Push |
| `day_type.rest` | Ruhetag | Rest Day | Dinlenme Günü |
| `day_type.shoulders` | Schultern | Shoulders | Omuz |
| `day_type.upper` | Oberkörper | Upper Body | Üst Vücut |

## `difficulty.*`  (3 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `difficulty.advanced` | Profi | Advanced | İleri |
| `difficulty.beginner` | Anfänger | Beginner | Başlangıç |
| `difficulty.intermediate` | Fortgeschritten | Intermediate | Orta |

## `editor.*`  (32 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `editor.exercise.delete` | Übung löschen | Delete exercise | Hareketi sil |
| `editor.exercise.deleteConfirmCta` | Löschen | Delete | Sil |
| `editor.exercise.deleteConfirmMessage` | Bist du sicher? Diese Custom-Übung verschwindet dauerhaft. Bereits geloggte Trainings bleiben erhalten. | Are you sure? This custom exercise is removed permanently. Already logged workouts stay intact. | Emin misin? Bu özel hareket kalıcı olarak silinir. Kaydedilmiş antrenmanlar korunur. |
| `editor.exercise.deleteConfirmTitle` | Übung löschen? | Delete exercise? | Hareket silinsin mi? |
| `editor.exercise.distanceKm` | Distanz (km) | Distance (km) | Mesafe (km) |
| `editor.exercise.field.distanceExample` | z.B. 5,0 | e.g. 5.0 | örn. 5,0 |
| `editor.exercise.field.durationMin` | Dauer (min) | Duration (min) | Süre (dk) |
| `editor.exercise.field.name` | Name | Name | Ad |
| `editor.exercise.field.notePlaceholder` | Notiz (optional) | Note (optional) | Not (opsiyonel) |
| `editor.exercise.field.repsMax` | Wdh. max | Reps max | Tekrar maks |
| `editor.exercise.field.repsMin` | Wdh. min | Reps min | Tekrar min |
| `editor.exercise.field.secondsMax` | Sek. max | Sec. max | Saniye maks |
| `editor.exercise.field.secondsMin` | Sek. min | Sec. min | Saniye min |
| `editor.exercise.field.targetRIR` | Ziel-RIR | Target RIR | Hedef RIR |
| `editor.exercise.field.weightExample` | z.B. 60 | e.g. 60 | örn. 60 |
| `editor.exercise.general.footer` | Cardio = Run/Bike (Distanz + Dauer). Zeit-basiert = Plank/Wall-Sit (Hold-Timer). Nur eins gleichzeitig. | Cardio = Run/Bike (distance + duration). Time-Based = Plank/Wall-Sit (hold timer). Only one at a time. | Kardiyo = Koşu/Bisiklet (mesafe + süre). Süre Bazlı = Plank/Wall-Sit (tutma zamanlayıcısı). Aynı anda sadece bir tanesi. |
| `editor.exercise.rest` | Pause | Rest | Mola |
| `editor.exercise.section.cardioTarget` | Ziel (optional) | Target (optional) | Hedef (opsiyonel) |
| `editor.exercise.section.general` | Allgemein | General | Genel |
| `editor.exercise.section.notes` | Notizen | Notes | Notlar |
| `editor.exercise.section.pauseRIR` | Pause & Intensität | Rest & Intensity | Mola & Yoğunluk |
| `editor.exercise.section.setsReps` | Sätze & Wiederholungen | Sets & Reps | Set & Tekrar |
| `editor.exercise.section.suggestedWeight` | Vorgeschlagenes Gewicht (optional) | Suggested Weight (optional) | Önerilen Ağırlık (opsiyonel) |
| `editor.exercise.sets` | Sätze | Sets | Set |
| `editor.exercise.smartOff` | Aus = das Gewicht wird nie automatisch geändert. Du behältst die volle Kontrolle. | Off = weight never auto-adjusts. You stay in full control. | Kapalı = ağırlık asla otomatik değişmez. Kontrol sende. |
| `editor.exercise.smartProgressionFooterCompound` | Compound: Wenn du in allen Sätzen die obere Rep-Grenze schaffst UND der letzte Satz bei RIR ≤ 3 war, steigt das Gewicht beim nächsten Mal automatisch um den eingestellten Inkrement. | Compound: When you hit the upper rep limit in every set AND the last set was at RIR ≤ 3, the weight automatically increases by your set increment next time. | Bileşik: Tüm setlerde üst tekrar sınırına ulaşırsan VE son set RIR ≤ 3 ise, ağırlık bir sonraki sefer ayarladığın artış kadar otomatik yükselir. |
| `editor.exercise.smartProgressionFooterIsolation` | Isolation: Wenn du in allen Sätzen die obere Rep-Grenze schaffst UND der letzte Satz bei RIR ≤ 1 war (also nah am Versagen), steigt das Gewicht beim nächsten Mal um den eingestellten Inkrement. | Isolation: When you hit the upper rep limit in every set AND the last set was at RIR ≤ 1 (close to failure), the weight increases by your set increment next time. | İzolasyon: Tüm setlerde üst tekrar sınırına ulaşırsan VE son set RIR ≤ 1 ise (yani yetmezliğe yakın), ağırlık bir sonraki sefer ayarladığın artış kadar yükselir. |
| `editor.exercise.templateLocked` | Template-Übung — Name und Cardio/Zeit-Flags sind festgelegt. | Template exercise — name and cardio/time flags are fixed. | Şablon hareket — ad ve kardiyo/süre bayrakları sabit. |
| `editor.exercise.toggle.cardio` | Cardio | Cardio | Kardiyo |
| `editor.exercise.toggle.compoundLift` | Compound-Lift | Compound Lift | Bileşik Hareket |
| `editor.exercise.toggle.smartOverload` | Smart Overload aktivieren | Enable Smart Overload | Akıllı Aşırı Yüklemeyi Etkinleştir |
| `editor.exercise.toggle.timeBased` | Zeit-basiert | Time-Based | Süre Bazlı |

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

## `exercise.*`  (192 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `exercise.detail.chart.title` | e1RM-Verlauf | e1RM over time | Zaman içinde e1RM |
| `exercise.detail.empty` | Noch keine Sätze für diese Übung geloggt. Sobald du sie trainierst, erscheint hier dein Verlauf. | No sets logged for this exercise yet. Once you train it, your history shows up here. | Bu egzersiz için henüz set kaydedilmedi. Çalıştığında geçmişin burada görünecek. |
| `exercise.detail.prs.title` | Persönliche Rekorde | Personal records | Kişisel rekorlar |
| `exercise.detail.recent.title` | Letzte Sätze | Recent sets | Son setler |
| `exercise.detail.stats.bestE1RM` | Bestes e1RM | Best e1RM | En iyi e1RM |
| `exercise.detail.stats.distance` | Distanz gesamt | Total distance | Toplam mesafe |
| `exercise.detail.stats.duration` | Zeit gesamt | Total time | Toplam süre |
| `exercise.detail.stats.maxWeight` | Schwerster Satz | Heaviest set | En ağır set |
| `exercise.detail.stats.sets` | Sätze gesamt | Total sets | Toplam set |
| `exercise.detail.stats.volume` | Volumen gesamt | Total volume | Toplam hacim |
| `exercise.kind.cardio` | Cardio | Cardio | Kardiyo |
| `exercise.name.assistedDip` | Dip (assistiert) | Assisted Dip | Destekli Dip |
| `exercise.name.assistedPullUp` | Klimmzug (assistiert) | Assisted Pull-Up | Destekli Barfiks |
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
| `exercise.name.battleRopes` | Battle Ropes | Battle Ropes | Battle Ropes (Halat) |
| `exercise.name.bayesianCurl` | Bayesian Curl | Bayesian Curl | Bayesian Curl |
| `exercise.name.behindNeckPress` | Nackendrücken | Behind-the-Neck Press | Behind-the-Neck Press |
| `exercise.name.benchpress` | Bankdrücken | Bench Press | Bench Press |
| `exercise.name.bicepcurl` | Bizeps-Curl (KH) | Dumbbell Curl | Dumbbell Curl |
| `exercise.name.bodyweightCalfRaise` | Wadenheben (BW) | Bodyweight Calf Raise | Bodyweight Calf Raise |
| `exercise.name.bodyweightHipThrust` | Hip Thrust (BW) | Bodyweight Hip Thrust | Bodyweight Hip Thrust |
| `exercise.name.bodyweightLunge` | Ausfallschritte (BW) | Bodyweight Lunges | Bodyweight Lunges |
| `exercise.name.bodyweightSquat` | Kniebeuge (BW) | Bodyweight Squat | Bodyweight Squat |
| `exercise.name.boxJump` | Box Jump | Box Jump | Box Jump |
| `exercise.name.boxSquat` | Box Squat | Box Squat | Box Squat |
| `exercise.name.bulgarianSplitSquatDB` | Bulgarische Kniebeuge (KH) | Dumbbell Bulgarian Split Squat | Dumbbell Bulgarian Split Squat |
| `exercise.name.burpee` | Burpees | Burpees | Burpees |
| `exercise.name.cableCrossover` | Kabel Crossover | Cable Crossover | Cable Crossover |
| `exercise.name.cableCrunch` | Kabel Crunch | Cable Crunch | Cable Crunch |
| `exercise.name.cableCurl` | Kabel Curl | Cable Curl | Cable Curl |
| `exercise.name.cableLateralRaise` | Kabel Seitheben | Cable Lateral Raise | Cable Lateral Raise |
| `exercise.name.cableOverheadTricepExtension` | Trizepsstrecker über Kopf (Kabel) | Cable Overhead Triceps Extension | Cable Overhead Triceps Extension |
| `exercise.name.cablePullThrough` | Cable Pull-Through | Cable Pull-Through | Cable Pull-Through |
| `exercise.name.cableWoodchopper` | Cable Woodchopper | Cable Woodchopper | Cable Woodchopper (Odun Kesme) |
| `exercise.name.calfPressLegPress` | Wadenpresse (Beinpresse) | Calf Press (Leg Press) | Baldır Press (Leg Press) |
| `exercise.name.chestDip` | Dips (Brust) | Chest Dips | Chest Dips |
| `exercise.name.chestPressMachine` | Brustdrücken (Maschine) | Machine Chest Press | Machine Chest Press |
| `exercise.name.chestSupportedRowDB` | Chest Supported Row (KH) | Chest-Supported Dumbbell Row | Chest-Supported Dumbbell Row |
| `exercise.name.cleanAndJerk` | Umsetzen & Stoßen | Clean & Jerk | Clean & Jerk (Silkme) |
| `exercise.name.closeGripBenchPress` | Enges Bankdrücken | Close-Grip Bench Press | Close-Grip Bench Press |
| `exercise.name.concentrationCurl` | Konzentrations-Curl (KH) | Concentration Curl | Concentration Curl |
| `exercise.name.copenhagenPlank` | Copenhagen Plank | Copenhagen Plank | Copenhagen Plank |
| `exercise.name.crunch` | Crunches (BW) | Crunches | Mekik |
| `exercise.name.cycling` | Radfahren (outdoor) | Outdoor Cycling | Bisiklet |
| `exercise.name.deadlift` | Kreuzheben (konventionell) | Conventional Deadlift | Conventional Deadlift |
| `exercise.name.declineBenchPress` | Schrägbankdrücken (abwärts) | Decline Bench Press | Decline Bench Press |
| `exercise.name.deficitDeadlift` | Deficit-Kreuzheben | Deficit Deadlift | Deficit Deadlift |
| `exercise.name.diamondPushup` | Diamant-Liegestütze | Diamond Push-Up | Diamond Push-Up |
| `exercise.name.dragonFlag` | Dragon Flag | Dragon Flag | Dragon Flag |
| `exercise.name.dumbbellBenchPress` | Bankdrücken (KH) | Dumbbell Bench Press | Dumbbell Bench Press |
| `exercise.name.dumbbellCalfRaise` | Wadenheben (KH) | Dumbbell Calf Raise | Dumbbell Calf Raise |
| `exercise.name.dumbbellDeadlift` | Kreuzheben (KH) | Dumbbell Deadlift | Dumbbell Deadlift |
| `exercise.name.dumbbellFlyFlat` | Flyes flach (KH) | Flat Dumbbell Fly | Flat Dumbbell Fly |
| `exercise.name.dumbbellFlyIncline` | Flyes Schrägbank (KH) | Incline Dumbbell Fly | Incline Dumbbell Fly |
| `exercise.name.dumbbellHipThrust` | Hip Thrust (KH) | Dumbbell Hip Thrust | Dumbbell Hip Thrust |
| `exercise.name.dumbbellInclineBenchPress` | Schrägbankdrücken aufwärts (KH) | Incline Dumbbell Bench Press | Incline Dumbbell Bench Press |
| `exercise.name.dumbbellLunge` | Ausfallschritte (KH) | Dumbbell Lunges | Dumbbell Lunges |
| `exercise.name.dumbbellOverheadTricepExtension` | Trizepsstrecker über Kopf (KH) | Overhead Dumbbell Triceps Extension | Overhead Dumbbell Triceps Extension |
| `exercise.name.dumbbellPullover` | Pullover (KH) | Dumbbell Pullover | Dumbbell Pullover |
| `exercise.name.dumbbellPushPress` | Push Press (KH) | Dumbbell Push Press | Dumbbell Push Press |
| `exercise.name.dumbbellRDL` | Rumänisches Kreuzheben (KH) | Dumbbell Romanian Deadlift | Dumbbell Romanian Deadlift |
| `exercise.name.dumbbellRowOneArm` | Rudern einarmig (KH) | One-Arm Dumbbell Row | One-Arm Dumbbell Row |
| `exercise.name.dumbbellShoulderPress` | Schulterdrücken (KH) | Dumbbell Shoulder Press | Dumbbell Shoulder Press |
| `exercise.name.dumbbellShrug` | Shrug (KH) | Dumbbell Shrug | Dumbbell Shrug |
| `exercise.name.dumbbellThruster` | Thruster (KH) | Dumbbell Thruster | Dumbbell Thruster |
| `exercise.name.dumbbellTricepKickback` | Trizepskickback (KH) | Dumbbell Triceps Kickback | Dumbbell Triceps Kickback |
| `exercise.name.easyRun` | Easy Run | Easy Run | Kolay Koşu |
| `exercise.name.elliptical` | Crosstrainer | Elliptical | Eliptik |
| `exercise.name.facePull` | Face Pull | Face Pull | Face Pull |
| `exercise.name.farmersWalk` | Farmer's Walk | Farmer's Walk | Farmer's Walk |
| `exercise.name.floorPress` | Floor Press | Floor Press | Floor Press |
| `exercise.name.frontRaise` | Frontheben | Front Raise | Front Raise |
| `exercise.name.frontSquat` | Front Squat | Front Squat | Front Squat |
| `exercise.name.gluteBridge` | Glute Bridge (BW) | Glute Bridge | Glute Bridge |
| `exercise.name.gobletSquat` | Goblet Squat | Goblet Squat | Goblet Squat |
| `exercise.name.goodMorning` | Good Morning | Good Morning | Good Morning |
| `exercise.name.hackSquat` | Hack Squat | Hack Squat | Hack Squat |
| `exercise.name.hammerCurl` | Hammer Curl | Hammer Curl | Hammer Curl |
| `exercise.name.handstandPushup` | Handstand-Liegestütze | Handstand Push-Up | Handstand Push-Up |
| `exercise.name.hangingLegRaise` | Hanging Leg Raises | Hanging Leg Raise | Hanging Leg Raise |
| `exercise.name.hexPress` | Hex Press (Squeeze Press) | Hex Press (Squeeze Press) | Hex Press (Squeeze Press) |
| `exercise.name.inclineBenchPress` | Schrägbankdrücken (aufwärts) | Incline Bench Press | Incline Bench Press |
| `exercise.name.inclineDumbbellCurl` | Schrägbank-Curl (KH) | Incline Dumbbell Curl | Incline Dumbbell Curl |
| `exercise.name.intervals` | Intervalle | Intervals | İnterval |
| `exercise.name.invertedRow` | Inverted Row | Inverted Row | Inverted Row |
| `exercise.name.jumpSquat` | Jump Squat | Jump Squat | Jump Squat |
| `exercise.name.jumpingLunges` | Gesprungene Ausfallschritte | Jumping Lunges | Jumping Lunges |
| `exercise.name.kettlebellCleanAndPress` | Kettlebell Clean & Press | Kettlebell Clean & Press | Kettlebell Clean & Press |
| `exercise.name.kettlebellDeadlift` | Kettlebell Kreuzheben | Kettlebell Deadlift | Kettlebell Deadlift |
| `exercise.name.kettlebellFloorPress` | Kettlebell Floor Press | Kettlebell Floor Press | Kettlebell Floor Press |
| `exercise.name.kettlebellFrontSquat` | Kettlebell Front Squat | Kettlebell Front Squat | Kettlebell Front Squat |
| `exercise.name.kettlebellGobletSquat` | Kettlebell Goblet Squat | Kettlebell Goblet Squat | Kettlebell Goblet Squat |
| `exercise.name.kettlebellHalo` | Kettlebell Halo | Kettlebell Halo | Kettlebell Halo |
| `exercise.name.kettlebellOverheadPress` | Kettlebell Overhead Press | Kettlebell Overhead Press | Kettlebell Overhead Press |
| `exercise.name.kettlebellPushPress` | Kettlebell Push Press | Kettlebell Push Press | Kettlebell Push Press |
| `exercise.name.kettlebellRDL` | Kettlebell RDL | Kettlebell RDL | Kettlebell RDL |
| `exercise.name.kettlebellRowSingleArm` | Kettlebell Row einarmig | Kettlebell Single-Arm Row | Kettlebell Tek Kol Row |
| `exercise.name.kettlebellSnatch` | Kettlebell Snatch | Kettlebell Snatch | Kettlebell Snatch |
| `exercise.name.kettlebellSnatchLeft` | Kettlebell Snatch (Links) | Kettlebell Snatch (Left) | Kettlebell Snatch (Sol) |
| `exercise.name.kettlebellSnatchRight` | Kettlebell Snatch (Rechts) | Kettlebell Snatch (Right) | Kettlebell Snatch (Sağ) |
| `exercise.name.kettlebellSuitcaseCarry` | Kettlebell Suitcase Carry | Kettlebell Suitcase Carry | Kettlebell Bavul Taşıma |
| `exercise.name.kettlebellSwing` | Kettlebell Swing | Kettlebell Swing | Kettlebell Swing |
| `exercise.name.kneePushup` | Liegestütze (Knie) | Knee Push-Up | Diz Üstü Şınav |
| `exercise.name.lSit` | L-Sit | L-Sit | L-Sit |
| `exercise.name.latPulldownClose` | Latzug (eng) | Close-Grip Lat Pulldown | Close-Grip Lat Pulldown |
| `exercise.name.lateralRaise` | Seitheben | Lateral Raise | Lateral Raise |
| `exercise.name.latpulldown` | Latzug (weit) | Wide-Grip Lat Pulldown | Wide-Grip Lat Pulldown |
| `exercise.name.legExtension` | Beinstrecker | Leg Extension | Leg Extension |
| `exercise.name.legpress` | Beinpresse | Leg Press | Leg Press |
| `exercise.name.longRun` | Long Run | Long Run | Uzun Koşu |
| `exercise.name.lyingLegCurl` | Beinbeuger liegend | Lying Leg Curl | Lying Leg Curl |
| `exercise.name.lyingLegExtension` | Beinstrecker liegend | Lying Leg Extension | Lying Leg Extension |
| `exercise.name.lyingLegRaise` | Beinheben (liegend) | Lying Leg Raise | Lying Leg Raise |
| `exercise.name.meadowsRow` | Meadows Row | Meadows Row | Meadows Row |
| `exercise.name.medicineBallSlam` | Medizinball-Slam | Medicine Ball Slam | Sağlık Topu Slam |
| `exercise.name.mountainClimber` | Mountain Climbers | Mountain Climbers | Mountain Climbers |
| `exercise.name.muscleUp` | Muscle-Up | Muscle-Up | Muscle-Up |
| `exercise.name.neckCurl` | Nacken-Curl | Neck Curl | Boyun Curl |
| `exercise.name.neckExtension` | Nacken-Extension | Neck Extension | Boyun Ekstansiyonu |
| `exercise.name.neutralGripLatPulldown` | Latzug (neutraler Griff) | Neutral-Grip Lat Pulldown | Nötr Tutuş Lat Çekiş |
| `exercise.name.nordicCurl` | Nordic Curls | Nordic Curl | Nordic Curl |
| `exercise.name.overheadpress` | Schulterdrücken (stehend) | Standing Overhead Press | Standing Overhead Press |
| `exercise.name.pecDeck` | Pec Deck (Butterfly) | Pec Deck | Pec Deck |
| `exercise.name.pendlayRow` | Pendlay Row | Pendlay Row | Pendlay Row |
| `exercise.name.pikePushup` | Pike Liegestütze | Pike Push-Up | Pike Push-Up |
| `exercise.name.pistolSquat` | Pistol Squat | Pistol Squat | Pistol Squat |
| `exercise.name.plank` | Plank | Plank | Plank |
| `exercise.name.preacherCurl` | Preacher Curl (Maschine) | Machine Preacher Curl | Machine Preacher Curl |
| `exercise.name.pullup` | Klimmzüge (eng/Chin-up) | Chin-Up | Barfiks (Chin-Up) |
| `exercise.name.pullupStandard` | Klimmzüge | Pull-Up | Barfiks |
| `exercise.name.pushPress` | Push Press | Push Press | Push Press |
| `exercise.name.pushup` | Liegestütze | Push-Up | Şınav |
| `exercise.name.renegadeRow` | Renegade Row | Renegade Row | Renegade Row |
| `exercise.name.reverseCableFly` | Reverse Cable Fly | Reverse Cable Fly | Ters Cable Fly |
| `exercise.name.reverseCurl` | Reverse Curl | Reverse Curl | Reverse Curl |
| `exercise.name.reverseFlyDB` | Reverse Flyes (KH) | Dumbbell Reverse Fly | Dumbbell Reverse Fly |
| `exercise.name.reverseNordicCurl` | Reverse Nordic Curl | Reverse Nordic Curl | Ters Nordic Curl |
| `exercise.name.reverseWristCurl` | Handgelenk-Curl (umgekehrt) | Reverse Wrist Curl | Ters Bilek Curl |
| `exercise.name.romanianDeadlift` | Rumänisches Kreuzheben | Romanian Deadlift | Romanian Deadlift |
| `exercise.name.rowingMachine` | Rudermaschine | Rowing Machine | Kürek Ergometresi |
| `exercise.name.run` | Freier Lauf | Outdoor Run | Koşu |
| `exercise.name.russianTwist` | Russian Twists | Russian Twist | Russian Twist |
| `exercise.name.sandbagCarry` | Sandbag Carry | Sandbag Carry | Kum Torbası Taşıma |
| `exercise.name.seatedCableRow` | Kabelrudern sitzend | Seated Cable Row | Seated Cable Row |
| `exercise.name.seatedCalfRaise` | Wadenpresse (sitzend) | Seated Calf Press | Seated Calf Press |
| `exercise.name.seatedLegCurl` | Beincurl sitzend | Seated Leg Curl | Oturarak Bacak Curl |
| `exercise.name.shoulderPressMachine` | Schulterdrücken (Maschine) | Machine Shoulder Press | Machine Shoulder Press |
| `exercise.name.sidePlank` | Seitstütz | Side Plank | Side Plank |
| `exercise.name.sissySquat` | Sissy Squats (BW) | Sissy Squat | Sissy Squat |
| `exercise.name.situp` | Sit-ups | Sit-Up | Sit-Up |
| `exercise.name.skullCrusher` | Skull Crusher | Skull Crusher | Skull Crusher |
| `exercise.name.sledPull` | Sled Pull | Sled Pull | Kızak Çekme |
| `exercise.name.sledPush` | Sled Push | Sled Push | Kızak İtme |
| `exercise.name.smithMachineSquat` | Smith Machine Squat | Smith Machine Squat | Smith Machine Squat |
| `exercise.name.snatch` | Reißen (Snatch) | Snatch | Snatch (Koparma) |
| `exercise.name.squat` | Kniebeuge | Back Squat | Back Squat |
| `exercise.name.stairStepper` | Stepper | Stair Stepper | Stepper |
| `exercise.name.standingLegCurl` | Beincurl stehend | Standing Leg Curl | Ayakta Bacak Curl |
| `exercise.name.stationaryBike` | Fahrradergometer | Exercise Bike | Egzersiz Bisikleti |
| `exercise.name.stepUpDB` | Step-Up (KH) | Dumbbell Step-Up | Dumbbell Step-Up |
| `exercise.name.sumoDeadlift` | Sumo-Kreuzheben | Sumo Deadlift | Sumo Deadlift |
| `exercise.name.swimming` | Schwimmen | Swimming | Yüzme |
| `exercise.name.tBarRow` | T-Bar Rudern | T-Bar Row | T-Bar Row |
| `exercise.name.tatePress` | Tate Press | Tate Press | Tate Press |
| `exercise.name.tibialisRaise` | Tibialis Raise | Tibialis Raise | Tibialis Raise |
| `exercise.name.towelRowDoorframe` | Handtuch-Rudern (Türrahmen) | Towel Row (Doorframe) | Towel Row |
| `exercise.name.trapBarDeadlift` | Trap-Bar-Kreuzheben | Trap Bar Deadlift | Trap Bar Deadlift |
| `exercise.name.treadmill` | Laufband | Treadmill | Koşu Bandı |
| `exercise.name.tricepDip` | Dips (Trizeps) | Triceps Dips | Triceps Dips |
| `exercise.name.tricepPushdown` | Trizepsdrücken (Kabel) | Cable Triceps Pushdown | Cable Triceps Pushdown |
| `exercise.name.turkishGetUp` | Turkish Get-Up | Turkish Get-Up | Türk Kalkışı |
| `exercise.name.wallSit` | Wall Sit | Wall Sit | Wall Sit |
| `exercise.name.warmupWalk` | Gehen / Einlaufen | Warm-Up Walk | Isınma Yürüyüşü |
| `exercise.name.widePullup` | Klimmzüge (weit) | Wide-Grip Pull-Up | Wide-Grip Pull-Up |
| `exercise.name.widePushup` | Breite Liegestütze | Wide Push-Up | Wide Push-Up |
| `exercise.name.wristCurl` | Handgelenk-Curl | Wrist Curl | Bilek Curl |
| `exercise.name.zPress` | Z-Press | Z-Press | Z-Press |
| `exercise.name.zercherSquat` | Zercher Squat | Zercher Squat | Zercher Squat |
| `exercise.rest.label` | Pause | Rest | Mola |
| `exercise.target.cardioFormat` | %1$@ • %2$llds %3$@ | %1$@ • %2$llds %3$@ | %1$@ • %2$llds %3$@ |
| `exercise.target.strengthFormat` | %1$lld × %2$@ %3$@ • %4$llds %5$@ | %1$lld × %2$@ %3$@ • %4$llds %5$@ | %1$lld × %2$@ %3$@ • %4$llds %5$@ |

## `experience.*`  (3 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `experience.advanced` | Experte | Advanced | İleri |
| `experience.beginner` | Anfänger | Beginner | Başlangıç |
| `experience.intermediate` | Fortgeschritten | Intermediate | Orta |

## `feeling.*`  (5 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `feeling.destroyed` | Zerstört / Am Limit | Destroyed / At Limit | Bitik / Limitte |
| `feeling.good` | Gut | Good | İyi |
| `feeling.great` | Großartig | Great | Harika |
| `feeling.hard` | Sehr schwer | Very Hard | Çok Zor |
| `feeling.okay` | Okay | Okay | İdare Eder |

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
| `gear.list.empty.cta` | Ausrüstung anlegen | Add Gear | Ekipman Ekle |
| `gear.list.empty.description` | Füge Laufschuhe oder Fahrräder hinzu, damit die App deine Kilometer automatisch trackt. | Add running shoes or bicycles so the app can track your distance automatically. | Koşu ayakkabıları veya bisikletler ekle, böylece uygulama mesafeni otomatik takip etsin. |
| `gear.list.empty.title` | Noch keine Ausrüstung | No gear yet | Henüz ekipman yok |
| `gear.list.footer` | Cardio-Trainings buchen ihre Distanz automatisch auf den im Finish-Sheet ausgewählten Schuh. | Cardio workouts log distance to the shoe selected in the finish sheet. | Kardiyo antrenmanları, bitiş sayfasında seçilen ayakkabıya mesafe ekler. |
| `gear.list.title` | Ausrüstung | Gear | Ekipman |
| `gear.needsReplacement` | Schuh erneuern — Dämpfung erschöpft. | Replace shoe — cushioning depleted. | Ayakkabıyı değiştir — yastıklama tükendi. |

## `goalType.*`  (5 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `goalType.fatloss` | Fett verbrennen | Burn Fat | Yağ Yak |
| `goalType.functional` | Funktionelle Fitness | Functional Fitness | Fonksiyonel Fitness |
| `goalType.hybrid` | Athletisch werden | Become Athletic | Atletik Ol |
| `goalType.hypertrophy` | Muskeln aufbauen | Build Muscle | Kas Yap |
| `goalType.strength` | Maximalkraft | Maximum Strength | Maksimal Güç |

## `heroMetric.*`  (10 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `heroMetric.bmi.label` | BMI | BMI | BMI |
| `heroMetric.bodyFatNavy.label` | KFA (Navy) | Body Fat (Navy) | Yağ Oranı (Navy) |
| `heroMetric.ffmi.label` | FFMI | FFMI | FFMI |
| `heroMetric.hk.permissionNeeded.a11y` | HealthKit-Zugriff benötigt — Doppeltippen um Verbindung zu öffnen. | HealthKit access required — double-tap to open permission prompt. | HealthKit erişimi gerekli — izin penceresini açmak için çift dokun. |
| `heroMetric.leanMass.label` | Magermasse | Lean Mass | Yağsız Kütle |
| `heroMetric.restingHR.label` | Ruhepuls | Resting HR | Dinlenme nabzı |
| `heroMetric.stepsToday.label` | Schritte heute | Steps today | Bugünkü adımlar |
| `heroMetric.waterTodayMl.label` | Wasser heute | Water today | Bugün su |
| `heroMetric.weight.label` | Gewicht | Weight | Ağırlık |
| `heroMetric.workoutsThisWeek.label` | Trainings diese Woche | Workouts this week | Bu haftaki antrenmanlar |

## `history.*`  (4 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `history.early.badge` | VORZEITIG | EARLY | ERKEN |
| `history.empty.description` | Beende dein erstes Training, um deine Historie zu sehen. | Finish your first workout to see your history. | Geçmişini görmek için ilk antrenmanını bitir. |
| `history.empty.title` | Noch keine Trainings | No workouts yet | Henüz antrenman yok |
| `history.session.fallback` | Training | Workout | Antrenman |

## `holdTimer.*`  (1 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `holdTimer.target.format` | Ziel: %lld Sek halten | Target: hold %lld sec | Hedef: %lld sn boyunca tut |

## `import.*`  (18 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `import.file.custom_exercises` | Übungsbibliothek | Exercise library | Egzersiz kütüphanesi |
| `import.file.gear` | Ausrüstung | Gear | Ekipman |
| `import.file.measurements` | Messungen | Measurements | Ölçümler |
| `import.file.personal_records` | Rekorde | Records | Rekorlar |
| `import.file.plan_days` | Trainingstage | Training days | Antrenman günleri |
| `import.file.plan_exercises` | Übungen in Plänen | Exercises in plans | Planlardaki egzersizler |
| `import.file.plans` | Trainingspläne | Training plans | Antrenman planları |
| `import.file.profile` | Profil | Profile | Profil |
| `import.file.settings` | Einstellungen | Settings | Ayarlar |
| `import.file.water_log` | Wasser | Water | Su |
| `import.file.workout_sets` | Sätze | Sets | Setler |
| `import.file.workouts` | Trainings | Workouts | Antrenmanlar |
| `import.preview.activePlanWarning` | Die Datei enthält einen aktiven Trainingsplan. | The file contains an active training plan. | Dosya etkin bir antrenman planı içeriyor. |
| `import.preview.comparison` | %1$lld Datensätze in der Datei · aktuell in der App: %2$lld | %1$lld records in the file · currently in the app: %2$lld | Dosyada %1$lld kayıt · uygulamada şu anda: %2$lld |
| `import.preview.exportedAt` | Erstellt am %@ | Created on %@ | Oluşturulma: %@ |
| `import.preview.restorePointNote` | Vor dem Import sichert Deltiq deinen jetzigen Stand automatisch. Du findest ihn unter Automatische Backups. | Before importing, Deltiq automatically saves your current data. You'll find it under Automatic backups. | İçe aktarmadan önce Deltiq mevcut verilerini otomatik olarak yedekler. Otomatik yedekler altında bulabilirsin. |
| `import.preview.title` | Inhalt der Datei | File contents | Dosya içeriği |
| `import.preview.unreadable` | Diese Datei konnte nicht gelesen werden — sie ist kein gültiges Deltiq-Backup. | This file could not be read — it isn't a valid Deltiq backup. | Bu dosya okunamadı — geçerli bir Deltiq yedeği değil. |

## `library.*`  (5 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `library.newExercise` | Neue Übung | New exercise | Yeni hareket |
| `library.readOnlyFooter` | System-Übung — die Basis-Vorlagen der App sind nicht bearbeitbar. | System exercise — the app's base templates can't be edited. | Sistem hareketi — uygulamanın temel şablonları düzenlenemez. |
| `library.row.history` | Verlauf | History | Geçmiş |
| `library.searchPlaceholder` | Übung suchen | Search exercise | Hareket ara |
| `library.title` | Übungsbibliothek | Exercise Library | Hareket Kütüphanesi |

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
| `measurement.derived.navy.fallback.female` | Hals/Taille/Hüfte erforderlich | Neck/Waist/Hip required | Boyun/Bel/Kalça gerekli |
| `measurement.derived.navy.fallback.male` | Hals/Taille erforderlich | Neck/Waist required | Boyun/Bel gerekli |
| `measurement.derived.navy.label` | KFA Navy | Body Fat (Navy) | Yağ Oranı (Navy) |
| `measurement.empty.description` | Lege erst dein Profil im Onboarding an, danach können wir Messwerte berechnen. | Set up your profile in onboarding first — then we can compute measurements. | Önce onboarding'de profilini oluştur — sonra ölçümleri hesaplayabiliriz. |
| `measurement.empty.title` | Kein Profil | No Profile | Profil Yok |
| `measurement.field.biceps` | Bizeps (cm) | Biceps (cm) | Pazı (cm) |
| `measurement.field.calf` | Wade (cm) | Calf (cm) | Baldır (cm) |
| `measurement.field.chest` | Brust (cm) | Chest (cm) | Göğüs (cm) |
| `measurement.field.hip` | Hüfte (cm) | Hip (cm) | Kalça (cm) |
| `measurement.field.neck` | Halsumfang (cm) | Neck (cm) | Boyun (cm) |
| `measurement.field.shoulder.full` | Schulterumfang (cm) | Shoulder Circumference (cm) | Omuz Çevresi (cm) |
| `measurement.field.shoulder.label` | Schulter (cm) | Shoulder (cm) | Omuz (cm) |
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
| `measurement.profile.age.label` | Alter | Age | Yaş |
| `measurement.profile.age.unit` | Jahre | Years | Yıl |
| `measurement.profile.goalWeight` | Zielgewicht | Goal Weight | Hedef Kilo |
| `measurement.profile.height` | Größe | Height | Boy |
| `measurement.profile.sex.female` | Weiblich | Female | Kadın |
| `measurement.profile.sex.label` | Geschlecht | Sex | Cinsiyet |
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
| `measurement.section.additional.footer` | Diese Werte fließen NICHT in die KFA/Navy-Berechnung — sie dienen deinem persönlichen Progress-Tracking. | These values do NOT feed into the body-fat / Navy calculation — they're for your personal progress tracking. | Bu değerler yağ oranı / Navy hesabına dahil edilmez — sadece kişisel ilerlemeni takip etmen için. |
| `measurement.section.additional.title` | Weitere Umfänge | Additional Measurements | Ek Ölçümler |
| `measurement.section.core.footer.female` | Gewicht, Hals, Taille und Hüfte werden für die Navy-KFA-Berechnung benötigt. | Weight, neck, waist, and hip are required for the Navy body-fat calculation. | Navy yağ oranı hesabı için ağırlık, boyun, bel ve kalça gereklidir. |
| `measurement.section.core.footer.male` | Gewicht, Hals und Taille werden für die Navy-KFA-Berechnung benötigt. Schulter optional für das Schulter-zu-Taillen-Verhältnis. | Weight, neck, and waist are required for the Navy body-fat calculation. Shoulder is optional for the shoulder-to-waist ratio. | Navy yağ oranı hesabı için ağırlık, boyun ve bel gereklidir. Omuz, omuz-bel oranı için isteğe bağlıdır. |
| `measurement.section.core.title` | Pflichtwerte | Required Values | Zorunlu Değerler |
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

## `metric.*`  (1 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `metric.weeklyDelta.suffix` | / Wo. | / wk. | / hf. |

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

## `muscleVolume.*`  (4 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `muscleVolume.bucket.maintenance` | Erhalt | Maintenance | Koruma |
| `muscleVolume.bucket.optimal` | Optimal | Optimal | Optimal |
| `muscleVolume.bucket.overreaching` | Übervolumen | Overreach | Aşırı yük |
| `muscleVolume.bucket.untrained` | Untrainiert | Untrained | Eğitilmemiş |

## `onboarding.*`  (53 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `onboarding.body.weightInitial` | Wird im Hintergrund als initiale Messung gespeichert. | Saved in the background as your initial measurement. | Arka planda ilk ölçüm olarak kaydedilir. |
| `onboarding.body.weightRequired` | Pflichtfeld — wird als erste Messung gespeichert. | Required — saved as your first measurement. | Zorunlu — ilk ölçüm olarak kaydedilir. |
| `onboarding.body.weightZero` | Gewicht muss > 0 sein. | Weight must be > 0. | Kilo > 0 olmalı. |
| `onboarding.environment.footnote1` | Trainingsort filtert Plan-Empfehlungen und die Equipment-Auswahl beim Übungs-Tausch. | Training location filters plan recommendations and equipment options when swapping exercises. | Antrenman yeri plan önerilerini ve hareket değiştirirken ekipman seçeneklerini filtreler. |
| `onboarding.environment.footnote2` | Hybrid- oder reine Lauf-Athleten wählen ihren Strength-Ort — die Hybrid-Pläne enthalten ihre Run-Tage unabhängig davon. | Hybrid or pure running athletes pick their strength location — Hybrid plans include run days regardless. | Hibrit veya saf koşu sporcuları güç antrenman yerini seçer — Hibrit planlar koşu günlerini her durumda içerir. |
| `onboarding.equipment.footer` | Du kannst diese Auswahl später jederzeit im Profil anpassen. Leer lassen = Standard-Variante (Langhantel) wird verwendet. | You can change this anytime in your profile. Leave empty = default variant (barbell) is used. | Bu seçimi profilden istediğin zaman değiştirebilirsin. Boş bırakırsan varsayılan (barbell) kullanılır. |
| `onboarding.equipment.subtitle` | Bestimmt, welche Geräte-Variante dein Trainingsplan nutzt — z. B. Kurzhantel- statt Langhantel-Übungen, wenn du kein Rack hast. | Determines which equipment variant your training plan uses — e.g. dumbbell instead of barbell exercises if you have no rack. | Antrenman planının hangi ekipman varyantını kullanacağını belirler — örneğin rack yoksa halter yerine dambıl egzersizleri. |
| `onboarding.equipment.title` | Womit trainierst du? | What do you train with? | Hangi ekipmanla çalışıyorsun? |
| `onboarding.field.birthdate` | Geburtsdatum | Birth date | Doğum Tarihi |
| `onboarding.field.environment` | Trainingsort | Training Location | Antrenman Yeri |
| `onboarding.field.firstName` | Vorname | First Name | Ad |
| `onboarding.field.firstNameFooter` | Optional — du kannst das Feld auch leer lassen. | Optional — you can leave this empty. | İsteğe bağlı — boş bırakabilirsin. |
| `onboarding.field.firstNamePlaceholder` | Wie dürfen wir dich nennen? | What should we call you? | Sana nasıl hitap edelim? |
| `onboarding.field.goalWeightKg` | Zielgewicht (kg, optional) | Goal Weight (kg, optional) | Hedef Kilo (kg, opsiyonel) |
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
| `onboarding.import.button` | Backup importieren (ZIP) | Import backup (ZIP) | Yedeği içe aktar (ZIP) |
| `onboarding.import.prompt` | Schon Deltiq-Nutzer? Stelle deine Daten aus einer Backup-Datei wieder her. | Already a Deltiq user? Restore your data from a backup file. | Zaten Deltiq kullanıcısı mısın? Verilerini bir yedek dosyasından geri yükle. |
| `onboarding.import.running` | Stelle deine Daten wieder her… | Restoring your data… | Verilerin geri yükleniyor… |
| `onboarding.nav.finish` | Fertig | Finish | Bitir |
| `onboarding.nav.next` | Weiter | Next | İleri |
| `onboarding.notif.footnote` | Beide nutzen lokale Notifications. Beim Aktivieren fragt iOS einmalig nach der Berechtigung. | Both use local notifications. iOS asks once for permission when enabled. | Her ikisi de yerel bildirimleri kullanır. Etkinleştirildiğinde iOS bir kez izin ister. |
| `onboarding.notif.measurement` | Mess-Erinnerung | Measurement Reminder | Ölçüm Hatırlatıcısı |
| `onboarding.notif.section` | Benachrichtigungen | Notifications | Bildirimler |
| `onboarding.notif.water` | Wasser-Erinnerung | Water Reminder | Su Hatırlatıcısı |
| `onboarding.plan.footnote` | Templates sind nach deinem Trainingsort gefiltert (%@). Auch ohne Plan starten ist okay. | Templates are filtered by your training location (%@). Starting without a plan is fine too. | Şablonlar antrenman yerine göre filtrelendi (%@). Plansız başlamak da mümkün. |
| `onboarding.plan.goalMatch` | Passt zu deinem Ziel | Matches your goal | Hedefine uygun |
| `onboarding.plan.noTemplates` | Keine Templates für '%@'. Du kannst trotzdem ohne Plan starten und später einen eigenen anlegen. | No templates for '%@'. You can still start without a plan and create your own later. | '%@' için şablon yok. Plansız başlayıp sonradan kendi planını oluşturabilirsin. |
| `onboarding.plan.quizCard.footnote` | Empfohlen, wenn du nicht weißt, welcher Plan zu dir passt. Du kannst stattdessen auch direkt aus der Liste unten wählen. | Recommended if you're not sure which plan fits. You can also pick directly from the list below. | Hangi planın sana uygun olduğundan emin değilsen önerilir. Aşağıdaki listeden de doğrudan seçebilirsin. |
| `onboarding.plan.quizCard.subtitle` | 4 kurze Fragen — wir matchen dich auf den passenden Plan. | 4 quick questions — we match you to the right plan. | 4 kısa soru — sana uygun planı eşleştiririz. |
| `onboarding.plan.quizCard.title` | Plan finden lassen | Find a Plan | Plan Bul |
| `onboarding.plan.recommended` | Empfohlen | Recommended | Önerilen |
| `onboarding.plan.section` | Trainingsplan für %@ | Plans for %@ | %@ için Plan |
| `onboarding.section.body` | Körpermaße | Body Measurements | Vücut Ölçüleri |
| `onboarding.section.goals` | Ziel & Training | Goals & Training | Hedef & Antrenman |
| `onboarding.section.name` | Dein Name | Your Name | Adın |
| `onboarding.section.profile` | Profil | Profile | Profil |
| `onboarding.title` | Willkommen | Welcome | Hoş Geldin |
| `onboarding.tone.subtitle` | Wir passen Tonfall und Feedback an deinen Stil an. Lässt sich später ändern. | We adapt tone and feedback to your style. Changeable later. | Ton ve geri bildirimi tarzına uyarlarız. Sonradan değiştirilebilir. |
| `onboarding.tone.title` | Wie soll dein Coach klingen? | How should your coach sound? | Koçun nasıl bir ses tonu olsun? |
| `onboarding.weeklyGoal.subtitle` | Wie oft willst du pro Woche trainieren? Dein Kalender-Streak zählt gegen dieses Ziel — wähle, was du wirklich durchhalten kannst. | How often do you want to train per week? Your calendar streak counts against this — pick what you can actually sustain. | Haftada kaç kez antrenman yapmak istiyorsun? Takvim serin bu hedefe göre sayılır — gerçekten sürdürebileceğini seç. |
| `onboarding.weeklyGoal.title` | Dein Wochenziel | Your weekly goal | Haftalık hedefin |

## `picker.*`  (13 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `picker.exercise.customBadge` | Custom | Custom | Özel |
| `picker.exercise.filter.button.a11y` | Filter öffnen | Open filters | Filtreleri aç |
| `picker.exercise.filter.reset` | Filter zurücksetzen | Reset filters | Filtreleri sıfırla |
| `picker.exercise.filter.section.equipment` | Gerät | Equipment | Ekipman |
| `picker.exercise.filter.section.muscle` | Muskelgruppe | Muscle Group | Kas Grubu |
| `picker.exercise.filter.title` | Filter | Filter | Filtre |
| `picker.exercise.filterFor` | Nur Übungen für %@ | Only %@ exercises | Sadece %@ hareketleri |
| `picker.exercise.filterHint` | Wenn aus, siehst du auch Übungen, die zu deinem Plan-Typ nicht passen. Die App fragt dann beim Hinzufügen nach, ob du den Plan umstellen willst. | When off, you also see exercises that don't fit your plan type. The app asks when adding whether to switch the plan. | Kapalıyken plan tipine uymayan hareketleri de görürsün. Eklerken plan değişimi sorulur. |
| `picker.exercise.namePlaceholder` | Name (z.B. Bankdrücken) | Name (e.g. Bench Press) | Ad (örn. Bench Press) |
| `picker.exercise.section.customs` | Eigene | Custom | Özel |
| `picker.plan.adoptFootnote` | Beim Übernehmen wird eine Tiefkopie für deine eigene Bibliothek angelegt — Tage, Übungen, Sätze sind danach frei editierbar. | Adopting creates a deep copy in your library — days, exercises, and sets are then freely editable. | Plan alındığında kütüphanende derin kopya oluşturulur — günler, hareketler ve setler özgürce düzenlenebilir. |
| `picker.plan.filterFootnote` | Gefiltert nach deinem Trainingsort (%@). Im Profil anpassen, wenn du auch andere Pläne sehen willst. | Filtered by your training location (%@). Adjust in profile to see other plans. | Antrenman yerine göre filtrelendi (%@). Diğer planları görmek için profilden ayarla. |
| `picker.plan.title` | Programm wählen | Choose Program | Program Seç |

## `plan.*`  (141 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `plan.day.arms` | Arme | Arms | Kol |
| `plan.day.back` | Rücken | Back | Sırt |
| `plan.day.benchDay` | Tag 2 – Bankdrück-Tag | Day 2 - Bench Day | Gün 2 - Bench Günü |
| `plan.day.chest` | Brust | Chest | Göğüs |
| `plan.day.chestBackA` | Brust & Rücken A | Chest & Back A | Göğüs & Sırt A |
| `plan.day.chestBackB` | Brust & Rücken B | Chest & Back B | Göğüs & Sırt B |
| `plan.day.cindyRx` | Cindy | Cindy | Cindy |
| `plan.day.cindyScaled` | Cindy (Scaled) | Cindy (Scaled) | Cindy (Scaled) |
| `plan.day.crossfitWeightedAmrap` | Grundlagen-AMRAP | Foundations AMRAP | Temel AMRAP |
| `plan.day.crossfitWeightedEmom` | EMOM Ganzkörper | EMOM Full Body | EMOM Tüm Vücut |
| `plan.day.crossfitWeightedForTime` | Auf Zeit: Thruster & Burpees | For Time: Thrusters & Burpees | Süreye Karşı: Thruster & Burpee |
| `plan.day.deadliftDay` | Tag 3 – Kreuzhebe-Tag | Day 3 - Deadlift Day | Gün 3 - Deadlift Günü |
| `plan.day.easyRun` | Easy Run | Easy Run | Kolay Koşu |
| `plan.day.emomIntensityRx` | EMOM Intensität | EMOM Intensity | EMOM Yoğunluk |
| `plan.day.emomIntensityScaled` | EMOM Intensität (Scaled) | EMOM Intensity (Scaled) | EMOM Yoğunluk (Scaled) |
| `plan.day.fatBurnA` | Cut A | Cut A | Cut A |
| `plan.day.fatBurnB` | Cut B | Cut B | Cut B |
| `plan.day.fatBurnC` | Cut C | Cut C | Cut C |
| `plan.day.forTimeSitupsSquatsRx` | Auf Zeit: Sit-ups & Squats | For Time: Sit-ups & Squats | Süreye Karşı: Mekik & Squat |
| `plan.day.forTimeSitupsSquatsScaled` | Auf Zeit: Sit-ups & Squats (Scaled) | For Time: Sit-ups & Squats (Scaled) | Süreye Karşı: Mekik & Squat (Scaled) |
| `plan.day.fullBodyA` | Ganzkörper A | Full Body A | Tüm Vücut A |
| `plan.day.fullBodyB` | Ganzkörper B | Full Body B | Tüm Vücut B |
| `plan.day.fullBodyC` | Ganzkörper C | Full Body C | Tüm Vücut C |
| `plan.day.fullBodyHIIT` | Ganzkörper HIIT | Full Body HIIT | Tüm Vücut HIIT |
| `plan.day.intervals` | Intervalle | Intervals | İnterval |
| `plan.day.kbFoundationsCircuit` | Grundlagen-Zirkel | Foundations Circuit | Temel Devre |
| `plan.day.kbHeavyPullEmom` | Heavy Pull: EMOM Snatch | Heavy Pull: EMOM Snatch | Ağır Çekiş: EMOM Snatch |
| `plan.day.kbHeavyPushSquat` | Heavy Push & Squat | Heavy Push & Squat | Ağır İtme & Squat |
| `plan.day.kbMetcon` | Metabolic Conditioning | Metabolic Conditioning | Metabolik Kondisyon |
| `plan.day.kbPushPullCore` | Push, Pull & Core | Push, Pull & Core | İtme, Çekme & Core |
| `plan.day.kbSwingEndurance` | Schwung & Ausdauer | Swing & Endurance | Salınım & Dayanıklılık |
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
| `plan.day.workoutA` | Training A | Workout A | Antrenman A |
| `plan.day.workoutB` | Training B | Workout B | Antrenman B |
| `plan.dayNumberLabel` | Tag %lld | Day %lld | Gün %lld |
| `plan.dayRow.exerciseCount` | %1$lld Übungen • %2$@ | %1$lld exercises • %2$@ | %1$lld hareket • %2$@ |
| `plan.metadata.days.one` | %lld Tag | %lld day | %lld gün |
| `plan.metadata.days.other` | %lld Tage | %lld days | %lld gün |
| `plan.metadata.weeks.one` | %lld Woche | %lld week | %lld hafta |
| `plan.metadata.weeks.other` | %lld Wochen | %lld weeks | %lld hafta |
| `plan.template.arnoldSplit.description` | Arnold Schwarzeneggers Trainingsansatz: Antagonisten (Brust+Rücken) werden gemeinsam trainiert für maximalen Pump und Dichte. | Arnold Schwarzenegger's training approach: antagonist muscles (chest + back) are trained together for maximum pump and density. | Arnold Schwarzenegger'in antrenman yaklaşımı: antagonist kaslar (göğüs + sırt) maksimum pump ve yoğunluk için birlikte çalıştırılır. |
| `plan.template.arnoldSplit.focus` | Hypertrophie | Hypertrophy | Hipertrofi |
| `plan.template.arnoldSplit.name` | Arnold Split | Arnold Split | Arnold Split |
| `plan.template.arnoldSplit.tagline` | 6 Tage · Bodybuilding | 6 Days · Bodybuilding | 6 Gün · Vücut Geliştirme |
| `plan.template.bodyweightMastery.description` | Komplettes Körpergewichtstraining ohne ein einziges Gerät. Kürzere Pausen und isometrische Übungen sorgen für maximalen Trainingsreiz. | Complete bodyweight training without a single piece of equipment. Shorter rest periods and isometric exercises maximize training stimulus. | Tek bir ekipman olmadan komple vücut ağırlığı antrenmanı. Kısa molalar ve izometrik hareketler maksimum antrenman uyarısı sağlar. |
| `plan.template.bodyweightMastery.focus` | Funktionelle Fitness | Functional Fitness | Fonksiyonel Fitness |
| `plan.template.bodyweightMastery.name` | Bodyweight Mastery | Bodyweight Mastery | Bodyweight Mastery |
| `plan.template.bodyweightMastery.tagline` | 3 Tage · Funktionelles Training ohne Geräte | 3 Days · Functional Training, No Equipment | 3 Gün · Ekipmansız Fonksiyonel Antrenman |
| `plan.template.broSplit.description` | Klassischer Bodybuilding-Split mit hohem Volumen pro Muskelgruppe. Jede Muskelgruppe wird einmal pro Woche mit maximaler Erschöpfung trainiert. | Classic bodybuilding split with high volume per muscle group. Each muscle group is trained once per week to maximum exhaustion. | Kas grubu başına yüksek hacimli klasik vücut geliştirme bölünmesi. Her kas grubu haftada bir kez maksimum yorgunluğa kadar çalıştırılır. |
| `plan.template.broSplit.focus` | Hypertrophie | Hypertrophy | Hipertrofi |
| `plan.template.broSplit.name` | Bro-Split | Bro-Split | Bro-Split |
| `plan.template.broSplit.tagline` | 5 Tage · Hypertrophie | 5 Days · Hypertrophy | 5 Gün · Hipertrofi |
| `plan.template.crossfitBodyweightRx.description` | Benchmark-WODs nur mit Körpergewicht: ein 20-Minuten-AMRAP, ein Intensitäts-EMOM und eine Auf-Zeit-Rundenleiter. Volle Rx-Bewegungen — Klimmzüge, Liegestütze, Air Squats. | Benchmark WODs using bodyweight only: a 20-minute AMRAP, an intensity EMOM, and a for-time round ladder. Full Rx movements — pull-ups, push-ups, air squats. | Sadece vücut ağırlığıyla ölçüt WOD'ları: 20 dakikalık bir AMRAP, bir yoğunluk EMOM'u ve süreye karşı bir tur merdiveni. Tam Rx hareketleri — barfiks, şınav, hava squat. |
| `plan.template.crossfitBodyweightRx.focus` | CrossFit & Kettlebell | CrossFit & Kettlebell | CrossFit & Kettlebell |
| `plan.template.crossfitBodyweightRx.name` | CrossFit Bodyweight (Rx) | CrossFit Bodyweight (Rx) | CrossFit Bodyweight (Rx) |
| `plan.template.crossfitBodyweightRx.tagline` | 3 Tage · Klassische Bodyweight-WODs | 3 days · Classic bodyweight WODs | 3 gün · Klasik vücut ağırlığı WOD'ları |
| `plan.template.crossfitBodyweightScaled.description` | Dieselben Benchmark-WODs wie Rx, mit Einsteiger-Bewegungen: Handtuch-Rudern statt Klimmzüge, Liegestütze auf den Knien und eine kürzere Rundenleiter. | The same benchmark WODs as Rx, with beginner-friendly movements: towel rows instead of pull-ups, knee push-ups, and a shorter round ladder. | Rx ile aynı ölçüt WOD'ları, başlangıç seviyesi hareketlerle: barfiks yerine havlu çekişi, dizde şınav ve daha kısa bir tur merdiveni. |
| `plan.template.crossfitBodyweightScaled.focus` | CrossFit & Kettlebell | CrossFit & Kettlebell | CrossFit & Kettlebell |
| `plan.template.crossfitBodyweightScaled.name` | CrossFit Bodyweight (Scaled) | CrossFit Bodyweight (Scaled) | CrossFit Bodyweight (Scaled) |
| `plan.template.crossfitBodyweightScaled.tagline` | 3 Tage · Bodyweight-WODs, Einsteiger-Varianten | 3 days · Bodyweight WODs, beginner variations | 3 gün · Vücut ağırlığı WOD'ları, başlangıç seviyesi varyasyonlar |
| `plan.template.crossfitWeighted.description` | Metcon-Workouts mit Zusatzgewicht statt reinem Körpergewicht — die Schwierigkeit steuerst du über das Gewicht, nicht über die Bewegung. Für Einsteiger und Fortgeschrittene. | Metcon workouts with added weight instead of pure bodyweight — you control the difficulty through the load, not the movement. For beginners and advanced athletes alike. | Salt vücut ağırlığı yerine ek yüklü metcon antrenmanları — zorluğu hareketle değil ağırlıkla ayarlarsın. Hem başlangıç hem ileri seviye için. |
| `plan.template.crossfitWeighted.focus` | CrossFit & Kettlebell | CrossFit & Kettlebell | CrossFit & Kettlebell |
| `plan.template.crossfitWeighted.name` | CrossFit mit Gewichten | CrossFit with Weights | Ağırlıklarla CrossFit |
| `plan.template.crossfitWeighted.tagline` | 3 Tage · Funktionelle WODs mit Kurzhantel/Kettlebell | 3 days · Functional WODs with dumbbell/kettlebell | 3 gün · Dambıl/kettlebell ile fonksiyonel WOD'lar |
| `plan.template.fatBurnFullBody.description` | Fettverlust kommt aus dem Kaloriendefizit — dieser Plan schützt Muskel und Kraft im Cut: solides Hypertrophie-Volumen bei moderaten Lasten plus ein Cardio-Finisher pro Einheit. Reps und Pausen folgen Standard-Hypertrophie (6–12 bzw. 8–15, 60–180 s Pause), kein 'hohe Wdh = Fett weg'-Mythos. | Fat loss comes from the calorie deficit — this plan preserves muscle and strength during the cut: solid hypertrophy volume at moderate loads plus a cardio finisher per session. Reps and rest follow standard hypertrophy (6–12 or 8–15, 60–180 s rest); no 'high reps melt fat' myth. | Yağ kaybı kalori açığından gelir — bu plan diyet sırasında kası ve kuvveti korur: orta yüklerde sağlam hipertrofi hacmi artı her seansta bir kardiyo finisher. Tekrar ve dinlenme standart hipertrofiye uyar (6–12 ya da 8–15, 60–180 sn dinlenme); 'yüksek tekrar = yağ erir' miti yok. |
| `plan.template.fatBurnFullBody.focus` | Defizit-Phase | Cut Phase | Cut Fazı |
| `plan.template.fatBurnFullBody.name` | Cut-Phase Ganzkörper | Cut Phase Full Body | Cut Fazı – Tüm Vücut |
| `plan.template.fatBurnFullBody.tagline` | 3 Tage · Muskelerhalt im Defizit | 3 Days · Muscle retention in a deficit | 3 Gün · Açıkta kas koruma |
| `plan.template.footballAthletic.description` | Athletik-Programm für Mannschaftssportler: Maximalkraft und Schnellkraft in zwei kompakten Einheiten pro Woche — ideal als Ergänzung zum Vereinstraining. | Athletics program for team-sport athletes: maximum strength and power in two compact sessions per week — ideal as a complement to club training. | Takım sporcuları için atletik program: haftada iki kompakt seansta maksimum güç ve patlayıcı kuvvet — kulüp antrenmanına ideal tamamlayıcı. |
| `plan.template.footballAthletic.focus` | Athletik | Athletics | Atletik |
| `plan.template.footballAthletic.name` | Fussball Athletik | Football Athletic | Futbol Atletik |
| `plan.template.footballAthletic.tagline` | 2 Tage · Kraft & Explosivität | 2 Days · Strength & Explosiveness | 2 Gün · Güç & Patlayıcılık |
| `plan.template.fullBody3x.description` | Höchste Trainingsfrequenz pro Muskelgruppe. Laut Forschung optimal für Anfänger und Wiedereinstieg — maximales Signal für Muskelwachstum. | Highest training frequency per muscle group. Research-backed as optimal for beginners and re-entry — maximum signal for muscle growth. | Kas grubu başına en yüksek antrenman frekansı. Araştırmalar başlangıç ve yeniden başlama için ideal olduğunu gösteriyor — kas gelişimi için maksimum sinyal. |
| `plan.template.fullBody3x.focus` | Anfänger / Allgemein | Beginner / General | Başlangıç / Genel |
| `plan.template.fullBody3x.name` | Ganzkörper 3x | Full Body 3x | Tüm Vücut 3x |
| `plan.template.fullBody3x.tagline` | 3 Tage · Anfänger & Re-Einstieg | 3 Days · Beginner & Re-Entry | 3 Gün · Başlangıç & Yeniden Başlama |
| `plan.template.homeGymHero.description` | Effektiver Ganzkörperplan komplett mit Kurzhanteln. Ideal für das Training zuhause — kein Fitnessstudio nötig. | Effective full-body plan using only dumbbells. Ideal for training at home — no gym required. | Sadece dambıllarla etkili tüm vücut planı. Evde antrenman için ideal — salon gerekmez. |
| `plan.template.homeGymHero.focus` | Hypertrophie | Hypertrophy | Hipertrofi |
| `plan.template.homeGymHero.name` | Home Gym Hero | Home Gym Hero | Home Gym Hero |
| `plan.template.homeGymHero.tagline` | 3 Tage · Muskelaufbau mit Kurzhanteln | 3 Days · Muscle Building with Dumbbells | 3 Gün · Dambıl ile Kas Gelişimi |
| `plan.template.hybridBalanced.description` | Drei fokussierte Strength-Einheiten (Push/Pull/Legs-Light) plus zwei strategisch platzierte Lauf-Tage. RIR-Puffer 2–3 verhindert systemische Erschöpfung — bleibt Trainings-vertrāglich. | Three focused strength sessions (Push/Pull/Legs-Light) plus two strategically placed run days. RIR buffer of 2–3 prevents systemic fatigue — stays training-compatible. | Üç odaklı güç seansı (Push/Pull/Hafif Bacak) artı iki stratejik konumlandırılmış koşu günü. RIR tamponu 2–3 sistemik yorgunluğu önler — antrenmana uyumlu kalır. |
| `plan.template.hybridBalanced.focus` | Hybrid & Athletik | Hybrid & Athletics | Hibrit & Atletik |
| `plan.template.hybridBalanced.name` | Hybrid Athlete — Balanced | Hybrid Athlete — Balanced | Hybrid Athlete — Balanced |
| `plan.template.hybridBalanced.tagline` | 5 Tage · Kraft + Ausdauer in Balance | 5 Days · Strength + Endurance Balanced | 5 Gün · Güç + Dayanıklılık Dengesi |
| `plan.template.hybridBeginner.description` | Concurrent-Training light: zwei Ganzkörper-Strength-Einheiten + zwei lockere Lauf-Tage pro Woche. RIR-Puffer schützt den Laufmotor, kein zerstörendes Versagens-Training. | Concurrent training light: two full-body strength sessions + two easy run days per week. RIR buffer protects the running engine — no destructive failure training. | Hafif eşzamanlı antrenman: haftada iki tüm vücut güç seansı + iki kolay koşu günü. RIR tamponu koşu motorunu korur — yıkıcı başarısızlık antrenmanı yok. |
| `plan.template.hybridBeginner.focus` | Hybrid & Athletik | Hybrid & Athletics | Hibrit & Atletik |
| `plan.template.hybridBeginner.name` | Hybrid Athlete — Beginner | Hybrid Athlete — Beginner | Hybrid Athlete — Beginner |
| `plan.template.hybridBeginner.tagline` | 4 Tage · Kraft + Laufen Einstieg | 4 Days · Strength + Running Intro | 4 Gün · Güç + Koşuya Giriş |
| `plan.template.hybridPerformance.description` | Sechs Trainingstage: drei Strength-Einheiten (Push/Pull/Legs) + drei Läufe (Easy, Intervalle, Long Run). Strength-RIR konservativ 2.5, damit der Gesamt-Volumen-Stress trainings-vertraglich bleibt. | Six training days: three strength sessions (Push/Pull/Legs) + three runs (Easy, Intervals, Long Run). Conservative RIR of 2.5 on strength to keep total volume stress training-compatible. | Altı antrenman günü: üç güç seansı (Push/Pull/Bacak) + üç koşu (Kolay, İnterval, Uzun Koşu). Toplam hacim stresinin antrenmana uyumlu kalması için güçte ihtiyatlı RIR 2.5. |
| `plan.template.hybridPerformance.focus` | Hybrid & Athletik | Hybrid & Athletics | Hibrit & Atletik |
| `plan.template.hybridPerformance.name` | Hybrid Athlete — Performance | Hybrid Athlete — Performance | Hybrid Athlete — Performance |
| `plan.template.hybridPerformance.tagline` | 6 Tage · Wettkampf-Hybrid | 6 Days · Competitive Hybrid | 6 Gün · Rekabetçi Hibrit |
| `plan.template.kettlebellAdvanced.description` | Komplexe Kettlebell-Lifts (Snatch, Clean & Press) für erfahrene Trainierende, ergänzt von einem 20-Minuten-Metcon. Plane zwischen den Einheiten einen Tag aktiver Erholung ein. | Complex kettlebell lifts (snatch, clean & press) for experienced athletes, rounded off with a 20-minute metcon. Plan a day of active recovery between sessions. | Deneyimli sporcular için karmaşık kettlebell hareketleri (snatch, clean & press), 20 dakikalık bir metconla tamamlanır. Seanslar arasında bir aktif toparlanma günü planla. |
| `plan.template.kettlebellAdvanced.focus` | CrossFit & Kettlebell | CrossFit & Kettlebell | CrossFit & Kettlebell |
| `plan.template.kettlebellAdvanced.name` | Kettlebell Fortgeschritten | Kettlebell Advanced | İleri Seviye Kettlebell |
| `plan.template.kettlebellAdvanced.tagline` | 3 Trainingstage · Maximalkraft, Explosivität, Metcon | 3 training days · Maximal strength, explosiveness, metcon | 3 antrenman günü · Maksimal kuvvet, patlayıcılık, metcon |
| `plan.template.kettlebellBeginner.description` | Einstieg ins Kettlebell-Training: saubere Grundtechnik bei Deadlift, Goblet Squat und Swing, ergänzt von einem AMRAP-Finisher zum Rundenaufbau. | Your entry into kettlebell training: clean technique on deadlifts, goblet squats and swings, rounded off with an AMRAP finisher to build round count. | Kettlebell antrenmanına giriş: deadlift, goblet squat ve swing'de temiz teknik, tur sayısı oluşturmak için bir AMRAP bitiricisiyle tamamlanır. |
| `plan.template.kettlebellBeginner.focus` | CrossFit & Kettlebell | CrossFit & Kettlebell | CrossFit & Kettlebell |
| `plan.template.kettlebellBeginner.name` | Kettlebell Grundlagen | Kettlebell Fundamentals | Kettlebell Temelleri |
| `plan.template.kettlebellBeginner.tagline` | 3 Tage · Technik, Kraftausdauer, Stabilität | 3 days · Technique, strength endurance, stability | 3 gün · Teknik, kuvvet dayanıklılığı, stabilite |
| `plan.template.powerlifting3x5.description` | Dreier-Frequenz auf die Grundübungen Kniebeuge, Bankdrücken und Kreuzheben. Jede Session dreht sich um eine primäre Wettkampfübung mit schweren 3x5-Sätzen. | Triple frequency on the core lifts: squat, bench press, and deadlift. Each session focuses on one primary competition lift with heavy 3x5 sets. | Temel hareketler (squat, bench press, deadlift) için üçlü frekans. Her seans ağır 3x5 setleriyle bir ana yarışma hareketine odaklanır. |
| `plan.template.powerlifting3x5.focus` | Kraft | Strength | Güç |
| `plan.template.powerlifting3x5.name` | Powerlifting 3x5 | Powerlifting 3x5 | Powerlifting 3x5 |
| `plan.template.powerlifting3x5.tagline` | 3 Tage · Maximalkraft | 3 Days · Maximum Strength | 3 Gün · Maksimal Güç |
| `plan.template.powerlifting5x5.description` | Das bewährteste Kraft-Programm für Anfänger & Fortgeschrittene. Progressive Überlastung mit den Grundübungen — wissenschaftlich und praktisch belegt. | The most proven strength program for beginners and intermediates. Progressive overload with the main lifts — scientifically and practically validated. | Başlangıç ve orta seviye için en kanıtlanmış güç programı. Temel hareketlerle aşamalı yüklenme — bilimsel ve pratik olarak doğrulanmış. |
| `plan.template.powerlifting5x5.focus` | Kraft | Strength | Güç |
| `plan.template.powerlifting5x5.name` | Powerlifting 5x5 | Powerlifting 5x5 | Powerlifting 5x5 |
| `plan.template.powerlifting5x5.tagline` | 3 Tage · Kraft & Masse | 3 Days · Strength & Mass | 3 Gün · Güç & Kütle |
| `plan.template.pushPullLegs.description` | Wissenschaftlich optimierter Split. Jede Muskelgruppe wird 2x pro Woche trainiert – ideal für intermediäre Sportler laut Meta-Analysen. | Scientifically optimized split. Each muscle group trained 2x per week — ideal for intermediate lifters per meta-analyses. | Bilimsel olarak optimize edilmiş split. Her kas grubu haftada 2 kez çalıştırılır — meta-analizlere göre orta seviye sporcular için ideal. |
| `plan.template.pushPullLegs.focus` | Hypertrophie | Hypertrophy | Hipertrofi |
| `plan.template.pushPullLegs.name` | Push-Pull-Legs | Push-Pull-Legs | Push-Pull-Legs |
| `plan.template.pushPullLegs.tagline` | 6 Tage · Hypertrophie + Kraft | 6 Days · Hypertrophy + Strength | 6 Gün · Hipertrofi + Güç |
| `plan.template.upperLower.description` | Optimale Balance zwischen Frequenz und Volumen. Laut Studienlage der effektivste Split für Kraft- und Muskelaufbau bei Intermediären. | Optimal balance between frequency and volume. Studies show this is the most effective split for strength and muscle building at the intermediate level. | Frekans ve hacim arasında optimal denge. Çalışmalar bunun orta seviyede güç ve kas gelişimi için en etkili split olduğunu gösteriyor. |
| `plan.template.upperLower.focus` | Kraft + Hypertrophie | Strength + Hypertrophy | Güç + Hipertrofi |
| `plan.template.upperLower.name` | Upper-Lower-Split | Upper-Lower Split | Upper-Lower Split |
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
| `planEditor.progressRIR.auto` | Auto (pro Übung) | Auto (per exercise) | Otomatik (hareket başına) |
| `planEditor.progressRIR.label` | Progressions-Ziel-RIR | Progression Target RIR | İlerleme Hedef RIR |
| `planEditor.progressRIR.rir0` | RIR ≤ 0 (zum Versagen) | RIR ≤ 0 (to failure) | RIR ≤ 0 (yenilgiye) |
| `planEditor.progressRIR.rir1` | RIR ≤ 1 | RIR ≤ 1 | RIR ≤ 1 |
| `planEditor.progressRIR.rir2` | RIR ≤ 2 | RIR ≤ 2 | RIR ≤ 2 |
| `planEditor.progressRIR.rir3` | RIR ≤ 3 | RIR ≤ 3 | RIR ≤ 3 |
| `planEditor.section.info` | Plan-Info | Plan Info | Plan Bilgisi |
| `planEditor.section.settings` | Einstellungen | Settings | Ayarlar |
| `planEditor.section.trainingDays` | Trainings-Tage | Training Days | Antrenman Günleri |
| `planEditor.template.banner.subtitle` | Struktur ist festgelegt. Du kannst Trainingsort und Wochen anpassen, aber Name/Tage/Übungen nicht ändern. | Structure is fixed. You can adjust training location and weeks, but not name/days/exercises. | Yapı sabit. Antrenman yerini ve haftaları ayarlayabilirsin ama ad/günler/hareketleri değiştiremezsin. |
| `planEditor.template.banner.title` | Template-Plan | Template Plan | Şablon Plan |
| `planEditor.toggle.setActive` | Als aktiven Plan setzen | Set as Active Plan | Aktif Plan Olarak Ayarla |

## `plans.*`  (14 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `plans.active.fallbackName` | Training läuft | Workout in progress | Antrenman devam ediyor |
| `plans.active.hint` | Tippe auf das Banner, um mit der Session weiterzumachen oder sie zu beenden. | Tap the banner to resume or end the session. | Banner'a dokunarak oturuma devam et veya bitir. |
| `plans.active.startedAt` | Gestartet %@ | Started %@ | %@ başladı |
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

## `pr.*`  (11 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `pr.kind.bestSet` | Neuer Bestsatz (Volumen) | New best set (volume) | Yeni en iyi set (hacim) |
| `pr.kind.estimated1RM` | Neuer 1RM (geschätzt) | New 1RM (estimated) | Yeni 1TM (tahmini) |
| `pr.kind.fastestPace` | Neue Best-Pace | New best pace | Yeni en iyi tempo |
| `pr.kind.fastestTime` | Neue WOD-Bestzeit | New WOD best time | Yeni WOD en iyi süresi |
| `pr.kind.heaviestWeight` | Neues Maximalgewicht | New max weight | Yeni maksimum ağırlık |
| `pr.kind.longestDistance` | Längste Distanz | Longest distance | En uzun mesafe |
| `pr.kind.maxHoldSeconds` | Neue Bestzeit | New best time | Yeni en iyi süre |
| `pr.kind.maxReps` | Neuer Reps-Rekord | New reps record | Yeni tekrar rekoru |
| `pr.kind.mostRounds` | Neue Bestrunde | New round record | Yeni tur rekoru |
| `pr.previousShort` | vorher | prev | önceki |
| `pr.volumeSuffix` | kg-Vol | kg-vol | kg-hac |

## `profile.*`  (30 Keys)

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
| `profile.equipment.footer` | Wähle aus, was du zur Verfügung hast. Pläne mit mehreren Implement-Varianten (z.B. Hybrid) bekommen automatisch die passende Übungsauswahl. Leer = Standard-Variante (Langhantel). | Pick what you have available. Plans with multiple implement variants (e.g. Hybrid) automatically get the matching exercise lineup. Empty = default variant (barbell). | Sahip olduğun ekipmanı seç. Birden çok ekipman varyantı olan planlar (örn. Hybrid) otomatik olarak uygun hareket listesini alır. Boş = varsayılan (barbell). |
| `profile.equipment.header` | Equipment-Präferenzen | Equipment preferences | Ekipman tercihleri |
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
| `profile.weeklyGoal.footer` | Dein Kalender-Streak zählt nur Wochen, die dieses Ziel erfüllen. Wähle, was du wirklich durchhalten kannst — ein gehaltener Streak schlägt ein verfehltes Ziel. | Your calendar streak only counts weeks that meet this goal. Pick what you can actually sustain — a streak you keep beats a goal you don't. | Takvim serin yalnızca bu hedefi karşılayan haftaları sayar. Gerçekten sürdürebileceğini seç — tutulan bir seri, kaçırılan bir hedeften iyidir. |
| `profile.weeklyGoal.header` | Wochenziel | Weekly goal | Haftalık hedef |
| `profile.weeklyGoal.label` | Workouts pro Woche | Workouts per week | Haftalık antrenman |

## `progression.*`  (3 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `progression.detail.newTargetFormat` | Neues Ziel: %@ kg | New target: %@ kg | Yeni hedef: %@ kg |
| `progression.headline.deload` | Lass uns kurz zurückrudern | Let's pull back briefly | Biraz geri çekilelim |
| `progression.headline.increase` | 🎯 Ziel erreicht — nächstes Mal mehr | 🎯 Goal hit — more next time | 🎯 Hedefe ulaşıldı — bir dahaki sefer daha fazla |

## `quiz.*`  (17 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `quiz.days.option` | %lld Tage | %lld days | %lld gün |
| `quiz.days.subtitle` | Sei realistisch — lieber 3 Tage konsistent als 6 geplant und nur 2 gemacht. | Be realistic — 3 consistent days beat 6 planned and only 2 done. | Gerçekçi ol — tutarlı 3 gün, planlanmış 6 ama yalnızca 2 yapılandan iyidir. |
| `quiz.days.title` | Wie oft möchtest du pro Woche trainieren? | How often do you want to train per week? | Haftada ne sıklıkla antrenman yapmak istersin? |
| `quiz.environment.gym` | Fitnessstudio | Gym | Salon |
| `quiz.environment.homeGym` | Home-Gym (Kurzhanteln) | Home Gym (Dumbbells) | Ev Salonu (Dambıllar) |
| `quiz.environment.noEquipment` | Überall (ohne Geräte) | Anywhere (no equipment) | Her yer (ekipmansız) |
| `quiz.environment.subtitle` | Wir filtern Programme, die zu deinem Equipment passen. | We filter programs to match your equipment. | Programları ekipmanına göre filtreleriz. |
| `quiz.environment.title` | Wo trainierst du meistens? | Where do you usually train? | Genelde nerede antrenman yapıyorsun? |
| `quiz.experience.subtitle` | Wir wählen Programme, die dich nicht überfordern. | We pick programs that won't overwhelm you. | Seni zorlamayacak programlar seçeriz. |
| `quiz.experience.title` | Wie viel Erfahrung hast du im Training? | How much training experience do you have? | Antrenmanda ne kadar deneyimin var? |
| `quiz.goal.subtitle` | Wähle das, was dich aktuell am meisten antreibt. | Pick what drives you most right now. | Şu an seni en çok motive edeni seç. |
| `quiz.goal.title` | Was ist dein primäres Ziel? | What's your primary goal? | Birincil hedefin ne? |
| `quiz.nav.next` | Weiter | Next | İleri |
| `quiz.result.alternatives` | Alternativen | Alternatives | Alternatifler |
| `quiz.result.choose` | Diesen Plan wählen | Choose This Plan | Bu Planı Seç |
| `quiz.result.topMatch` | TOP EMPFEHLUNG FÜR DICH | TOP MATCH FOR YOU | SENİN İÇİN EN İYİ EŞLEŞME |
| `quiz.title` | Plan finden | Find a Plan | Plan Bul |

## `rest.*`  (5 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `rest.notification.body` | Weiter mit %1$@ — Satz %2$lld von %3$lld wartet. | Back to %1$@ — set %2$lld of %3$lld is waiting. | %1$@ ile devam — %3$lld setten %2$lld. set bekliyor. |
| `rest.notification.title` | Pause vorbei! 💪 | Rest is over! 💪 | Mola bitti! 💪 |
| `rest.skip` | Pause überspringen | Skip rest | Molayı atla |
| `rest.timer.label.active` | PAUSE | REST | MOLA |
| `rest.timer.label.finished` | PAUSE VORBEI | REST OVER | MOLA BİTTİ |

## `rir.*`  (9 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `rir.tooltip.0` | Absolutes Muskelversagen — keine weitere Wiederholung möglich. | Absolute failure — no more clean reps possible. | Tam yetersizlik — başka temiz tekrar mümkün değil. |
| `rir.tooltip.0_5` | Hart am Limit — höchstens noch 1 wackelige Wiederholung. | Right at the edge — 1 shaky rep at most. | Sınırın dibinde — en fazla 1 zorlu tekrar. |
| `rir.tooltip.1` | Sehr hart — maximal noch 1 saubere Wiederholung im Tank. | Very hard — only 1 clean rep left in the tank. | Çok zor — tankta sadece 1 temiz tekrar kaldı. |
| `rir.tooltip.1_5` | Sehr intensiv — noch 1-2 saubere Wiederholungen im Tank. | Very intense — 1-2 clean reps left in the tank. | Çok yoğun — tankta 1-2 temiz tekrar kaldı. |
| `rir.tooltip.2` | Optimaler Reiz — noch 2 Wiederholungen möglich. | Optimal stimulus — 2 more reps possible. | Optimal uyaran — 2 tekrar daha mümkün. |
| `rir.tooltip.2_5` | Starker Reiz — noch 2-3 Wiederholungen möglich. | Strong stimulus — 2-3 more reps possible. | Güçlü uyaran — 2-3 tekrar daha mümkün. |
| `rir.tooltip.3` | Moderater Reiz — noch 3 saubere Wiederholungen machbar. | Moderate stimulus — 3 clean reps still doable. | Orta uyaran — 3 temiz tekrar daha yapılabilir. |
| `rir.tooltip.3_5` | Solider Reiz — noch 3-4 saubere Wiederholungen machbar. | Solid stimulus — 3-4 clean reps still doable. | Sağlam uyaran — 3-4 temiz tekrar daha yapılabilir. |
| `rir.tooltip.4plus` | Leichtes Training — ideal für Warm-up oder Deload. | Light training — ideal for warm-up or deload. | Hafif antrenman — ısınma veya deload için ideal. |

## `root.*`  (1 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `root.resetting.label` | Daten werden zurückgesetzt … | Resetting data … | Veriler sıfırlanıyor … |

## `session.*`  (7 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `session.adHoc.dayName` | Spontanes Training | Spontaneous Workout | Anlık Antrenman |
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

## `settings.*`  (126 Keys)

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
| `settings.confirm.reset.message` | Profil, alle Messungen, Pläne und Trainings-Sessions gehen UNWIDERRUFLICH verloren. Die App startet danach im Onboarding. | Profile, all measurements, plans, and workouts will be IRRECOVERABLY lost. The app will start in onboarding. | Profil, tüm ölçümler, planlar ve antrenman oturumları GERİ ALINAMAZ şekilde silinecek. Uygulama ardından tekrar onboarding'den başlayacak. |
| `settings.confirm.reset.title` | App wirklich zurücksetzen? | Really reset the app? | Uygulamayı gerçekten sıfırlamak istiyor musun? |
| `settings.dangerZone.footer` | Löscht Profil, Messungen, Pläne, Trainings-Templates und Trainings-Sessions vollständig. Die Apple-Health-Daten bleiben erhalten — die löscht du in der Health-App selber. | Deletes profile, measurements, plans, training templates, and workout sessions completely. Apple Health data is preserved — delete that from the Health app. | Profil, ölçümler, planlar, antrenman şablonları ve antrenman oturumlarını tamamen siler. Apple Health verileri korunur — onları Health uygulamasından silersin. |
| `settings.dataExport.action.share` | Archiv teilen | Share archive | Arşivi paylaş |
| `settings.dataExport.action.start` | Export starten | Start export | Dışa aktarmayı başlat |
| `settings.dataExport.contents.custom` | Eigene Übungen, die du selbst angelegt hast | Custom exercises you created yourself | Kendin oluşturduğun özel egzersizler |
| `settings.dataExport.contents.gear` | Ausrüstung (Schuhe, Bikes) und deren Kilometer | Gear (shoes, bikes) and their mileage | Ekipman (ayakkabı, bisiklet) ve kilometre bilgileri |
| `settings.dataExport.contents.header` | Was enthalten ist | What's included | Neler dahil |
| `settings.dataExport.contents.measurements` | Körpermessungen (Gewicht, KFA, Umfänge) | Body measurements (weight, body fat, circumferences) | Vücut ölçümleri (kilo, yağ oranı, çevreler) |
| `settings.dataExport.contents.plans` | Trainingspläne, Tage und Übungen | Training plans, days and exercises | Antrenman planları, günler ve egzersizler |
| `settings.dataExport.contents.profile` | Profil, Ziele, Trainings-Präferenzen | Profile, goals, training preferences | Profil, hedefler, antrenman tercihleri |
| `settings.dataExport.contents.records` | Persönliche Rekorde und PR-Historie | Personal records and PR history | Kişisel rekorlar ve PR geçmişi |
| `settings.dataExport.contents.settings` | App-Einstellungen & Erinnerungen (Einheiten, Theme, Benachrichtigungs-Präferenzen) | App settings & reminders (units, theme, notification preferences) | Uygulama ayarları ve hatırlatıcılar (birimler, tema, bildirim tercihleri) |
| `settings.dataExport.contents.workouts` | Alle Workouts mit Sätzen, Reps, Gewichten und RIR | All workouts with sets, reps, weights and RIR | Set, tekrar, ağırlık ve RIR ile tüm antrenmanlar |
| `settings.dataExport.exporting` | Sammle deine Daten… | Collecting your data… | Verilerin toplanıyor… |
| `settings.dataExport.finished.header` | Bereit zum Teilen | Ready to share | Paylaşmaya hazır |
| `settings.dataExport.finished.summary` | %lld Einträge in mehrere CSV-Dateien exportiert. | %lld records exported across multiple CSV files. | %lld kayıt birden fazla CSV dosyasına aktarıldı. |
| `settings.dataExport.intro.body` | Erstellt ein ZIP-Archiv mit allen Daten, die Deltiq über dich speichert — Workouts, Sätze, Körpermessungen, Pläne, persönliche Rekorde und Ausrüstung. Alles als CSV-Dateien, die Excel, Numbers oder jedes Tabellen-Tool öffnen kann. | Creates a ZIP archive containing every piece of data Deltiq stores about you — workouts, sets, measurements, plans, personal records and gear. All in plain CSV files that Excel, Numbers, or any spreadsheet tool can open. | Deltiq'in seninle ilgili sakladığı her veriyi içeren bir ZIP arşivi oluşturur — antrenmanlar, setler, ölçümler, planlar, kişisel rekorlar ve ekipman. Hepsi Excel, Numbers veya herhangi bir tablo aracının açabileceği basit CSV dosyaları olarak. |
| `settings.dataExport.intro.footer` | Deine Daten verlassen dein Gerät erst, wenn du das Archiv selbst teilst. Der Export läuft vollständig auf diesem iPhone. | Your data never leaves your device unless you share the archive yourself. The export happens entirely on this iPhone. | Arşivi sen kendin paylaşmadıkça verilerin cihazından ayrılmaz. Dışa aktarma tamamen bu iPhone'da gerçekleşir. |
| `settings.dataExport.intro.header` | Was das macht | What this does | Bu ne yapar |
| `settings.dataExport.title` | Daten-Export | Data Export | Veri Dışa Aktarımı |
| `settings.dataImport.action.pick` | ZIP-Datei auswählen | Choose ZIP file | ZIP dosyası seç |
| `settings.dataImport.action.shareErrors` | Fehlerprotokoll teilen | Share error log | Hata günlüğünü paylaş |
| `settings.dataImport.action.start` | Import starten | Start import | İçe aktarmayı başlat |
| `settings.dataImport.action.startReplace` | Daten löschen und einspielen | Delete data and restore | Verileri sil ve geri yükle |
| `settings.dataImport.confirm.action` | Ja, jetzt importieren | Yes, import now | Evet, şimdi içe aktar |
| `settings.dataImport.confirm.message` | Bestehende Daten bleiben unangetastet. Nur fehlende Zeilen aus dem Archiv werden ergänzt. Duplikate werden erkannt und übersprungen. | Existing data stays untouched. Only missing rows from the archive will be added. Duplicates are detected and skipped. | Mevcut veriler değişmez. Yalnızca arşivdeki eksik satırlar eklenir. Yinelenen kayıtlar algılanır ve atlanır. |
| `settings.dataImport.confirm.title` | Daten importieren? | Import data? | Verileri içe aktar? |
| `settings.dataImport.importing` | Lese Archiv und füge Daten ein… | Reading archive and merging data… | Arşiv okunuyor ve veriler birleştiriliyor… |
| `settings.dataImport.importing.header` | Import läuft | Import in progress | İçe aktarma sürüyor |
| `settings.dataImport.intro.body` | Wähle ein Deltiq-Export-ZIP (auf diesem oder einem anderen Gerät erstellt) und wir spielen die Daten in deine Bibliothek ein. Der Import ist sicher: nichts, was bereits in der App ist, wird angefasst. | Pick a Deltiq export ZIP (created on this or another device) and we'll merge the data into your library. The import is safe: nothing already in your app gets touched. | Bir Deltiq dışa aktarma ZIP'i seç (bu veya başka bir cihazda oluşturulmuş) ve verileri kütüphanene birleştirelim. İçe aktarma güvenlidir: uygulamada zaten bulunan hiçbir şey değişmez. |
| `settings.dataImport.intro.footer` | Es werden nur ZIP-Archive mit Format-Version 1.x unterstützt. Neuere oder ältere Formate werden abgelehnt. | Only ZIP archives with format version 1.x are supported. Newer or older formats will be refused. | Yalnızca format sürümü 1.x olan ZIP arşivleri desteklenir. Daha yeni veya eski formatlar reddedilir. |
| `settings.dataImport.intro.header` | Von einem Export wiederherstellen | Restore from an export | Bir dışa aktarmadan geri yükle |
| `settings.dataImport.picked.header` | Ausgewählte Datei | Selected file | Seçili dosya |
| `settings.dataImport.progress.customExercises` | Lese eigene Übungen… | Reading custom exercises… | Özel egzersizler okunuyor… |
| `settings.dataImport.progress.gear` | Lese Ausrüstung… | Reading gear… | Ekipman okunuyor… |
| `settings.dataImport.progress.measurements` | Lese Messungen… | Reading measurements… | Ölçümler okunuyor… |
| `settings.dataImport.progress.personalRecords` | Lese persönliche Rekorde… | Reading personal records… | Kişisel rekorlar okunuyor… |
| `settings.dataImport.progress.planDays` | Lese Plan-Tage… | Reading plan days… | Plan günleri okunuyor… |
| `settings.dataImport.progress.planExercises` | Lese Plan-Übungen… | Reading plan exercises… | Plan egzersizleri okunuyor… |
| `settings.dataImport.progress.plans` | Lese Pläne… | Reading plans… | Planlar okunuyor… |
| `settings.dataImport.progress.profile` | Lese Profil… | Reading profile… | Profil okunuyor… |
| `settings.dataImport.progress.save` | Speichere in der Datenbank… | Saving to database… | Veritabanına kaydediliyor… |
| `settings.dataImport.progress.settings` | Lese Einstellungen… | Reading settings… | Ayarlar okunuyor… |
| `settings.dataImport.progress.waterLog` | Lese Wasser-Protokoll… | Reading water log… | Su günlüğü okunuyor… |
| `settings.dataImport.progress.wipe` | Lösche bestehende Daten… | Clearing existing data… | Mevcut veriler temizleniyor… |
| `settings.dataImport.progress.workoutSets` | Lese Workout-Sätze… | Reading workout sets… | Antrenman setleri okunuyor… |
| `settings.dataImport.progress.workouts` | Lese Workouts… | Reading workouts… | Antrenmanlar okunuyor… |
| `settings.dataImport.replaceConfirm.action` | Löschen und einspielen | Delete and restore | Sil ve geri yükle |
| `settings.dataImport.replaceConfirm.message` | Hierbei werden alle in der App gespeicherten Workouts, Pläne, Messungen, Ausrüstungs-Einträge und persönlichen Rekorde unwiderruflich gelöscht — anschließend wird alles aus dem Archiv eingespielt. Diese Aktion kann nicht rückgängig gemacht werden. | This will permanently delete every workout, plan, measurement, gear entry and personal record stored in the app — then restore everything from the archive. This action cannot be undone. | Bu işlem, uygulamada saklanan tüm antrenmanları, planları, ölçümleri, ekipman kayıtlarını ve kişisel rekorları kalıcı olarak siler — ardından her şeyi arşivden geri yükler. Bu işlem geri alınamaz. |
| `settings.dataImport.replaceConfirm.title` | Alle Daten löschen? | Delete all data? | Tüm veriler silinsin mi? |
| `settings.dataImport.result.errors` | Fehlerhafte Zeilen | Failed rows | Başarısız satırlar |
| `settings.dataImport.result.fileSummary` | +%lld / skip %lld | +%lld / skip %lld | +%lld / atla %lld |
| `settings.dataImport.result.header` | Import abgeschlossen | Import complete | İçe aktarma tamamlandı |
| `settings.dataImport.result.imported` | Importiert | Imported | İçe aktarıldı |
| `settings.dataImport.result.skipped` | Übersprungen (Duplikate) | Skipped (duplicates) | Atlandı (yinelenen) |
| `settings.dataImport.strategy.appendOnly` | Append-only — deine bestehenden Workouts, Rekorde und Pläne bleiben unangetastet. | Append-only — your existing workouts, records and plans stay untouched. | Yalnızca ekleme — mevcut antrenmanların, rekorların ve planların değişmez. |
| `settings.dataImport.strategy.duplicates` | Duplikate (gleiches Workout/Maß/PR) werden anhand des Zeitstempels erkannt und übersprungen. | Duplicates (same workout/measurement/PR) are detected by timestamp and skipped. | Yinelenen kayıtlar (aynı antrenman/ölçüm/PR) zaman damgasına göre algılanır ve atlanır. |
| `settings.dataImport.strategy.errorsLog` | Fehlerhafte Zeilen werden in einem Fehlerprotokoll gesammelt, das du teilen kannst. | Broken rows are collected into an errors report you can share. | Bozuk satırlar, paylaşabileceğin bir hata raporunda toplanır. |
| `settings.dataImport.strategy.header` | Wie der Import arbeitet | How the import works | İçe aktarma nasıl çalışır |
| `settings.dataImport.strategyPicker.appendOnly` | Anhängen (sicher) | Append (safe) | Ekle (güvenli) |
| `settings.dataImport.strategyPicker.appendOnlyDescription` | Nur fehlende Einträge werden hinzugefügt. Deine bestehenden Daten bleiben erhalten. | Only missing entries are added. Your existing data is preserved. | Yalnızca eksik kayıtlar eklenir. Mevcut verilerin korunur. |
| `settings.dataImport.strategyPicker.header` | Import-Strategie | Import strategy | İçe aktarma stratejisi |
| `settings.dataImport.strategyPicker.replace` | Ersetzen | Replace | Değiştir |
| `settings.dataImport.strategyPicker.replaceWarning` | Alle bestehenden Workouts, Pläne, Messungen, Ausrüstung und PRs werden gelöscht, bevor das Archiv eingespielt wird. Das kann nicht rückgängig gemacht werden. | All existing workouts, plans, measurements, gear and PRs will be deleted before the archive is restored. This cannot be undone. | Arşiv geri yüklenmeden önce mevcut tüm antrenmanlar, planlar, ölçümler, ekipman ve PR'lar silinir. Bu işlem geri alınamaz. |
| `settings.dataImport.title` | Daten-Import | Data Import | Veri İçe Aktarımı |
| `settings.deload.description` | Deltiq erkennt Überlastung und lange Pausen und schlägt dann vor, die Arbeitsgewichte vorübergehend zu senken. Aus heißt: keine Vorschläge mehr — bereits gesenkte Gewichte bleiben, bis du sie unten zurücksetzt. | Deltiq detects overreaching and long breaks and then suggests temporarily lowering your working weights. Off means no more suggestions — weights already lowered stay until you reset them below. | Deltiq aşırı yüklenmeyi ve uzun molaları algılar ve çalışma ağırlıklarını geçici olarak düşürmeyi önerir. Kapalı: artık öneri gelmez — hâlihazırda düşürülmüş ağırlıklar, aşağıdan sıfırlayana kadar öyle kalır. |
| `settings.deload.endNow` | Gesenkte Gewichte zurücksetzen (%lld Übungen) | Restore lowered weights (%lld exercises) | Düşürülmüş ağırlıkları geri yükle (%lld egzersiz) |
| `settings.deload.endNow.done` | Ursprüngliche Gewichte wiederhergestellt. | Original weights restored. | Orijinal ağırlıklar geri yüklendi. |
| `settings.deload.toggle` | Deload-Vorschläge | Deload suggestions | Deload önerileri |
| `settings.health.connect` | Verbinden | Connect | Bağla |
| `settings.health.denied` | Berechtigung verweigert | Permission denied | İzin reddedildi |
| `settings.health.footer` | Bei aktivierter Verbindung wird im Messwerte-Formular das letzte Waagen-Gewicht vorausgefüllt. Beim Speichern werden Gewicht, KFA und Magere Masse zurück nach Apple Health geschrieben. | When connected, the measurement form prefills your last scale weight. Saving writes weight, body fat %, and lean mass back to Apple Health. | Bağlıyken ölçüm formu son tartı kilonu önceden doldurur. Kaydetme; kilo, yağ oranı ve yağsız kütleyi Apple Health'e yazar. |
| `settings.health.lastSync` | Letzter Sync | Last Sync | Son Senkronizasyon |
| `settings.health.notSetup` | Nicht eingerichtet | Not set up | Kurulmadı |
| `settings.health.openIOSSettings` | In iOS-Einstellungen öffnen | Open iOS Settings | iOS Ayarlarını Aç |
| `settings.health.unavailable` | Nicht verfügbar | Not available | Kullanılamıyor |
| `settings.preferences.exerciseLibrary` | Übungen | Exercises | Hareketler |
| `settings.preferences.gear` | Ausrüstung & Schuhe | Gear & Shoes | Ekipman & Ayakkabı |
| `settings.preferences.units.imperial` | Imperial | Imperial | İmperyal |
| `settings.preferences.units.label` | Einheiten | Units | Birimler |
| `settings.preferences.units.metric` | Metrisch | Metric | Metrik |
| `settings.privacy.backups` | Automatische Backups | Automatic backups | Otomatik yedekler |
| `settings.privacy.dataExport` | Daten exportieren (CSV) | Export data (CSV) | Verileri dışa aktar (CSV) |
| `settings.privacy.dataImport` | Daten importieren (CSV) | Import data (CSV) | Verileri içe aktar (CSV) |
| `settings.privacy.footer` | Exportiere alle deine Trainings- und Profildaten als ZIP-Archiv mit CSV-Dateien. Praktisch für Backups, Gerätewechsel oder einfach um deine Daten in der Hand zu haben. | Export all your training and profile data as a ZIP archive of CSV files. Useful for backups, switching devices, or simply having your data. | Tüm antrenman ve profil verilerini CSV dosyalarından oluşan bir ZIP arşivi olarak dışa aktar. Yedekleme, cihaz değişikliği veya verilerine sahip olmak için kullanışlıdır. |
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
| `settings.section.privacy` | Datenschutz | Privacy | Gizlilik |
| `settings.section.profile_goals` | Profil & Ziele | Profile & Goals | Profil & Hedefler |
| `settings.timer.footer` | Wird beim Ablauf des Pausen-Timers ausgelöst. Vibrations-Toggle hat auf iPads keine Wirkung. 'PR-Feiern' steuert Save-Screen-Popups, Live-Activity-Headline und lokale Benachrichtigungen — die Bestleistungen werden trotzdem im Trophy-Room gespeichert. | Fires when the rest timer ends. Vibration has no effect on iPads. 'Celebrate PRs' drives save-screen popups, Live Activity headlines, and local notifications — PRs are saved to the Trophy Room either way. | Mola zamanlayıcısı bittiğinde tetiklenir. Titreşim iPad'lerde etkisizdir. 'PR'ı Kutla' kaydetme ekranı pencerelerini, Live Activity başlıklarını ve yerel bildirimleri yönlendirir — PR'lar her durumda Kupa Odası'na kaydedilir. |
| `settings.timer.haptics` | Vibrieren | Vibrate | Titret |
| `settings.timer.prCelebrations` | PR-Feiern | Celebrate PRs | PR'ı Kutla |
| `settings.timer.section` | Pausen-Timer-Feedback | Rest Timer Feedback | Mola Zamanlayıcı Geri Bildirimi |
| `settings.timer.sound` | Ton abspielen | Play sound | Ses çal |
| `settings.title` | Einstellungen | Settings | Ayarlar |
| `settings.training.rirTooltip.description` | Zeigt kurze Erklärungen beim Einstellen der Intensität (Reps in Reserve). | Shows short explanations when setting intensity (Reps in Reserve). | Yoğunluk ayarlanırken kısa açıklamalar gösterir (Reps in Reserve). |
| `settings.training.rirTooltip.title` | RIR-Hilfstexte anzeigen | Show RIR helper texts | RIR yardım metinlerini göster |
| `settings.units.footer` | Die DB speichert immer metrisch. Diese Einstellung steuert nur die Anzeige in Eingabe-Feldern, im Hantel-Rechner und auf den Karten. | DB always stores metric. This setting only changes display in inputs, the plate calculator, and cards. | Veritabanı her zaman metrik kaydeder. Bu ayar sadece giriş alanlarında, plaka hesabında ve kartlarda görünümü değiştirir. |
| `settings.workout.footer` | Wenn aus, werden Warmup- und Cooldown-Übungen während der Session ausgeblendet. Die Templates und deine Plan-Editierung bleiben unverändert — der Toggle wirkt nur auf den Live-Trainings-Flow. Warmups sind ohnehin nie Pflicht: der „Training speichern"-Button bleibt immer klickbar, auch wenn du sie nicht abhakst. | When off, warmup and cooldown exercises are hidden during the session. Templates and plan editing remain unchanged — only the live workout flow is affected. Warmups are never mandatory: 'Save Workout' stays tappable even if you skip them. | Kapalıyken oturum sırasında ısınma ve soğuma hareketleri gizlenir. Şablonlar ve plan düzenleme değişmez — yalnızca canlı antrenman akışı etkilenir. Isınmalar zorunlu değildir: 'Antrenmanı Kaydet' onları atlasan bile aktif kalır. |
| `settings.workout.section` | Trainings-Verhalten | Workout Behavior | Antrenman Davranışı |
| `settings.workout.showWarmups` | Warmup & Cooldown anzeigen | Show warmup & cooldown | Isınma & Soğuma Göster |

## `sex.*`  (2 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `sex.female` | Weiblich | Female | Kadın |
| `sex.male` | Männlich | Male | Erkek |

## `summary.*`  (59 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `summary.achievements.heaviestOfWeek.subtitle` | Höchstes Volumen aller bisherigen Trainings dieser Woche. | Highest volume of all your workouts this week so far. | Bu hafta yaptığın tüm antrenmanların en yüksek hacmi. |
| `summary.achievements.heaviestOfWeek.title` | Stärkstes Training der Woche | Heaviest workout of the week | Haftanın en ağır antrenmanı |
| `summary.achievements.longestDistanceOfWeek.subtitle` | Mehr Strecke als jedes Cardio diese Woche. | More distance than any cardio this week. | Bu haftaki tüm kardiyolardan daha uzun. |
| `summary.achievements.longestDistanceOfWeek.title` | Längste Distanz der Woche | Longest distance of the week | Haftanın en uzun mesafesi |
| `summary.achievements.longestOfWeek.subtitle` | Du warst diese Woche noch nie so lange dabei. | You haven't trained this long all week. | Bu hafta hiç bu kadar uzun antrenman yapmamıştın. |
| `summary.achievements.longestOfWeek.title` | Längstes Training der Woche | Longest workout of the week | Haftanın en uzun antrenmanı |
| `summary.achievements.section` | Erfolge | Achievements | Başarılar |
| `summary.achievements.weeklyMilestone.subtitle` | Solides Pensum — bleib dran. | Solid pace — keep going. | Sağlam tempo — devam et. |
| `summary.achievements.weeklyMilestone.titleFormat` | Dein %lld. Training diese Woche | Workout #%lld this week | Bu haftaki %lld. antrenmanın |
| `summary.action.finish` | Speichern & zum Dashboard | Save & to dashboard | Kaydet ve Panele Dön |
| `summary.addExercise.button` | Übung hinzufügen | Add exercise | Egzersiz ekle |
| `summary.addExercise.hint` | Vergessen, eine Übung im Training zu loggen? Hinzufügen, Sätze eintragen, fertig. | Forgot to log an exercise during the workout? Add it here, fill in the sets, done. | Antrenman sırasında bir egzersizi kaydetmeyi unuttun mu? Buradan ekle, setleri doldur, hazır. |
| `summary.addSet.button` | Satz hinzufügen | Add set | Set ekle |
| `summary.date` | Datum | Date | Tarih |
| `summary.deleteSession.confirmDelete` | Löschen | Delete | Sil |
| `summary.deleteSession.confirmMessage` | Alle Sätze und das Volumen dieses Trainings werden entfernt. Diese Aktion kann nicht rückgängig gemacht werden. | All sets and the volume of this workout will be removed. This cannot be undone. | Bu antrenmanın tüm setleri ve hacmi kaldırılacak. Bu işlem geri alınamaz. |
| `summary.deleteSession.confirmTitle` | Training endgültig löschen? | Delete workout permanently? | Antrenman kalıcı olarak silinsin mi? |
| `summary.detailTitle` | Trainings-Detail | Workout Details | Antrenman Detayı |
| `summary.duration` | Dauer | Duration | Süre |
| `summary.durationMinutes` | %lld Min | %lld min | %lld dk |
| `summary.early.footnote` | Der Lauf ist gespeichert, zählt aber nicht als Bestleistung — das Pensum war noch offen. | This run is saved but doesn't count as a personal best — the target wasn't fully reached. | Bu antrenman kaydedildi ama hedef tamamlanmadığı için rekor olarak sayılmıyor. |
| `summary.early.progress` | %1$@ von %2$@ | %1$@ of %2$@ | %2$@ içinde %1$@ |
| `summary.early.unitWithTime` | %1$@ in %2$@ | %1$@ in %2$@ | %2$@ içinde %1$@ |
| `summary.editMeta.footer` | Datum + Dauer werden hier überschrieben. Set-Werte unten editierst du direkt am Satz. | Date + duration are overridden here. Edit set values directly on each set below. | Tarih + süre burada üzerine yazılır. Set değerlerini aşağıda doğrudan her sette düzenle. |
| `summary.editMeta.header` | Eckdaten | Key Data | Temel Veriler |
| `summary.editTitle` | Training bearbeiten | Edit Workout | Antrenmanı Düzenle |
| `summary.exercise.bestPrefix` | Beste | Best | En İyi |
| `summary.exercise.footer.one` | %1$lld Satz • %2$@ kg Volumen | %1$lld set • %2$@ kg volume | %1$lld set • %2$@ kg hacim |
| `summary.exercise.footer.other` | %1$lld Sätze • %2$@ kg Volumen | %1$lld sets • %2$@ kg volume | %1$lld set • %2$@ kg hacim |
| `summary.exercise.removeFromSession` | Aus Session entfernen | Remove from session | Oturumdan kaldır |
| `summary.finishFooter` | Die Session ist bereits gespeichert. Der Button schließt die Zusammenfassung und bringt dich zurück aufs Dashboard. | Session is already saved. The button closes the summary and returns you to the dashboard. | Oturum zaten kaydedildi. Buton özeti kapatır ve seni panele döndürür. |
| `summary.gear.header` | Ausrüstung | Gear | Ekipman |
| `summary.gear.none` | Kein Gear | No gear | Ekipman yok |
| `summary.hero.title` | Training abgeschlossen | Workout completed | Antrenman Tamamlandı |
| `summary.hero.title.early` | Vorzeitig gespeichert | Saved early | Erken kaydedildi |
| `summary.hero.unit.km` | km Cardio | km cardio | km kardiyo |
| `summary.hero.unit.minutes` | Minuten Training | minutes training | dakika antrenman |
| `summary.hero.unit.minutesDone` | Minuten geschafft | minutes done | tamamlanan dakika |
| `summary.hero.unit.rounds` | Runden geschafft | rounds completed | tamamlanan tur |
| `summary.hero.unit.volumeKg` | kg Volumen | kg volume | kg hacim |
| `summary.menu.deleteSession` | Training löschen | Delete Workout | Antrenmanı sil |
| `summary.note.footer` | Tauchen später in der History pro Session auf — gut für Form-Cues und Verletzungs-Tracking. | Show up later in history per session — useful for form cues and injury tracking. | Geçmişte oturum başına görünür — form ipuçları ve sakatlık takibi için faydalı. |
| `summary.note.label` | Notiz | Note | Not |
| `summary.note.placeholder` | Wie war's? Schmerzen, Pump, Performance ... | How was it? Pain, pump, performance ... | Nasıldı? Ağrı, pump, performans ... |
| `summary.prFooter` | Erkannt durch Vergleich mit allen vorherigen abgeschlossenen Sessions. Cardio bleibt aussen vor — andere Metrik-Domäne. | Detected by comparing all previous completed sessions. Cardio excluded — different metric domain. | Tüm önceki tamamlanan oturumlar ile karşılaştırarak tespit edildi. Kardiyo dahil değil — farklı metrik. |
| `summary.progressionFooter` | Ziel erreicht? Die App passt das Gewicht fürs nächste Training automatisch an. Änderbar pro Übung im Editor. | Target hit? The app adjusts the weight for next workout automatically. Adjustable per exercise in the editor. | Hedefe ulaşıldı mı? Uygulama bir sonraki antrenman için ağırlığı otomatik ayarlar. Editörde hareket başına düzenlenebilir. |
| `summary.removeExercise.confirmMessageFormat` | Alle Sätze von „%@" werden aus diesem Training entfernt. Die Übung selbst bleibt für zukünftige Trainings erhalten. | All sets of "%@" will be removed from this workout. The exercise itself stays available for future workouts. | „%@" egzersizinin tüm setleri bu antrenmandan kaldırılacak. Egzersiz gelecekteki antrenmanlar için kalır. |
| `summary.removeExercise.confirmRemove` | Entfernen | Remove | Kaldır |
| `summary.removeExercise.confirmTitle` | Übung aus Session entfernen? | Remove exercise from session? | Egzersiz oturumdan kaldırılsın mı? |
| `summary.section.personalRecords` | Persönliche Rekorde | Personal Records | Kişisel Rekorlar |
| `summary.section.progression` | Smart-Progression | Smart Progression | Akıllı İlerleme |
| `summary.section.stats` | Zusammenfassung | Summary | Özet |
| `summary.setsEmpty` | Keine Sätze geloggt. | No sets logged. | Set kaydedilmedi. |
| `summary.setsHeader` | Sätze | Sets | Setler |
| `summary.stat.exercises` | Übungen | Exercises | Egzersizler |
| `summary.stat.minuteTarget` | Minuten-Ziel | Minute target | Dakika hedefi |
| `summary.title` | Zusammenfassung | Summary | Özet |
| `summary.toolbar.done` | Fertig | Done | Tamam |
| `summary.toolbar.edit` | Bearbeiten | Edit | Düzenle |

## `tab.*`  (5 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `tab.dashboard` | Dashboard | Dashboard | Panel |
| `tab.measurement` | Messung | Measurement | Ölçüm |
| `tab.more` | Mehr | More | Daha Fazla |
| `tab.plan` | Plan | Plan | Plan |
| `tab.tools` | Werkzeuge | Tools | Araçlar |

## `timedWorkout.*`  (21 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `timedWorkout.amrap.addRound` | +1 Runde | +1 round | +1 tur |
| `timedWorkout.amrap.capContext` | %lld Min. Deckel | %lld min cap | %lld dk limit |
| `timedWorkout.amrap.circuitHint` | Von vorn, bis die Zeit abgelaufen ist. | Start over, until time runs out. | Süre bitene kadar baştan başla. |
| `timedWorkout.amrap.partialReps` | Zusätzliche Wdh. | Extra reps | Ek tekrar |
| `timedWorkout.amrap.roundsLabel` | RUNDEN | ROUNDS | TUR |
| `timedWorkout.discard.confirmButton` | Abbrechen & verwerfen | Cancel & discard | İptal et ve sil |
| `timedWorkout.discard.confirmTitle` | Training abbrechen? | Cancel workout? | Antrenmanı iptal et? |
| `timedWorkout.discard.menu` | Verwerfen | Discard | Sil |
| `timedWorkout.elapsed` | Verstrichen: %@ | Elapsed: %@ | Geçen süre: %@ |
| `timedWorkout.emom.completedPill` | %lld erledigt | %lld done | %lld tamam |
| `timedWorkout.emom.markDone` | Minute geschafft | Minute done | Dakika tamam |
| `timedWorkout.emom.minuteContext` | Minute %lld / %lld | Minute %lld of %lld | %lld. / %lld. dakika |
| `timedWorkout.emom.nextMinute` | Nächste Minute | Next minute | Sonraki dakika |
| `timedWorkout.emom.notification.complete` | EMOM geschafft! Ergebnis speichern. | EMOM complete! Save your result. | EMOM tamamlandı! Sonucu kaydet. |
| `timedWorkout.emom.notification.nextMinute` | Minute %lld beginnt | Minute %lld starts | %lld. dakika başlıyor |
| `timedWorkout.emom.thisMinute` | DIESE MINUTE | THIS MINUTE | BU DAKİKA |
| `timedWorkout.finish.save` | Speichern | Save | Kaydet |
| `timedWorkout.forTime.finishedLabel` | Geschafft! | Done! | Tamamlandı! |
| `timedWorkout.forTime.lastRoundHint` | Das letzte Häkchen stoppt die Uhr. | The last checkmark stops the clock. | Son işaret saati durdurur. |
| `timedWorkout.forTime.pillLabel` | Auf Zeit | For Time | Süreye Karşı |
| `timedWorkout.forTime.progressContext` | %lld / %lld erledigt | %lld of %lld done | %lld / %lld tamam |

## `trophy.*`  (24 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `trophy.axis.distance` | Distanz (km) | Distance (km) | Mesafe (km) |
| `trophy.axis.pace` | Pace (min/km) | Pace (min/km) | Tempo (dk/km) |
| `trophy.axis.reps` | Wdh | Reps | Tekrar |
| `trophy.axis.rounds` | Runden | Rounds | Tur |
| `trophy.axis.seconds` | Sekunden | Seconds | Saniye |
| `trophy.axis.volume` | Volumen (kg) | Volume (kg) | Hacim (kg) |
| `trophy.axis.weight` | Gewicht (kg) | Weight (kg) | Ağırlık (kg) |
| `trophy.empty.cta.detect` | Aus History detektieren | Detect from History | Geçmişten Tespit Et |
| `trophy.empty.description.firstWorkout` | Beende dein erstes Training, um deinen ersten PR aufzustellen. | Finish your first workout to set your first PR. | İlk PR'ını koymak için ilk antrenmanını bitir. |
| `trophy.empty.description.hasWorkouts` | Du hast bereits Trainings, aber noch keine Rekorde gespeichert. Klick unten, um sie aus deiner History zu detektieren. | You have workouts but no records saved yet. Tap below to detect them from your history. | Antrenmanların var ama henüz kayıtlı rekor yok. Geçmişinden tespit etmek için aşağıya dokun. |
| `trophy.empty.title` | Noch keine Rekorde | No records yet | Henüz rekor yok |
| `trophy.kind.short.bestSet` | Bestsatz | Best Set | En İyi Set |
| `trophy.kind.short.estimated1RM` | 1RM | 1RM | 1RM |
| `trophy.kind.short.fastestPace` | Pace | Pace | Tempo |
| `trophy.kind.short.heaviestWeight` | Max-Gewicht | Max Weight | Maks. Ağırlık |
| `trophy.kind.short.longestDistance` | Distanz | Distance | Mesafe |
| `trophy.kind.short.maxHoldSeconds` | Bestzeit | Best Time | En İyi Süre |
| `trophy.kind.short.maxReps` | Max Wdh | Max Reps | Maks. Tekrar |
| `trophy.rebuild.confirm.cta` | Neu berechnen | Recompute | Yeniden hesapla |
| `trophy.rebuild.confirm.message` | Setzt alle gespeicherten Rekorde zurück und detektiert sie aus deiner kompletten History neu. Nützlich nach gelöschten Sessions. | Resets all saved records and re-detects them from your complete history. Useful after deleted sessions. | Tüm kayıtlı rekorları sıfırlar ve geçmişinden yeniden tespit eder. Silinen oturumlardan sonra faydalı. |
| `trophy.rebuild.confirm.title` | Trophy Room neu berechnen? | Recompute Trophy Room? | Kupa Odası yeniden hesaplansın mı? |
| `trophy.rebuild.menu` | Aus History neu berechnen | Recompute from history | Geçmişten yeniden hesapla |
| `trophy.singleEntry` | Nur ein %@-Eintrag — Trend ab 2 Rekorden. | Only one %@ entry — trend starts at 2 records. | Sadece bir %@ kaydı — trend 2 rekordan başlar. |
| `trophy.totalRecords` | %lld Rekorde gesamt | %lld records total | Toplam %lld rekor |

## `unit.*`  (6 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `unit.kg.lower` | kg | kg | kg |
| `unit.kg.upper` | KG | KG | KG |
| `unit.km.lower` | km | km | km |
| `unit.minutes.short` | Min | min | dk |
| `unit.reps.short` | Wdh | reps | tkr |
| `unit.seconds.short` | Sek | sec | sn |

## `warmup.*`  (2 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `warmup.ramp.emptyBar` | Leere Stange | Empty bar | Boş bar |
| `warmup.ramp.title` | Aufwärm-Sätze | Warm-up sets | Isınma setleri |

## `water.*`  (11 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `water.empty` | Trag deinen ersten Schluck mit den Buttons oben ein. | Log your first sip with the buttons above. | İlk yudumu yukarıdaki butonlarla kaydet. |
| `water.goalReached` | Tagesziel erreicht | Daily goal reached | Günlük hedef ulaşıldı |
| `water.heroFooter` | Tagesziel = Gewicht × 35 ml. Quelle: %@. | Daily goal = weight × 35 ml. Source: %@. | Günlük hedef = kilo × 35 ml. Kaynak: %@. |
| `water.ofTotal` | ml von %lld | ml of %lld | ml / %lld |
| `water.quickAdd.section` | Schnell-Eintrag | Quick Add | Hızlı Ekle |
| `water.remainingToGoal` | %lld ml bis zum Ziel | %lld ml to goal | Hedefe %lld ml |
| `water.resetToday` | Heute zurücksetzen | Reset Today | Bugünü Sıfırla |
| `water.source.defaultFormat` | Standard %lld kg | default %lld kg | varsayılan %lld kg |
| `water.source.goalWeight` | Profil-Zielgewicht | profile goal weight | profil hedef kilo |
| `water.source.lastMeasurement` | letzte Messung | last measurement | son ölçüm |
| `water.title` | Wasser | Water | Su |

## `widget.*`  (12 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `widget.cardioPace.name` | Cardio-Pace-Trend | Cardio Pace Trend | Kardiyo Tempo Trendi |
| `widget.coachingInsight.name` | Coaching-Insight | Coaching Insight | Koçluk İçgörüsü |
| `widget.compoundLifts.name` | Compound-Lift-Trend | Compound Lift Trend | Temel Hareket Trendi |
| `widget.muscleHeatmap.name` | Muskel-Heatmap | Muscle Heatmap | Kas Isı Haritası |
| `widget.nextWorkout.name` | Nächstes Training | Next Workout | Sıradaki Antrenman |
| `widget.recentWorkouts.name` | Letzte Trainings | Recent Workouts | Son Antrenmanlar |
| `widget.trainingCalendar.name` | Trainings-Kalender | Training calendar | Antrenman takvimi |
| `widget.trophyRoom.name` | Trophy Room | Trophy Room | Kupa Odası |
| `widget.volumeOverTime.name` | Volumen-Trend | Volume trend | Hacim trendi |
| `widget.weeklyVolume.name` | Diese Woche | This Week | Bu Hafta |
| `widget.weightTrend.name` | Gewichts-Trend | Weight Trend | Kilo Trendi |
| `widget.workoutHistory.name` | Trainingsverlauf | Workout History | Antrenman Geçmişi |

## `workout.*`  (6 Keys)

| Key | Deutsch (DE) | English (EN) | Türkçe (TR) |
|---|---|---|---|
| `workout.allSetsDone` | Alle Sätze erledigt | All sets done | Tüm setler tamam |
| `workout.detail.cardio` | Cardio • %llds Pause | Cardio • %llds rest | Kardiyo • %llds mola |
| `workout.detail.reps.one` | %1$lld Satz • %2$@ Wdh • %3$llds Pause | %1$lld set • %2$@ reps • %3$llds rest | %1$lld set • %2$@ tekrar • %3$llds mola |
| `workout.detail.reps.other` | %1$lld Sätze • %2$@ Wdh • %3$llds Pause | %1$lld sets • %2$@ reps • %3$llds rest | %1$lld set • %2$@ tekrar • %3$llds mola |
| `workout.detail.seconds.one` | %1$lld Satz • %2$@ Sek • %3$llds Pause | %1$lld set • %2$@ sec • %3$llds rest | %1$lld set • %2$@ sn • %3$llds mola |
| `workout.detail.seconds.other` | %1$lld Sätze • %2$@ Sek • %3$llds Pause | %1$lld sets • %2$@ sec • %3$llds rest | %1$lld set • %2$@ sn • %3$llds mola |


---

# 🚧 Hartkodierte deutsche Strings (noch nicht im Catalog)

Stand: 0 hartkodierte deutsche Strings über 0 Dateien gefunden (per Heuristik — false positives möglich, beim Refactor wird jede Stelle nochmal geprüft).

Diese Strings müssen in einem späteren i18n-Sweep (DEL-073 Phase 2-4) nach `Localizable.xcstrings` migriert werden:

1. Active Workout (ActiveWorkoutView, ExerciseCard, SetRow, WorkoutSummaryView)
2. Plan-Editor (PlanEditorView, DayEditorView, ProgramTemplatePickerView)
3. Library (ExerciseLibraryData, Domain-Enum-Labels)

