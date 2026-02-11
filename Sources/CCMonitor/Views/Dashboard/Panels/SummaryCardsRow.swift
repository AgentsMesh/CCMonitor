import SwiftUI

struct SummaryCardsRow: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 16) {
            // 今日消耗
            SummaryCard(
                title: "Today's Cost",
                value: Formatters.formatCost(appState.dashboardVM.todayCost),
                subtitle: appState.dashboardVM.todayTokenBreakdown,
                icon: "dollarsign.circle.fill",
                color: .blue
            )

            // Burn Rate
            SummaryCard(
                title: "Burn Rate",
                value: Formatters.formatBurnRate(appState.dashboardVM.burnRate.costPerHour),
                subtitle: Formatters.formatTokenRate(appState.dashboardVM.burnRate.tokensPerMinute),
                icon: "flame.fill",
                color: .orange
            )

            // 活跃 Sessions
            SummaryCard(
                title: "Active Sessions",
                value: "\(appState.dashboardVM.activeSessions)",
                subtitle: "\(appState.aggregator.sessions.count) total",
                icon: "person.2.fill",
                color: .green
            )
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
