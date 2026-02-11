import SwiftUI

struct TimeRangePicker: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var vm = appState.dashboardVM

        Picker("Time Range", selection: $vm.selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 200)
    }
}
