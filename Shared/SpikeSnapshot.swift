import Foundation

/// ข้อมูลทดสอบสำหรับ spike: host เขียน, widget อ่าน
struct SpikeSnapshot: Codable, Sendable, Equatable {
    var counter: Int
    var writtenAt: Date
    var writer: String
}

enum SnapshotStoreError: Error, CustomStringConvertible {
    case missingGroupID
    case noContainer(groupID: String)
    case notFound(path: String)
    case io(String)

    var description: String {
        switch self {
        case .missingGroupID:
            "ไม่พบ RXAppGroupID ใน Info.plist (DEVELOPMENT_TEAM ว่าง?)"
        case .noContainer(let id):
            "เปิด App Group container ไม่ได้: \(id)"
        case .notFound:
            "ยังไม่มี snapshot"
        case .io(let message):
            message
        }
    }
}

/// อ่าน/เขียน snapshot ใน App Group container
enum SnapshotStore {
    static let fileName = "spike-snapshot.json"

    static var groupID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "RXAppGroupID") as? String,
              !id.isEmpty, !id.hasPrefix(".") else { return nil }
        return id
    }

    static func containerURL() throws(SnapshotStoreError) -> URL {
        guard let id = groupID else { throw .missingGroupID }
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: id
        ) else { throw .noContainer(groupID: id) }
        return url
    }

    static func fileURL() throws(SnapshotStoreError) -> URL {
        try containerURL().appending(path: fileName)
    }

    static func write(_ snapshot: SpikeSnapshot) throws(SnapshotStoreError) {
        let url = try fileURL()
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            throw .io("เขียนไม่สำเร็จ: \(error.localizedDescription)")
        }
    }

    static func read() throws(SnapshotStoreError) -> SpikeSnapshot {
        let url = try fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw .notFound(path: url.path)
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SpikeSnapshot.self, from: Data(contentsOf: url))
        } catch {
            throw .io("อ่านไม่สำเร็จ: \(error.localizedDescription)")
        }
    }
}
