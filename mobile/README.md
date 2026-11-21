# GamingSuite X – Android-App (Flutter)

Zeigt die Werte des PCs (Dashboard, Diagnose, Spiele-Messungen, Gaming Mode als Vollbild-Monitor) und echte Handy-Systemdaten. Die App liest nur, sie ändert am PC nichts.

## Aufbau

```
lib/main.dart                   Dashboard
lib/device/device_stats.dart    Handy-Daten (/proc, /sys – ohne Root, ohne Zusatzpakete)
lib/pc/pc_connection.dart       Verbindung zum PC (UDP-Suche Port 47800, HTTP Port 47801)
lib/pc/pc_stats.dart            Datenmodell /api/stats
lib/pc/pc_games_data.dart       Datenmodell /api/games
lib/pc/pc_diagnostics_screen.dart  PC-Diagnose
lib/pc/pc_games_screen.dart     Spiele-Messungen
lib/gaming/gaming_mode_screen.dart Gaming Mode (Vollbild, Bildschirm bleibt an)
```

Zusätzlich nötig im Android-Projekt:
- `android/app/src/main/AndroidManifest.xml`: `<uses-permission android:name="android.permission.INTERNET"/>` und `android:usesCleartextTraffic="true"` beim `<application>`-Tag
- `MainActivity.kt`: Kanal `gsx/screen` für „Bildschirm bleibt an“ (siehe Gaming Mode)

## Bauen

```bash
flutter pub get
flutter analyze
flutter build apk --release --target-platform android-arm64
```

In **Termux** muss zusätzlich das ARM-taugliche `aapt2` verwendet werden:
```bash
pkg install aapt2
echo "android.aapt2FromMavenOverride=$PREFIX/bin/aapt2" >> android/gradle.properties
```

## Bekannte Einschränkungen
- Die **PIN** (PC → Settings) unterstützt derzeit nur die Web-App. Ist eine PIN gesetzt, zeigt die Android-App „Keine Verbindung“.
- Die CPU-Auslastung des Handys gibt Android Apps nicht frei. Angezeigt wird deshalb der CPU-Takt.
