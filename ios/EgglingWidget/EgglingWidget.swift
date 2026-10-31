import AppIntents
import SwiftUI
import UIKit
import WidgetKit

private extension Color {
  /// Parses the `#RRGGBB` the app writes into the snapshot.
  init(hex: String?, fallback: Color) {
    guard let hex, let value = UInt32(hex.dropFirst(), radix: 16) else {
      self = fallback
      return
    }
    self.init(
      red: Double(value >> 16 & 255) / 255,
      green: Double(value >> 8 & 255) / 255,
      blue: Double(value & 255) / 255)
  }
}

private let defaultSoft = Color(red: 0.929, green: 0.894, blue: 1.0)
private let defaultAccent = Color(red: 0.831, green: 1.0, blue: 0.227)
private let ink = Color(red: 0.106, green: 0.063, blue: 0.2)

struct Snapshot: Decodable {
  struct Pet: Decodable {
    let name: String
    let form: String
    let accent: String?
    let soft: String?
  }

  struct Moment: Decodable {
    let at: Double
    let pose: String
    let hint: String
    let hunger: Int
    let happy: Int
    let canFeed: Bool
    let canPlay: Bool
  }

  let pet: Pet?
  let entries: [Moment]

  static func load() -> Snapshot? {
    guard let data = WidgetStore.read("snapshot.json") else { return nil }
    return try? JSONDecoder().decode(Snapshot.self, from: data)
  }
}

struct PetEntry: TimelineEntry {
  let date: Date
  let name: String?
  let moment: Snapshot.Moment?
  let stale: Bool
  let queued: Bool
  var hunger = 0
  var happy = 0
  var accent: String? = nil
  var soft: String? = nil
}

/// Taps the app has not replayed yet still count towards what the widget shows.
private func pendingCount(_ type: String) -> Int {
  WidgetStore.actionLines().filter { $0.contains("\"type\":\"\(type)\"") }.count
}

struct Provider: TimelineProvider {
  private static let staleAfter: TimeInterval = 24 * 3600

  func placeholder(in context: Context) -> PetEntry {
    PetEntry(date: .now, name: "Your pet", moment: nil, stale: false, queued: false)
  }

  private func entry(_ moment: Snapshot.Moment?, pet: Snapshot.Pet?, date: Date, last: Date?) -> PetEntry {
    let meals = pendingCount("meal"), snacks = pendingCount("snack")
    return PetEntry(
      date: date, name: pet?.name, moment: moment,
      stale: last.map { date.timeIntervalSince($0) > Self.staleAfter } ?? false,
      queued: meals + snacks > 0,
      hunger: min(4, (moment?.hunger ?? 0) + meals),
      happy: min(4, (moment?.happy ?? 0) + snacks),
      accent: pet?.accent, soft: pet?.soft)
  }

  func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
    let s = Snapshot.load()
    completion(entry(current(s, .now), pet: s?.pet, date: .now, last: lastDate(s)))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
    let s = Snapshot.load()
    let now = Date.now
    var entries = [entry(current(s, now), pet: s?.pet, date: now, last: lastDate(s))]
    for m in s?.entries ?? [] where m.at / 1000 > now.timeIntervalSince1970 {
      entries.append(entry(m, pet: s?.pet, date: Date(timeIntervalSince1970: m.at / 1000), last: lastDate(s)))
    }
    if let last = lastDate(s) {
      entries.append(entry(s?.entries.last, pet: s?.pet, date: last.addingTimeInterval(Self.staleAfter), last: last))
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }

  private func lastDate(_ s: Snapshot?) -> Date? {
    s?.entries.last.map { Date(timeIntervalSince1970: $0.at / 1000) }
  }

  private func current(_ s: Snapshot?, _ date: Date) -> Snapshot.Moment? {
    let t = date.timeIntervalSince1970 * 1000
    return s?.entries.last(where: { $0.at <= t }) ?? s?.entries.first
  }
}

struct FeedMealIntent: AppIntent {
  static var title: LocalizedStringResource = "Give a meal"
  static var isDiscoverable = false

  func perform() async throws -> some IntentResult {
    _ = WidgetStore.appendAction(type: "meal")
    return .result()
  }
}

struct FeedSnackIntent: AppIntent {
  static var title: LocalizedStringResource = "Give a snack"
  static var isDiscoverable = false

  func perform() async throws -> some IntentResult {
    _ = WidgetStore.appendAction(type: "snack")
    return .result()
  }
}

private struct Sprite: View {
  let pose: String

  var body: some View {
    if let data = WidgetStore.read("pose_\(pose).png"), let image = UIImage(data: data) {
      Image(uiImage: image)
        .interpolation(.none)
        .resizable()
        .scaledToFit()
        .accessibilityHidden(true)
    } else {
      Text("?").font(.title).foregroundStyle(ink)
    }
  }
}

/// Four chunky pips, standing in for the app's hearts.
private struct Pips: View {
  let value: Int
  let size: CGFloat

  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<4, id: \.self) { i in
        RoundedRectangle(cornerRadius: 2)
          .fill(i < value ? ink : Color.clear)
          .overlay(RoundedRectangle(cornerRadius: 2).stroke(ink, lineWidth: 1.5))
          .frame(width: size, height: size)
      }
    }
  }
}

private struct Key: View {
  let label: String
  let color: Color

  var body: some View {
    Text(label)
      .font(.system(size: 14, weight: .black, design: .rounded))
      .foregroundStyle(ink)
      .frame(maxWidth: .infinity, minHeight: 36)
      .background(color, in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(ink, lineWidth: 2.5))
  }
}

struct EgglingWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: PetEntry

  private var soft: Color { Color(hex: entry.soft, fallback: defaultSoft) }
  private var accent: Color { Color(hex: entry.accent, fallback: defaultAccent) }
  private var pose: String { entry.moment?.pose ?? "idle" }
  private var name: String { entry.name ?? "your pet" }

  /// Eggs and departed pets have nothing to feed.
  private var showsKeys: Bool { pose != "egg" && pose != "departed" }

  private var hint: String {
    if pose == "departed" { return "open to hatch a new egg" }
    if entry.stale { return "open to check in" }
    if entry.queued { return "saved. applies when you open eggling" }
    return entry.moment?.hint ?? "no pet yet"
  }

  var body: some View {
    Group {
      if family == .accessoryRectangular {
        lockScreen
      } else if entry.moment == nil {
        empty
      } else if family == .systemSmall {
        small
      } else if family == .systemLarge {
        large
      } else {
        wide
      }
    }
    .foregroundStyle(ink)
    .containerBackground(family == .accessoryRectangular ? Color.clear : soft, for: .widget)
    .widgetURL(URL(string: "eggling://open/room"))
  }

  private var empty: some View {
    VStack(spacing: 6) {
      Text("eggling").font(.system(.headline, design: .rounded).weight(.black))
      Text(entry.name == nil ? "open the app to hatch an egg" : "open to check in")
        .font(.system(.caption, design: .rounded).weight(.semibold))
        .multilineTextAlignment(.center)
    }
  }

  private var lockScreen: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(name).font(.system(.headline, design: .rounded).weight(.black)).lineLimit(1)
      Text(hint).font(.system(.caption, design: .rounded).weight(.semibold)).lineLimit(2)
    }
    .foregroundStyle(.primary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private func meters(size: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      meter("food", entry.hunger, size: size).accessibilityLabel("Food \(entry.hunger) of 4")
      meter("joy", entry.happy, size: size).accessibilityLabel("Joy \(entry.happy) of 4")
    }
  }

  private func meter(_ title: String, _ value: Int, size: CGFloat) -> some View {
    HStack(spacing: 6) {
      Text(title)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .frame(width: 30, alignment: .leading)
      Pips(value: value, size: size)
    }
  }

  private var status: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(name).font(.system(.title3, design: .rounded).weight(.black)).lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(hint).font(.system(size: 13, weight: .semibold, design: .rounded))
        .lineLimit(2).minimumScaleFactor(0.8)
      meters(size: 11)
    }
  }

  private var keys: some View {
    HStack(spacing: 6) {
      if entry.moment?.canFeed == true, entry.hunger < 4 {
        Button(intent: FeedMealIntent()) { Key(label: "meal", color: accent) }.buttonStyle(.plain)
      } else {
        Link(destination: URL(string: "eggling://open/feed")!) { Key(label: "meal", color: .white) }
      }
      if entry.moment?.canPlay == true {
        Button(intent: FeedSnackIntent()) { Key(label: "snack", color: accent) }.buttonStyle(.plain)
      } else {
        Link(destination: URL(string: "eggling://open/feed")!) { Key(label: "snack", color: .white) }
      }
      Link(destination: URL(string: "eggling://open/game")!) { Key(label: "play", color: .white) }
    }
  }

  private var small: some View {
    VStack(spacing: 3) {
      Sprite(pose: pose)
      Text(name).font(.system(.subheadline, design: .rounded).weight(.black)).lineLimit(1)
      Text(hint).font(.system(size: 12, weight: .semibold, design: .rounded))
        .lineLimit(1).minimumScaleFactor(0.7)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(name). \(hint). Food \(entry.hunger) of 4. Joy \(entry.happy) of 4.")
  }

  private var wide: some View {
    VStack(spacing: 8) {
      HStack(spacing: 10) {
        Sprite(pose: pose)
        status.frame(maxWidth: .infinity, alignment: .leading)
      }
      if showsKeys { keys }
    }
  }

  private var large: some View {
    VStack(spacing: 10) {
      Sprite(pose: pose).frame(maxHeight: .infinity)
      status.frame(maxWidth: .infinity, alignment: .leading)
      if showsKeys { keys }
    }
  }
}

@main
struct EgglingWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "EgglingWidget", provider: Provider()) { entry in
      EgglingWidgetView(entry: entry)
    }
    .configurationDisplayName("Eggling")
    .description("See how your pet is doing, and feed it from here.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
  }
}
