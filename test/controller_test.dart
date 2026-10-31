import 'dart:io';

import 'package:eggling/data/save_store.dart';
import 'package:eggling/domain/pet_state.dart';
import 'package:eggling/domain/reminders.dart';
import 'package:eggling/domain/rules.dart';
import 'package:eggling/game/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  late Directory dir;
  late FakePlatform platform;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('ctl');
    platform = FakePlatform();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<GameController> boot() async {
    final c = GameController(SaveStore(dir), platform);
    await c.boot();
    return c;
  }

  Future<GameController> withPet() async {
    final c = await boot();
    await c.startNewEgg(profile: RuleProfile.classicA, shell: 'mint', name: ' Pip ');
    await c.perform(const HatchNow());
    return c;
  }

  test('fresh install has no pet and publishes an empty widget', () async {
    final c = await boot();
    expect(c.pet, isNull);
    expect(platform.lastSnapshot, contains('"pet":null'));
  });

  test('a restart keeps the pet and applies time that passed', () async {
    final c = await withPet();
    await c.perform(const FeedMeal());
    expect(c.pet!.hunger, 1);
    expect(c.pet!.name, 'Pip');
    platform.now += hourMs;
    final again = await boot();
    expect(again.pet!.id, c.pet!.id);
    expect(again.pet!.stage, LifeStage.baby);
    expect(again.pet!.careMistakesIn(LifeStage.baby), greaterThan(0));
  });

  test('a widget tap queued while closed is applied at its own time', () async {
    final c = await withPet();
    platform.queue.add('{"id":"w1","type":"meal","at":${c.now + 1000}}');
    platform.now += 2000;
    final again = await boot();
    expect(again.pet!.hunger, 1);
    expect(platform.queue, isEmpty);
  });

  test('the queue is acked before the widget sees the new snapshot', () async {
    final c = await withPet();
    platform.queue.add('{"id":"w2","type":"meal","at":${c.now + 1000}}');
    platform.now += 2000;
    platform.queueAtPublish = -1;
    await c.refresh();
    expect(platform.queueAtPublish, 0);
  });

  test('every accepted action saves and publishes', () async {
    final c = await withPet();
    final before = platform.publishes;
    await c.perform(const FeedSnack());
    expect(platform.publishes, before + 1);
    final disk = await SaveStore(dir).read();
    expect(disk!.pet!.happiness, 1);
  });

  test('overlapping actions and ticks never lose a change', () async {
    final c = await withPet();
    await Future.wait([
      c.perform(const FeedMeal()),
      c.refresh(),
      c.perform(const FeedSnack()),
      c.refresh(save: true),
      c.perform(const FeedMeal()),
    ]);
    expect(c.pet!.hunger, 2);
    expect(c.pet!.happiness, 1);
    final disk = await SaveStore(dir).read();
    expect(disk!.pet!.hunger, 2);
  });

  test('refused actions report why', () async {
    final c = await withPet();
    expect(await c.perform(const Clean()), Rejection.nothingToClean);
  });

  test('reminders stay empty until enabled, then follow the plan', () async {
    final c = await withPet();
    expect(platform.reminders, isEmpty);
    await c.enableNotifications();
    await c.perform(const FeedMeal());
    expect(platform.reminders, isNotEmpty);
    expect(platform.reminders.length, lessThanOrEqualTo(reminderSlots));
  });

  test('importing rubbish changes nothing; a good export round trips', () async {
    final c = await withPet();
    final exported = c.exportSave();
    await expectLater(c.importSave('rubbish'), throwsFormatException);
    expect(c.pet, isNotNull);
    await c.clearPet();
    await c.importSave(exported);
    expect(c.pet!.name, 'Pip');
  });
}
