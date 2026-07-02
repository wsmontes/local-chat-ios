import Foundation

enum ModelLoadStatus: Equatable {
    case available
    case loading(progress: Double)
    case loaded
    case error(String)

    var displayString: String {
        switch self {
        case .available: return "Available"
        case .loading(let p): return "Loading \(Int(p * 100))%"
        case .loaded: return "Loaded"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
