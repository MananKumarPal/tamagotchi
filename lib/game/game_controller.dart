import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart' show ChangeNotifier, Color;

import '../art/shells.dart';
import '../data/save_codec.dart';
import '../data/save_store.dart';
import '../domain/naming.dart';
import '../domain/pet_state.dart';
import '../domain/projection.dart';
import '../domain/reminders.dart';
import '../domain/rules.dart';
import '../domain/simulation.dart';
import '../domain/widget_codec.dart';

enum Cue {
  select,
  confirm,
  cancel,
  call,
  eat,
  happy,
  sick,
  medicine,
  evolve,
  death,
  game,
  lose,
}

/// What happened while the app was closed.
class AwayReport {
  const AwayReport({
    required this.missedCalls,
    required this.grewInto,
    required this.fellSick,
    required this.departed,
  });

  final int missedCalls;
  final String? grewInto;
  final bool fellSick;
  final bool departed;
}

/// Everything the game needs from the phone. [DevicePlatform] is the real
/// adapter; tests use a fake.
abstract class GamePlatform {
  int get now;
  int get offsetMinutes;
  Future<List<String>> readWidgetActions();
  Future<void> ackWidgetActions(int count);
  Future<void> publishWidget(
    String snapshotJson,
    String? formId,
    PetState? pet,
  );
  Future<void> scheduleReminders(List<Reminder> plan);
  Future<bool> requestNotificationPermission();
  void play(Cue cue);
}

/// Owns the live pet: loads it, keeps it current, saves after every change and
/// tells the widgets and reminders. The UI only reads [pet] and sends commands.
class GameController extends ChangeNotifier {
  GameController(this.store, this.platform);

  final SaveStore store;
  final GamePlatform platform;

  PetState? pet;
  Settings settings = const Settings();
  bool ready = false;

  /// Non-null when a save existed but could not be read at all.
  String? loadProblem;

  /// Screen a deep link asked for, consumed by the room.
  String? pendingRoute;

  /// Added to the device clock by the developer panel only.
  int devSkewMs = 0;

  final _events = StreamController<PetEvent>.broadcast();
  Stream<PetEvent> get events => _events.stream;

  AwayReport? _awayReport;

  /// The report for the last catch-up, once. Null if nothing worth saying.
  AwayReport? takeAwayReport() {
    final r = _awayReport;
    _awayReport = null;
    return r;
  }

  static const _awayThresholdMs = 10 * minuteMs;

  void _noteAway(PetState before, List<PetEvent> events) {
    if (now - before.lastSimulatedAt < _awayThresholdMs) return;
    final missed = events.where((e) => e.kind == EventKind.missedNeedCall).length;
    final evolved = events.where((e) => e.kind == EventKind.evolved).toList();
    final sick = events.any((e) => e.kind == EventKind.fellSick);
    final gone = events.any((e) => e.kind == EventKind.departed);
    if (missed == 0 && evolved.isEmpty && !sick && !gone) return;
    _awayReport = AwayReport(
      missedCalls: missed,
      grewInto: evolved.isEmpty ? null : pet!.roster.form(evolved.last.detail!).name,
      fellSick: sick,
      departed: gone,
    );
  }

  int _widgetSeq = 0;
  String? _publishedForm;
  int get now => platform.now + devSkewMs;
  int get _offset => platform.offsetMinutes;

  /// Runs [job] after all earlier ones. Every change to [pet] goes through
  /// here: the tick and a tap must never read the same state and both write.
  Future<T> _serial<T>(Future<T> Function() job) {
    _pending++;
    final result = _queue.then((_) => job());
    _queue = result
        .then<void>((_) {}, onError: (_) {})
        .whenComplete(() => _pending--);
    return result;
  }

  Future<void> _queue = Future.value();
  int _pending = 0;

  Future<void> boot() async {
    try {
      final save = await store.read();
      pet = save?.pet;
      settings = save?.settings ?? const Settings();
      // Show the pet now. Widget and reminder setup can be slow on first run.
      ready = true;
      notifyListeners();
      await refresh(save: true);
    } on Object catch (e) {
      loadProblem = '$e';
      ready = true;
      notifyListeners();
    }
  }

  /// Applies queued widget taps and elapsed time. Call on launch, on resume
  /// and from the foreground tick.
  Future<void> refresh({bool save = false}) {
    if (!save && _pending > 0) return Future.value();
    return _serial(() => _refresh(save));
  }

  Future<void> _refresh(bool save) async {
    final current = pet;
    if (current == null) {
      if (save) await _publish();
      return;
    }
    final queued = WidgetCodec.decodeActions(
      await platform.readWidgetActions(),
    );
    final due = Simulation.nextDueAt(current);
    if (queued.isEmpty && !save && (due == null || due > now)) return;
    final o = Projection.replay(current, queued, now, _offset);
    pet = o.state;
    _noteAway(current, o.events);
    await _save();
    // Ack before publishing: the widget adds queued taps to the snapshot, so
    // the other order briefly counts each tap twice. If the app dies between
    // save and ack, appliedActions stops the tap applying again.
    await platform.ackWidgetActions(queued.length);
    await _publish();
    _announce(o.events);
    notifyListeners();
  }

  /// Runs a player command. Returns why it was refused, if it was.
  Future<Rejection?> perform(Command command) =>
      _serial(() => _perform(command));

  Future<Rejection?> _perform(Command command) async {
    final current = pet;
    if (current == null) return null;
    final o = Simulation.apply(current, command, now, _offset);
    pet = o.state;
    if (o.events.isNotEmpty || o.accepted) await _commit();
    _announce(o.events);
    notifyListeners();
    return o.rejection;
  }

  Future<void> startNewEgg({
    required RuleProfile profile,
    required String shell,
    required String name,
  }) => _serial(() async {
    pet = Simulation.newEgg(
      id: 'pet-${now.toRadixString(36)}',
      profile: profile,
      shell: shell,
      name: cleanName(name),
      seed: Random().nextInt(1 << 31),
      at: now,
    );
    await _commit();
    notifyListeners();
  });

  Future<void> clearPet() => _serial(() async {
    pet = null;
    await _commit();
    notifyListeners();
  });

  Future<void> updateSettings(Settings next) => _serial(() async {
    settings = next;
    await _commit();
    notifyListeners();
  });

  /// Asks the OS, then records the answer. Returns whether reminders are on.
  Future<bool> enableNotifications() async {
    final granted = await platform.requestNotificationPermission();
    await updateSettings(
      settings.copyWith(notificationsOn: granted, notificationsAsked: true),
    );
    return granted;
  }

  String exportSave() =>
      SaveCodec.encode(SaveFile(pet: pet, settings: settings));

  /// Throws [FormatException] and changes nothing if [text] is not a good save.
  Future<void> importSave(String text) async {
    final save = SaveCodec.decode(text);
    await _serial(() async {
      pet = save.pet;
      settings = save.settings;
      await _refresh(true);
    });
    notifyListeners();
  }

  Future<void> rename(String raw) => _serial(() async {
        final p = pet;
        if (p == null) return;
        pet = p.copy()..name = cleanName(raw);
        await _commit();
        notifyListeners();
      });

  void setRoute(String route) {
    pendingRoute = route;
    notifyListeners();
  }

  void play(Cue cue) {
    if (settings.soundOn) platform.play(cue);
  }

  Future<void> addDevSkew(int ms) async {
    devSkewMs += ms;
    await refresh(save: true);
  }

  Future<void> _save() => store.write(SaveFile(pet: pet, settings: settings));

  Future<void> _commit() async {
    await _save();
    await _publish();
  }

  Future<void> _publish() async {
    _widgetSeq++;
    final p = pet;
    if (p == null) {
      await platform.publishWidget(
        WidgetCodec.encodeEmpty(seq: _widgetSeq),
        null,
        null,
      );
      await platform.scheduleReminders(const []);
      return;
    }
    final key = '${p.formId}:${p.profile.name}';
    await platform.publishWidget(
      WidgetCodec.encodeSnapshot(p, _offset,
            seq: _widgetSeq,
            accent: _hex(shellById(p.shell).accent),
            soft: _hex(shellById(p.shell).soft)),
      key == _publishedForm ? null : p.formId,
      p,
    );
    _publishedForm = key;
    final calls = p.isPaused
        ? const <UpcomingCall>[]
        : Projection.upcomingCalls(p, _offset);
    await platform.scheduleReminders(
      planReminders(
        [for (final c in calls) UpcomingCallAt(c.at, c.reason)],
        enabled: settings.notificationsOn,
        quietStartHour: settings.quietStartHour,
        quietEndHour: settings.quietEndHour,
        offsetMinutes: _offset,
      ),
    );
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _announce(List<PetEvent> events) {
    final recent = now - 2 * minuteMs;
    for (final e in events) {
      _events.add(e);
      if (e.at < recent) continue;
      final cue = switch (e.kind) {
        EventKind.callStarted => Cue.call,
        EventKind.fedMeal || EventKind.fedSnack => Cue.eat,
        EventKind.gameWon ||
        EventKind.wasCured ||
        EventKind.hatched => Cue.happy,
        EventKind.gameLost || EventKind.scolded => Cue.lose,
        EventKind.fellSick => Cue.sick,
        EventKind.dosed => Cue.medicine,
        EventKind.evolved => Cue.evolve,
        EventKind.departed => Cue.death,
        EventKind.cleaned || EventKind.lightsChanged => Cue.confirm,
        _ => null,
      };
      if (cue != null) play(cue);
    }
  }

  @override
  void dispose() {
    _events.close();
    super.dispose();
  }
}
