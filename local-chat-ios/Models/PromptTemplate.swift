import Foundation

/// Represents a configurable prompt template with special tokens.
/// `{text}` is replaced with the article/input text.
/// `{system}` is replaced with the system prompt.
struct PromptTemplate: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var systemPrompt: String
    var template: String
    var stopTokens: [String]

    /// Assemble the final prompt by injecting text and system into the template.
    func assemble(articleText: String) -> String {
        template
            .replacingOccurrences(of: "{system}", with: systemPrompt)
            .replacingOccurrences(of: "{text}", with: articleText)
    }

    // MARK: - Presets

    static let llama32Summarize = PromptTemplate(
        id: UUID(),
        name: "Llama 3.2 — Summarize",
        systemPrompt: "You are a helpful assistant. Summarize the given article in 2-3 sentences in the same language as the article. Reply ONLY with the summary.",
        template: """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>

        {system}<|eot_id|><|start_header_id|>user<|end_header_id|>

        {text}<|eot_id|><|start_header_id|>assistant<|end_header_id|>

        """,
        stopTokens: ["<|eot_id|>", "<|end_of_text|>"]
    )

    static let llama32Chat = PromptTemplate(
        id: UUID(),
        name: "Llama 3.2 — Chat",
        systemPrompt: "You are a helpful, respectful and honest assistant.",
        template: """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>

        {system}<|eot_id|><|start_header_id|>user<|end_header_id|>

        {text}<|eot_id|><|start_header_id|>assistant<|end_header_id|>

        """,
        stopTokens: ["<|eot_id|>", "<|end_of_text|>"]
    )

    static let qwen35Summarize = PromptTemplate(
        id: UUID(),
        name: "Qwen 3.5 — Summarize",
        systemPrompt: "You are a helpful assistant. Summarize the given article in 2-3 sentences in the same language as the article. Reply ONLY with the summary.",
        template: """
        <|im_start|>system
        {system}<|im_end|>
        <|im_start|>user
        {text}<|im_end|>
        <|im_start|>assistant

        """,
        stopTokens: ["<|im_end|>", "<|endoftext|>"]
    )

    static let qwen25Summarize = PromptTemplate(
        id: UUID(),
        name: "Qwen 2.5 — Summarize",
        systemPrompt: "You are a helpful assistant. Summarize the given article in 2-3 sentences in the same language as the article. Reply ONLY with the summary.",
        template: """
        <|im_start|>system
        {system}<|im_end|>
        <|im_start|>user
        {text}<|im_end|>
        <|im_start|>assistant

        """,
        stopTokens: ["<|im_end|>", "<|endoftext|>"]
    )

    static let raw = PromptTemplate(
        id: UUID(),
        name: "Raw Text (no template)",
        systemPrompt: "",
        template: "{text}",
        stopTokens: []
    )

    static let presets: [PromptTemplate] = [
        .llama32Summarize,
        .llama32Chat,
        .qwen35Summarize,
        .qwen25Summarize,
        .raw
    ]
}

/// User-editable copy of a template for the current session.
struct EditableTemplate: Equatable {
    var template: PromptTemplate
    var editedSystemPrompt: String
    var editedTemplate: String

    init(from preset: PromptTemplate) {
        self.template = preset
        self.editedSystemPrompt = preset.systemPrompt
        self.editedTemplate = preset.template
    }

    /// Assemble prompt using the edited values.
    func assemble(articleText: String) -> String {
        editedTemplate
            .replacingOccurrences(of: "{system}", with: editedSystemPrompt)
            .replacingOccurrences(of: "{text}", with: articleText)
    }

    var hasChanges: Bool {
        editedSystemPrompt != template.systemPrompt || editedTemplate != template.template
    }
}
