# Hausenergie im eigenen Haus einrichten

Der Einstieg erfolgt mit echten Messwerten im Lesemodus. Die vorhandene Anlage behält dabei ihre bisherige Regelung. Anschließend werden die zusätzliche Wallboxregelung und ihr Ausfallverhalten eingerichtet.

## Benötigte Angaben

| Angabe | Wofür sie gebraucht wird |
| --- | --- |
| Rechner für die Zentrale | Dauerhaft laufender Dienst; bei einem NAS Hersteller und Modell nennen |
| IP-Adresse des Cerbo GX | Lokaler MQTT-Zugriff |
| GX-Portal-ID | Zuordnung der MQTT-Topics; kein VRM-Cloudlogin |
| Venus-OS-Version | Passende Diensteinstellungen und verfügbare Messwerte |
| IP-Adresse der go-e CORE | Lokale HTTP API v2 |
| go-e-Firmware und Phaseneinstellung | Verfügbare Schnittstellen und spätere Regelung |
| Victron-Geräteinstanzen | Eindeutige Zuordnung der beiden MPPT und der Zähler |
| Lage der Wallbox im Messaufbau | Richtige Trennung von Haus- und Autoverbrauch |

Die Adressen sollten im Heimnetz dauerhaft zugewiesen sein. iPhone, Energiezentrale und Geräte benötigen gegenseitige Erreichbarkeit; getrennte Gastnetze können diese verhindern. Zugangsschlüssel werden lokal hinterlegt.

## Rechner und Betriebsart festlegen

Die Zentrale kann zunächst auf dem Mac laufen. Für fortlaufende Aufzeichnung und Regelung muss der gewählte Rechner eingeschaltet und verfügbar bleiben. Ein vorhandener Server oder ein geeignetes NAS kann den Dienst später dauerhaft betreiben. Ob eine native Python-Installation oder Docker sinnvoll ist, richtet sich nach diesem Gerät. Docker ist optional.

Der Dienst wird außerhalb des Cerbo eingerichtet. Die App auf dem iPhone ist die Bedienoberfläche und muss nicht dauerhaft geöffnet bleiben.

## Schnittstellen und Konfiguration einrichten

Den lokalen MQTT-Zugriff am Cerbo und die lokale HTTP API v2 an der go-e aktivieren. Die genauen Einstellungen richten sich nach den vorhandenen Firmware-Versionen.

Die bestehende `Energiezentrale/config.json` ergänzen. Bei einem neuen Git-Checkout zuerst `config.example.json` nach `config.json` kopieren; die lokale Konfiguration wird nicht versioniert. Bereits eingetragene Anlagenwerte erhalten.

| Konfigurationsfeld | Eintrag |
| --- | --- |
| `mqtt.host` | Adresse des Cerbo GX |
| `mqtt.portalID` | Portal-ID dieses GX-Geräts |
| `mqtt.port` und `mqtt.tls` | Tatsächliche lokale MQTT-Verbindung |
| `charger.url` | Lokale Adresse der Wallbox einschließlich `http://` oder `https://` |
| `sensors` | Tatsächlich vorhandene System- oder Zählerpfade |
| `solarSources` | Jeweils die eindeutigen Leistungspfade der vier PV-Quellen |
| `wallboxIncludedInConsumption` | Ob der Victron-Verbrauch die Wallbox schon einschließt |

Die Beispielwerte für drei Phasen, 16 A und 11 kW Netzbezug sind keine festgestellten Anschlussgrenzen. Vor der Steuerfreigabe werden die tatsächlichen Werte eingetragen.

## Energiezentrale starten

Im Ordner `Energiezentrale` mit Python ab Version 3.11:

```sh
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
python3 gateway.py --host 0.0.0.0
```

Der Dienst startet ohne Wallbox-Schreibfreigabe. Beim ersten Start legt er seinen Zugriffsschlüssel unter `data/zugriffsschluessel.txt` an. Alternativ wird der Schlüssel über `GATEWAY_TOKEN` vorgegeben. Optionale MQTT-Anmeldedaten werden über `MQTT_USERNAME` und `MQTT_PASSWORD` gesetzt.

Der Aufruf betreibt den Dienst im geöffneten Terminal. Ein automatischer Start nach einem Neustart des Rechners wird erst passend zum ausgewählten Betriebssystem eingerichtet. Vorhandene Docker-Dateien stehen als Alternative bereit; ein Docker-Betrieb ist noch nicht für das Haus eingerichtet.

## App verbinden

In der App **Einstellungen** öffnen, den Demomodus ausschalten und die Adresse `http://<Adresse-des-Rechners>:8787` sowie den Zugriffsschlüssel eintragen. Unter **Verbindung herstellen** wird die lokale Verbindung aufgebaut. Bei der iOS-Abfrage den lokalen Netzwerkzugriff erlauben.

Der Server in der App ist die Energiezentrale, nicht direkt die IP-Adresse des Cerbo oder der Wallbox. Die App erhält darüber die Messwerte beider Geräte.

Anschließend nutzbare Fahrzeugkapazität, tatsächliche AC-Ladeleistung, Reserve, Preise und Abfahrtszeit in der App eintragen. Der Audi-Ladestand wird in dieser Version manuell vorgegeben.

## Wallboxregelung als nächste Ausbaustufe

Vor unbeaufsichtigtem Laden werden ein geräteseitiges Rückfallverhalten bei Verbindungsverlust und die Begrenzung je Netzanschlussphase ergänzt. Außerdem müssen die Victron-ESS-Reserve und die Wallboxautomatik zusammenpassen. Diese Schritte gehören zur Betriebsintegration und sind noch nicht abgeschlossen.

Die vorhandene Schreibfreigabe ist als `ENABLE_CHARGER_CONTROL=true` umgesetzt. Sie bleibt bis zur passenden Anlagenintegration deaktiviert. Eine ausdrückliche Übernahme des Ladeplans in der App ist zusätzlich erforderlich.

## Nutzung von außerhalb des Hauses

Für den ersten Betrieb bleibt die Verbindung im Heimnetz. Für Fernzugriff kann später ein VPN oder ein abgesicherter HTTPS-Zugang eingerichtet werden. Der Dienst konfiguriert keine Routerfreigaben automatisch.
