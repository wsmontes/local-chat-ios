import Foundation

@MainActor
final class TestHarness: ObservableObject {
    @Published var isRunning = false
    @Published var liveTokenCount = 0
    @Published var liveTokensPerSecond = 0.0
    @Published var statusMessage = ""
    @Published var inferencePhase: InferenceEngine.Phase = .loading

    private let memoryMonitor = MemoryMonitor()
    private let inferenceEngine = InferenceEngine()
    private let metricsStore = MetricsStore()

    func runTest(model: ModelInfo, articleText: String, template: EditableTemplate? = nil) async -> InferenceResult {
        isRunning = true
        inferencePhase = .loading
        statusMessage = "Loading model..."
        liveTokenCount = 0
        liveTokensPerSecond = 0

        let input = InferenceInput(modelId: model.id, articleText: articleText, template: template)

        let beforeMem = await memoryMonitor.currentFootprintMB() ?? 0
        let startTime = Date()

        let result: InferenceResult
        do {
            result = try await inferenceEngine.run(
                input: input,
                modelName: model.fileName,
                modelURL: model.fileURL,
                onProgress: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.inferencePhase = progress.phase
                        self.liveTokenCount = progress.tokenCount
                        self.liveTokensPerSecond = progress.tokensPerSecond
                        switch progress.phase {
                        case .loading:
                            self.statusMessage = "Loading model..."
                        case .generating:
                            self.statusMessage = "Generating..."
                        case .done:
                            self.statusMessage = "Done"
                        }
                    }
                }
            )
        } catch {
            isRunning = false
            statusMessage = "Failed: \(error.localizedDescription)"
            return InferenceResult(
                id: UUID(),
                modelId: model.id,
                modelName: model.fileName,
                inputTokenCount: 0,
                outputTokenCount: 0,
                articleText: String(articleText.prefix(2000)),
                summary: "Error: \(error.localizedDescription)",
                latencyMs: Date().timeIntervalSince(startTime) * 1000,
                timeToFirstTokenMs: 0,
                tokensPerSecond: 0,
                peakMemoryMB: 0,
                timestamp: Date(),
                didFail: true,
                errorMessage: error.localizedDescription
            )
        }

        let afterMem = await memoryMonitor.currentFootprintMB() ?? 0
        let peakMem = max(beforeMem, afterMem)

        let finalResult = InferenceResult(
            id: result.id,
            modelId: result.modelId,
            modelName: result.modelName,
            inputTokenCount: result.inputTokenCount,
            outputTokenCount: result.outputTokenCount,
            articleText: result.articleText,
            summary: result.summary,
            latencyMs: result.latencyMs,
            timeToFirstTokenMs: result.timeToFirstTokenMs,
            tokensPerSecond: result.tokensPerSecond,
            peakMemoryMB: peakMem,
            timestamp: result.timestamp,
            didFail: result.didFail,
            errorMessage: result.errorMessage
        )

        await metricsStore.save(finalResult)

        liveTokenCount = finalResult.outputTokenCount
        liveTokensPerSecond = finalResult.tokensPerSecond
        isRunning = false
        statusMessage = finalResult.didFail
            ? "Failed — \(finalResult.errorMessage ?? "unknown error")"
            : "Complete — \(finalResult.outputTokenCount) tokens in \(String(format: "%.1f", finalResult.latencyMs / 1000))s"

        return finalResult
    }

    func loadResults() async -> [InferenceResult] {
        await metricsStore.loadAll()
    }

    func clearResults() async {
        await metricsStore.clearAll()
    }

    func exportCSV() async -> URL {
        await metricsStore.exportCSV()
    }
}
