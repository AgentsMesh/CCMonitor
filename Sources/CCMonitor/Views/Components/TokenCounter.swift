import SwiftUI

struct TokenCounter: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(Formatters.formatTokenCount(count))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }
}
