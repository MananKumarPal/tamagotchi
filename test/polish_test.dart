import 'dart:io';

import 'package:eggling/data/save_store.dart';
import 'package:eggling/domain/naming.dart';
import 'package:eggling/domain/pet_state.dart';
import 'package:eggling/domain/reminders.dart';
import 'package:eggling/domain/rules.dart';
import 'package:eggling/domain/widget_codec.dart';
import 'package:eggling/game/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  group('names', () {
    test('cleaning trims and collapses spaces', () {
      expect(cleanName('  Big   Pip '), 'Big Pip');
    });

    test('blank names are invalid, others valid', () {
      expect(nameProblem('   '), isNotNull);
      expect(nameProblem('Zoë'), isNull);
    });

    test('pixel font check spots characters it cannot draw', () {
      expect(fitsPixelFont('Pip 2'), isTrue);
      expect(fitsPixelFont('Zoë'), isFalse);
      expect(fitsPixelFont('🐣'), isFalse);
    });

    test('articles and plurals read properly', () {
      expect(withArticle('Aurelle'), 'an Aurelle');
      expect(withArticle('Old Tobb'), 'an Old Tobb');
      expect(withArticle('Mote'), 'a Mote');
      expect(counted(1, 'mess', 'messes'), '1 mess');
      expect(counted(2, 'mess', 'messes'), '2 messes');
    });
  });

  test('reminders use the pet name', () {
    expect(reminderText(CallReason.hunger, 'Pip'), contains('Pip'));
  });

  test('snapshot carries the flavour colours', () {
    final s = WidgetCodec.encodeSnapshot(raise(newEgg(), clock(0, 12)), 0, seq: 1, accent: '#FF8A5C', soft: '#FFE6DA');
    expect(s, contains('#FF8A5C'));
  });

  group('controller', () {
    late Directory dir;
    late FakePlatform platform;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('pol');
      platform = FakePlatform();
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Future<GameController> boot() async {
      final c = GameController(SaveStore(dir), platform);
      await c.boot();
      return c;
    }

    Future<GameController> keepAlive() async {
      final c = await boot();
      await c.startNewEgg(profile: RuleProfile.classicA, shell: 'mint', name: 'Pip');
      await c.perform(const HatchNow());
      await c.perform(const FeedMeal());
      await c.perform(const FeedSnack());
      return c;
    }

    test('rename cleans the name and saves it', () async {
      final c = await keepAlive();
      await c.rename('  New   Name ');
      expect(c.pet!.name, 'New Name');
      expect((await SaveStore(dir).read())!.pet!.name, 'New Name');
    });

    test('coming back after a while gives a report of what happened', () async {
      await keepAlive();
      platform.now += 2 * hourMs;
      final again = await boot();
      final report = again.takeAwayReport();
      expect(report, isNotNull);
      expect(report!.grewInto, isNotNull);
      expect(report.missedCalls, greaterThan(0));
      expect(again.takeAwayReport(), isNull);
    });

    test('a quick reopen stays quiet', () async {
      await keepAlive();
      platform.now += 30 * 1000;
      final again = await boot();
      expect(again.takeAwayReport(), isNull);
    });
  });
}
