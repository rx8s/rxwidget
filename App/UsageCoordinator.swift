import Foundation
import Observation
import WidgetKit

/// ดึงข้อมูลทุก provider เป็นรอบ แล้วเขียน snapshot ลง App Group ให้ widget
@MainActor
@Observable
final class UsageCoordinator {
    static let refreshInterval: Duration = .seconds(5 * 60)

    private(set) var snapshot: UsageSnapshot?
    private(set) var isRefreshing = false
    private(set) var storeError: String?

    private let providers: [any UsageProvider] = [
        ClaudeSubscriptionProvider(),
        CodexProvider(),
    ]
    private var loopTask: Task<Void, Never>?

    init() {
        snapshot = try? SnapshotStore.read()
    }

    func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let fresh = await withTaskGroup(of: ProviderSnapshot.self) { group in
            for provider in providers {
                group.addTask { await provider.fetch() }
            }
            var all: [ProviderSnapshot] = []
            for await s in group { all.append(s) }
            return all
        }

        let previous = snapshot
        let merged = providers.compactMap { provider -> ProviderSnapshot? in
            guard let new = fresh.first(where: { $0.id == provider.id }) else { return nil }
            return Self.merge(new, previous: previous?.provider(provider.id))
        }
        let next = UsageSnapshot(generatedAt: .now, providers: merged)
        snapshot = next

        do {
            try SnapshotStore.write(next)
            storeError = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            storeError = error.description
        }
    }

    /// ถ้ารอบนี้ไม่ได้ข้อมูลใหม่ ให้คงค่าเดิมไว้แสดง พร้อมสถานะที่บอกว่าเป็นข้อมูลเก่า
    static func merge(_ new: ProviderSnapshot, previous: ProviderSnapshot?) -> ProviderSnapshot {
        guard new.windows.isEmpty, let previous, !previous.windows.isEmpty else { return new }
        var out = new
        out.windows = previous.windows
        out.dataAsOf = previous.dataAsOf
        out.plan = new.plan ?? previous.plan
        out.source = previous.source
        if case .error(let message) = new.status {
            out.status = .stale(reason: message)
        }
        return out
    }
}
