import 'pet_state.dart';
import 'simulation.dart';
import 'rules.dart';

/// One forecast moment: what the pet looks like if nobody touches it.
class TimelineEntry {
  const TimelineEntry({
    required this.at,
    required this.pose,
    required this.hint,
    required this.hunger,
    required this.happiness,
    required this.asleep,
    required this.calling,
    required this.sick,
    required this.poops,
    required this.canFeed,
    required this.canPlay,
  });

  final int at;
  final String pose;
  final String hint;
  final int hunger;
  final int happiness;
  final bool asleep;
  final bool calling;
  final bool sick;
  final int poops;
  final bool canFeed;
  final bool canPlay;
}

class UpcomingCall {
  const UpcomingCall(this.at, this.reason);
  final int at;
  final CallReason reason;
}

class WidgetAction {
  const WidgetAction(this.id, this.command, this.at);
  final String id;
  final Command command;
  final int at;
}

/// The one-line need shown wherever the status icons are not.
String statusHint(PetState s) {
  if (s.isPaused) return 'on pause';
  if (s.isDeparted) return 'has gone on';
  if (s.isEgg) return 'about to hatch';
  if (s.hasCall(CallReason.lights)) return 'light off, please';
  if (s.isAsleep) return s.sleep == SleepKind.nap ? 'napping' : 'zzz';
  if (s.sick) return 'feeling gross';
  if (s.hasCall(CallReason.hunger)) return 'hungry!!';
  if (s.hasCall(CallReason.happiness)) return 'pay attention to me';
  if (s.misbehaving) return 'acting up';
  if (s.poops.isNotEmpty) return 'it stinks in here';
  if (s.hunger <= 1) return 'kinda hungry';
  if (s.happiness <= 1) return 'kinda bored';
  return 'vibing';
}

/// The pose name, one of the widget poses rendered by `art/widget_sprites`.
String statusPose(PetState s) {
  if (s.isDeparted) return 'departed';
  if (s.isEgg) return 'egg';
  if (s.isAsleep) return 'sleep';
  if (s.sick) return 'sick';
  if (s.isCalling) return 'call';
  if (s.hunger >= 3 && s.happiness >= 3) return 'happy';
  return 'idle';
}

class Projection {
  Projection._();

  static TimelineEntry _entry(PetState s, int at) => TimelineEntry(
        at: at,
        pose: statusPose(s),
        hint: statusHint(s),
        hunger: s.hunger,
        happiness: s.happiness,
        asleep: s.isAsleep,
        calling: s.isCalling,
        sick: s.sick,
        poops: s.poops.length,
        canFeed: Simulation.check(s, const FeedMeal()) == null,
        canPlay: Simulation.check(s, const StartGame()) == null,
      );

  /// Up to [limit] entries from the pet's current moment, ignoring care.
  static List<TimelineEntry> timeline(PetState state, int offsetMinutes,
      {int hours = 24, int limit = 48}) {
    final entries = [_entry(state, state.lastSimulatedAt)];
    final end = state.lastSimulatedAt + hours * hourMs;
    var s = state;
    while (entries.length < limit) {
      final due = Simulation.nextDueAt(s);
      if (due == null || due > end) break;
      s = Simulation.advance(s, due, offsetMinutes).state;
      final entry = _entry(s, due);
      if (entries.last.at == due) {
        entries[entries.length - 1] = entry;
      } else {
        entries.add(entry);
      }
    }
    return entries;
  }

  static List<UpcomingCall> upcomingCalls(PetState state, int offsetMinutes,
      {int hours = 48}) {
    final out = <UpcomingCall>[];
    final o = Simulation.advance(
        state, state.lastSimulatedAt + hours * hourMs, offsetMinutes);
    for (final e in o.events) {
      if (e.kind == EventKind.callStarted) {
        out.add(UpcomingCall(e.at, CallReason.values.byName(e.detail!)));
      }
    }
    return out;
  }

  /// Applies queued actions in time order, then advances to [now]. Ids already
  /// applied are skipped. A refused action is still consumed, so a stale tap
  /// (the pet fell asleep first, say) does nothing and never retries.
  static Outcome replay(PetState state, List<WidgetAction> actions, int now,
      int offsetMinutes) {
    var s = state;
    final events = <PetEvent>[];
    for (final a in actions) {
      if (s.appliedActions.contains(a.id)) continue;
      final o = Simulation.apply(s, a.command, a.at, offsetMinutes);
      events.addAll(o.events);
      s = o.state.copy();
      s.appliedActions = [...s.appliedActions, a.id];
      if (s.appliedActions.length > 64) {
        s.appliedActions = s.appliedActions.sublist(s.appliedActions.length - 64);
      }
    }
    final o = Simulation.advance(s, now, offsetMinutes);
    return Outcome(o.state, [...events, ...o.events]);
  }
}
