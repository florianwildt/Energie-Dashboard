import Foundation

struct EnergyHistory: Sendable {
    let points: [EnergyPoint]
    let chartPoints: [EnergyPoint]
    let totals: EnergyTotals

    static let demo = EnergyHistory(points: EnergyPoint.demoDay())
    static let empty = EnergyHistory(points: [])

    init(points: [EnergyPoint]) {
        let sorted = points.sorted { $0.timestamp < $1.timestamp }
        self.points = sorted
        self.chartPoints = Self.displayPoints(sorted, limit: 360)
        self.totals = EnergyTotals(points: sorted)
    }

    // Keep extrema for each series. Cost and energy totals always use every sample.
    private static func displayPoints(_ points: [EnergyPoint], limit: Int) -> [EnergyPoint] {
        guard points.count > limit else { return points }
        let bucketCount = max(1, (limit - 2) / 12)
        let keys: [KeyPath<EnergyPoint, Double?>] = [\.solarKW, \.houseKW, \.carKW, \.gridKW]
        var selected: Set<Int> = [0, points.count - 1]
        for bucket in 0..<bucketCount {
            let start = 1 + (points.count - 2) * bucket / bucketCount
            let end = 1 + (points.count - 2) * (bucket + 1) / bucketCount
            for key in keys {
                var minimum: (index: Int, value: Double)?
                var maximum: (index: Int, value: Double)?
                var missing: Int?
                for index in start..<end {
                    guard let value = points[index][keyPath: key] else {
                        if missing == nil { missing = index }
                        continue
                    }
                    if minimum == nil || value < minimum!.value { minimum = (index, value) }
                    if maximum == nil || value > maximum!.value { maximum = (index, value) }
                }
                if let minimum { selected.insert(minimum.index) }
                if let maximum { selected.insert(maximum.index) }
                if let missing { selected.insert(missing) }
            }
        }
        return selected.sorted().map { points[$0] }
    }
}

struct EnergyTotals: Sendable {
    var solar = 0.0
    var house = 0.0
    var car = 0.0
    var imported = 0.0
    var exported = 0.0
    var coverageHours = 0.0
    var gridHours = 0.0

    init(points: [EnergyPoint]) {
        for (first, second) in zip(points, points.dropFirst()) {
            let hours = second.timestamp.timeIntervalSince(first.timestamp) / 3600
            guard hours > 0, hours <= 0.5 else { continue }
            coverageHours += hours
            if let a = first.solarKW, let b = second.solarKW { solar += (a + b) / 2 * hours }
            if let a = first.houseKW, let b = second.houseKW { house += (a + b) / 2 * hours }
            if let a = first.carKW, let b = second.carKW { car += (a + b) / 2 * hours }
            if let a = first.gridKW, let b = second.gridKW {
                gridHours += hours
                if a * b < 0 {
                    let share = abs(a) / (abs(a) + abs(b))
                    imported += max(a, 0) * hours * share / 2 + max(b, 0) * hours * (1 - share) / 2
                    exported += max(-a, 0) * hours * share / 2 + max(-b, 0) * hours * (1 - share) / 2
                } else {
                    imported += max(0, (a + b) / 2) * hours
                    exported += max(0, -(a + b) / 2) * hours
                }
            }
        }
    }
}
