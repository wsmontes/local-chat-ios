import Foundation

struct InferenceInput {
    let modelId: String
    let articleText: String
    let maxTokens: Int = 256
    /// Optional custom template. When nil, uses the default chat format.
    let template: EditableTemplate?

    var characterCount: Int { articleText.count }
    var isEmpty: Bool { articleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Build the final prompt. Uses template if provided, otherwise simple summarization prompt.
    func buildPrompt() -> String {
        if let template {
            return template.assemble(articleText: articleText)
        }
        return """
        Summarize the following article in 2-3 sentences in the same language \
        as the article. Focus on the main topic and key takeaways.

        \(articleText)
        """
    }
}
