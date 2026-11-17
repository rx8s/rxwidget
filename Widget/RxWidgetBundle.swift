import SwiftUI
import WidgetKit

@main
struct RxWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpikeWidget()
    }
}

struct SpikeEntry: TimelineEntry {
    let date: Date
    let result: Result<SpikeSnapshot, SnapshotStoreError>
}

struct SpikeProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpikeEntry {
        SpikeEntry(date: .now, result: .success(.init(counter: 0, writtenAt: .now, writer: "placeholder")))
    }

    func getSnapshot(in context: Context, completion: @escaping (SpikeEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpikeEntry>) -> Void) {
        // widget อ่านอย่างเดียว; host เป็นคนสั่ง reload เมื่อเขียนข้อมูลใหม่
        completion(Timeline(entries: [makeEntry()], policy: .after(.now.addingTimeInterval(15 * 60))))
    }

    private func makeEntry() -> SpikeEntry {
        let result: Result<SpikeSnapshot, SnapshotStoreError>
        do { result = .success(try SnapshotStore.read()) }
        catch { result = .failure(error) }
        return SpikeEntry(date: .now, result: result)
    }
}

struct SpikeWidgetView: View {
    let entry: SpikeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("App Group spike").font(.caption).foregroundStyle(.secondary)
            switch entry.result {
            case .success(let s):
                Text("#\(s.counter)").font(.system(size: 40, weight: .semibold, design: .rounded))
                Text("เขียนเมื่อ \(s.writtenAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
            case .failure(let error):
                Image(systemName: "exclamationmark.triangle")
                Text(error.description).font(.caption).lineLimit(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SpikeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SpikeWidget", provider: SpikeProvider()) { entry in
            SpikeWidgetView(entry: entry)
        }
        .configurationDisplayName("RxWidget Spike")
        .description("ทดสอบอ่าน snapshot จาก App Group")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
