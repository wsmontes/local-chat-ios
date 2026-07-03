import Foundation

struct InferenceInput {
    let modelId: String
    let articleText: String
    let parameters: InferenceParameters
    let template: EditableTemplate?

    var characterCount: Int { articleText.count }
    var isEmpty: Bool { articleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
