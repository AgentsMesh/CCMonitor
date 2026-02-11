import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                Text("CCMonitor")
                    .font(.headline)
                Spacer()
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // 加载进度
            if appState.isLoadingHistory {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(appState.loadingProgress)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // 今日摘要
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Formatters.formatCost(appState.menuBarVM.todayCost))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }

                HStack {
                    Text("Tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(appState.menuBarVM.todayTokenBreakdown)
                        .font(.caption)
                        .monospacedDigit()
                }
            }

            Divider()

            // Burn Rate
            HStack {
                Label("Burn Rate", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Spacer()
                Text(Formatters.formatBurnRate(appState.menuBarVM.burnRate.costPerHour))
                    .font(.caption)
                    .monospacedDigit()
            }

            // 活跃 Sessions
            HStack {
                Label("Sessions", systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                Text("\(appState.menuBarVM.activeSessions) active")
                    .font(.caption)
            }

            // 主要模型
            HStack {
                Label("Model", systemImage: "cpu")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Spacer()
                Text(appState.menuBarVM.topModel)
                    .font(.caption)
                    .lineLimit(1)
            }

            Divider()

            // 操作按钮
            HStack {
                Button("Dashboard") {
                    // 每次点击时注入最新的 openWindow action，确保引用有效
                    WindowManager.openWindowAction = openWindow
                    WindowManager.openDashboard()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()

                Button("Settings") {
                    WindowManager.openWindowAction = openWindow
                    WindowManager.openSettings()
                }
                .controlSize(.small)

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .controlSize(.small)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
