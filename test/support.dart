import 'package:eggling/domain/pet_state.dart';
import 'package:eggling/domain/rules.dart';
import 'package:eggling/domain/reminders.dart';
import 'package:eggling/domain/simulation.dart';
import 'package:eggling/game/game_controller.dart';

/// 2026-01-05 10:00 at UTC offset 0, so tests read as local time.
final int t0 = DateTime.utc(2026, 1, 5, 10).millisecondsSinceEpoch;

int mins(int n) => n * minuteMs;

PetState newEgg({RuleProfile profile = RuleProfile.classicA, int seed = 7}) =>
    Simulation.newEgg(
        id: 'pet', profile: profile, shell: 'mint', name: 'Pip', seed: seed, at: t0);

PetState run(PetState s, int at) => Simulation.advance(s, at, 0).state;

PetState act(PetState s, Command c, int at) {
  final o = Simulation.apply(s, c, at, 0);
  if (!o.accepted) throw StateError('rejected ${o.rejection} for $c');
  return o.state;
}

/// Local hour on [day] days after t0's date.
int clock(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 1, 5 + day, hour, minute).millisecondsSinceEpoch;

/// Keeps a pet healthy until [until], answering everything each 5 minutes.
/// [onCall] decides how to answer misbehaving; [skipCare] leaves needs ignored.
PetState raise(PetState start, int until,
    {bool scold = true, bool medicate = true, bool Function(CallReason)? ignore}) {
  PetState tryAct(PetState p, Command c, int at) =>
      Simulation.apply(p, c, at, 0).state;

  var s = start;
  var now = s.lastSimulatedAt;
  while (now < until && !s.isDeparted) {
    now += mins(5);
    if (now > until) now = until;
    s = run(s, now);
    if (s.isEgg || s.isDeparted) continue;
    for (final call in List.of(s.calls)) {
      if (ignore?.call(call.reason) ?? false) continue;
      switch (call.reason) {
        case CallReason.lights:
          s = tryAct(s, const SetLights(false), now);
        case CallReason.misbehave:
          if (scold) s = tryAct(s, const Scold(), now);
        case CallReason.hunger:
          s = tryAct(s, const FeedMeal(), now);
        case CallReason.happiness:
          s = tryAct(s, const FeedSnack(), now);
      }
    }
    if (s.isAsleep) continue;
    if (s.poops.isNotEmpty) s = tryAct(s, const Clean(), now);
    if (s.sick && medicate) s = tryAct(s, const GiveMedicine(), now);
  }
  return s;
}

class FakePlatform implements GamePlatform {
  @override
  int now = t0;
  @override
  int offsetMinutes = 0;
  List<String> queue = [];
  int publishes = 0;
  int queueAtPublish = -1;
  String? lastSnapshot;
  List<Reminder> reminders = [];

  @override
  Future<List<String>> readWidgetActions() async => List.of(queue);
  @override
  Future<void> ackWidgetActions(int count) async => queue = queue.sublist(count);
  @override
  Future<void> publishWidget(String json, String? formId, PetState? pet) async {
    publishes++;
    lastSnapshot = json;
    queueAtPublish = queue.length;
  }

  @override
  Future<void> scheduleReminders(List<Reminder> plan) async => reminders = plan;
  @override
  Future<bool> requestNotificationPermission() async => true;
  @override
  void play(Cue cue) {}
}

