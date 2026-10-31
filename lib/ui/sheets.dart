import 'package:flutter/material.dart';

import '../art/sprites.dart';
import '../art/sticker.dart';
import '../data/save_codec.dart';
import '../domain/naming.dart';
import '../domain/pet_state.dart';
import '../domain/rules.dart';
import '../game/game_controller.dart';
import 'kit.dart';
import 'strings.dart';

Future<Command?> showFeedSheet(BuildContext context, GameController c) {
  return showChunkSheet<Command>(context, (ctx) {
    final full = c.pet!.hunger >= Rules.maxHearts;
    Widget option(String prop, String name, String hint, Command command, {bool off = false}) => Expanded(
          child: Gummy(
            semantic: '$name. $hint',
            onTap: off ? null : () => Navigator.of(ctx).pop(command),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PixelIcon(propArt[prop]!, size: 64, color: propColors[prop]!),
              const SizedBox(height: 8),
              Text(name, style: title),
              const SizedBox(height: 2),
              Text(hint, textAlign: TextAlign.center, style: label),
            ]),
          ),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      option('meal', 'meal', full ? 'stuffed already' : '+1 food', const FeedMeal(), off: full),
      const SizedBox(width: 12),
      option('snack', 'snack', '+1 joy, more weight', const FeedSnack()),
    ]);
  });
}

Future<void> showStatusSheet(BuildContext context, GameController c) {
  return showChunkSheet<void>(context, (ctx) {
    final p = c.pet!;
    final unit = c.settings.unit == WeightUnit.oz ? 'oz' : 'g';
    Widget stat(String name, String value) => Expanded(
          child: Chunk(
            padding: const EdgeInsets.all(10),
            radius: 16,
            shadow: 0,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PixelText(value, size: 21),
              Text(name, style: label),
            ]),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Sticker(p.isEgg ? 'egg' : p.formId, size: 90),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.form.name, style: title),
            Text(p.form.blurb, style: body),
            Text(S.mode(p.profile), style: label),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        stat(p.age == 1 ? 'year' : 'years', '${p.age}'),
        const SizedBox(width: 8),
        stat(unit, '${p.weight}'),
        const SizedBox(width: 8),
        stat('discipline', '${p.discipline}%'),
      ]),
      const SizedBox(height: 10),
      HeartMeter(name: 'food', value: p.hunger),
      const SizedBox(height: 4),
      HeartMeter(name: 'joy', value: p.happiness),
      const SizedBox(height: 6),
    ]);
  });
}

Future<void> showTutorial(BuildContext context, GameController c) {
  return showChunkSheet<void>(context, (ctx) => const _Tutorial()).whenComplete(() {
    if (!c.settings.tutorialSeen) {
      c.updateSettings(c.settings.copyWith(tutorialSeen: true));
    }
  });
}

class _Tutorial extends StatefulWidget {
  const _Tutorial();

  @override
  State<_Tutorial> createState() => _TutorialState();
}

class _TutorialState extends State<_Tutorial> {
  int step = 0;

  @override
  Widget build(BuildContext context) {
    final (heading, text) = S.tutorial[step];
    final last = step == S.tutorial.length - 1;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(heading, style: title.copyWith(fontSize: 24)),
      const SizedBox(height: 6),
      ConstrainedBox(constraints: const BoxConstraints(minHeight: 72), child: Text(text, style: body)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Cta('skip', quiet: true, onTap: () => Navigator.of(context).pop())),
        const SizedBox(width: 10),
        Expanded(
          child: Cta(last ? 'got it' : 'next', onTap: () {
            if (last) {
              Navigator.of(context).pop();
            } else {
              setState(() => step++);
            }
          }),
        ),
      ]),
    ]);
  }
}

/// Rename, with the same field and rules as first naming.
Future<void> showRenameSheet(BuildContext context, GameController c) {
  return showChunkSheet<void>(context, (ctx) => _Rename(controller: c));
}

class _Rename extends StatefulWidget {
  const _Rename({required this.controller});
  final GameController controller;

  @override
  State<_Rename> createState() => _RenameState();
}

class _RenameState extends State<_Rename> {
  late final _name = TextEditingController(text: widget.controller.pet?.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (nameProblem(_name.text) != null) return;
    final navigator = Navigator.of(context);
    await widget.controller.rename(_name.text);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('rename your pet', style: title),
        const SizedBox(height: 12),
        NameField(controller: _name, autofocus: true, onChanged: (_) => setState(() {}), onDone: _save),
        const SizedBox(height: 8),
        Cta('save name', onTap: nameProblem(_name.text) == null ? _save : null),
      ]);
}

/// Tells the player what they missed. Without this, a pet can change form
/// while the app is closed and nobody ever says so.
Future<void> showAwaySheet(BuildContext context, GameController c, AwayReport r) {
  final name = c.pet?.name ?? 'your pet';
  return showChunkSheet<void>(context, (ctx) {
    final lines = [
      if (r.grewInto != null) '$name grew into ${withArticle(r.grewInto!)}!',
      if (r.fellSick) '$name got sick.',
      if (r.missedCalls > 0) '${counted(r.missedCalls, 'call', 'calls')} went unanswered.',
    ];
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('while you were gone', style: title),
      const SizedBox(height: 6),
      for (final line in lines) Text(line, style: body),
      const SizedBox(height: 12),
      Cta('ok', onTap: () => Navigator.of(ctx).pop()),
    ]);
  });
}
