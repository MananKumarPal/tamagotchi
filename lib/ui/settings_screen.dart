import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/save_codec.dart';
import '../domain/pet_state.dart';
import '../domain/rules.dart';
import '../game/game_controller.dart';
import '../art/shells.dart';
import 'kit.dart';
import 'help_screen.dart';
import 'sheets.dart';
import 'strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final GameController controller;

  GameController get c => controller;

  static const devTools = bool.fromEnvironment('DEV_TOOLS');

  Future<void> _export(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      final dir = await getTemporaryDirectory();
      final name = c.pet?.name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '') ?? 'pet';
      final file = File('${dir.path}/eggling-${name.isEmpty ? 'pet' : name}.json');
      await file.writeAsString(c.exportSave());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        // iPads anchor the share popover here, and crash without it.
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } on Object {
      if (context.mounted) showToast(context, 'export failed. check your storage and try again.');
    }
  }

  Future<void> _import(BuildContext context) async {
    final name = c.pet?.name;
    if (name != null) {
      final yes = await showChunkDialog(
        context,
        heading: 'replace $name?',
        message: 'importing swaps $name for the pet in the file. export first if you want to keep them.',
        confirm: 'choose a file',
        cancel: 'keep $name',
      );
      if (!yes) return;
    }
    final picked = await FilePicker.pickFiles();
    final path = picked.firstOrNull?.path;
    if (path == null) return;
    String? outcome;
    try {
      await c.importSave(await File(path).readAsString());
      outcome = 'save imported.';
    } on FormatException catch (e) {
      outcome = 'nothing changed. ${e.message}.'.toLowerCase();
    } on FileSystemException {
      outcome = 'that file could not be read. nothing changed.';
    }
    if (context.mounted) showToast(context, outcome);
  }

  Future<void> _reset(BuildContext context) async {
    final name = c.pet?.name;
    if (name == null) return;
    final yes = await showChunkDialog(
      context,
      heading: 'start a new egg?',
      message: 'this removes $name for good. export a save first if you might want them back.',
      confirm: 'remove $name',
      cancel: 'keep $name',
    );
    if (!yes) return;
    await c.clearPet();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _pickHour(BuildContext context, String heading, int current, ValueChanged<int> done) async {
    final h = await showHourSheet(context, heading: heading, current: current);
    if (h != null) done(h);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.settings;
        final p = c.pet;
        final accent = VibeTheme.of(context).shell.accent;
        final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
        final quietOff = s.quietStartHour == s.quietEndHour;
        Widget sw(String name, String? sub, bool v, ValueChanged<bool> on) => SwitchListTile(
              title: Text(name, style: body),
              subtitle: sub == null ? null : Text(sub, style: label.copyWith(fontWeight: FontWeight.w500)),
              value: v,
              onChanged: on,
              activeThumbColor: ink,
              activeTrackColor: accent,
            );
        Widget tile(String name, String? sub, VoidCallback onTap) => ListTile(
              title: Text(name, style: body),
              subtitle: sub == null ? null : Text(sub, style: label.copyWith(fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.chevron_right_rounded, color: ink),
              onTap: onTap,
            );
        Widget group(String name, List<Widget> rows) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Semantics(header: true, child: Text(name, style: title.copyWith(fontSize: 16))),
                ),
                Chunk(padding: const EdgeInsets.symmetric(vertical: 4), radius: 20, shadow: 4, child: Material(type: MaterialType.transparency, child: Column(children: rows))),
              ]),
            );
        void go(Widget page) => Navigator.of(context).push(popRoute<void>(context, (_) => page));
        return SoftPage(
          heading: 'SETTINGS',
          child: ListView(children: [
            group('sound and motion', [
              sw('sound', null, s.soundOn, (v) => c.updateSettings(s.copyWith(soundOn: v))),
              sw('reduce motion', 'holds the pet still, skips confetti', s.reducedMotion,
                  (v) => c.updateSettings(s.copyWith(reducedMotion: v))),
            ]),
            group('nudges', [
              sw('care reminders', 'sent by this phone, no network', s.notificationsOn, (v) async {
                if (v) {
                  final ok = await c.enableNotifications();
                  if (!ok && context.mounted) {
                    showToast(context, 'reminders are blocked. allow notifications for eggling in your phone\'s settings.');
                  }
                } else {
                  await c.updateSettings(s.copyWith(notificationsOn: false));
                }
              }),
              tile('quiet from', formatHour(s.quietStartHour, use24),
                  () => _pickHour(context, 'quiet from', s.quietStartHour, (h) => c.updateSettings(s.copyWith(quietStartHour: h)))),
              tile('quiet until', quietOff ? 'same as start, so quiet hours are off' : formatHour(s.quietEndHour, use24),
                  () => _pickHour(context, 'quiet until', s.quietEndHour, (h) => c.updateSettings(s.copyWith(quietEndHour: h)))),
            ]),
            group('game', [
              sw('weight in grams', 'otherwise ounces', s.unit == WeightUnit.g,
                  (v) => c.updateSettings(s.copyWith(unit: v ? WeightUnit.g : WeightUnit.oz))),
              if (p != null) ...[
                tile('rename', p.name, () => showRenameSheet(context, c)),
                sw('care pause', 'stops time completely. age, hunger and evolution all wait.', p.isPaused,
                    (v) => c.perform(SetPaused(v))),
                tile('about this mode', S.mode(p.profile), () => go(TextPage(heading: 'THIS MODE', text: S.aboutMode(p.profile)))),
              ],
            ]),
            group('your data', [
              Builder(builder: (ctx) => tile('export save', 'creates a file you can keep', () => _export(ctx))),
              tile('import save', 'replaces the current pet', () => _import(context)),
              tile('privacy', null, () => go(const TextPage(heading: 'PRIVACY', text: S.privacy))),
              tile('start a new egg', 'removes the current pet', () => _reset(context)),
            ]),
            if ((kDebugMode || devTools) && p != null)
              group('developer', [
                tile('seed ${p.seed}', p.formId, () {}),
                tile('skip 10 minutes', null, () => c.addDevSkew(10 * minuteMs)),
                tile('skip 1 hour', null, () => c.addDevSkew(hourMs)),
                tile('skip 12 hours', null, () => c.addDevSkew(12 * hourMs)),
                tile('skip 1 day', null, () => c.addDevSkew(dayMs)),
              ]),
          ]),
        );
      },
    );
  }
}
