import SwiftUI

/// สีของ rxwidget (โทนพาสเทล) ใช้ร่วมกันระหว่างเมนู, หน้าต่างลอย และ widget
enum Theme {
    // พาสเทลหลัก
    static let mint = Color(red: 0.66, green: 0.89, blue: 0.78)
    static let butter = Color(red: 0.99, green: 0.91, blue: 0.62)
    static let peach = Color(red: 1.00, green: 0.78, blue: 0.64)
    static let coral = Color(red: 0.98, green: 0.62, blue: 0.66)
    static let lavender = Color(red: 0.78, green: 0.74, blue: 0.96)
    static let sky = Color(red: 0.68, green: 0.83, blue: 0.98)

    /// ไล่สีแถบ % ตามความยาว: มิ้นต์ → เหลืองนม → พีช → ชมพูคอรัล
    static let levelGradient = LinearGradient(
        stops: [
            .init(color: mint, location: 0.0),
            .init(color: butter, location: 0.6),
            .init(color: peach, location: 0.8),
            .init(color: coral, location: 1.0),
        ],
        startPoint: .leading, endPoint: .trailing)

    /// สีตัวเลข % — เข้มกว่าพาสเทลเพื่อให้อ่านออกบนพื้นสว่าง แต่ยังอยู่โทนเดียวกัน
    static func levelText(_ percent: Double) -> Color {
        switch percent {
        case ..<70: Color(red: 0.24, green: 0.62, blue: 0.47)   // เขียวเสจ
        case ..<90: Color(red: 0.85, green: 0.52, blue: 0.22)   // ส้มแอปริคอต
        default: Color(red: 0.86, green: 0.33, blue: 0.40)      // ชมพูเข้ม
        }
    }

    /// พื้นหลังการ์ด: ไล่จากพีชไปลาเวนเดอร์ไปฟ้า (ใช้ทับ material แบบโปร่งๆ)
    static let cardGradient = LinearGradient(
        colors: [peach, lavender, sky],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let cardTintOpacity = 0.35
}

extension ProviderID {
    /// สีประจำ provider โทนพาสเทล (สีของเราเอง ไม่ใช่สีแบรนด์)
    var accent: Color {
        switch self {
        case .claudeSubscription: Theme.peach
        case .codex: Theme.mint
        case .claudeAPI: Theme.lavender
        case .openAIAPI: Theme.sky
        }
    }
}

/// พื้นหลังการ์ดสี: material + gradient พาสเทล ใช้ได้ทั้งโหมดสว่างและมืด
struct TintedCardBackground: View {
    var cornerRadius: CGFloat = 14

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(.regularMaterial)
            shape.fill(Theme.cardGradient).opacity(Theme.cardTintOpacity)
            shape.strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
        }
    }
}
