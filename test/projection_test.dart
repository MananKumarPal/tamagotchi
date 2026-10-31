import 'dart:convert';

import 'package:eggling/domain/pet_state.dart';
import 'package:eggling/domain/projection.dart';
import 'package:eggling/domain/rules.dart';
import 'package:eggling/domain/simulation.dart';
import 'package:eggling/domain/widget_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  final pet = raise(newEgg(), clock(0, 12));

  group('projection', () {
    test('forecast entries match really advancing the pet', () {
      final entries = Projection.timeline(pet, 0, hours: 12);
      expect(entries.first.at, pet.lastSimulatedAt);
      for (final e in entries.skip(1)) {
        final real = run(pet, e.at);
        expect(e.hunger, real.hunger);
        expect(e.happiness, real.happiness);
        expect(e.asleep, real.isAsleep);
        expect(e.calling, real.isCalling);
      }
    });

    test('forecast does not change the pet', () {
      final before = jsonEncode(pet.toJson());
      Projection.timeline(pet, 0, hours: 24);
      expect(jsonEncode(pet.toJson()), before);
    });

    test('upcoming calls lists future call moments with reasons', () {
      final calls = Projection.upcomingCalls(pet, 0, hours: 12);
      expect(calls, isNotEmpty);
      expect(calls.first.at, greaterThan(pet.lastSimulatedAt));
    });

    test('a departed pet forecasts one final entry', () {
      final gone = run(Simulation.newEgg(id: 'x', profile: RuleProfile.classicB,
          shell: 's', name: 'n', seed: 1, at: t0), t0 + dayMs * 3);
      final entries = Projection.timeline(gone, 0);
      expect(entries.single.pose, 'departed');
    });
  });

  group('widget codec', () {
    test('snapshot round trips and carries the feed gate', () {
      final json = WidgetCodec.encodeSnapshot(pet, 0, seq: 12);
      final map = jsonDecode(json) as Map<String, dynamic>;
      expect(map['schema'], WidgetCodec.schema);
      expect(map['seq'], 12);
      expect(map['pet']['name'], 'Pip');
      final first = (map['entries'] as List).first as Map;
      expect(first.keys, containsAll(['at', 'pose', 'hint', 'hunger', 'happy', 'canFeed', 'canPlay']));
    });

    test('no pet encodes an explicit empty snapshot', () {
      final map = jsonDecode(WidgetCodec.encodeEmpty(seq: 1)) as Map;
      expect(map['pet'], isNull);
      expect(map['entries'], isEmpty);
    });

    test('actions decode to commands, unknown or malformed are dropped', () {
      final actions = WidgetCodec.decodeActions([
        '{"id":"a","type":"meal","at":5}',
        '{"id":"b","type":"snack","at":6}',
        '{"id":"c","type":"explode","at":7}',
        'not json',
      ]);
      expect(actions.map((a) => a.id), ['a', 'b']);
      expect(actions.first.command, isA<FeedMeal>());
    });

    test('actions sort chronologically', () {
      final actions = WidgetCodec.decodeActions([
        '{"id":"late","type":"meal","at":9}',
        '{"id":"early","type":"snack","at":2}',
      ]);
      expect(actions.first.id, 'early');
    });
  });

  group('replaying widget actions', () {
    test('an action replays at the moment it was tapped', () {
      var s = raise(newEgg(), clock(0, 12));
      final due = Simulation.nextDueAt(s)!;
      final tapped = s.copy()..hunger = 0;
      final later = Projection.replay(tapped, [
        WidgetAction('w1', const FeedMeal(), due),
      ], due + mins(30), 0);
      expect(later.state.hunger, greaterThan(0));
      expect(later.state.appliedActions, contains('w1'));
    });

    test('the same action id is only ever applied once', () {
      var s = raise(newEgg(), clock(0, 12)).copy()..hunger = 1;
      final at = s.lastSimulatedAt;
      final action = WidgetAction('w1', const FeedMeal(), at);
      s = Projection.replay(s, [action], at, 0).state;
      final again = Projection.replay(s, [action], at, 0).state;
      expect(again.hunger, 2);
    });

    test('a rejected action is consumed without changing hearts', () {
      final s = raise(newEgg(), clock(0, 12)).copy()..hunger = 4;
      final at = s.lastSimulatedAt;
      final o = Projection.replay(s, [WidgetAction('w', const FeedMeal(), at)], at, 0);
      expect(o.state.hunger, 4);
      expect(o.state.appliedActions, contains('w'));
    });
  });
}
