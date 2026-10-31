import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/shells.dart';
import '../art/sky.dart';
import '../art/sticker.dart';
import '../art/sprites.dart';
import '../domain/naming.dart';

/// Reads the player's flavour.
class VibeTheme extends InheritedWidget {
  const VibeTheme({super.key, required this.shell, required this.reduced, required super.child});

  final Shell shell;

  /// True when motion should stop: the OS setting or the in-app one.
  final bool reduced;

  static VibeTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VibeTheme>()!;

  @override
  bool updateShouldNotify(VibeTheme old) => old.shell != shell || old.reduced != reduced;
}

const body = TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w600, height: 1.3);
const label = TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.2);
const title = TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w900, height: 1.15);

/// The house surface: thick grape outline, hard shadow, big corners.
class Chunk extends StatelessWidget {
  const Chunk({
    super.key,
    required this.child,
    this.color = paper,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.shadow = 5,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final double radius;
  final double shadow;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: ink, width: 3),
          boxShadow: [BoxShadow(color: ink, offset: Offset(0, shadow))],
        ),
        child: child,
      );
}

/// A pressable block that sinks onto its own shadow.
class Gummy extends StatefulWidget {
  const Gummy({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.color = paper,
    this.semantic,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.radius = 20,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final String? semantic;
  final bool selected;
  final EdgeInsets padding;
  final double radius;

  @override
  State<Gummy> createState() => _GummyState();
}

class _GummyState extends State<Gummy> {
  bool _down = false;
  static const _depth = 5.0;

  void _set(bool v) {
    if (widget.onTap != null) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semantic,
      excludeSemantics: widget.semantic != null,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onLongPress: widget.onLongPress,
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onTap!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          margin: EdgeInsets.only(top: _down ? _depth : 0, bottom: _down ? 0 : _depth),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: enabled ? widget.color : Color.lerp(widget.color, const Color(0xFFB9B3C6), 0.7),
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: ink, width: 3),
            boxShadow: [BoxShadow(color: ink, offset: Offset(0, _down ? 0 : _depth))],
          ),
          // Size factors centre the child without growing to fill the space.
          child: Align(widthFactor: 1, heightFactor: 1, child: widget.child),
        ),
      ),
    );
  }
}

class Cta extends StatelessWidget {
  const Cta(this.text, {super.key, required this.onTap, this.quiet = false});

  final String text;
  final VoidCallback? onTap;
  final bool quiet;

  @override
  Widget build(BuildContext context) => Gummy(
        onTap: onTap,
        color: quiet ? paper : VibeTheme.of(context).shell.accent,
        semantic: text,
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w900)),
      );
}

/// One care action. [alert] makes it jump until the need is met.
class ActionKey extends StatefulWidget {
  const ActionKey({super.key, required this.icon, required this.text, required this.onTap, this.alert = false, this.hint, this.onHelp});

  final List<String> icon;
  final String text;
  final VoidCallback onTap;
  final bool alert;
  final String? hint;

  /// Long press explains the button: phones have no hover.
  final VoidCallback? onHelp;

  @override
  State<ActionKey> createState() => _ActionKeyState();
}

class _ActionKeyState extends State<ActionKey> with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ActionKey old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final on = widget.alert && !VibeTheme.of(context).reduced;
    if (on && !_wiggle.isAnimating) _wiggle.repeat();
    if (!on && _wiggle.isAnimating) {
      _wiggle
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vibe = VibeTheme.of(context).shell;
    return AnimatedBuilder(
      animation: _wiggle,
      builder: (context, child) {
        final t = _wiggle.value;
        final kick = t < 0.35 ? math.sin(t / 0.35 * math.pi * 3) * 0.06 : 0.0;
        return Transform.rotate(angle: kick, child: child);
      },
      child: Gummy(
        onTap: widget.onTap,
        onLongPress: widget.onHelp,
        color: widget.alert ? vibe.accent : paper,
        semantic: widget.hint == null ? widget.text : '${widget.text}. ${widget.hint}',
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
        radius: 18,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PixelIcon(widget.icon, size: 24),
          const SizedBox(height: 3),
          FittedBox(fit: BoxFit.scaleDown, child: Text(widget.text, maxLines: 1, style: label)),
        ]),
      ),
    );
  }
}

/// A four-segment meter drawn with pixel hearts.
class HeartMeter extends StatelessWidget {
  const HeartMeter({super.key, required this.name, required this.value});

  final String name;
  final int value;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$name $value of 4',
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(name, style: label),
          const SizedBox(width: 6),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(left: 1),
              child: AnimatedScale(
                scale: i < value ? 1 : 0.85,
                curve: Curves.elasticOut,
                duration: const Duration(milliseconds: 500),
                child: PixelIcon(propArt[i < value ? 'heart' : 'heart_empty']!, size: 15,
                    color: i < value ? const Color(0xFFFF4D8D) : ink.withValues(alpha: 0.35)),
              ),
            ),
        ]),
      );
}

/// Full-screen sky for the current local hour, with drifting pixel clouds by
/// day and twinkling stars by night.
class SkyBackdrop extends StatefulWidget {
  const SkyBackdrop({super.key, this.lightsOff = false, this.hourOverride, required this.child});

  final bool lightsOff;
  final int? hourOverride;
  final Widget child;

  @override
  State<SkyBackdrop> createState() => _SkyBackdropState();
}

class _SkyBackdropState extends State<SkyBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: const Duration(seconds: 60));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = VibeTheme.of(context).reduced;
    if (reduced && _drift.isAnimating) _drift.stop();
    if (!reduced && !_drift.isAnimating) _drift.repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vibe = VibeTheme.of(context).shell;
    final sky = skyFor(widget.hourOverride ?? DateTime.now().hour, lightsOff: widget.lightsOff);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (sky.night ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 900),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [skyMix(sky.top, vibe), skyMix(sky.bottom, vibe)],
          ),
        ),
        child: Stack(fit: StackFit.expand, children: [
          ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(painter: _SkyPainter(_drift, sky.night)),
            ),
          ),
          widget.child,
        ]),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.t, this.night) : super(repaint: t);

  final Animation<double> t;
  final bool night;

  static const _cloud = ['...###......', '..#####.##..', '.###########', '############'];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    if (night) {
      for (var i = 0; i < 42; i++) {
        final x = (i * 73 % 101) / 101 * size.width;
        final y = (i * 37 % 89) / 89 * size.height * 0.7;
        final twinkle = math.sin(t.value * math.pi * 40 + i) > 0.2;
        p.color = paper.withValues(alpha: twinkle ? 0.9 : 0.3);
        final s = i % 5 == 0 ? 4.0 : 2.0;
        canvas.drawRect(Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), s, s), p);
      }
      return;
    }
    p.color = paper.withValues(alpha: 0.75);
    for (var i = 0; i < 4; i++) {
      const u = 6.0;
      final span = size.width + 90;
      final x = (((t.value * (1 + i % 2)) + i * 0.27) % 1) * span - 80;
      final y = 60.0 + i * size.height * 0.13;
      for (var r = 0; r < _cloud.length; r++) {
        for (var c = 0; c < _cloud[r].length; c++) {
          if (_cloud[r][c] == '#') {
            canvas.drawRect(Rect.fromLTWH((x / u).floorToDouble() * u + c * u, y + r * u, u, u), p);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.night != night;
}

class _Bit {
  _Bit(this.prop, this.x, this.y, this.vx, this.vy, this.spin);
  final String prop;
  double x, y, vx, vy;
  final double spin;
}

/// Pixel confetti over the whole screen. Call [ConfettiState.burst].
class Confetti extends StatefulWidget {
  const Confetti({super.key, required this.child});
  final Widget child;

  @override
  State<Confetti> createState() => ConfettiState();
}

class ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(days: 1));
  final _bits = <_Bit>[];
  final _rand = math.Random();
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _clock.addListener(_step);
  }

  void burst(List<String> props, Offset origin, {int count = 18}) {
    if (VibeTheme.of(context).reduced) return;
    for (var i = 0; i < count; i++) {
      final a = _rand.nextDouble() * math.pi * 2;
      final v = 120 + _rand.nextDouble() * 280;
      _bits.add(_Bit(props[i % props.length], origin.dx, origin.dy, math.cos(a) * v,
          math.sin(a) * v - 240, _rand.nextDouble()));
    }
    if (!_clock.isAnimating) {
      _last = Duration.zero;
      _clock.forward(from: 0);
    }
  }

  void _step() {
    final now = _clock.lastElapsedDuration ?? Duration.zero;
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    for (final b in _bits) {
      b.vy += 900 * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
    }
    final h = context.size?.height ?? 2000;
    _bits.removeWhere((b) => b.y > h + 40);
    if (_bits.isEmpty) _clock.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        widget.child,
        IgnorePointer(child: ExcludeSemantics(child: CustomPaint(painter: _BitsPainter(_bits)))),
      ]);
}

class _BitsPainter extends CustomPainter {
  const _BitsPainter(this.bits);
  final List<_Bit> bits;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      paintProp(canvas, b.prop, 3, Offset(b.x, b.y));
    }
  }

  @override
  bool shouldRepaint(_BitsPainter old) => true;
}

/// Screens slide up with a little overshoot, or just appear under reduced motion.
Route<T> popRoute<T>(BuildContext context, WidgetBuilder builder) {
  final reduced = VibeTheme.of(context).reduced;
  return PageRouteBuilder<T>(
    transitionDuration: Duration(milliseconds: reduced ? 0 : 420),
    reverseTransitionDuration: Duration(milliseconds: reduced ? 0 : 220),
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, a, _, child) => SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn)),
      child: child,
    ),
  );
}

/// Bottom sheet in house style.
Future<T?> showChunkSheet<T>(BuildContext context, WidgetBuilder builder) {
  final theme = VibeTheme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: ink.withValues(alpha: 0.45),
    builder: (ctx) => VibeTheme(
      shell: theme.shell,
      reduced: theme.reduced,
      child: SafeArea(
        child: Padding(
          // Lifts the sheet above the keyboard when it holds a text field.
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Chunk(
            color: theme.shell.soft,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              Flexible(child: builder(ctx)),
            ]),
          ),
        ),
      ),
    ),
  );
}

/// Settings-style page: soft flavour colour, chunky back button.
class SoftPage extends StatelessWidget {
  const SoftPage({super.key, required this.heading, required this.child});

  final String heading;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: VibeTheme.of(context).shell.soft,
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                Gummy(
                  onTap: () => Navigator.of(context).pop(),
                  semantic: 'Back',
                  padding: const EdgeInsets.all(10),
                  radius: 14,
                  child: const Icon(Icons.arrow_back_rounded, color: ink, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Align(alignment: Alignment.centerLeft, child: PixelText(heading, size: 21))),
              ]),
            ),
            Expanded(child: child),
          ]),
        ),
      );
}


/// A pet's name in pixel type, or bold system type when the font can't draw it.
class NameText extends StatelessWidget {
  const NameText(this.name, {super.key, this.size = 21});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => fitsPixelFont(name)
      ? PixelText(name, size: size)
      : Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: title.copyWith(fontSize: size));
}

/// The one text field in the app, used for naming and renaming.
class NameField extends StatefulWidget {
  const NameField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onDone,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone;
  final bool autofocus;

  @override
  State<NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<NameField> {
  bool _touched = false;

  @override
  Widget build(BuildContext context) {
    final vibe = VibeTheme.of(context).shell;
    final problem = _touched ? nameProblem(widget.controller.text) : null;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: 3));
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      maxLength: maxNameLength,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      onChanged: (v) {
        setState(() => _touched = true);
        widget.onChanged(v);
      },
      onSubmitted: (_) {
        setState(() => _touched = true);
        widget.onDone();
      },
      cursorColor: ink,
      cursorWidth: 3,
      style: const TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: 'name',
        hintText: 'fig, noodle, biscuit...',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintStyle: body.copyWith(color: ink.withValues(alpha: 0.55), fontSize: 18),
        labelStyle: label,
        floatingLabelStyle: label,
        counterStyle: label,
        errorText: problem,
        errorStyle: label.copyWith(color: const Color(0xFFB3123F)),
        filled: true,
        fillColor: vibe.soft,
        enabledBorder: border(ink),
        focusedBorder: border(ink),
        errorBorder: border(const Color(0xFFB3123F)),
        focusedErrorBorder: border(const Color(0xFFB3123F)),
      ),
    );
  }
}

/// House confirmation. Returns true only if the player picks [confirm].
Future<bool> showChunkDialog(
  BuildContext context, {
  required String heading,
  required String message,
  required String confirm,
  required String cancel,
}) async {
  final theme = VibeTheme.of(context);
  final answer = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: ink.withValues(alpha: 0.55),
    transitionDuration: Duration(milliseconds: theme.reduced ? 0 : 240),
    transitionBuilder: (_, a, _, child) =>
        ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: child),
    pageBuilder: (ctx, _, _) => VibeTheme(
      shell: theme.shell,
      reduced: theme.reduced,
      child: SafeArea(
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Chunk(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Semantics(header: true, child: Text(heading, style: title.copyWith(fontSize: 22))),
                    const SizedBox(height: 6),
                    Text(message, style: body),
                    const SizedBox(height: 16),
                    // The safe choice is the loud one, so a reflex tap loses nothing.
                    Cta(cancel, onTap: () => Navigator.of(ctx).pop(false)),
                    const SizedBox(height: 6),
                    Cta(confirm, quiet: true, onTap: () => Navigator.of(ctx).pop(true)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return answer ?? false;
}

/// Shown after anything that finishes quietly: a saved rename, a failed import.
void showToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// House hour picker: the system clock dial is overkill for whole hours.
Future<int?> showHourSheet(BuildContext context, {required String heading, required int current}) {
  final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
  return showChunkSheet<int>(context, (ctx) {
    final vibe = VibeTheme.of(ctx).shell;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(heading, style: title),
      const SizedBox(height: 10),
      Flexible(
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          childAspectRatio: 1.7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 8,
          children: [
            for (var h = 0; h < 24; h++)
              Gummy(
                onTap: () => Navigator.of(ctx).pop(h),
                selected: h == current,
                color: h == current ? vibe.accent : paper,
                radius: 12,
                padding: EdgeInsets.zero,
                child: Text(formatHour(h, use24), style: label),
              ),
          ],
        ),
      ),
    ]);
  });
}

String formatHour(int h, bool use24) {
  if (use24) return '${h.toString().padLeft(2, '0')}:00';
  final twelve = h % 12 == 0 ? 12 : h % 12;
  return '$twelve${h < 12 ? 'am' : 'pm'}';
}
