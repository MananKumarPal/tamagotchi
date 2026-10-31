import 'dart:async';

import 'package:flutter/material.dart' hide Simulation;

import '../art/shells.dart';
import '../art/sprites.dart';
import '../art/sticker.dart';
import '../domain/naming.dart';
import '../domain/pet_state.dart';
import '../domain/projection.dart';
import '../domain/simulation.dart';
import '../game/game_controller.dart';
import 'ceremony.dart';
import 'departed_screen.dart';
import 'game_screen.dart';
import 'help_screen.dart';
import 'kit.dart';
import 'pet_stage.dart';
import 'settings_screen.dart';
import 'sheets.dart';
import 'strings.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with WidgetsBindingObserver {
  final _stage = GlobalKey<PetStageState>();
  final _confetti = GlobalKey<ConfettiState>();
  Timer? _ticker;
  StreamSubscription<PetEvent>? _sub;
  String? _message;
  bool _opening = false;
  Timer? _messageTimer;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _sub = c.events.listen(_onEvent);
    c.addListener(_handleRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleRoute();
      if (!c.settings.tutorialSeen && mounted) showTutorial(context, c);
    });
  }

  void _tick() {
    c.refresh();
    if (c.pet?.isEgg ?? false) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.paused) {
      c.refresh(save: true);
    }
  }

  Offset get _centre {
    final size = MediaQuery.of(context).size;
    return Offset(size.width / 2, size.height * 0.45);
  }

  void _party(List<String> props, {int count = 18}) =>
      _confetti.currentState?.burst(props, _centre, count: count);

  void _onEvent(PetEvent e) {
    if (!mounted || e.at < c.now - 5000) return;
    final name = c.pet?.name ?? '';
    switch (e.kind) {
      case EventKind.evolved:
        showCeremony(context, c, evolved: true);
      case EventKind.hatched:
        showCeremony(context, c, evolved: false);
      case EventKind.dosed when c.pet?.sick ?? false:
        _say('one more dose.');
      case EventKind.wasCured:
        _say('$name feels better.');
        _party(['spark', 'heart']);
      case EventKind.cleaned:
        _say('fresh.');
        _party(['spark'], count: 10);
      case EventKind.fedSnack:
        _party(['heart'], count: 8);
      case EventKind.fedMeal:
        _party(['spark'], count: 6);
      case EventKind.scolded:
        _say('$name got the message.');
      default:
        break;
    }
  }

  void _handleRoute() {
    final away = c.ready && mounted ? c.takeAwayReport() : null;
    if (away != null && !away.departed && (c.pet?.isDeparted == false)) {
      showAwaySheet(context, c, away);
    }
    final route = c.pendingRoute;
    if (route == null || !mounted || !c.ready) return;
    c.pendingRoute = null;
    Navigator.of(context).popUntil((r) => r.isFirst);
    switch (route) {
      case 'feed':
        _feed();
      case 'game':
        _game();
      case 'status':
        _stats();
    }
  }

  void _say(String text) {
    _messageTimer?.cancel();
    setState(() => _message = text);
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  Future<void> _do(Command command, {String? done}) async {
    final rejected = await c.perform(command);
    if (!mounted) return;
    final p = c.pet;
    if (rejected != null && p != null) {
      c.play(Cue.cancel);
      _say(S.rejection(rejected, p.name));
      if (!p.isAsleep && !p.isEgg) _stage.currentState?.react('sad');
    } else if (done != null) {
      _say(done);
    }
  }

  Future<void> _feed() async {
    final p = c.pet;
    if (p == null) return;
    final blocked = Simulation.check(p, const FeedSnack());
    if (blocked != null) {
      c.play(Cue.cancel);
      _say(S.rejection(blocked, p.name));
      return;
    }
    c.play(Cue.select);
    final choice = await showFeedSheet(context, c);
    if (choice != null) await _do(choice);
  }

  Future<void> _game() async {
    final p = c.pet;
    if (p == null || _opening) return;
    _opening = true;
    final rejected = await c.perform(const StartGame());
    if (!mounted) return;
    if (rejected != null) {
      _opening = false;
      c.play(Cue.cancel);
      _say(S.rejection(rejected, p.name));
      return;
    }
    await Navigator.of(context).push(popRoute<void>(context, (_) => GameScreen(controller: c)));
    _opening = false;
  }

  void _stats() {
    c.play(Cue.select);
    showStatusSheet(context, c);
  }

  void _lights() {
    final p = c.pet;
    if (p == null) return;
    _do(SetLights(!p.lightsOn), done: p.lightsOn ? 'light off.' : 'light on.');
  }

  void _open(Widget page) =>
      Navigator.of(context).push(popRoute<void>(context, (_) => page));

  void _explain() {
    final p = c.pet;
    if (p == null) return;
    _say(p.calls.isEmpty ? '${p.name} is good right now. hold any button to see what it does.' : S.call(p.calls.first.reason, p.name));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _messageTimer?.cancel();
    _sub?.cancel();
    c.removeListener(_handleRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final p = c.pet;
        if (p == null) return const SizedBox.shrink();
        if (p.isDeparted) return DepartedScreen(controller: c);
        final dark = p.isAsleep && !p.lightsOn;
        return Scaffold(
          body: SkyBackdrop(
            lightsOff: dark,
            child: Confetti(
              key: _confetti,
              child: SafeArea(
                child: LayoutBuilder(builder: (context, box) {
                  final wide = box.maxWidth > box.maxHeight;
                  final scene = _scene(p);
                  final dock = _dock(p);
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 820 : 500),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                        child: Column(children: [
                          _top(p),
                          const SizedBox(height: 8),
                          Expanded(
                            child: wide
                                ? Row(children: [
                                    Expanded(child: scene),
                                    const SizedBox(width: 12),
                                    Expanded(child: Center(child: SingleChildScrollView(child: dock))),
                                  ])
                                : Column(children: [Expanded(child: scene), dock]),
                          ),
                        ]),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _top(PetState p) => Chunk(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        radius: 20,
        shadow: 4,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Align(alignment: Alignment.centerLeft, child: NameText(p.name)),
              const SizedBox(height: 2),
              Wrap(spacing: 12, runSpacing: 2, children: [
                HeartMeter(name: 'food', value: p.hunger),
                HeartMeter(name: 'joy', value: p.happiness),
              ]),
            ]),
          ),
          const SizedBox(width: 6),
          Gummy(
            onTap: () => _open(SettingsScreen(controller: c)),
            semantic: 'Settings',
            padding: const EdgeInsets.all(9),
            radius: 14,
            child: const Icon(Icons.settings_rounded, color: ink, size: 22),
          ),
        ]),
      );

  Widget _scene(PetState p) {
    final text = _message ?? (p.isEgg ? _eggText(p) : statusHint(p));
    return Column(children: [
      const SizedBox(height: 6),
      _Bubble(text: text, urgent: p.isCalling && _message == null, onTap: _explain),
      Expanded(
        child: Stack(alignment: Alignment.bottomCenter, children: [
          PetStage(key: _stage, controller: c, onPetted: (at) {
            _confetti.currentState?.burst(['heart'], at, count: 5);
            _say(['hehe', 'more pls', 'ok ok', ':3'][c.now % 4]);
          }),
          if (p.poops.isNotEmpty)
            Positioned(
              right: 4,
              bottom: 8,
              child: Semantics(
                button: true,
                label: 'Clean ${counted(p.poops.length, 'mess', 'messes')}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => _do(const Clean()),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < p.poops.length; i++)
                      PixelIcon(propArt['poop']!, size: 30, color: propColors['poop']!),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _dock(PetState p) {
    if (p.isEgg) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Cta('hatch now', onTap: () => _do(const HatchNow())),
      );
    }
    Widget key(String icon, String text, VoidCallback onTap, {bool alert = false, String? hint}) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ActionKey(
              icon: menuIconArt[icon]!,
              text: text,
              onTap: onTap,
              alert: alert,
              hint: hint,
              onHelp: () => _say(S.glossary.firstWhere((g) => g.$1 == icon).$3),
            ),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (!c.settings.notificationsAsked) _nudge(p),
      Row(children: [
        key('food', 'feed', _feed, alert: p.hasCall(CallReason.hunger)),
        key('game', 'play', _game, alert: p.hasCall(CallReason.happiness)),
        key('clean', 'clean', () => _do(const Clean()), alert: p.poops.isNotEmpty),
        key('light', 'light', _lights, alert: p.hasCall(CallReason.lights), hint: p.lightsOn ? 'Turn off' : 'Turn on'),
      ]),
      Row(children: [
        key('medicine', 'meds', () => _do(const GiveMedicine()), alert: p.sick),
        key('scold', 'scold', () => _do(const Scold()), alert: p.misbehaving),
        key('meter', 'stats', _stats),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ActionKey(icon: pixelFont['?']!, text: 'help', onTap: () => _open(HelpScreen(controller: c))),
          ),
        ),
      ]),
    ]);
  }

  String _eggText(PetState p) {
    if (p.isPaused) return 'on pause';
    final left = ((p.hatchAt - c.now) / 1000).ceil().clamp(0, 300);
    return 'hatching in ${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
  }

  Widget _nudge(PetState p) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Chunk(
          padding: const EdgeInsets.all(10),
          radius: 18,
          shadow: 4,
          child: Column(children: [
            Text('want a nudge when ${p.name} calls? works offline, respects quiet hours.',
                textAlign: TextAlign.center, style: label),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Cta('nudge me', onTap: () => c.enableNotifications())),
              const SizedBox(width: 8),
              Expanded(child: Cta('not now', quiet: true, onTap: () => c.updateSettings(c.settings.copyWith(notificationsAsked: true)))),
            ]),
          ]),
        ),
      );
}

/// The pet's speech bubble. It pops in whenever the words change.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.urgent, required this.onTap});

  final String text;
  final bool urgent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = VibeTheme.of(context);
    return Semantics(
      liveRegion: true,
      button: true,
      label: text,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: theme.reduced ? 0 : 320),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
          child: Column(key: ValueKey(text), mainAxisSize: MainAxisSize.min, children: [
            Chunk(
              color: urgent ? theme.shell.accent : paper,
              radius: 18,
              shadow: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(text, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            CustomPaint(size: const Size(16, 9), painter: _Tail(urgent ? theme.shell.accent : paper)),
          ]),
        ),
      ),
    );
  }
}

class _Tail extends CustomPainter {
  const _Tail(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, -3)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, -3);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
        path,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_Tail old) => old.color != color;
}
