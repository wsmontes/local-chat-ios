import Foundation
import LocalLLMClient
import LocalLLMClientLlama

actor InferenceEngine {
    private var activeClient: LocalLLMClient?

    /// Run summarization inference with the given input and model.
    func run(input: InferenceInput, modelName: String, modelURL: URL) async throws -> InferenceResult {
        let startTime = Date()
        let prompt = input.buildPrompt()

        let client = try await LocalLLMClient.llama(
            url: modelURL,
            parameter: .init(
                context: 4096,
                temperature: 0.3,
                topK: 40,
                topP: 0.9
            )
        )
        self.activeClient = client

        let llmInput = LLMInput.text(prompt)

        var outputTokens = 0
        var firstToken = true
        var timeToFirstTokenMs: Double = 0
        var summary = ""

        let stream = try await client.textStream(from: llmInput)

        do {
            for try await token in stream {
                if firstToken {
                    timeToFirstTokenMs = Date().timeIntervalSince(startTime) * 1000
                    firstToken = false
                }
                summary += token
                outputTokens += 1
            }
        } catch {
            let latencyMs = Date().timeIntervalSince(startTime) * 1000
            return InferenceResult(
                id: UUID(),
                modelId: input.modelId,
                modelName: modelName,
                inputTokenCount: estimateTokenCount(prompt),
                outputTokenCount: outputTokens,
                articleText: String(input.articleText.prefix(2000)),
                summary: summary.isEmpty ? "Inference failed: \(error.localizedDescription)" : summary,
                latencyMs: latencyMs,
                timeToFirstTokenMs: timeToFirstTokenMs,
                tokensPerSecond: latencyMs > 0 ? Double(outputTokens) / (latencyMs / 1000.0) : 0,
                peakMemoryMB: 0,
                timestamp: Date(),
                didFail: true,
                errorMessage: error.localizedDescription
            )
        }

        let endTime = Date()
        let latencyMs = endTime.timeIntervalSince(startTime) * 1000
        let tokensPerSecond = latencyMs > 0 ? Double(outputTokens) / (latencyMs / 1000.0) : 0

        self.activeClient = nil

        return InferenceResult(
            id: UUID(),
            modelId: input.modelId,
            modelName: modelName,
            inputTokenCount: estimateTokenCount(prompt),
            outputTokenCount: outputTokens,
            articleText: String(input.articleText.prefix(2000)),
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            latencyMs: latencyMs,
            timeToFirstTokenMs: timeToFirstTokenMs,
            tokensPerSecond: tokensPerSecond,
            peakMemoryMB: 0,
            timestamp: Date(),
            didFail: false,
            errorMessage: nil
        )
    }

    func cancel() {
        activeClient = nil
    }

    private func estimateTokenCount(_ text: String) -> Int {
        max(1, text.count / 4)
    }
}
