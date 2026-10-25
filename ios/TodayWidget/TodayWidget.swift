import SwiftUI
import WidgetKit

// The app (home_widget) writes these keys to the shared App Group defaults;
// see lib/core/widget_snapshot.dart. The widget only draws them.
private let appGroupId = "group.com.nutriton.app"

struct TodayEntry: TimelineEntry {
    let date: Date
    let valueText: String
    let caption: String
    let progress: Double
    let overGoal: Bool

    static let placeholder = TodayEntry(
        date: Date(), valueText: "1500", caption: "kcal left",
        progress: 0.25, overGoal: false)

    /// What a day with nothing logged looks like, for after midnight and
    /// before the app has published anything.
    static func empty(at date: Date, valueText: String, caption: String) -> TodayEntry {
        TodayEntry(
            date: date, valueText: valueText, caption: caption,
            progress: 0, overGoal: false)
    }
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        // The stored figures belong to one day. From midnight the widget shows
        // an empty day until the app next publishes (it reloads then too).
        let entries = [currentEntry(at: now), currentEntry(at: midnight)]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }

    /// The stored figures as they should look at [date]: unchanged on the day
    /// they were published for, otherwise reset to an empty day.
    private func currentEntry(at date: Date) -> TodayEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let caption = defaults?.string(forKey: "caption") ?? "kcal left"
        let emptyValue = defaults?.string(forKey: "empty_value_text") ?? "0"
        guard let defaults = defaults,
            let storedDay = defaults.string(forKey: "date_key"),
            let valueText = defaults.string(forKey: "value_text")
        else {
            return .empty(at: date, valueText: emptyValue, caption: caption)
        }
        guard storedDay == Self.dayKey(date) else {
            // After midnight a "left" caption still holds: nothing is eaten.
            let resetCaption = caption.hasSuffix("over")
                ? String(caption.dropLast("over".count)) + "left" : caption
            return .empty(at: date, valueText: emptyValue, caption: resetCaption)
        }
        return TodayEntry(
            date: date, valueText: valueText, caption: caption,
            progress: min(max(defaults.double(forKey: "progress"), 0), 1),
            overGoal: defaults.bool(forKey: "over_goal"))
    }

    /// 'yyyy-MM-dd' in the device's calendar, matching the app's date keys.
    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry

    private var tint: Color { entry.overGoal ? .red : .green }

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(entry.valueText)
                    .font(.title2.weight(.semibold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(entry.caption)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 18)
        }
        .padding(4)
    }
}

extension View {
    /// iOS 17 requires a container background; earlier versions draw one.
    @ViewBuilder
    fileprivate func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { Color(.secondarySystemBackground) }
        } else {
            background(Color(.secondarySystemBackground))
        }
    }
}

@main
struct TodayWidget: Widget {
    // Must match HomeWidgetPublisher.iosWidgetName in the Dart code.
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry).widgetBackground()
        }
        .configurationDisplayName("Today")
        .description("Calories left today.")
        .supportedFamilies([.systemSmall])
    }
}
