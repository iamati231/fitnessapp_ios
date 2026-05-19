"""DEL-117 -- Hardcoded German Strings Sweep.

Centralizes ALL string-migrations (PR1 + PR2) into one dict.  Idempotent
xcstrings injection: only fills empty slots, never overwrites existing.

Run from project root:
    "C:\\Python314\\python.exe" .scripts/del117_hardcoded_sweep.py

The Swift source-file edits are handled separately (per view), since each
requires precise context — Button label vs Text view vs alert message vs
navigationTitle. This script is the SINGLE SOURCE OF TRUTH for the
DE/EN/TR translations.

Convention: dot-namespace keys.  Shared reusable keys live under `common.*`.
String-interpolation tokens use `%@` (text) or `%lld` (integer).
"""
import json
import os

ROOT      = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
XCSTRINGS = os.path.join(ROOT, "Sources", "FitnessAppUI", "Resources", "Localizable.xcstrings")


# Schema: key -> (de, en, tr)
KEYS = {
    # ──────────────────────────────────────────────────────────────────
    # Shared common.* — reused across many views.  Existing keys
    # (common.cancel, common.save, common.done, common.discard) NOT
    # repeated here; this dict only adds NEW shared keys.
    # ──────────────────────────────────────────────────────────────────
    "common.add":     ("Hinzufügen",       "Add",        "Ekle"),
    "common.close":   ("Schließen",        "Close",      "Kapat"),
    "common.back":    ("Zurück",           "Back",       "Geri"),
    "common.edit":    ("Bearbeiten",       "Edit",       "Düzenle"),
    "common.delete":  ("Löschen",          "Delete",     "Sil"),

    # ──────────────────────────────────────────────────────────────────
    # PR1 Batch 1 — 8 smallest files
    # ──────────────────────────────────────────────────────────────────

    # ExerciseCard.swift
    "workout.allSetsDone":      ("Alle Sätze erledigt",     "All sets done",                "Tüm setler tamam"),

    # RestTimerBar.swift
    "rest.skip":                ("Pause überspringen",      "Skip rest",                    "Molayı atla"),

    # DayPickerSheet.swift
    "dayPicker.title":          ("Trainingstage wählen",    "Choose Training Days",         "Antrenman Günleri"),
    "dayPicker.prompt":         ("Wähle exakt %lld Tage, an denen du trainieren möchtest.",
                                  "Choose exactly %lld days you want to train.",
                                  "Antrenman yapmak istediğin tam olarak %lld gün seç."),
    "dayPicker.startPlan":      ("Plan starten",            "Start Plan",                   "Planı Başlat"),

    # SetRow.swift
    "set.numberLabel":          ("Satz %lld",               "Set %lld",                     "Set %lld"),
    "set.lockedHint":           ("Beende oder stoppe die laufende Übung zuerst.",
                                  "Finish or stop the active exercise first.",
                                  "Önce aktif hareketi bitir ya da durdur."),
    "barbell.loading.title":    ("Hantel-Aufladung",        "Barbell Loading",              "Halter Yükleme"),
    "barbell.loading.empty":    ("Keine Aufladung — bleib bei der leeren Stange.",
                                  "No plates needed — keep the empty bar.",
                                  "Plaka yok — boş barı bırak."),

    # ExerciseEditorView.swift
    "editor.exercise.templateLocked": ("Template-Übung — Name und Cardio/Zeit-Flags sind festgelegt.",
                                        "Template exercise — name and cardio/time flags are fixed.",
                                        "Şablon hareket — ad ve kardiyo/süre bayrakları sabit."),
    "editor.exercise.sets":     ("Sätze",                   "Sets",                         "Set"),
    "editor.exercise.rest":     ("Pause",                   "Rest",                         "Mola"),
    "editor.exercise.distanceKm": ("Distanz (km)",          "Distance (km)",                "Mesafe (km)"),
    "editor.exercise.smartOff": ("Aus = das Gewicht wird nie automatisch geändert. Du behältst die volle Kontrolle.",
                                  "Off = weight never auto-adjusts. You stay in full control.",
                                  "Kapalı = ağırlık asla otomatik değişmez. Kontrol sende."),

    # ExercisePickerView.swift
    "picker.exercise.title":    ("Übung wählen",            "Choose Exercise",              "Hareket Seç"),
    "picker.exercise.filterFor": ("Nur Übungen für %@",     "Only %@ exercises",            "Sadece %@ hareketleri"),
    "picker.exercise.filterHint": ("Wenn aus, siehst du auch Übungen, die zu deinem Plan-Typ nicht passen. Die App fragt dann beim Hinzufügen nach, ob du den Plan umstellen willst.",
                                    "When off, you also see exercises that don't fit your plan type. The app asks when adding whether to switch the plan.",
                                    "Kapalıyken plan tipine uymayan hareketleri de görürsün. Eklerken plan değişimi sorulur."),
    "picker.exercise.namePlaceholder": ("Name (z.B. Bankdrücken)",
                                         "Name (e.g. Bench Press)",
                                         "Ad (örn. Bench Press)"),
    "picker.exercise.libraryEmpty": ("Bibliothek ist leer — leg oben deine erste eigene Übung an.",
                                      "Library is empty — create your first custom exercise above.",
                                      "Kütüphane boş — yukarıdan ilk özel hareketini oluştur."),

    # OnboardingQuizView.swift
    "quiz.title":               ("Plan finden",             "Find a Plan",                  "Plan Bul"),
    "quiz.result.topMatch":     ("TOP EMPFEHLUNG FÜR DICH", "TOP MATCH FOR YOU",            "SENİN İÇİN EN İYİ EŞLEŞME"),
    "quiz.result.choose":       ("Diesen Plan wählen",      "Choose This Plan",             "Bu Planı Seç"),

    # ProgramTemplatePickerView.swift
    "picker.plan.title":        ("Programm wählen",         "Choose Program",               "Program Seç"),
    "picker.plan.filterFootnote": ("Gefiltert nach deinem Trainingsort (%@). Im Profil anpassen, wenn du auch andere Pläne sehen willst.",
                                     "Filtered by your training location (%@). Adjust in profile to see other plans.",
                                     "Antrenman yerine göre filtrelendi (%@). Diğer planları görmek için profilden ayarla."),
    "picker.plan.adoptFootnote": ("Beim Übernehmen wird eine Tiefkopie für deine eigene Bibliothek angelegt — Tage, Übungen, Sätze sind danach frei editierbar.",
                                    "Adopting creates a deep copy in your library — days, exercises, and sets are then freely editable.",
                                    "Plan alındığında kütüphanende derin kopya oluşturulur — günler, hareketler ve setler özgürce düzenlenebilir."),
    "plan.dayNumberLabel":      ("Tag %lld",                "Day %lld",                     "Gün %lld"),

    # ──────────────────────────────────────────────────────────────────
    # PR1 Batch 2 — PlansListView + WorkoutSummaryView
    # ──────────────────────────────────────────────────────────────────

    # PlansListView.swift
    "plans.active.title":       ("Laufendes Training",      "Active Workout",               "Aktif Antrenman"),
    "plans.active.hint":        ("Tippe auf das Banner, um mit der Session weiterzumachen oder sie zu beenden.",
                                  "Tap the banner to resume or end the session.",
                                  "Banner'a dokunarak oturuma devam et veya bitir."),
    "plans.list.title":         ("Pläne",                   "Plans",                        "Planlar"),
    "plans.duplicate":          ("Duplizieren",             "Duplicate",                    "Çoğalt"),
    "plans.create.fromTemplate": ("Aus Template anlegen",   "From Template",                "Şablondan Oluştur"),
    "plans.create.empty":       ("Leerer Plan",             "Empty Plan",                   "Boş Plan"),
    "plans.create.fromTemplateShort": ("Aus Template",      "From Template",                "Şablondan"),
    "plans.create.emptyShort":  ("Leer",                    "Empty",                        "Boş"),
    "plans.new":                ("Neuer Plan",              "New Plan",                     "Yeni Plan"),
    "plans.empty.title":        ("Noch kein Plan",          "No plans yet",                 "Henüz plan yok"),
    "plans.empty.hint":         ("Lege deinen ersten Trainings-Plan an — Tage, Übungen, Sätze. Der Plan ist die Grundlage für jede Session.",
                                  "Create your first training plan — days, exercises, sets. The plan is the foundation of every session.",
                                  "İlk antrenman planını oluştur — günler, hareketler, setler. Plan, her oturumun temelidir."),
    "plans.activeBadge":        ("Aktiv",                   "Active",                       "Aktif"),

    # WorkoutSummaryView.swift
    "summary.editTitle":        ("Workout bearbeiten",      "Edit Workout",                 "Antrenmanı Düzenle"),
    "summary.detailTitle":      ("Workout-Detail",          "Workout Details",              "Antrenman Detayı"),
    "summary.title":            ("Zusammenfassung",         "Summary",                      "Özet"),
    "summary.date":             ("Datum",                   "Date",                         "Tarih"),
    "summary.duration":         ("Dauer",                   "Duration",                     "Süre"),
    "summary.durationMinutes":  ("%lld Min",                "%lld min",                     "%lld dk"),
    "summary.prFooter":         ("Erkannt durch Vergleich mit allen vorherigen abgeschlossenen Sessions. Cardio bleibt aussen vor — andere Metrik-Domäne.",
                                  "Detected by comparing all previous completed sessions. Cardio excluded — different metric domain.",
                                  "Tüm önceki tamamlanan oturumlar ile karşılaştırarak tespit edildi. Kardiyo dahil değil — farklı metrik."),
    "summary.progressionFooter": ("Ziel erreicht? Die App passt das Gewicht fürs nächste Workout automatisch an. Änderbar pro Übung im Editor.",
                                   "Target hit? The app adjusts the weight for next workout automatically. Adjustable per exercise in the editor.",
                                   "Hedefe ulaşıldı mı? Uygulama bir sonraki antrenman için ağırlığı otomatik ayarlar. Editörde hareket başına düzenlenebilir."),
    "summary.note.placeholder": ("Wie war's? Schmerzen, Pump, Performance ...",
                                  "How was it? Pain, pump, performance ...",
                                  "Nasıldı? Ağrı, pump, performans ..."),
    "summary.note.label":       ("Notiz",                   "Note",                         "Not"),
    "summary.note.footer":      ("Tauchen später in der History pro Session auf — gut für Form-Cues und Verletzungs-Tracking.",
                                  "Show up later in history per session — useful for form cues and injury tracking.",
                                  "Geçmişte oturum başına görünür — form ipuçları ve sakatlık takibi için faydalı."),
    "summary.setsHeader":       ("Sätze",                   "Sets",                         "Setler"),
    "summary.setsEmpty":        ("Keine Sätze geloggt.",    "No sets logged.",              "Set kaydedilmedi."),
    "summary.finishFooter":     ("Die Session ist bereits gespeichert. Der Button schließt die Zusammenfassung und bringt dich zurück aufs Dashboard.",
                                   "Session is already saved. The button closes the summary and returns you to the dashboard.",
                                   "Oturum zaten kaydedildi. Buton özeti kapatır ve seni panele döndürür."),

    # ──────────────────────────────────────────────────────────────────
    # PR1 Batch 2b — DayEditorView
    # ──────────────────────────────────────────────────────────────────
    "day.editor.untitled":              ("Tag",                     "Day",                  "Gün"),
    "day.editor.equipmentConflict.title": ("Equipment-Konflikt",    "Equipment Conflict",   "Ekipman Çakışması"),
    "day.editor.equipmentConflict.switchPlan": ("Plan auf %@ umstellen",
                                                 "Switch plan to %@",
                                                 "Planı %@ olarak değiştir"),
    "day.editor.equipmentConflict.justAdd": ("Nur Übung hinzufügen", "Add exercise only",   "Sadece hareketi ekle"),
    "day.editor.equipmentConflict.message": ("„%1$@\" erfordert Equipment, das in %2$@-Plänen normalerweise nicht verfügbar ist. Möchtest du den Plan-Typ entsprechend anpassen?",
                                               "\"%1$@\" requires equipment that's not normally available in %2$@ plans. Want to adjust the plan type?",
                                               "\"%1$@\" %2$@ planlarında genellikle bulunmayan ekipman gerektirir. Plan tipini değiştirmek ister misin?"),
    "session.recovery.resume":          ("Fortsetzen",              "Continue",             "Devam et"),
    "session.recovery.saveAndRestart":  ("Speichern & neu starten", "Save & Restart",       "Kaydet ve Yeniden Başlat"),
    "session.recovery.discardAndRestart": ("Verwerfen & neu starten", "Discard & Restart", "Sil ve Yeniden Başlat"),
    "session.recovery.message.withInfo": ("Es gibt bereits ein angefangenes Training (%1$@, gestartet %2$@). Was möchtest du tun?",
                                            "There's already an active session (%1$@, started %2$@). What would you like to do?",
                                            "Zaten devam eden bir oturum var (%1$@, başlatıldı %2$@). Ne yapmak istersin?"),
    "session.recovery.message.fallback": ("Es gibt bereits ein angefangenes Training.",
                                            "There's already an active session.",
                                            "Zaten devam eden bir oturum var."),
    "session.recovery.dayName.unknown": ("Unbekannt",               "Unknown",              "Bilinmiyor"),
    "day.restDay.title":                ("Ruhetag",                 "Rest Day",             "Dinlenme Günü"),
    "day.restDay.heroMessage":          ("Regeneration ist Teil des Plans. Hak den Tag ab, wenn du durch bist — dein Plan-Pointer springt automatisch zum nächsten echten Training.",
                                          "Recovery is part of the plan. Check off the day when you're done — your plan pointer jumps to the next real training day automatically.",
                                          "Toparlanma planın bir parçasıdır. Bitince günü işaretle — plan işaretçisi otomatik olarak bir sonraki gerçek antrenman gününe atlar."),
    "day.restDay.complete":             ("Ruhetag abschließen",     "Complete Rest Day",    "Dinlenme Gününü Tamamla"),
    "day.restDay.complete.footer":      ("Markiert den Ruhetag als erledigt — kein leerer Eintrag in der History, aber der Plan-Pointer rückt zum nächsten echten Training.",
                                           "Marks the rest day as done — no empty history entry, but the plan pointer advances to the next real training day.",
                                           "Dinlenme gününü tamamlandı olarak işaretler — geçmişte boş kayıt olmaz ama plan işaretçisi bir sonraki gerçek antrenmana ilerler."),
    "day.editor.field.name":            ("Name",                    "Name",                 "Ad"),
    "day.editor.field.weekday":         ("Wochentag",               "Weekday",              "Gün"),
    "day.editor.field.type":            ("Typ",                     "Type",                 "Tip"),
    "day.editor.field.nextIntensity":   ("Nächste Intensität",      "Next Intensity",       "Sonraki Yoğunluk"),
    "day.editor.section.info":          ("Tag-Info",                "Day Info",             "Gün Bilgisi"),
    "day.editor.section.exercises":     ("Übungen",                 "Exercises",            "Hareketler"),
    "day.editor.templateLocked.footer": ("Dieser Tag gehört zu einem vorgefertigten Plan-Template und kann strukturell nicht bearbeitet werden. Du kannst aber die Trainings-Intensität anpassen.",
                                          "This day belongs to a built-in plan template and can't be edited structurally. You can adjust training intensity though.",
                                          "Bu gün hazır bir plan şablonuna ait ve yapısal olarak düzenlenemez. Ancak antrenman yoğunluğunu ayarlayabilirsin."),
    "day.editor.templateLocked.exercises": ("Template-Plan — Übungen sind festgelegt. Du kannst sie ansehen, aber nicht hinzufügen, entfernen oder umsortieren.",
                                              "Template plan — exercises are fixed. You can view them but not add, remove, or reorder.",
                                              "Şablon plan — hareketler sabit. Görüntüleyebilirsin ama ekleyemez, kaldıramaz veya sıralayamazsın."),
    "day.editor.start":                 ("Training starten",        "Start Workout",        "Antrenmanı Başlat"),
    "day.editor.start.hintEmpty":       ("Füge erst mindestens eine Übung hinzu, dann kannst du das Training starten.",
                                          "Add at least one exercise first to start the workout.",
                                          "Antrenmanı başlatmak için önce en az bir hareket ekle."),
    "day.editor.exercises.restDayEmpty": ("Ruhetag — keine Übungen.", "Rest day — no exercises.", "Dinlenme günü — hareket yok."),
    "day.editor.exercises.empty":       ("Noch keine Übungen.",     "No exercises yet.",    "Henüz hareket yok."),
    "day.editor.exercises.editHint":    ("Tippe eine Übung an um sie zu bearbeiten. „Bearbeiten\" oben rechts aktiviert die Drag-Handles zum Umsortieren — Superset-Partner werden automatisch mit verschoben.",
                                          "Tap an exercise to edit. \"Edit\" top-right enables drag handles for reordering — superset partners move together.",
                                          "Düzenlemek için bir harekete dokun. Sağ üstteki \"Düzenle\" sıralama tutamaçlarını etkinleştirir — süperset eşleri birlikte hareket eder."),
    "day.editor.superset.link":         ("Verbinden",               "Link",                 "Bağla"),
    "day.editor.superset.unlink":       ("Trennen",                 "Unlink",                "Ayır"),
    "day_intensity.light":              ("Leicht",                  "Light",                "Hafif"),
    "day_intensity.normal":             ("Normal",                  "Normal",               "Normal"),
    "day_intensity.heavy":              ("Schwer",                  "Heavy",                "Ağır"),

    # ──────────────────────────────────────────────────────────────────
    # PR1 Batch 3a — OnboardingView (~30 Strings)
    # ──────────────────────────────────────────────────────────────────
    "onboarding.health.title":          ("Apple Health verbinden",  "Connect Apple Health", "Apple Health'i Bağla"),
    "onboarding.health.intro":          ("Wenn du Apple Health verbindest, ziehen wir Alter, Geschlecht, Größe und Gewicht aus deinem Profil — du musst nichts doppelt tippen. Diesen Schritt kannst du auch überspringen.",
                                          "Connect Apple Health and we'll pull age, sex, height, and weight from your profile — no double-entry. You can also skip this step.",
                                          "Apple Health'i bağlarsan yaş, cinsiyet, boy ve kilonu profilinden çekeriz — iki kere yazmana gerek yok. Bu adımı atlayabilirsin."),
    "onboarding.health.unavailable":    ("Apple Health ist auf diesem Gerät nicht verfügbar.",
                                          "Apple Health is not available on this device.",
                                          "Apple Health bu cihazda kullanılamıyor."),
    "onboarding.health.connected":      ("Verbunden",               "Connected",            "Bağlı"),
    "onboarding.health.pulled":         ("Daten übernommen — du kannst sie im nächsten Schritt prüfen.",
                                          "Data imported — review in the next step.",
                                          "Veriler alındı — bir sonraki adımda kontrol edebilirsin."),
    "onboarding.health.loading":        ("Lade …",                  "Loading …",            "Yükleniyor …"),
    "onboarding.health.pull":           ("Daten aus Apple Health übernehmen",
                                          "Import from Apple Health",
                                          "Apple Health'ten Al"),
    "onboarding.health.denied":        ("Apple Health-Berechtigung verweigert. Aktiviere sie später in iOS-Einstellungen → Datenschutz → Apple Health → Deltiq.",
                                          "Apple Health permission denied. Enable it later in iOS Settings → Privacy → Apple Health → Deltiq.",
                                          "Apple Health izni reddedildi. iOS Ayarlar → Gizlilik → Apple Health → Deltiq'ten etkinleştirebilirsin."),
    "onboarding.field.heightCm":        ("Größe (cm)",              "Height (cm)",          "Boy (cm)"),
    "onboarding.field.weightCurrentKg": ("Aktuelles Gewicht (kg)",  "Current Weight (kg)",  "Mevcut Kilo (kg)"),
    "onboarding.section.body":          ("Körperdaten",             "Body Metrics",         "Vücut Ölçüleri"),
    "onboarding.body.weightZero":       ("Gewicht muss > 0 sein.",  "Weight must be > 0.",  "Kilo > 0 olmalı."),
    "onboarding.body.weightRequired":   ("Pflichtfeld — wird als erste Messung gespeichert.",
                                          "Required — saved as your first measurement.",
                                          "Zorunlu — ilk ölçüm olarak kaydedilir."),
    "onboarding.body.weightInitial":    ("Wird im Hintergrund als initiale Messung gespeichert.",
                                          "Saved in the background as your initial measurement.",
                                          "Arka planda ilk ölçüm olarak kaydedilir."),
    "onboarding.field.goalWeightKg":    ("Zielgewicht (kg, optional)", "Goal Weight (kg, optional)", "Hedef Kilo (kg, opsiyonel)"),
    "onboarding.environment.footnote1": ("Trainingsort filtert Plan-Empfehlungen und die Equipment-Auswahl beim Übungs-Tausch.",
                                           "Training location filters plan recommendations and equipment options when swapping exercises.",
                                           "Antrenman yeri plan önerilerini ve hareket değiştirirken ekipman seçeneklerini filtreler."),
    "onboarding.environment.footnote2": ("Hybrid- oder reine Lauf-Athleten wählen ihren Strength-Ort — die Hybrid-Pläne enthalten ihre Run-Tage unabhängig davon.",
                                           "Hybrid or pure running athletes pick their strength location — Hybrid plans include run days regardless.",
                                           "Hibrit veya saf koşu sporcuları güç antrenman yerini seçer — Hibrit planlar koşu günlerini her durumda içerir."),
    "onboarding.goal.title":            ("Was ist dein primärer Fokus?", "What's your primary focus?", "Birincil odağın ne?"),
    "onboarding.goal.subtitle":         ("Wir kalibrieren Insights, Recovery-Hinweise und Coaching-Botschaften entsprechend.",
                                          "We calibrate insights, recovery hints, and coaching messages accordingly.",
                                          "Öngörüleri, toparlanma ipuçlarını ve koçluk mesajlarını buna göre ayarlarız."),
    "onboarding.tone.title":            ("Wie soll dein Coach klingen?",
                                          "How should your coach sound?",
                                          "Koçun nasıl bir ses tonu olsun?"),
    "onboarding.tone.subtitle":         ("Wir passen Tonfall und Feedback an deinen Stil an. Lässt sich später ändern.",
                                          "We adapt tone and feedback to your style. Changeable later.",
                                          "Ton ve geri bildirimi tarzına uyarlarız. Sonradan değiştirilebilir."),
    "onboarding.notif.water":           ("Wasser-Erinnerung",       "Water Reminder",       "Su Hatırlatıcısı"),
    "onboarding.notif.measurement":     ("Mess-Erinnerung",         "Measurement Reminder", "Ölçüm Hatırlatıcısı"),
    "onboarding.notif.section":         ("Benachrichtigungen",      "Notifications",        "Bildirimler"),
    "onboarding.notif.footnote":       ("Beide nutzen lokale Notifications. Beim Aktivieren fragt iOS einmalig nach der Berechtigung.",
                                          "Both use local notifications. iOS asks once for permission when enabled.",
                                          "Her ikisi de yerel bildirimleri kullanır. Etkinleştirildiğinde iOS bir kez izin ister."),
    "onboarding.plan.quizCard.title":   ("Plan finden lassen",      "Find a Plan",          "Plan Bul"),
    "onboarding.plan.quizCard.subtitle": ("4 kurze Fragen — wir matchen dich auf den passenden Plan.",
                                            "4 quick questions — we match you to the right plan.",
                                            "4 kısa soru — sana uygun planı eşleştiririz."),
    "onboarding.plan.recommended":      ("Empfohlen",               "Recommended",          "Önerilen"),
    "onboarding.plan.quizCard.footnote": ("Empfohlen, wenn du nicht weißt, welcher Plan zu dir passt. Du kannst stattdessen auch direkt aus der Liste unten wählen.",
                                            "Recommended if you're not sure which plan fits. You can also pick directly from the list below.",
                                            "Hangi planın sana uygun olduğundan emin değilsen önerilir. Aşağıdaki listeden de doğrudan seçebilirsin."),
    "onboarding.plan.noTemplates":      ("Keine Templates für '%@'. Du kannst trotzdem ohne Plan starten und später einen eigenen anlegen.",
                                          "No templates for '%@'. You can still start without a plan and create your own later.",
                                          "'%@' için şablon yok. Plansız başlayıp sonradan kendi planını oluşturabilirsin."),
    "onboarding.plan.section":          ("Trainingsplan für %@",    "Plans for %@",         "%@ için Plan"),
    "onboarding.plan.footnote":         ("Templates sind nach deinem Trainingsort gefiltert (%@). Auch ohne Plan starten ist okay.",
                                          "Templates are filtered by your training location (%@). Starting without a plan is fine too.",
                                          "Şablonlar antrenman yerine göre filtrelendi (%@). Plansız başlamak da mümkün."),

    # ──────────────────────────────────────────────────────────────────
    # PR1 Batch 3b — ProfileEditorView
    # ──────────────────────────────────────────────────────────────────
    "profile.envSwap.title":            ("Trainingsort geändert",   "Training Location Changed", "Antrenman Yeri Değişti"),
    "profile.envSwap.confirm":          ("Ja, Pläne anpassen",      "Yes, Adjust Plans",    "Evet, Planları Ayarla"),
    "profile.envSwap.keep":             ("Nein, so lassen",         "No, Keep As-Is",       "Hayır, Olduğu Gibi Bırak"),
    "profile.envSwap.message":          ("Du hast deinen Trainingsort auf %@ geändert. Sollen deine bestehenden Trainingspläne automatisch an das dort verfügbare Equipment angepasst werden?",
                                          "You changed your training location to %@. Should existing plans be auto-adjusted to the equipment available there?",
                                          "Antrenman yerini %@ olarak değiştirdin. Mevcut planlar oradaki ekipmana otomatik uyarlanmalı mı?"),
    "profile.envRestore.title":         ("Ursprüngliche Übungen wiederherstellen?",
                                          "Restore Original Exercises?",
                                          "Orijinal Hareketler Geri Yüklensin mi?"),
    "profile.envRestore.confirm":       ("Ja, wiederherstellen",    "Yes, Restore",         "Evet, Geri Yükle"),
    "profile.envRestore.adjustNew":     ("Nein, neu anpassen",      "No, Re-Adjust",        "Hayır, Yeniden Uyarla"),
    "profile.envRestore.message":      ("Wir haben Original-Übungen aus einem früheren Equipment-Wechsel gespeichert. Möchtest du diese in deinen Plänen wiederherstellen (inkl. der letzten Arbeitsgewichte)?",
                                          "We saved original exercises from a previous equipment change. Restore them in your plans (with the last working weights)?",
                                          "Önceki bir ekipman değişikliğinden orijinal hareketleri kaydettik. Bunları planlarına geri yüklemek ister misin (son çalışma ağırlıklarıyla)?"),
    "profile.health.pull":              ("Aus Apple Health übernehmen", "Import from Apple Health", "Apple Health'ten Al"),
    "profile.health.pulled":            ("Aus Apple Health übernommen: %@",
                                          "Imported from Apple Health: %@",
                                          "Apple Health'ten alındı: %@"),
    "profile.health.denied":            ("Berechtigung verweigert. Aktiviere sie in iOS-Einstellungen → Datenschutz → Apple Health → Deltiq.",
                                          "Permission denied. Enable it in iOS Settings → Privacy → Apple Health → Deltiq.",
                                          "İzin reddedildi. iOS Ayarlar → Gizlilik → Apple Health → Deltiq'ten etkinleştir."),
    "profile.section.health":           ("Apple Health",            "Apple Health",         "Apple Health"),
    "profile.health.footer":            ("Pre-fill von Geburtsdatum, Geschlecht und Größe aus dem Apple-Health-Profil. Manuelle Eingaben werden NICHT überschrieben, wenn sie schon plausible Werte haben.",
                                          "Pre-fills date of birth, sex, and height from Apple Health. Manual entries are NOT overwritten if they already have plausible values.",
                                          "Apple Health profilinden doğum tarihi, cinsiyet ve boyu önceden doldurur. Manuel girişler makul değer içeriyorsa ÜZERİNE YAZILMAZ."),
    "profile.section.person":           ("Person",                  "Person",               "Kişi"),
    "profile.person.footer":            ("Sex steuert die Navy/Deurenberg-Formeln; das Alter geht in Mifflin-St-Jeor-BMR und Deurenberg ein.",
                                          "Sex drives the Navy/Deurenberg formulas; age feeds into Mifflin-St-Jeor BMR and Deurenberg.",
                                          "Cinsiyet Navy/Deurenberg formüllerini etkiler; yaş Mifflin-St-Jeor BMR ve Deurenberg'e dahil olur."),
    "profile.body.heightPlaceholder":   ("z.B. 180",                "e.g. 180",             "örn. 180"),
    "profile.section.body":             ("Körpermasse",             "Body Metrics",         "Vücut Ölçüleri"),
    "profile.body.plausible":           ("Plausibel: %1$lld–%2$lld cm.",
                                          "Plausible: %1$lld–%2$lld cm.",
                                          "Makul: %1$lld–%2$lld cm."),
    "profile.body.footerOk":            ("Alle Berechnungen lesen Höhe metrisch aus dieser Quelle.",
                                          "All calculations read height metrically from this source.",
                                          "Tüm hesaplamalar boyu metrik olarak bu kaynaktan okur."),
    "profile.goal.weightPlaceholder":   ("z.B. 75",                 "e.g. 75",              "örn. 75"),
    "profile.goal.footer":              ("Das Zielgewicht erscheint als grüne Linie im Dashboard-Trend-Chart. Trainingsort filtert später Plan-Empfehlungen.",
                                          "Goal weight shows as a green line in the dashboard trend chart. Training location filters plan recommendations.",
                                          "Hedef kilo, panel trend grafiğinde yeşil çizgi olarak görünür. Antrenman yeri plan önerilerini filtreler."),
    "profile.coaching.goal":            ("Trainingsziel",           "Training Goal",        "Antrenman Hedefi"),
    "profile.coaching.tone":            ("Coaching-Stil",           "Coaching Style",       "Koçluk Tarzı"),
    "profile.section.coach":            ("Coach",                   "Coach",                "Koç"),
    "profile.coaching.footer":          ("Steuert Tonfall und Inhalt der Coaching-Insights auf dem Dashboard. Lässt sich jederzeit ändern.",
                                          "Drives tone and content of coaching insights on the dashboard. Changeable any time.",
                                          "Paneldeki koçluk öngörülerinin tonunu ve içeriğini yönlendirir. Her zaman değiştirilebilir."),
    "environment.gym":                  ("Gym",                     "Gym",                  "Salon"),

    # ──────────────────────────────────────────────────────────────────
    # PR1 Batch 3b/2 — PlanEditorView
    # ──────────────────────────────────────────────────────────────────
    "planEditor.globalSync.title":      ("Auch andere Pläne anpassen?",
                                          "Adjust Other Plans Too?",
                                          "Diğer Planlar da Ayarlansın mı?"),
    "planEditor.globalSync.allPlans":   ("Für alle anpassen",       "Adjust All",           "Hepsi için Ayarla"),
    "planEditor.globalSync.thisOnly":   ("Nur für diesen Plan",     "This Plan Only",       "Sadece Bu Plan"),
    "planEditor.globalSync.message":    ("Du hast mehrere aktive Pläne. Soll dein globaler Trainingsort und deine anderen aktiven Pläne ebenfalls auf %@ geändert werden?",
                                          "You have multiple active plans. Should your global training location and other active plans also switch to %@?",
                                          "Birden çok aktif planın var. Genel antrenman yerin ve diğer aktif planların da %@ olarak değişsin mi?"),
    "planEditor.envSwap.adapt":         ("Übungen anpassen",        "Adapt Exercises",      "Hareketleri Uyarla"),
    "planEditor.envSwap.justEnv":       ("Nur Trainingsort ändern", "Change Location Only", "Sadece Yeri Değiştir"),
    "planEditor.envSwap.message":      ("Sollen die Übungen an deinen neuen Trainingsort angepasst werden? Übungen ohne passende Alternative bleiben im Plan und brauchen manuelle Anpassung.",
                                          "Adapt exercises to the new training location? Exercises without a matching alternative stay in the plan and need manual adjustment.",
                                          "Hareketler yeni antrenman yerine uyarlansın mı? Uygun alternatifi olmayan hareketler planda kalır ve manuel ayarlama gerektirir."),
    "planEditor.envRestore.message":    ("Wir haben gespeicherte Original-Übungen aus einem früheren Equipment-Wechsel gefunden. Möchtest du diese wiederherstellen (inkl. der letzten Arbeitsgewichte aus der Historie), statt das aktuelle Setup neu anzupassen?",
                                          "We found saved original exercises from a previous equipment change. Restore them (with the last working weights from history) instead of re-adapting the current setup?",
                                          "Önceki bir ekipman değişikliğinden orijinal hareketler bulduk. Mevcut kurulumu yeniden uyarlamak yerine bunları (geçmişten son çalışma ağırlıklarıyla) geri yüklemek ister misin?"),
    "planEditor.template.banner.title": ("Template-Plan",           "Template Plan",        "Şablon Plan"),
    "planEditor.template.banner.subtitle": ("Struktur ist festgelegt. Du kannst Trainingsort und Wochen anpassen, aber Name/Tage/Übungen nicht ändern.",
                                              "Structure is fixed. You can adjust training location and weeks, but not name/days/exercises.",
                                              "Yapı sabit. Antrenman yerini ve haftaları ayarlayabilirsin ama ad/günler/hareketleri değiştiremezsin."),
    "planEditor.section.info":          ("Plan-Info",               "Plan Info",            "Plan Bilgisi"),
    "planEditor.section.settings":      ("Einstellungen",           "Settings",             "Ayarlar"),
    "planEditor.field.weeks":           ("Wochen",                  "Weeks",                "Hafta"),
    "planEditor.toggle.setActive":      ("Als aktiven Plan setzen", "Set as Active Plan",   "Aktif Plan Olarak Ayarla"),
    "planEditor.progressRIR.label":     ("Progressions-Ziel-RIR",   "Progression Target RIR", "İlerleme Hedef RIR"),
    "planEditor.progressRIR.auto":      ("Auto (pro Übung)",        "Auto (per exercise)",  "Otomatik (hareket başına)"),
    "planEditor.progressRIR.0":         ("RIR ≤ 0 (zum Versagen)",  "RIR ≤ 0 (to failure)", "RIR ≤ 0 (yenilgiye)"),
    "planEditor.progressRIR.1":         ("RIR ≤ 1",                 "RIR ≤ 1",              "RIR ≤ 1"),
    "planEditor.progressRIR.2":         ("RIR ≤ 2",                 "RIR ≤ 2",              "RIR ≤ 2"),
    "planEditor.progressRIR.3":         ("RIR ≤ 3",                 "RIR ≤ 3",              "RIR ≤ 3"),
    "planEditor.days.empty.template":   ("Template hat keine Trainings-Tage konfiguriert (sollte nicht passieren).",
                                          "Template has no training days configured (shouldn't happen).",
                                          "Şablonun antrenman günleri yok (olmamalı)."),
    "planEditor.days.empty.user":       ("Noch keine Trainings-Tage. Tippe '+' oben rechts um deinen ersten Tag anzulegen.",
                                          "No training days yet. Tap '+' top-right to add your first day.",
                                          "Henüz antrenman günü yok. İlk gününü eklemek için sağ üstteki '+' simgesine dokun."),
    "planEditor.section.trainingDays":  ("Trainings-Tage",          "Training Days",        "Antrenman Günleri"),
    "planEditor.days.add.training":     ("Trainingstag",            "Training Day",         "Antrenman Günü"),
    "planEditor.days.footer.template":  ("Template — Tage sind festgelegt. Tippe einen Tag an, um die Übungen zu sehen.",
                                          "Template — days are fixed. Tap a day to see its exercises.",
                                          "Şablon — günler sabit. Hareketleri görmek için bir güne dokun."),
    "planEditor.days.footer.user":      ("Sortiert nach Wochentag (Mo-So). „Bearbeiten\" oben rechts aktiviert den Drag-Mode — die Wochentage rotieren entsprechend mit, du musst sie nicht einzeln umstellen.",
                                          "Sorted by weekday (Mon-Sun). \"Edit\" top-right enables drag mode — weekdays rotate accordingly, no manual reshuffle needed.",
                                          "Hafta gününe göre sıralandı (Pzt-Pzr). Sağ üstteki \"Düzenle\" sürükleme modunu etkinleştirir — hafta günleri uygun şekilde döner, tek tek değiştirmen gerekmez."),

    # ──────────────────────────────────────────────────────────────────
    # PR1 Batch 3c — ActiveWorkoutView
    # ──────────────────────────────────────────────────────────────────
    "active.addExercise":               ("Übung",                   "Exercise",             "Hareket"),
    "active.discard.message":           ("Die Session und alle %lld bisher geloggten Sätze gehen verloren.",
                                          "The session and all %lld logged sets will be lost.",
                                          "Oturum ve şimdiye kadar kaydedilen %lld set kaybolacak."),
    "active.interference.title":        ("Du hattest gestern eine harte Einheit",
                                          "You had a hard session yesterday",
                                          "Dün zorlu bir antrenmanın vardı"),
    "active.interference.message":      ("Erwäge heute, dein Ziel-RIR bei Beinübungen um +1 zu erhöhen, um dein ZNS nicht zu überlasten.",
                                          "Consider raising your target RIR on leg exercises by +1 today to avoid overloading your CNS.",
                                          "MSS'ni aşırı yüklemekten kaçınmak için bugün bacak hareketlerinde hedef RIR'ı +1 artırmayı düşün."),
    "active.interference.dismiss":      ("Banner schließen",        "Dismiss banner",       "Banner'ı kapat"),
    "active.empty.session.title":       ("Diese Session hat keine Übungen.",
                                          "This session has no exercises.",
                                          "Bu oturumda hareket yok."),
    "active.empty.session.message":     ("Vermutlich wurde der Plan-Tag nach dem Start geleert. Du kannst die Session verwerfen oder ohne Sätze beenden.",
                                          "The plan day was likely emptied after starting. Discard the session or finish without sets.",
                                          "Plan günü başlatıldıktan sonra muhtemelen boşaltıldı. Oturumu silebilir veya setsiz bitirebilirsin."),
    "active.empty.adhoc.title":         ("Dein Workout ist noch leer", "Your workout is empty", "Antrenmanın henüz boş"),
    "active.empty.adhoc.message":      ("Such dir aus der Library eine Übung — alles weitere passiert wie im Plan-Workout.",
                                          "Pick an exercise from the library — everything else works like a plan workout.",
                                          "Kütüphaneden bir hareket seç — gerisi plan antrenmanı gibi çalışır."),
    "active.addExerciseCTA":            ("Übung hinzufügen",        "Add Exercise",         "Hareket Ekle"),
    "active.discard.cta":               ("Workout abbrechen",       "Discard Workout",      "Antrenmanı Sil"),
    "active.placeholder.subtext":      ("Set-Logging mit Vorgaben & Rest-Timer • Live Activities folgen im Xcode-Target.",
                                          "Set logging with targets & rest timer • Live Activities arrive in the Xcode target.",
                                          "Hedefli set kaydı ve dinlenme zamanlayıcısı • Live Activities Xcode hedefinde gelir."),
    "active.finish.title":              ("Workout beenden",         "Finish Workout",       "Antrenmanı Bitir"),
    "active.finish.gear":               ("Verwendete Ausrüstung",   "Gear Used",            "Kullanılan Ekipman"),
    "active.finish.summary":            ("Dein Workout",            "Your Workout",         "Antrenmanın"),
    "active.summary.duration":          ("Dauer",                   "Duration",             "Süre"),
    "active.summary.sets":              ("Sätze",                   "Sets",                 "Set"),
    "active.summary.volume":            ("Volumen",                 "Volume",               "Hacim"),
    "active.finish.feeling.title":      ("Wie hat sich das Training angefühlt?",
                                          "How did the workout feel?",
                                          "Antrenman nasıl hissettirdi?"),
    "active.finish.feeling.message":   ("Die App nutzt das für die Progression: Wenn du am Limit warst, halten wir das Gewicht stabil — kein Zwangs-Plus.",
                                          "We use this for progression: when you were at the limit, we keep the weight stable — no forced increase.",
                                          "Bunu ilerleme için kullanırız: limitteydiysen ağırlığı sabit tutarız — zorla artırma yok."),
    "active.finish.feeling.noProgression": ("Kein Gewichts-Plus im nächsten Workout",
                                              "No weight increase next workout",
                                              "Sonraki antrenmanda ağırlık artışı yok"),
    "active.finish.save":               ("Workout speichern",       "Save Workout",         "Antrenmanı Kaydet"),

    # ──────────────────────────────────────────────────────────────────
    # PR2 Batch A — GearListView
    # ──────────────────────────────────────────────────────────────────
    "gear.list.empty.title":            ("Noch keine Ausrüstung",   "No gear yet",          "Henüz ekipman yok"),
    "gear.list.empty.description":      ("Lege deine Laufschuhe an, damit die App deine Kilometer automatisch trackt.",
                                          "Add your running shoes so the app tracks your kilometers automatically.",
                                          "Koşu ayakkabılarını ekle, uygulama kilometreni otomatik takip etsin."),
    "gear.list.empty.cta":              ("Schuh anlegen",           "Add Shoe",             "Ayakkabı Ekle"),
    "gear.list.footer":                 ("Cardio-Workouts buchen ihre Distanz automatisch auf den im Finish-Sheet ausgewählten Schuh.",
                                          "Cardio workouts log distance to the shoe selected in the finish sheet.",
                                          "Kardiyo antrenmanları, bitiş sayfasında seçilen ayakkabıya mesafe ekler."),
    "gear.list.title":                  ("Ausrüstung",              "Gear",                 "Ekipman"),
    "gear.inactive":                    ("INAKTIV",                 "INACTIVE",             "PASİF"),
    "gear.needsReplacement":            ("Schuh erneuern — Dämpfung erschöpft.",
                                          "Replace shoe — cushioning depleted.",
                                          "Ayakkabıyı değiştir — yastıklama tükendi."),
    "gear.editor.section.general":      ("Allgemein",               "General",              "Genel"),
    "gear.editor.field.name":           ("Name (z.B. Nike Pegasus 40)",
                                          "Name (e.g. Nike Pegasus 40)",
                                          "Ad (örn. Nike Pegasus 40)"),
    "gear.editor.field.type":           ("Typ",                     "Type",                 "Tip"),
    "gear.editor.type.shoe":            ("Laufschuh",               "Shoe",                 "Ayakkabı"),
    "gear.editor.type.bike":            ("Fahrrad",                 "Bike",                 "Bisiklet"),
    "gear.editor.toggle.active":        ("Aktiv (im Picker anbieten)", "Active (show in picker)", "Aktif (seçicide göster)"),
    "gear.editor.section.distance":     ("Distanz",                 "Distance",             "Mesafe"),
    "gear.editor.field.maxKm":          ("Max. km",                 "Max km",               "Maks. km"),
    "gear.editor.field.currentKm":      ("Bisherige km",            "Current km",           "Mevcut km"),
    "gear.editor.distance.footer":      ("Laufschuhe verlieren nach ~600–800 km ihre Dämpfung. Bei Erreichen des Maximums warnt die App.",
                                          "Running shoes lose cushioning after ~600–800 km. The app warns when you hit the max.",
                                          "Koşu ayakkabıları ~600–800 km sonra yastıklamasını kaybeder. Maks. ulaşıldığında uygulama uyarır."),
    "gear.editor.title.new":            ("Neue Ausrüstung",         "New Gear",             "Yeni Ekipman"),
    "gear.editor.title.edit":           ("Bearbeiten",              "Edit",                 "Düzenle"),

    # ──────────────────────────────────────────────────────────────────
    # PR2 Batch A — SettingsView (rest of the hardcoded strings)
    # ──────────────────────────────────────────────────────────────────
    "settings.profile.missing":         ("Kein Profil vorhanden — App neu starten oder zurücksetzen.",
                                          "No profile — restart or reset the app.",
                                          "Profil yok — uygulamayı yeniden başlat ya da sıfırla."),
    "settings.profile.years":           ("%lld Jahre",              "%lld years",           "%lld yaş"),
    "settings.profile.goal":            ("Ziel %@",                 "Goal %@",              "Hedef %@"),
    "settings.preferences.gear":        ("Ausrüstung & Schuhe",     "Gear & Shoes",         "Ekipman & Ayakkabı"),
    "settings.units.footer":            ("Die DB speichert immer metrisch. Diese Einstellung steuert nur die Anzeige in Eingabe-Feldern, im Hantel-Rechner und auf den Karten.",
                                          "DB always stores metric. This setting only changes display in inputs, the plate calculator, and cards.",
                                          "Veritabanı her zaman metrik kaydeder. Bu ayar sadece giriş alanlarında, plaka hesabında ve kartlarda görünümü değiştirir."),
    "settings.appearance.section":      ("Erscheinungsbild",        "Appearance",           "Görünüm"),
    "settings.appearance.system":       ("System",                  "System",               "Sistem"),
    "settings.appearance.light":        ("Hell",                    "Light",                "Açık"),
    "settings.appearance.dark":         ("Dunkel",                  "Dark",                 "Koyu"),
    "settings.appearance.footer":       ("Greift in alle Views der App. 'System' folgt der iOS-Einstellung.",
                                          "Applies to all views. 'System' follows iOS settings.",
                                          "Tüm görünümlerde geçerli. 'Sistem' iOS ayarını izler."),
    "settings.timer.section":           ("Pausen-Timer-Feedback",   "Rest Timer Feedback",  "Mola Zamanlayıcı Geri Bildirimi"),
    "settings.timer.sound":             ("Ton abspielen",           "Play sound",           "Ses çal"),
    "settings.timer.haptics":           ("Vibrieren",               "Vibrate",              "Titret"),
    "settings.timer.prCelebrations":    ("PR-Feiern",               "Celebrate PRs",        "PR'ı Kutla"),
    "settings.timer.footer":            ("Wird beim Ablauf des Pausen-Timers ausgelöst. Vibrations-Toggle hat auf iPads keine Wirkung. 'PR-Feiern' steuert Save-Screen-Popups, Live-Activity-Headline und lokale Benachrichtigungen — die Bestleistungen werden trotzdem im Trophy-Room gespeichert.",
                                          "Fires when the rest timer ends. Vibration has no effect on iPads. 'Celebrate PRs' drives save-screen popups, Live Activity headlines, and local notifications — PRs are saved to the Trophy Room either way.",
                                          "Mola zamanlayıcısı bittiğinde tetiklenir. Titreşim iPad'lerde etkisizdir. 'PR'ı Kutla' kaydetme ekranı pencerelerini, Live Activity başlıklarını ve yerel bildirimleri yönlendirir — PR'lar her durumda Kupa Odası'na kaydedilir."),
    "settings.workout.section":         ("Workout-Verhalten",       "Workout Behavior",     "Antrenman Davranışı"),
    "settings.workout.showWarmups":     ("Warmup & Cooldown anzeigen", "Show warmup & cooldown", "Isınma & Soğuma Göster"),
    "settings.workout.footer":          ("Wenn aus, werden Warmup- und Cooldown-Übungen während der Session ausgeblendet. Die Templates und deine Plan-Editierung bleiben unverändert — der Toggle wirkt nur auf den Live-Workout-Flow. Warmups sind ohnehin nie Pflicht: der „Workout speichern\"-Button bleibt immer klickbar, auch wenn du sie nicht abhakst.",
                                          "When off, warmup and cooldown exercises are hidden during the session. Templates and plan editing remain unchanged — only the live workout flow is affected. Warmups are never mandatory: 'Save Workout' stays tappable even if you skip them.",
                                          "Kapalıyken oturum sırasında ısınma ve soğuma hareketleri gizlenir. Şablonlar ve plan düzenleme değişmez — yalnızca canlı antrenman akışı etkilenir. Isınmalar zorunlu değildir: 'Antrenmanı Kaydet' onları atlasan bile aktif kalır."),
    "settings.reminders.section":       ("Erinnerungen",            "Reminders",            "Hatırlatıcılar"),
    "settings.reminders.water":         ("Wasser erinnern",         "Water reminder",       "Su hatırlat"),
    "settings.reminders.frequency":     ("Häufigkeit",              "Frequency",            "Sıklık"),
    "settings.reminders.every1h":       ("Jede Stunde",             "Every hour",           "Her saat"),
    "settings.reminders.every2h":       ("Alle 2 Stunden",          "Every 2 hours",        "Her 2 saat"),
    "settings.reminders.every3h":       ("Alle 3 Stunden",          "Every 3 hours",        "Her 3 saat"),
    "settings.reminders.every4h":       ("Alle 4 Stunden",          "Every 4 hours",        "Her 4 saat"),
    "settings.reminders.measurement":   ("Messung erinnern",        "Measurement reminder", "Ölçüm hatırlat"),
    "settings.reminders.time":          ("Uhrzeit",                 "Time",                 "Saat"),
    "settings.reminders.hour":          ("%lld:00 Uhr",             "%lld:00",              "%lld:00"),
    "settings.reminders.footer":        ("Lokale Benachrichtigungen — keine Server-Verbindung. Tippen auf eine Erinnerung öffnet direkt den passenden Tab.",
                                          "Local notifications — no server connection. Tapping a reminder opens the matching tab.",
                                          "Yerel bildirimler — sunucu bağlantısı yok. Bir hatırlatıcıya dokunmak doğru sekmeyi açar."),
    "settings.health.lastSync":         ("Letzter Sync",            "Last Sync",            "Son Senkronizasyon"),
    "settings.health.footer":           ("Bei aktivierter Verbindung wird im Messwerte-Formular das letzte Waagen-Gewicht vorausgefüllt. Beim Speichern werden Gewicht, KFA und Magere Masse zurück nach Apple Health geschrieben.",
                                          "When connected, the measurement form prefills your last scale weight. Saving writes weight, body fat %, and lean mass back to Apple Health.",
                                          "Bağlıyken ölçüm formu son tartı kilonu önceden doldurur. Kaydetme; kilo, yağ oranı ve yağsız kütleyi Apple Health'e yazar."),
    "settings.health.notSetup":         ("Nicht eingerichtet",      "Not set up",           "Kurulmadı"),
    "settings.health.connect":          ("Verbinden",               "Connect",              "Bağla"),
    "settings.health.denied":           ("Berechtigung verweigert", "Permission denied",    "İzin reddedildi"),
    "settings.health.unavailable":      ("Nicht verfügbar",         "Not available",        "Kullanılamıyor"),
    "settings.health.openIOSSettings":  ("In iOS-Einstellungen öffnen", "Open iOS Settings", "iOS Ayarlarını Aç"),
    "settings.about.version":           ("Version",                 "Version",              "Sürüm"),
    "settings.about.bundle":            ("Bundle",                  "Bundle",               "Bundle"),
    "settings.dangerZone.footer":       ("Löscht Profil, Messungen, Pläne, Trainings-Templates und Workout-Sessions vollständig. Die Apple-Health-Daten bleiben erhalten — die löscht du in der Health-App selber.",
                                          "Deletes profile, measurements, plans, training templates, and workout sessions completely. Apple Health data is preserved — delete that from the Health app.",
                                          "Profil, ölçümler, planlar, antrenman şablonları ve antrenman oturumlarını tamamen siler. Apple Health verileri korunur — onları Health uygulamasından silersin."),

    # ──────────────────────────────────────────────────────────────────
    # PR2 Batch B — Calculators (OneRepMax + TDEE + PlateCalc + Index)
    # ──────────────────────────────────────────────────────────────────

    # CalculatorsView (index)
    "calc.index.title":                 ("Rechner",                 "Calculators",          "Hesaplayıcılar"),
    "calc.index.plate.title":           ("Hantel-Rechner",          "Plate Calculator",     "Plaka Hesaplayıcı"),
    "calc.index.plate.subtitle":        ("Welche Plates für dein Zielgewicht — mit Inventar-Cap und visualer Stange.",
                                          "Which plates for your target weight — with inventory cap and visual bar.",
                                          "Hedef ağırlığın için hangi plakalar — envanter sınırı ve görsel barla."),
    "calc.index.1rm.title":             ("1RM-Rechner",             "1RM Calculator",       "1RM Hesaplayıcı"),
    "calc.index.1rm.subtitle":          ("Epley + Brzycki + Mittelwert, plus Trainings-%-Tabelle.",
                                          "Epley + Brzycki + average, plus a training-% table.",
                                          "Epley + Brzycki + ortalama, artı antrenman % tablosu."),
    "calc.index.tdee.title":            ("Kalorien-Rechner",        "Calorie Calculator",   "Kalori Hesaplayıcı"),
    "calc.index.tdee.subtitle":         ("BMR + TDEE aus deinem Profil und Aktivitäts-Level.",
                                          "BMR + TDEE from your profile and activity level.",
                                          "Profil ve aktivite seviyenden BMR + TDEE."),
    "calc.index.water.title":           ("Wasser-Tracker",          "Water Tracker",        "Su Takipçisi"),
    "calc.index.water.subtitle":        ("Tagesziel = Gewicht × 35 ml. Mit Quick-Add.",
                                          "Daily goal = weight × 35 ml. With quick-add.",
                                          "Günlük hedef = kilo × 35 ml. Hızlı ekleme ile."),
    "calc.index.footer":                ("Alle Rechner nutzen die gleiche Domain-Logik (FitnessAppCore) wie der Rest der App — Werte sind 1:1 mit Dashboard und MeasurementView.",
                                          "All calculators use the same domain logic (FitnessAppCore) as the rest of the app — values match dashboard and measurement view 1:1.",
                                          "Tüm hesaplayıcılar uygulamanın geri kalanıyla aynı domain mantığını (FitnessAppCore) kullanır — değerler panel ve ölçüm görünümü ile birebir eşleşir."),

    # OneRepMaxView
    "calc.1rm.weightPlaceholder":       ("z.B. 100",                "e.g. 100",             "örn. 100"),
    "calc.1rm.weightLabel":             ("Gewicht (%@)",            "Weight (%@)",          "Ağırlık (%@)"),
    "calc.1rm.reps":                    ("Wiederholungen",          "Reps",                 "Tekrar"),
    "calc.1rm.section.input":           ("Eingabe",                 "Input",                "Giriş"),
    "calc.1rm.input.footer":            ("Gültig für 1-36 Reps. Bei sehr hohen Reps wird die Schätzung unzuverlässig — die Formeln liefern nur für den Hypertrophie- bis Kraft-Bereich (~1-12 Reps) brauchbare Werte.",
                                          "Valid for 1-36 reps. Estimates get unreliable at very high reps — formulas work best in the hypertrophy-to-strength range (~1-12 reps).",
                                          "1-36 tekrar için geçerli. Çok yüksek tekrarlarda tahmin güvenilmez olur — formüller hipertrofi-güç aralığında (~1-12 tekrar) en iyi sonucu verir."),
    "calc.1rm.section.estimate":        ("Geschätztes 1RM",         "Estimated 1RM",        "Tahmini 1RM"),
    "calc.1rm.weightRequired":          ("Trag Gewicht > 0 ein.",   "Enter weight > 0.",    "Ağırlık > 0 gir."),
    "calc.1rm.row.average":             ("Mittelwert",              "Average",              "Ortalama"),
    "calc.1rm.tableEmpty":              ("Tabelle erscheint, sobald 1RM berechnet ist.",
                                          "Table shows up once the 1RM is calculated.",
                                          "1RM hesaplandığında tablo görünür."),
    "calc.1rm.section.percentages":     ("Trainings-Last (vom Mittelwert-1RM)",
                                          "Training Load (from average 1RM)",
                                          "Antrenman Yükü (ortalama 1RM'den)"),
    "calc.1rm.percentages.footer":      ("Rep-Hints sind Faustwerte. Effektive Reps hängen vom Trainings-Status und der Bewegung ab.",
                                          "Rep hints are rules of thumb. Actual reps depend on training status and the lift.",
                                          "Tekrar ipuçları yaklaşık değerlerdir. Gerçek tekrar; antrenman durumuna ve harekete bağlıdır."),
    "calc.1rm.repsHint":                ("~ %lld Reps",             "~ %lld reps",          "~ %lld tekrar"),

    # TDEEView
    "calc.tdee.title":                  ("Kalorien-Rechner",        "Calorie Calculator",   "Kalori Hesaplayıcı"),
    "calc.tdee.noProfile.title":       ("Kein Profil",             "No profile",           "Profil yok"),
    "calc.tdee.noProfile.message":      ("Lege erst dein Profil im Onboarding an.",
                                          "Set up your profile in onboarding first.",
                                          "Önce profilini başlangıçta oluştur."),
    "calc.tdee.section.profile":        ("Aus deinem Profil",       "From your profile",    "Profilinden"),
    "calc.tdee.age":                    ("Alter",                   "Age",                  "Yaş"),
    "calc.tdee.height":                 ("Größe",                   "Height",               "Boy"),
    "calc.tdee.weightLabel":            ("Gewicht (kg)",            "Weight (kg)",          "Ağırlık (kg)"),
    "calc.tdee.weightPlaceholder":      ("z.B. %@",                 "e.g. %@",              "örn. %@"),
    "calc.tdee.activity":               ("Aktivität",               "Activity",             "Aktivite"),
    "calc.tdee.section.input":          ("Aktuelles Gewicht & Aktivität",
                                          "Current Weight & Activity",
                                          "Mevcut Kilo & Aktivite"),
    "calc.tdee.section.results":        ("Energiebedarf",           "Energy Needs",         "Enerji İhtiyacı"),
    "calc.tdee.bmrMifflin":             ("BMR (Mifflin-St-Jeor)",   "BMR (Mifflin-St-Jeor)", "BMR (Mifflin-St-Jeor)"),
    "calc.tdee.bmrKatch":               ("BMR (Katch-McArdle)",     "BMR (Katch-McArdle)",  "BMR (Katch-McArdle)"),
    "calc.tdee.tdee":                   ("TDEE",                    "TDEE",                 "TDEE"),
    "calc.tdee.cut":                    ("Cut (-500)",              "Cut (-500)",           "Cut (-500)"),
    "calc.tdee.maintenance":            ("Erhaltung",               "Maintenance",          "Koruma"),
    "calc.tdee.bulk":                   ("Bulk (+300)",             "Bulk (+300)",          "Bulk (+300)"),
    "calc.tdee.weightRequired":         ("Trag dein aktuelles Gewicht ein.",
                                          "Enter your current weight.",
                                          "Mevcut kilonu gir."),

    # PlateCalculatorView
    "calc.plate.unit":                  ("Einheit",                 "Unit",                 "Birim"),
    "calc.plate.unit.footer":           ("App-weit umschaltbar. DB speichert immer metrisch — nur die Anzeige ändert sich.",
                                          "Switchable app-wide. DB always stores metric — only the display changes.",
                                          "Uygulama genelinde değiştirilebilir. Veritabanı her zaman metrik kaydeder — sadece görünüm değişir."),
    "calc.plate.target":                ("Zielgewicht (%@)",        "Target Weight (%@)",   "Hedef Ağırlık (%@)"),
    "calc.plate.bar":                   ("Stange (%@)",             "Bar (%@)",             "Bar (%@)"),
    "calc.plate.section.input":         ("Zielgewicht & Stange",    "Target & Bar",         "Hedef & Bar"),
    "calc.plate.maxTarget":             ("Maximal %1$@ %2$@ Zielgewicht.",
                                          "Max %1$@ %2$@ target weight.",
                                          "Maks. %1$@ %2$@ hedef ağırlık."),
    "calc.plate.maxBar":                ("Maximal %1$@ %2$@ Stange.",
                                          "Max %1$@ %2$@ bar.",
                                          "Maks. %1$@ %2$@ bar."),
    "calc.plate.section.results":       ("Ergebnis",                "Result",               "Sonuç"),
    "calc.plate.perSide":               ("Pro Seite",               "Per Side",             "Tarafa"),
    "calc.plate.loaded":                ("Geladen gesamt",          "Total Loaded",         "Yüklenen Toplam"),
    "calc.plate.shortOfTarget":         ("Mit deinem Inventar nur %1$@ %2$@ erreichbar (%3$@).",
                                          "Only %1$@ %2$@ reachable with your inventory (%3$@).",
                                          "Envanterinle sadece %1$@ %2$@ ulaşılabilir (%3$@)."),
    "calc.plate.resetInventory":        ("Inventar zurücksetzen",   "Reset Inventory",      "Envanteri Sıfırla"),
    "calc.plate.section.inventory":     ("Inventar pro Seite",      "Inventory Per Side",   "Tarafa Envanter"),

    # ──────────────────────────────────────────────────────────────────
    # PR2 Batch C — PRHistory + WaterTracker + WorkoutHistory
    # ──────────────────────────────────────────────────────────────────

    # PRHistoryView
    "trophy.rebuild.menu":              ("Aus History neu berechnen", "Recompute from history", "Geçmişten yeniden hesapla"),
    "trophy.rebuild.confirm.title":     ("Trophy Room neu berechnen?", "Recompute Trophy Room?", "Kupa Odası yeniden hesaplansın mı?"),
    "trophy.rebuild.confirm.cta":       ("Neu berechnen",           "Recompute",            "Yeniden hesapla"),
    "trophy.rebuild.confirm.message":   ("Setzt alle gespeicherten Rekorde zurück und detektiert sie aus deiner kompletten History neu. Nützlich nach gelöschten Sessions.",
                                          "Resets all saved records and re-detects them from your complete history. Useful after deleted sessions.",
                                          "Tüm kayıtlı rekorları sıfırlar ve geçmişinden yeniden tespit eder. Silinen oturumlardan sonra faydalı."),
    "trophy.empty.title":               ("Noch keine Rekorde",      "No records yet",       "Henüz rekor yok"),
    "trophy.empty.description.firstWorkout": ("Beende dein erstes Training, um deinen ersten PR aufzustellen.",
                                                "Finish your first workout to set your first PR.",
                                                "İlk PR'ını koymak için ilk antrenmanını bitir."),
    "trophy.empty.description.hasWorkouts":  ("Du hast bereits Workouts, aber noch keine Rekorde gespeichert. Klick unten, um sie aus deiner History zu detektieren.",
                                                "You have workouts but no records saved yet. Tap below to detect them from your history.",
                                                "Antrenmanların var ama henüz kayıtlı rekor yok. Geçmişinden tespit etmek için aşağıya dokun."),
    "trophy.empty.cta.detect":          ("Aus History detektieren", "Detect from History",  "Geçmişten Tespit Et"),
    "trophy.totalRecords":              ("%lld Rekorde gesamt",     "%lld records total",   "Toplam %lld rekor"),
    "trophy.singleEntry":               ("Nur ein %@-Eintrag — Trend ab 2 Rekorden.",
                                          "Only one %@ entry — trend starts at 2 records.",
                                          "Sadece bir %@ kaydı — trend 2 rekordan başlar."),

    # WaterTrackerView
    "water.title":                      ("Wasser",                  "Water",                "Su"),
    "water.resetToday":                 ("Heute zurücksetzen",      "Reset Today",          "Bugünü Sıfırla"),
    "water.goalReached":                ("Tagesziel erreicht",      "Daily goal reached",   "Günlük hedef ulaşıldı"),
    "water.remainingToGoal":            ("%lld ml bis zum Ziel",    "%lld ml to goal",      "Hedefe %lld ml"),
    "water.heroFooter":                 ("Tagesziel = Gewicht × 35 ml. Quelle: %@.",
                                          "Daily goal = weight × 35 ml. Source: %@.",
                                          "Günlük hedef = kilo × 35 ml. Kaynak: %@."),
    "water.ofTotal":                    ("ml von %lld",             "ml of %lld",           "ml / %lld"),
    "water.quickAdd.section":           ("Schnell-Eintrag",         "Quick Add",            "Hızlı Ekle"),
    "water.empty":                      ("Trag deinen ersten Schluck mit den Buttons oben ein.",
                                          "Log your first sip with the buttons above.",
                                          "İlk yudumu yukarıdaki butonlarla kaydet."),

    # WorkoutHistoryView
    "history.empty.title":              ("Noch keine Workouts",     "No workouts yet",      "Henüz antrenman yok"),
    "history.empty.description":        ("Beende dein erstes Training, um deine Historie zu sehen.",
                                          "Finish your first workout to see your history.",
                                          "Geçmişini görmek için ilk antrenmanını bitir."),

    # ──────────────────────────────────────────────────────────────────
    # DEL-118 — Workout-Detail-Format-Strings (DayRow + Plan-Template-Vorschau)
    # ──────────────────────────────────────────────────────────────────
    # Unified format: "<sets> Sätze • <reps> <Wdh|Sek> • <restSeconds>s Pause"
    # Cardio variant: "Cardio • <restSeconds>s Pause"
    "workout.detail.reps":              ("%1$lld Sätze • %2$@ Wdh • %3$llds Pause",
                                          "%1$lld sets • %2$@ reps • %3$llds rest",
                                          "%1$lld set • %2$@ tekrar • %3$llds mola"),
    "workout.detail.seconds":           ("%1$lld Sätze • %2$@ Sek • %3$llds Pause",
                                          "%1$lld sets • %2$@ sec • %3$llds rest",
                                          "%1$lld set • %2$@ sn • %3$llds mola"),
    "workout.detail.cardio":            ("Cardio • %llds Pause",
                                          "Cardio • %llds rest",
                                          "Kardiyo • %llds mola"),

    # ──────────────────────────────────────────────────────────────────
    # DEL-120 — Enum-Localization (Coaching/Training/Activity/Feeling)
    # ──────────────────────────────────────────────────────────────────

    # CoachingTone (DEL-100 — ProfileEditor + Onboarding)
    "coaching.tone.analytical":         ("Analytisch",              "Analytical",           "Analitik"),
    "coaching.tone.motivating":         ("Motivierend",             "Motivating",           "Motive Edici"),
    "coaching.tone.strict":             ("Streng",                  "Strict",               "Sıkı"),
    "coaching.tone.analytical.blurb":   ("Fakten & Daten. Neutrales Feedback zu Load und Progression.",
                                          "Facts & data. Neutral feedback on load and progression.",
                                          "Veriler ve gerçekler. Yük ve ilerleme hakkında nötr geri bildirim."),
    "coaching.tone.motivating.blurb":   ("Positiv & bestärkend. Fokus auf Erfolge und Erholung.",
                                          "Positive & encouraging. Focus on wins and recovery.",
                                          "Olumlu ve destekleyici. Başarılara ve iyileşmeye odaklı."),
    "coaching.tone.strict.blurb":       ("Direkt & fordernd. Klartext, wenn du vom Plan abweichst.",
                                          "Direct & demanding. Plain talk when you deviate from the plan.",
                                          "Doğrudan ve talepkar. Plandan sapınca net konuşur."),

    # TrainingGoal (DEL-100)
    "coaching.goal.hypertrophy":        ("Muskelaufbau",            "Muscle Building",      "Kas Gelişimi"),
    "coaching.goal.strength":           ("Maximalkraft",            "Maximum Strength",     "Maksimal Güç"),
    "coaching.goal.hybrid":             ("Funktionell / Hybrid",    "Functional / Hybrid",  "Fonksiyonel / Hibrit"),
    "coaching.goal.hypertrophy.blurb":  ("Volumen, Pump, sichtbares Muskelwachstum.",
                                          "Volume, pump, visible muscle growth.",
                                          "Hacim, pump, görünür kas gelişimi."),
    "coaching.goal.strength.blurb":     ("Maximales 1RM, niedrige Reps, schwere Hauptlifts.",
                                          "Max 1RM, low reps, heavy main lifts.",
                                          "Maksimum 1RM, düşük tekrar, ağır ana hareketler."),
    "coaching.goal.hybrid.blurb":       ("Kraft + Ausdauer + Mobilität — alles fließt zusammen.",
                                          "Strength + endurance + mobility — all flowing together.",
                                          "Güç + dayanıklılık + mobilite — hepsi bir arada."),

    # ExperienceLevel (DEL-090 Quiz)
    "experience.beginner":              ("Anfänger",                "Beginner",             "Başlangıç"),
    "experience.intermediate":          ("Fortgeschritten",         "Intermediate",         "Orta"),
    "experience.advanced":              ("Experte",                 "Advanced",             "İleri"),

    # GoalType (DEL-090 Quiz)
    "goalType.hypertrophy":             ("Muskeln aufbauen",        "Build Muscle",         "Kas Yap"),
    "goalType.strength":                ("Maximalkraft",            "Maximum Strength",     "Maksimal Güç"),
    "goalType.fatloss":                 ("Fett verbrennen",         "Burn Fat",             "Yağ Yak"),
    "goalType.hybrid":                  ("Athletisch werden",       "Become Athletic",      "Atletik Ol"),
    "goalType.functional":              ("Funktionelle Fitness",    "Functional Fitness",   "Fonksiyonel Fitness"),

    # SessionFeeling (DEL-057 Finish-Sheet)
    "feeling.great":                    ("Großartig",               "Great",                "Harika"),
    "feeling.good":                     ("Gut",                     "Good",                 "İyi"),
    "feeling.okay":                     ("Okay",                    "Okay",                 "İdare Eder"),
    "feeling.hard":                     ("Sehr schwer",             "Very Hard",            "Çok Zor"),
    "feeling.destroyed":                ("Zerstört / Am Limit",     "Destroyed / At Limit", "Bitik / Limitte"),

    # ActivityLevel (TDEE)
    "activity.sedentary":               ("Bürojob (1.2)",           "Sedentary (1.2)",      "Hareketsiz (1.2)"),
    "activity.light":                   ("Leicht aktiv (1.375)",    "Lightly Active (1.375)", "Az Hareketli (1.375)"),
    "activity.moderate":                ("Moderat (1.55)",          "Moderate (1.55)",      "Orta (1.55)"),
    "activity.active":                  ("Aktiv (1.725)",           "Active (1.725)",       "Aktif (1.725)"),
    "activity.veryActive":              ("Sehr aktiv (1.9)",        "Very Active (1.9)",    "Çok Aktif (1.9)"),
    "activity.sedentary.description":   ("Bürojob, kaum Bewegung neben dem Alltag.",
                                          "Office job, little movement outside daily routine.",
                                          "Ofis işi, günlük rutin dışında az hareket."),
    "activity.light.description":       ("1-2 leichte Trainings pro Woche.",
                                          "1-2 light workouts per week.",
                                          "Haftada 1-2 hafif antrenman."),
    "activity.moderate.description":    ("3-5 Trainings pro Woche (Default für Hobby-Lifter).",
                                          "3-5 workouts per week (default for hobby lifters).",
                                          "Haftada 3-5 antrenman (hobi sporcular için varsayılan)."),
    "activity.active.description":      ("6-7 Trainings pro Woche oder körperlicher Beruf.",
                                          "6-7 workouts per week or physical job.",
                                          "Haftada 6-7 antrenman ya da fiziksel iş."),
    "activity.veryActive.description":  ("Tag-täglich intensives Training oder schwere körperliche Arbeit.",
                                          "Daily intense training or heavy physical labor.",
                                          "Her gün yoğun antrenman ya da ağır fiziksel iş."),

    # DayType (für DayEditorView typeLabel)
    "dayType.chest":                    ("Brust",                   "Chest",                "Göğüs"),
    "dayType.back":                     ("Rücken",                  "Back",                 "Sırt"),
    "dayType.legs":                     ("Beine",                   "Legs",                 "Bacak"),
    "dayType.shoulders":                ("Schultern",               "Shoulders",            "Omuz"),
    "dayType.arms":                     ("Arme",                    "Arms",                 "Kol"),
    "dayType.push":                     ("Push",                    "Push",                 "Push"),
    "dayType.pull":                     ("Pull",                    "Pull",                 "Pull"),
    "dayType.upper":                    ("Oberkörper",              "Upper Body",           "Üst Vücut"),
    "dayType.lower":                    ("Unterkörper",             "Lower Body",           "Alt Vücut"),
    "dayType.fullBody":                 ("Ganzkörper",              "Full Body",            "Tüm Vücut"),
    "dayType.rest":                     ("Ruhetag",                 "Rest Day",             "Dinlenme Günü"),
    "dayType.custom":                   ("Custom",                  "Custom",               "Özel"),
    "dayType.cardio":                   ("Cardio / Run",            "Cardio / Run",         "Kardiyo / Koşu"),

    # Dashboard history teaser (DEL-019)
    "dashboard.history.empty":          ("Noch keine Trainings — starte oben dein erstes.",
                                          "No workouts yet — start your first one above.",
                                          "Henüz antrenman yok — yukarıdan ilkini başlat."),
    "dashboard.history.countWithLast":  ("%1$lld Trainings • zuletzt %2$@",
                                          "%1$lld workouts • last %2$@",
                                          "%1$lld antrenman • son %2$@"),
    "dashboard.history.countOnly":      ("%lld Trainings",          "%lld workouts",        "%lld antrenman"),

    # DEL-120 — Onboarding-Quiz Schritte
    "quiz.goal.title":                  ("Was ist dein primäres Ziel?",     "What's your primary goal?",        "Birincil hedefin ne?"),
    "quiz.goal.subtitle":               ("Wähle das, was dich aktuell am meisten antreibt.",
                                          "Pick what drives you most right now.",
                                          "Şu an seni en çok motive edeni seç."),
    "quiz.experience.title":            ("Wie viel Erfahrung hast du im Training?",
                                          "How much training experience do you have?",
                                          "Antrenmanda ne kadar deneyimin var?"),
    "quiz.experience.subtitle":         ("Wir wählen Programme, die dich nicht überfordern.",
                                          "We pick programs that won't overwhelm you.",
                                          "Seni zorlamayacak programlar seçeriz."),
    "quiz.days.title":                  ("Wie oft möchtest du pro Woche trainieren?",
                                          "How often do you want to train per week?",
                                          "Haftada ne sıklıkla antrenman yapmak istersin?"),
    "quiz.days.subtitle":               ("Sei realistisch — lieber 3 Tage konsistent als 6 geplant und nur 2 gemacht.",
                                          "Be realistic — 3 consistent days beat 6 planned and only 2 done.",
                                          "Gerçekçi ol — tutarlı 3 gün, planlanmış 6 ama yalnızca 2 yapılandan iyidir."),
    "quiz.days.option":                 ("%lld Tage",               "%lld days",            "%lld gün"),
    "quiz.environment.title":           ("Wo trainierst du meistens?",   "Where do you usually train?",     "Genelde nerede antrenman yapıyorsun?"),
    "quiz.environment.subtitle":        ("Wir filtern Programme, die zu deinem Equipment passen.",
                                          "We filter programs to match your equipment.",
                                          "Programları ekipmanına göre filtreleriz."),
    "quiz.environment.gym":             ("Fitnessstudio",           "Gym",                  "Salon"),
    "quiz.environment.homeGym":         ("Home-Gym (Kurzhanteln)",  "Home Gym (Dumbbells)", "Ev Salonu (Dambıllar)"),
    "quiz.environment.noEquipment":     ("Überall (ohne Geräte)",   "Anywhere (no equipment)", "Her yer (ekipmansız)"),
}


def upsert(strings, key, de, en, tr):
    """Upsert a key with DE/EN/TR. Only fills empty slots — never
    overwrites existing translations.  Returns (created?, slots_filled)."""
    if key not in strings:
        strings[key] = {"extractionState": "manual", "localizations": {}}
        created = True
    else:
        created = False
    entry = strings[key].setdefault("localizations", {})
    filled = 0
    for code, val in (("de", de), ("en", en), ("tr", tr)):
        existing = entry.get(code, {}).get("stringUnit", {}).get("value")
        if not existing:
            entry[code] = {"stringUnit": {"state": "translated", "value": val}}
            filled += 1
    return created, filled


def main():
    with open(XCSTRINGS, "r", encoding="utf-8") as f:
        data = json.load(f)
    strings = data["strings"]

    created = filled = 0
    for key, (de, en, tr) in KEYS.items():
        c, f = upsert(strings, key, de, en, tr)
        created += int(c)
        filled += f

    with open(XCSTRINGS, "w", encoding="utf-8") as ff:
        json.dump(data, ff, ensure_ascii=False, indent=2)
        ff.write("\n")
    print(f"DEL-117: {created} new keys, {filled} empty translation slots filled")


if __name__ == "__main__":
    main()
