import SwiftUI
import WidgetKit

@main
struct RxWidgetBundle: WidgetBundle {
    var body: some Widget {
        UsageWidget()
    }
}

struct UsageEntry: TimelineEntry {
    let date: Date
    let result: Result<UsageSnapshot, SnapshotStoreError>
}

/// widget อ่านอย่างเดียว; host สั่ง reload ทุกครั้งที่เขียน snapshot ใหม่
struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: .now, result: .success(.placeholder))
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        completion(Timeline(entries: [makeEntry()], policy: .after(.now.addingTimeInterval(15 * 60))))
    }

    private func makeEntry() -> UsageEntry {
        let result: Result<UsageSnapshot, SnapshotStoreError>
        do { result = .success(try SnapshotStore.read()) }
        catch { result = .failure(error) }
        return UsageEntry(date: .now, result: result)
    }
}

struct UsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsageEntry

    var body: some View {
        Group {
            switch entry.result {
            case .success(let snapshot):
                content(snapshot)
            case .failure(let error):
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error.description).font(.caption).lineLimit(4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            ZStack {
                Rectangle().fill(.fill.tertiary)
                Rectangle().fill(Theme.cardGradient).opacity(Theme.cardTintOpacity)
            }
        }
    }

    @ViewBuilder
    private func content(_ snapshot: UsageSnapshot) -> some View {
        let providers = snapshot.providers
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(providers) { ProviderSection(provider: $0, compact: true, maxWindows: 2) }
                Spacer(minLength: 0)
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                ForEach(providers) { ProviderSection(provider: $0, compact: true, maxWindows: 3) }
            }
        }
    }
}

struct UsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UsageWidget", provider: UsageTimelineProvider()) { entry in
            UsageWidgetView(entry: entry)
        }
        .configurationDisplayName("RxWidget")
        .description("โควตา Claude และ Codex")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension UsageSnapshot {
    static var placeholder: UsageSnapshot {
        let now = Date.now
        func w(_ id: String, _ kind: WindowKind, _ label: String, _ p: Double) -> UsageWindow {
            UsageWindow(id: id, kind: kind, label: label, usedPercent: p, resetsAt: now.addingTimeInterval(3600))
        }
        return UsageSnapshot(generatedAt: now, providers: [
            ProviderSnapshot(id: .claudeSubscription, status: .ok, windows: [
                w("s", .session, "5 ชั่วโมง", 25), w("w", .weekly, "7 วัน", 60),
            ], checkedAt: now),
            ProviderSnapshot(id: .codex, status: .ok, windows: [
                w("s", .session, "5 ชั่วโมง", 40), w("w", .weekly, "7 วัน", 10),
            ], checkedAt: now),
        ])
    }
}
