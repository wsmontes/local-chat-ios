import SwiftUI

struct ResultsListView: View {
    @StateObject private var harness = TestHarness()
    @State private var results: [InferenceResult] = []
    @State private var selectedResult: InferenceResult?

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("Run inference tests to see results here.")
                    )
                } else {
                    List {
                        ForEach(results) { result in
                            resultRow(result)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedResult = result
                                }
                        }
                    }
                }
            }
            .navigationTitle("Results")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !results.isEmpty {
                        Button {
                            exportCSV()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !results.isEmpty {
                        Button("Clear All", role: .destructive) {
                            Task {
                                await harness.clearResults()
                                results = []
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedResult) { result in
                ResultDetailView(result: result)
            }
            .task {
                results = await harness.loadResults()
            }
            .refreshable {
                results = await harness.loadResults()
            }
        }
    }

    private func resultRow(_ result: InferenceResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(result.modelName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                LatencyBadge(tier: result.latencyTier)
            }
            HStack(spacing: 12) {
                Label("\(String(format: "%.0f", result.latencyMs))ms", systemImage: "clock")
                Label("\(String(format: "%.1f", result.tokensPerSecond)) tok/s", systemImage: "bolt")
                Label("\(String(format: "%.0f", result.peakMemoryMB))MB", systemImage: "memorychip")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(result.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(result.timestamp, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func exportCSV() {
        Task {
            let url = await harness.exportCSV()
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first,
               let root = window.rootViewController {
                root.present(activityVC, animated: true)
            }
        }
    }
}
