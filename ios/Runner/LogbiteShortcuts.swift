import AppIntents
import Foundation

// Siri, Spotlight, the Shortcuts app and the Action button. The Dart side
// (lib/core/shortcuts.dart, lib/data/shortcuts/) writes the keys below to the
// App Group defaults the widget also uses; these intents only read them, and
// store a "log this" request for the app to carry out.

/// The App Group defaults and the keys shared with the Dart side.
enum ShortcutsStore {
  static let appGroupId = "group.com.andrewcruz.nutriton"
  static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

  /// Set by AppDelegate once Flutter runs: tells Dart a request is waiting.
  static var notifyApp: (() -> Void)?

  /// What to say about today. The stored sentence belongs to one day; on a
  /// later day, before the app publishes again, nothing is logged yet.
  static func sentence(at date: Date) -> String {
    guard let defaults, let sentence = defaults.string(forKey: "shortcut_sentence") else {
      return "Open Logbite once, then ask again."
    }
    if defaults.string(forKey: "shortcut_date_key") == dayKey(date) {
      return sentence
    }
    return defaults.string(forKey: "shortcut_empty_sentence") ?? sentence
  }

  /// The saved meals and starred foods the app published, by name.
  static func items() -> [(id: String, name: String)] {
    guard let json = defaults?.string(forKey: "shortcut_items"),
      let data = json.data(using: .utf8),
      let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return [] }
    return list.compactMap { item in
      guard let id = item["id"] as? String, let name = item["name"] as? String else { return nil }
      return (id: id, name: name)
    }
  }

  /// Leaves a request for the app to log [itemId]; the app drops it after
  /// ten minutes (shortcutRequestLifetime).
  static func requestLog(itemId: String) {
    defaults?.set(itemId, forKey: "shortcut_request_item")
    defaults?.set(Date().timeIntervalSince1970, forKey: "shortcut_request_at")
    notifyApp?()
  }

  /// 'yyyy-MM-dd' in the device's calendar, matching the app's date keys.
  private static func dayKey(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}

/// A saved meal or a starred food, as Siri sees it.
@available(iOS 16.0, *)
struct LoggableItem: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Food or Meal"
  static var defaultQuery = LoggableItemQuery()

  /// "meal:<id>" or "food:<id>".
  let id: String
  let name: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }

  static func all() -> [LoggableItem] {
    ShortcutsStore.items().map { LoggableItem(id: $0.id, name: $0.name) }
  }
}

@available(iOS 16.0, *)
struct LoggableItemQuery: EntityStringQuery {
  func entities(for identifiers: [String]) async throws -> [LoggableItem] {
    LoggableItem.all().filter { identifiers.contains($0.id) }
  }

  func entities(matching string: String) async throws -> [LoggableItem] {
    LoggableItem.all().filter { $0.name.localizedCaseInsensitiveContains(string) }
  }

  func suggestedEntities() async throws -> [LoggableItem] {
    LoggableItem.all()
  }
}

/// "How much is left in Logbite?" Answered from the stored sentence, without
/// opening the app.
@available(iOS 16.0, *)
struct AmountLeftIntent: AppIntent {
  static var title: LocalizedStringResource = "Amount Left Today"
  static var description = IntentDescription(
    "Says how much of today's goal is left, or how much you have had.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let sentence = ShortcutsStore.sentence(at: Date())
    return .result(value: sentence, dialog: "\(sentence)")
  }
}

/// "Log Breakfast in Logbite." Opens the app, which logs the item for today
/// in the slot for the time of day.
@available(iOS 16.0, *)
struct LogItemIntent: AppIntent {
  static var title: LocalizedStringResource = "Log Food or Meal"
  static var description = IntentDescription(
    "Logs one of your saved meals or starred foods for today.")
  static var openAppWhenRun = true

  @Parameter(title: "Food or Meal")
  var item: LoggableItem

  static var parameterSummary: some ParameterSummary {
    Summary("Log \(\.$item)")
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    ShortcutsStore.requestLog(itemId: item.id)
    return .result(dialog: "Logging \(item.name).")
  }
}

/// The phrases Siri knows without any setup. Every phrase names the app.
@available(iOS 16.0, *)
struct LogbiteShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AmountLeftIntent(),
      phrases: [
        "How much is left in \(.applicationName)",
        "What's left today in \(.applicationName)",
        "How am I doing in \(.applicationName)",
      ],
      shortTitle: "Left Today",
      systemImageName: "chart.pie"
    )
    AppShortcut(
      intent: LogItemIntent(),
      phrases: [
        "Log \(\.$item) in \(.applicationName)",
        "Add \(\.$item) to \(.applicationName)",
        "Log food in \(.applicationName)",
      ],
      shortTitle: "Log Food or Meal",
      systemImageName: "plus.circle"
    )
  }
}
