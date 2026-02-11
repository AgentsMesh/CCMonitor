import SwiftUI
import Charts

struct ModelDistributionPanel: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Distribution")
                .font(.headline)

            if appState.dashboardVM.modelDistribution.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.pie",
                    description: Text("Model usage will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(appState.dashboardVM.modelDistribution, id: \.model) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value("Model", item.model))
                }
                .chartLegend(position: .bottom, spacing: 8)
                .frame(height: 200)

                // 详细列表
                ForEach(appState.dashboardVM.modelDistribution, id: \.model) { item in
                    HStack {
                        Text(item.model)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
