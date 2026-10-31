import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/manifest.dart';
import '../art/shells.dart';
import '../art/sticker.dart';
import '../domain/pet_state.dart';
import '../domain/projection.dart';
import '../domain/rules.dart';
import '../game/game_controller.dart';
import 'kit.dart';

String ambientAnimation(PetState p) {
  if (p.isDeparted) {
    return p.profile == RuleProfile.classicA ? 'departedA' : 'departedB';
  }
  if (p.isAsleep) return 'sleep';
  if (p.sick) return 'sick';
  if (p.isCalling) return 'call';
  return 'idle';
}

String? reactionFor(EventKind kind) => switch (kind) {
      EventKind.fedMeal => 'eatMeal',
      EventKind.fedSnack => 'eatSnack',
      EventKind.gameWon || EventKind.wasCured || EventKind.hatched => 'happy',
      EventKind.gameLost || EventKind.scolded => 'sad',
      EventKind.pooped => 'poop',
      EventKind.woke => 'wake',
      EventKind.dosed => 'medicine',
      EventKind.evolved => 'evolve',
      _ => null,
    };

/// The living pet: plays the manifest, breathes, and squashes on every beat.
class PetStage extends StatefulWidget {
  const PetStage({super.key, required this.controller, this.onPetted});

  final GameController controller;

  /// Tapping the pet is pure affection and has no game effect.
  final ValueChanged<Offset>? onPetted;

  @override
  State<PetStage> createState() => PetStageState();
}

class PetStageState extends State<PetStage> with TickerProviderStateMixin {
  late final AnimationController _breath =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _boing =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650), value: 1);
  Timer? _timer;
  StreamSubscription<PetEvent>? _sub;
  String? _oneShot;
  int _frame = 0;
  String _playing = 'idle';

  GameController get c => widget.controller;

  void react(String name) {
    if (!mounted) return;
    setState(() {
      _oneShot = name;
      _frame = 0;
    });
    _boing.forward(from: 0);
    _schedule();
  }

  @override
  void initState() {
    super.initState();
    _sub = c.events.listen((e) {
      if (e.at < c.now - 5000) return;
      final r = reactionFor(e.kind);
      if (r != null) react(r);
    });
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = VibeTheme.of(context).reduced;
    if (reduced) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat();
    }
  }

  void _schedule() {
    _timer?.cancel();
    final state = animationFor(_oneShot ?? _playing);
    _timer = Timer.periodic(Duration(milliseconds: state.frameMs), (_) => _step());
  }

  void _step() {
    final p = c.pet;
    if (!mounted || p == null) return;
    final state = animationFor(_oneShot ?? _playing);
    setState(() {
      _frame++;
      if (_frame >= state.frames.length) {
        _frame = 0;
        if (state.oneShot) _oneShot = null;
      }
    });
    final next = _oneShot ?? ambientAnimation(p);
    if (next != _playing) {
      _playing = next;
      _frame = 0;
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _breath.dispose();
    _boing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = VibeTheme.of(context).reduced;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final p = c.pet;
        if (p == null) return const SizedBox.shrink();
        final egg = p.isEgg;
        final name = egg ? 'idle' : (_oneShot ?? ambientAnimation(p));
        _playing = _oneShot ?? (egg ? 'idle' : ambientAnimation(p));
        final state = animationFor(name);
        final frames = state.frames;
        final frame = egg
            ? const AnimFrame(Expression.normal)
            : reduced
                ? (state.oneShot ? frames[frames.length ~/ 2] : frames.first)
                : frames[_frame % frames.length];
        final shake = egg && !reduced ? (_frame % 4 == 1 ? 1 : (_frame % 4 == 3 ? -1 : 0)) : 0;
        return Semantics(
          label: '${p.name}, ${p.form.name}. ${statusHint(p)}.',
          image: true,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              if (p.isAsleep || p.isDeparted) return;
              _boing.forward(from: 0);
              widget.onPetted?.call(d.globalPosition);
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([_breath, _boing]),
              builder: (context, _) {
                final breathe = reduced ? 0.0 : math.sin(_breath.value * math.pi * 2) * 0.025;
                final b = _boing.value;
                final boing = reduced ? 0.0 : math.sin(b * math.pi * 3) * (1 - b) * 0.22;
                return CustomPaint(
                  painter: _StagePainter(
                    formId: egg ? 'egg' : p.formId,
                    frame: frame,
                    shake: shake,
                    squash: breathe + boing,
                    dim: p.isAsleep && !p.lightsOn ? 0.45 : 0,
                    sick: p.sick,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _StagePainter extends CustomPainter {
  const _StagePainter({
    required this.formId,
    required this.frame,
    required this.shake,
    required this.squash,
    required this.dim,
    required this.sick,
  });

  final String formId;
  final AnimFrame frame;
  final int shake;
  final double squash;
  final double dim;
  final bool sick;

  @override
  void paint(Canvas canvas, Size size) {
    final u = (math.min(size.width, size.height) / 24).floorToDouble().clamp(3.0, 16.0);
    final cx = size.width / 2, floor = size.height - u * 2.5;
    final shadowWidth = u * 13 * (1 - frame.dy.abs() * 0.05);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, floor + u * 0.6), width: shadowWidth, height: u * 2.2),
        Paint()..color = ink.withValues(alpha: 0.28));
    canvas.save();
    // Squash pivots on the feet so the pet stays planted.
    canvas.translate(cx + (frame.dx + shake) * u, floor + frame.dy * u);
    canvas.scale(1 - squash, 1 + squash);
    final art = StickerArt.of(formId, frame.expression, flip: frame.flip);
    final origin = Offset(-8 * u, -15.5 * u);
    final tint = sick ? Color.lerp(bodyColor(formId), const Color(0xFF9FD18B), 0.6)! : bodyColor(formId);
    paintSticker(canvas, art, tint, u, origin, dim: dim);
    canvas.restore();
    final prop = frame.prop;
    if (prop != null) {
      final o = Offset(cx - 8 * u + frame.px * u, floor - 15.5 * u + frame.py * u);
      // Food stays big enough to read; little effects stay little.
      final food = prop.startsWith('meal') || prop.startsWith('snack');
      paintProp(canvas, prop, food ? u : (u * 0.6).floorToDouble(), o);
    }
  }

  @override
  bool shouldRepaint(_StagePainter old) => true;
}
