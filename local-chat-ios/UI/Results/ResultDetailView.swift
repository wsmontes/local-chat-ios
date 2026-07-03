import SwiftUI

struct ResultDetailView: View {
    let result: InferenceResult
    @State private var showOriginalText = false

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
                            MetricCell(label: "Time to First Token", value: "\(String(format: "%.0f", result.timeToFirstTokenMs)) ms")
                            MetricCell(label: "Tokens / Second", value: String(format: "%.1f", result.tokensPerSecond))
                            MetricCell(label: "Peak Memory", value: "\(String(format: "%.1f", result.peakMemoryMB)) MB")
                            MetricCell(label: "Input Tokens", value: "\(result.inputTokenCount)")
                            MetricCell(label: "Output Tokens", value: "\(result.outputTokenCount)")
                            MetricCell(label: "Model", value: result.modelName)
                            MetricCell(label: "Timestamp", value: result.timestamp.formatted(date: .abbreviated, time: .shortened))
                        }
                    }

                    LatencyBadge(tier: result.latencyTier)

                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation { showOriginalText.toggle() }
                        } label: {
                            HStack {
                                Text("Original Text")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: showOriginalText ? "chevron.up" : "chevron.down")
                            }
                        }

                        if showOriginalText {
                            Text(result.articleText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding()
                                .background(Color.secondary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    if result.didFail, let error = result.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error")
                                .font(.headline)
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Result Detail")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

