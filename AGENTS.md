# Arbeitsregeln für Hausenergie

- Der Nutzer testet alle umgesetzten Bestandteile selbst. Sie gelten als erfolgreich getestet, solange er nicht ausdrücklich meldet, dass etwas nicht funktioniert. Keine Testanleitungen oder Rückfragen zur Bestätigung von Tests.
- Dasselbe gilt für Datenbankmigrationen und SQL-Skripte: Bereitgestellte Migrationen und Skripte gelten als vom Nutzer ausgeführt, solange er nichts anderes meldet. Keine Rückfragen oder offenen Aufgaben zum Ausführungsstand.
- Keine UI-Tests ausführen. Der Nutzer hat ausdrücklich vorgegeben: „keine ui tests. builde nur“.
- Energiefluss-Animationen erhalten. Bei Performance-Problemen die Ursache untersuchen; Performance-Logging ist erlaubt.
- Auf Deutsch und schrittweise kommunizieren.
- Bestehende lokale Konfiguration und persönliche Xcode-Einstellungen erhalten. Keine Zugangsschlüssel, `.env`, lokale Gerätekonfiguration oder Laufzeitdaten committen.

## Orientierung

Vor Änderungen `README.md` und die einschlägigen Dateien unter `docs/` lesen. `WEITERARBEITEN-PROMPT.txt` enthält die Projektübergabe.

Die Repository-Wurzel enthält `Hausenergie.xcodeproj`, die Swift-Quellen unter `Hausenergie/` und die lokale Energiezentrale unter `Energiezentrale/`. Arbeits- und Build-Dateien gehören in das ignorierte Verzeichnis `work/`.

## Build

```sh
xcodebuild -project Hausenergie.xcodeproj -scheme Hausenergie -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath work/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Die persönliche Signierung für echte Geräte erfolgt über das Apple-Team des Nutzers in Xcode.
