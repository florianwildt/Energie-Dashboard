import SwiftUI

struct OverviewView: View {
    @Environment(EnergyStore.self) private var store
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        let _ = PerformanceLog.shared.count("view.overview")
        PageLayout {
            SectionIntro(eyebrow: "Dein Zuhause im Gleichgewicht", title: "Energie im Blick.",
                         subtitle: store.settings.demoMode ? "Ein sonniger Beispieltag für dein Energiesystem." : "Deine Energieflüsse, direkt aus dem eigenen Haus.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 14) {
                MetricTile(title: "PV-Leistung", value: EnergyFormat.power(store.snapshot.solarKW), subtitle: "Gesamte Erzeugung", symbol: "sun.max", color: Theme.solar)
                MetricTile(title: "Hausakku", value: EnergyFormat.percent(store.snapshot.batterySOC), subtitle: "Reserve: \(EnergyFormat.percent(store.settings.batteryReserve))", symbol: "battery.75percent", color: Theme.mint)
                MetricTile(title: "Audi A6 e-tron", value: EnergyFormat.percent(store.snapshot.carSOC), subtitle: store.snapshot.carSOCSource, symbol: "car.side", color: Theme.blue)
                MetricTile(title: (store.snapshot.gridKW ?? 0) < 0 ? "Einspeisung" : "Netzbezug", value: EnergyFormat.power(store.snapshot.gridKW), subtitle: "Am Netzanschluss", symbol: "transmission.tower", color: Theme.violet)
            }
            if availableWidth >= 950 {
                HStack(alignment: .top, spacing: 20) {
                    flowCard.frame(maxWidth: .infinity)
                    VStack(spacing: 20) { insightCard; carCard }.frame(maxWidth: 350)
                }
            } else {
                flowCard
                insightCard
                carCard
            }
            EnergyCard("Dein Tagesverlauf", eyebrow: store.settings.demoMode ? "Beispieldaten · ganzer Tag" : "Heute · gemessene Werte") {
                EnergyChartView(points: store.chartPoints).equatable()
            }
            if !store.settings.demoMode, let last = store.lastSuccess {
                Text("Letzter Abruf \(last.formatted(date: .omitted, time: .standard)) · \(store.stale ? "Messwerte veraltet" : "Aktualisierung alle 5 Sekunden")")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
    }

    private var flowCard: some View {
        EnergyCard {
            HStack { Text("So fließt deine Energie").font(.headline); Spacer(); StatusPill(title: store.settings.demoMode ? "Demo" : store.stale ? "Veraltet" : "Live", color: store.stale ? Theme.solar : Theme.mint) }
            EnergyFlowView(snapshot: store.snapshot)
            Text("Hausverbrauch ohne Auto · Akku: + Laden / − Entladen")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }
    }

    private var insightCard: some View {
        EnergyCard(eyebrow: "Was gerade passiert") {
            Image(systemName: "sparkles").font(.title2).foregroundStyle(Theme.mint)
            Text(store.snapshot.message).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            Label(store.settings.demoMode ? "Simulation deiner Anlage" : "Lokale Energiezentrale", systemImage: "leaf")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var carCard: some View {
        EnergyCard(eyebrow: "Bereit für morgen") {
            HStack {
                Text("Audi A6 e-tron").font(.headline)
                Spacer()
                Image(systemName: "car.side.fill").foregroundStyle(Theme.blue)
            }
            ProgressView(value: min(max(store.snapshot.carSOC ?? store.settings.manualCarSOC, 0), 100), total: 100).tint(Theme.blue)
                .accessibilityLabel("Ladestand des Audi")
            InfoRow(title: "Dein Ladeziel", value: "\(EnergyFormat.percent(store.settings.targetSOC)) bis \(store.settings.departureLabel)")
            InfoRow(title: "Noch benötigt, inkl. Verlusten", value: "\(EnergyFormat.number(store.plan.requiredKWh)) kWh")
            Text(store.settings.mode.title).font(.caption.weight(.medium)).foregroundStyle(Theme.blue)
        }
    }
}
