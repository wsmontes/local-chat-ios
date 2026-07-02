import Foundation

struct InferenceResult: Codable, Identifiable, Equatable {
    let id: UUID
    let modelId: String
    let modelName: String
    let inputTokenCount: Int
    let outputTokenCount: Int
    let articleText: String
    let summary: String
    let latencyMs: Double
    let timeToFirstTokenMs: Double
    let tokensPerSecond: Double
    let peakMemoryMB: Double
    let timestamp: Date
    let didFail: Bool
    let errorMessage: String?

    var latencyTier: LatencyTier {
        if didFail { return .failed }
        switch latencyMs {
        case ..<2000: return .good
        case 2000..<5000: return .acceptable
        default: return .slow
        }
    }
}

enum LatencyTier: String, Codable {
    case good
    case acceptable
    case slow
    case failed
}
