import Foundation

struct ModelInfo: Identifiable, Equatable {
    let id: String
    let fileName: String
    let fileURL: URL
    let fileSizeBytes: Int64
    let isBundled: Bool
    var loadStatus: ModelLoadStatus = .available

    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSizeBytes)
    }
}
