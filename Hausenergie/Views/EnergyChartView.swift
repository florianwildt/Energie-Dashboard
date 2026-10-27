import SwiftUI
import Charts

struct EnergyChartView: View, Equatable {
    var points: [EnergyPoint]
    var showCar: Bool = true
    @State private var selectedDate: Date?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.points == rhs.points && lhs.showCar == rhs.showCar
    }

    private var selected: EnergyPoint? {
        guard let selectedDate else { return nil }
        guard !points.isEmpty else { return nil }
        var low = 0
        var high = points.count
        while low < high {
            let middle = (low + high) / 2
            if points[middle].timestamp < selectedDate { low = middle + 1 } else { high = middle }
        }
        let next = min(low, points.count - 1)
        let previous = max(0, next - 1)
        return abs(points[previous].timestamp.timeIntervalSince(selectedDate)) < abs(points[next].timestamp.timeIntervalSince(selectedDate)) ? points[previous] : points[next]
    }

    var body: some View {
        let _ = PerformanceLog.shared.count("view.chart")
        VStack(alignment: .leading, spacing: 16) {
            if points.isEmpty {
                ContentUnavailableView("Noch kein Verlauf", systemImage: "chart.xyaxis.line", description: Text("Neue Messwerte erscheinen nach der Verbindung mit deiner Energiezentrale."))
                    .frame(height: 220)
            } else {
                Chart {
                    ForEach(points) { point in
                        if let value = point.solarKW {
                            AreaMark(x: .value("Zeit", point.timestamp), y: .value("Leistung", value))
                                .foregroundStyle(LinearGradient(colors: [Theme.solar.opacity(0.20), Theme.solar.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.monotone)
                            LineMark(x: .value("Zeit", point.timestamp), y: .value("Leistung", value), series: .value("Quelle", "PV"))
                                .foregroundStyle(Theme.solar).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.monotone)
                        }
                        if let value = point.houseKW {
                            LineMark(x: .value("Zeit", point.timestamp), y: .value("Leistung", value), series: .value("Quelle", "Haus"))
                                .foregroundStyle(Theme.mint).lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.monotone)
                        }
                        if showCar, let value = point.carKW {
                            LineMark(x: .value("Zeit", point.timestamp), y: .value("Leistung", value), series: .value("Quelle", "Audi"))
                                .foregroundStyle(Theme.blue).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4])).interpolationMethod(.monotone)
                        }
                    }
                    if let selected {
                        RuleMark(x: .value("Auswahl", selected.timestamp)).foregroundStyle(.secondary.opacity(0.5))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                        AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(.primary.opacity(0.06)); AxisValueLabel() }
                }
                .chartYAxisLabel("kW", position: .topLeading)
                .chartXSelection(value: $selectedDate)
                .frame(height: 210)
                HStack(spacing: 18) {
                    legend("PV", color: Theme.solar)
                    legend("Haus", color: Theme.mint)
                    if showCar { legend("Audi", color: Theme.blue) }
                    Spacer(minLength: 0)
                }
                if let selected {
                    Text("\(selected.timestamp.formatted(date: .omitted, time: .shortened)) · PV \(EnergyFormat.power(selected.solarKW)) · Haus \(EnergyFormat.power(selected.houseKW))")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) { Circle().fill(color).frame(width: 6, height: 6); Text(title).font(.caption).foregroundStyle(.secondary) }
    }
}
