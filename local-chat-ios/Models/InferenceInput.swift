import Foundation

struct InferenceInput {
    let modelId: String
    let articleText: String
    let maxTokens: Int = 256

    var characterCount: Int { articleText.count }
    var isEmpty: Bool { articleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func buildPrompt() -> String {
        """
        Summarize the following article in 2-3 sentences in the same language \
        as the article. Focus on the main topic and key takeaways.

        \(articleText)
        """
    }
}
