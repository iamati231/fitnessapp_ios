"""Ernaehrungssuche UX + lokaler Katalog erweitern -- new localized keys.

Same idempotent upsert pattern as del117_hardcoded_sweep.py /
pagination_barcode_strings.py (only fills empty slots, never overwrites
existing translations). Run from project root:
    "C:\\Python314\\python.exe" .scripts/ux_catalog_strings.py
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LOCALIZABLE = os.path.join(ROOT, "Sources", "FitnessAppUI", "Resources", "Localizable.xcstrings")

# ── FoodCategory labels (never localized before -- no category UI existed) ──
CATEGORY_KEYS = {
    "nutrition.category.meat.name": ("Fleisch", "Meat", "Et"),
    "nutrition.category.fish.name": ("Fisch", "Fish", "Balık"),
    "nutrition.category.dairy.name": ("Milchprodukte", "Dairy", "Süt Ürünleri"),
    "nutrition.category.egg.name": ("Eier", "Eggs", "Yumurta"),
    "nutrition.category.grain.name": ("Getreide", "Grains", "Tahıllar"),
    "nutrition.category.vegetable.name": ("Gemüse", "Vegetables", "Sebze"),
    "nutrition.category.fruit.name": ("Obst", "Fruit", "Meyve"),
    "nutrition.category.legume.name": ("Hülsenfrüchte", "Legumes", "Baklagiller"),
    "nutrition.category.nutSeed.name": ("Nüsse & Samen", "Nuts & Seeds", "Kuruyemiş & Tohum"),
    "nutrition.category.fat.name": ("Fette", "Fats", "Yağlar"),
    "nutrition.category.beverage.name": ("Getränke", "Beverages", "İçecekler"),
    "nutrition.category.sweet.name": ("Süßes", "Sweets", "Tatlılar"),
    "nutrition.category.other.name": ("Sonstiges", "Other", "Diğer"),
}

# ── New UI strings: UX hierarchy + redesigned scanner ──
UI_KEYS = {
    "nutrition.addMeal.category.all": ("Alle", "All", "Tümü"),
    "nutrition.addMeal.popularSection": ("Beliebt", "Popular", "Popüler"),
    "nutrition.addMeal.loadMoreLocal": ("Weitere lokale Treffer", "More local results", "Daha fazla yerel sonuç"),
    "nutrition.barcode.scanSubtitle": (
        "Fertigprodukt schnell erfassen", "Quickly log a packaged product", "Paketli ürünü hızlıca ekle"),
    "nutrition.barcode.requiresOptIn": (
        "Aktiviere die Online-Produktsuche in den Einstellungen, um Barcodes zu scannen.",
        "Enable online product search in Settings to scan barcodes.",
        "Barkod taramak için Ayarlar'dan çevrimiçi ürün aramasını etkinleştir."),
    "nutrition.barcode.openSettings": ("Einstellungen öffnen", "Open Settings", "Ayarları Aç"),
    "nutrition.barcode.autoDetectHint": (
        "Der Barcode wird automatisch erkannt.", "The barcode is detected automatically.",
        "Barkod otomatik olarak algılanır."),
    "nutrition.barcode.manualEntry": (
        "Barcode manuell eingeben", "Enter barcode manually", "Barkodu manuel gir"),
    "nutrition.barcode.manualPlaceholder": ("Barcode", "Barcode", "Barkod"),
    "nutrition.barcode.manualSubmit": ("Suchen", "Search", "Ara"),
    "nutrition.barcode.manualInvalid": (
        "Ungültiger Barcode. Bitte nur Ziffern eingeben.",
        "Invalid barcode. Please enter digits only.",
        "Geçersiz barkod. Lütfen yalnızca rakam girin."),
}

# ── New local catalog entries: nutrition.food.{id}.name ──
FOOD_KEYS = {
    # Meat
    "nutrition.food.chicken_wing_raw.name": ("Hähnchenflügel, roh", "Chicken wing, raw", "Tavuk kanadı, çiğ"),
    "nutrition.food.chicken_drumstick_raw.name": ("Hähnchenkeule, roh", "Chicken drumstick, raw", "Tavuk but, çiğ"),
    "nutrition.food.turkey_mince_raw.name": ("Putenhackfleisch, roh", "Ground turkey, raw", "Kıyma (hindi), çiğ"),
    "nutrition.food.beef_sirloin_raw.name": ("Rinder-Roastbeef, roh", "Beef sirloin, raw", "Sığır bonfile, çiğ"),
    "nutrition.food.pork_mince_raw.name": ("Schweinehackfleisch, roh", "Ground pork, raw", "Kıyma (domuz), çiğ"),
    "nutrition.food.lamb_mince_raw.name": ("Lammhackfleisch, roh", "Ground lamb, raw", "Kıyma (kuzu), çiğ"),
    "nutrition.food.chicken_liver_cooked.name": ("Hähnchenleber, gebraten", "Chicken liver, cooked", "Tavuk ciğeri, pişmiş"),
    "nutrition.food.sausage_bratwurst.name": ("Bratwurst", "Bratwurst sausage", "Bratwurst sosis"),
    "nutrition.food.frankfurter_sausage.name": ("Frankfurter Würstchen", "Frankfurter sausage", "Frankfurter sosis"),
    # Fish
    "nutrition.food.shrimp_raw.name": ("Garnelen, roh", "Shrimp, raw", "Karides, çiğ"),
    "nutrition.food.salmon_smoked.name": ("Räucherlachs", "Smoked salmon", "Füme somon"),
    "nutrition.food.tuna_canned_oil.name": ("Thunfisch, in Öl, abgetropft", "Tuna, canned in oil, drained", "Ton balığı, yağlı, süzülmüş"),
    "nutrition.food.sardines_canned_oil.name": ("Sardinen, in Öl", "Sardines, canned in oil", "Sardalya, yağlı konserve"),
    "nutrition.food.mussels_cooked.name": ("Miesmuscheln, gekocht", "Mussels, cooked", "Midye, pişmiş"),
    "nutrition.food.crab_cooked.name": ("Krabbenfleisch, gekocht", "Crab meat, cooked", "Yengeç eti, pişmiş"),
    # Dairy
    "nutrition.food.milk_skim.name": ("Magermilch", "Skim milk", "Yağsız süt"),
    "nutrition.food.buttermilk.name": ("Buttermilch", "Buttermilk", "Ayran (tereyağlı süt)"),
    "nutrition.food.cream_light.name": ("Sahne, 10% Fett", "Light cream, 10% fat", "Krema, %10 yağlı"),
    "nutrition.food.cheese_feta.name": ("Feta-Käse", "Feta cheese", "Beyaz peynir (feta)"),
    "nutrition.food.cheese_cheddar.name": ("Cheddar-Käse", "Cheddar cheese", "Cheddar peyniri"),
    "nutrition.food.cheese_ricotta.name": ("Ricotta", "Ricotta cheese", "Ricotta peyniri"),
    "nutrition.food.cheese_halloumi.name": ("Halloumi", "Halloumi cheese", "Hellim peyniri"),
    "nutrition.food.kefir.name": ("Kefir", "Kefir", "Kefir"),
    # Egg
    "nutrition.food.egg_fried.name": ("Spiegelei", "Fried egg", "Sahanda yumurta"),
    "nutrition.food.egg_scrambled.name": ("Rührei", "Scrambled eggs", "Çırpılmış yumurta"),
    # Grain
    "nutrition.food.rye_bread.name": ("Roggenbrot", "Rye bread", "Çavdar ekmeği"),
    "nutrition.food.tortilla_wheat.name": ("Weizen-Tortilla", "Wheat tortilla", "Buğday tortilla"),
    "nutrition.food.pita_bread.name": ("Pita-Brot", "Pita bread", "Pita ekmeği"),
    "nutrition.food.rice_cakes.name": ("Reiswaffel", "Rice cake", "Pirinç keki"),
    "nutrition.food.rice_basmati_raw.name": ("Basmatireis, roh", "Basmati rice, raw", "Basmati pirinç, çiğ"),
    "nutrition.food.rice_basmati_cooked.name": ("Basmatireis, gekocht", "Basmati rice, cooked", "Basmati pirinç, pişmiş"),
    "nutrition.food.polenta_cooked.name": ("Polenta, gekocht", "Polenta, cooked", "Polenta, pişmiş"),
    "nutrition.food.granola.name": ("Granola", "Granola", "Granola"),
    "nutrition.food.breadcrumbs.name": ("Paniermehl", "Breadcrumbs", "Galeta unu"),
    "nutrition.food.naan_bread.name": ("Naan-Brot", "Naan bread", "Naan ekmeği"),
    "nutrition.food.crackers_salted.name": ("Salzcracker", "Salted crackers", "Tuzlu kraker"),
    "nutrition.food.rice_noodles_cooked.name": ("Reisnudeln, gekocht", "Rice noodles, cooked", "Pirinç eriştesi, pişmiş"),
    # Vegetable
    "nutrition.food.beetroot_raw.name": ("Rote Bete, roh", "Beetroot, raw", "Pancar, çiğ"),
    "nutrition.food.radish_raw.name": ("Radieschen, roh", "Radish, raw", "Turp, çiğ"),
    "nutrition.food.leek_raw.name": ("Lauch, roh", "Leek, raw", "Pırasa, çiğ"),
    "nutrition.food.celery_raw.name": ("Staudensellerie, roh", "Celery, raw", "Kereviz sapı, çiğ"),
    "nutrition.food.pumpkin_raw.name": ("Kürbis, roh", "Pumpkin, raw", "Balkabağı, çiğ"),
    "nutrition.food.eggplant_raw.name": ("Aubergine, roh", "Eggplant, raw", "Patlıcan, çiğ"),
    "nutrition.food.brussels_sprouts_cooked.name": ("Rosenkohl, gekocht", "Brussels sprouts, cooked", "Brüksel lahanası, pişmiş"),
    "nutrition.food.kale_raw.name": ("Grünkohl, roh", "Kale, raw", "Kara lahana, çiğ"),
    "nutrition.food.fennel_raw.name": ("Fenchel, roh", "Fennel, raw", "Rezene, çiğ"),
    "nutrition.food.chili_pepper_raw.name": ("Chilischote, roh", "Chili pepper, raw", "Acı biber, çiğ"),
    "nutrition.food.sauerkraut.name": ("Sauerkraut", "Sauerkraut", "Lahana turşusu"),
    "nutrition.food.olives_green.name": ("Oliven, grün", "Olives, green", "Yeşil zeytin"),
    "nutrition.food.asparagus_raw.name": ("Spargel, roh", "Asparagus, raw", "Kuşkonmaz, çiğ"),
    "nutrition.food.mashed_potatoes.name": ("Kartoffelpüree", "Mashed potatoes", "Patates püresi"),
    # Fruit
    "nutrition.food.cherries.name": ("Kirschen", "Cherries", "Kiraz"),
    "nutrition.food.plum.name": ("Pflaume", "Plum", "Erik"),
    "nutrition.food.peach.name": ("Pfirsich", "Peach", "Şeftali"),
    "nutrition.food.apricot.name": ("Aprikose", "Apricot", "Kayısı"),
    "nutrition.food.fig_fresh.name": ("Feige, frisch", "Fig, fresh", "Taze incir"),
    "nutrition.food.pomegranate.name": ("Granatapfel", "Pomegranate", "Nar"),
    "nutrition.food.grapefruit.name": ("Grapefruit", "Grapefruit", "Greyfurt"),
    "nutrition.food.lemon.name": ("Zitrone", "Lemon", "Limon"),
    "nutrition.food.papaya.name": ("Papaya", "Papaya", "Papaya"),
    "nutrition.food.raspberry.name": ("Himbeere", "Raspberry", "Ahududu"),
    "nutrition.food.blackberry.name": ("Brombeere", "Blackberry", "Böğürtlen"),
    "nutrition.food.nectarine.name": ("Nektarine", "Nectarine", "Nektarin"),
    # Legume
    "nutrition.food.white_beans_cooked.name": ("Weiße Bohnen, gekocht", "White beans, cooked", "Beyaz fasulye, pişmiş"),
    "nutrition.food.soybeans_cooked.name": ("Sojabohnen, gekocht", "Soybeans, cooked", "Soya fasulyesi, pişmiş"),
    "nutrition.food.tempeh.name": ("Tempeh", "Tempeh", "Tempeh"),
    "nutrition.food.hummus.name": ("Hummus", "Hummus", "Humus"),
    "nutrition.food.split_peas_cooked.name": ("Gelbe Erbsen, gekocht", "Split peas, cooked", "Sarı bezelye, pişmiş"),
    "nutrition.food.pinto_beans_cooked.name": ("Pinto-Bohnen, gekocht", "Pinto beans, cooked", "Pinto fasulyesi, pişmiş"),
    # Nut / seed
    "nutrition.food.pistachios.name": ("Pistazien", "Pistachios", "Antep fıstığı"),
    "nutrition.food.hazelnuts.name": ("Haselnüsse", "Hazelnuts", "Fındık"),
    "nutrition.food.pecans.name": ("Pekannüsse", "Pecans", "Pekan cevizi"),
    "nutrition.food.almond_butter.name": ("Mandelmus", "Almond butter", "Badem ezmesi"),
    "nutrition.food.tahini.name": ("Tahini (Sesammus)", "Tahini (sesame paste)", "Tahin"),
    "nutrition.food.sesame_seeds.name": ("Sesamsamen", "Sesame seeds", "Susam"),
    "nutrition.food.hemp_seeds.name": ("Hanfsamen", "Hemp seeds", "Kenevir tohumu"),
    # Fat
    "nutrition.food.rapeseed_oil.name": ("Rapsöl", "Rapeseed oil", "Kanola yağı"),
    "nutrition.food.avocado_oil.name": ("Avocadoöl", "Avocado oil", "Avokado yağı"),
    "nutrition.food.ghee.name": ("Ghee (Butterschmalz)", "Ghee (clarified butter)", "Sadeyağ (ghee)"),
    "nutrition.food.margarine.name": ("Margarine", "Margarine", "Margarin"),
    "nutrition.food.pesto.name": ("Pesto", "Pesto", "Pesto"),
    # Beverage
    "nutrition.food.tea_black.name": ("Schwarzer Tee", "Black tea", "Siyah çay"),
    "nutrition.food.soy_milk.name": ("Sojamilch", "Soy milk", "Soya sütü"),
    "nutrition.food.oat_milk.name": ("Hafermilch", "Oat milk", "Yulaf sütü"),
    "nutrition.food.coconut_water.name": ("Kokoswasser", "Coconut water", "Hindistan cevizi suyu"),
    "nutrition.food.tomato_juice.name": ("Tomatensaft", "Tomato juice", "Domates suyu"),
    "nutrition.food.red_wine.name": ("Rotwein", "Red wine", "Kırmızı şarap"),
    "nutrition.food.white_wine.name": ("Weißwein", "White wine", "Beyaz şarap"),
    "nutrition.food.hot_chocolate.name": ("Heiße Schokolade", "Hot chocolate", "Sıcak çikolata"),
    # Sweet
    "nutrition.food.maple_syrup.name": ("Ahornsirup", "Maple syrup", "Akçaağaç şurubu"),
    "nutrition.food.ice_cream_vanilla.name": ("Vanilleeis", "Vanilla ice cream", "Vanilyalı dondurma"),
    "nutrition.food.waffle.name": ("Waffel", "Waffle", "Waffle"),
    "nutrition.food.pancake.name": ("Pfannkuchen", "Pancake", "Pankek"),
    "nutrition.food.croissant.name": ("Croissant", "Croissant", "Kruvasan"),
    "nutrition.food.donut_glazed.name": ("Donut, glasiert", "Glazed donut", "Donut, sırlı"),
    "nutrition.food.cake_sponge.name": ("Rührkuchen", "Sponge cake", "Kek"),
    # Other (sauces, condiments, generic dishes)
    "nutrition.food.tomato_sauce.name": ("Tomatensoße", "Tomato sauce", "Domates sosu"),
    "nutrition.food.ketchup.name": ("Ketchup", "Ketchup", "Ketçap"),
    "nutrition.food.mustard.name": ("Senf", "Mustard", "Hardal"),
    "nutrition.food.soy_sauce.name": ("Sojasoße", "Soy sauce", "Soya sosu"),
    "nutrition.food.pizza_margherita.name": ("Pizza Margherita", "Pizza Margherita", "Margarita Pizza"),
    "nutrition.food.lasagna.name": ("Lasagne", "Lasagna", "Lazanya"),
    "nutrition.food.french_fries.name": ("Pommes frites", "French fries", "Patates kızartması"),
    "nutrition.food.vegetable_soup.name": ("Gemüsesuppe", "Vegetable soup", "Sebze çorbası"),
}

ALL_KEYS = {}
ALL_KEYS.update(CATEGORY_KEYS)
ALL_KEYS.update(UI_KEYS)
ALL_KEYS.update(FOOD_KEYS)


def upsert(strings, key, de, en, tr):
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
    with open(LOCALIZABLE, "r", encoding="utf-8") as f:
        data = json.load(f)
    strings = data["strings"]

    created = filled = 0
    for key, (de, en, tr) in ALL_KEYS.items():
        c, f = upsert(strings, key, de, en, tr)
        created += int(c)
        filled += f

    with open(LOCALIZABLE, "w", encoding="utf-8") as ff:
        json.dump(data, ff, ensure_ascii=False, indent=2)
        ff.write("\n")
    print(f"ux_catalog_strings: {created} new keys, {filled} empty translation slots filled "
          f"({len(CATEGORY_KEYS)} categories, {len(UI_KEYS)} UI, {len(FOOD_KEYS)} food names)")


if __name__ == "__main__":
    main()
