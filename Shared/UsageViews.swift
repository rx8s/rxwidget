import SwiftUI

/// view ที่ใช้ร่วมกันระหว่าง menu bar และ widget
/// หมายเหตุ: หน้าตาชั่วคราว จะออกแบบจริงในขั้น UI

extension ProviderStatus {
    var message: String? {
        switch self {
        case .ok: nil
        case .stale(let r): "ข้อมูลเก่า · \(r)"
        case .needsLogin(let r): r
        case .error(let m): m
        case .notConfigured: "ยังไม่ได้ตั้งค่า"
        }
    }

    var isProblem: Bool { self != .ok }
}

extension UsageWindow {
    /// ถ้าเลยเวลารีเซ็ตแล้ว ค่าที่เก็บไว้ไม่ใช่ปัจจุบัน
    func isExpired(at date: Date = .now) -> Bool {
        guard let resetsAt else { return false }
        return resetsAt <= date
    }

    var tint: Color { Theme.levelText(usedPercent) }
}

struct UsageBar: View {
    let window: UsageWindow
    var compact = false

    private var fraction: Double {
        window.isExpired() ? 0 : min(max(window.usedPercent, 0), 100) / 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.label).font(compact ? .caption2 : .caption)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(window.isExpired() ? "รีเซ็ตแล้ว" : "\(Int(window.usedPercent.rounded()))%")
                    .font((compact ? Font.caption2 : .caption).monospacedDigit().weight(.bold))
                    .foregroundStyle(window.isExpired() ? Color.secondary : window.tint)
            }
            GradientBar(fraction: fraction)
                .frame(height: compact ? 5 : 7)
            if !compact, let resetsAt = window.resetsAt, !window.isExpired() {
                Text("รีเซ็ต \(resetsAt, style: .relative)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// แถบ % แบบไล่สี: gradient เต็มความกว้าง แล้ว mask ให้เห็นแค่ส่วนที่ใช้ไป
/// สีที่ปลายแถบจึงบอกระดับได้ทันที (เขียว → แดง)
struct GradientBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(Theme.levelGradient)
                    .mask(alignment: .leading) {
                        Capsule().frame(width: max(geo.size.width * fraction, fraction > 0 ? geo.size.height : 0))
                    }
            }
        }
    }
}

struct ProviderSection: View {
    let provider: ProviderSnapshot
    var compact = false
    var maxWindows = Int.max

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 6) {
            HStack(spacing: 5) {
                Circle().fill(provider.id.accent).frame(width: compact ? 6 : 8, height: compact ? 6 : 8)
                // ชื่อใช้สีตัวอักษรปกติ เพราะพาสเทลบนพื้นสว่างอ่านยาก
                Text(provider.id.displayName).font(compact ? .caption.weight(.semibold) : .headline)
                if let plan = provider.plan {
                    Text(plan).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if provider.status.isProblem {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.caption2)
                }
            }
            ForEach(provider.windows.prefix(maxWindows)) { UsageBar(window: $0, compact: compact) }
            if !compact {
                if let message = provider.status.message {
                    Text(message).font(.caption2).foregroundStyle(.orange)
                }
                if let note = provider.note {
                    Text(note).font(.caption2).foregroundStyle(.secondary)
                }
                if let asOf = provider.dataAsOf {
                    Text("ข้อมูลเมื่อ \(asOf.formatted(date: .omitted, time: .shortened))"
                         + (provider.source.map { " · \($0)" } ?? ""))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            } else if provider.windows.isEmpty, let message = provider.status.message {
                Text(message).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        // แถบสีประจำ provider ด้านซ้าย
        .padding(.leading, compact ? 7 : 9)
        .overlay(alignment: .leading) {
            Capsule().fill(provider.id.accent.gradient).frame(width: 3)
        }
    }
}
