import SwiftUI
import Charts

struct TimeSeriesPanel: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var vm = appState.dashboardVM

        VStack(alignment: .leading, spacing: 12) {
            // 标题栏：标题 + 图表类型切换 + 时间范围选择
            HStack(spacing: 12) {
                Text("Usage Over Time")
                    .font(.headline)

                Spacer()

                // 图表类型切换
                Picker("Style", selection: $vm.selectedChartStyle) {
                    ForEach(ChartStyle.allCases, id: \.self) { style in
                        Image(systemName: style == .bar ? "chart.bar.fill" : "chart.line.uptrend.xyaxis")
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 80)

                TimeRangePicker()
            }

            if appState.dashboardVM.timeSeriesData.isEmpty {
                // 空状态居中显示
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Usage data will appear here as Claude Code is used.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 图表
                Chart(appState.dashboardVM.timeSeriesData) { item in
                    if appState.dashboardVM.selectedChartStyle == .bar {
                        BarMark(
                            x: .value("Time", item.date),
                            y: .value("Cost", item.cost)
                        )
                        .foregroundStyle(.blue.gradient)
                    } else {
                        LineMark(
                            x: .value("Time", item.date),
                            y: .value("Cost", item.cost)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Time", item.date),
                            y: .value("Cost", item.cost)
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                        .interpolationMethod(.catmullRom)
                    }

                    // 选中数据点的标注线
                    if let selected = appState.dashboardVM.selectedPoint,
                       selected.date == item.date {
                        RuleMark(x: .value("Selected", item.date))
                            .foregroundStyle(.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(dash: [4, 4]))
                            .annotation(position: .top, spacing: 4) {
                                selectedPointTooltip(item)
                            }

                        PointMark(
                            x: .value("Time", item.date),
                            y: .value("Cost", item.cost)
                        )
                        .symbolSize(60)
                        .foregroundStyle(.blue)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: timeFormat)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Formatters.formatCostShort(v))
                            }
                        }
                    }
                }
                .chartXSelection(value: $vm.rawSelectedDate)
                .onChange(of: appState.dashboardVM.rawSelectedDate) { _, newDate in
                    updateSelectedPoint(for: newDate)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Tooltip

    private func selectedPointTooltip(_ point: TimeSeriesPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Formatters.formatDateTime(point.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Label(Formatters.formatCost(point.cost), systemImage: "dollarsign.circle")
                    .font(.caption)
                    .fontWeight(.semibold)
                Label(Formatters.formatTokenCount(point.tokens), systemImage: "number")
                    .font(.caption)
            }
            Text("\(point.requests) requests")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func updateSelectedPoint(for date: Date?) {
        guard let date else {
            appState.dashboardVM.selectedPoint = nil
            return
        }
        // 查找最近的数据点
        appState.dashboardVM.selectedPoint = appState.dashboardVM.timeSeriesData
            .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private var timeFormat: Date.FormatStyle {
        switch appState.dashboardVM.selectedTimeRange {
        case .minutes:
            return .dateTime.hour().minute()
        case .hours:
            return .dateTime.weekday(.abbreviated).hour()
        case .days:
            return .dateTime.month(.abbreviated).day()
        }
    }
}
