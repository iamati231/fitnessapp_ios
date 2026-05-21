#!/usr/bin/env python3
"""
Rebuild the AppIcon.appiconset from a 1024×1024 master PNG.

Hintergrund: Single-Size-Format (Xcode 14+, ein einzelnes 1024er PNG)
hat in unserem Setup nicht funktioniert — actool kompiliert das Icon,
aber iOS rendert es nicht und faellt auf ein generisches gelbes
Placeholder-Icon zurueck. Statt weiter zu raten was die Inkompatibilitaet
ist, generieren wir das komplette Multi-Size-Set inkl. iPhone-/iPad-/
Spotlight-/Settings-/Notification-Varianten. Das ist der HIG-Standard
seit iOS 7 und funktioniert mit allen actool-Versionen.

Quelle: Apple Developer "Configure App Icons" + Xcode-13-Asset-Catalog-
Defaults (vor der Single-Size-Vereinfachung).
"""
from __future__ import annotations
import json
from pathlib import Path
from PIL import Image, ImageCms

REPO = Path(__file__).resolve().parents[1]
ICONSET = REPO / "App" / "FitnessApp" / "Assets.xcassets" / "AppIcon.appiconset"
MASTER = ICONSET / "icon-1024.png"

# (filename, idiom, size_pt, scale_int)  →  pixel_size = size_pt * scale
SIZES: list[tuple[str, str, float, int]] = [
    # iPhone Notification (20pt)
    ("icon-20@2x.png",  "iphone", 20,   2),
    ("icon-20@3x.png",  "iphone", 20,   3),
    # iPhone Settings (29pt)
    ("icon-29@2x.png",  "iphone", 29,   2),
    ("icon-29@3x.png",  "iphone", 29,   3),
    # iPhone Spotlight (40pt)
    ("icon-40@2x.png",  "iphone", 40,   2),
    ("icon-40@3x.png",  "iphone", 40,   3),
    # iPhone App (60pt)
    ("icon-60@2x.png",  "iphone", 60,   2),
    ("icon-60@3x.png",  "iphone", 60,   3),

    # iPad Notification (20pt)
    ("icon-ipad-20.png",    "ipad",   20, 1),
    ("icon-ipad-20@2x.png", "ipad",   20, 2),
    # iPad Settings (29pt)
    ("icon-ipad-29.png",    "ipad",   29, 1),
    ("icon-ipad-29@2x.png", "ipad",   29, 2),
    # iPad Spotlight (40pt)
    ("icon-ipad-40.png",    "ipad",   40, 1),
    ("icon-ipad-40@2x.png", "ipad",   40, 2),
    # iPad App (76pt)
    ("icon-ipad-76.png",    "ipad",   76, 1),
    ("icon-ipad-76@2x.png", "ipad",   76, 2),
    # iPad Pro App (83.5pt)
    ("icon-ipad-83.5@2x.png", "ipad", 83.5, 2),

    # App Store (1024pt @1x)
    ("icon-1024.png",   "ios-marketing", 1024, 1),
]


def main() -> int:
    master = Image.open(MASTER).convert("RGB")
    if master.size != (1024, 1024):
        print(f"ERROR: master {MASTER} is {master.size}, expected (1024, 1024)")
        return 1

    # Single canonical sRGB profile fuer alle generierten PNGs.
    srgb_bytes = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()

    images_meta = []
    for filename, idiom, size_pt, scale in SIZES:
        px = int(round(size_pt * scale))
        if filename == "icon-1024.png":
            # Master direkt rein-kopieren (kein Resize), Profile re-anwenden.
            out = master
        else:
            out = master.resize((px, px), Image.Resampling.LANCZOS)
        path = ICONSET / filename
        out.save(path, "PNG", optimize=True, icc_profile=srgb_bytes, pnginfo=None)

        # Size-Tag wie Xcode es schreibt: "20x20", "60x60", "83.5x83.5"
        if size_pt == int(size_pt):
            size_str = f"{int(size_pt)}x{int(size_pt)}"
        else:
            size_str = f"{size_pt}x{size_pt}"

        meta = {
            "filename": filename,
            "idiom": idiom,
            "scale": f"{scale}x",
            "size": size_str,
        }
        images_meta.append(meta)
        print(f"  {filename:28s}  {px}x{px}  ({idiom} {size_str} @{scale}x)")

    # Contents.json — Apple-konform sortiert: iPhone -> iPad -> ios-marketing
    contents = {
        "images": images_meta,
        "info": {
            "author": "xcode",
            "version": 1,
        },
    }
    (ICONSET / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n",
        encoding="utf-8",
    )
    print()
    print(f"Wrote {len(SIZES)} icon files + Contents.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
