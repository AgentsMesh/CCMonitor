import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState.settingsVM

        TabView {
            // 通用设置
            Form {
                Section("Display") {
                    Toggle("Show cost in menu bar", isOn: $settings.showCostInMenuBar)

                    Picker("Menu bar style", selection: $settings.menuBarDisplayMode) {
                        ForEach(SettingsViewModel.MenuBarDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .disabled(!settings.showCostInMenuBar)
                }

                Section("Startup") {
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gear")
            }

            // 预算设置
            Form {
                Section("Budget Limits") {
                    HStack {
                        Text("Daily budget")
                        Spacer()
                        TextField("", value: $settings.dailyBudget, format: .currency(code: "USD"))
                            .frame(width: 120)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Monthly budget")
                        Spacer()
                        TextField("", value: $settings.monthlyBudget, format: .currency(code: "USD"))
                            .frame(width: 120)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Notifications") {
                    Toggle("Enable budget alerts", isOn: $settings.budgetAlertEnabled)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Budget", systemImage: "dollarsign.circle")
            }
        }
        .frame(width: 420, height: 280)
    }
}
