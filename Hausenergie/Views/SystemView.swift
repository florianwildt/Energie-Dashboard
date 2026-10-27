import SwiftUI

struct SystemView: View {
    @Environment(EnergyStore.self) private var store

    var body: some View {
        @Bindable var store = store
        PageLayout {
            SectionIntro(eyebrow: "Alles verbunden", title: "Dein Energiesystem.", subtitle: "Victron, Hausakku und Auto an einem Ort.")
            EnergyCard("Die Verbindung") {
                HStack {
                    Image(systemName: store.settings.demoMode ? "sparkles" : "network").font(.title).foregroundStyle(Theme.mint)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.settings.demoMode ? "Demoumgebung" : "Lokale Energiezentrale").font(.headline)
                        Text(store.settings.demoMode ? "Alle Werte sind simuliert." : store.settings.gatewayURL.isEmpty ? "Noch nicht eingerichtet" : store.settings.gatewayURL)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                InfoRow(title: "Betrieb", value: store.settings.demoMode ? "Simulation" : store.snapshot.controlEnabled ? "Wallboxsteuerung freigegeben" : "Nur lesen")
                Text("Die App verbindet sich mit einer Energiezentrale im Haus. Diese liest das Cerbo GX und die Wallbox aus und führt freigegebene Ladepläne unabhängig vom iPhone aus.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            EnergyCard("Deine Geräte") {
                if store.snapshot.devices.isEmpty {
                    Text("Geräte erscheinen nach der Verbindung mit deiner Energiezentrale.").foregroundStyle(.secondary)
                }
                ForEach(store.snapshot.devices) { device in
                    HStack(spacing: 14) {
                        Image(systemName: device.symbol).font(.title3).foregroundStyle(Theme.mint)
                            .frame(width: 42, height: 42).background(Theme.mint.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name).font(.subheadline.weight(.medium))
                            Text(device.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: device.online ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(device.online ? Theme.mint : Theme.solar)
                            .accessibilityLabel(device.online ? "Verbunden" : "Keine aktuellen Daten")
                    }
                    if device.id != store.snapshot.devices.last?.id { Divider() }
                }
            }
            EnergyCard("Deine PV-Anlagenteile") {
                if store.snapshot.solarSources.isEmpty { Text("Noch keine Quellen zugeordnet.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(store.snapshot.solarSources) { source in
                    InfoRow(title: source.name, value: EnergyFormat.power(source.powerKW), color: Theme.solar)
                }
                Text("Quellen werden an der Energiezentrale eindeutig zugeordnet. Summen und Einzelzähler dürfen nicht doppelt in die Bilanz eingehen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            EnergyCard("Dein Hausakku") {
                InfoRow(title: "Ladestand", value: EnergyFormat.percent(store.snapshot.batterySOC))
                InfoRow(title: "Temperatur", value: store.snapshot.batteryTemperature.map { "\(EnergyFormat.number($0)) °C" } ?? "Nicht verfügbar")
                HStack { Text("Gewünschte Reserve"); Spacer(); Text(EnergyFormat.percent(store.settings.batteryReserve)).foregroundStyle(Theme.mint).fontWeight(.semibold) }
                Slider(value: $store.settings.batteryReserve, in: 10...90, step: 5).accessibilityLabel("Hausakku-Reserve")
                Text("Die Reserve wird beim nächsten Senden des Ladeplans übernommen. Die App verändert keine Batrium-Schutzgrenzen und schreibt in dieser Version keine Victron-ESS-Sollwerte.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
