import 'package:eggling/art/sticker.dart';
import 'package:eggling/art/manifest.dart';
import 'package:eggling/art/sprites.dart';
import 'package:eggling/domain/forms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final forms = [...classicA.forms, ...classicB.forms];

  test('every form in both rosters has art', () {
    for (final f in forms) {
      expect(creatureArt, contains(f.id), reason: f.id);
    }
  });

  creatureArt.forEach((id, rows) {
    test('$id is exactly 16x16 with a face', () {
      expect(rows.length, 16, reason: id);
      for (final (i, r) in rows.indexed) {
        expect(r.length, 16, reason: '$id row $i');
      }
      if (id != 'egg') {
        expect(rows.join().contains('e'), isTrue);
        expect(rows.join().contains('m'), isTrue);
      }
    });
  });

  test('all creature silhouettes are different drawings', () {
    final seen = creatureArt.values.map((r) => r.join()).toSet();
    expect(seen.length, creatureArt.length);
  });

  test('every expression changes the face and stays on the grid', () {
    for (final id in creatureArt.keys.where((k) => k != 'egg')) {
      final faces = {
        for (final e in Expression.values)
          (creatureCells(id, e).map((c) => c.x * 100 + c.y).toList()..sort()).join()
      };
      expect(faces.length, greaterThanOrEqualTo(5), reason: id);
    }
  });

  test('manifest props all exist and required states are present', () {
    for (final state in animationManifest.values) {
      for (final f in state.frames) {
        if (f.prop != null) expect(propArt, contains(f.prop), reason: state.name);
      }
    }
    expect(animationManifest.keys, containsAll([
      'idle', 'call', 'eatMeal', 'eatSnack', 'happy', 'sad', 'dance', 'poop',
      'sleep', 'wake', 'sick', 'medicine', 'evolve', 'departedA', 'departedB',
    ]));
  });

  test('an unknown animation falls back to idle', () {
    expect(animationFor('nope').name, 'idle');
  });

  test('prop rows are rectangular and font glyphs are 5x7', () {
    propArt.forEach((k, rows) {
      expect(rows.map((r) => r.length).toSet().length, 1, reason: k);
    });
    menuIconArt.forEach((k, rows) {
      expect(rows.length, 12, reason: k);
      expect(rows.every((r) => r.length == 12), isTrue, reason: k);
    });
    pixelFont.forEach((k, rows) {
      expect(rows.length, 7, reason: k);
      expect(rows.every((r) => r.length == 5), isTrue, reason: k);
    });
  });
}
