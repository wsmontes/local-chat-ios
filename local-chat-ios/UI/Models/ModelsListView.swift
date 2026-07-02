import SwiftUI
import UniformTypeIdentifiers

struct ModelsListView: View {
    @State private var models: [ModelInfo] = []
    @State private var showFileImporter = false
    @State private var importError: String?
    @State private var showImportError = false

    private let modelManager = ModelManager()

    var body: some View {
        NavigationStack {
            Group {
                if models.isEmpty {
                    ContentUnavailableView(
                        "No Models",
                        systemImage: "cpu",
                        description: Text("Add GGUF model files to get started.\nTap + to import from Files.")
                    )
                } else {
                    List {
                        ForEach(models) { model in
                            modelRow(model)
                        }
                        .onDelete(perform: deleteModels)
                    }
                }
            }
            .navigationTitle("Models")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType(filenameExtension: "gguf") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("Import Error", isPresented: $showImportError) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
            .task {
                models = await modelManager.discoverModels()
            }
            .refreshable {
                models = await modelManager.discoverModels()
            }
        }
    }

    private func modelRow(_ model: ModelInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: model.isBundled ? "shippingbox" : "doc")
                .font(.title2)
                .foregroundStyle(model.isBundled ? .blue : .orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.fileName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(model.fileSizeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.isBundled ? "Bundled" : "Imported")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(model.isBundled ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
                Text(model.loadStatus.displayString)
                    .font(.caption)
                    .foregroundStyle(loadStatusColor(model.loadStatus))
            }
        }
        .padding(.vertical, 2)
    }

    private func loadStatusColor(_ status: ModelLoadStatus) -> Color {
        switch status {
        case .available: return .secondary
        case .loading: return .blue
        case .loaded: return .green
        case .error: return .red
        }
    }

    private func deleteModels(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let model = models[index]
                try? await modelManager.deleteModel(model.id)
            }
            models = await modelManager.discoverModels()
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Lock security-scoped access BEFORE the async Task
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Permission denied — cannot access the selected file."
                showImportError = true
                return
            }
            Task {
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    _ = try await modelManager.importModel(from: url)
                    models = await modelManager.discoverModels()
                } catch {
                    importError = error.localizedDescription
                    showImportError = true
                }
            }
        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }
}
