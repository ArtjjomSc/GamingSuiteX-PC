# Veröffentlichen auf GitHub – Schritt für Schritt

## 1. Repository anlegen (einmalig, im Browser)

1. Auf https://github.com ein Konto anlegen bzw. anmelden.
2. Oben rechts auf **+**, dann **New repository**.
   - Name: `GamingSuiteX`
   - **Public** auswählen.
   - **Kein** Häkchen bei „Add a README“, denn wir bringen eine mit.
3. **Create repository**.

## 2. Dateien hochladen (ohne Git, im Browser)

1. Im neuen Repository auf **uploading an existing file** klicken.
2. Den **Inhalt** dieses Ordners hineinziehen: `README.md`, `LICENSE`, `THIRD_PARTY.md`, `.gitignore` und die Ordner `pc`, `mobile`, `docs`, `.github`.
   > Ordner, die mit einem Punkt beginnen (`.github`, `.gitignore`), zeigt Windows manchmal nicht an. Im Explorer unter **Ansicht** → **Einblenden** → **Ausgeblendete Elemente** aktivieren.
3. Unten **Commit changes**.
4. In `LICENSE` oben **[DEIN NAME ODER GITHUB-NAME]** durch deinen Namen ersetzen: Datei öffnen, auf den Stift klicken, ändern und speichern.

## 3. Release erstellen (für jede neue Version)

**PC-Paket:**
1. Den Ordner `pc` öffnen und **alles darin** markieren (`GamingSuiteX.ps1`, `START_GamingSuiteX.bat`, `Modules`).
2. Rechtsklick → **Komprimieren in ZIP-Datei** → umbenennen in `GamingSuiteX-PC-v11.4.zip`.

**Android-App:** siehe Abschnitt 4. Ergebnis ist `GamingSuiteX-v11.4.apk`.

**Auf GitHub:**
1. Rechts auf **Releases** → **Create a new release**.
2. **Tag:** `v11.4` (neu erstellen). **Titel:** `GamingSuite X 11.4`.
3. Darunter kurz beschreiben, was neu ist.
4. ZIP und APK in das Feld **Attach binaries** ziehen.
5. Wenn es noch nicht alle getestet haben, **Set as a pre-release** anhaken.
6. **Publish release**.

## 4. Android-App für die Veröffentlichung signieren (Termux)

Die bisherige `app-debug.apk` ist nur zum Testen gedacht. Für die Veröffentlichung braucht die App einen **eigenen Schlüssel**.

> ⚠️ **Den Schlüssel und die Passwörter gut sichern**, z. B. auf einem USB-Stick oder im Passwortmanager. Geht der Schlüssel verloren, können Nutzer spätere Versionen nicht mehr als Update installieren. Der Schlüssel darf **nie** auf GitHub landen. Die `.gitignore` schließt ihn schon aus.

**4.1 Schlüssel erzeugen (einmalig):**
```bash
keytool -genkey -v -keystore ~/gsx-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias gsx
```
Das Programm fragt nach einem Passwort und nach Name und Ort. Die können beliebig sein.

**4.2 Datei `android/key.properties` anlegen:**
```bash
cd ~/GamingSuiteX-Mobile
cat > android/key.properties <<'EOF'
storePassword=DEIN_PASSWORT
keyPassword=DEIN_PASSWORT
keyAlias=gsx
storeFile=/data/data/com.termux/files/home/gsx-release.jks
EOF
```

**4.3 Signierung in `android/app/build.gradle.kts` eintragen:**
Erst die Datei anzeigen und an mich bzw. die Entwicklung schicken, bevor etwas geändert wird:
```bash
cat android/app/build.gradle.kts
```
Eingetragen werden muss der offizielle Flutter-Block (`signingConfigs` → `release`, siehe https://docs.flutter.dev/deployment/android#configure-signing-in-gradle).

**4.4 Release bauen:**
```bash
flutter build apk --release --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-release.apk ~/storage/downloads/GamingSuiteX-v11.4.apk
```

## 5. Vor einer öffentlichen Version testen

- [ ] Auf mindestens einem **AMD-** und einem **Intel/NVIDIA-System** starten
- [ ] Optimizer: **Alles optimieren**, dann **Alles zurücksetzen** und prüfen, ob alles wieder wie vorher ist
- [ ] Ein Spiel 4 Minuten spielen: Erscheint die Messung?
- [ ] Web-App am Handy öffnen, auch mit PIN
- [ ] **Fehlerbericht erstellen** und die ZIP-Datei auf private Daten prüfen
