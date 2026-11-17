import SwiftUI

/// สีของ rxwidget ใช้ร่วมกันระหว่างเมนู, หน้าต่างลอย และ widget
enum Theme {
    /// ไล่สีแถบ % ตามความยาว: เขียว → เหลือง → ส้ม → แดง
    static let levelGradient = LinearGradient(
        stops: [
            .init(color: .green, location: 0.0),
            .init(color: .yellow, location: 0.6),
            .init(color: .orange, location: 0.8),
            .init(color: .red, location: 1.0),
        ],
        startPoint: .leading, endPoint: .trailing)

    /// พื้นหลังการ์ด: ไล่จากสี Claude ไปสี Codex (ใช้ทับ material แบบโปร่งๆ)
    static let cardGradient = LinearGradient(
        colors: [ProviderID.claudeSubscription.accent, ProviderID.codex.accent],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let cardTintOpacity = 0.22
}

extension ProviderID {
    /// สีประจำ provider (สีกลางๆ ของเราเอง ไม่ใช่สีแบรนด์)
    var accent: Color {
        switch self {
        case .claudeSubscription: Color(red: 0.86, green: 0.47, blue: 0.33) // ส้มอิฐ
        case .codex: Color(red: 0.13, green: 0.66, blue: 0.62)              // เขียวอมฟ้า
        case .claudeAPI: Color(red: 0.72, green: 0.38, blue: 0.55)          // ชมพูม่วง
        case .openAIAPI: Color(red: 0.35, green: 0.48, blue: 0.86)          // น้ำเงิน
        }
    }
}

/// พื้นหลังการ์ดสี: material + gradient โปร่งๆ ใช้ได้ทั้งโหมดสว่างและมืด
struct TintedCardBackground: View {
    var cornerRadius: CGFloat = 14

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(.regularMaterial)
            shape.fill(Theme.cardGradient).opacity(Theme.cardTintOpacity)
            shape.strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        }
    }
}
