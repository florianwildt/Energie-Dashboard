import Foundation
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case overview = "Übersicht", charging = "Laden", planning = "Planung", analytics = "Auswertung", system = "Anlage"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .charging: "bolt.car"
        case .planning: "calendar"
        case .analytics: "chart.xyaxis.line"
        case .system: "slider.horizontal.3"
        }
    }
}

enum ChargingMode: String, Codable, CaseIterable, Identifiable {
    case smart, solar, departure, immediate, paused
    var id: String { rawValue }
    var title: String {
        switch self {
        case .smart: "Intelligent"
        case .solar: "Nur Sonne"
        case .departure: "Zur Abfahrt"
        case .immediate: "Sofort laden"
        case .paused: "Pausiert"
        }
    }
    var symbol: String {
        switch self {
        case .smart: "sparkles"
        case .solar: "sun.max"
        case .departure: "clock"
        case .immediate: "bolt.fill"
        case .paused: "pause.fill"
        }
    }
    var detail: String {
        switch self {
        case .smart: "PV-Überschuss nutzen und dein Abfahrtsziel berücksichtigen."
        case .solar: "Nur den aktuellen PV-Überschuss nutzen. Keine Ladegarantie zur Abfahrt."
        case .departure: "Benötigte Energie bis zur Abfahrt einplanen, bei Bedarf aus dem Netz."
        case .immediate: "Mit der eingestellten maximalen Ladeleistung laden."
        case .paused: "Das Laden bleibt bis zu deiner nächsten Modusänderung pausiert."
        }
    }
}

struct EnergySnapshot: Codable, Sendable {
    var timestamp: Date
    var solarKW: Double?
    var houseKW: Double?
    var batteryKW: Double? // Positive = charging; negative = discharging.
    var gridKW: Double? // Positive = import; negative = export.
    var carKW: Double?
    var batterySOC: Double?
    var carSOC: Double?
    var carConnected: Bool
    var batteryTemperature: Double?
    var solarSources: [SolarSource]
    var devices: [DeviceStatus]
    var message: String
    var isDemo: Bool
    var carSOCSource: String
    var chargerTimestamp: Date?
    var controlEnabled: Bool

    static var demo: EnergySnapshot {
        EnergySnapshot(timestamp: .now, solarKW: 8.4, houseKW: 1.2, batteryKW: 2.1,
                       gridKW: -0.9, carKW: 4.2, batterySOC: 68, carSOC: 54,
                       carConnected: true, batteryTemperature: 24.6,
                       solarSources: [SolarSource(id: "mppt1", name: "MPPT 1", powerKW: 2.1),
                                      SolarSource(id: "mppt2", name: "MPPT 2", powerKW: 1.5),
                                      SolarSource(id: "pv1", name: "Bestandsanlage · Zähler 1", powerKW: 2.8),
                                      SolarSource(id: "pv2", name: "Bestandsanlage · Zähler 2", powerKW: 2.0)],
                       devices: [DeviceStatus(id: "gx", name: "Cerbo GX", subtitle: "Venus OS · Energiezentrale", online: true, symbol: "cpu"),
                                 DeviceStatus(id: "multis", name: "3 × MultiPlus 5000", subtitle: "Wechselrichter-Verbund", online: true, symbol: "bolt.horizontal.circle"),
                                 DeviceStatus(id: "mppt", name: "2 × Victron MPPT", subtitle: "Solar-Laderegler", online: true, symbol: "sun.max"),
                                 DeviceStatus(id: "meters", name: "3 × Energiezähler", subtitle: "2 × PV · 1 × Netz", online: true, symbol: "gauge.with.dots.needle.50percent"),
                                 DeviceStatus(id: "batrium", name: "Batrium BMS", subtitle: "Hausakku · über Cerbo GX", online: true, symbol: "battery.75percent"),
                                 DeviceStatus(id: "goe", name: "go-e Charger CORE", subtitle: "Audi A6 e-tron · verbunden", online: true, symbol: "ev.charger")],
                       message: "Dein Audi lädt mit Sonnenstrom. Gleichzeitig wird der Hausakku für den Abend gefüllt.",
                       isDemo: true, carSOCSource: "Beispielwert", chargerTimestamp: .now, controlEnabled: false)
    }
}

struct SolarSource: Identifiable, Codable, Sendable {
    var id: String
    var name: String
    var powerKW: Double?
}

struct DeviceStatus: Identifiable, Codable, Sendable {
    var id: String
    var name: String
    var subtitle: String
    var online: Bool
    var symbol: String
}

struct EnergyPoint: Identifiable, Codable, Equatable, Sendable {
    var timestamp: Date
    var solarKW: Double?
    var houseKW: Double?
    var carKW: Double?
    var gridKW: Double?
    var id: Date { timestamp }

    static func demoDay() -> [EnergyPoint] {
        let start = Calendar.current.startOfDay(for: .now)
        return (0...96).map { index in
            let hour = Double(index) / 4
            let sun = max(0, sin((hour - 6.5) / 12 * .pi)) * (hour < 18.5 ? 8.8 : 0)
            let house = 0.65 + (hour > 17 && hour < 22 ? 1.3 : 0.35) + abs(sin(hour * 1.4)) * 0.4
            let car = hour >= 10 && hour <= 15.5 ? min(5.5, max(0, sun - house - 1.8)) : 0
            return EnergyPoint(timestamp: start.addingTimeInterval(Double(index) * 900), solarKW: sun,
                               houseKW: house, carKW: car, gridKW: house + car - sun)
        }
    }
}

struct UserSettings: Codable, Equatable {
    var targetSOC: Double = 80
    var manualCarSOC: Double = 54
    var batteryReserve: Double = 30
    var carCapacityKWh: Double = 94.9
    var houseCapacityKWh: Double = 20
    var maxChargingKW: Double = 11
    var importPrice: Double = 0.32
    var exportPrice: Double = 0.08
    var chargingEfficiency: Double = 0.90
    var departureHour: Int = 7
    var departureMinute: Int = 0
    var mode: ChargingMode = .smart
    var demoMode: Bool = true
    var gatewayURL: String = ""
    var allowGridCharging: Bool = true
    var appearance: String = "system"

    var departure: Date {
        let calendar = Calendar.current
        return calendar.nextDate(after: .now, matching: DateComponents(hour: departureHour, minute: departureMinute),
                                 matchingPolicy: .nextTime) ?? .now.addingTimeInterval(86400)
    }

    var departureLabel: String {
        String(format: "%02d:%02d", departureHour, departureMinute)
    }
}

struct ChargingPlan {
    var requiredKWh: Double
    var durationHours: Double
    var availableHours: Double
    var feasible: Bool
    var earliestStart: Date
    var explanation: String

    static func make(settings: UserSettings, soc: Double?, connected: Bool) -> ChargingPlan {
        let actualSOC = soc ?? settings.manualCarSOC
        let energy = max(0, settings.targetSOC - actualSOC) / 100 * settings.carCapacityKWh / settings.chargingEfficiency
        let hours = energy / max(1.4, settings.maxChargingKW)
        let available = max(0, settings.departure.timeIntervalSinceNow / 3600)
        let start = settings.departure.addingTimeInterval(-hours * 3600 - 900)
        let feasible = connected && hours <= available
        let message: String
        if !connected {
            message = "Das Auto ist nicht verbunden. Der Ladeplan wartet auf das Anstecken."
        } else if energy == 0 {
            message = "Dein eingestelltes Ladeziel ist bereits erreicht."
        } else if !feasible {
            message = "Das Ziel ist mit der eingestellten Leistung bis zur Abfahrt nicht erreichbar."
        } else if settings.mode == .paused {
            message = "Laden pausiert. Für dein Abfahrtsziel muss das Laden wieder aktiviert werden."
        } else if !settings.allowGridCharging || settings.mode == .solar {
            message = "Ladung nur aus PV-Überschuss. Ohne Wetterprognose ist das Abfahrtsziel nicht gesichert."
        } else {
            message = "PV-Überschuss zuerst. Fehlende Energie spätestens ab \(start.formatted(date: .omitted, time: .shortened)) aus dem Netz ergänzen."
        }
        return ChargingPlan(requiredKWh: energy, durationHours: hours, availableHours: available,
                            feasible: feasible, earliestStart: max(.now, start), explanation: message)
    }
}

enum EnergyFormat {
    static func number(_ value: Double, decimals: Int = 1) -> String {
        value.formatted(.number.locale(Locale(identifier: "de_DE")).precision(.fractionLength(decimals)))
    }
    static func power(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "– kW" }
        return "\(number(abs(value))) kW"
    }
    static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "– %" }
        return "\(number(value, decimals: 0)) %"
    }
    static func money(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
    }
}
