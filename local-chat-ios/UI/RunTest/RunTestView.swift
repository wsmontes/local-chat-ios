import SwiftUI

struct RunTestView: View {
    @StateObject private var harness = TestHarness()
    @State private var articleText = ""
    @State private var selectedModel: ModelInfo?
    @State private var models: [ModelInfo] = []
    @State private var lastResult: InferenceResult?
    @State private var currentMemoryMB: Double = 0

    private let modelManager = ModelManager()
    private let memoryMonitor = MemoryMonitor()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    modelPickerSection

                    MemoryGaugeView(usedMemoryMB: currentMemoryMB)
                        .padding(.horizontal)

                    textInputSection

                    runButtonSection

                    if harness.isRunning {
                        liveMetricsSection
                    }

                    if let result = lastResult {
                        resultSummarySection(result)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Run Test")
            .task {
                models = await modelManager.discoverModels()
                if let mem = await memoryMonitor.currentFootprintMB() {
                    currentMemoryMB = mem
                }
            }
        }
    }

    // MARK: - Sections

    private var modelPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model")
                .font(.headline)
                .padding(.horizontal)

            if models.isEmpty {
                Text("No models found. Add GGUF files in the Models tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                Picker("Model", selection: $selectedModel) {
                    Text("Select a model…").tag(nil as ModelInfo?)
                    ForEach(models) { model in
                        Text("\(model.fileName) (\(model.fileSizeFormatted))")
                            .tag(model as ModelInfo?)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
            }
        }
    }

    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Article Text")
                    .font(.headline)
                Spacer()
                Text("\(articleText.count) chars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal)

            TextEditor(text: $articleText)
                .font(.body)
                .frame(minHeight: 200)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if articleText.isEmpty {
                        Text("Paste article text here…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal)
        }
    }

    private var runButtonSection: some View {
        Button {
            runTest()
        } label: {
            HStack {
                if harness.isRunning {
                    ProgressView()
                        .tint(.white)
                    Text("Running…")
                } else {
                    Image(systemName: "play.fill")
                    Text("Run Inference")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(canRun ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!canRun)
        .padding(.horizontal)
    }

    private var liveMetricsSection: some View {
        HStack(spacing: 24) {
            MetricBadge(label: "Tokens", value: "\(harness.liveTokenCount)")
            MetricBadge(label: "tok/s", value: String(format: "%.1f", harness.liveTokensPerSecond))
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func resultSummarySection(_ result: InferenceResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Result")
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text(result.summary)
                    .font(.body)
                    .padding()
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 16) {
                    MetricBadge(label: "Latency", value: "\(String(format: "%.0f", result.latencyMs))ms")
                    MetricBadge(label: "tok/s", value: String(format: "%.1f", result.tokensPerSecond))
                    MetricBadge(label: "TTFT", value: "\(String(format: "%.0f", result.timeToFirstTokenMs))ms")
                    MetricBadge(label: "Mem", value: "\(String(format: "%.0f", result.peakMemoryMB))MB")
                }

                LatencyBadge(tier: result.latencyTier)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private var canRun: Bool {
        selectedModel != nil && !articleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !harness.isRunning
    }

    private func runTest() {
        guard let model = selectedModel else { return }
        let text = articleText
        Task {
            if let mem = await memoryMonitor.currentFootprintMB() {
                currentMemoryMB = mem
            }
            let result = await harness.runTest(model: model, articleText: text)
            lastResult = result
            if let mem = await memoryMonitor.currentFootprintMB() {
                currentMemoryMB = mem
            }
        }
    }
}

// MARK: - Shared Subviews

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
