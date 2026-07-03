import SwiftUI

// MARK: - Metric Badge

struct MetricBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Metric Cell

struct MetricCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Latency Badge

struct LatencyBadge: View {
    let tier: LatencyTier

    var body: some View {
        Text(tierLabel)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundColor(backgroundColor)
            .clipShape(Capsule())
    }

    private var tierLabel: String {
        switch tier {
        case .good: return "< 2s"
        case .acceptable: return "2-5s"
        case .slow: return "> 5s"
        case .failed: return "Failed"
        }
    }

    private var backgroundColor: Color {
        switch tier {
        case .good: return .green
        case .acceptable: return .yellow
        case .slow: return .red
        case .failed: return .red
        }
    }
}

// MARK: - Result Sheet

struct ResultSheetView: View {
    let result: InferenceResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.headline)
                        Text(result.summary)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Metrics")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricCell(label: "Total Latency", value: "\(String(format: "%.0f", result.latencyMs)) ms")
                            MetricCell(label: "TTFT", value: "\(String(format: "%.0f", result.timeToFirstTokenMs)) ms")
                            MetricCell(label: "Tokens / Second", value: String(format: "%.1f", result.tokensPerSecond))
                            MetricCell(label: "Peak Memory", value: "\(String(format: "%.1f", result.peakMemoryMB)) MB")
                            MetricCell(label: "Input Tokens", value: "\(result.inputTokenCount)")
                            MetricCell(label: "Output Tokens", value: "\(result.outputTokenCount)")
                            MetricCell(label: "Model", value: result.modelName)
                            MetricCell(label: "Output", value: "\(result.outputTokenCount) tokens")
                        }
                    }

                    LatencyBadge(tier: result.latencyTier)

                    DisclosureGroup("Original Text") {
                        Text(result.articleText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if result.didFail, let error = result.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
