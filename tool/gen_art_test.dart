// Generates the app icon and a sprite contact sheet.
// Run with: flutter test tool/gen_art_test.dart
// Then tool/install_icon.sh copies the icon into the iOS and Android projects.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:eggling/art/sticker.dart';
import 'package:eggling/art/manifest.dart';
import 'package:eggling/art/sprites.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> save(ui.Picture picture, int w, int h, String path) async {
  final image = await picture.toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  test('generate', () async {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    c.drawRect(const Rect.fromLTWH(0, 0, 1024, 1024), Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 1024), [const Color(0xFFFF6FA8), const Color(0xFF6A4DFF)]));
    paintSticker(c, StickerArt.of('egg', Expression.normal), bodyColor('egg'), 44, const Offset(160, 150));
    await save(recorder.endRecording(), 1024, 1024, 'build/art/icon.png');

    final ids = creatureArt.keys.toList();
    final faces = Expression.values;
    const cell = 6.0, box = 110.0;
    final sheet = ui.PictureRecorder();
    final s = Canvas(sheet);
    final w = box * faces.length, h = box * ids.length;
    s.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF58B4FF));
    for (final (row, id) in ids.indexed) {
      for (final (col, face) in faces.indexed) {
        paintSticker(s, StickerArt.of(id, face), bodyColor(id), cell, Offset(col * box + 7, row * box + 7));
      }
    }
    await save(sheet.endRecording(), w.toInt(), h.toInt(), 'build/art/contact_sheet.png');
  });
}
