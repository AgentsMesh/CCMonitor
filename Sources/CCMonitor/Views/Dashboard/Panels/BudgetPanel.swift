import SwiftUI

struct BudgetPanel: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Budget & Forecast")
                .font(.headline)

            // 日预算进度
            BudgetProgressView(
                title: "Daily Budget",
                current: appState.dashboardVM.todayCost,
                budget: appState.settingsVM.dailyBudget,
                warningThreshold: Constants.blocksWarningThreshold
            )

            // 月预算进度
            BudgetProgressView(
                title: "Monthly Budget",
                current: appState.aggregator.totalCostUSD,
                budget: appState.settingsVM.monthlyBudget,
                warningThreshold: Constants.blocksWarningThreshold
            )

            Divider()

            // 成本预测
            VStack(alignment: .leading, spacing: 8) {
                Text("Forecast")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Daily (projected)")
                        .font(.caption)
                    Spacer()
                    Text(Formatters.formatCost(appState.dashboardVM.burnRate.projectedDailyCost))
                        .font(.caption)
                        .monospacedDigit()
                }

                HStack {
                    Text("Monthly (projected)")
                        .font(.caption)
                    Spacer()
                    Text(Formatters.formatCost(appState.dashboardVM.burnRate.projectedMonthlyCost))
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct BudgetProgressView: View {
    let title: String
    let current: Double
    let budget: Double
    let warningThreshold: Double

    private var progress: Double {
        guard budget > 0 else { return 0 }
        return min(current / budget, 1.0)
    }

    private var progressColor: Color {
        if progress >= 1.0 { return .red }
        if progress >= warningThreshold { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text("\(Formatters.formatCostShort(current)) / \(Formatters.formatCostShort(budget))")
                    .font(.caption)
                    .monospacedDigit()
            }

            ProgressView(value: progress)
                .tint(progressColor)
        }
    }
}
