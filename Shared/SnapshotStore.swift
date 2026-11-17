import Foundation

enum SnapshotStoreError: Error, CustomStringConvertible {
    case missingGroupID
    case noContainer(groupID: String)
    case notFound
    case io(String)

    var description: String {
        switch self {
        case .missingGroupID:
            "ไม่พบ RXAppGroupID ใน Info.plist (DEVELOPMENT_TEAM ว่าง?)"
        case .noContainer(let id):
            "เปิด App Group container ไม่ได้: \(id)"
        case .notFound:
            "ยังไม่มีข้อมูล — เปิดแอป RxWidget บน menu bar"
        case .io(let message):
            message
        }
    }
}

/// อ่าน/เขียน UsageSnapshot ใน App Group container
/// host เขียนอย่างเดียว, widget อ่านอย่างเดียว
enum SnapshotStore {
    static let fileName = "usage-snapshot.json"

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

    static func write(_ snapshot: UsageSnapshot) throws(SnapshotStoreError) {
        let url = try fileURL()
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            throw .io("เขียน snapshot ไม่สำเร็จ: \(error.localizedDescription)")
        }
    }

    static func read() throws(SnapshotStoreError) -> UsageSnapshot {
        let url = try fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { throw .notFound }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(UsageSnapshot.self, from: Data(contentsOf: url))
        } catch {
            throw .io("อ่าน snapshot ไม่สำเร็จ: \(error.localizedDescription)")
        }
    }
}
