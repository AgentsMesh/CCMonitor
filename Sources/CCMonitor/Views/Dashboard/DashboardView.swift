import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部摘要卡片（横向排列）
                SummaryCardsRow()
                    .fixedSize(horizontal: false, vertical: true)

                // 中部: 图表区域（横向排列）
                HStack(alignment: .top, spacing: 16) {
                    // 时间序列图表
                    TimeSeriesPanel()
                        .frame(minHeight: 350)
                        .clipped()

                    // 模型分布
                    ModelDistributionPanel()
                        .frame(minWidth: 300, maxWidth: 300, minHeight: 350)
                        .clipped()
                }
                .fixedSize(horizontal: false, vertical: true)

                // 底部: 项目 + 预算（横向排列）
                HStack(alignment: .top, spacing: 16) {
                    ProjectPanel()
                        .frame(minHeight: 250)
                        .clipped()

                    BudgetPanel()
                        .frame(minWidth: 300, maxWidth: 300, minHeight: 250)
                        .clipped()
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("CCMonitor Dashboard")
    }
}
