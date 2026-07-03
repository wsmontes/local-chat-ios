import Foundation

/// All inference parameters exposed for sandbox experimentation.
struct InferenceParameters: Codable, Equatable {
    var temperature: Double = 0.3
    var topK: Int = 40
    var topP: Double = 0.9
    var contextSize: Int = 100_000
    var maxOutputTokens: Int = 256

    static let `default` = InferenceParameters()
}
