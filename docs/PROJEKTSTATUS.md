# Projektstatus Hausenergie

Stand: 27. Oktober 2026. Hausenergie ist eine native iPhone- und iPad-App mit einer lokalen Energiezentrale für Victron und go-e. Die aktuelle Version 1.0.1, Build 2, enthält eine bedienbare Demo und implementierte Schnittstellen. Als Nächstes wird die vorhandene Hausanlage für den lesenden Betrieb eingerichtet.

## Ziele des Nutzers

Die App soll Energieflüsse im Haus verständlich darstellen, Anlage und Kosten überwachen und die Verteilung von PV-Strom zwischen Haus, Hausakku, Audi und Netz optimieren. Langfristig soll die Planung Erzeugung, Hausbedarf, Abfahrtsziele, Strompreise und Einspeisevergütung gemeinsam berücksichtigen.

Die Oberfläche soll auf iPhone und iPad gut bedienbar sein. Der Nutzer hat die Gestaltung ausdrücklich positiv bewertet und möchte die Energiefluss-Animationen erhalten.

## Vorhandene Hausanlage

| Bestandteil | Bekannter Stand |
| --- | --- |
| Wechselrichter | 3 × Victron MultiPlus 5000; genaue Modelle und Verschaltung noch nicht dokumentiert |
| Solarregler | 2 × Victron MPPT |
| Steuerung | Cerbo GX mit Venus OS; Firmware-Version noch nicht bekannt |
| Ältere PV-Anlage | Erfassung über 2 Victron-Energiezähler |
| Netzanschluss | Erfassung über einen Victron-Energiezähler |
| Hausakku | Batrium-Batteriemanagement; Modell, Kapazität und Leistungsgrenzen noch nicht bekannt |
| Wallbox | go-e Charger CORE; konkrete Konfiguration noch nicht bekannt |
| Fahrzeug | Audi A6 e-tron, Modelljahr 2027; genaue Variante und AC-Ausstattung noch nicht bekannt |

Aus der Bezeichnung MultiPlus 5000 darf keine bestätigte Gesamt-Wirkleistung von 15 kW oder eine bestimmte Phasenverschaltung abgeleitet werden.

## Implementierter Funktionsumfang

| Bereich | Stand |
| --- | --- |
| Übersicht | Energieflussbild, aktuelle Leistungen, Ladezustände und Gerätehinweise |
| Laden | Fünf Modi, Ziel-Ladestand, nächste Abfahrt, Netzfreigabe und Bedarfsrechnung |
| Planung | Regelbasierte Planung nach PV-Überschuss und Abfahrtszeit |
| Auswertung | Tagesverlauf, aus Leistungswerten integrierte Energie und Kostensaldo |
| Anlage | Geräteübersicht, PV-Quellen und Hausakku-Reserve |
| Einstellungen | Verbindungsdaten, Fahrzeugannahmen, Preise und Darstellung |
| Diagnose | Lokale Performance-Aufzeichnung und JSON-Export |
| Energiezentrale | Victron-MQTT-Lesen, go-e HTTP API v2, SQLite-Verlauf und optionale Wallboxregelung |

Die Standardwerte für Fahrzeugkapazität, Ladeleistung, Strompreis, Vergütung und Reserve sind editierbare Annahmen. Sie sind keine bestätigten Anlagendaten.

## Aktueller Betriebsstand

Die Konfiguration enthält noch keine tatsächlichen Geräteadressen oder zugeordneten PV-Gerätepfade. Ein dauerhaft laufender Rechner für die Energiezentrale ist noch nicht festgelegt. Die bisherige App-Darstellung basiert auf gekennzeichneten Beispieldaten.

Der Python-Dienst kann ohne Docker betrieben werden. Docker-Dateien sind als zusätzliche Betriebsvariante vorhanden. Im Rahmen der bisherigen Arbeit wurde Docker weder installiert noch gestartet. Auch der Gateway-Dienst wurde durch den Agenten nicht im Heimnetz eingerichtet oder für Gerätezugriffe gestartet.

## Performance und Geräteblockade

Der Nutzer meldete zunächst eine sehr langsame App und anschließend eine Blockade des iPhone bis hin zu fehlender Scroll- und Schließmöglichkeit. Daraufhin wurde Version 1.0.1 erstellt.

Ein auffälliger Fehler lag in der Energiefluss-Animation: Der Strichversatz wurde aus dem absoluten Datum berechnet und erreichte rund 11,4 Milliarden Punkte bei einer Musterlänge von 12 Punkten. Die neue Implementierung verwendet vier `CAShapeLayer` mit einer `CABasicAnimation` von 0 bis plus oder minus 12 Punkten. Die Animationen sind erhalten; ein wiederkehrender SwiftUI-Timer ist dafür nicht mehr erforderlich.

Weitere Änderungen sind zwischengespeicherte Demodaten und Auswertungen, bedarfsgerecht aufgebaute Ansichten, getrennte Abrufintervalle für Momentanwerte und Verlauf sowie Verarbeitung und Speicherung außerhalb des UI-Aktors. Diagramme verwenden höchstens 360 ausgewählte Messpunkte, die Energieberechnung weiterhin die vollständige Historie.

Die große Animationsphase ist ein begründeter Ursachenverdacht. Es liegen bisher keine exportierten Geräteprotokolle vor, die sie als alleinige Ursache der Blockade bestätigen. Die vorhandene Diagnose erfasst UI-Wartezeiten, Callbackrate, CPU-Zeit, Speicher-Spitzenwert und Aufbereitungszeiten. Ihre Callbackrate ist keine direkte GPU-Bildratenmessung.

## Build und Arbeitsregeln

Das GitHub-Repository ist `florianwildt/Energie-Dashboard`, der Hauptbranch heißt `main`. Die versionierten Dateien beginnen unmittelbar mit `Hausenergie.xcodeproj`, `Hausenergie/`, `Energiezentrale/` und `docs/`. Die lokale Verzeichnisstruktur des ursprünglichen Chats ist für einen neuen Checkout nicht erforderlich. Die konkreten Regeln stehen zusätzlich in `AGENTS.md`.

Der letzte dokumentierte Build mit Xcode 27.1 für ein generisches iOS-Gerät endete mit `BUILD SUCCEEDED`. Er erfolgte ohne Codesignierung und ohne UI-Tests. Die persönliche Gerätesignierung wird in Xcode über das Apple-Team des Nutzers eingerichtet. Build-Artefakte und das Build-Protokoll liegen außerhalb des auszuliefernden Projekts im Arbeitsordner `work`.

Für die Weiterarbeit gelten die direkten Nutzeranweisungen:

- Keine UI-Tests ausführen; nur bauen.
- Der Nutzer erprobt umgesetzte Bestandteile selbst. Sie gelten als erfolgreich, solange er nicht ausdrücklich einen Fehler meldet. Keine Testanleitungen oder Rückfragen zur Testbestätigung.
- Bereitgestellte Datenbankmigrationen und SQL-Skripte gelten ebenfalls als ausgeführt, sofern der Nutzer nichts anderes meldet. Keine Rückfragen zum Ausführungsstand.
- Animationen erhalten; Performance-Probleme anhand der Ursache bearbeiten. Performance-Logging ist ausdrücklich erlaubt.
- Schrittweise und in verständlicher deutscher Sprache vorgehen.
- Keine neuen Agenten oder Chats starten, sofern der Nutzer dies nicht ausdrücklich beauftragt.

## Nächste Arbeitsschritte

1. Rechner für die lokale Energiezentrale festlegen. Bei einem NAS werden Hersteller und Modell benötigt.
2. IP-Adressen von Cerbo GX und go-e CORE sowie Venus-Version und GX-Portal-ID übernehmen. Passwörter und Zugriffsschlüssel bleiben lokal.
3. Lokalen MQTT-Zugriff und die go-e HTTP API v2 passend zur tatsächlichen Firmware einrichten.
4. Vorhandene Geräteinstanzen und Messpfade zuordnen. Die beiden PV-Zähler und die MPPT dürfen nicht doppelt in eine Bilanz eingehen.
5. Ermitteln, ob die Wallbox bereits im Victron-Verbrauch enthalten ist; `wallboxIncludedInConsumption` entsprechend setzen.
6. Energiezentrale im Lesemodus auf dem ausgewählten Rechner einrichten, die App verbinden und tatsächliche Anlagenparameter hinterlegen.
7. Vor unbeaufsichtigter Regelung das geräteseitige Rückfallverhalten bei Ausfall der Zentrale und die Begrenzung je Anschlussphase ergänzen. Die Fähigkeiten der konkreten Firmware sind hierfür entscheidend.
8. Danach die bestehende Wallboxregelung mit der Victron-ESS-Strategie koordinieren. Erst darauf aufbauend die gemeinsame wirtschaftliche Optimierung ausbauen.

## Noch nicht implementiert

Automatischer myAudi-Zugriff, Wetterprognosen, dynamische Tarife, getrennte PV-Vergütungen, schreibende ESS-Steuerung, automatische Phasenumschaltung, V2H/V2G, Push-Meldungen und mehrtägige Auswertungsansichten sind nicht enthalten. Ein zuverlässiger Fahrzeug-SoC-Zugriff für den konkreten Audi wurde nicht bestätigt.

## Änderungen an der Dokumentation

Am 27. Oktober 2026 wurden der Übergabeprompt, die Beschreibung der Architektur und der Ablauf für die Inbetriebnahme ergänzt. Diese Dokumentationspflege verändert weder App-Funktionen noch Gerätefreigaben. Die aktuelle App-Symbolzuordnung auf `AppIcon-v2.png` bleibt erhalten.
