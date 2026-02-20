import SwiftUI
import Charts
import AppKit

struct TimeSeriesPanel: View {
    @Environment(AppState.self) private var appState

    /// 图表区域宽度（用于像素→时间换算）
    @State private var chartWidth: CGFloat = 1
    /// 上次拖拽位置（用于计算增量）
    @State private var lastDragX: CGFloat = 0

    var body: some View {
        @Bindable var vm = appState.dashboardVM

        VStack(alignment: .leading, spacing: 12) {
            // 标题栏：标题 + 图表类型 + 粒度标签 + 缩放 + 预设 + Live
            headerBar

            if appState.dashboardVM.timeSeriesData.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Usage data will appear here as Claude Code is used.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 图表 + 手势层
                chartView
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Header

    private var headerBar: some View {
        @Bindable var vm = appState.dashboardVM

        return HStack(spacing: 8) {
            Text("Usage Over Time")
                .font(.headline)

            // 自动粒度标签
            Text(appState.dashboardVM.selectedTimeRange.rawValue)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())

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

            Divider().frame(height: 16)

            // +/- 缩放按钮
            Button {
                appState.dashboardVM.zoom(by: 1.0 - Constants.zoomStepFactor)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Zoom In")

            Button {
                appState.dashboardVM.zoom(by: 1.0 + Constants.zoomStepFactor)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Zoom Out")

            Divider().frame(height: 16)

            // 预设按钮
            ForEach(Constants.timeWindowPresets, id: \.label) { preset in
                Button(preset.label) {
                    appState.dashboardVM.applyPreset(duration: preset.duration)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(isPresetActive(preset.duration) ? .primary : .secondary)
            }

            Divider().frame(height: 16)

            // Live 按钮
            Button {
                appState.dashboardVM.goLive()
            } label: {
                HStack(spacing: 3) {
                    Circle()
                        .fill(appState.dashboardVM.isLive ? .green : .gray)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
            .help("Resume live scrolling")
        }
    }

    // MARK: - Chart

    private var chartView: some View {
        let vm = appState.dashboardVM

        return ZStack(alignment: .topLeading) {
            GeometryReader { geo in
                ZStack {
                    Chart(vm.timeSeriesData) { item in
                        if vm.selectedChartStyle == .bar {
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
                        if let selected = vm.selectedPoint,
                           selected.date == item.date {
                            RuleMark(x: .value("Selected", item.date))
                                .foregroundStyle(.gray.opacity(0.5))
                                .lineStyle(StrokeStyle(dash: [4, 4]))

                            PointMark(
                                x: .value("Time", item.date),
                                y: .value("Cost", item.cost)
                            )
                            .symbolSize(60)
                            .foregroundStyle(.blue)
                        }
                    }
                    .chartXScale(domain: vm.timeWindow.start...vm.timeWindow.end)
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
                    .chartXSelection(value: Binding(
                        get: { vm.rawSelectedDate },
                        set: { appState.dashboardVM.rawSelectedDate = $0 }
                    ))
                    .onChange(of: vm.rawSelectedDate) { _, newDate in
                        updateSelectedPoint(for: newDate)
                    }

                }
                .onAppear { chartWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, w in chartWidth = w }
                // 横向拖拽手势 — simultaneousGesture 避免吞掉 chartXSelection
                .simultaneousGesture(dragGesture)
                .overlay {
                    // 滚轮缩放捕获层 — 仅拦截滚轮事件，透传点击/拖拽
                    ScrollWheelCatcher { deltaY in
                        let factor = 1.0 + deltaY * Constants.zoomStepFactor * Constants.scrollWheelSensitivity
                        appState.dashboardVM.zoom(by: factor)
                    }
                }
            }

            // Tooltip 作为 overlay 悬浮显示
            if let point = vm.selectedPoint, !vm.isDragging {
                selectedPointTooltip(point)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !appState.dashboardVM.isDragging {
                    // 拖拽开始，记录起始 X
                    appState.dashboardVM.isDragging = true
                    lastDragX = 0
                }
                let currentX = value.translation.width
                let deltaX = currentX - lastDragX
                lastDragX = currentX

                let secondsPerPixel = appState.dashboardVM.timeWindow.duration / Double(chartWidth)
                let timeDelta = Double(-deltaX) * secondsPerPixel
                appState.dashboardVM.pan(by: timeDelta)
            }
            .onEnded { _ in
                appState.dashboardVM.isDragging = false
                lastDragX = 0
            }
    }

    // MARK: - Tooltip

    private func selectedPointTooltip(_ point: TimeSeriesPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Formatters.formatDateTime(point.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Label(Formatters.formatCost(point.cost), systemImage: "dollarsign.circle")
                .font(.caption)
                .fontWeight(.semibold)
            Text(point.tokenBreakdown)
                .font(.caption)
                .monospacedDigit()
            Text("\(point.requests) requests")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func updateSelectedPoint(for date: Date?) {
        guard !appState.dashboardVM.isDragging else { return }
        guard let date else {
            appState.dashboardVM.selectedPoint = nil
            return
        }
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

    private func isPresetActive(_ duration: TimeInterval) -> Bool {
        abs(appState.dashboardVM.timeWindow.duration - duration) < 60
    }
}

// MARK: - ScrollWheelCatcher (NSViewRepresentable)

/// 捕获 macOS 滚轮事件，deltaY 映射为缩放因子
struct ScrollWheelCatcher: NSViewRepresentable {
    let onScroll: (_ deltaY: CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class ScrollWheelNSView: NSView {
    var onScroll: ((_ deltaY: CGFloat) -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handleScroll(event)
                return event
            }
        }
    }

    override func removeFromSuperview() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        super.removeFromSuperview()
    }

    private func handleScroll(_ event: NSEvent) {
        // 检查鼠标是否在本 view 区域内
        guard self.window != nil else { return }
        let locationInWindow = event.locationInWindow
        let locationInView = convert(locationInWindow, from: nil)
        guard bounds.contains(locationInView) else { return }

        let dy = event.scrollingDeltaY
        guard abs(dy) > 0.1 else { return }

        let normalizedDy: CGFloat
        if event.hasPreciseScrollingDeltas {
            normalizedDy = dy / 50.0   // 触控板：降低灵敏度
        } else {
            normalizedDy = dy          // 鼠标滚轮：直接使用
        }
        onScroll?(normalizedDy)
    }

    // hitTest 返回 nil — 所有鼠标点击/悬停事件透传给下层 Chart
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override var acceptsFirstResponder: Bool { false }
}
