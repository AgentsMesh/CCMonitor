import SwiftUI
import SwiftData
import Logging

@main
struct CCMonitorApp: App {
    @State private var appState = AppState()

    init() {
        // 配置全局日志级别
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .debug
            return handler
        }
    }

    var body: some Scene {
        // 菜单栏
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                let title = appState.menuBarVM.menuBarTitle(mode: appState.settingsVM.menuBarDisplayMode)
                if appState.settingsVM.showCostInMenuBar, !title.isEmpty {
                    Text(title)
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)

        // Dashboard 窗口
        Window("CCMonitor Dashboard", id: "dashboard") {
            DashboardView()
                .environment(appState)
                .frame(
                    minWidth: 900, idealWidth: Constants.dashboardDefaultWidth,
                    minHeight: 600, idealHeight: Constants.dashboardDefaultHeight
                )
                .onDisappear {
                    WindowManager.deactivateApp()
                }
        }
        .defaultSize(width: Constants.dashboardDefaultWidth, height: Constants.dashboardDefaultHeight)

        // 设置窗口
        Window("CCMonitor Settings", id: "settings") {
            SettingsView()
                .environment(appState)
                .onDisappear {
                    WindowManager.deactivateApp()
                }
        }
        .defaultSize(width: 450, height: 300)
        .windowResizability(.contentSize)
    }
}
