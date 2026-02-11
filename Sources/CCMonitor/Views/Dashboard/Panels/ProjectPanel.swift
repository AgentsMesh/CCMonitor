import SwiftUI

struct ProjectPanel: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects")
                .font(.headline)

            if appState.dashboardVM.projects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "folder",
                    description: Text("Project usage data will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(appState.dashboardVM.projects) {
                    TableColumn("Project") { project in
                        Text(project.displayName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(min: 150, ideal: 200)

                    TableColumn("Cost") { project in
                        Text(Formatters.formatCost(project.totalCostUSD))
                            .monospacedDigit()
                    }
                    .width(80)

                    TableColumn("Tokens") { project in
                        Text(Formatters.formatTokenCount(project.totalTokens))
                            .monospacedDigit()
                    }
                    .width(80)

                    TableColumn("Requests") { project in
                        Text("\(project.requestCount)")
                            .monospacedDigit()
                    }
                    .width(70)

                    TableColumn("Last Active") { project in
                        Text(Formatters.formatDateTime(project.lastActivity))
                            .font(.caption)
                    }
                    .width(120)
                }
                .tableStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
