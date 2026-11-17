import SwiftUI
import WidgetKit

/// Spike iOS: เขียน snapshot ทดสอบลง App Group แล้วให้ widget อ่าน
/// ยังไม่มีการรับข้อมูลจริงจาก Mac
@main
struct RxWidgetiOSApp: App {
    var body: some Scene {
        WindowGroup { SpikeScreen() }
    }
}

struct SpikeScreen: View {
    @State private var counter = 0
    @State private var status = ""
    @State private var containerPath = "-"
    @State private var snapshot: UsageSnapshot?

    var body: some View {
        NavigationStack {
            List {
                Section("App Group") {
                    LabeledContent("Group ID", value: SnapshotStore.groupID ?? "(ไม่มี)")
                    Text(containerPath).font(.caption.monospaced()).textSelection(.enabled)
                }
                Section {
                    Button("เขียน snapshot ทดสอบ") { write() }
                    if !status.isEmpty {
                        Text(status).font(.callout).foregroundStyle(.secondary)
                    }
                }
                if let snapshot {
                    Section("ข้อมูลที่อ่านกลับ") {
                        ForEach(snapshot.providers) { ProviderSection(provider: $0) }
                    }
                }
            }
            .navigationTitle("RxWidget · Spike iOS")
        }
        .onAppear(perform: load)
    }

    private func load() {
        do {
            containerPath = try SnapshotStore.containerURL().path
            snapshot = try SnapshotStore.read()
        } catch {
            status = error.description
        }
    }

    private func write() {
        counter += 1
        let now = Date.now
        // ตัวเลขทดสอบ เปลี่ยนทุกครั้งที่กด เพื่อให้เห็นว่า widget อัปเดต
        let used = Double((counter * 17) % 100)
        let sample = UsageSnapshot(generatedAt: now, providers: [
            ProviderSnapshot(
                id: .claudeSubscription, status: .ok, source: "spike-ios", plan: "test",
                windows: [
                    UsageWindow(id: "s", kind: .session, label: 18000.windowLabel, durationSeconds: 18000,
                                usedPercent: used, resetsAt: now.addingTimeInterval(3 * 3600)),
                    UsageWindow(id: "w", kind: .weekly, label: 604800.windowLabel, durationSeconds: 604800,
                                usedPercent: 40, resetsAt: now.addingTimeInterval(3 * 86400)),
                ],
                dataAsOf: now, checkedAt: now),
            ProviderSnapshot(
                id: .codex, status: .stale(reason: "ทดสอบสถานะข้อมูลเก่า"), source: "spike-ios", plan: "test",
                windows: [
                    UsageWindow(id: "s", kind: .session, label: 18000.windowLabel, durationSeconds: 18000,
                                usedPercent: 100 - used, resetsAt: now.addingTimeInterval(3600)),
                ],
                dataAsOf: now, checkedAt: now),
        ])
        do {
            try SnapshotStore.write(sample)
            snapshot = try SnapshotStore.read()
            WidgetCenter.shared.reloadAllTimelines()
            status = "เขียนและอ่านกลับสำเร็จ (#\(counter)) · สั่ง widget reload แล้ว"
        } catch {
            status = "ผิดพลาด: \(error.description)"
        }
    }
}
