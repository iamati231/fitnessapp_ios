"""Ernaehrungssuche erweitern + Barcode-Scan ergaenzen -- new localized keys.

Same idempotent upsert pattern as del117_hardcoded_sweep.py (only fills
empty slots, never overwrites existing translations). Run from project root:
    "C:\\Python314\\python.exe" .scripts/pagination_barcode_strings.py
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LOCALIZABLE = os.path.join(ROOT, "Sources", "FitnessAppUI", "Resources", "Localizable.xcstrings")
INFOPLIST = os.path.join(ROOT, "App", "FitnessApp", "InfoPlist.xcstrings")

LOCALIZABLE_KEYS = {
    "nutrition.addMeal.onlineSearch.loadMore": (
        "Weitere Ergebnisse laden", "Load more results", "Daha fazla sonuç yükle"),
    "nutrition.barcode.scanAction": (
        "Barcode scannen", "Scan Barcode", "Barkod Tara"),
    "nutrition.barcode.instructions": (
        "Halte den Barcode des Produkts in den Rahmen.",
        "Hold the product's barcode inside the frame.",
        "Ürünün barkodunu çerçevenin içinde tut."),
    "nutrition.barcode.unsupportedDevice": (
        "Barcode-Scan wird auf diesem Gerät nicht unterstützt.",
        "Barcode scanning isn't supported on this device.",
        "Barkod tarama bu cihazda desteklenmiyor."),
    "nutrition.barcode.permissionDenied": (
        "Kein Kamerazugriff. Aktiviere ihn in den iOS-Einstellungen, um Barcodes zu scannen.",
        "No camera access. Enable it in iOS Settings to scan barcodes.",
        "Kamera erişimi yok. Barkod taramak için iOS Ayarlar'dan izin ver."),
    "nutrition.barcode.notFound": (
        "Produkt nicht gefunden.", "Product not found.", "Ürün bulunamadı."),
}

INFOPLIST_KEYS = {
    "NSCameraUsageDescription": (
        "Deltiq nutzt die Kamera, um den Barcode eines Produkts zu scannen und dessen Nährwerte über Open Food Facts abzurufen.",
        "Deltiq uses the camera to scan a product's barcode so it can look up its nutrition facts on Open Food Facts.",
        "Deltiq, bir ürünün barkodunu tarayıp Open Food Facts üzerinden besin değerlerini bulmak için kamerayı kullanır."),
}


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


def apply(path, keys):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    strings = data["strings"]
    created = filled = 0
    for key, (de, en, tr) in keys.items():
        c, f = upsert(strings, key, de, en, tr)
        created += int(c)
        filled += f
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    # Validate the file we just wrote is still well-formed JSON.
    with open(path, "r", encoding="utf-8") as f:
        json.load(f)
    print(f"{os.path.basename(path)}: {created} new keys, {filled} translation slots filled")


def main():
    apply(LOCALIZABLE, LOCALIZABLE_KEYS)
    apply(INFOPLIST, INFOPLIST_KEYS)


if __name__ == "__main__":
    main()
