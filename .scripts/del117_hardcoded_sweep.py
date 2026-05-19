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
