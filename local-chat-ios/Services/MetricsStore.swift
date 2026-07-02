import Foundation

actor MetricsStore {
    private let fileManager = FileManager.default
    private let fileName = "inference_results.json"

    private var storageURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    /// Persist a single result by appending to the existing array.
    func save(_ result: InferenceResult) {
        var existing = loadAll()
        existing.append(result)
        writeAll(existing)
    }

    /// Load all persisted results, sorted by most recent first.
    func loadAll() -> [InferenceResult] {
        guard fileManager.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let results = try? JSONDecoder().decode([InferenceResult].self, from: data)
        else {
            return []
        }
        return results.sorted { $0.timestamp > $1.timestamp }
    }

    /// Delete all stored results.
    func clearAll() {
        try? fileManager.removeItem(at: storageURL)
    }

    /// Export results as CSV, returning the file URL for the share sheet.
    func exportCSV() -> URL {
        let csvLines = buildCSVLines()
        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent("llm_bench_results_\(DateFormatter.iso8601.string(from: Date())).csv")

        let csvContent = csvLines.joined(separator: "\n")
        try? csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    // MARK: - Private

    private func writeAll(_ results: [InferenceResult]) {
        guard let data = try? JSONEncoder().encode(results) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func buildCSVLines() -> [String] {
        guard fileManager.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let results = try? JSONDecoder().decode([InferenceResult].self, from: data)
        else {
            return ["timestamp,model_name,model_id,input_tokens,output_tokens,latency_ms,ttft_ms,tokens_per_sec,peak_memory_mb,did_fail,summary"]
        }

        var lines = ["timestamp,model_name,model_id,input_tokens,output_tokens,latency_ms,ttft_ms,tokens_per_sec,peak_memory_mb,did_fail,summary"]
        for r in results.sorted(by: { $0.timestamp > $1.timestamp }) {
            let escapedSummary = "\"\(r.summary.replacingOccurrences(of: "\"", with: "\"\""))\""
            lines.append([
                DateFormatter.iso8601.string(from: r.timestamp),
                r.modelName,
                r.modelId,
                String(r.inputTokenCount),
                String(r.outputTokenCount),
                String(format: "%.0f", r.latencyMs),
                String(format: "%.0f", r.timeToFirstTokenMs),
                String(format: "%.1f", r.tokensPerSecond),
                String(format: "%.1f", r.peakMemoryMB),
                r.didFail ? "true" : "false",
                escapedSummary
            ].joined(separator: ","))
        }
        return lines
    }
}

private extension DateFormatter {
    static let iso8601: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
