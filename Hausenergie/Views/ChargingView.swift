import SwiftUI

struct ChargingView: View {
    @Environment(EnergyStore.self) private var store
    @State private var selectedMode: ChargingMode = .smart

    var body: some View {
        @Bindable var store = store
        PageLayout {
            SectionIntro(eyebrow: "Deine Mobilität", title: "Mit gutem Gefühl laden.", subtitle: "Du bestimmst das Ziel. Dein Zuhause liefert die Energie.")
            EnergyCard {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AUDI A6 E-TRON").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                        Text(EnergyFormat.percent(store.snapshot.carSOC)).font(.system(size: 52, weight: .medium, design: .rounded)).monospacedDigit()
                        Text(store.snapshot.carSOCSource).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "car.side.fill").font(.system(size: 68, weight: .ultraLight))
                        .foregroundStyle(Theme.blue.gradient).padding(.top, 20).accessibilityHidden(true)
                }
                ProgressView(value: min(100, max(0, store.snapshot.carSOC ?? store.settings.manualCarSOC)), total: 100).tint(Theme.blue)
                HStack {
                    StatusPill(title: store.snapshot.carConnected ? "Verbunden" : "Nicht verbunden", color: store.snapshot.carConnected ? Theme.mint : Theme.solar)
                    Spacer()
                    Text(EnergyFormat.power(store.snapshot.carKW)).font(.headline).monospacedDigit()
                }
            }

            EnergyCard("Wie möchtest du laden?") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                    ForEach(ChargingMode.allCases) { mode in
                        Button { selectedMode = mode } label: {
                            HStack(spacing: 8) {
                                Image(systemName: mode.symbol)
                                Text(mode.title).font(.subheadline.weight(.medium))
                            }
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .foregroundStyle(selectedMode == mode ? Theme.background : Color.primary)
                            .background(selectedMode == mode ? Theme.mint : Theme.inset, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
                    }
                }
                Text(selectedMode.detail).font(.subheadline).foregroundStyle(.secondary)
            }

            EnergyCard("Dein Ladeziel") {
                HStack { Text("Ziel-Ladestand"); Spacer(); Text(EnergyFormat.percent(store.settings.targetSOC)).font(.title2.weight(.semibold)).foregroundStyle(Theme.blue) }
                Slider(value: $store.settings.targetSOC, in: 20...100, step: 5).tint(Theme.blue)
                    .accessibilityLabel("Ziel-Ladestand")
                HStack {
                    Text("Nächste Abfahrt")
                    Spacer()
                    DatePicker("Abfahrt", selection: departureBinding, displayedComponents: .hourAndMinute).labelsHidden()
                }
                Divider()
                Toggle("Netzstrom bei Bedarf erlauben", isOn: $store.settings.allowGridCharging)
                    .font(.subheadline)
                Text("Die Wallboxregelung berücksichtigt deine Hausakku-Reserve. Die tatsächliche Akku-Untergrenze wird weiterhin im Victron-ESS festgelegt. Die Planung nutzt deine manuelle SoC-Eingabe.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            EnergyCard(eyebrow: "Dein Plan") {
                InfoRow(title: "Benötigte Ladeenergie", value: "\(EnergyFormat.number(store.plan.requiredKWh)) kWh")
                InfoRow(title: "Mindestladezeit bei Maximalleistung", value: "\(EnergyFormat.number(store.plan.durationHours)) Stunden")
                InfoRow(title: "Zeit bis zur Abfahrt", value: "\(EnergyFormat.number(store.plan.availableHours)) Stunden")
                Text(store.plan.explanation).font(.subheadline).foregroundStyle(store.plan.feasible ? Color.secondary : Theme.solar)
                if let notice = store.notice {
                    Label(notice, systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(Theme.mint)
                }
                if !store.settings.demoMode && !store.canControl {
                    Label("Lesemodus. Die Energiezentrale muss für die Wallboxsteuerung freigegeben sein.", systemImage: "lock")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    Task { await store.applyMode(selectedMode) }
                } label: {
                    HStack {
                        if store.isSending { ProgressView().tint(Theme.background) }
                        Text(store.settings.demoMode ? "Ladeplan in der Demo anwenden" : "Ladeplan an Energiezentrale senden")
                    }
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(!store.canControl || store.isSending)
                .opacity(!store.canControl ? 0.45 : 1)
            }
        }
        .onAppear { selectedMode = store.settings.mode }
    }

    private var departureBinding: Binding<Date> {
        Binding(get: { store.settings.departure }, set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            store.settings.departureHour = components.hour ?? 7
            store.settings.departureMinute = components.minute ?? 0
        })
    }
}
