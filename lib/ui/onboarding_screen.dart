import 'dart:math';

import 'package:flutter/material.dart';

import '../art/shells.dart';
import '../art/sticker.dart';
import '../domain/naming.dart';
import '../domain/rules.dart';
import '../game/game_controller.dart';
import 'kit.dart';
import 'strings.dart';

/// First launch and every new egg: rules, flavour, name, then into the room.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller, required this.onShell});

  final GameController controller;
  final ValueChanged<Shell> onShell;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

const _names = ['Pip', 'Moss', 'Button', 'Sprocket', 'Biscuit', 'Tumble', 'Fig', 'Noodle'];

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  int step = 0;
  RuleProfile profile = RuleProfile.classicA;
  Shell shell = shells.first;
  bool _starting = false;
  final _name = TextEditingController();
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (VibeTheme.of(context).reduced) {
      _bob.stop();
    } else if (!_bob.isAnimating) {
      _bob.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bob.dispose();
    super.dispose();
  }

  void _pickShell(Shell s) {
    widget.controller.play(Cue.select);
    setState(() => shell = s);
    widget.onShell(s);
  }

  void _surprise() {
    final r = Random();
    profile = RuleProfile.values[r.nextInt(2)];
    _pickShell(shells[r.nextInt(shells.length)]);
    _name.text = _names[r.nextInt(_names.length)];
    setState(() => step = 3);
  }

  Future<void> _hatch() async {
    if (nameProblem(_name.text) != null || _starting) return;
    _starting = true;
    FocusManager.instance.primaryFocus?.unfocus();
    widget.controller.play(Cue.confirm);
    await widget.controller.startNewEgg(profile: profile, shell: shell.id, name: _name.text);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(step - 1);
      },
      child: Scaffold(
      body: SkyBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: VibeTheme.of(context).reduced ? 0 : 260),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                  child: KeyedSubtree(key: ValueKey(step), child: _step()),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _step() => switch (step) {
        0 => _welcome(),
        1 => _rules(),
        2 => _flavours(),
        _ => _naming(),
      };

  void _back(int to) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => step = to);
  }

  Widget _nav(int back, String next, VoidCallback? onNext) => Row(children: [
        Expanded(child: Cta('back', quiet: true, onTap: () => _back(back))),
        const SizedBox(width: 10),
        Expanded(child: Cta(next, onTap: onNext)),
      ]);

  Widget _welcome() => Column(mainAxisSize: MainAxisSize.min, children: [
        const PixelText('EGGLING', size: 49, color: paper),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _bob,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -14 * Curves.easeInOut.transform(_bob.value)),
            child: child,
          ),
          child: const Sticker('egg', size: 190),
        ),
        const SizedBox(height: 14),
        Chunk(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('a tiny pet that lives on your real time. it gets hungry when the app is closed. '
                'no account, no wifi needed.', textAlign: TextAlign.center, style: body),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Cta('surprise me', quiet: true, onTap: _surprise)),
              const SizedBox(width: 10),
              Expanded(child: Cta('start', onTap: () => setState(() => step = 1))),
            ]),
          ]),
        ),
      ]);

  Widget _rules() {
    Widget option(RuleProfile p, String sticker) {
      final on = profile == p;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Gummy(
          selected: on,
          semantic: '${S.mode(p)}. ${S.modeSummary(p)}',
          color: on ? shell.accent : paper,
          onTap: () {
            widget.controller.play(Cue.select);
            setState(() => profile = p);
          },
          child: Row(children: [
            Sticker(sticker, size: 72),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(S.mode(p), style: title),
                Text(S.modeSummary(p), style: body.copyWith(fontSize: 14)),
              ]),
            ),
          ]),
        ),
      );
    }

    return Chunk(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PixelText('PICK YOUR\nRULES', size: 28),
        const SizedBox(height: 4),
        const Text('how you raise it decides what it becomes.', style: body),
        const SizedBox(height: 12),
        option(RuleProfile.classicA, 'lumo'),
        option(RuleProfile.classicB, 'aurelle'),
        _nav(0, 'next', () => setState(() => step = 2)),
      ]),
    );
  }

  Widget _flavours() => Chunk(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PixelText('PICK A\nFLAVOUR', size: 28),
          const SizedBox(height: 4),
          const Text('just the colours. your care decides what hatches.', style: body),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: [
              for (final s in shells)
                Gummy(
                  selected: s == shell,
                  semantic: '${s.name} flavour',
                  color: s.accent,
                  padding: const EdgeInsets.all(4),
                  onTap: () => _pickShell(s),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (s == shell) const Icon(Icons.check_rounded, color: ink, size: 22),
                    Text(s.name, textAlign: TextAlign.center, style: label),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _nav(1, 'next', () => setState(() => step = 3)),
        ]),
      );

  Widget _naming() => Chunk(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PixelText('NAME IT', size: 28),
          const SizedBox(height: 4),
          const Text('it hatches in about five minutes, or skip the wait.', style: body),
          const SizedBox(height: 12),
          NameField(controller: _name, onChanged: (_) => setState(() {}), onDone: _hatch),
          const SizedBox(height: 8),
          _nav(2, 'start the egg', nameProblem(_name.text) != null ? null : _hatch),
        ]),
      );
}
