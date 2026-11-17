import SwiftUI
import WidgetKit

@main
struct RxWidgetApp: App {
    var body: some Scene {
        MenuBarExtra("RxWidget", systemImage: "gauge.with.dots.needle.33percent") {
            SpikePanel()
        }
        .menuBarExtraStyle(.window)
    }
}

/// หน้าทดสอบ spike: เขียน snapshot ลง App Group แล้วสั่ง widget reload
struct SpikePanel: View {
    @State private var lastSnapshot: SpikeSnapshot?
    @State private var status = ""
    @State private var containerPath = "-"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RxWidget · Spike App Group").font(.headline)

            LabeledContent("Group ID", value: SnapshotStore.groupID ?? "(ไม่มี)")
            LabeledContent("Container") {
                Text(containerPath).font(.caption.monospaced()).textSelection(.enabled)
            }
            if let s = lastSnapshot {
                LabeledContent("ล่าสุด", value: "#\(s.counter) · \(s.writtenAt.formatted(date: .omitted, time: .standard))")
            }
            if !status.isEmpty {
                Text(status).font(.callout).foregroundStyle(.secondary)
            }

            HStack {
                Button("เขียน snapshot") { writeSnapshot() }
                    .keyboardShortcut(.defaultAction)
                Spacer()
                Button("ออก") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 340)
        .onAppear(perform: load)
    }

    private func load() {
        do {
            containerPath = try SnapshotStore.containerURL().path
            lastSnapshot = try SnapshotStore.read()
        } catch {
            status = error.description
        }
    }

    private func writeSnapshot() {
        let next = SpikeSnapshot(
            counter: (lastSnapshot?.counter ?? 0) + 1,
            writtenAt: .now,
            writer: "host"
        )
        do {
            try SnapshotStore.write(next)
            lastSnapshot = try SnapshotStore.read()
            WidgetCenter.shared.reloadAllTimelines()
            status = "เขียนและอ่านกลับสำเร็จ · สั่ง widget reload แล้ว"
        } catch {
            status = "ผิดพลาด: \(error.description)"
        }
    }
}
