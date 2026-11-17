import Foundation
import os

let log = Logger(subsystem: "com.rx8s.rxwidget", category: "providers")

protocol UsageProvider: Sendable {
    var id: ProviderID { get }
    /// ดึงข้อมูลใหม่ ห้าม throw — ทุกความผิดพลาดต้องแปลงเป็น ProviderStatus
    func fetch() async -> ProviderSnapshot
}

// MARK: - Process

enum ProcessRunner {
    struct Output: Sendable {
        let status: Int32
        let stdout: Data
        let stderr: String
    }

    /// รันโปรแกรมแล้วรอผล บน background thread (ไม่บล็อก cooperative pool)
    static func run(_ path: String, _ arguments: [String]) async -> Output {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                let out = Pipe(), err = Pipe()
                process.standardOutput = out
                process.standardError = err
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: Output(status: -1, stdout: Data(), stderr: "\(error)"))
                    return
                }
                // อ่านจนหมดก่อน waitUntilExit กัน pipe เต็มแล้วค้าง
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: Output(
                    status: process.terminationStatus,
                    stdout: data,
                    stderr: String(decoding: errData, as: UTF8.self)))
            }
        }
    }
}

// MARK: - HTTP

enum HTTPResult: Sendable {
    case ok(Data)
    case status(Int, Data)
    case failure(String)
}

enum HTTP {
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    static func get(_ url: URL, headers: [String: String]) async -> HTTPResult {
        var request = URLRequest(url: url)
        request.setValue("rxwidget/0.1", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        do {
            let (data, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            return code == 200 ? .ok(data) : .status(code, data)
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}

// MARK: - Dates

enum DateParsing {
    /// ISO 8601 ที่มีหรือไม่มีเศษวินาที (รองรับเศษวินาทีกี่หลักก็ได้)
    static func iso8601(_ string: String?) -> Date? {
        guard var s = string, !s.isEmpty else { return nil }
        // ตัดเศษวินาทีให้เหลือ 3 หลัก: ".796877+00:00" → ".796+00:00"
        if let dot = s.firstIndex(of: ".") {
            var end = s.index(after: dot)
            while end < s.endIndex, s[end].isNumber { end = s.index(after: end) }
            let digits = s[s.index(after: dot)..<end]
            s.replaceSubrange(dot..<end, with: "." + digits.prefix(3).padding(toLength: 3, withPad: "0", startingAt: 0))
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = s.contains(".")
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter.date(from: s)
    }

    /// epoch วินาทีหรือมิลลิวินาที
    static func epoch(_ value: Double?) -> Date? {
        guard let v = value, v > 0 else { return nil }
        return Date(timeIntervalSince1970: v > 1e12 ? v / 1000 : v)
    }
}

/// ค่าที่อาจเป็นตัวเลขหรือ string ใน JSON (เช่น expiresAt)
struct FlexibleNumber: Decodable, Sendable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) {
            value = d
        } else if let s = try? c.decode(String.self) {
            value = Double(s) ?? DateParsing.iso8601(s).map { $0.timeIntervalSince1970 * 1000 }
        } else {
            value = nil
        }
    }
}
