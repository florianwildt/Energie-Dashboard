import Foundation

// Networking, date parsing and history preparation stay off the UI actor.
actor GatewayClient {
    func history(address: String, token: String) async throws -> EnergyHistory {
        let points: [EnergyPoint] = try await request("api/history", address: address, token: token)
        try Task.checkCancellation()
        let span = PerformanceLog.shared.begin("history.prepare")
        defer { PerformanceLog.shared.end(span) }
        return EnergyHistory(points: points)
    }

    func request<T: Decodable & Sendable>(_ path: String, address: String, method: String = "GET", body: Data? = nil, token: String) async throws -> T {
        let networkSpan = PerformanceLog.shared.begin("gateway.request")
        defer { PerformanceLog.shared.end(networkSpan) }
        PerformanceLog.shared.event("gateway.endpoint", detail: path)
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: address), let scheme = base.scheme, ["http", "https"].contains(scheme),
              base.host != nil, base.user == nil, base.password == nil, base.query == nil, base.fragment == nil else {
            throw GatewayError.message("Bitte eine gültige Adresse wie http://192.168.1.20:8787 eintragen.")
        }
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw GatewayError.message("Keine gültige Antwort der Energiezentrale.") }
        guard (200..<300).contains(response.statusCode) else {
            let detail = (try? JSONDecoder().decode(GatewayFailure.self, from: data))?.detail
            throw GatewayError.message(detail ?? "Energiezentrale antwortet mit Status \(response.statusCode).")
        }
        // Reusable Sendable value types instead of allocating reference formatters per point.
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let standard = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = (try? standard.parse(value)) ?? (try? fractional.parse(value)) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Ungültiger Zeitstempel")
        }
        let decodeSpan = PerformanceLog.shared.begin("gateway.decode")
        defer { PerformanceLog.shared.end(decodeSpan) }
        return try decoder.decode(T.self, from: data)
    }
}

private struct GatewayFailure: Decodable { var detail: String }
enum GatewayError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}

actor SettingsPersistence {
    func save(_ settings: UserSettings) {
        let span = PerformanceLog.shared.begin("settings.persist")
        defer { PerformanceLog.shared.end(span) }
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: "energy.settings.v1")
    }

    func saveToken(_ token: String) {
        let span = PerformanceLog.shared.begin("keychain.persist")
        defer { PerformanceLog.shared.end(span) }
        KeychainToken.save(token)
    }
}
