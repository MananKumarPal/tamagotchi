import 'dart:async';

import 'package:flutter/material.dart';

import '../art/manifest.dart';
import '../art/shells.dart';
import '../art/sprites.dart';
import '../art/sticker.dart';
import '../domain/games.dart';
import '../domain/pet_state.dart';
import '../domain/rules.dart';
import '../game/game_controller.dart';
import 'kit.dart';
import 'strings.dart';

/// One screen, two rule sets: the session decides the prompt and the answers.
/// A finished game starts another until the player quits; quitting mid-game
/// sends nothing, so it has no effect on the pet.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Phase { asking, revealing, summary }

class _GameScreenState extends State<GameScreen> {
  final _confetti = GlobalKey<ConfettiState>();
  late GameSession _game;
  _Phase _phase = _Phase.asking;
  bool _lastWon = false;
  int _lastDirection = 0;
  Timer? _timer;
  final List<bool> _results = [];

  GameController get c => widget.controller;
  PetState get p => c.pet!;
  bool get _numbers => _game is NumberGame;

  @override
  void initState() {
    super.initState();
    _newSession();
  }

  void _newSession() {
    _game = GameSession.forProfile(p.profile, p.seed, p.gamesStarted);
    _phase = _Phase.asking;
    _results.clear();
  }

  void _answer(int side) {
    if (_phase != _Phase.asking) return;
    c.play(Cue.game);
    final g = _game;
    final RoundResult r;
    if (g is DirectionGame) {
      r = g.guess(side == 0 ? Direction.left : Direction.right);
      _lastDirection = r.revealed;
    } else {
      r = (g as NumberGame).guess(side == 0 ? Guess.lower : Guess.higher);
    }
    setState(() {
      _lastWon = r.won;
      _phase = _Phase.revealing;
      _results.add(r.won);
    });
    c.play(r.won ? Cue.confirm : Cue.lose);
    if (r.won) {
      final size = MediaQuery.of(context).size;
      _confetti.currentState?.burst(['spark'], Offset(size.width / 2, size.height * 0.4), count: 12);
    }
    _timer = Timer(const Duration(milliseconds: 1100), _next);
  }

  Future<void> _next() async {
    if (!mounted) return;
    if (!_game.done) {
      setState(() => _phase = _Phase.asking);
      return;
    }
    setState(() => _phase = _Phase.summary);
    if (_game.wonGame) {
      final size = MediaQuery.of(context).size;
      _confetti.currentState?.burst(['heart', 'spark', 'note'], size.center(Offset.zero), count: 36);
    }
    await c.perform(FinishGame(_game.wins));
  }

  Future<void> _again() async {
    final rejected = await c.perform(const StartGame());
    if (!mounted) return;
    if (rejected != null) {
      Navigator.of(context).pop();
      return;
    }
    setState(_newSession);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _line {
    final g = _game;
    if (_phase == _Phase.summary) {
      return g.wonGame ? '${g.wins} of ${Rules.gameRounds}. +1 joy!' : '${g.wins} of ${Rules.gameRounds}. so close.';
    }
    if (_phase == _Phase.revealing) return _lastWon ? 'yes!!' : 'nope.';
    return S.modeGame(p.profile);
  }

  Expression get _face => _phase == _Phase.asking
      ? Expression.normal
      : (_phase == _Phase.revealing ? _lastWon : _game.wonGame)
          ? Expression.happy
          : Expression.sad;

  Widget _pips() => Semantics(
        label: '${_results.where((r) => r).length} rounds won',
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < Rules.gameRounds; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: i >= _results.length
                    ? paper
                    : (_results[i] ? VibeTheme.of(context).shell.accent : ink),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ink, width: 3),
              ),
            ),
        ]),
      );

  Widget _arena() {
    final g = _game;
    final sticker = g is DirectionGame
        ? Transform.flip(
            flipX: _phase == _Phase.revealing && _lastDirection == Direction.right.index,
            child: Sticker(p.formId, expression: _face, size: 170),
          )
        : Sticker(p.formId, expression: _face, size: 110);
    if (g is NumberGame) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        sticker,
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: Duration(milliseconds: VibeTheme.of(context).reduced ? 0 : 280),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
          child: Chunk(
            key: ValueKey(g.current),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
            child: PixelText('${g.current}', size: 70),
          ),
        ),
      ]);
    }
    return sticker;
  }

  Widget _choice(int side, String text, List<String> icon) => Expanded(
        child: Gummy(
          onTap: _phase == _Phase.asking ? () => _answer(side) : null,
          semantic: text,
          color: VibeTheme.of(context).shell.accent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PixelIcon(icon, size: 28),
            const SizedBox(height: 4),
            Text(text, style: title),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SkyBackdrop(
        child: Confetti(
          key: _confetti,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Gummy(
                        onTap: () => Navigator.of(context).pop(),
                        semantic: 'Quit game',
                        padding: const EdgeInsets.all(9),
                        radius: 14,
                        child: const Icon(Icons.close_rounded, color: ink, size: 22),
                      ),
                      Expanded(child: Center(child: _pips())),
                      const SizedBox(width: 46),
                    ]),
                    const SizedBox(height: 24),
                    _arena(),
                    const SizedBox(height: 18),
                    Chunk(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      radius: 16,
                      shadow: 0,
                      child: Semantics(liveRegion: true, child: Text(_line, textAlign: TextAlign.center, style: body)),
                    ),
                    const SizedBox(height: 20),
                    if (_phase == _Phase.summary)
                      Row(children: [
                        Expanded(child: Cta('stop', quiet: true, onTap: () => Navigator.of(context).pop())),
                        const SizedBox(width: 12),
                        Expanded(child: Cta('play again', onTap: _again)),
                      ])
                    else
                      Row(children: [
                        _choice(0, _numbers ? 'lower' : 'left', propArt['arrow_left']!),
                        const SizedBox(width: 12),
                        _choice(1, _numbers ? 'higher' : 'right', propArt['arrow_right']!),
                      ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
