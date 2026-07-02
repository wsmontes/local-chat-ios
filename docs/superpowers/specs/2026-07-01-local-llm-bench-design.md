# Local LLM Inference Bench — Design Spec

**Date:** 2026-07-01
**Project:** local-chat-ios
**Device:** iPhone 14 Plus (A15 Bionic, 6GB RAM, 16-core Neural Engine)
**Goal:** Prove that an iPhone can run a local LLM for reading, classifying, and summarizing RSS article content with acceptable performance.

---

## Overview

This is a **test-bench app**, not a production chat app. It exists to:

1. Load 2-3 GGUF models of increasing size onto an iPhone 14 Plus
2. Run summarization inference against pasted article text
3. Measure and record: latency, tokens/second, peak memory, output quality
4. Produce data to decide whether on-device LLM is viable for a downstream RSS app

The app uses **llama.cpp** via the **LocalLLMClient** Swift package (iOS 17+) with Metal GPU acceleration.

---

## Models Under Test

Ordered by priority — test the largest that fits comfortably:

| Priority | Model | Format | Disk Size | Est. RAM |
|----------|-------|--------|-----------|----------|
| 1 | Qwen 3.5 0.8B Instruct | Q4_K_M GGUF | ~335 MB | ~500 MB |
| 2 | Gemma 3 1B Instruct | Q4_K_M GGUF | ~300 MB | ~500 MB |
| 3 | Qwen 2.5 0.5B Instruct | Q4_K_M GGUF | ~150 MB | ~300 MB |

Models are bundled in the app or imported via FilePicker. The app needs the `com.apple.developer.kernel.increased-memory-limit` entitlement to exceed iOS's default per-process memory cap.

---

## Architecture

```
┌─────────────────────────────────────────────┐
│                  SwiftUI App                 │
├─────────────────────────────────────────────┤
│  ModelPicker  │  TextInput  │  ResultsView   │
├─────────────────────────────────────────────┤
│              TestHarness                      │
│   (orchestrates: load → infer → measure)     │
├──────────────────┬──────────────────────────┤
│  InferenceEngine │     MetricsStore          │
│  (wraps          │  (latency, tok/s, RAM,    │
│   LocalLLMClient)│   output quality)          │
├──────────────────┴──────────────────────────┤
│              ModelManager                     │
│     (discovery, caching, load/unload)         │
├─────────────────────────────────────────────┤
│  LocalLLMClient (SPM)  │  llama.cpp (C++)    │
│  GGUF model files      │  Metal backend      │
└─────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Does | Does NOT |
|-----------|------|----------|
| **ModelManager** | Lists available models, loads/unloads from memory, reports status | Inference |
| **InferenceEngine** | Takes prompt + loaded model → returns `AsyncStream<String>` of tokens | Performance measurement |
| **TestHarness** | Orchestrates full cycle, collects raw metrics | Data persistence |
| **MetricsStore** | Computes derived metrics (tok/s, p95), persists history as JSON | UI rendering |

### Data Flow (single inference run)

```
1. User selects model → pastes text → taps "Run"

2. TestHarness:
   ├─ Tells ModelManager to load the selected model
   ├─ Records start timestamp + initial memory footprint
   ├─ Sends summarization prompt to InferenceEngine
   ├─ InferenceEngine streams tokens via AsyncStream
   ├─ Per token: counts, measures elapsed time
   ├─ Records end timestamp + final memory footprint
   └─ Delivers result to MetricsStore

3. MetricsStore persists → ResultsView renders
```

---

## Data Model

```swift
struct InferenceInput {
    let modelId: String
    let articleText: String
    let maxTokens: Int = 256
}

struct InferenceResult: Codable, Identifiable {
    let id: UUID
    let modelId: String
    let modelName: String
    let inputTokenCount: Int
    let outputTokenCount: Int
    let articleText: String         // original text (truncated to 2000 chars in storage)
    let summary: String
    let latencyMs: Double           // wall-clock: first prompt token → last output token
    let timeToFirstTokenMs: Double  // time from prompt submission to first token
    let tokensPerSecond: Double
    let peakMemoryMB: Double
    let timestamp: Date
}
```

### Summarization Prompt Template

```
"Summarize the following article in 2-3 sentences in the same language as the article. Focus on the main topic and key takeaways.\n\n[article text]"
```

---

## UI Design (3-Tab SwiftUI)

### Tab 1 — "Run Test"
- **Top:** Model picker showing name, disk size, load status (available/loading/loaded)
- **Center:** `TextEditor` with placeholder "Paste article text here…" and character counter
- **Memory gauge:** Horizontal bar showing current / 6GB available, updated before/after inference
- **"Run Inference" button** — disabled until model is loaded AND text is non-empty
- **During inference:** Progress spinner + live token count + real-time tok/s

### Tab 2 — "Results"
- Scrollable list of past test runs, each row showing:
  - Model name, timestamp, latency, tok/s, peak memory
- Tap a row → detail sheet with:
  - Original text (collapsed), generated summary, full metrics
  - Color badge: green (<2s), yellow (2-5s), red (>5s)
- Toolbar button: "Export CSV" — shares via system share sheet

### Tab 3 — "Models"
- List of GGUF files (bundled + user-imported)
- Each row: file name, disk size, load status
- "+" button to import `.gguf` files via `DocumentPicker`
- Swipe-to-delete for user-imported models (bundled models cannot be deleted)

---

## Performance Targets

These are measurement targets, not hard requirements — the PoC exists to find reality.

| Metric | Target | Notes |
|--------|--------|-------|
| Time to first token | < 500ms | Model load time excluded |
| Tokens/second | > 15 tok/s | Acceptable for 50-100 token summaries |
| Total latency | < 5s | For a ~2000 word article → 2-3 sentence summary |
| Peak memory | < 2 GB | Leaves 4GB for system + other apps |
| Output quality | Subjective | Does the summary capture the article's key point? |

---

## Error Handling

| Failure | Handling |
|---------|----------|
| Model fails to load (OOM) | Show alert with "Try a smaller model", log to MetricsStore |
| Inference timeout (>30s) | Cancel, record as failed test with timeout flag |
| Empty input text | Button disabled — prevented at UI level |
| Model file corrupted | ModelManager validates GGUF magic bytes on import; shows error |
| App backgrounded during inference | Cancel inference, allow resume on foreground |

---

## Testing Strategy

- **Model validation:** Each GGUF passes basic metadata check (magic bytes, vocab size) on import
- **Inference smoke test:** Bundled test article of 500 words → must produce non-empty summary
- **Memory monitoring:** `phys_footprint` via `task_info` before/after each run
- **Manual quality check:** Human reviews 5 summaries per model against source articles

---

## Out of Scope

- Chat/conversational UI (this is a test bench, not a chatbot)
- Multi-model comparison in a single run
- Background inference while app is closed
- RAG, embeddings, or vector search
- Integration with the RSS app (that comes after validation)
- iOS 26 / Apple Foundation Models (separate investigation)
- Classification-specific prompt testing (uses same engine, different prompt — can be added as secondary test case later)

---

## Dependencies

- **LocalLLMClient** (SPM, v0.5.0+) — Swift wrapper over llama.cpp
- **llama.cpp** — bundled via LocalLLMClient, Metal backend
- **GGUF models** — sourced from Hugging Face, bundled or imported
- Minimum deployment target: **iOS 17.0**
- Entitlement: `com.apple.developer.kernel.increased-memory-limit`
