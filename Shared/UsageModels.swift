import Foundation

/// แหล่งข้อมูลที่ rxwidget รู้จัก
enum ProviderID: String, Codable, Sendable, CaseIterable {
    case claudeSubscription
    case codex
    case claudeAPI
    case openAIAPI

    var displayName: String {
        switch self {
        case .claudeSubscription: "Claude"
        case .codex: "Codex"
        case .claudeAPI: "Claude API"
        case .openAIAPI: "OpenAI API"
        }
    }
}

/// ประเภทช่วงเวลาของโควตา แยกตามความยาว window (ไม่ยึดชื่อ slot ของ provider)
enum WindowKind: String, Codable, Sendable {
    case session   // ~5 ชั่วโมง
    case weekly    // ~7 วัน
    case other

    static func from(durationSeconds: Int) -> WindowKind {
        switch durationSeconds {
        case ...(6 * 3600): .session
        case (6 * 86400)...(8 * 86400): .weekly
        default: .other
        }
    }
}

struct UsageWindow: Codable, Sendable, Equatable, Identifiable {
    var id: String
    var kind: WindowKind
    var label: String
    var durationSeconds: Int?
    /// 0–100
    var usedPercent: Double
    var resetsAt: Date?
    /// ค่าจาก provider ถ้ามี เช่น "normal"
    var severity: String?
    var isActive: Bool?
}

enum ProviderStatus: Codable, Sendable, Equatable {
    case ok
    /// ข้อมูลที่แสดงเป็นของเก่า (เช่น token หมดอายุ) — windows คือค่าล่าสุดที่เคยได้
    case stale(reason: String)
    /// ต้อง login ที่ต้นทางก่อน (เช่น Claude Code)
    case needsLogin(reason: String)
    case error(String)
    case notConfigured
}

struct ProviderSnapshot: Codable, Sendable, Equatable, Identifiable {
    var id: ProviderID
    var status: ProviderStatus
    /// แหล่งที่ได้ข้อมูลจริง เช่น "api", "rollout"
    var source: String?
    /// ข้อความเสริม เช่น "API ใช้ไม่ได้ ใช้ข้อมูลจาก log แทน"
    var note: String?
    var plan: String?
    var windows: [UsageWindow]
    /// เวลาของข้อมูล usage จริง (ไม่ใช่เวลาที่ตรวจ)
    var dataAsOf: Date?
    /// เวลาที่ host ตรวจล่าสุด
    var checkedAt: Date
}

struct UsageSnapshot: Codable, Sendable, Equatable {
    var version: Int = 1
    var generatedAt: Date
    var providers: [ProviderSnapshot]

    func provider(_ id: ProviderID) -> ProviderSnapshot? {
        providers.first { $0.id == id }
    }
}

extension Int {
    /// 18000 → "5 ชั่วโมง", 604800 → "7 วัน"
    var windowLabel: String {
        if self % 86400 == 0 { return "\(self / 86400) วัน" }
        if self % 3600 == 0 { return "\(self / 3600) ชั่วโมง" }
        return "\(self / 60) นาที"
    }
}
