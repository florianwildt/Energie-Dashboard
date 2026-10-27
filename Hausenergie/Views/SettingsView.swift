import SwiftUI

struct SettingsView: View {
    @Environment(EnergyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var checking = false
    @AppStorage("energy.performanceLogging") private var performanceLogging = true
    @State private var performanceFile: URL?
    @State private var exportingPerformance = false
    @State private var performanceExportError: String?

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Toggle("Demomodus", isOn: $store.settings.demoMode)
                    .onChange(of: store.settings.demoMode) { _, _ in Task { await store.changeSource() } }
            } footer: { Text("Im Demomodus bleiben alle Aktionen in der App. Es werden keine Geräte angesprochen.") }

            if !store.settings.demoMode {
                Section("Lokale Energiezentrale") {
                    TextField("http://192.168.1.20:8787", text: $store.settings.gatewayURL)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .onChange(of: store.settings.gatewayURL) { _, _ in store.clearLiveData() }
                    SecureField("Zugriffsschlüssel", text: $store.token).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button {
                        Task {
                            checking = true
                            await store.changeSource()
                            checking = false
                        }
                    } label: {
                        HStack { Text("Verbindung herstellen"); Spacer(); if checking { ProgressView() } }
                    }.disabled(checking || store.settings.gatewayURL.isEmpty)
                    if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(Theme.solar) }
                    if let last = store.lastSuccess {
                        Label("Verbunden · \(last.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle").foregroundStyle(Theme.mint)
                    }
                }
            }

            Section {
                HStack { Text("Aktueller Audi-Ladestand"); Spacer(); Text(EnergyFormat.percent(store.settings.manualCarSOC)).foregroundStyle(Theme.blue) }
                Slider(value: $store.settings.manualCarSOC, in: 0...100, step: 1).tint(Theme.blue)
                    .accessibilityLabel("Manueller Audi-Ladestand")
                numericField("Nutzbarer Autoakku", value: $store.settings.carCapacityKWh, unit: "kWh")
                numericField("Maximale AC-Ladeleistung", value: $store.settings.maxChargingKW, unit: "kW")
                HStack { Text("Angenommener Ladewirkungsgrad"); Spacer(); Text(EnergyFormat.percent(store.settings.chargingEfficiency * 100)) }
                Slider(value: $store.settings.chargingEfficiency, in: 0.75...0.98, step: 0.01).accessibilityLabel("Ladewirkungsgrad")
            } header: { Text("Fahrzeug und Planung") }
              footer: { Text("Kapazität und Ladeleistung sind Startannahmen und müssen zu deiner Fahrzeugausstattung passen. Ohne Fahrzeuganbindung wird der manuelle Ladestand für den nächsten Ladeplan verwendet. Bei neuem Ladestand den Ladeplan erneut senden.") }

            Section {
                numericField("Netzstrom", value: $store.settings.importPrice, unit: "€/kWh")
                numericField("Einspeisevergütung", value: $store.settings.exportPrice, unit: "€/kWh")
            } header: { Text("Deine Energiepreise") }
              footer: { Text("Die Preise dienen der Auswertung. Die erste Version unterstützt einen festen Bezugspreis und eine einheitliche Einspeisevergütung.") }

            Section("Darstellung") {
                Picker("Erscheinungsbild", selection: $store.settings.appearance) {
                    Text("Wie das Gerät").tag("system")
                    Text("Hell").tag("light")
                    Text("Dunkel").tag("dark")
                }
            }
            Section {
                Toggle("Performance protokollieren", isOn: $performanceLogging)
                    .onChange(of: performanceLogging) { _, value in PerformanceLog.shared.setEnabled(value) }
                Button {
                    exportingPerformance = true
                    Task {
                        defer { exportingPerformance = false }
                        do {
                            performanceFile = try await PerformanceLog.shared.export()
                            performanceExportError = nil
                        } catch { performanceExportError = "Das Protokoll konnte nicht exportiert werden." }
                    }
                } label: {
                    HStack { Text("Performance-Protokoll vorbereiten"); Spacer(); if exportingPerformance { ProgressView() } }
                }.disabled(exportingPerformance)
                if let performanceFile {
                    ShareLink(item: performanceFile) { Label("Performance-Protokoll teilen", systemImage: "square.and.arrow.up") }
                }
                if let performanceExportError { Text(performanceExportError).font(.caption).foregroundStyle(.secondary) }
            } header: { Text("Diagnose") }
              footer: { Text("Das lokale, begrenzte Protokoll erfasst UI-Verzögerungen, UI-Bildtakt, CPU-Zeit, Speicher-Spitzenwert und Rechenzeiten. Es enthält keine Zugriffsschlüssel, Geräteadressen oder Energiemesswerte. Der UI-Bildtakt misst die Erreichbarkeit der Bedienoberfläche, nicht direkt die GPU-Bildrate.") }
            Section {
                LabeledContent("Version", value: "1.0.1 · Performance-Diagnose")
                Text("Die Energiezentrale unterstützt Victron-Messwerte und die go-e-Wallbox. Audi-Cloudzugriff, Wetterprognosen und bidirektionales Laden sind noch nicht integriert.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { Task { await store.flushPersistence() } }
        .toolbar { ToolbarItem(placement: .confirmationAction) {
            Button("Fertig") {
                normalizeSettings()
                Task { await store.refresh() }
                dismiss()
            }
        } }
    }

    private func numericField(_ title: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(0...3)))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                .accessibilityLabel(title)
            Text(unit).foregroundStyle(.secondary).font(.caption)
        }
    }

    private func normalizeSettings() {
        store.settings.carCapacityKWh = min(150, max(10, store.settings.carCapacityKWh))
        store.settings.maxChargingKW = min(22, max(1.4, store.settings.maxChargingKW))
        store.settings.importPrice = min(5, max(0, store.settings.importPrice))
        store.settings.exportPrice = min(5, max(0, store.settings.exportPrice))
    }
}
