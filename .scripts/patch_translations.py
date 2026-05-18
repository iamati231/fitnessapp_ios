"""Apply EN/TR translations to Localizable.xcstrings.

Run from project root: python .scripts/patch_translations.py
"""
import json
import os

XCSTRINGS = os.path.join(
    os.path.dirname(__file__),
    "..",
    "Sources",
    "FitnessAppUI",
    "Resources",
    "Localizable.xcstrings",
)

# Full translation dictionary: key -> {"en": ..., "tr": ...}
# Sport-context-aware, consistent vocabulary.
T = {
    # active + common
    "active.action.discard": {"tr": "Sil"},
    "active.confirm.discard.title": {"tr": "Antrenmanı silmek istiyor musun?"},
    "active.confirm.finish.title": {"tr": "Antrenmanı bitirelim mi?"},
    "common.discard": {"tr": "Sil"},

    # coaching matrix
    "coaching.cnsOverloaded.analytical.hybrid": {
        "en": "Accumulated CNS load over threshold. Skip high-intensity cardio and heavy compounds today. Skill work and mobility are fine.",
        "tr": "Birikmiş MSS yükü eşiğin üzerinde. Bugün yüksek yoğunluklu kardiyo ve ağır temel hareketlere ara ver. Teknik çalışması ve mobilite uygundur.",
    },
    "coaching.cnsOverloaded.analytical.hypertrophy": {
        "en": "CNS load elevated. Hypertrophy stimuli are still productive, but pause compound lifts and focus on machine isolation.",
        "tr": "MSS yükü artmış. Hipertrofi uyarıları hâlâ verimli, ancak temel hareketlere ara ver ve makineli izolasyona odaklan.",
    },
    "coaching.cnsOverloaded.analytical.strength": {
        "en": "CNS load >90%. Heavy 1RM attempts are statistically inefficient today. Reduce intensity.",
        "tr": "MSS yükü %90 üzerinde. Bugün ağır 1RM denemeleri istatistiksel olarak verimsiz. Yoğunluğu azalt.",
    },
    "coaching.cnsOverloaded.motivating.hypertrophy": {
        "en": "You've worked incredibly hard! Give your nervous system some rest and focus on light isolation exercises today.",
        "tr": "Çok sıkı çalıştın! Bugün sinir sistemine biraz dinlenme ver ve hafif izolasyon hareketlerine odaklan.",
    },
    "coaching.cnsOverloaded.strict.hybrid": {
        "en": "Red zone. Your nervous system is fried. No heavy kettlebell swings today. Mobility work — or rest.",
        "tr": "Kırmızı bölge. Sinir sistemin bitik. Bugün ağır kettlebell swing yok. Mobilite ya da dinlen.",
    },
    "coaching.newPR.analytical.hybrid": {
        "en": "Performance increase detected. New volume PR achieved in the functional circuit. Progression is on track.",
        "tr": "Performans artışı tespit edildi. Fonksiyonel devrede yeni hacim PR'ı. İlerleme plan dahilinde.",
    },
    "coaching.newPR.analytical.hypertrophy": {
        "en": "New volume PR logged. Progressive overload is working — plan +1 set or +2 reps for the next micro-cycle.",
        "tr": "Yeni hacim PR'ı kaydedildi. Aşamalı yüklenme işliyor — bir sonraki mikro döngüde +1 set veya +2 tekrar planla.",
    },
    "coaching.newPR.analytical.strength": {
        "en": "New top-set PR. Estimated 1RM updated. Training maxes are being recalibrated in the background.",
        "tr": "Yeni en üst set PR'ı. Tahmini 1RM güncellendi. Antrenman maksimumları arka planda yeniden hesaplanıyor.",
    },
    "coaching.newPR.motivating.strength": {
        "en": "Incredible performance! New PR on the bar. That's how progressive overload works — celebrate your win!",
        "tr": "Muhteşem performans! Barda yeni PR. Aşamalı yüklenme tam olarak böyle çalışır — başarını kutla!",
    },
    "coaching.newPR.strict.hypertrophy": {
        "en": "New PR. Good. But don't get cocky — technique still has to be 100% in the next cycle. Keep working.",
        "tr": "Yeni PR. İyi. Ama kibre kapılma — sonraki döngüde de teknik %100 oturmalı. Çalışmaya devam.",
    },
    "coaching.plateauDetected.analytical.hybrid": {
        "en": "Plateau over 3+ weeks. Switch the stimulus: tempo, ROM, or exercise substitute — then a 5–7 day deload.",
        "tr": "3+ haftadır plato. Uyarıyı değiştir: tempo, hareket aralığı veya hareket değişimi — ardından 5–7 günlük deload.",
    },
    "coaching.plateauDetected.analytical.hypertrophy": {
        "en": "Stagnation detected for 3 weeks. Adjusting exercise selection or a deload week is recommended.",
        "tr": "3 haftalık durağanlık tespit edildi. Hareket seçimini değiştirmek veya bir deload haftası önerilir.",
    },
    "coaching.plateauDetected.analytical.strength": {
        "en": "Top-set progression is flattening. Add a variant (pin press, block pull) or take a deload week, then return to the main lift.",
        "tr": "En üst set ilerlemesi düzleşiyor. Varyant ekle (pin press, block pull) veya deload haftası al, sonra ana harekete dön.",
    },
    "coaching.plateauDetected.motivating.hybrid": {
        "en": "Totally normal to hit a wall every now and then! Let's change the stimulus — try a new movement pattern.",
        "tr": "Arada bir duraklamak son derece normal! Hadi uyarıyı değiştirelim — yeni bir hareket kalıbı dene.",
    },
    "coaching.plateauDetected.strict.strength": {
        "en": "You're stuck. Either you're under-eating, under-sleeping, or your plan needs a reset. Time for a deload.",
        "tr": "Sıkıştın. Ya yeterince yemiyorsun, ya uyumuyorsun, ya da planının sıfırlanması gerekiyor. Deload zamanı.",
    },
    "coaching.restDay.analytical.hybrid": {
        "en": "Rest day in your plan. Optional easy aerobic block (Z2, 30–45 min) for active recovery — otherwise, take it off.",
        "tr": "Planında dinlenme günü. İsteğe bağlı kolay aerobik blok (Z2, 30–45 dk) aktif iyileşme için — yoksa tamamen dinlen.",
    },
    "coaching.restDay.analytical.hypertrophy": {
        "en": "Recovery phase active. Muscle protein synthesis is running. Your next workout is scheduled for tomorrow.",
        "tr": "İyileşme aşaması aktif. Kas protein sentezi devam ediyor. Sonraki antrenman yarın için planlandı.",
    },
    "coaching.restDay.analytical.strength": {
        "en": "Recovery day. Your CNS is working now — your next 1RM is prepared today, not in the gym.",
        "tr": "İyileşme günü. MSS şu an çalışıyor — sonraki 1RM bugün hazırlanır, salonda değil.",
    },
    "coaching.restDay.motivating.hybrid": {
        "en": "You've earned a break! A light mobility flow or a walk is perfect for active recovery today.",
        "tr": "Bir mola hak ettin! Bugün hafif bir mobilite akışı veya yürüyüş aktif iyileşme için ideal.",
    },
    "coaching.restDay.strict.strength": {
        "en": "No training today. You get stronger on rest days, not under the barbell. Stay out of the gym.",
        "tr": "Bugün antrenman yok. Halterin altında değil, dinlenme günlerinde güçlenirsin. Salona girme.",
    },

    # dashboard
    "dashboard.action.adHoc.a11y": {
        "en": "Start a spontaneous workout — empty session without plan attachment",
        "tr": "Spontane antrenman başlat — plana bağlı olmayan boş oturum",
    },
    "dashboard.action.adHoc.primary": {"en": "Start spontaneous workout", "tr": "Spontane antrenman başlat"},
    "dashboard.action.adHoc.secondary": {"en": "Skip the plan — spontaneous workout", "tr": "Plandan sap — spontane antrenman"},
    "dashboard.action.resumeRunning": {"en": "Resume running workout", "tr": "Devam eden antrenmanı sürdür"},
    "dashboard.action.startDirect": {"en": "Start now", "tr": "Hemen başlat"},
    "dashboard.cardioChart.legend": {"en": "min/km · lower = better", "tr": "dk/km · daha düşük = daha iyi"},
    "dashboard.cardioChart.title": {"en": "Cardio Pace Trend", "tr": "Kardiyo Tempo Trendi"},
    "dashboard.compoundChart.empty.hint": {
        "en": "Once you log a compound lift across two sessions, the trend will appear here.",
        "tr": "Bir temel hareketi iki farklı oturumda kaydettiğinde, trend burada görünür.",
    },
    "dashboard.compoundChart.empty.title": {"en": "Not enough data yet", "tr": "Henüz yeterli veri yok"},
    "dashboard.compoundChart.legend": {"en": "Estimated 1RM", "tr": "Tahmini 1RM"},
    "dashboard.compoundChart.title": {"en": "Compound Lift Trend", "tr": "Temel Hareket Trendi"},
    "dashboard.goal.line": {"en": "Goal %@ kg", "tr": "Hedef %@ kg"},
    "dashboard.heatmap.legend": {"en": "Sets", "tr": "Set"},
    "dashboard.heatmap.title": {"en": "Muscle Heatmap (week)", "tr": "Kas Isı Haritası (hafta)"},
    "dashboard.history.empty": {
        "en": "No workouts yet — start your first one above.",
        "tr": "Henüz antrenman yok — yukarıdan ilkini başlat.",
    },
    "dashboard.history.title": {"en": "Workout History", "tr": "Antrenman Geçmişi"},
    "dashboard.newMeasurement": {"en": "New Measurement", "tr": "Yeni Ölçüm"},
    "dashboard.openSession.cancel": {"en": "Cancel", "tr": "İptal"},
    "dashboard.openSession.dayName.unknown": {"en": "Unknown", "tr": "Bilinmiyor"},
    "dashboard.openSession.discardAndStart": {"en": "Discard old & start new", "tr": "Eskiyi sil ve yeni başlat"},
    "dashboard.openSession.message.fallback": {
        "en": "There's already an open training session.",
        "tr": "Halihazırda açık bir antrenman oturumu var.",
    },
    "dashboard.openSession.message.withInfo": {
        "en": "A session is still running from %1$@ (%2$@). What would you like to do?",
        "tr": "%1$@ tarihinden kalan bir oturum hâlâ aktif (%2$@). Ne yapmak istersin?",
    },
    "dashboard.openSession.resume": {"en": "Resume old", "tr": "Eskisini sürdür"},
    "dashboard.openSession.title": {"en": "Active session", "tr": "Aktif oturum"},
    "dashboard.plan.checkoffRestDay": {"en": "Check off day in plan", "tr": "Günü planda işaretle"},
    "dashboard.plan.checkoffRestDay.a11y": {
        "en": "Check off rest day in plan to show tomorrow's next workout day",
        "tr": "Dinlenme gününü planda işaretle, yarınki sonraki antrenman günü görünsün",
    },
    "dashboard.plan.nextWorkout": {"en": "Next workout", "tr": "Sıradaki antrenman"},
    "dashboard.plan.noActivePlan": {"en": "No active plan", "tr": "Aktif plan yok"},
    "dashboard.plan.noActivePlan.hint": {
        "en": "Set up your first training plan in the Plan tab.",
        "tr": "İlk antrenman planını Plan sekmesinden oluştur.",
    },
    "dashboard.plan.planEmpty": {"en": "Plan still empty", "tr": "Plan henüz boş"},
    "dashboard.plan.planEmpty.hint": {
        "en": "Add days and exercises to your active plan in the Plan tab.",
        "tr": "Plan sekmesinden aktif planına gün ve hareket ekle.",
    },
    "dashboard.plan.restDay": {"en": "Today is a rest day. Time to recover!", "tr": "Bugün dinlenme günü. İyileşme zamanı!"},
    "dashboard.plan.tabShortcut": {"en": "Plan tab", "tr": "Plan sekmesi"},
    "dashboard.plan.todayRestDay": {"en": "Today: rest day", "tr": "Bugün: dinlenme günü"},
    "dashboard.recent.empty.hint": {"en": "Start your first workout above.", "tr": "İlk antrenmanını yukarıdan başlat."},
    "dashboard.recent.empty.title": {"en": "No training sessions yet", "tr": "Henüz antrenman yok"},
    "dashboard.recent.title": {"en": "Recent Workouts", "tr": "Son Antrenmanlar"},
    "dashboard.recent.viewAll": {"en": "Show all", "tr": "Tümünü göster"},
    "dashboard.title": {"en": "Dashboard", "tr": "Panel"},
    "dashboard.trend.empty": {
        "en": "Log your first measurement to see the trend.",
        "tr": "Trendi görmek için ilk ölçümünü kaydet.",
    },
    "dashboard.trend.emptyDescription": {
        "en": "Tap '+' at the top right to enter your first value.",
        "tr": "İlk değeri girmek için sağ üstteki '+' simgesine dokun.",
    },
    "dashboard.trend.emptyTitle": {"en": "No measurements yet", "tr": "Henüz ölçüm yok"},
    "dashboard.trend.forecast.legend": {"en": "Forecast 4 / 8 w.", "tr": "Tahmin 4 / 8 hf."},
    "dashboard.trend.insufficient": {
        "en": "%lld of 3 required measurements — linear regression starts at 3 values over at least 1 week.",
        "tr": "%lld / 3 gerekli ölçüm — doğrusal regresyon en az 1 hafta üzerinden 3 değerle başlar.",
    },
    "dashboard.trend.needMore": {
        "en": "More values over at least 1 week needed for a forecast.",
        "tr": "Tahmin için en az 1 hafta boyunca daha fazla değer gerekli.",
    },
    "dashboard.trend.title": {"en": "Weight Trend", "tr": "Kilo Trendi"},
    "dashboard.trend.unstable": {
        "en": "Values fluctuating heavily — forecast hidden until the trend stabilises.",
        "tr": "Değerler büyük dalgalanmalar gösteriyor — trend kararlı hale gelene kadar tahmin gizli.",
    },
    "dashboard.trophy.empty": {
        "en": "No PRs yet — finish a workout to set your first one.",
        "tr": "Henüz PR yok — ilkini kaydetmek için bir antrenmanı tamamla.",
    },
    "dashboard.trophy.title": {"en": "Trophy Room", "tr": "Kupa Odası"},
    "dashboard.weeklySummary.distance": {"en": "Distance", "tr": "Mesafe"},
    "dashboard.weeklySummary.title": {"en": "This Week", "tr": "Bu Hafta"},
    "dashboard.weeklySummary.volume": {"en": "Volume", "tr": "Hacim"},

    # day_intensity
    "day_intensity.heavy": {"tr": "Ağır"},
    "day_intensity.light": {"tr": "Hafif"},
    "day_intensity.normal": {"tr": "Normal"},

    # day_type
    "day_type.arms": {"tr": "Kol"},
    "day_type.back": {"tr": "Sırt"},
    "day_type.cardio": {"tr": "Kardiyo / Koşu"},
    "day_type.chest": {"tr": "Göğüs"},
    "day_type.custom": {"tr": "Özel"},
    "day_type.full_body": {"tr": "Tüm Vücut"},
    "day_type.legs": {"tr": "Bacak"},
    "day_type.lower": {"tr": "Alt Vücut"},
    "day_type.pull": {"tr": "Pull"},
    "day_type.push": {"tr": "Push"},
    "day_type.rest": {"tr": "Dinlenme Günü"},
    "day_type.shoulders": {"tr": "Omuz"},
    "day_type.upper": {"tr": "Üst Vücut"},

    # difficulty
    "difficulty.advanced": {"tr": "İleri"},
    "difficulty.beginner": {"tr": "Başlangıç"},
    "difficulty.intermediate": {"tr": "Orta"},

    # environment
    "environment.home_gym": {"tr": "Ev Salonu"},
    "environment.no_equipment": {"tr": "Ekipmansız"},

    # equipment
    "equipment.band": {"tr": "Direnç Bandı"},
    "equipment.barbell": {"tr": "Halter"},
    "equipment.bodyweight": {"tr": "Vücut Ağırlığı"},
    "equipment.cable": {"tr": "Kablo"},
    "equipment.dumbbell": {"tr": "Dambıl"},
    "equipment.kettlebell": {"tr": "Kettlebell"},
    "equipment.machine": {"tr": "Makine"},

    # metric.*
    "metric.ffmi": {"en": "FFMI", "tr": "FFMI"},
    "metric.kfaNavy": {"en": "Body Fat (Navy)", "tr": "Yağ Oranı (Navy)"},
    "metric.weeklyDelta.suffix": {"en": "/ wk.", "tr": "/ hf."},
    "metric.weight": {"en": "Weight", "tr": "Ağırlık"},

    # muscle
    "muscle.back": {"tr": "Sırt"},
    "muscle.biceps": {"tr": "Pazı"},
    "muscle.calves": {"tr": "Baldır"},
    "muscle.chest": {"tr": "Göğüs"},
    "muscle.core": {"tr": "Merkez"},
    "muscle.glutes": {"tr": "Kalça"},
    "muscle.hamstrings": {"tr": "Hamstring"},
    "muscle.quads": {"tr": "Quadriceps"},
    "muscle.shoulders": {"tr": "Omuz"},
    "muscle.triceps": {"tr": "Triseps"},

    # onboarding
    "onboarding.field.birthdate": {"tr": "Doğum Tarihi"},
    "onboarding.field.environment": {"tr": "Antrenman Yeri"},
    "onboarding.field.goal_weight": {"tr": "Hedef Kilo (kg, isteğe bağlı)"},
    "onboarding.field.height": {"tr": "Boy (cm)"},
    "onboarding.field.sex": {"tr": "Cinsiyet"},
    "onboarding.intro.body": {
        "tr": "Doğru hesaplamalar (BKİ, yağ oranı, FFMI, BMR) için cinsiyet, yaş ve boya ihtiyacımız var. Tüm değerleri sonradan Profil altında değiştirebilirsin.",
    },
    "onboarding.intro.title": {"tr": "Hadi başlayalım"},
    "onboarding.section.body": {"tr": "Vücut Ölçüleri"},
    "onboarding.section.goals": {"tr": "Hedef & Antrenman"},
    "onboarding.section.profile": {"tr": "Profil"},

    # settings
    "settings.action.reset": {"tr": "Uygulamayı Sıfırla"},
    "settings.confirm.reset.action": {"tr": "Her şeyi sil"},
    "settings.confirm.reset.message": {
        "tr": "Profil, tüm ölçümler, planlar ve antrenman oturumları GERİ ALINAMAZ şekilde silinecek. Uygulama ardından tekrar onboarding'den başlayacak.",
    },
    "settings.confirm.reset.title": {"tr": "Uygulamayı gerçekten sıfırlamak istiyor musun?"},
    "settings.preferences.units": {"tr": "Birimler"},
    "settings.preferences.units.imperial": {"tr": "İmperial (lbs / in)"},
    "settings.preferences.units.metric": {"tr": "Metrik (kg / cm)"},
    "settings.section.about": {"tr": "Hakkında"},
    "settings.section.danger_zone": {"tr": "Veri Yönetimi"},
    "settings.section.preferences": {"tr": "Tercihler"},
    "settings.section.profile_goals": {"tr": "Profil & Hedefler"},

    # summary
    "summary.action.finish": {"tr": "Kaydet ve Panele Dön"},

    # trophy
    "trophy.kind.estimated1RM": {"tr": "1RM"},
}

# Plural special case
PLURAL_T = {
    "%lld Rekorde": {
        "en": {"one": "%lld record", "other": "%lld records"},
        # Turkish doesn't pluralize nouns after explicit counts ("5 rekor" not "5 rekorlar")
        "tr": {"one": "%lld rekor", "other": "%lld rekor"},
    }
}


def main():
    with open(XCSTRINGS, "r", encoding="utf-8") as f:
        data = json.load(f)

    patched_en = 0
    patched_tr = 0
    not_found = []

    for key, langs in T.items():
        if key not in data["strings"]:
            not_found.append(key)
            continue
        locs = data["strings"][key].setdefault("localizations", {})
        if "en" in langs:
            existing = locs.get("en", {}).get("stringUnit", {}).get("value")
            if not existing:
                locs["en"] = {"stringUnit": {"state": "translated", "value": langs["en"]}}
                patched_en += 1
        if "tr" in langs:
            existing = locs.get("tr", {}).get("stringUnit", {}).get("value")
            if not existing:
                locs["tr"] = {"stringUnit": {"state": "translated", "value": langs["tr"]}}
                patched_tr += 1

    for key, langs in PLURAL_T.items():
        if key not in data["strings"]:
            not_found.append(key)
            continue
        locs = data["strings"][key].setdefault("localizations", {})
        for lang_code, forms in langs.items():
            if lang_code not in locs:
                locs[lang_code] = {"variations": {"plural": {}}}
            plural = locs[lang_code].setdefault("variations", {}).setdefault("plural", {})
            for kind, val in forms.items():
                if kind not in plural:
                    plural[kind] = {"stringUnit": {"state": "translated", "value": val}}
                    if lang_code == "en":
                        patched_en += 1
                    elif lang_code == "tr":
                        patched_tr += 1

    with open(XCSTRINGS, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Patched {patched_en} EN entries")
    print(f"Patched {patched_tr} TR entries")
    if not_found:
        print(f"Warning: {len(not_found)} keys not found:")
        for k in not_found:
            print(f"  - {k}")


if __name__ == "__main__":
    main()
