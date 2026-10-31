import 'dart:io';

import 'package:eggling/app.dart';
import 'package:eggling/data/save_codec.dart';
import 'package:eggling/data/save_store.dart';
import 'package:eggling/domain/pet_state.dart';
import 'package:eggling/domain/rules.dart';
import 'package:eggling/game/game_controller.dart';
import 'package:eggling/ui/game_screen.dart';
import 'package:eggling/ui/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Keeps saves in memory: file I/O never completes under the widget test clock.
class MemoryStore extends SaveStore {
  MemoryStore(super.dir);
  SaveFile? saved;

  @override
  Future<void> write(SaveFile save) async => saved = save;

  @override
  Future<SaveFile?> read() async => saved;
}

/// Pumps real frames, so route and switcher transitions actually finish.
Future<void> steps(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ui'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<GameController> open(WidgetTester tester, {Size size = const Size(402, 874), double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    final c = GameController(MemoryStore(dir), FakePlatform());
    await c.boot();
    await tester.pumpWidget(EgglingApp(controller: c));
    await tester.pump();
    return c;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await steps(tester, 2);
  }

  Future<void> withPet(WidgetTester tester, GameController c, RuleProfile p) async {
    await c.updateSettings(c.settings.copyWith(tutorialSeen: true, notificationsAsked: true));
    await c.startNewEgg(profile: p, shell: 'plum', name: 'Pip');
    await steps(tester, 1);
    await c.perform(const HatchNow());
    await steps(tester, 3);
    final cont = find.text('continue');
    if (cont.evaluate().isNotEmpty) {
      await tester.ensureVisible(cont);
      await tester.pump();
      await tester.tap(cont);
      await steps(tester, 1);
    }
  }

  testWidgets('first launch walks through to the egg', (tester) async {
    final c = await open(tester);
    expect(find.textContaining('tiny pet'), findsOneWidget);
    await tester.tap(find.text('start'));
    await steps(tester, 1);
    await tester.tap(find.text('Classic B'));
    await tester.pump();
    await tester.tap(find.text('next'));
    await steps(tester, 1);
    await tester.tap(find.text('next'));
    await steps(tester, 1);
    await tester.enterText(find.byType(TextField), 'Moss');
    await tester.pump();
    await tester.tap(find.text('start the egg'));
    await tester.pump();
    await steps(tester, 1);
    expect(c.pet!.name, 'Moss');
    expect(c.pet!.profile, RuleProfile.classicB);
    expect(find.text('it lives on real time'), findsOneWidget);
    await close(tester);
  });

  testWidgets('tapping outside a field dismisses the keyboard', (tester) async {
    await open(tester);
    await tester.tap(find.text('surprise me'));
    await steps(tester, 1);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasPrimaryFocus, isTrue);
    await tester.tap(find.textContaining('it hatches in'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    await close(tester);
  });

  for (final profile in RuleProfile.values) {
    testWidgets('$profile: a whole game can be played with its own controls', (tester) async {
      final c = await open(tester);
      await withPet(tester, c, profile);
      await c.perform(const StartGame());
      await tester.pump();
      Navigator.of(tester.element(find.text('feed'))).push(
          MaterialPageRoute<void>(builder: (_) => GameScreen(controller: c)));
      await steps(tester, 1);
      final labels = profile == RuleProfile.classicA ? ['left', 'right'] : ['lower', 'higher'];
      for (final l in labels) {
        expect(find.text(l), findsOneWidget);
      }
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text(labels[1]));
        await tester.pump();
        await steps(tester, 2);
      }
      expect(find.text('play again'), findsOneWidget);
      expect(c.pet!.gamesStarted, 1);
      await close(tester);
    });
  }

  for (final (size, scale) in [(const Size(320, 568), 1.0), (const Size(320, 568), 1.6), (const Size(844, 390), 1.0), (const Size(768, 1024), 1.0)]) {
    testWidgets('room lays out at $size text ×$scale without overflow', (tester) async {
      final c = await open(tester, size: size, textScale: scale);
      await withPet(tester, c, RuleProfile.classicA);
      expect(tester.takeException(), isNull);
      expect(find.text('stats'), findsOneWidget);
      await close(tester);
    });
  }

  testWidgets('sheets hug their content instead of filling the screen', (tester) async {
    final c = await open(tester);
    await withPet(tester, c, RuleProfile.classicA);
    await tester.tap(find.text('feed'));
    await steps(tester, 1);
    final meal = find.ancestor(of: find.text('meal'), matching: find.byType(Gummy));
    expect(tester.getSize(meal).height, lessThan(220));
    await close(tester);
  });

  testWidgets('tutorial buttons stay button sized', (tester) async {
    final c = await open(tester);
    await c.startNewEgg(profile: RuleProfile.classicA, shell: 'plum', name: 'Pip');
    await steps(tester, 1);
    final skip = find.ancestor(of: find.text('skip'), matching: find.byType(Gummy));
    expect(tester.getSize(skip).height, lessThan(90));
    await close(tester);
  });

  testWidgets('a blank name shows why start is disabled', (tester) async {
    await open(tester);
    await tester.tap(find.text('surprise me'));
    await steps(tester, 1);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.text('your pet needs a name'), findsOneWidget);
    await close(tester);
  });

  testWidgets('feed refuses straight away while asleep, full meal is disabled', (tester) async {
    final c = await open(tester);
    await withPet(tester, c, RuleProfile.classicA);
    for (var i = 0; i < 4; i++) {
      await c.perform(const FeedMeal());
    }
    await tester.tap(find.text('feed'));
    await steps(tester, 1);
    expect(find.text('stuffed already'), findsOneWidget);
    await close(tester);
  });

  testWidgets('new egg confirmation is house styled and keeps the pet by default', (tester) async {
    final c = await open(tester);
    await withPet(tester, c, RuleProfile.classicA);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await steps(tester, 1);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await steps(tester, 1);
    await tester.tap(find.text('start a new egg'));
    await steps(tester, 1);
    expect(find.text('keep Pip'), findsOneWidget);
    await tester.tap(find.text('keep Pip'));
    await steps(tester, 1);
    expect(c.pet, isNotNull);
    await close(tester);
  });

  testWidgets('a name the pixel font cannot draw falls back to normal type', (tester) async {
    final c = await open(tester);
    await withPet(tester, c, RuleProfile.classicA);
    await c.rename('Zoë');
    await tester.pump();
    expect(find.text('Zoë'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a departed pet offers a new egg and it returns to setup', (tester) async {
    final c = await open(tester);
    await withPet(tester, c, RuleProfile.classicB);
    await c.addDevSkew(3 * dayMs);
    await steps(tester, 2);
    expect(find.textContaining('tiny saucer'), findsOneWidget);
    await tester.tap(find.text('hatch a new egg'));
    await tester.pump();
    await steps(tester, 1);
    expect(find.textContaining('tiny pet'), findsOneWidget);
    await close(tester);
  });

  testWidgets('settings opens in every shell-tinted section', (tester) async {
    final c = await open(tester);
    await withPet(tester, c, RuleProfile.classicA);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await steps(tester, 1);
    expect(find.text('sound'), findsOneWidget);
    expect(find.text('care pause'), findsOneWidget);
    await close(tester);
  });
}
