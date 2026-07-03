import SwiftUI

struct RunTestView: View {
    @StateObject private var harness = TestHarness()
    @State private var articleText = ""
    @State private var selectedModel: ModelInfo?
    @State private var models: [ModelInfo] = []
    @State private var lastResult: InferenceResult?
    @State private var showResult = false
    @State private var currentMemoryMB: Double = 0

    // Template mode
    @State private var useTemplate = false
    @State private var selectedPreset: PromptTemplate = .llama32Summarize
    @State private var editedSystem: String = PromptTemplate.llama32Summarize.systemPrompt
    @State private var editedTemplate: String = PromptTemplate.llama32Summarize.template
    @State private var showAssembledPreview = false

    private let modelManager = ModelManager()
    private let memoryMonitor = MemoryMonitor()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    modelPickerSection

                    MemoryGaugeView(usedMemoryMB: currentMemoryMB)
                        .padding(.horizontal)

                    // Mode toggle
                    modeToggleSection

                    if useTemplate {
                        templateEditorSection
                    }

                    articleInputSection

                    if useTemplate && !articleText.isEmpty {
                        assembledPreviewSection
                    }

                    runButtonSection

                    if harness.isRunning {
                        liveMetricsSection
                    }
                }
                .padding(.vertical)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Run Test")
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

    // MARK: - Mode Toggle

    private var modeToggleSection: some View {
        HStack {
            Text("Prompt Mode")
                .font(.headline)
            Spacer()
            Picker("Mode", selection: $useTemplate) {
                Text("Simple").tag(false)
                Text("Template").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(.horizontal)
    }

    // MARK: - Template Editor

    private var templateEditorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Preset picker
            HStack {
                Text("Preset")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Preset", selection: $selectedPreset) {
                    ForEach(PromptTemplate.presets) { preset in
                        Text(preset.name).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedPreset) { _, preset in
                    editedSystem = preset.systemPrompt
                    editedTemplate = preset.template
                }
            }

            // System prompt
            VStack(alignment: .leading, spacing: 4) {
                Text("System Prompt — `{system}`")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $editedSystem)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 60, maxHeight: 100)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.horizontal)

            // Template structure
            VStack(alignment: .leading, spacing: 4) {
                Text("Template Structure — `{text}` = article, `{system}` = system prompt above")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $editedTemplate)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 100, maxHeight: 160)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Article Input

    private var articleInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(useTemplate ? "Article Text — `{text}`" : "Article Text")
                    .font(.headline)
                Spacer()
                Text("\(articleText.count) chars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal)

            TextEditor(text: $articleText)
                .font(.body)
                .frame(minHeight: 120, maxHeight: 200)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if articleText.isEmpty {
                        Text("Paste article text here…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal)
        }
    }

    // MARK: - Assembled Preview

    private var assembledPreviewSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                showAssembledPreview = true
            } label: {
                HStack {
                    Image(systemName: "eye")
                    Text("Preview assembled prompt")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }

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

    // MARK: - Run Button

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
        et.editedSystemPrompt = editedSystem
        et.editedTemplate = editedTemplate
        return et
    }

    private func runTest() {
        guard let model = selectedModel else { return }
        let text = articleText
        let template = useTemplate ? currentTemplate : nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Task {
            if let mem = await memoryMonitor.currentFootprintMB() {
                currentMemoryMB = mem
            }
            let result = await harness.runTest(model: model, articleText: text, template: template)
            lastResult = result
            showResult = true
            if let mem = await memoryMonitor.currentFootprintMB() {
                currentMemoryMB = mem
            }
        }
    }
}
