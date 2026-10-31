import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/manifest.dart';
import '../art/shells.dart';
import '../art/sticker.dart';
import '../domain/naming.dart';
import '../game/game_controller.dart';
import 'kit.dart';

/// Hatch and evolution: rays spin up, the old form shakes, then the new one
/// bursts out with confetti.
Future<void> showCeremony(BuildContext context, GameController c, {required bool evolved}) {
  final theme = VibeTheme.of(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: ink.withValues(alpha: 0.9),
    transitionDuration: Duration(milliseconds: theme.reduced ? 0 : 200),
    pageBuilder: (_, _, _) => VibeTheme(
      shell: theme.shell,
      reduced: theme.reduced,
      child: _Ceremony(controller: c, evolved: evolved),
    ),
  );
}

class _Ceremony extends StatefulWidget {
  const _Ceremony({required this.controller, required this.evolved});

  final GameController controller;
  final bool evolved;

  @override
  State<_Ceremony> createState() => _CeremonyState();
}

class _CeremonyState extends State<_Ceremony> with TickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 12));
  late final AnimationController _reveal =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  final _confetti = GlobalKey<ConfettiState>();
  bool _burst = false;

  @override
  void initState() {
    super.initState();
    _reveal.addListener(() {
      if (!_burst && _reveal.value > 0.62) {
        _burst = true;
        final size = MediaQuery.of(context).size;
        _confetti.currentState?.burst(['spark', 'heart', 'note'], size.center(Offset.zero), count: 44);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (VibeTheme.of(context).reduced) {
      _reveal.value = 1;
    } else if (!_spin.isAnimating && _reveal.value == 0) {
      _spin.repeat();
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.controller.pet!;
    final vibe = VibeTheme.of(context).shell;
    return Material(
      type: MaterialType.transparency,
      child: Confetti(
        key: _confetti,
        child: AnimatedBuilder(
          animation: Listenable.merge([_spin, _reveal]),
          builder: (context, _) {
            final t = _reveal.value;
            final out = t > 0.62;
            final pop = out ? Curves.elasticOut.transform(((t - 0.62) / 0.38).clamp(0, 1)) : 1.0;
            final shake = out ? 0.0 : math.sin(t * 90) * t * 7;
            return Stack(fit: StackFit.expand, children: [
              ExcludeSemantics(child: CustomPaint(painter: _Rays(_spin.value, vibe.accent, t))),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Transform.translate(
                        offset: Offset(shake, 0),
                        child: Transform.scale(
                          scale: pop,
                          child: Sticker(out ? p.formId : (widget.evolved ? p.formId : 'egg'),
                              expression: out ? Expression.happy : Expression.normal, size: 200),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedOpacity(
                        opacity: out ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Chunk(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              if (widget.evolved) const PixelText('GLOW UP!', size: 28) else NameText('hi ${p.name}', size: 28),
                              const SizedBox(height: 6),
                              Text('${p.name} is ${withArticle(p.form.name)}. ${p.form.blurb}', textAlign: TextAlign.center, style: body),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: Cta('continue', onTap: out ? () => Navigator.of(context).pop() : null),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Rays extends CustomPainter {
  const _Rays(this.turn, this.color, this.strength);
  final double turn;
  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide;
    final p = Paint()..color = color.withValues(alpha: (strength * 1.5).clamp(0, 1) * 0.85);
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turn * math.pi * 2);
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(math.cos(a) * r, math.sin(a) * r)
            ..lineTo(math.cos(a + 0.3) * r, math.sin(a + 0.3) * r)
            ..close(),
          p);
    }
  }

  @override
  bool shouldRepaint(_Rays old) => true;
}
