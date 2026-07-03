import Foundation
import os
import LocalLLMClient
import LocalLLMClientLlama

final class InferenceEngine: @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: State())

    private struct State {
        var activeClient: LlamaClient?
        var isCancelled = false
    }

    struct Progress: Sendable {
        let tokenCount: Int
        let tokensPerSecond: Double
        let phase: Phase
    }

    enum Phase: Sendable {
        case loading
        case generating
        case done
    }

    func run(
        input: InferenceInput,
        modelName: String,
        modelURL: URL,
        onProgress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> InferenceResult {
        let prompt = input.buildPrompt()
        let maxOutputTokens = 256

        return try await Task.detached(priority: .userInitiated) { [self] in
            let startTime = Date()

            onProgress?(Progress(tokenCount: 0, tokensPerSecond: 0, phase: .loading))

            let client = try await LocalLLMClient.llama(
                url: modelURL,
                parameter: .init(
                    context: 100_000,
                    temperature: 0.3,
                    topK: 40,
                    topP: 0.9
                )
            )

            let cancelled: Bool = state.withLock { $0.isCancelled }
            if cancelled { throw CancellationError() }

            state.withLock { $0.activeClient = client }

            // If a custom template is used, send as plain (template already has special tokens).
            // Otherwise, use chat format so the model knows when to stop.
            let llmInput: LLMInput
            if input.template != nil {
                llmInput = LLMInput.plain(prompt)
            } else {
                llmInput = LLMInput.chat([
                    .system("You are a helpful assistant. Summarize the given article in 2-3 sentences. Reply ONLY with the summary, nothing else."),
                    .user(prompt)
                ])
            }

            var outputTokens = 0
            var firstToken = true
            var timeToFirstTokenMs: Double = 0
            var summary = ""

            let generator = try client.textStream(from: llmInput)

            onProgress?(Progress(tokenCount: 0, tokensPerSecond: 0, phase: .generating))

            var lastProgressTime = Date()
            var stoppedEarly = false

            do {
                for try await token in generator {
                    if firstToken {
                        timeToFirstTokenMs = Date().timeIntervalSince(startTime) * 1000
                        firstToken = false
                    }
                    summary += token
                    outputTokens += 1

                    // Hard cap: stop at maxOutputTokens
                    if outputTokens >= maxOutputTokens {
                        stoppedEarly = true
                        break
                    }

                    // Throttle progress to every 100ms
                    let now = Date()
                    if now.timeIntervalSince(lastProgressTime) > 0.1 {
                        let elapsed = now.timeIntervalSince(startTime)
                        let tps = elapsed > 0 ? Double(outputTokens) / elapsed : 0
                        onProgress?(Progress(tokenCount: outputTokens, tokensPerSecond: tps, phase: .generating))
                        lastProgressTime = now
                    }

                    // Check cancellation
                    let c: Bool = state.withLock { $0.isCancelled }
                    if c { break }
                }
            } catch {
                state.withLock { $0.activeClient = nil }
                let latencyMs = Date().timeIntervalSince(startTime) * 1000
                return InferenceResult(
                    id: UUID(), modelId: input.modelId, modelName: modelName,
                    inputTokenCount: estimateTokenCount(prompt),
                    outputTokenCount: outputTokens,
                    articleText: String(input.articleText.prefix(2000)),
                    summary: summary.isEmpty ? "Inference failed: \(error.localizedDescription)" : summary,
                    latencyMs: latencyMs, timeToFirstTokenMs: timeToFirstTokenMs,
                    tokensPerSecond: latencyMs > 0 ? Double(outputTokens) / (latencyMs / 1000.0) : 0,
                    peakMemoryMB: 0, timestamp: Date(), didFail: true,
                    errorMessage: error.localizedDescription
                )
            }

            state.withLock { $0.activeClient = nil }

            let endTime = Date()
            let latencyMs = endTime.timeIntervalSince(startTime) * 1000
            let tokensPerSecond = latencyMs > 0 ? Double(outputTokens) / (latencyMs / 1000.0) : 0

            onProgress?(Progress(tokenCount: outputTokens, tokensPerSecond: tokensPerSecond, phase: .done))

            return InferenceResult(
                id: UUID(), modelId: input.modelId, modelName: modelName,
                inputTokenCount: estimateTokenCount(prompt),
                outputTokenCount: outputTokens,
                articleText: String(input.articleText.prefix(2000)),
                summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                latencyMs: latencyMs, timeToFirstTokenMs: timeToFirstTokenMs,
                tokensPerSecond: tokensPerSecond, peakMemoryMB: 0,
                timestamp: Date(), didFail: false, errorMessage: nil
            )
        }.value
    }

    func cancel() {
        state.withLock { $0.isCancelled = true }
    }

    private func estimateTokenCount(_ text: String) -> Int {
        max(1, text.count / 4)
    }
}
