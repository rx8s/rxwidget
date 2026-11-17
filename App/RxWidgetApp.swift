import SwiftUI

@main
struct RxWidgetApp: App {
    @State private var coordinator: UsageCoordinator
    @State private var floating: FloatingPanelController

    var body: some Scene {
        MenuBarExtra("RxWidget", systemImage: "gauge.with.dots.needle.33percent") {
            MenuPanel(coordinator: coordinator, floating: floating)
        }
        .menuBarExtraStyle(.window)
    }

    init() {
        // เริ่มรอบดึงข้อมูลทันทีที่แอปเปิด ไม่ต้องรอผู้ใช้คลิกเมนู
        let c = UsageCoordinator()
        let f = FloatingPanelController(coordinator: c)
        _coordinator = State(initialValue: c)
        _floating = State(initialValue: f)
        c.start()
        // สร้างหน้าต่างหลัง NSApplication พร้อมแล้ว
        Task { @MainActor in f.restore() }
    }
}

struct MenuPanel: View {
    let coordinator: UsageCoordinator
    let floating: FloatingPanelController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let snapshot = coordinator.snapshot {
                ForEach(snapshot.providers) { provider in
                    ProviderSection(provider: provider)
                    if provider.id != snapshot.providers.last?.id { Divider() }
                }
            } else {
                Text(coordinator.isRefreshing ? "กำลังโหลด…" : "ยังไม่มีข้อมูล")
                    .foregroundStyle(.secondary)
            }

            if let error = coordinator.storeError {
                Text(error).font(.caption2).foregroundStyle(.red)
            }

            Divider()
            Toggle("หน้าต่างลอย", isOn: Binding(
                get: { floating.isShown },
                set: { $0 ? floating.show() : floating.hide() }))
                .toggleStyle(.switch)
                .controlSize(.small)

            HStack {
                if let at = coordinator.snapshot?.generatedAt {
                    Text("ตรวจล่าสุด \(at.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await coordinator.refresh() }
                } label: {
                    if coordinator.isRefreshing { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .buttonStyle(.borderless)
                .disabled(coordinator.isRefreshing)
                .help("ดึงข้อมูลใหม่")
                Button("ออก") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 320)
    }
}
