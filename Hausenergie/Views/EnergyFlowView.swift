import SwiftUI

struct EnergyFlowView: View {
    var snapshot: EnergySnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let nodeWidth = min(94, w * 0.26)
            let centerSize = min(112, w * 0.36)
            let middle = CGPoint(x: w * 0.5, y: h * 0.50)
            let sun = CGPoint(x: w * 0.5, y: h * 0.12)
            let grid = CGPoint(x: w * 0.14, y: h * 0.50)
            let car = CGPoint(x: w * 0.86, y: h * 0.50)
            let battery = CGPoint(x: w * 0.5, y: h * 0.87)
            ZStack {
                Circle().fill(Theme.mint.opacity(0.035)).frame(width: min(w * 0.76, 290))
                    .position(middle)
                Circle().strokeBorder(Theme.mint.opacity(0.07), lineWidth: 1)
                    .frame(width: min(w * 0.76, 290)).position(middle)
                FlowConnectionsView(connections: [
                    FlowConnection(from: sun, to: middle, color: UIColor(Theme.solar), power: snapshot.solarKW),
                    FlowConnection(from: grid, to: middle, color: UIColor(Theme.violet), power: snapshot.gridKW),
                    FlowConnection(from: middle, to: car, color: UIColor(Theme.blue), power: snapshot.carKW),
                    FlowConnection(from: middle, to: battery, color: UIColor(Theme.mint), power: snapshot.batteryKW)
                ], animated: !reduceMotion && scenePhase == .active, colorScheme: colorScheme)
                .frame(width: w, height: h).accessibilityHidden(true)
                flowNode("Photovoltaik", symbol: "sun.max.fill", value: EnergyFormat.power(snapshot.solarKW),
                         detail: "Erzeugung", color: Theme.solar, width: nodeWidth).position(sun)
                flowNode("Netz", symbol: "transmission.tower", value: EnergyFormat.power(snapshot.gridKW),
                         detail: snapshot.gridKW.map { $0 < 0 ? "Einspeisung" : "Bezug" } ?? "Nicht verfügbar", color: Theme.violet, width: nodeWidth).position(grid)
                flowNode("Audi", symbol: "car.side.fill", value: EnergyFormat.power(snapshot.carKW),
                         detail: snapshot.carConnected ? "Verbunden" : "Nicht verbunden", color: Theme.blue, width: nodeWidth).position(car)
                flowNode("Hausakku", symbol: "battery.75percent", value: EnergyFormat.percent(snapshot.batterySOC),
                         detail: snapshot.batteryKW.map { "\($0 >= 0 ? "+" : "−")\(EnergyFormat.power($0))" } ?? "Nicht verfügbar", color: Theme.mint, width: nodeWidth).position(battery)
                VStack(spacing: 6) {
                    Image(systemName: "house.fill").font(.title2).foregroundStyle(Theme.mint)
                    Text(EnergyFormat.power(snapshot.houseKW)).font(.system(.headline, design: .rounded, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
                    Text("Haus").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(width: centerSize, height: centerSize)
                .background(Theme.card, in: Circle())
                .overlay { Circle().strokeBorder(Theme.mint.opacity(0.3), lineWidth: 1.5) }
                .position(middle)
            }
        }
        .frame(height: 340)
        .accessibilityElement(children: .combine)
    }

    private func flowNode(_ title: String, symbol: String, value: String, detail: String, color: Color, width: CGFloat) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.title3).foregroundStyle(color)
            Text(title).font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(.system(.subheadline, design: .rounded, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.vertical, 8).frame(width: width)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
