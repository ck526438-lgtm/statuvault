"""Applique les réglages Statuvault aux dossiers android/ et ios/ générés par `flutter create`."""
import glob
import os
import plistlib
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

# --- Android : MainActivity (canal SAF) ---------------------------------
if os.path.isdir("android"):
    acts = glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True)
    assert acts, "MainActivity.kt introuvable"
    gen = open(acts[0], encoding="utf-8").read()
    pkg = re.search(r"^package\s+([\w.]+)", gen, re.M).group(1)
    src = open("native/android/MainActivity.kt", encoding="utf-8").read()
    src = re.sub(r"^package\s+[\w.]+", f"package {pkg}", src, count=1, flags=re.M)
    open(acts[0], "w", encoding="utf-8").write(src)

    man_path = "android/app/src/main/AndroidManifest.xml"
    man = open(man_path, encoding="utf-8").read()
    man = re.sub(r'android:label="[^"]*"', 'android:label="Statuvault"', man, count=1)
    perm = ('<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" '
            'android:maxSdkVersion="28" />')
    if "WRITE_EXTERNAL_STORAGE" not in man:
        man = man.replace("<application", perm + "\n    <application", 1)
    open(man_path, "w", encoding="utf-8").write(man)
    print("Android patché, package", pkg)

# --- iOS : Info.plist ----------------------------------------------------
plist_path = "ios/Runner/Info.plist"
if os.path.exists(plist_path):
    with open(plist_path, "rb") as f:
        pl = plistlib.load(f)
    pl["CFBundleDisplayName"] = "Statuvault"
    pl["CFBundleName"] = "Statuvault"
    pl["NSPhotoLibraryAddUsageDescription"] = "Statuvault enregistre tes statuts dans l'album « Statuvault » de ta galerie."
    pl["NSPhotoLibraryUsageDescription"] = "Statuvault a besoin de tes photos pour importer des statuts."
    pl["UIFileSharingEnabled"] = True
    pl["LSSupportsOpeningDocumentsInPlace"] = False
    with open(plist_path, "wb") as f:
        plistlib.dump(pl, f)
    print("iOS patché")
