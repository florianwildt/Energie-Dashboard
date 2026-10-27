import SwiftUI

struct RootView: View {
    @Environment(EnergyStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: AppSection? = .overview
    @State private var showSettings = false

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    VStack(alignment: .leading, spacing: 26) {
                        HStack(spacing: 10) {
                            Image(systemName: "house.and.flag.fill").foregroundStyle(Theme.mint)
                            Text("hausenergie").font(.system(.title2, design: .rounded, weight: .semibold))
                        }.padding(.horizontal, 18).padding(.top, 24)
                        List(AppSection.allCases, selection: $selection) { section in
                            Label(section.rawValue, systemImage: section.symbol).tag(section)
                                .padding(.vertical, 7)
                        }.listStyle(.sidebar).scrollContentBackground(.hidden)
                        VStack(alignment: .leading, spacing: 10) {
                            StatusPill(title: store.settings.demoMode ? "Demomodus" : store.stale ? "Verbindung prüfen" : "Lokal verbunden",
                                       color: store.stale ? Theme.solar : Theme.mint)
                            Text("Energie bewusst nutzen.").font(.caption).foregroundStyle(.secondary)
                        }.padding(20)
                    }
                    .background(Theme.background)
                    .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 280)
                } detail: {
                    NavigationStack { page(selection ?? .overview) }
                }
            } else {
                TabView(selection: $selection) {
                    ForEach(AppSection.allCases) { section in
                        NavigationStack {
                            if selection == section {
                                page(section)
                            } else {
                                Theme.background
                            }
                        }
                            .tabItem { Label(section.rawValue, systemImage: section.symbol) }
                            .tag(Optional(section))
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
    }

    private func page(_ section: AppSection) -> some View {
        VStack(spacing: 0) {
            if store.settings.demoMode {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                    Text("Demomodus · Beispieldaten · keine Gerätesteuerung")
                    Spacer(minLength: 0)
                }
                .font(.caption).foregroundStyle(Theme.mint)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Theme.mint.opacity(0.07))
            } else if let error = store.errorMessage {
                Label(error, systemImage: "wifi.exclamationmark")
                    .font(.caption).foregroundStyle(Theme.solar)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(Theme.solar.opacity(0.08))
            } else if store.stale {
                Label("Noch keine aktuellen Messwerte", systemImage: "clock.badge.exclamationmark")
                    .font(.caption).foregroundStyle(Theme.solar).padding(10)
            }
            Group {
                switch section {
                case .overview: OverviewView()
                case .charging: ChargingView()
                case .planning: PlanningView()
                case .analytics: AnalyticsView()
                case .system: SystemView()
                }
            }
        }
        .background(Theme.background)
        .navigationTitle(sizeClass == .regular ? "" : "hausenergie")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if sizeClass == .regular {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if store.isRefreshing && !store.settings.demoMode { ProgressView().controlSize(.small) }
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Einstellungen öffnen")
            }
        }
        .refreshable { await store.refresh(forceHistory: true) }
    }
}
