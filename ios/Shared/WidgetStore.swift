import Foundation

/// The file contract shared by the app and the widget extension, inside the
/// App Group container. See docs/widgets.md. Writes are coordinated so the app
/// and an App Intent running in the extension cannot corrupt each other.
enum WidgetStore {
  static let groupId = "group.com.manankumar.eggling"

  static var directory: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)
  }

  static func file(_ name: String) -> URL? { directory?.appendingPathComponent(name) }

  private static func coordinate(_ url: URL, _ body: (URL) -> Void) {
    var error: NSError?
    NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &error, byAccessor: body)
  }

  static func write(_ data: Data, name: String) {
    guard let url = file(name) else { return }
    coordinate(url) { try? data.write(to: $0, options: .atomic) }
  }

  static func read(_ name: String) -> Data? {
    guard let url = file(name) else { return nil }
    var out: Data?
    var error: NSError?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) {
      out = try? Data(contentsOf: $0)
    }
    return out
  }

  static func actionLines() -> [String] {
    guard let data = read("actions.jsonl"), let text = String(data: data, encoding: .utf8) else {
      return []
    }
    return text.split(separator: "\n").map(String.init)
  }

  /// Returns only after the action is safely on disk.
  static func appendAction(type: String) -> Bool {
    guard let url = file("actions.jsonl") else { return false }
    var saved = false
    coordinate(url) { target in
      var lines = (try? String(contentsOf: target, encoding: .utf8)) ?? ""
      let at = Int(Date().timeIntervalSince1970 * 1000)
      lines += "{\"id\":\"\(UUID().uuidString)\",\"type\":\"\(type)\",\"at\":\(at)}\n"
      saved = (try? lines.data(using: .utf8)?.write(to: target, options: .atomic)) != nil
    }
    return saved
  }

  static func ackActions(_ count: Int) {
    guard let url = file("actions.jsonl") else { return }
    coordinate(url) { target in
      let text = (try? String(contentsOf: target, encoding: .utf8)) ?? ""
      let rest = text.split(separator: "\n").dropFirst(count).map { $0 + "\n" }.joined()
      try? rest.data(using: .utf8)?.write(to: target, options: .atomic)
    }
  }
}
