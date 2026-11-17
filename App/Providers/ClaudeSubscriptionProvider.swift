import Foundation

/// Claude subscription ผ่าน token ของ Claude Code
/// - อ่าน token จาก Keychain ด้วย /usr/bin/security (อ่านอย่างเดียว ห้าม refresh เอง)
/// - endpoint ไม่ได้ประกาศเป็นทางการ: ทุกความผิดพลาดต้องกลายเป็นสถานะ ไม่ใช่ crash
struct ClaudeSubscriptionProvider: UsageProvider {
    let id = ProviderID.claudeSubscription

    static let keychainService = "Claude Code-credentials"
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let betaHeader = "oauth-2025-04-20"

    func fetch() async -> ProviderSnapshot {
        let now = Date()
        var snap = ProviderSnapshot(id: id, status: .ok, source: "api", windows: [], checkedAt: now)

        // 1) credential
        let creds: Credentials
        switch await Self.readCredentials() {
        case .success(let c): creds = c
        case .failure(let failure):
            snap.status = failure.status
            return snap
        }
        snap.plan = creds.subscriptionType

        if let exp = DateParsing.epoch(creds.expiresAt), exp <= now {
            snap.status = .stale(reason: "token หมดอายุ — เปิด Claude Code เพื่อต่ออายุ")
            return snap
        }

        // 2) usage
        let result = await HTTP.get(Self.usageURL, headers: [
            "Authorization": "Bearer \(creds.accessToken)",
            "anthropic-beta": Self.betaHeader,
        ])
        switch result {
        case .ok(let data):
            do {
                snap.windows = try Self.parseUsage(data)
                snap.dataAsOf = now
                if snap.windows.isEmpty {
                    snap.status = .error("API ไม่ส่งข้อมูลโควตามา (รูปแบบอาจเปลี่ยน)")
                }
            } catch {
                log.error("claude decode: \(error.localizedDescription, privacy: .public)")
                snap.status = .error("อ่านข้อมูลไม่ได้ (รูปแบบอาจเปลี่ยน)")
            }
        case .status(let code, _) where code == 401 || code == 403:
            snap.status = .stale(reason: "token ใช้ไม่ได้ (HTTP \(code)) — เปิด Claude Code เพื่อต่ออายุ")
        case .status(let code, _):
            snap.status = .error("API ตอบ HTTP \(code)")
        case .failure(let message):
            snap.status = .error("เชื่อมต่อไม่ได้: \(message)")
        }
        return snap
    }

    // MARK: Credentials

    struct Credentials: Sendable {
        let accessToken: String
        let expiresAt: Double?
        let subscriptionType: String?
    }

    private struct KeychainBlob: Decodable {
        struct OAuth: Decodable {
            let accessToken: String?
            let expiresAt: FlexibleNumber?
            let subscriptionType: String?
        }
        let claudeAiOauth: OAuth?
    }

    static func readCredentials() async -> Result<Credentials, ProviderStatusError> {
        let out = await ProcessRunner.run("/usr/bin/security",
                                          ["find-generic-password", "-s", keychainService, "-w"])
        guard out.status == 0 else {
            log.notice("claude keychain: exit \(out.status) \(out.stderr, privacy: .public)")
            return .failure(.init(.needsLogin(reason: "ไม่พบ credential ของ Claude Code — รัน `claude auth login`")))
        }
        guard let blob = try? JSONDecoder().decode(KeychainBlob.self, from: out.stdout),
              let oauth = blob.claudeAiOauth else {
            return .failure(.init(.error("อ่าน credential ของ Claude Code ไม่ได้ (รูปแบบอาจเปลี่ยน)")))
        }
        guard let token = oauth.accessToken, !token.isEmpty else {
            return .failure(.init(.needsLogin(reason: "Claude Code ยังไม่ได้ login (token ว่าง) — รัน `claude auth login`")))
        }
        return .success(Credentials(accessToken: token,
                                    expiresAt: oauth.expiresAt?.value,
                                    subscriptionType: oauth.subscriptionType))
    }

    // MARK: Parsing

    struct UsageResponse: Decodable {
        struct Window: Decodable {
            let utilization: Double?
            let resetsAt: String?
        }
        struct Limit: Decodable {
            struct Scope: Decodable {
                struct Model: Decodable { let displayName: String? }
                let model: Model?
            }
            let kind: String?
            let group: String?
            let percent: Double?
            let severity: String?
            let resetsAt: String?
            let scope: Scope?
            let isActive: Bool?
        }
        let fiveHour: Window?
        let sevenDay: Window?
        let limits: [Limit]?
    }

    /// ใช้ `limits[]` เป็นหลัก ถ้าไม่มีหรือว่างค่อยใช้ `five_hour`/`seven_day`
    static func parseUsage(_ data: Data) throws -> [UsageWindow] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let r = try decoder.decode(UsageResponse.self, from: data)

        let fromLimits: [UsageWindow] = (r.limits ?? []).enumerated().compactMap { index, l in
            guard let percent = l.percent else { return nil }
            let kind: WindowKind = switch l.group ?? "" {
            case "session": .session
            case "weekly": .weekly
            default: .other
            }
            let base = switch kind {
            case .session: 18000.windowLabel
            case .weekly: 604800.windowLabel
            case .other: l.kind ?? "อื่นๆ"
            }
            let model = l.scope?.model?.displayName
            return UsageWindow(
                id: "\(l.kind ?? "limit")-\(model ?? "")-\(index)",
                kind: kind,
                label: model.map { "\(base) · \($0)" } ?? base,
                durationSeconds: kind == .session ? 18000 : kind == .weekly ? 604800 : nil,
                usedPercent: percent,
                resetsAt: DateParsing.iso8601(l.resetsAt),
                severity: l.severity,
                isActive: l.isActive)
        }
        if !fromLimits.isEmpty { return fromLimits }

        var legacy: [UsageWindow] = []
        for (key, window, seconds) in [("five_hour", r.fiveHour, 18000), ("seven_day", r.sevenDay, 604800)] {
            guard let w = window, let used = w.utilization else { continue }
            legacy.append(UsageWindow(
                id: key, kind: .from(durationSeconds: seconds), label: seconds.windowLabel,
                durationSeconds: seconds, usedPercent: used,
                resetsAt: DateParsing.iso8601(w.resetsAt)))
        }
        return legacy
    }
}

/// ห่อ ProviderStatus ให้ใช้กับ Result ได้
struct ProviderStatusError: Error, Sendable {
    let status: ProviderStatus
    init(_ status: ProviderStatus) { self.status = status }
}
