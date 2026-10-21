import Foundation

/// Lokaler Lebensmittelkatalog fuer die Nutrition-Tracking-Funktion.
/// Deutsche Alltagslebensmittel, grob nach `FoodCategory` gruppiert
/// (gleiches Muster wie `ExerciseLibraryData.all`).
///
/// Konventionen (Spec 4.2):
/// - Rohes und gegartes Lebensmittel sind, wo sich die Naehrwerte
///   unterscheiden, getrennte Eintraege (z. B. `_raw` / `_cooked`-Suffix).
/// - `densityGramsPerMl` ist NUR bei echten Fluessigkeiten gesetzt — nie
///   pauschal 1.0 fuer alles mit ml-Einheit.
/// - `pieceWeightGrams` ist nur bei stueckbaren Lebensmitteln gesetzt.
/// - Alle Naehrwertangaben sind Durchschnittswerte pro 100 g/ml (grobe
///   Richtwerte fuer Seed-Daten, keine Laboranalyse).
public enum FoodCatalogData {
    public static let all: [FoodCatalogItem] = [
        // ── MEAT ───────────────────────────────────────────────────────────
        FoodCatalogItem(id: "chicken_breast_raw", nameKey: "nutrition.food.chicken_breast_raw.name", category: .meat, kcalPer100g: 120, proteinPer100g: 22.5, carbsPer100g: 0, fatPer100g: 2.6),
        FoodCatalogItem(id: "chicken_breast_cooked", nameKey: "nutrition.food.chicken_breast_cooked.name", category: .meat, kcalPer100g: 165, proteinPer100g: 31.0, carbsPer100g: 0, fatPer100g: 3.6),
        FoodCatalogItem(id: "chicken_thigh_raw", nameKey: "nutrition.food.chicken_thigh_raw.name", category: .meat, kcalPer100g: 156, proteinPer100g: 17.0, carbsPer100g: 0, fatPer100g: 9.3),
        FoodCatalogItem(id: "chicken_thigh_cooked", nameKey: "nutrition.food.chicken_thigh_cooked.name", category: .meat, kcalPer100g: 209, proteinPer100g: 26.0, carbsPer100g: 0, fatPer100g: 10.9),
        FoodCatalogItem(id: "turkey_breast_raw", nameKey: "nutrition.food.turkey_breast_raw.name", category: .meat, kcalPer100g: 104, proteinPer100g: 23.0, carbsPer100g: 0, fatPer100g: 1.0),
        FoodCatalogItem(id: "turkey_breast_cooked", nameKey: "nutrition.food.turkey_breast_cooked.name", category: .meat, kcalPer100g: 135, proteinPer100g: 30.0, carbsPer100g: 0, fatPer100g: 1.2),
        FoodCatalogItem(id: "beef_mince_raw", nameKey: "nutrition.food.beef_mince_raw.name", category: .meat, kcalPer100g: 215, proteinPer100g: 18.0, carbsPer100g: 0, fatPer100g: 15.0),
        FoodCatalogItem(id: "beef_mince_cooked", nameKey: "nutrition.food.beef_mince_cooked.name", category: .meat, kcalPer100g: 254, proteinPer100g: 25.0, carbsPer100g: 0, fatPer100g: 17.0),
        FoodCatalogItem(id: "beef_steak_raw", nameKey: "nutrition.food.beef_steak_raw.name", category: .meat, kcalPer100g: 190, proteinPer100g: 21.0, carbsPer100g: 0, fatPer100g: 11.0),
        FoodCatalogItem(id: "beef_steak_cooked", nameKey: "nutrition.food.beef_steak_cooked.name", category: .meat, kcalPer100g: 250, proteinPer100g: 27.0, carbsPer100g: 0, fatPer100g: 15.0),
        FoodCatalogItem(id: "pork_tenderloin_raw", nameKey: "nutrition.food.pork_tenderloin_raw.name", category: .meat, kcalPer100g: 107, proteinPer100g: 21.5, carbsPer100g: 0, fatPer100g: 2.0),
        FoodCatalogItem(id: "pork_tenderloin_cooked", nameKey: "nutrition.food.pork_tenderloin_cooked.name", category: .meat, kcalPer100g: 143, proteinPer100g: 26.0, carbsPer100g: 0, fatPer100g: 3.5),
        FoodCatalogItem(id: "pork_chop_raw", nameKey: "nutrition.food.pork_chop_raw.name", category: .meat, kcalPer100g: 143, proteinPer100g: 20.0, carbsPer100g: 0, fatPer100g: 6.5),
        FoodCatalogItem(id: "ham_cooked", nameKey: "nutrition.food.ham_cooked.name", category: .meat, kcalPer100g: 109, proteinPer100g: 20.9, carbsPer100g: 1.0, fatPer100g: 2.5),
        FoodCatalogItem(id: "salami", nameKey: "nutrition.food.salami.name", category: .meat, kcalPer100g: 378, proteinPer100g: 21.0, carbsPer100g: 1.0, fatPer100g: 32.0),
        FoodCatalogItem(id: "bacon_raw", nameKey: "nutrition.food.bacon_raw.name", category: .meat, kcalPer100g: 417, proteinPer100g: 13.0, carbsPer100g: 0, fatPer100g: 40.0),
        FoodCatalogItem(id: "lamb_leg_raw", nameKey: "nutrition.food.lamb_leg_raw.name", category: .meat, kcalPer100g: 158, proteinPer100g: 20.0, carbsPer100g: 0, fatPer100g: 8.5),

        // ── FISH ───────────────────────────────────────────────────────────
        FoodCatalogItem(id: "salmon_raw", nameKey: "nutrition.food.salmon_raw.name", category: .fish, kcalPer100g: 142, proteinPer100g: 20.0, carbsPer100g: 0, fatPer100g: 6.3),
        FoodCatalogItem(id: "salmon_cooked", nameKey: "nutrition.food.salmon_cooked.name", category: .fish, kcalPer100g: 206, proteinPer100g: 22.0, carbsPer100g: 0, fatPer100g: 12.4),
        FoodCatalogItem(id: "tuna_raw", nameKey: "nutrition.food.tuna_raw.name", category: .fish, kcalPer100g: 116, proteinPer100g: 25.0, carbsPer100g: 0, fatPer100g: 1.0),
        FoodCatalogItem(id: "tuna_canned_water", nameKey: "nutrition.food.tuna_canned_water.name", category: .fish, kcalPer100g: 103, proteinPer100g: 23.6, carbsPer100g: 0, fatPer100g: 0.8),
        FoodCatalogItem(id: "cod_raw", nameKey: "nutrition.food.cod_raw.name", category: .fish, kcalPer100g: 82, proteinPer100g: 18.0, carbsPer100g: 0, fatPer100g: 0.7),
        FoodCatalogItem(id: "cod_cooked", nameKey: "nutrition.food.cod_cooked.name", category: .fish, kcalPer100g: 105, proteinPer100g: 23.0, carbsPer100g: 0, fatPer100g: 0.9),
        FoodCatalogItem(id: "shrimp_cooked", nameKey: "nutrition.food.shrimp_cooked.name", category: .fish, kcalPer100g: 99, proteinPer100g: 24.0, carbsPer100g: 0.2, fatPer100g: 0.3),
        FoodCatalogItem(id: "mackerel_raw", nameKey: "nutrition.food.mackerel_raw.name", category: .fish, kcalPer100g: 205, proteinPer100g: 19.0, carbsPer100g: 0, fatPer100g: 14.0),
        FoodCatalogItem(id: "herring_raw", nameKey: "nutrition.food.herring_raw.name", category: .fish, kcalPer100g: 158, proteinPer100g: 18.0, carbsPer100g: 0, fatPer100g: 9.0),
        FoodCatalogItem(id: "trout_raw", nameKey: "nutrition.food.trout_raw.name", category: .fish, kcalPer100g: 119, proteinPer100g: 20.0, carbsPer100g: 0, fatPer100g: 3.5),

        // ── DAIRY ──────────────────────────────────────────────────────────
        // Milch/Sahne tragen eine echte Dichte (leicht ueber 1.0 wegen Fett-
        // und Laktoseanteil) — niemals pauschal 1 ml = 1 g (Spec 4.2).
        FoodCatalogItem(id: "milk_whole", nameKey: "nutrition.food.milk_whole.name", category: .dairy, kcalPer100g: 64, proteinPer100g: 3.3, carbsPer100g: 4.8, fatPer100g: 3.5, densityGramsPerMl: 1.03),
        FoodCatalogItem(id: "milk_lowfat", nameKey: "nutrition.food.milk_lowfat.name", category: .dairy, kcalPer100g: 46, proteinPer100g: 3.4, carbsPer100g: 4.9, fatPer100g: 1.5, densityGramsPerMl: 1.03),
        FoodCatalogItem(id: "yogurt_natural", nameKey: "nutrition.food.yogurt_natural.name", category: .dairy, kcalPer100g: 61, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.5),
        FoodCatalogItem(id: "yogurt_greek", nameKey: "nutrition.food.yogurt_greek.name", category: .dairy, kcalPer100g: 133, proteinPer100g: 5.7, carbsPer100g: 4.0, fatPer100g: 10.3),
        FoodCatalogItem(id: "quark_lowfat", nameKey: "nutrition.food.quark_lowfat.name", category: .dairy, kcalPer100g: 67, proteinPer100g: 12.0, carbsPer100g: 4.0, fatPer100g: 0.3),
        FoodCatalogItem(id: "quark_fullfat", nameKey: "nutrition.food.quark_fullfat.name", category: .dairy, kcalPer100g: 145, proteinPer100g: 11.0, carbsPer100g: 3.5, fatPer100g: 9.5),
        FoodCatalogItem(id: "cottage_cheese", nameKey: "nutrition.food.cottage_cheese.name", category: .dairy, kcalPer100g: 98, proteinPer100g: 11.1, carbsPer100g: 3.4, fatPer100g: 4.3),
        FoodCatalogItem(id: "cheese_gouda", nameKey: "nutrition.food.cheese_gouda.name", category: .dairy, kcalPer100g: 356, proteinPer100g: 24.9, carbsPer100g: 0, fatPer100g: 27.4),
        FoodCatalogItem(id: "cheese_mozzarella", nameKey: "nutrition.food.cheese_mozzarella.name", category: .dairy, kcalPer100g: 280, proteinPer100g: 22.0, carbsPer100g: 2.2, fatPer100g: 20.0),
        FoodCatalogItem(id: "cheese_parmesan", nameKey: "nutrition.food.cheese_parmesan.name", category: .dairy, kcalPer100g: 392, proteinPer100g: 35.0, carbsPer100g: 3.2, fatPer100g: 26.0),
        FoodCatalogItem(id: "cheese_cream", nameKey: "nutrition.food.cheese_cream.name", category: .dairy, kcalPer100g: 290, proteinPer100g: 6.0, carbsPer100g: 4.0, fatPer100g: 28.0),
        FoodCatalogItem(id: "butter", nameKey: "nutrition.food.butter.name", category: .dairy, kcalPer100g: 717, proteinPer100g: 0.9, carbsPer100g: 0.6, fatPer100g: 81.0),
        FoodCatalogItem(id: "cream_heavy", nameKey: "nutrition.food.cream_heavy.name", category: .dairy, kcalPer100g: 292, proteinPer100g: 2.4, carbsPer100g: 3.4, fatPer100g: 30.0, densityGramsPerMl: 0.99),
        FoodCatalogItem(id: "skyr", nameKey: "nutrition.food.skyr.name", category: .dairy, kcalPer100g: 63, proteinPer100g: 11.0, carbsPer100g: 4.0, fatPer100g: 0.2),

        // ── EGG ────────────────────────────────────────────────────────────
        FoodCatalogItem(id: "egg_whole_raw", nameKey: "nutrition.food.egg_whole_raw.name", category: .egg, kcalPer100g: 143, proteinPer100g: 12.6, carbsPer100g: 0.7, fatPer100g: 9.9, pieceWeightGrams: 58),
        FoodCatalogItem(id: "egg_whole_cooked", nameKey: "nutrition.food.egg_whole_cooked.name", category: .egg, kcalPer100g: 155, proteinPer100g: 12.6, carbsPer100g: 1.1, fatPer100g: 10.6, pieceWeightGrams: 58),
        FoodCatalogItem(id: "egg_white_raw", nameKey: "nutrition.food.egg_white_raw.name", category: .egg, kcalPer100g: 52, proteinPer100g: 10.9, carbsPer100g: 0.7, fatPer100g: 0.2),
        FoodCatalogItem(id: "egg_yolk_raw", nameKey: "nutrition.food.egg_yolk_raw.name", category: .egg, kcalPer100g: 322, proteinPer100g: 15.9, carbsPer100g: 3.6, fatPer100g: 26.5),

        // ── GRAIN ──────────────────────────────────────────────────────────
        FoodCatalogItem(id: "oats", nameKey: "nutrition.food.oats.name", category: .grain, kcalPer100g: 379, proteinPer100g: 13.5, carbsPer100g: 60.0, fatPer100g: 7.0),
        FoodCatalogItem(id: "rice_white_raw", nameKey: "nutrition.food.rice_white_raw.name", category: .grain, kcalPer100g: 360, proteinPer100g: 7.1, carbsPer100g: 79.0, fatPer100g: 0.7),
        FoodCatalogItem(id: "rice_white_cooked", nameKey: "nutrition.food.rice_white_cooked.name", category: .grain, kcalPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28.0, fatPer100g: 0.3),
        FoodCatalogItem(id: "rice_brown_raw", nameKey: "nutrition.food.rice_brown_raw.name", category: .grain, kcalPer100g: 357, proteinPer100g: 7.5, carbsPer100g: 76.0, fatPer100g: 2.7),
        FoodCatalogItem(id: "rice_brown_cooked", nameKey: "nutrition.food.rice_brown_cooked.name", category: .grain, kcalPer100g: 123, proteinPer100g: 2.6, carbsPer100g: 25.6, fatPer100g: 1.0),
        FoodCatalogItem(id: "pasta_raw", nameKey: "nutrition.food.pasta_raw.name", category: .grain, kcalPer100g: 353, proteinPer100g: 12.5, carbsPer100g: 70.0, fatPer100g: 1.5),
        FoodCatalogItem(id: "pasta_cooked", nameKey: "nutrition.food.pasta_cooked.name", category: .grain, kcalPer100g: 158, proteinPer100g: 5.8, carbsPer100g: 30.9, fatPer100g: 0.9),
        FoodCatalogItem(id: "whole_wheat_pasta_cooked", nameKey: "nutrition.food.whole_wheat_pasta_cooked.name", category: .grain, kcalPer100g: 149, proteinPer100g: 6.3, carbsPer100g: 30.0, fatPer100g: 1.1),
        FoodCatalogItem(id: "bread_wheat", nameKey: "nutrition.food.bread_wheat.name", category: .grain, kcalPer100g: 265, proteinPer100g: 9.0, carbsPer100g: 49.0, fatPer100g: 3.2, servingNameKey: "nutrition.serving.slice", pieceWeightGrams: 30),
        FoodCatalogItem(id: "bread_whole_grain", nameKey: "nutrition.food.bread_whole_grain.name", category: .grain, kcalPer100g: 219, proteinPer100g: 8.5, carbsPer100g: 38.0, fatPer100g: 3.3, servingNameKey: "nutrition.serving.slice", pieceWeightGrams: 35),
        FoodCatalogItem(id: "bread_toast", nameKey: "nutrition.food.bread_toast.name", category: .grain, kcalPer100g: 270, proteinPer100g: 8.0, carbsPer100g: 50.0, fatPer100g: 3.5, servingNameKey: "nutrition.serving.slice", pieceWeightGrams: 25),
        FoodCatalogItem(id: "quinoa_raw", nameKey: "nutrition.food.quinoa_raw.name", category: .grain, kcalPer100g: 368, proteinPer100g: 14.1, carbsPer100g: 64.0, fatPer100g: 6.1),
        FoodCatalogItem(id: "quinoa_cooked", nameKey: "nutrition.food.quinoa_cooked.name", category: .grain, kcalPer100g: 120, proteinPer100g: 4.4, carbsPer100g: 21.3, fatPer100g: 1.9),
        FoodCatalogItem(id: "couscous_cooked", nameKey: "nutrition.food.couscous_cooked.name", category: .grain, kcalPer100g: 112, proteinPer100g: 3.8, carbsPer100g: 23.2, fatPer100g: 0.2),
        FoodCatalogItem(id: "bulgur_cooked", nameKey: "nutrition.food.bulgur_cooked.name", category: .grain, kcalPer100g: 83, proteinPer100g: 3.1, carbsPer100g: 18.6, fatPer100g: 0.2),
        FoodCatalogItem(id: "cornflakes", nameKey: "nutrition.food.cornflakes.name", category: .grain, kcalPer100g: 357, proteinPer100g: 7.5, carbsPer100g: 84.0, fatPer100g: 0.9),
        FoodCatalogItem(id: "muesli", nameKey: "nutrition.food.muesli.name", category: .grain, kcalPer100g: 362, proteinPer100g: 9.0, carbsPer100g: 65.0, fatPer100g: 6.0),

        // ── VEGETABLE ──────────────────────────────────────────────────────
        FoodCatalogItem(id: "broccoli_raw", nameKey: "nutrition.food.broccoli_raw.name", category: .vegetable, kcalPer100g: 34, proteinPer100g: 2.8, carbsPer100g: 7.0, fatPer100g: 0.4),
        FoodCatalogItem(id: "broccoli_cooked", nameKey: "nutrition.food.broccoli_cooked.name", category: .vegetable, kcalPer100g: 35, proteinPer100g: 2.4, carbsPer100g: 7.2, fatPer100g: 0.4),
        FoodCatalogItem(id: "spinach_raw", nameKey: "nutrition.food.spinach_raw.name", category: .vegetable, kcalPer100g: 23, proteinPer100g: 2.9, carbsPer100g: 3.6, fatPer100g: 0.4),
        FoodCatalogItem(id: "spinach_cooked", nameKey: "nutrition.food.spinach_cooked.name", category: .vegetable, kcalPer100g: 23, proteinPer100g: 3.0, carbsPer100g: 2.0, fatPer100g: 0.4),
        FoodCatalogItem(id: "carrot_raw", nameKey: "nutrition.food.carrot_raw.name", category: .vegetable, kcalPer100g: 41, proteinPer100g: 0.9, carbsPer100g: 9.6, fatPer100g: 0.2),
        FoodCatalogItem(id: "tomato_raw", nameKey: "nutrition.food.tomato_raw.name", category: .vegetable, kcalPer100g: 18, proteinPer100g: 0.9, carbsPer100g: 3.9, fatPer100g: 0.2),
        FoodCatalogItem(id: "cucumber_raw", nameKey: "nutrition.food.cucumber_raw.name", category: .vegetable, kcalPer100g: 15, proteinPer100g: 0.7, carbsPer100g: 3.6, fatPer100g: 0.1),
        FoodCatalogItem(id: "bell_pepper_raw", nameKey: "nutrition.food.bell_pepper_raw.name", category: .vegetable, kcalPer100g: 31, proteinPer100g: 1.0, carbsPer100g: 6.0, fatPer100g: 0.3),
        FoodCatalogItem(id: "zucchini_raw", nameKey: "nutrition.food.zucchini_raw.name", category: .vegetable, kcalPer100g: 17, proteinPer100g: 1.2, carbsPer100g: 3.1, fatPer100g: 0.3),
        FoodCatalogItem(id: "potato_raw", nameKey: "nutrition.food.potato_raw.name", category: .vegetable, kcalPer100g: 77, proteinPer100g: 2.0, carbsPer100g: 17.0, fatPer100g: 0.1),
        FoodCatalogItem(id: "potato_cooked", nameKey: "nutrition.food.potato_cooked.name", category: .vegetable, kcalPer100g: 87, proteinPer100g: 1.9, carbsPer100g: 20.0, fatPer100g: 0.1),
        FoodCatalogItem(id: "sweet_potato_raw", nameKey: "nutrition.food.sweet_potato_raw.name", category: .vegetable, kcalPer100g: 86, proteinPer100g: 1.6, carbsPer100g: 20.1, fatPer100g: 0.1),
        FoodCatalogItem(id: "sweet_potato_cooked", nameKey: "nutrition.food.sweet_potato_cooked.name", category: .vegetable, kcalPer100g: 90, proteinPer100g: 2.0, carbsPer100g: 20.7, fatPer100g: 0.1),
        FoodCatalogItem(id: "onion_raw", nameKey: "nutrition.food.onion_raw.name", category: .vegetable, kcalPer100g: 40, proteinPer100g: 1.1, carbsPer100g: 9.3, fatPer100g: 0.1),
        FoodCatalogItem(id: "garlic_raw", nameKey: "nutrition.food.garlic_raw.name", category: .vegetable, kcalPer100g: 149, proteinPer100g: 6.4, carbsPer100g: 33.0, fatPer100g: 0.5),
        FoodCatalogItem(id: "mushroom_raw", nameKey: "nutrition.food.mushroom_raw.name", category: .vegetable, kcalPer100g: 22, proteinPer100g: 3.1, carbsPer100g: 3.3, fatPer100g: 0.3),
        FoodCatalogItem(id: "cauliflower_raw", nameKey: "nutrition.food.cauliflower_raw.name", category: .vegetable, kcalPer100g: 25, proteinPer100g: 1.9, carbsPer100g: 5.0, fatPer100g: 0.3),
        FoodCatalogItem(id: "green_beans_raw", nameKey: "nutrition.food.green_beans_raw.name", category: .vegetable, kcalPer100g: 31, proteinPer100g: 1.8, carbsPer100g: 7.0, fatPer100g: 0.1),
        FoodCatalogItem(id: "lettuce", nameKey: "nutrition.food.lettuce.name", category: .vegetable, kcalPer100g: 15, proteinPer100g: 1.4, carbsPer100g: 2.9, fatPer100g: 0.2),
        FoodCatalogItem(id: "cabbage_raw", nameKey: "nutrition.food.cabbage_raw.name", category: .vegetable, kcalPer100g: 25, proteinPer100g: 1.3, carbsPer100g: 5.8, fatPer100g: 0.1),
        FoodCatalogItem(id: "corn_cooked", nameKey: "nutrition.food.corn_cooked.name", category: .vegetable, kcalPer100g: 96, proteinPer100g: 3.4, carbsPer100g: 21.0, fatPer100g: 1.5),
        FoodCatalogItem(id: "peas_cooked", nameKey: "nutrition.food.peas_cooked.name", category: .vegetable, kcalPer100g: 81, proteinPer100g: 5.4, carbsPer100g: 14.0, fatPer100g: 0.4),

        // ── FRUIT ──────────────────────────────────────────────────────────
        FoodCatalogItem(id: "banana", nameKey: "nutrition.food.banana.name", category: .fruit, kcalPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23.0, fatPer100g: 0.3, pieceWeightGrams: 120),
        FoodCatalogItem(id: "apple", nameKey: "nutrition.food.apple.name", category: .fruit, kcalPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14.0, fatPer100g: 0.2, pieceWeightGrams: 180),
        FoodCatalogItem(id: "orange", nameKey: "nutrition.food.orange.name", category: .fruit, kcalPer100g: 47, proteinPer100g: 0.9, carbsPer100g: 12.0, fatPer100g: 0.1, pieceWeightGrams: 200),
        FoodCatalogItem(id: "strawberry", nameKey: "nutrition.food.strawberry.name", category: .fruit, kcalPer100g: 32, proteinPer100g: 0.7, carbsPer100g: 7.7, fatPer100g: 0.3),
        FoodCatalogItem(id: "blueberry", nameKey: "nutrition.food.blueberry.name", category: .fruit, kcalPer100g: 57, proteinPer100g: 0.7, carbsPer100g: 14.5, fatPer100g: 0.3),
        FoodCatalogItem(id: "grape", nameKey: "nutrition.food.grape.name", category: .fruit, kcalPer100g: 69, proteinPer100g: 0.6, carbsPer100g: 18.0, fatPer100g: 0.2),
        FoodCatalogItem(id: "pineapple", nameKey: "nutrition.food.pineapple.name", category: .fruit, kcalPer100g: 50, proteinPer100g: 0.5, carbsPer100g: 13.1, fatPer100g: 0.1),
        FoodCatalogItem(id: "mango", nameKey: "nutrition.food.mango.name", category: .fruit, kcalPer100g: 60, proteinPer100g: 0.8, carbsPer100g: 15.0, fatPer100g: 0.4),
        FoodCatalogItem(id: "avocado", nameKey: "nutrition.food.avocado.name", category: .fruit, kcalPer100g: 160, proteinPer100g: 2.0, carbsPer100g: 8.5, fatPer100g: 14.7, pieceWeightGrams: 200),
        FoodCatalogItem(id: "watermelon", nameKey: "nutrition.food.watermelon.name", category: .fruit, kcalPer100g: 30, proteinPer100g: 0.6, carbsPer100g: 7.6, fatPer100g: 0.2),
        FoodCatalogItem(id: "pear", nameKey: "nutrition.food.pear.name", category: .fruit, kcalPer100g: 57, proteinPer100g: 0.4, carbsPer100g: 15.0, fatPer100g: 0.1, pieceWeightGrams: 170),
        FoodCatalogItem(id: "kiwi", nameKey: "nutrition.food.kiwi.name", category: .fruit, kcalPer100g: 61, proteinPer100g: 1.1, carbsPer100g: 14.7, fatPer100g: 0.5, pieceWeightGrams: 75),
        FoodCatalogItem(id: "raisins", nameKey: "nutrition.food.raisins.name", category: .fruit, kcalPer100g: 299, proteinPer100g: 3.1, carbsPer100g: 79.0, fatPer100g: 0.5),
        FoodCatalogItem(id: "dates_dried", nameKey: "nutrition.food.dates_dried.name", category: .fruit, kcalPer100g: 277, proteinPer100g: 1.8, carbsPer100g: 75.0, fatPer100g: 0.2),

        // ── LEGUME ─────────────────────────────────────────────────────────
        FoodCatalogItem(id: "lentils_raw", nameKey: "nutrition.food.lentils_raw.name", category: .legume, kcalPer100g: 353, proteinPer100g: 25.0, carbsPer100g: 60.0, fatPer100g: 1.1),
        FoodCatalogItem(id: "lentils_cooked", nameKey: "nutrition.food.lentils_cooked.name", category: .legume, kcalPer100g: 116, proteinPer100g: 9.0, carbsPer100g: 20.0, fatPer100g: 0.4),
        FoodCatalogItem(id: "chickpeas_cooked", nameKey: "nutrition.food.chickpeas_cooked.name", category: .legume, kcalPer100g: 164, proteinPer100g: 8.9, carbsPer100g: 27.4, fatPer100g: 2.6),
        FoodCatalogItem(id: "black_beans_cooked", nameKey: "nutrition.food.black_beans_cooked.name", category: .legume, kcalPer100g: 132, proteinPer100g: 8.9, carbsPer100g: 23.7, fatPer100g: 0.5),
        FoodCatalogItem(id: "kidney_beans_cooked", nameKey: "nutrition.food.kidney_beans_cooked.name", category: .legume, kcalPer100g: 127, proteinPer100g: 8.7, carbsPer100g: 22.8, fatPer100g: 0.5),
        FoodCatalogItem(id: "tofu", nameKey: "nutrition.food.tofu.name", category: .legume, kcalPer100g: 76, proteinPer100g: 8.0, carbsPer100g: 1.9, fatPer100g: 4.8),
        FoodCatalogItem(id: "edamame_cooked", nameKey: "nutrition.food.edamame_cooked.name", category: .legume, kcalPer100g: 122, proteinPer100g: 11.0, carbsPer100g: 10.0, fatPer100g: 5.2),

        // ── NUT / SEED ─────────────────────────────────────────────────────
        FoodCatalogItem(id: "almonds", nameKey: "nutrition.food.almonds.name", category: .nutSeed, kcalPer100g: 579, proteinPer100g: 21.0, carbsPer100g: 22.0, fatPer100g: 50.0),
        FoodCatalogItem(id: "walnuts", nameKey: "nutrition.food.walnuts.name", category: .nutSeed, kcalPer100g: 654, proteinPer100g: 15.0, carbsPer100g: 14.0, fatPer100g: 65.0),
        FoodCatalogItem(id: "peanuts", nameKey: "nutrition.food.peanuts.name", category: .nutSeed, kcalPer100g: 567, proteinPer100g: 25.8, carbsPer100g: 16.0, fatPer100g: 49.0),
        FoodCatalogItem(id: "peanut_butter", nameKey: "nutrition.food.peanut_butter.name", category: .nutSeed, kcalPer100g: 588, proteinPer100g: 25.0, carbsPer100g: 20.0, fatPer100g: 50.0),
        FoodCatalogItem(id: "cashews", nameKey: "nutrition.food.cashews.name", category: .nutSeed, kcalPer100g: 553, proteinPer100g: 18.0, carbsPer100g: 30.0, fatPer100g: 44.0),
        FoodCatalogItem(id: "chia_seeds", nameKey: "nutrition.food.chia_seeds.name", category: .nutSeed, kcalPer100g: 486, proteinPer100g: 17.0, carbsPer100g: 42.0, fatPer100g: 31.0),
        FoodCatalogItem(id: "flaxseed", nameKey: "nutrition.food.flaxseed.name", category: .nutSeed, kcalPer100g: 534, proteinPer100g: 18.0, carbsPer100g: 29.0, fatPer100g: 42.0),
        FoodCatalogItem(id: "sunflower_seeds", nameKey: "nutrition.food.sunflower_seeds.name", category: .nutSeed, kcalPer100g: 584, proteinPer100g: 21.0, carbsPer100g: 20.0, fatPer100g: 51.0),
        FoodCatalogItem(id: "pumpkin_seeds", nameKey: "nutrition.food.pumpkin_seeds.name", category: .nutSeed, kcalPer100g: 559, proteinPer100g: 30.0, carbsPer100g: 11.0, fatPer100g: 49.0),

        // ── FAT ────────────────────────────────────────────────────────────
        // Oele: Dichte < 1.0 (leichter als Wasser) — bewusst gesetzt, nie 1.0.
        FoodCatalogItem(id: "olive_oil", nameKey: "nutrition.food.olive_oil.name", category: .fat, kcalPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100.0, densityGramsPerMl: 0.92),
        FoodCatalogItem(id: "sunflower_oil", nameKey: "nutrition.food.sunflower_oil.name", category: .fat, kcalPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100.0, densityGramsPerMl: 0.92),
        FoodCatalogItem(id: "coconut_oil", nameKey: "nutrition.food.coconut_oil.name", category: .fat, kcalPer100g: 862, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 99.1, densityGramsPerMl: 0.92),
        FoodCatalogItem(id: "mayonnaise", nameKey: "nutrition.food.mayonnaise.name", category: .fat, kcalPer100g: 680, proteinPer100g: 1.1, carbsPer100g: 2.6, fatPer100g: 75.0),

        // ── BEVERAGE ───────────────────────────────────────────────────────
        // Jede Fluessigkeit traegt ihre echte Dichte — Wasser ist der einzige
        // Fall, bei dem 1.0 tatsaechlich korrekt ist, nicht die Annahme.
        FoodCatalogItem(id: "water", nameKey: "nutrition.food.water.name", category: .beverage, kcalPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, densityGramsPerMl: 1.0),
        FoodCatalogItem(id: "orange_juice", nameKey: "nutrition.food.orange_juice.name", category: .beverage, kcalPer100g: 45, proteinPer100g: 0.7, carbsPer100g: 10.4, fatPer100g: 0.2, densityGramsPerMl: 1.04),
        FoodCatalogItem(id: "apple_juice", nameKey: "nutrition.food.apple_juice.name", category: .beverage, kcalPer100g: 46, proteinPer100g: 0.1, carbsPer100g: 11.3, fatPer100g: 0.1, densityGramsPerMl: 1.04),
        FoodCatalogItem(id: "cola", nameKey: "nutrition.food.cola.name", category: .beverage, kcalPer100g: 42, proteinPer100g: 0, carbsPer100g: 10.6, fatPer100g: 0, densityGramsPerMl: 1.04),
        FoodCatalogItem(id: "beer", nameKey: "nutrition.food.beer.name", category: .beverage, kcalPer100g: 43, proteinPer100g: 0.5, carbsPer100g: 3.6, fatPer100g: 0, densityGramsPerMl: 1.01),
        FoodCatalogItem(id: "coffee_black", nameKey: "nutrition.food.coffee_black.name", category: .beverage, kcalPer100g: 1, proteinPer100g: 0.1, carbsPer100g: 0, fatPer100g: 0, densityGramsPerMl: 1.0),
        FoodCatalogItem(id: "almond_milk", nameKey: "nutrition.food.almond_milk.name", category: .beverage, kcalPer100g: 17, proteinPer100g: 0.6, carbsPer100g: 0.6, fatPer100g: 1.2, densityGramsPerMl: 1.01),

        // ── SWEET ──────────────────────────────────────────────────────────
        FoodCatalogItem(id: "sugar_white", nameKey: "nutrition.food.sugar_white.name", category: .sweet, kcalPer100g: 400, proteinPer100g: 0, carbsPer100g: 100.0, fatPer100g: 0),
        FoodCatalogItem(id: "honey", nameKey: "nutrition.food.honey.name", category: .sweet, kcalPer100g: 304, proteinPer100g: 0.3, carbsPer100g: 82.0, fatPer100g: 0, densityGramsPerMl: 1.42),
        FoodCatalogItem(id: "dark_chocolate", nameKey: "nutrition.food.dark_chocolate.name", category: .sweet, kcalPer100g: 546, proteinPer100g: 7.8, carbsPer100g: 46.0, fatPer100g: 31.0),
        FoodCatalogItem(id: "milk_chocolate", nameKey: "nutrition.food.milk_chocolate.name", category: .sweet, kcalPer100g: 535, proteinPer100g: 7.6, carbsPer100g: 59.0, fatPer100g: 29.7),
        FoodCatalogItem(id: "jam", nameKey: "nutrition.food.jam.name", category: .sweet, kcalPer100g: 250, proteinPer100g: 0.3, carbsPer100g: 62.0, fatPer100g: 0.1),
    ]
}
