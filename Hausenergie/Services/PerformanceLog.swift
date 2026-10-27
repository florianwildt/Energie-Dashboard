import Foundation
import UIKit
import QuartzCore
import os

// Bounded, local diagnostics. No sensor readings, URLs, keys or vehicle IDs.
final class PerformanceLog: @unchecked Sendable {
    static let shared = PerformanceLog()
    private static let osLog = OSLog(subsystem: "de.wildt.Hausenergie", category: "Performance")
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "de.wildt.hausenergie.performance", qos: .utility)
    private var enabled: Bool
    private var active = false
    private var entries: [Entry] = []
    private var counters: [String: Int] = [:]
    private var timer: DispatchSourceTimer?
    private var probeStarted: TimeInterval?
    private var frames = 0
    private var sampleStarted = ProcessInfo.processInfo.systemUptime
    private var lastCPU = 0.0
    private var sampler: FrameSampler?
    private let fileURL: URL

    struct Span {
        let name: StaticString
        let start: TimeInterval
        let id: OSSignpostID
        let enabled: Bool
    }

    private struct Entry: Codable {
        let timestamp: Date
        let name: String
        let milliseconds: Double?
        let detail: String?
        let metrics: [String: Double]?
    }

    private init() {
        enabled = UserDefaults.standard.object(forKey: "energy.performanceLogging") as? Bool ?? true
        fileURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("hausenergie-performance.json")
        // Carry the last bounded trace across restarts after a freeze.
        if let data = try? Data(contentsOf: fileURL),
           let previous = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = Array(previous.suffix(600))
        }
    }

    @MainActor func setActive(_ value: Bool) {
        let shouldRun = lock.withLock { active = value; return value && enabled }
        if shouldRun {
            if sampler == nil { sampler = FrameSampler(owner: self) }
            sampler?.start()
            startTimer()
            event("app.active", detail: "animation-cycle=12pt; build=2")
        } else {
            sampler?.stop()
            lock.withLock {
                timer?.cancel()
                timer = nil
                probeStarted = nil
                frames = 0
            }
            event("app.inactive")
            queue.async { self.writeTrace() }
        }
    }

    @MainActor func setEnabled(_ value: Bool) {
        lock.withLock { enabled = value }
        UserDefaults.standard.set(value, forKey: "energy.performanceLogging")
        setActive(lock.withLock { active })
    }

    func begin(_ name: StaticString) -> Span {
        let isEnabled = lock.withLock { enabled }
        let id = OSSignpostID(log: Self.osLog)
        if isEnabled { os_signpost(.begin, log: Self.osLog, name: name, signpostID: id) }
        return Span(name: name, start: ProcessInfo.processInfo.systemUptime, id: id, enabled: isEnabled)
    }

    func end(_ span: Span) {
        guard span.enabled else { return }
        let duration = (ProcessInfo.processInfo.systemUptime - span.start) * 1000
        os_signpost(.end, log: Self.osLog, name: span.name, signpostID: span.id, "%.2f ms", duration)
        append(Entry(timestamp: .now, name: String(describing: span.name), milliseconds: duration, detail: nil, metrics: nil))
    }

    func count(_ name: String) {
        lock.withLock {
            guard enabled && active else { return }
            counters[name, default: 0] += 1
        }
    }

    func event(_ name: String, detail: String? = nil) {
        guard lock.withLock({ enabled }) else { return }
        append(Entry(timestamp: .now, name: name, milliseconds: nil, detail: detail, metrics: nil))
    }

    fileprivate func frame() {
        lock.withLock { frames += 1 }
    }

    private func startTimer() {
        lock.withLock {
            guard timer == nil else { return }
            sampleStarted = ProcessInfo.processInfo.systemUptime
            frames = 0
            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now() + 2, repeating: 2, leeway: .milliseconds(150))
            source.setEventHandler { [weak self] in self?.sample() }
            timer = source
            source.resume()
        }
    }

    private func sample() {
        let now = ProcessInfo.processInfo.systemUptime
        let sampled = lock.withLock { () -> (Double, [String: Int], Double?, Bool, Double) in
            let elapsed = max(0.001, now - sampleStarted)
            let rate = Double(frames) / elapsed
            let counts = counters
            frames = 0
            counters.removeAll(keepingCapacity: true)
            sampleStarted = now
            let previousProbe = probeStarted
            let newProbe = previousProbe == nil
            if newProbe { probeStarted = now }
            return (rate, counts, previousProbe, newProbe, elapsed)
        }
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let cpu = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        var metrics: [String: Double] = [
            "mainCallbackHz": sampled.0,
            "peakMemoryMB": Double(usage.ru_maxrss) / 1_048_576,
            "thermalState": Double(ProcessInfo.processInfo.thermalState.rawValue)
        ]
        if lastCPU > 0 { metrics["cpuCorePercent"] = max(0, cpu - lastCPU) / sampled.4 * 100 }
        lastCPU = cpu
        for (key, value) in sampled.1 { metrics[key] = Double(value) }
        if let pending = sampled.2 { metrics["mainProbePendingMS"] = (now - pending) * 1000 }
        store(Entry(timestamp: .now, name: "runtime.sample", milliseconds: nil, detail: nil, metrics: metrics))
        if sampled.3 {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let delay = (ProcessInfo.processInfo.systemUptime - now) * 1000
                self.lock.withLock { self.probeStarted = nil }
                if delay >= 150 {
                    self.append(Entry(timestamp: .now, name: "ui.stall", milliseconds: delay, detail: "main-queue-delay", metrics: nil))
                }
            }
        }
        // Runs on the utility queue, even while the main thread is blocked.
        writeTrace()
    }

    private func append(_ entry: Entry) {
        queue.async { self.store(entry) }
    }

    private func store(_ entry: Entry) {
        entries.append(entry)
        if entries.count > 1000 { entries.removeFirst(entries.count - 1000) }
        os_log("%{public}@ %{public}@", log: Self.osLog, type: .info, entry.name, entry.milliseconds.map { String(format: "%.2f ms", $0) } ?? entry.detail ?? "")
    }

    private func writeTrace() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func export() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601
                    let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Hausenergie-Performance.json")
                    try encoder.encode(self.entries).write(to: destination, options: .atomic)
                    continuation.resume(returning: destination)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}

@MainActor private final class FrameSampler: NSObject {
    private weak var owner: PerformanceLog?
    private var link: CADisplayLink?
    init(owner: PerformanceLog) { self.owner = owner }
    func start() {
        guard link == nil else { return }
        let displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        displayLink.add(to: .main, forMode: .common)
        link = displayLink
    }
    func stop() { link?.invalidate(); link = nil }
    @objc private func tick() { owner?.frame() }
}
