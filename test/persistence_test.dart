import 'dart:convert';
import 'dart:io';

import 'package:eggling/data/save_codec.dart';
import 'package:eggling/data/save_store.dart';
import 'package:eggling/domain/reminders.dart';
import 'package:eggling/domain/pet_state.dart';
import 'package:eggling/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  final save = SaveFile(pet: raise(newEgg(), clock(1, 12)), settings: const Settings());

  group('save codec', () {
    test('encode then decode preserves pet and settings', () {
      final back = SaveCodec.decode(SaveCodec.encode(save));
      expect(back.pet!.toJson(), save.pet!.toJson());
      expect(back.settings.soundOn, isTrue);
    });

    test('no pet is valid', () {
      final back = SaveCodec.decode(SaveCodec.encode(const SaveFile(pet: null, settings: Settings())));
      expect(back.pet, isNull);
    });

    test('older schemas run through migrations in order', () {
      final old = jsonDecode(SaveCodec.encode(save)) as Map<String, dynamic>
        ..['schemaVersion'] = 0
        ..remove('settings');
      final back = SaveCodec.decode(jsonEncode(old), migrations: {
        0: (j) => j..['settings'] = {'soundOn': false},
      });
      expect(back.settings.soundOn, isFalse);
    });

    test('a newer schema is refused', () {
      final future = jsonDecode(SaveCodec.encode(save)) as Map<String, dynamic>
        ..['schemaVersion'] = SaveCodec.currentVersion + 1;
      expect(() => SaveCodec.decode(jsonEncode(future)), throwsFormatException);
    });

    test('garbage and out-of-range values are refused', () {
      expect(() => SaveCodec.decode('{nope'), throwsFormatException);
      final bad = jsonDecode(SaveCodec.encode(save)) as Map<String, dynamic>;
      (bad['pet'] as Map)['hunger'] = 9;
      expect(() => SaveCodec.decode(jsonEncode(bad)), throwsFormatException);
    });
  });

  group('save store', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('egg'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes atomically and reads back', () async {
      final store = SaveStore(dir);
      await store.write(save);
      expect((await store.read())!.pet!.name, 'Pip');
      expect(dir.listSync().map((f) => f.path).where((p) => p.endsWith('.tmp')), isEmpty);
    });

    test('a corrupt save falls back to the previous one', () async {
      final store = SaveStore(dir);
      await store.write(save);
      await store.write(save);
      File('${dir.path}/save.json').writeAsStringSync('corrupt');
      expect((await store.read())!.pet!.name, 'Pip');
    });

    test('nothing saved yet reads as null', () async {
      expect(await SaveStore(dir).read(), isNull);
    });
  });

  group('reminder plan', () {
    List<UpcomingCallAt> calls(List<int> hours) =>
        [for (final h in hours) UpcomingCallAt(clock(0, h), CallReason.hunger)];

    test('disabled plans nothing', () {
      expect(planReminders(calls([9]), enabled: false, quietStartHour: 22, quietEndHour: 7, offsetMinutes: 0), isEmpty);
    });

    test('quiet hours are skipped, across midnight', () {
      final p = planReminders(calls([23, 3, 12]), enabled: true, quietStartHour: 22, quietEndHour: 7, offsetMinutes: 0);
      expect(p.map((r) => r.at), [clock(0, 12)]);
    });

    test('calls close together merge and ids are stable slots', () {
      final near = [
        UpcomingCallAt(clock(0, 12), CallReason.hunger),
        UpcomingCallAt(clock(0, 12, 10), CallReason.happiness),
        UpcomingCallAt(clock(0, 14), CallReason.hunger),
      ];
      final p = planReminders(near, enabled: true, quietStartHour: 0, quietEndHour: 0, offsetMinutes: 0);
      expect(p.length, 2);
      expect(p.map((r) => r.slot), [0, 1]);
    });

    test('never more than the slot limit', () {
      final p = planReminders(calls(List.generate(20, (i) => i + 1).map((i) => i % 24).toList()..sort()),
          enabled: true, quietStartHour: 0, quietEndHour: 0, offsetMinutes: 0);
      expect(p.length, lessThanOrEqualTo(reminderSlots));
    });

    test('reasons have copy, and rule constant is sane', () {
      expect(reminderText(CallReason.lights, 'Pip'), contains('light'));
      expect(Rules.callWindowMinutes, 15);
    });
  });
}
