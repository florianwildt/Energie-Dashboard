import SwiftUI

struct AnalyticsView: View {
    @Environment(EnergyStore.self) private var store

    var body: some View {
        let _ = PerformanceLog.shared.count("view.analytics")
        let totals = store.totals
        let importCost = totals.imported * store.settings.importPrice
        let exportRevenue = totals.exported * store.settings.exportPrice
        PageLayout {
            SectionIntro(eyebrow: "Verstehen statt vermuten", title: "Was deine Energie bewegt.",
                         subtitle: store.settings.demoMode ? "Auswertung eines vollständigen Beispieltages." : "Heute · ausschließlich aufgezeichnete Messintervalle.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 14) {
                MetricTile(title: "PV-Ertrag", value: "\(EnergyFormat.number(totals.solar)) kWh", subtitle: "Aus Leistungsverlauf", symbol: "sun.max", color: Theme.solar)
                MetricTile(title: "Hausverbrauch", value: "\(EnergyFormat.number(totals.house)) kWh", subtitle: "Ohne Autoladung", symbol: "house", color: Theme.mint)
                MetricTile(title: "Autoladung", value: "\(EnergyFormat.number(totals.car)) kWh", subtitle: "An der Wallbox", symbol: "bolt.car", color: Theme.blue)
                MetricTile(title: "Stromsaldo", value: EnergyFormat.money(importCost - exportRevenue), subtitle: "Bezug minus Vergütung", symbol: "eurosign.circle", color: Theme.violet)
            }
            EnergyCard("Erzeugung und Verbrauch", eyebrow: store.settings.demoMode ? "Beispieltag" : "Heute") {
                EnergyChartView(points: store.chartPoints).equatable()
            }
            EnergyCard("Deine Strombilanz") {
                balanceRow(title: "Netzbezug", energy: totals.imported, money: importCost, color: Theme.violet)
                Divider()
                balanceRow(title: "Einspeisung", energy: totals.exported, money: -exportRevenue, color: Theme.mint)
                Divider()
                InfoRow(title: "Saldo", value: EnergyFormat.money(importCost - exportRevenue), color: Theme.mint)
                Text("Rechnerische Energiekosten mit deinen eingestellten Preisen. Grundgebühren sind nicht enthalten. Ein negativer Saldo bedeutet einen Überschuss aus Einspeiseerlösen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            EnergyCard("Transparente Daten") {
                InfoRow(title: "Erfasster Zeitraum", value: "\(EnergyFormat.number(totals.coverageHours)) Stunden")
                InfoRow(title: "Davon mit Netzwerten", value: "\(EnergyFormat.number(totals.gridHours)) Stunden")
                InfoRow(title: "Datenpunkte", value: "\(store.history.count)")
                Text("Die Werte werden aus dem Leistungsverlauf berechnet. Messlücken über 30 Minuten werden nicht aufgefüllt. Fehlende Messwerte zählen nicht als gemessener Nullverbrauch. Die Anzeige ersetzt keinen Abrechnungszähler.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func balanceRow(title: String, energy: Double, money: Double, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text("\(EnergyFormat.number(energy)) kWh").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(EnergyFormat.money(money)).font(.headline).monospacedDigit()
        }
    }
}
