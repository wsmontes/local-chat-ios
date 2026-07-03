import SwiftUI

struct RunTestView: View {
    @StateObject private var harness = TestHarness()
    @State private var selectedModel: ModelInfo?
    @State private var models: [ModelInfo] = []
    @State private var lastResult: InferenceResult?
    @State private var showResult = false
    @State private var currentMemoryMB: Double = 0

    // Text inputs
    @State private var articleText = ""
    @State private var systemPrompt = "You are a helpful assistant. Summarize the given article in 2-3 sentences. Reply ONLY with the summary."

    // Parameters
    @State private var temperature: Double = 0.3
    @State private var topK: Double = 40
    @State private var topP: Double = 0.9
    @State private var maxTokens: Double = 256
    @State private var contextSize: Double = 8192
    @State private var showParams = false

    // Template
    @State private var useTemplate = false
    @State private var selectedPreset: PromptTemplate = .llama32Summarize
    @State private var editedTemplate: String = PromptTemplate.llama32Summarize.template
    @State private var showTemplateEditor = false
    @State private var showAssembledPreview = false

    private let modelManager = ModelManager()
    private let memoryMonitor = MemoryMonitor()

    // Focus state for keyboard management
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case article, system, template
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // ── Model & Memory ──
                    modelSection

                    // ── System Prompt ──
                    systemPromptSection

                    // ── Article Input ──
                    articleSection

                    // ── Parameters ──
                    parametersSection

                    // ── Template ──
                    templateSection

                    // ── Run ──
                    runButtonSection

                    if harness.isRunning {
                        liveMetricsSection
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
            .navigationTitle("Sandbox")
            .sheet(isPresented: $showResult) {
                if let result = lastResult {
                    ResultSheetView(result: result)
                }
            }
            .sheet(isPresented: $showAssembledPreview) {
                assembledPromptSheet
            }
            .task {
                models = await modelManager.discoverModels()
                if let mem = await memoryMonitor.currentFootprintMB() {
                    currentMemoryMB = mem
                }
            }
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        VStack(spacing: 8) {
            if models.isEmpty {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundStyle(.secondary)
                    Text("No models. Add GGUF files in the Models tab.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            } else {
                HStack {
                    Text("Model")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Model", selection: $selectedModel) {
                        Text("Select…").tag(nil as ModelInfo?)
                        ForEach(models) { model in
                            Text(model.fileName).tag(model as ModelInfo?)
                        }
                    }
                    .pickerStyle(.menu)
                    Spacer()
                }
                .padding(.horizontal)
            }

            MemoryGaugeView(usedMemoryMB: currentMemoryMB)
                .padding(.horizontal)
        }
    }

    // MARK: - System Prompt

    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("System Prompt")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            TextField("System prompt…", text: $systemPrompt, axis: .vertical)
                .font(.subheadline)
                .focused($focusedField, equals: .system)
                .padding(10)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
        }
    }

    // MARK: - Article Input

    private var articleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Input Text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(articleText.count) chars")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal)

            TextEditor(text: $articleText)
                .font(.body)
                .focused($focusedField, equals: .article)
                .frame(minHeight: 140, maxHeight: 220)
                .padding(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if articleText.isEmpty {
                        Text("Paste or type text here…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal)
        }
    }

    // MARK: - Parameters

    private var parametersSection: some View {
        DisclosureGroup(isExpanded: $showParams) {
            VStack(spacing: 12) {
                ParamSlider(label: "Temperature", value: $temperature, range: 0...2, step: 0.05, format: "%.2f")
                ParamSlider(label: "Top-K", value: $topK, range: 1...200, step: 1, format: "%.0f")
                ParamSlider(label: "Top-P", value: $topP, range: 0...1, step: 0.05, format: "%.2f")
                ParamSlider(label: "Max Output Tokens", value: $maxTokens, range: 16...2048, step: 16, format: "%.0f")
                ParamSlider(label: "Context Size", value: $contextSize, range: 512...131072, step: 512, format: "%.0f")
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("Parameters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !showParams {
                    summaryChip("T:\(String(format: "%.2f", temperature))")
                    summaryChip("K:\(Int(topK))")
                    summaryChip("P:\(String(format: "%.2f", topP))")
                }
            }
        }
        .padding(.horizontal)
    }

    private func summaryChip(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Template

    private var templateSection: some View {
        DisclosureGroup(isExpanded: $showTemplateEditor) {
            VStack(spacing: 10) {
                // Preset picker
                Picker("Preset", selection: $selectedPreset) {
                    ForEach(PromptTemplate.presets) { preset in
                        Text(preset.name).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedPreset) { _, preset in
                    editedTemplate = preset.template
                    systemPrompt = preset.systemPrompt
                }

                // Template editor
                TextEditor(text: $editedTemplate)
                    .font(.system(.caption, design: .monospaced))
                    .focused($focusedField, equals: .template)
                    .frame(minHeight: 80, maxHeight: 140)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )

                // Preview button
                Button {
                    focusedField = nil
                    showAssembledPreview = true
                } label: {
                    Label("Preview assembled prompt", systemImage: "eye")
                        .font(.caption)
                }
            }
            .padding(.top, 4)
        } label: {
            HStack {
                Text("Template")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !showTemplateEditor {
                    summaryChip(selectedPreset.name)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Assembled Preview

    private var assembledPromptSheet: some View {
        NavigationStack {
            ScrollView {
                Text(currentTemplate.assemble(articleText: articleText))
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .textSelection(.enabled)
            }
            .navigationTitle("Assembled Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showAssembledPreview = false }
                }
            }
        }
    }

    // MARK: - Run

    private var runButtonSection: some View {
        Button {
            runTest()
        } label: {
            HStack {
                if harness.isRunning {
                    ProgressView()
                        .tint(.white)
                    Text(harness.statusMessage)
                } else {
                    Image(systemName: "play.fill")
                    Text("Run Inference")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(canRun ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!canRun)
        .padding(.horizontal)
    }

    private var liveMetricsSection: some View {
        HStack(spacing: 24) {
            MetricBadge(label: "Tokens", value: "\(harness.liveTokenCount)")
            MetricBadge(label: "tok/s", value: String(format: "%.1f", harness.liveTokensPerSecond))
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    // MARK: - Actions

    private var canRun: Bool {
        selectedModel != nil && !articleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !harness.isRunning
    }

    private var currentTemplate: EditableTemplate {
        var et = EditableTemplate(from: selectedPreset)
        et.editedSystemPrompt = systemPrompt
        et.editedTemplate = editedTemplate
        return et
    }

    private var currentParams: InferenceParameters {
        InferenceParameters(
            temperature: temperature,
            topK: Int(topK),
            topP: topP,
            contextSize: Int(contextSize),
            maxOutputTokens: Int(maxTokens)
        )
    }

    private func runTest() {
        guard let model = selectedModel else { return }
        focusedField = nil
        let text = articleText
        let template = showTemplateEditor ? currentTemplate : nil
        let params = currentParams
        Task {
            if let mem = await memoryMonitor.currentFootprintMB() {
                currentMemoryMB = mem
            }
            let result = await harness.runTest(model: model, articleText: text, parameters: params, template: template)
            lastResult = result
            showResult = true
            if let mem = await memoryMonitor.currentFootprintMB() {
                currentMemoryMB = mem
            }
        }
    }
}

// MARK: - Parameter Slider

struct ParamSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Slider(value: $value, in: range, step: step)
            Text(String(format: format, value))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
    }
}
