import AppKit
import Observation
import SwiftUI

/// หน้าต่างลอยเหนือทุกแอป แสดงโควตาชุดเดียวกับเมนู
/// - ไม่มีกรอบ, ไม่แย่ง focus, อยู่ทุก Space และทับแอปเต็มจอได้
/// - ลากย้ายได้ จำตำแหน่งและสถานะเปิด/ปิดไว้
@MainActor
@Observable
final class FloatingPanelController {
    private static let visibleKey = "floatingPanelVisible"
    private static let frameName = "RxWidgetFloatingPanel"

    private(set) var isShown = false
    @ObservationIgnored private var panel: NSPanel?
    private let coordinator: UsageCoordinator

    init(coordinator: UsageCoordinator) {
        self.coordinator = coordinator
    }

    /// เรียกตอนแอปเปิด: แสดงตามสถานะครั้งก่อน (ครั้งแรกแสดงเลย)
    func restore() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.visibleKey) == nil || defaults.bool(forKey: Self.visibleKey) {
            show()
        }
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.orderFrontRegardless()
        isShown = true
        UserDefaults.standard.set(true, forKey: Self.visibleKey)
    }

    func hide() {
        panel?.orderOut(nil)
        isShown = false
        UserDefaults.standard.set(false, forKey: Self.visibleKey)
    }

    func toggle() {
        isShown ? hide() : show()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let host = NSHostingController(rootView: FloatingUsageView(
            coordinator: coordinator,
            onClose: { [weak self] in self?.hide() }))
        // ให้ขนาดหน้าต่างตามเนื้อหา SwiftUI
        host.sizingOptions = [.preferredContentSize]
        panel.contentViewController = host

        if !panel.setFrameUsingName(Self.frameName) {
            // ครั้งแรก: มุมขวาบนของจอหลัก ใต้ menu bar
            if let screen = NSScreen.main?.visibleFrame {
                let size = panel.frame.size
                panel.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 16,
                                             y: screen.maxY - size.height - 16))
            }
        }
        panel.setFrameAutosaveName(Self.frameName)
        return panel
    }
}

/// เนื้อหาในหน้าต่างลอย — ใช้ ProviderSection แบบ compact ชุดเดียวกับ widget
struct FloatingUsageView: View {
    let coordinator: UsageCoordinator
    let onClose: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let snapshot = coordinator.snapshot {
                ForEach(snapshot.providers) { ProviderSection(provider: $0, compact: true, maxWindows: 3) }
            } else {
                Text(coordinator.isRefreshing ? "กำลังโหลด…" : "ยังไม่มีข้อมูล")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                if let at = coordinator.snapshot?.generatedAt {
                    Text("ตรวจ \(at.formatted(date: .omitted, time: .shortened))")
                }
                Spacer()
                if hovering {
                    Button {
                        Task { await coordinator.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(coordinator.isRefreshing)
                    .help("ดึงข้อมูลใหม่")
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .help("ซ่อนหน้าต่างลอย (เปิดใหม่ได้จากเมนู)")
                }
            }
            .buttonStyle(.borderless)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 220)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .gesture(WindowDragGesture())
        .onHover { hovering = $0 }
    }
}
