import SwiftUI
import Charts

struct PlanningView: View {
    @Environment(EnergyStore.self) private var store

    var body: some View {
        PageLayout {
            SectionIntro(eyebrow: "Vorausschauend nutzen", title: "Heute planen. Morgen los.", subtitle: "Ein klarer Plan für dein Auto und die Reserve im Haus.")
            EnergyCard {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DEIN NÄCHSTES ZIEL").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.secondary)
                        Text("\(EnergyFormat.percent(store.settings.targetSOC)) bis \(store.settings.departureLabel)")
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        Text(store.settings.departure.formatted(.dateTime.weekday(.wide).day().month(.wide))).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "sun.horizon").font(.largeTitle).foregroundStyle(Theme.solar)
                }
                Text(store.plan.explanation).font(.subheadline)
                StatusPill(title: store.plan.feasible ? "Zeitlich möglich · Energieangebot offen" : "Ziel benötigt Aufmerksamkeit", color: store.plan.feasible ? Theme.mint : Theme.solar)
            }
            EnergyCard("So wird Energie verteilt") {
                timelineRow(number: "01", title: "Dein Zuhause versorgen", detail: "Der laufende Hausverbrauch und die Gerätegrenzen haben Vorrang.", symbol: "house", color: Theme.mint)
                Divider()
                timelineRow(number: "02", title: "Reserve erhalten", detail: "Mindestens \(EnergyFormat.percent(store.settings.batteryReserve)) im Hausakku einplanen. BMS-Grenzwerte bleiben maßgeblich.", symbol: "battery.75percent", color: Theme.violet)
                Divider()
                timelineRow(number: "03", title: "Sonne für den Audi nutzen", detail: "Wallboxleistung am Überschuss ausrichten. Kurze Schwankungen werden geglättet.", symbol: "sun.max", color: Theme.solar)
                Divider()
                timelineRow(number: "04", title: "Abfahrtsziel berücksichtigen", detail: store.settings.allowGridCharging ? "Fehlende Energie mit Zeitpuffer aus dem Netz ergänzen, sofern du nicht Nur Sonne gewählt hast." : "Netzladen ist deaktiviert. Das Ladeziel hängt vom PV-Angebot ab.", symbol: "bolt.car", color: Theme.blue)
            }
            if store.settings.demoMode {
                EnergyCard("Ein möglicher Sonnentag", eyebrow: "Illustration · keine Wettervorhersage") {
                    EnergyChartView(points: EnergyHistory.demo.chartPoints).equatable()
                }
            }
            EnergyCard("Die Rahmenbedingungen") {
                InfoRow(title: "Maximale Ladeleistung", value: EnergyFormat.power(store.settings.maxChargingKW))
                InfoRow(title: "Angenommener Ladewirkungsgrad", value: EnergyFormat.percent(store.settings.chargingEfficiency * 100))
                InfoRow(title: "Netzpreis", value: "\(EnergyFormat.number(store.settings.importPrice * 100)) ct/kWh")
                InfoRow(title: "Einspeisevergütung", value: "\(EnergyFormat.number(store.settings.exportPrice * 100)) ct/kWh")
                InfoRow(title: "Bei vollständiger Netzladung", value: EnergyFormat.money(store.plan.requiredKWh * store.settings.importPrice))
                Text("Die erste Version plant nach Überschuss und Abfahrtszeit. Wetterprognosen, dynamische Tarife und unterschiedliche PV-Vergütungen sind für einen späteren Ausbau vorgesehen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func timelineRow(number: String, title: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.title3).foregroundStyle(color)
                .frame(width: 44, height: 44).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(number).font(.caption.monospaced()).foregroundStyle(.tertiary)
        }
    }
}
