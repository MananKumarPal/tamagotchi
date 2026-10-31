import 'package:eggling/domain/games.dart';
import 'package:eggling/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Classic A is a left/right game, Classic B is higher/lower', () {
    expect(GameSession.forProfile(RuleProfile.classicA, 1, 1), isA<DirectionGame>());
    expect(GameSession.forProfile(RuleProfile.classicB, 1, 1), isA<NumberGame>());
  });

  test('direction game: five rounds, correct guess wins the round', () {
    final g = DirectionGame(3, 1);
    for (var i = 0; i < 5; i++) {
      expect(g.done, isFalse);
      final r = g.guess(g.peekDirection);
      expect(r.won, isTrue);
    }
    expect(g.done, isTrue);
    expect(g.wins, 5);
    expect(g.wonGame, isTrue);
  });

  test('direction game: two wins is a loss', () {
    final g = DirectionGame(3, 1);
    for (var i = 0; i < 5; i++) {
      g.guess(i < 2 ? g.peekDirection : g.peekDirection.opposite);
    }
    expect(g.wins, 2);
    expect(g.wonGame, isFalse);
  });

  test('number game: numbers are 1-9 and chain from the last reveal', () {
    final g = NumberGame(5, 2);
    for (var i = 0; i < 5; i++) {
      expect(g.current, inInclusiveRange(1, 9));
      final next = g.peekNext;
      final r = g.guess(Guess.higher);
      expect(r.revealed, next);
      expect(g.current, next);
    }
  });

  test('number game: a tie wins whichever way you guessed', () {
    for (var seed = 0; seed < 200; seed++) {
      final g = NumberGame(seed, 1);
      if (g.peekNext != g.current) continue;
      expect(g.guess(Guess.lower).won, isTrue);
      return;
    }
    fail('no tie found');
  });

  test('sessions replay for the same seed and index, and differ by index', () {
    List<int> nums(int index) {
      final g = NumberGame(9, index);
      return [for (var i = 0; i < 5; i++) g.guess(Guess.higher).revealed];
    }
    expect(nums(1), nums(1));
    expect(nums(1), isNot(nums(2)));
  });
}
