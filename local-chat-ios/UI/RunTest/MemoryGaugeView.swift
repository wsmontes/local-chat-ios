import SwiftUI

struct MemoryGaugeView: View {
    let usedMemoryMB: Double
    let totalMemoryMB: Double = 6144

    private var ratio: Double {
        min(usedMemoryMB / totalMemoryMB, 1.0)
    }

    private var barColor: Color {
        switch ratio {
        case ..<0.33: return .green
        case ..<0.66: return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Memory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(String(format: "%.0f", usedMemoryMB)) MB / \(String(format: "%.0f", totalMemoryMB)) MB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geometry.size.width * ratio, height: 8)
                        .animation(.easeOut(duration: 0.5), value: ratio)
                }
            }
            .frame(height: 8)
        }
    }
}
