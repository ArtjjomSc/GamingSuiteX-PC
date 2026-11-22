# GamingSuite X

### ⬇️ [Hier herunterladen (neueste Version)](https://github.com/ArtjjomSc/GamingSuiteX-PC/releases/latest)

**Dein Spiel ruckelt, und du weißt nicht warum? GamingSuite X misst es, findet die Ursache und erklärt sie in einfachen Worten.**

Kostenloses Tool für Windows – gemacht für Spieler, die sich **nicht** mit Hardware, BIOS oder Registry auskennen wollen. Kein „FPS-Booster“ mit Wundertricks, sondern ehrliche Messwerte und verständliche Empfehlungen. Dazu eine Handy- bzw. Web-App als Zweitbildschirm.

> 🇬🇧 *Free Windows tool that measures how smoothly your games really run (1% lows, stutters per minute), checks your hardware for common mistakes and explains the results in plain language. No "FPS booster" magic. UI is currently German only.*

## Screenshots

| PC-Programm | Handy-App |
|---|---|
| ![Dashboard](docs/dashboard.png) | <img src="docs/app.png" width="260"> |

---

## Was GamingSuite X macht

### 1. Messen: Wie flüssig läuft dein Spiel wirklich?
- Erkennt jedes laufende Spiel automatisch (Steam, Epic, GOG, Ubisoft, EA, Battle.net, Riot, Xbox) – oder du startest es per Knopf aus der **Spielebibliothek**.
- Misst nicht nur die durchschnittlichen FPS, sondern das, was man als Ruckeln spürt: **1%-Low, 0,1%-Low und Hänger pro Minute**.
- Sagt dir, **woran es liegt**: Grafikkarte am Limit, Prozessor am Limit, Grafikspeicher voll, Frame Generation mit zu wenig echten Bildern – und was du dagegen tun kannst.
- Menüs, Ladebildschirme und Alt+Tab werden automatisch herausgefiltert, damit die Werte stimmen.

### 2. Prüfen: Ist deine Hardware richtig eingerichtet?
Viele PCs verschenken Leistung durch Kleinigkeiten, die man nicht sieht. GamingSuite X prüft und erklärt:
- Läuft der Arbeitsspeicher mit vollem Tempo (**XMP/EXPO**) und im **Dual-Channel**?
- Ist das **BIOS** oder der **Grafiktreiber** sehr alt?
- Ist **Resizable BAR** aktiv? Liegt Windows auf einer SSD, ist genug Platz frei?

Hier wird nichts verändert – du bekommst nur einen Hinweis und eine Erklärung.

### 3. Einstellen: Nur behutsam und nur, wenn du willst
- „Alles optimieren“ setzt nur wenige, **risikoarme** Windows-Einstellungen (Spielmodus, GPU-Planung, Game DVR aus).
- Alles andere ist **optional**, wird einzeln angekreuzt und erklärt – inklusive Nachteilen (z. B. höherer Stromverbrauch).
- Vor jeder Änderung wird ein **Backup** angelegt. **„Alles zurücksetzen“** stellt den Originalzustand wieder her.
- Für Counter-Strike 2 und Battlefield 6 kann die Grafik automatisch an deine Monitor-Hz angepasst werden (auf Wunsch, mit Sicherung der Spieldateien).

### Was GamingSuite X bewusst **nicht** macht
- **Keine Windows-Dienste** abschalten (Drucker, Suche usw. funktionieren weiter).
- **Keine** dauerhaft höheren Stromverbrauch ohne Nachfrage (Energiesparplan „Höchstleistung“ nur optional, mit Hinweis).
- **Keine** Sicherheitsfunktionen ohne ausdrückliche Warnung ändern.
- **Nichts** in laufende Spiele einschleusen (wichtig wegen Anti-Cheat).
- **Keine** Telemetrie, keine Werbung, kein Konto.

### Weitere Funktionen
| Bereich | Was es macht |
|---|---|
| **Dashboard & Live-Monitor** | CPU, GPU, RAM, Laufwerke, Netzwerk und Temperaturen live, mit Verlaufskurven |
| **Handy / Browser** | Android-App oder Web-App (iPhone, Tablet, jeder Browser) zeigt alle Werte im WLAN, **nur lesend** |
| **Fehlerbericht** | Ein Klick erzeugt eine ZIP-Datei für Issues, ohne PC-Name, Benutzername und Prozessliste |

## Voraussetzungen

- **Windows 10 (ab 1709) oder Windows 11**, mit Windows PowerShell 5.1 (bereits vorinstalliert)
- Administratorrechte, die nötig für den Optimizer sind. Das Programm fragt beim Start danach.
- Grafikkarte: **NVIDIA, AMD und Intel** werden unterstützt.
  - GPU-Auslastung und VRAM kommen bei allen Herstellern über Windows.
  - Die GPU-**Temperatur** wird bei NVIDIA direkt gelesen. Bei AMD/Intel und für die CPU-Temperatur braucht es zusätzlich [LibreHardwareMonitor](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor), gestartet als Administrator.
- macOS und Linux werden **nicht** unterstützt, weil alle Optimierungen Windows-Einstellungen betreffen.

## Installation

1. Unter [Releases](../../releases) die neueste `GamingSuiteX-PC-vX.Y.zip` herunterladen.
2. Entpacken, z. B. nach `C:\GamingSuiteX`. Der Ordner `Modules` muss neben `GamingSuiteX.ps1` liegen.
3. `START_GamingSuiteX.bat` doppelklicken.
   - Fragt Windows nach Administratorrechten, mit **Ja** bestätigen.
   - Erscheint „Der Computer wurde durch Windows geschützt“: **Weitere Informationen**, dann **Trotzdem ausführen** (siehe [FAQ](#faq)).
   - Fragt die Firewall nach: **Private Netzwerke** zulassen. Das ist nur für den Handy-Zugriff nötig.
4. Beim ersten Start erscheint ein Hinweis, den du bestätigen musst.

## Handy-App / Web-App

Du kannst dein Handy oder Tablet als zweiten Bildschirm nutzen und dort alle Werte sehen – auch während du spielst. **Eine IP-Adresse musst du dafür nicht selbst herausfinden.**

**So geht's (iPhone, Android, Tablet):**
1. Handy und PC müssen im **selben WLAN / Heimnetz** sein. (Der PC darf per Kabel am Router hängen.)
2. GamingSuite X am PC starten und links auf **Settings** klicken.
3. Dort siehst du einen **QR-Code** und daneben die Adresse, z. B. `http://192.168.178.20:47801`.
4. Am Handy die **Kamera-App** öffnen und den QR-Code scannen – die Seite öffnet sich im Browser. Alternativ die Adresse genau so in Safari oder Chrome eintippen.
5. Tipp: Im Browser **Teilen → „Zum Home-Bildschirm“** – dann liegt GamingSuite X wie eine App auf dem Handy.

**Android-App (optional):** `GamingSuiteX.apk` aus den [Releases](../../releases) installieren („Unbekannte Apps installieren“ erlauben), dann **PC CONNECT → Automatisch suchen**. Die App findet den PC von selbst.

**Klappt nicht?**
- Sind Handy und PC wirklich im selben WLAN? (Gäste-WLAN oder mobile Daten funktionieren nicht.)
- Hat Windows beim ersten Start nach der Firewall gefragt? Dann **„Zulassen“** wählen.
- Die Adresse muss mit `http://` beginnen (nicht https) und mit `:47801` enden.
- Unter **Settings** muss „Zugriff im WLAN erlauben“ angehakt sein.

Der Zugriff ist **nur lesend** – vom Handy aus lässt sich am PC nichts ändern. Unter **Settings** kannst du ihn abschalten oder mit einer **PIN** schützen (die Web-App fragt die PIN automatisch ab; in der Android-App gibt es dafür ein PIN-Feld im Fenster „Mit PC verbinden“).

## Sicherheit & Datenschutz

- **Ohne Gewähr.** Der Optimizer ändert nur Einstellungen, die du bestätigst (Registry, auf Wunsch Energiesparplan und Netzwerk). Dienste wie Druckerwarteschlange oder Windows-Suche werden **nicht** angefasst. Energiesparplan „Höchstleistung“, CPU-Mindestleistung 100 % und Power Throttling sind nur optional, weil sie den Stromverbrauch auch im Leerlauf erhöhen (je nach PC ca. 10–50 W). Vor jeder Änderung wird ein Backup angelegt, und **„Alles zurücksetzen“** stellt den Originalzustand wieder her. Im Zweifel vorher einen Wiederherstellungspunkt anlegen.
- **„Alles optimieren“** ändert nur unkritische Einstellungen:
  - Energiesparplan, CPU-Mindestleistung, Power Throttling, Spiele-Priorität (MMCSS), Mausbeschleunigung und Netzwerk-Tweaks sind **optional** und werden nur einzeln per Haken gesetzt.
  - Die **Speicher-Integrität** (Kernisolierung) wird nie automatisch geändert. Sie hat einen eigenen Knopf mit Warnung, denn das Ausschalten senkt die Sicherheit von Windows.
  - Bei **AMD Ryzen X3D mit zwei CCDs** (z. B. 7950X3D) bleiben Energiesparplan, Core-Parking und Game Bar unangetastet, weil der 3D-Cache sie braucht.
- **Spiele-Einstellungen** (CS2, Battlefield 6) werden nur bei geschlossenem Spiel geändert, vorher wird gesichert. Es wird nichts in laufende Spiele eingeschleust, wichtig wegen Anti-Cheat.
- **Keine Telemetrie.** Es werden keine Daten ins Internet gesendet. Einzige Internetverbindung: der einmalige Download von Intel PresentMon von GitHub.
- Der Handy-Server lauscht nur im lokalen Netz (Port 47801 TCP, 47800 UDP). Die Firewall-Regeln gelten nur für **private** Netzwerke.

## FAQ

**Windows SmartScreen oder Virenscanner warnt?**
Das Programm ist nicht digital signiert, denn ein Zertifikat kostet Geld. PowerShell-Skripte, die Admin-Rechte nutzen, die Registry ändern und etwas herunterladen, lösen bei manchen Scannern Fehlalarme aus. Der komplette Quellcode liegt offen in diesem Repository und kann geprüft werden.

**Die FPS-Messung startet nicht oder bricht ab?**
Das Spiel muss mindestens etwa 3,5 Minuten im Vordergrund laufen (90 s Wartezeit plus 2 min Messung). Menüs und Alt+Tab werden automatisch herausgefiltert. Manche Anti-Cheat-Systeme können die Messung blockieren. Dann bitte einen Fehlerbericht erstellen.

**Bringt das Tool mehr FPS?**
Meistens nicht in großem Umfang – und das ist ehrlich gemeint. Moderne Windows-Versionen sind für Spiele bereits gut eingestellt. Den größten Unterschied machen fast immer richtig eingerichtete Hardware (XMP, Dual-Channel, aktuelle Treiber) und passende Grafikeinstellungen. Genau das findet GamingSuite X heraus. Ob eine Änderung bei dir etwas bringt, kannst du selbst prüfen: Spiel vorher und nachher an derselben Stelle messen und 1%-Low sowie Hänger pro Minute vergleichen.

**Warum steht bei Frame Generation „echt 33“?**
Mit Frame Generation sind die angezeigten FPS etwa doppelt so hoch wie die echt berechneten. Für die Eingabeverzögerung zählen die echten FPS, unter etwa 55 fühlt es sich träge an.

## Fehler melden

**Settings → Fehlerbericht erstellen** legt eine ZIP-Datei auf den Desktop. Bitte ein [Issue](../../issues/new/choose) eröffnen und die Datei anhängen.

## Projektaufbau

```
pc/        Windows-Programm (PowerShell 5.1 + WinForms)
  GamingSuiteX.ps1          Startskript
  START_GamingSuiteX.bat    Starter (holt Admin-Rechte)
  Modules/                  Module (Hardware, Optimizer, Spiele-Tuning, UI, Handy-Server ...)
  Modules/web/              Web-App für Handy/Browser
mobile/    Android-App (Flutter), Quellcode unter lib/
docs/      Anleitungen (Release, Android-Build)
```

## Entstehung

GamingSuite X ist ein Freizeitprojekt von ArtjjomSc und wurde **mit Unterstützung von KI (Claude)** entwickelt. Idee, Ausrichtung, Tests und Entscheidungen stammen von mir. Feedback und Verbesserungsvorschläge von erfahrenen Leuten sind ausdrücklich willkommen – gern als [Issue](../../issues).

## Lizenz

[MIT](LICENSE). Kostenlos nutzen, verändern und weitergeben. Verwendete Fremdsoftware siehe [THIRD_PARTY.md](THIRD_PARTY.md).
