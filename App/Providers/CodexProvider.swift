import Foundation

/// Codex (ChatGPT plan)
/// 1) GET chatgpt.com/backend-api/wham/usage ด้วย token จาก ~/.codex/auth.json
/// 2) ถ้าไม่ได้ → อ่าน event `token_count` ล่าสุดจาก ~/.codex/sessions/**/rollout-*.jsonl
/// แยกช่วงเวลาตามความยาว window ไม่ยึด slot primary/secondary
struct CodexProvider: UsageProvider {
    let id = ProviderID.codex

    static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    static var codexHome: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex")
    }

    func fetch() async -> ProviderSnapshot {
        let now = Date()
        var snap = ProviderSnapshot(id: id, status: .ok, windows: [], checkedAt: now)

        // 1) API
        var apiProblem: String
        if let auth = Self.readAuth() {
            let result = await HTTP.get(Self.usageURL, headers: [
                "Authorization": "Bearer \(auth.accessToken)",
                "ChatGPT-Account-Id": auth.accountID ?? "",
            ])
            switch result {
            case .ok(let data):
                if let parsed = try? Self.parseUsage(data), !parsed.windows.isEmpty {
                    snap.source = "api"
                    snap.plan = parsed.plan
                    snap.windows = parsed.windows
                    snap.dataAsOf = now
                    return snap
                }
                apiProblem = "อ่านข้อมูล API ไม่ได้ (รูปแบบอาจเปลี่ยน)"
            case .status(let code, _):
                apiProblem = "API ตอบ HTTP \(code)"
            case .failure(let message):
                apiProblem = "เชื่อมต่อ API ไม่ได้: \(message)"
            }
        } else {
            apiProblem = "ไม่พบ token ใน ~/.codex/auth.json"
        }
        log.notice("codex api: \(apiProblem, privacy: .public) → rollout fallback")

        // 2) rollout fallback
        if let rollout = Self.latestRolloutLimits() {
            snap.source = "rollout"
            snap.note = "\(apiProblem) — ใช้ข้อมูลจาก log ของ Codex แทน"
            snap.plan = rollout.plan
            snap.windows = rollout.windows
            snap.dataAsOf = rollout.timestamp
            return snap
        }
        snap.status = .error("\(apiProblem) และไม่พบข้อมูลใน log ของ Codex")
        return snap
    }

    // MARK: auth.json

    struct Auth: Sendable {
        let accessToken: String
        let accountID: String?
    }

    private struct AuthFile: Decodable {
        struct Tokens: Decodable {
            let accessToken: String?
            let accountId: String?
        }
        let tokens: Tokens?
    }

    static func readAuth() -> Auth? {
        let url = codexHome.appending(path: "auth.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let file = try? decoder.decode(AuthFile.self, from: data),
              let token = file.tokens?.accessToken, !token.isEmpty else { return nil }
        return Auth(accessToken: token, accountID: file.tokens?.accountId)
    }

    // MARK: wham/usage

    struct Parsed: Sendable {
        let plan: String?
        let windows: [UsageWindow]
    }

    private struct UsageResponse: Decodable {
        struct Window: Decodable {
            let usedPercent: Double?
            let limitWindowSeconds: Int?
            let resetAt: Double?
        }
        struct RateLimit: Decodable {
            let primaryWindow: Window?
            let secondaryWindow: Window?
        }
        let planType: String?
        let rateLimit: RateLimit?
        // additional_rate_limits: ยังไม่เคยเห็นค่าจริง (null) จึงยังไม่ decode — ไม่เดารูปแบบ
    }

    static func parseUsage(_ data: Data) throws -> Parsed {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let r = try decoder.decode(UsageResponse.self, from: data)
        let windows = [r.rateLimit?.primaryWindow, r.rateLimit?.secondaryWindow]
            .compactMap { $0 }
            .compactMap { w -> UsageWindow? in
                guard let used = w.usedPercent, let seconds = w.limitWindowSeconds else { return nil }
                return makeWindow(seconds: seconds, used: used, resetsAt: DateParsing.epoch(w.resetAt))
            }
        return Parsed(plan: r.planType, windows: sorted(windows))
    }

    // MARK: rollout

    struct RolloutResult: Sendable {
        let plan: String?
        let windows: [UsageWindow]
        let timestamp: Date?
    }

    private struct RolloutEvent: Decodable {
        struct Payload: Decodable { let rateLimits: RateLimits? }
        struct RateLimits: Decodable {
            struct Window: Decodable {
                let usedPercent: Double?
                let windowMinutes: Int?
                let resetsAt: Double?
            }
            let primary: Window?
            let secondary: Window?
            let planType: String?
        }
        let timestamp: String?
        let payload: Payload?
        let rateLimits: RateLimits?
    }

    /// ไล่ไฟล์ rollout จากใหม่ไปเก่า (สูงสุด 20 ไฟล์) หา event token_count ที่มี rate_limits ตัวล่าสุด
    static func latestRolloutLimits() -> RolloutResult? {
        let root = codexHome.appending(path: "sessions")
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }

        var files: [(URL, Date)] = []
        for case let url as URL in enumerator
        where url.lastPathComponent.hasPrefix("rollout-") && url.pathExtension == "jsonl" {
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            files.append((url, date ?? .distantPast))
        }
        files.sort { $0.1 > $1.1 }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        for (url, _) in files.prefix(20) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n").reversed()
            where line.contains("\"token_count\"") && line.contains("\"rate_limits\"") {
                guard let event = try? decoder.decode(RolloutEvent.self, from: Data(line.utf8)),
                      let limits = event.payload?.rateLimits ?? event.rateLimits else { continue }
                let windows = [limits.primary, limits.secondary].compactMap { $0 }.compactMap { w -> UsageWindow? in
                    guard let used = w.usedPercent, let minutes = w.windowMinutes else { return nil }
                    return makeWindow(seconds: minutes * 60, used: used, resetsAt: DateParsing.epoch(w.resetsAt))
                }
                guard !windows.isEmpty else { continue }
                return RolloutResult(plan: limits.planType, windows: sorted(windows),
                                     timestamp: DateParsing.iso8601(event.timestamp))
            }
        }
        return nil
    }

    // MARK: helpers

    static func makeWindow(seconds: Int, used: Double, resetsAt: Date?) -> UsageWindow {
        UsageWindow(id: "window-\(seconds)", kind: .from(durationSeconds: seconds),
                    label: seconds.windowLabel, durationSeconds: seconds,
                    usedPercent: used, resetsAt: resetsAt)
    }

    static func sorted(_ windows: [UsageWindow]) -> [UsageWindow] {
        windows.sorted { ($0.durationSeconds ?? .max) < ($1.durationSeconds ?? .max) }
    }
}
