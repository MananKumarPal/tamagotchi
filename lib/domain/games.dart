import 'rules.dart';

enum Direction {
  left,
  right;

  Direction get opposite => this == left ? right : left;
}

enum Guess { lower, higher }

class RoundResult {
  const RoundResult(this.won, this.revealed);
  final bool won;

  /// [Direction.index] for the direction game, the next number otherwise.
  final int revealed;
}

/// One play of a mini-game, seeded from the pet so answers survive a restart
/// but differ per [index], which the simulation bumps on every [StartGame].
abstract class GameSession {
  GameSession(int seed, int index) : _seed = seed ^ (index * 0x5BD1E995);

  static GameSession forProfile(RuleProfile p, int seed, int index) =>
      p == RuleProfile.classicA ? DirectionGame(seed, index) : NumberGame(seed, index);

  final int _seed;
  int rounds = 0;
  int wins = 0;

  bool get done => rounds >= Rules.gameRounds;
  bool get wonGame => wins >= Rules.gameWinsNeeded;

  int draw(int n, int bound) {
    var z = (_seed + (n + 1) * 0x9E3779B9) & 0xFFFFFFFF;
    z = ((z ^ (z >> 15)) * 0x2C1B3C6D) & 0xFFFFFFFF;
    z = ((z ^ (z >> 12)) * 0x297A2D39) & 0xFFFFFFFF;
    return ((z ^ (z >> 15)) & 0xFFFFFFFF) % bound;
  }

  RoundResult record(bool won, int revealed) {
    rounds++;
    if (won) wins++;
    return RoundResult(won, revealed);
  }
}

/// Classic A: guess which way the pet will turn.
class DirectionGame extends GameSession {
  DirectionGame(super.seed, super.index);

  Direction get peekDirection => Direction.values[draw(rounds, 2)];

  RoundResult guess(Direction d) {
    final actual = peekDirection;
    return record(d == actual, actual.index);
  }
}

/// Classic B: guess whether the next number 1-9 is higher or lower. Each
/// reveal becomes the next round's number. A tie always wins.
class NumberGame extends GameSession {
  NumberGame(super.seed, super.index);

  int get current => rounds == 0 ? draw(100, 9) + 1 : _last;
  late int _last;

  int get peekNext => draw(rounds, 9) + 1;

  RoundResult guess(Guess g) {
    final now = current;
    final next = peekNext;
    final won = next == now || (g == Guess.higher ? next > now : next < now);
    _last = next;
    return record(won, next);
  }
}
