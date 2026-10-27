#!/usr/bin/env python3
"""Local Hausenergie gateway. Python 3.11+, optional paho-mqtt for Cerbo GX.

Only the go-e HTTP API can receive commands. Victron MQTT is read-only apart
from R/.../keepalive. No ESS or BMS settings are written.
"""
from __future__ import annotations

import argparse
import hmac
import json
import logging
import math
import os
from pathlib import Path
import secrets
import signal
import sqlite3
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent
LOG = logging.getLogger("hausenergie")


def utcnow():
    return datetime.now(timezone.utc)


def iso(value=None):
    return (value or utcnow()).astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def numeric(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def json_http(url, timeout=4):
    request = Request(url, headers={"Accept": "application/json", "User-Agent": "Hausenergie/1.0"})
    with urlopen(request, timeout=timeout) as response:
        result = json.loads(response.read(262144))
    if not isinstance(result, dict):
        raise ValueError("Ungültige Geräteantwort")
    return result


class Victron:
    def __init__(self, config):
        self.config = config
        self.values = {}
        self.lock = threading.RLock()
        self.connected = False
        self.client = None
        mqtt_config = config["mqtt"]
        if not mqtt_config.get("host") or not mqtt_config.get("portalID"):
            LOG.info("Cerbo GX noch nicht konfiguriert; Messwerte bleiben leer.")
            return
        try:
            import paho.mqtt.client as mqtt
        except ImportError:
            raise SystemExit("Für die Cerbo-Anbindung zuerst requirements.txt installieren.")
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="hausenergie-" + secrets.token_hex(4))
        if os.environ.get("MQTT_USERNAME"):
            self.client.username_pw_set(os.environ["MQTT_USERNAME"], os.environ.get("MQTT_PASSWORD"))
        if mqtt_config.get("tls", False):
            self.client.tls_set(ca_certs=mqtt_config.get("caFile") or None)
        self.client.on_connect = self.on_connect
        self.client.on_disconnect = self.on_disconnect
        self.client.on_message = self.on_message
        self.client.reconnect_delay_set(min_delay=1, max_delay=30)
        self.client.connect_async(mqtt_config["host"], int(mqtt_config.get("port", 1883)), keepalive=30)
        self.client.loop_start()

    def on_connect(self, client, userdata, flags, reason_code, properties):
        self.connected = reason_code == 0
        if self.connected:
            portal = self.config["mqtt"]["portalID"]
            client.subscribe(f"N/{portal}/#", qos=0)
            self.refresh()

    def on_disconnect(self, client, userdata, flags, reason_code, properties):
        self.connected = False

    def on_message(self, client, userdata, message):
        prefix = f"N/{self.config['mqtt']['portalID']}/"
        if not message.topic.startswith(prefix):
            return
        key = message.topic[len(prefix):]
        try:
            value = json.loads(message.payload).get("value") if message.payload else None
        except (ValueError, AttributeError):
            value = None
        with self.lock:
            self.values[key] = (value, time.monotonic())

    def refresh(self):
        if self.client and self.connected:
            self.client.publish(f"R/{self.config['mqtt']['portalID']}/keepalive", payload="")

    def sensor(self, specification):
        if not self.connected or not specification:
            return None
        paths = specification.get("paths", [])
        if not paths:
            return None
        with self.lock:
            samples = [self.values.get(path) for path in paths]
        if any(sample is None or time.monotonic() - sample[1] > 30 or not numeric(sample[0]) for sample in samples):
            return None
        return sum(sample[0] for sample in samples) * specification.get("scale", 1)

    def stop(self):
        if self.client:
            self.client.disconnect()
            self.client.loop_stop()


class GoE:
    def __init__(self, config):
        self.config = config
        self.status = {}
        self.updated = None
        self.error = None
        self.last_command = None
        self.last_switch = 0.0
        self.lock = threading.RLock()
        address = config.get("url", "")
        if address:
            parts = urlsplit(address)
            if parts.scheme not in ("http", "https") or not parts.hostname or parts.query or parts.fragment or parts.username:
                raise ValueError("go-e-URL ist ungültig")

    def poll(self):
        if not self.config.get("url"):
            return
        try:
            keys = "nrg,car,err,wh,amp,frc,pnp,ama,alw"
            result = json_http(self.config["url"].rstrip("/") + "/api/status?" + urlencode({"filter": keys}))
            if "car" not in result or not isinstance(result.get("nrg"), list) or len(result["nrg"]) < 12:
                raise ValueError("go-e HTTP API v2 liefert keine vollständigen Messwerte")
            with self.lock:
                self.status = result
                self.updated = utcnow()
                self.error = None
        except (URLError, ValueError, TimeoutError, OSError):
            self.error = "Die Wallbox liefert keine aktuellen Daten."

    @property
    def fresh(self):
        return self.updated is not None and (utcnow() - self.updated).total_seconds() <= 15 and self.error is None

    @property
    def power(self):
        if not self.fresh:
            return None
        values = self.status.get("nrg", [])
        return max(0, values[11]) / 1000 if len(values) > 11 and numeric(values[11]) else None

    @property
    def connected(self):
        return self.fresh and self.status.get("car") in (2, 3, 4)

    @property
    def energy_wh(self):
        value = self.status.get("wh")
        return value if self.fresh and numeric(value) else None

    def command(self, amps, force=False):
        """No phase switching. Device-side current caps remain untouched."""
        amps = max(0, min(int(amps), int(self.config["maxCurrentA"])))
        amps = amps if amps >= 6 else 0
        requested = (amps, 2 if amps else 1)
        if not force and requested == self.last_command:
            return
        previous_on = bool(self.last_command and self.last_command[0])
        # A stop can always happen immediately. Restart has a minimum pause.
        if amps and not previous_on and time.monotonic() - self.last_switch < 60 and not force:
            return
        query = {"frc": requested[1]}
        if amps:
            query["amp"] = amps
        response = json_http(self.config["url"].rstrip("/") + "/api/set?" + urlencode(query))
        if any(response.get(key) is not True for key in query):
            raise ValueError("Die Wallbox hat den Steuerbefehl nicht vollständig bestätigt.")
        if previous_on != bool(amps):
            self.last_switch = time.monotonic()
        self.last_command = requested


class Gateway:
    def __init__(self, config, data_dir):
        self.config = config
        self.lock = threading.RLock()
        self.stopping = threading.Event()
        self.victron = Victron(config)
        self.charger = GoE(config["charger"])
        self.plan = None
        self.control_message = "Noch kein Ladeplan aktiv. Es werden keine Geräteeinstellungen verändert."
        self.manual_soc = None
        self.last_saved = 0.0
        data_dir.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(data_dir / "energy.sqlite3", check_same_thread=False)
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("CREATE TABLE IF NOT EXISTS samples (timestamp TEXT PRIMARY KEY, payload TEXT NOT NULL)")
        self.db.execute("CREATE TABLE IF NOT EXISTS events (timestamp TEXT NOT NULL, message TEXT NOT NULL)")
        self.db.commit()

    @property
    def controls_enabled(self):
        charger = self.config["charger"]
        return (os.environ.get("ENABLE_CHARGER_CONTROL") == "true"
                and bool(charger.get("url")) and charger.get("phases") in (1, 3)
                and isinstance(charger.get("maxCurrentA"), int) and 6 <= charger["maxCurrentA"] <= 32
                and numeric(charger.get("maxGridImportKW")) and charger["maxGridImportKW"] > 0)

    def snapshot(self):
        sensors = self.config.get("sensors", {})
        get = lambda key: self.victron.sensor(sensors.get(key))
        sources = [{"id": source["id"], "name": source["name"], "powerKW": self.victron.sensor(source)}
                   for source in self.config.get("solarSources", [])]
        solar_values = [source["powerKW"] for source in sources]
        solar = sum(solar_values) if solar_values and all(value is not None for value in solar_values) else None
        total_house = get("houseTotalKW")
        car = self.charger.power
        house = total_house
        if self.config.get("wallboxIncludedInConsumption", True):
            house = max(0, total_house - car) if total_house is not None and car is not None else None
        grid, battery, soc = get("gridKW"), get("batteryKW"), get("batterySOC")
        devices = [
            {"id": "gx", "name": "Cerbo GX", "subtitle": "Venus OS · MQTT", "online": self.victron.connected and grid is not None, "symbol": "cpu"},
            {"id": "multis", "name": "MultiPlus-Verbund", "subtitle": "Systemmesswerte über Cerbo GX", "online": total_house is not None, "symbol": "bolt.horizontal.circle"},
            {"id": "battery", "name": "Hausakku / Batrium", "subtitle": "Batteriedaten über Cerbo GX", "online": soc is not None, "symbol": "battery.75percent"},
            {"id": "goe", "name": "go-e Charger CORE", "subtitle": "Lokale HTTP API", "online": self.charger.fresh, "symbol": "ev.charger"},
        ]
        message = self.control_message
        if grid is None:
            message = "Netzmessung fehlt oder ist veraltet. Prüfe die Zuordnung am Cerbo GX."
        elif self.charger.error:
            message = self.charger.error
        return {"timestamp": iso() if grid is not None else "1970-01-01T00:00:00Z",
                "solarKW": solar, "houseKW": house, "batteryKW": battery, "gridKW": grid,
                "carKW": car, "batterySOC": soc, "carSOC": None,
                "carConnected": self.charger.connected, "batteryTemperature": get("batteryTemperature"),
                "solarSources": sources, "devices": devices, "message": message, "isDemo": False,
                "carSOCSource": "Kein Fahrzeugzugriff · manuelle Planung", "chargerTimestamp": iso(self.charger.updated) if self.charger.updated else None,
                "controlEnabled": self.controls_enabled}

    def history(self):
        # Aggregate into minute buckets and preserve NULL for missing sensor data.
        local_day = datetime.now().astimezone().replace(hour=0, minute=0, second=0, microsecond=0)
        with self.lock:
            rows = self.db.execute("SELECT payload FROM samples WHERE timestamp >= ? ORDER BY timestamp", (iso(local_day),)).fetchall()
        buckets = {}
        for row in rows:
            sample = json.loads(row[0])
            minute = sample["timestamp"][:16]
            buckets.setdefault(minute, []).append(sample)
        result = []
        for minute, samples in buckets.items():
            point = {"timestamp": minute + ":00Z"}
            for key in ("solarKW", "houseKW", "carKW", "gridKW"):
                valid = [sample[key] for sample in samples if numeric(sample.get(key))]
                point[key] = sum(valid) / len(valid) if len(valid) == len(samples) else None
            result.append(point)
        return result

    def event(self, message):
        with self.lock:
            self.db.execute("INSERT INTO events VALUES (?, ?)", (iso(), message))
            self.db.commit()
        LOG.info(message)

    def accept_plan(self, body):
        if not self.controls_enabled:
            raise PermissionError("Die Wallboxsteuerung ist an der Energiezentrale nicht freigegeben.")
        if body.get("mode") not in ("smart", "solar", "departure", "immediate", "paused"):
            raise ValueError("Unbekannter Lademodus")
        ranges = {"targetSOC": (20, 100), "manualCarSOC": (0, 100), "carCapacityKWh": (10, 150),
                  "chargingEfficiency": (0.75, 0.98), "batteryReserve": (10, 90), "maxChargingKW": (1.4, 22)}
        for key, (minimum, maximum) in ranges.items():
            if not numeric(body.get(key)) or not minimum <= body[key] <= maximum:
                raise ValueError(f"Ungültiger Planparameter: {key}")
        if not isinstance(body.get("allowGridCharging"), bool):
            raise ValueError("Netzfreigabe fehlt")
        try:
            departure = datetime.fromisoformat(body["departure"].replace("Z", "+00:00"))
            until = (departure - utcnow()).total_seconds()
        except (ValueError, KeyError, TypeError):
            raise ValueError("Ungültige Abfahrtszeit")
        if not 0 < until <= 7 * 86400:
            raise ValueError("Die Abfahrt muss innerhalb der nächsten sieben Tage liegen.")
        if not self.charger.fresh or not self.charger.connected or self.charger.energy_wh is None:
            raise ValueError("Es fehlen aktuelle Wallboxdaten oder das Fahrzeug ist nicht verbunden.")
        with self.lock:
            body = dict(body)
            body["baselineWh"] = self.charger.energy_wh
            body["lastWh"] = body["baselineWh"]
            body["requiredWh"] = max(0, body["targetSOC"] - body["manualCarSOC"]) / 100 * body["carCapacityKWh"] * 1000 / body["chargingEfficiency"]
            body["departureDate"] = departure
            # Start a new plan from a known, acknowledged stopped state.
            self.charger.command(0, force=True)
            self.plan = body
            self.manual_soc = body["manualCarSOC"]
            self.control_message = "Ladeplan übernommen. Die lokale Regelung berücksichtigt Überschuss, Reserve und Abfahrtszeit."
            self.event(f"Ladeplan übernommen: {body['mode']}")

    def regulate(self, snapshot):
        with self.lock:
            if not self.controls_enabled or self.plan is None:
                return
            plan = self.plan
            charger = self.charger
            if not charger.fresh:
                self.control_message = "Wallbox nicht erreichbar. Ladeplan angehalten; bestehender Gerätebefehl kann weiter gelten."
                return
            wh = charger.energy_wh
            if not charger.connected or wh is None or wh + 1 < plan["lastWh"]:
                charger.command(0, force=True)
                self.plan = None
                self.control_message = "Ladesitzung beendet oder geändert. Für ein neues Anstecken bitte einen neuen Ladeplan senden."
                self.event("Ladeplan wegen geänderter Ladesitzung beendet")
                return
            plan["lastWh"] = wh
            remaining = max(0, plan["requiredWh"] - max(0, wh - plan["baselineWh"]))
            if utcnow() >= plan["departureDate"] or remaining == 0 or plan["mode"] == "paused":
                charger.command(0)
                self.control_message = "Laden pausiert." if plan["mode"] == "paused" else "Ladeplan beendet: Energieziel oder Abfahrtszeit erreicht."
                if plan["mode"] != "paused":
                    self.plan = None
                return
            grid, soc, battery = (snapshot[key] for key in ("gridKW", "batterySOC", "batteryKW"))
            if any(value is None for value in (grid, soc, battery)) or charger.status.get("err") != 0:
                charger.command(0)
                self.control_message = "Laden angehalten: Messwerte fehlen oder die Wallbox meldet einen Fehler."
                return
            phases = self.config["charger"]["phases"]
            observed = charger.status.get("pnp")
            if observed in (1, 3) and observed != phases:
                charger.command(0)
                self.control_message = "Laden angehalten: Phasenzahl passt nicht zur Konfiguration."
                return
            cap = min(plan["maxChargingKW"], self.config["charger"]["maxCurrentA"] * 230 * phases / 1000)
            max_device_a = charger.status.get("ama")
            if numeric(max_device_a):
                cap = min(cap, max_device_a * 230 * phases / 1000)
            car_power = snapshot["carKW"]
            if car_power is None:
                charger.command(0)
                return
            # Subtract battery discharge so it is not mistaken for solar surplus.
            surplus = max(0, car_power - grid + min(0, battery) - 0.15)
            remaining_hours = max(0, (plan["departureDate"] - utcnow()).total_seconds() / 3600 - 0.25)
            urgent = remaining / 1000 >= remaining_hours * cap
            use_grid = plan["allowGridCharging"] and (plan["mode"] == "immediate" or (plan["mode"] in ("smart", "departure") and urgent))
            desired = cap if use_grid else min(cap, surplus)
            # Conservative wallbox-side reserve protection; ESS retains its own policy.
            if soc <= plan["batteryReserve"] and battery < -0.10:
                desired = max(0, car_power + battery - 0.15)
                self.control_message = "Wallbox reduziert: Der Hausakku liegt an der Reserve und entlädt."
            else:
                self.control_message = "Netzergänzung für dein Ladeziel aktiv." if use_grid else "Wallbox folgt dem PV-Überschuss."
            headroom = max(0, self.config["charger"]["maxGridImportKW"] - grid + car_power - 0.25)
            desired = min(desired, headroom, cap)
            amps = math.floor(desired * 1000 / (230 * phases))
            charger.command(amps)

    def loop(self):
        counter = 0
        while not self.stopping.is_set():
            started = time.monotonic()
            if counter % 4 == 0:
                self.victron.refresh()
            self.charger.poll()
            snapshot = self.snapshot()
            try:
                self.regulate(snapshot)
            except (ValueError, URLError, TimeoutError, OSError):
                self.control_message = "Wallboxbefehl nicht bestätigt. Regelung wartet auf eine erfolgreiche Verbindung."
                LOG.warning("Wallboxbefehl nicht bestätigt")
                try:
                    self.charger.command(0, force=True)
                except (ValueError, URLError, TimeoutError, OSError):
                    pass
            if time.monotonic() - self.last_saved >= 30 and snapshot["gridKW"] is not None:
                with self.lock:
                    self.db.execute("INSERT OR REPLACE INTO samples VALUES (?, ?)", (iso(), json.dumps(snapshot, allow_nan=False)))
                    # Keep one year; app requests only the current day.
                    cutoff = datetime.fromtimestamp(time.time() - 366 * 86400, timezone.utc)
                    self.db.execute("DELETE FROM samples WHERE timestamp < ?", (iso(cutoff),))
                    self.db.commit()
                self.last_saved = time.monotonic()
            counter += 1
            self.stopping.wait(max(0.1, 5 - (time.monotonic() - started)))

    def close(self):
        self.stopping.set()
        if self.controls_enabled and self.plan:
            try:
                self.charger.command(0, force=True)
            except (ValueError, URLError, TimeoutError, OSError):
                LOG.warning("Wallbox beim Beenden nicht erreichbar")
        self.victron.stop()


class Handler(BaseHTTPRequestHandler):
    server_version = "Hausenergie/1.0"

    def log_message(self, format, *args):
        # Avoid logging request paths, credentials or submitted settings.
        return

    def reply(self, code, payload):
        data = json.dumps(payload, ensure_ascii=False, allow_nan=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def authorized(self):
        self.connection.settimeout(10)
        expected = "Bearer " + self.server.access_token
        provided = self.headers.get("Authorization", "")
        if not hmac.compare_digest(provided.encode(), expected.encode()):
            self.reply(401, {"detail": "Der Zugriffsschlüssel fehlt oder ist ungültig."})
            return False
        return True

    def do_GET(self):
        if not self.authorized():
            return
        path = urlsplit(self.path).path
        if path == "/api/snapshot":
            self.reply(200, self.server.gateway.snapshot())
        elif path == "/api/history":
            self.reply(200, self.server.gateway.history())
        else:
            self.reply(404, {"detail": "Unbekannter Endpunkt"})

    def do_POST(self):
        if not self.authorized():
            return
        if urlsplit(self.path).path != "/api/control":
            self.reply(404, {"detail": "Unbekannter Endpunkt"})
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if size <= 0 or size > 16384:
                raise ValueError("Ungültige Nachrichtengröße")
            body = json.loads(self.rfile.read(size))
            if not isinstance(body, dict):
                raise ValueError("Ein Ladeplan wird als Objekt erwartet")
            self.server.gateway.accept_plan(body)
            self.reply(200, {"message": "Ladeplan übernommen. Die Zentrale regelt lokal weiter."})
        except PermissionError as error:
            self.reply(403, {"detail": str(error)})
        except (ValueError, KeyError, TypeError) as error:
            self.reply(400, {"detail": str(error)})
        except (URLError, TimeoutError, OSError):
            self.reply(502, {"detail": "Die Wallbox hat den Befehl nicht bestätigt. Der Ladeplan wurde nicht aktiviert."})


def main():
    parser = argparse.ArgumentParser(description="Hausenergie: lokale Energiezentrale")
    parser.add_argument("--config", type=Path, default=ROOT / "config.json")
    parser.add_argument("--data", type=Path, default=ROOT / "data")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    config = json.loads(args.config.read_text())
    args.data.mkdir(parents=True, exist_ok=True)
    token_file = args.data / "zugriffsschluessel.txt"
    token = os.environ.get("GATEWAY_TOKEN", "").strip()
    if not token:
        if not token_file.exists():
            fd = os.open(token_file, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
            with os.fdopen(fd, "w") as file:
                file.write(secrets.token_urlsafe(32))
        token = token_file.read_text().strip()
    if len(token) < 24:
        raise SystemExit("Der Zugriffsschlüssel muss mindestens 24 Zeichen lang sein.")
    gateway = Gateway(config, args.data)
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    server.daemon_threads = True
    server.gateway = gateway
    server.access_token = token
    worker = threading.Thread(target=gateway.loop, daemon=True, name="energy-loop")
    worker.start()
    def stop(signum, frame):
        threading.Thread(target=server.shutdown, daemon=True).start()
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    LOG.info("Energiezentrale bereit auf %s:%s", args.host, args.port)
    LOG.info("Zugriffsschlüssel: Umgebungsvariable GATEWAY_TOKEN oder Datei %s", token_file)
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        gateway.stopping.set()
        worker.join(timeout=10)
        gateway.close()
        server.server_close()


if __name__ == "__main__":
    main()
