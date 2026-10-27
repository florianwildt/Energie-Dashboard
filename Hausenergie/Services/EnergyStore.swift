import Foundation
import Observation
import Security

@MainActor @Observable
final class EnergyStore {
    var settings: UserSettings {
        didSet {
            guard settings != oldValue else { return }
            settingsSaveTask?.cancel()
            let value = settings
            settingsSaveTask = Task {
                do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
                await persistence.save(value)
            }
        }
    }
    var snapshot: EnergySnapshot = .demo
    private(set) var historyData: EnergyHistory = .demo
    var history: [EnergyPoint] { historyData.points }
    var chartPoints: [EnergyPoint] { historyData.chartPoints }
    var totals: EnergyTotals { historyData.totals }
    var isRefreshing = false
    var isSending = false
    var errorMessage: String?
    var notice: String?
    var lastSuccess: Date?
    var token: String {
        didSet {
            guard token != oldValue else { return }
            tokenSaveTask?.cancel()
            let value = token
            tokenSaveTask = Task {
                do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
                await persistence.saveToken(value)
            }
        }
    }
    @ObservationIgnored private let client = GatewayClient()
    @ObservationIgnored private let persistence = SettingsPersistence()
    @ObservationIgnored private var settingsSaveTask: Task<Void, Never>?
    @ObservationIgnored private var tokenSaveTask: Task<Void, Never>?
    @ObservationIgnored private var historyTask: Task<Void, Never>?
    @ObservationIgnored private var lastHistoryLoad: Date?
    @ObservationIgnored private var sourceGeneration = 0
    @ObservationIgnored private var demoInputs: DemoInputs?

    init() {
        if let data = UserDefaults.standard.data(forKey: "energy.settings.v1"),
           let saved = try? JSONDecoder().decode(UserSettings.self, from: data) {
            settings = saved
        } else {
            settings = UserSettings()
        }
        token = KeychainToken.read()
        if !settings.demoMode { clearLiveData() }
    }

    var plan: ChargingPlan {
        ChargingPlan.make(settings: settings, soc: snapshot.carSOC, connected: snapshot.carConnected)
    }

    var stale: Bool { !settings.demoMode && (lastSuccess == nil || Date.now.timeIntervalSince(snapshot.timestamp) > 30) }
    var canControl: Bool { settings.demoMode || (!stale && snapshot.controlEnabled) }

    func run() async {
        PerformanceLog.shared.event("refresh.session", detail: settings.demoMode ? "demo" : "live")
        if settings.demoMode {
            await refresh()
            return
        }
        while !Task.isCancelled {
            await refresh()
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
        }
    }

    func clearLiveData() {
        sourceGeneration += 1
        historyTask?.cancel()
        historyTask = nil
        lastHistoryLoad = nil
        demoInputs = nil
        snapshot = EnergySnapshot(timestamp: .distantPast, carConnected: false, solarSources: [], devices: [],
                                  message: "Verbinde deine lokale Energiezentrale, um Messwerte zu sehen.", isDemo: false,
                                  carSOCSource: "Manuelle Eingabe", controlEnabled: false)
        historyData = .empty
        lastSuccess = nil
    }

    func changeSource() async {
        errorMessage = nil
        notice = nil
        clearLiveData()
        await refresh()
    }

    func refresh(forceHistory: Bool = false) async {
        guard !isRefreshing else { return }
        if settings.demoMode {
            let inputs = DemoInputs(settings: settings)
            guard inputs != demoInputs else { return }
            let span = PerformanceLog.shared.begin("demo.refresh")
            defer { PerformanceLog.shared.end(span) }
            var demo = EnergySnapshot.demo
            demo.carSOC = settings.manualCarSOC
            let atTarget = settings.manualCarSOC >= settings.targetSOC
            let paused = settings.mode == .paused || atTarget
            let carPower = paused ? 0 : min(settings.mode == .immediate ? settings.maxChargingKW : 4.2, settings.maxChargingKW)
            demo.carKW = carPower
            demo.gridKW = 1.2 + 2.1 + carPower - 8.4
            demo.message = atTarget ? "Dein Ladeziel ist erreicht. Der Hausakku nutzt den Sonnenstrom."
                : paused ? "Das Auto pausiert. Sonnenstrom versorgt dein Haus und den Hausakku."
                : settings.mode == .immediate ? "Sofortladen ist aktiv. Zusätzlicher Bedarf wird aus dem Netz gedeckt."
                : "Dein Audi nutzt Sonnenstrom. Der Hausakku wird parallel für den Abend gefüllt."
            snapshot = demo
            if history.isEmpty || !Calendar.current.isDate(history[0].timestamp, inSameDayAs: .now) {
                historyData = EnergyHistory(points: EnergyPoint.demoDay())
            }
            demoInputs = inputs
            lastSuccess = .now
            errorMessage = nil
            return
        }
        guard !settings.gatewayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let requestedURL = settings.gatewayURL
        let requestedToken = token
        let generation = sourceGeneration
        do {
            let current: EnergySnapshot = try await client.request("api/snapshot", address: requestedURL, token: requestedToken)
            guard !Task.isCancelled, generation == sourceGeneration, !settings.demoMode, settings.gatewayURL == requestedURL, token == requestedToken else { return }
            snapshot = current
            lastSuccess = .now
            errorMessage = nil
            loadHistoryIfNeeded(force: forceHistory)
        } catch {
            guard !Task.isCancelled, generation == sourceGeneration, !settings.demoMode, settings.gatewayURL == requestedURL else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadHistoryIfNeeded(force: Bool) {
        guard historyTask == nil, force || lastHistoryLoad == nil || Date.now.timeIntervalSince(lastHistoryLoad!) >= 60 else { return }
        let address = settings.gatewayURL
        let requestedToken = token
        let generation = sourceGeneration
        historyTask = Task {
            defer { if generation == sourceGeneration { historyTask = nil } }
            do {
                let data = try await client.history(address: address, token: requestedToken)
                guard !Task.isCancelled, generation == sourceGeneration, !settings.demoMode,
                      settings.gatewayURL == address, token == requestedToken else { return }
                if data.points != history { historyData = data }
                lastHistoryLoad = .now
            } catch {
                if !Task.isCancelled { PerformanceLog.shared.event("history.error", detail: "request-failed") }
            }
        }
    }

    func flushPersistence() async {
        settingsSaveTask?.cancel()
        tokenSaveTask?.cancel()
        await persistence.save(settings)
        await persistence.saveToken(token)
    }

    func applyMode(_ mode: ChargingMode) async {
        guard !isSending else { return }
        if settings.demoMode {
            settings.mode = mode
            await refresh()
            notice = "\(mode.title) im Demomodus aktiviert."
            return
        }
        guard canControl else {
            errorMessage = "Die Anlage ist im Lesemodus oder die Messwerte sind veraltet."
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            let body = ControlRequest(mode: mode, targetSOC: settings.targetSOC, manualCarSOC: settings.manualCarSOC,
                                      carCapacityKWh: settings.carCapacityKWh, chargingEfficiency: settings.chargingEfficiency,
                                      batteryReserve: settings.batteryReserve, maxChargingKW: settings.maxChargingKW,
                                      departure: settings.departure, allowGridCharging: settings.allowGridCharging)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let response: ControlResponse = try await request("api/control", method: "POST", body: encoder.encode(body), token: token)
            settings.mode = mode
            notice = response.message
            await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    private func request<T: Decodable & Sendable>(_ path: String, method: String = "GET", body: Data? = nil, token: String) async throws -> T {
        try await client.request(path, address: settings.gatewayURL, method: method, body: body, token: token)
    }
}

private struct ControlRequest: Encodable {
    var mode: ChargingMode
    var targetSOC: Double
    var manualCarSOC: Double
    var carCapacityKWh: Double
    var chargingEfficiency: Double
    var batteryReserve: Double
    var maxChargingKW: Double
    var departure: Date
    var allowGridCharging: Bool
}
private struct ControlResponse: Decodable, Sendable { var message: String }
private struct DemoInputs: Equatable {
    let day: Date
    let carSOC: Double
    let target: Double
    let mode: ChargingMode
    let power: Double
    init(settings: UserSettings) {
        day = Calendar.current.startOfDay(for: .now)
        carSOC = settings.manualCarSOC
        target = settings.targetSOC
        mode = settings.mode
        power = settings.maxChargingKW
    }
}

enum KeychainToken {
    private static let service = "de.wildt.hausenergie.gateway"
    static func read() -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecAttrAccount as String: "token",
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ value: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecAttrAccount as String: "token"]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
