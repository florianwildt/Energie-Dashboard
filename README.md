# Hausenergie

Native App für iPhone und iPad ab iOS/iPadOS 18. Die erste Ausbaustufe enthält ein Energiefluss-Dashboard, Wallbox-Ladepläne, Tagesverläufe, Kostenauswertung und eine lokale Energiezentrale für Victron und go-e.

## Aktueller Projektstand

Stand: 27. Oktober 2026. Die App steht bei **Version 1.0.1, Build 2**. Der letzte dokumentierte iOS-Build war erfolgreich. Die Oberfläche und die Schnittstellen sind implementiert; die konkrete Hausanlage ist noch nicht konfiguriert. In `Energiezentrale/config.json` sind Cerbo-Adresse, Portal-ID, Wallbox-Adresse und PV-Gerätepfade noch leer.

Der nächste Arbeitsschritt ist die Einrichtung des Live-Dashboards im Lesemodus. Dafür fehlen die Wahl des dauerhaft laufenden Rechners, die Geräteadressen und die tatsächliche Sensorzuordnung. Vor einem unbeaufsichtigten Ladebetrieb sind das geräteseitige Ausfallverhalten und die Überwachung der Anschlussphasen zu ergänzen. Die aktuelle Regelung ist noch keine gemeinsame wirtschaftliche Optimierung von Hausakku, Auto und Netz.

## Weiterführende Projektdokumentation

- [Projektstatus und nächste Arbeitsschritte](docs/PROJEKTSTATUS.md)
- [Architektur und Schnittstellen](docs/ARCHITEKTUR.md)
- [Inbetriebnahme im eigenen Haus](docs/INBETRIEBNAHME.md)
- [Übergabeprompt für einen anderen KI Agenten](WEITERARBEITEN-PROMPT.txt)

Der Übergabeprompt enthält die Nutzerregeln, den bisherigen Verlauf, die relevanten Dateien und die Grenzen der aktuellen Umsetzung. Bestehende App-Symbole und persönliche Xcode-Einstellungen sind bei der Weiterarbeit zu erhalten.

## Repository einrichten

Das Projekt liegt auf [GitHub unter florianwildt/Energie-Dashboard](https://github.com/florianwildt/Energie-Dashboard). Der Hauptbranch heißt `main`. Die Datei `Hausenergie.xcodeproj` liegt direkt in der Repository-Wurzel.

Nach einem neuen Checkout die Datei `Energiezentrale/config.example.json` nach `Energiezentrale/config.json` kopieren und die eigene Anlage darin konfigurieren. Diese lokale Konfiguration, `.env`, Laufzeitdaten und Build-Artefakte werden nicht versioniert. Eine bereits vorhandene lokale Konfiguration bleibt erhalten.

Die Arbeitsregeln für weitere KI-Agenten stehen in [AGENTS.md](AGENTS.md). Es werden keine UI-Tests ausgeführt.

## Version 1.0.1: Performance und Diagnose

Die Energiefluss-Animation bleibt erhalten. Sie läuft über vier Core-Animation-Ebenen statt über regelmäßige SwiftUI-Neuberechnungen. Ihre Strichphase liegt immer innerhalb eines 12-Punkte-Zyklus. Die bisherige Berechnung aus dem absoluten Datum führte zu einem Versatz von über 11 Milliarden Punkten. Das ist eine konkrete problematische Eingabe für die Grafik; ob sie allein die beobachtete Gerätesperre erklärt, ist ohne Geräteprofil noch nicht bestätigt.

Zusätzlich werden Demowerte nur bei Änderungen neu erzeugt, inaktive Tabs nicht aufgebaut, unveränderte Diagramme wiederverwendet und Tagesdaten nur einmal pro Minute separat geladen. Dekodierung, Datumsverarbeitung, Diagrammverdichtung und Summenberechnung erfolgen außerhalb des UI-Aktors. Die Diagramme zeigen maximal 360 ausgewählte Punkte mit erhaltenen Extremwerten; Energiesummen verwenden weiterhin alle Originalwerte. Das Speichern bei Eingaben wird um 400 ms gebündelt und erfolgt außerhalb der Bedienoberfläche.

Unter **Einstellungen → Diagnose** ist das lokale Performance-Protokoll abschaltbar und als JSON-Datei teilbar. Es enthält:

- `ui.stall`: Eine Probe auf der Hauptwarteschlange wurde mindestens 150 ms verzögert.
- `runtime.sample`: UI-Callbackrate, CPU-Zeit, Speicher-Spitzenwert, thermischer Zustand und Anzahl bestimmter View-Neuberechnungen im Abtastintervall.
- `mainProbePendingMS`: Eine UI-Probe wartet noch; wird auch während einer anhaltenden Blockade von einer Hintergrundwarteschlange aufgezeichnet.
- `gateway.request`, `gateway.decode`, `history.prepare`: Netzwerk-, Dekodierungs- und Aufbereitungsdauer.
- `flow.layers.update`, `settings.persist`, `keychain.persist`: Aktualisierungs- und Speicherzeiten.

Die UI-Callbackrate ist keine direkte Messung der GPU-Bildrate. Die UI-Probe erfolgt alle zwei Sekunden und ist keine lückenlose Erfassung kurzer Ruckler. Der Speicherwert ist der Spitzenwert seit Prozessstart. CPU-Prozente beziehen sich auf einen Prozessorkern und können bei paralleler Arbeit über 100 liegen.

Das Protokoll wird auf 1000 Einträge begrenzt und im App-Cache gespeichert. Bei einem erneuten App-Start bleiben bis zu 600 vorherige Einträge erhalten. Es enthält keine Energiemesswerte, Zugriffsschlüssel, Geräteadressen oder Fahrzeugkennungen. Dieselben Ereignisse stehen mit dem Subsystem `de.wildt.Hausenergie` und der Kategorie `Performance` in der Apple-Systemprotokollierung; Zeitintervalle sind als Signposts verfügbar.

## Die App öffnen

Die Datei `Hausenergie.xcodeproj` in Xcode öffnen. Das gemeinsame Schema heißt **Hausenergie**. Die App startet im **Demomodus**; hierfür werden weder eine Energiezentrale noch Gerätezugänge benötigt.

Für die Installation auf einem eigenen iPhone oder iPad in Xcode unter **Hausenergie → Signing & Capabilities → Team** das eigene Apple-Team auswählen. Die persönliche Signierung ist bewusst nicht im Projekt hinterlegt.

## Bereits umgesetzt

- Übersicht mit fünf Energie-Knoten: PV, Haus, Hausakku, Audi und Netz. Die Flussrichtung folgt dem Vorzeichen der Leistung.
- Separate Darstellung der beiden MPPT und der beiden PV-Zähler.
- Ladeziel, nächste Abfahrt, Hausakku-Reserve, Netzfreigabe und fünf Lademodi.
- Bedarfsberechnung mit nutzbarer Fahrzeugkapazität und angenommenem Ladewirkungsgrad.
- Tageskurven mit auswählbaren Zeitpunkten, berechneten Energiemengen und Kostensaldo.
- Geräteübersicht, Erreichbarkeit, veraltete Messwerte und fehlende Daten.
- Native iPad-Seitenleiste und platzabhängige Anordnung; Tab-Navigation auf dem iPhone.
- Helle und dunkle Darstellung, deutsche Zahlenformate, VoiceOver-Beschriftungen und reduzierte Animation bei entsprechender Systemeinstellung.
- Persistente Einstellungen und Speicherung des Gateway-Zugriffsschlüssels im iOS-Schlüsselbund.
- Lokaler Gateway-Dienst mit Victron-MQTT, go-e HTTP API v2, SQLite-Verlauf und optionaler Wallboxregelung.

## Was der Demomodus bedeutet

Alle Werte sind Beispieldaten. Der Tagesverlauf zeigt einen vollständigen simulierten Sonnentag und keine Wettervorhersage. Ladeziele und Lademodi sind bedienbar; Änderungen lösen keine Gerätebefehle aus. Kapazität, Preise und Ladeleistung in den Einstellungen sind editierbare Startannahmen.

## Echte Messwerte verbinden

Die App spricht mit dem mitgelieferten Dienst im Ordner `Energiezentrale`. Dieser läuft dauerhaft im Haus, zum Beispiel auf einem vorhandenen Rechner oder Server. Der Mac muss dafür eingeschaltet bleiben; für den späteren Dauerbetrieb kann der Dienst auf einen anderen Rechner umziehen.

1. Die vorhandene `Energiezentrale/config.json` ergänzen. Die Datei `config.example.json` dient als Vorlage; eine bereits eingerichtete Konfiguration nicht durch die Vorlage ersetzen.
2. Die IP-Adresse des Cerbo GX und seine VRM-Portal-ID unter `mqtt` eintragen. Die Portal-ID identifiziert das GX-Gerät; ein VRM-Cloudlogin ist für die lokale Verbindung nicht erforderlich. Den lokalen MQTT-Zugriff am GX aktivieren. MQTT-Zugangsdaten werden optional über `MQTT_USERNAME` und `MQTT_PASSWORD` als Umgebungsvariablen übergeben.
3. Die lokale Adresse der Wallbox unter `charger.url` eintragen und ihre lokale HTTP API v2 aktivieren.
4. Die Sensorpfade anhand der tatsächlichen Victron-Geräteinstanzen zuordnen. Die Systempfade im Beispiel sind eine Vorlage für ein dreiphasiges System. Die vier PV-Quellen haben absichtlich leere Pfade, damit keine Geräteinstanzen erfunden werden. Typische Pfade sind `solarcharger/<Instanz>/Yield/Power` oder die Phasenleistungen eines `pvinverter/<Instanz>`; maßgeblich sind die tatsächlich vorhandenen Topics.
5. Mit `wallboxIncludedInConsumption` festlegen, ob die Wallbox bereits im Victron-Gesamtverbrauch enthalten ist. Die App zeigt den Hausverbrauch ohne Auto.
6. Im Ordner `Energiezentrale` den Dienst starten:

```sh
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
python3 gateway.py --host 0.0.0.0
```

Der Dienst verwendet Python ab Version 3.11 und Port 8787. Der Zugriffsschlüssel wird beim ersten Start in `Energiezentrale/data/zugriffsschluessel.txt` angelegt. Die Datei hat auf Unix-Systemen nur Leserechte für den Besitzer. Alternativ kann ein eigener mindestens 24 Zeichen langer Schlüssel über die Umgebungsvariable `GATEWAY_TOKEN` vorgegeben werden.

In der App unter **Einstellungen** den Demomodus ausschalten, `http://<Adresse-des-Servers>:8787` und den Zugriffsschlüssel eintragen. Das lokale Netzwerk muss beim ersten Zugriff in iOS erlaubt werden. Der Mac und das iPhone benötigen gegenseitige Erreichbarkeit im Heimnetz.

Der HTTP-Dienst ist für das eigene Heimnetz oder einen VPN-Zugang ausgelegt. Für Verbindungen außerhalb dieses Netzes ist HTTPS vor dem Dienst einzurichten. Es werden keine Ports automatisch am Router freigegeben.

## Wallboxregelung

Der Dienst startet standardmäßig ohne Schreibfreigabe. Für eine bewusst eingerichtete Wallboxregelung zusätzlich `ENABLE_CHARGER_CONTROL=true` als Umgebungsvariable setzen. Die Parameter `phases`, `maxCurrentA` und `maxGridImportKW` müssen zur vorhandenen Installation passen. Anschließend wird ein Ladeplan in der App mit **Ladeplan an Energiezentrale senden** aktiviert.

Die erste Regelung nutzt aktuellen Überschuss und Abfahrtszeit. Sie reduziert die Wallbox bei fehlenden Messwerten, berücksichtigt Akkuentladung bei der Überschussberechnung und setzt Mindestpausen vor dem Neustart. Ladeenergie wird mit dem Wallboxzähler `wh` seit Übernahme des Plans verrechnet. Nach Abstecken, Zählerrücksetzung, Neustart des Dienstes oder Ende des Plans wird kein neuer Ladevorgang automatisch geplant. Ein neuer Plan muss ausdrücklich gesendet werden.

Die Regelung schaltet die Phasenzahl nicht um. Sie begrenzt Stromvorgaben und den gemessenen Gesamt-Netzbezug; eine dynamische Überwachung aller einzelnen Anschlussphasen ist noch nicht umgesetzt. Andere Wallbox-Automatiken dürfen den freigegebenen Plan nicht gleichzeitig übersteuern.

Die App schreibt keine Victron-ESS- oder Batrium-Schutzwerte. Die gewünschte Hausakku-Untergrenze muss daher auch in der bestehenden Victron-Regelung passend hinterlegt sein. Die Wallbox allein kann keine bestimmte Energiequelle erzwingen, wenn das ESS andere Vorgaben verfolgt. Die eingebaute Reserveberücksichtigung ersetzt diese Konfiguration nicht.

Bei einem geordneten Beenden versucht der Dienst, eine von ihm gesteuerte Ladung zu pausieren. Bei Prozessabsturz, Stromausfall oder Kommunikationsverlust kann ein bereits erteilter Wallboxbefehl weiterwirken. Eine geräteseitige Überwachung für den Verlust der Regelzentrale ist in dieser Ausbaustufe nicht integriert. Die bestehenden elektrischen Schutz- und Lastgrenzen bleiben erforderlich.

## Bilanz und Datenqualität

Positive Netzleistung bedeutet Bezug, negative Einspeisung. Positive Akkuleistung bedeutet Laden, negative Entladen. Bei fehlenden Werten liefert der Dienst `null`; die App zeigt einen Strich. Die PV-Gesamtsumme wird nur angezeigt, wenn alle konfigurierten Quellen aktuelle Werte liefern.

AC- und DC-Erzeugung liegen an unterschiedlichen Messgrenzen. Ihre einfache Erzeugungssumme enthält keine Umrechnung auf eine gemeinsame AC-Bilanz und ist deshalb keine verlustfreie Gesamtenergiebilanz. Die erste Version berechnet daraus bewusst keine Autarkie- oder Eigenverbrauchsquote und keine Herkunftsgarantie für einzelne Ladungen.

Messwerte werden alle 30 Sekunden aufgezeichnet und für die App in Minuten verdichtet. Die Datenbank hält bis zu ein Jahr vor; die Oberfläche zeigt aktuell den laufenden Tag. Energie wird durch Integration verfügbarer Leistungsintervalle berechnet. Größere Lücken werden ausgelassen. Kosten sind berechnete Werte mit festen eingestellten Preisen und ohne Grundgebühren.

## Noch nicht enthalten

Automatischer Audi-/myAudi-Zugriff, Wetterprognosen, dynamische Strompreise, getrennte Einspeisevergütungen, schreibende ESS-Optimierung, automatische Phasenumschaltung, V2H/V2G, Push-Meldungen und mehrtägige Auswertungsansichten sind spätere Ausbaustufen. Der aktuelle Fahrzeug-Ladestand muss manuell vorgegeben werden. Die Abfahrtsplanung ist eine Berechnung anhand dieser Eingabe, keine bestätigte Fahrzeug-SoC-Prognose.

## Projektaufbau

```text
Hausenergie.xcodeproj/       Xcode-Projekt und gemeinsames Schema
Hausenergie/
  Models/                   Messwerte, Einstellungen, Ladebedarf
  Services/                 Zustand, Gateway-Verbindung, Schlüsselbund
  Views/                    Native Oberflächen und Diagramme
  Assets.xcassets/          App-Symbol und Akzentfarbe
Configuration/Info.plist     Lokaler Netzwerkzugriff und App-Metadaten
Energiezentrale/             Python-Dienst und Docker-Variante
```

## Docker-Variante

Im Ordner `Energiezentrale` die Dateien `config.json` und `.env` aus den Vorlagen anlegen. In `.env` einen eigenen langen `GATEWAY_TOKEN` setzen. Danach kann der Dienst mit `docker compose up -d --build` dauerhaft laufen. Die Daten liegen in einem benannten Docker-Volume. Nach einem Neustart bleibt die Steuerung inaktiv, bis ein neuer Ladeplan gesendet wird.

## Schnittstellenquellen

- [Victron: MQTT-Schnittstelle von Venus OS](https://github.com/victronenergy/dbus-flashmq)
- [Victron: D-Bus-Pfade](https://github.com/victronenergy/venus/wiki/dbus)
- [go-e: lokale HTTP API v2](https://github.com/goecharger/go-eCharger-API-v2/blob/main/http-en.md)
- [go-e: API-Schlüssel](https://github.com/goecharger/go-eCharger-API-v2/blob/main/API_KEYS_FIRMWARE/apikeys-en.md)

Es wurden keine UI-Tests angelegt. Das Projekt enthält keine zusätzlichen Swift-Paketabhängigkeiten.
