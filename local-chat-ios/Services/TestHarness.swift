import Foundation

@MainActor
final class TestHarness: ObservableObject {
    @Published var isRunning = false
    @Published var liveTokenCount = 0
    @Published var liveTokensPerSecond = 0.0
    @Published var statusMessage = ""

    private let memoryMonitor = MemoryMonitor()
    private let inferenceEngine = InferenceEngine()
    private let metricsStore = MetricsStore()

    /// Run a complete test: measure memory, run inference, record results.
    func runTest(model: ModelInfo, articleText: String) async -> InferenceResult {
        isRunning = true
        statusMessage = "Starting inference..."
        liveTokenCount = 0
        liveTokensPerSecond = 0

        let input = InferenceInput(modelId: model.id, articleText: articleText)

        let beforeMem = await memoryMonitor.currentFootprintMB() ?? 0
        let startTime = Date()

        let result: InferenceResult
        do {
            result = try await inferenceEngine.run(
                input: input,
                modelName: model.fileName,
                modelURL: model.fileURL
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
