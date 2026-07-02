import Foundation

actor MemoryMonitor {
    /// Returns current physical memory footprint in bytes, or nil if unavailable.
    func currentFootprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return info.phys_footprint
    }

    /// Returns current physical memory footprint in megabytes.
    func currentFootprintMB() -> Double? {
        guard let bytes = currentFootprint() else { return nil }
        return Double(bytes) / (1024.0 * 1024.0)
    }

    /// Snapshots memory before and after an async operation, returning the delta.
    func measureDelta<T>(during operation: () async throws -> T) async rethrows -> (beforeMB: Double, afterMB: Double, peakDeltaMB: Double) {
        let before = currentFootprintMB() ?? 0
        _ = try await operation()
        let after = currentFootprintMB() ?? 0
        return (before, after, after - before)
    }
}
