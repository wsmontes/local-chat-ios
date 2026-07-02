import Foundation

actor ModelManager {
    private(set) var models: [ModelInfo] = []

    private let fileManager = FileManager.default
    private let modelsDirectoryName = "GGUFModels"

    /// Directory where user-imported models are stored.
    private var modelsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(modelsDirectoryName, isDirectory: true)
    }

    /// Discover all models: bundled + user-imported.
    func discoverModels() -> [ModelInfo] {
        ensureModelsDirectory()
        var discovered: [ModelInfo] = []

        if let bundleURLs = Bundle.main.urls(forResourcesWithExtension: "gguf", subdirectory: nil) {
            for url in bundleURLs {
                if let info = modelInfo(from: url, isBundled: true) {
                    discovered.append(info)
                }
            }
        }

        if let docURLs = try? fileManager.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) {
            for url in docURLs where url.pathExtension == "gguf" {
                if let info = modelInfo(from: url, isBundled: false) {
                    discovered.append(info)
                }
            }
        }

        models = discovered
        return discovered
    }

    /// Import a GGUF file from an external URL.
    func importModel(from sourceURL: URL) throws -> ModelInfo {
        ensureModelsDirectory()

        guard validateGGUFMagic(sourceURL) else {
            throw ModelManagerError.invalidGGUFFile
        }

        let destination = modelsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.copyItem(at: sourceURL, to: destination)

        guard let info = modelInfo(from: destination, isBundled: false) else {
            throw ModelManagerError.failedToCreateModelInfo
        }

        discoverModels()
        return info
    }

    /// Delete a user-imported model. Bundled models cannot be deleted.
    func deleteModel(_ id: String) throws {
        guard let model = models.first(where: { $0.id == id }) else {
            throw ModelManagerError.modelNotFound
        }
        guard !model.isBundled else {
            throw ModelManagerError.cannotDeleteBundledModel
        }
        try fileManager.removeItem(at: model.fileURL)
        discoverModels()
    }

    // MARK: - Private

    private func ensureModelsDirectory() {
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }

    private func modelInfo(from url: URL, isBundled: Bool) -> ModelInfo? {
        let fileName = url.lastPathComponent
        let id = (fileName as NSString).deletingPathExtension
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ?? 0
        return ModelInfo(
            id: id,
            fileName: fileName,
            fileURL: url,
            fileSizeBytes: size,
            isBundled: isBundled
        )
    }

    /// Validate GGUF magic bytes: 0x47 0x47 0x55 0x46 ("GGUF").
    private func validateGGUFMagic(_ url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }

        let data = handle.readData(ofLength: 4)
        let magic: [UInt8] = [0x47, 0x47, 0x55, 0x46]
        return data.count == 4 && data.elementsEqual(magic)
    }
}

enum ModelManagerError: LocalizedError {
    case invalidGGUFFile
    case failedToCreateModelInfo
    case modelNotFound
    case cannotDeleteBundledModel

    var errorDescription: String? {
        switch self {
        case .invalidGGUFFile: return "Invalid GGUF file — magic bytes not found."
        case .failedToCreateModelInfo: return "Failed to read model file metadata."
        case .modelNotFound: return "Model not found."
        case .cannotDeleteBundledModel: return "Bundled models cannot be deleted."
        }
    }
}
