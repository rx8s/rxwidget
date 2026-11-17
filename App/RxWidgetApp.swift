import SwiftUI

@main
struct RxWidgetApp: App {
    @State private var coordinator: UsageCoordinator

    var body: some Scene {
        MenuBarExtra("RxWidget", systemImage: "gauge.with.dots.needle.33percent") {
            MenuPanel(coordinator: coordinator)
        }
        .menuBarExtraStyle(.window)
    }

    init() {
        // เริ่มรอบดึงข้อมูลทันทีที่แอปเปิด ไม่ต้องรอผู้ใช้คลิกเมนู
        let c = UsageCoordinator()
        _coordinator = State(initialValue: c)
        c.start()
    }
}

struct MenuPanel: View {
    let coordinator: UsageCoordinator

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
