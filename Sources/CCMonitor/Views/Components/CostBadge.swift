import SwiftUI

struct CostBadge: View {
    let cost: Double
    var size: BadgeSize = .medium

    enum BadgeSize {
        case small, medium, large

        var font: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .body
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
            case .medium: return EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6)
            case .large: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            }
        }
    }

    var body: some View {
        Text(Formatters.formatCostShort(cost))
            .font(size.font)
            .fontWeight(.medium)
            .monospacedDigit()
            .padding(size.padding)
            .background(costColor.opacity(0.15), in: Capsule())
            .foregroundStyle(costColor)
    }

    private var costColor: Color {
        if cost >= 10 { return .red }
        if cost >= 1 { return .orange }
        return .green
    }
}
