# Architektur und Schnittstellen von Hausenergie

Die native App ist die Bedienoberfläche. Ein separater Dienst im Haus sammelt Messwerte, speichert Verläufe und führt ausdrücklich übernommene Wallbox-Ladepläne aus. Die bestehenden Schutzfunktionen von Victron, Batrium und go-e bleiben auf den Geräten.

## Datenwege

```text
Victron-Geräte und Batrium
          |
       Cerbo GX -- lokales MQTT --+
                                 |
go-e CORE ---- lokale HTTP API --+-- Energiezentrale -- HTTP oder HTTPS -- iPhone und iPad
                                 |
                               SQLite
```

Die Victron-Anbindung liest `N/<Portal-ID>/...` und sendet ausschließlich Lese-Keepalives unter `R/<Portal-ID>/keepalive`. Sie schreibt keine `W/...`-Sollwerte. Batrium wird über die verfügbaren Batteriewerte am Cerbo eingebunden; eine zusätzliche direkte Zellüberwachung ist nicht implementiert.

## Komponenten der App

| Datei oder Ordner | Aufgabe |
| --- | --- |
| `Hausenergie/HausenergieApp.swift` | App-Einstieg, Darstellung und aktive Aktualisierungssitzung |
| `Hausenergie/Models/EnergyModels.swift` | Momentanwerte, Geräte, Einstellungen und Ladebedarfsrechnung |
| `Hausenergie/Models/EnergyHistory.swift` | Sortierung, Diagrammverdichtung und Energiesummen |
| `Hausenergie/Services/EnergyStore.swift` | Beobachtbarer UI-Zustand, Demo und Übernahme von Ladeplänen |
| `Hausenergie/Services/GatewayClient.swift` | Netzwerk, Dekodierung und Hintergrundspeicherung |
| `Hausenergie/Services/PerformanceLog.swift` | Begrenztes lokales Protokoll und Apple-Signposts |
| `Hausenergie/Views/FlowConnectionsView.swift` | Grafikbasierte Energiefluss-Animation |
| `Hausenergie/Views/EnergyChartView.swift` | Swift-Charts-Darstellung mit Datenauswahl |
| `Hausenergie/Views/` | Fünf Hauptbereiche, Einstellungen und gemeinsame Gestaltung |

Momentanwerte werden im Livebetrieb alle fünf Sekunden geladen, der Verlauf in der Regel alle 60 Sekunden. Beim manuellen Aktualisieren kann zusätzlich ein neuer Verlauf angefordert werden. Im Demomodus läuft keine dauerhafte Abfrageschleife.

Der Gateway-Schlüssel liegt im iOS-Schlüsselbund. Andere Einstellungen liegen lokal in UserDefaults. Einstellungsänderungen werden nach 400 Millisekunden gebündelt gespeichert; beim Verlassen der Einstellungen und beim Wechsel in den Hintergrund wird eine Speicherung angestoßen.

## Lokale Energiezentrale

`Energiezentrale/gateway.py` verwendet Python ab Version 3.11. HTTP-Server, JSON, SQLite und Geräteabfragen basieren auf der Standardbibliothek. Für MQTT wird `paho-mqtt` aus `requirements.txt` benötigt.

Der Standardstart bindet nur an `127.0.0.1:8787`. Für den Zugriff aus dem Heimnetz wird `--host 0.0.0.0` verwendet. Alle API-Endpunkte verlangen den Zugriffsschlüssel im Header `Authorization: Bearer <Schlüssel>`. Der Dienst erzeugt einen Schlüssel unter `data/zugriffsschluessel.txt`, falls keiner durch `GATEWAY_TOKEN` vorgegeben wurde.

Der eingebaute Server stellt HTTP bereit. HTTPS benötigt eine davor eingerichtete Absicherung. Docker ist eine optionale Verpackung desselben Dienstes und keine Voraussetzung für die App.

## Schnittstelle zur App

| Methode und Pfad | Inhalt |
| --- | --- |
| `GET /api/snapshot` | Zeitstempel, Leistungen, Akku-SoC, PV-Quellen, Gerätestatus und Steuerfreigabe |
| `GET /api/history` | Verlauf des laufenden lokalen Tages, in Minuten verdichtet |
| `POST /api/control` | Übernahme eines Wallbox-Ladeplans bei aktivierter Schreibfreigabe |

Zeitstempel werden als ISO-8601-Werte übertragen. Fehlende Messwerte sind `null` und werden in der App als nicht verfügbar dargestellt. Die verfügbare PV-Gesamtsumme setzt aktuelle Werte aller konfigurierten Quellen voraus.

Ein Ladeplan enthält `mode`, `targetSOC`, `manualCarSOC`, `carCapacityKWh`, `chargingEfficiency`, `batteryReserve`, `maxChargingKW`, `departure` und `allowGridCharging`. Zulässige Modi sind `smart`, `solar`, `departure`, `immediate` und `paused`.

Die zusätzliche Freigabe `ENABLE_CHARGER_CONTROL=true` sowie gültige Strom-, Phasen- und Netzbezugsgrenzen sind Voraussetzung für schreibende Wallboxbefehle. Das Abschalten des Demomodus in der App allein aktiviert keine Steuerung.

## Messgrenzen und Vorzeichen

- `gridKW > 0`: Netzbezug; `gridKW < 0`: Einspeisung.
- `batteryKW > 0`: Hausakku lädt; `batteryKW < 0`: Hausakku entlädt.
- `carKW`: Leistungsaufnahme an der Wallbox, keine direkt im Fahrzeug gespeicherte Leistung.
- `houseKW`: Hausverbrauch ohne Wallbox, abhängig von der konfigurierten Messanordnung.

Die Quellenpfade stehen in `config.json`. Die Vorlage enthält Systempfade für ein dreiphasiges Victron-System; die realen Geräteinstanzen und verfügbaren Phasen sind anlagenspezifisch. Eine Summe von AC- und DC-Erzeugung ist ohne Verlustmodell keine geschlossene Bilanz. Deshalb werden aktuell keine verbindlichen Eigenverbrauchs- oder Autarkiequoten berechnet.

## Datenhaltung

Die SQLite-Datenbank enthält `samples` und `events`. Bei vorhandener Netzmessung wird in der Regel alle 30 Sekunden eine Momentaufnahme gespeichert. Messdaten werden bis zu 366 Tage aufbewahrt; die App fragt derzeit nur den laufenden Tag ab. Energie- und Kostenwerte entstehen durch Integration der vorhandenen Leistungsintervalle. Lücken über 30 Minuten werden ausgelassen.

Aktive Ladepläne liegen im Arbeitsspeicher. Nach Neustart des Dienstes startet keine alte Regelung automatisch weiter. Ein neues Anstecken oder eine zurückgesetzte Wallbox-Energiezählung beendet den bisherigen Plan. Der Nutzer sendet anschließend bei Bedarf einen neuen Plan.

## Grenzen der aktuellen Regelung

Die Zentrale verändert an der Wallbox Ladefreigabe und Stromvorgabe, aber keine Phasenumschaltung. Sie berücksichtigt gemessenen Überschuss, Abfahrtszeit, Akkuentladung und eine Grenze für den Gesamt-Netzbezug. Die Anschlussphasen werden noch nicht einzeln dynamisch überwacht.

Die tatsächliche Hausakku-Untergrenze bleibt eine Einstellung des Victron-ESS. Die Wallboxsteuerung allein kann nicht erzwingen, dass ein Ladestrom aus dem Netz statt aus dem Hausakku kommt. Eine gemeinsame ESS-Optimierung ist ein nachfolgender Ausbau.

Bei geordnetem Beenden versucht die Zentrale eine von ihr gesteuerte Ladung zu pausieren. Bei Prozessabsturz, Stromausfall oder nicht erreichbarer Wallbox kann der letzte Befehl wirksam bleiben. Ein geräteseitiger Watchdog mit definierter Rückfallstrategie muss vor einem unbeaufsichtigten Regelbetrieb passend zur konkreten Wallbox-Firmware ergänzt werden.
