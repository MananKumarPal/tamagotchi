import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'manifest.dart';
import 'shells.dart';
import 'sprites.dart';

typedef Cell = ({int x, int y});

List<Cell> _cells(List<String> rows, {String on = '#'}) => [
      for (var y = 0; y < rows.length; y++)
        for (var x = 0; x < rows[y].length; x++)
          if (on.contains(rows[y][x])) (x: x, y: y),
    ];

/// Pixels of a creature with its face redrawn for [e].
List<Cell> creatureCells(String formId, Expression e, {bool flip = false}) {
  final art = creatureArt[formId] ?? creatureArt['egg']!;
  final out = <Cell>[..._cells(art)];
  final eyes = _cells(art, on: 'e');
  final mouth = _cells(art, on: 'm');
  if (eyes.isNotEmpty) {
    final top = eyes.map((c) => c.y).reduce((a, b) => a < b ? a : b);
    final upper = eyes.where((c) => c.y == top);
    final lower = eyes.where((c) => c.y != top);
    switch (e) {
      case Expression.normal || Expression.chew || Expression.shout:
        out.addAll(eyes);
      case Expression.blink || Expression.sleeping:
        out.addAll(lower);
      case Expression.happy:
        out.addAll(upper);
        for (final c in upper) {
          out.add((x: c.x - 1, y: c.y + 1));
          out.add((x: c.x + 1, y: c.y + 1));
        }
      case Expression.sad:
        out.addAll(lower);
        for (final c in upper) {
          out.add((x: c.x + 1, y: c.y - 1));
        }
      case Expression.sick:
        for (final c in upper) {
          out.add((x: c.x - 1, y: c.y));
          out.add((x: c.x + 1, y: c.y));
          out.add((x: c.x, y: c.y + 1));
        }
    }
  }
  switch (e) {
    case Expression.shout:
      out.addAll(mouth);
      out.addAll(mouth.map((c) => (x: c.x, y: c.y + 1)));
    case Expression.chew || Expression.sleeping:
      if (mouth.isNotEmpty) out.add(mouth.first);
    case Expression.sad || Expression.sick:
      out.addAll(mouth.map((c) => (x: c.x, y: c.y + 1)));
    default:
      out.addAll(mouth);
  }
  return flip ? [for (final c in out) (x: 15 - c.x, y: c.y)] : out;
}

List<Cell> propCells(String name) => _cells(propArt[name] ?? const []);

List<Cell> textCells(String text, {int x = 0, int y = 0}) {
  final out = <Cell>[];
  var cx = x;
  for (final ch in text.toUpperCase().split('')) {
    final glyph = pixelFont[ch] ?? pixelFont['?']!;
    for (final c in _cells(glyph)) {
      out.add((x: cx + c.x, y: y + c.y));
    }
    cx += 6;
  }
  return out;
}

const List<Color> _bodyColors = [
  Color(0xFFFFD36E), Color(0xFF9CF0D2), Color(0xFFFFA8D5), Color(0xFFB9C7FF),
  Color(0xFFFFB38A), Color(0xFFD8F36B), Color(0xFFC9A6FF), Color(0xFF8FE3FF),
];

/// Each creature keeps its own colour, whichever flavour the player picked.
Color bodyColor(String formId) {
  if (formId == 'egg') return const Color(0xFFFFF4E0);
  if (formId == 'old_tobb' || formId == 'nocto') return const Color(0xFF8C7BA8);
  return _bodyColors[formId.codeUnits.fold(7, (a, b) => a * 31 + b) % _bodyColors.length];
}

Set<Cell> _dilate(Set<Cell> cells) => {
      for (final c in cells)
        for (var dx = -1; dx <= 1; dx++)
          for (var dy = -1; dy <= 1; dy++) (x: c.x + dx, y: c.y + dy),
    };

/// Cells enclosed by [ink], found by flooding in from outside the sprite.
Set<Cell> _interior(Set<Cell> ink) {
  const min = -1, max = 17;
  final outside = <Cell>{};
  final open = <Cell>[(x: min, y: min)];
  while (open.isNotEmpty) {
    final c = open.removeLast();
    if (c.x < min || c.x > max || c.y < min || c.y > max) continue;
    if (ink.contains(c) || !outside.add(c)) continue;
    open.addAll([(x: c.x + 1, y: c.y), (x: c.x - 1, y: c.y), (x: c.x, y: c.y + 1), (x: c.x, y: c.y - 1)]);
  }
  return {
    for (var x = 0; x < 16; x++)
      for (var y = 0; y < 16; y++)
        if (!ink.contains((x: x, y: y)) && !outside.contains((x: x, y: y))) (x: x, y: y)
  };
}

/// One creature as layered cells: white die-cut edge, body, blush, ink line.
class StickerArt {
  StickerArt._(this.edge, this.body, this.blush, this.line);

  factory StickerArt.of(String formId, Expression e, {bool flip = false}) {
    final key = '$formId/${e.name}/$flip';
    return _cache[key] ??= () {
      final line = creatureCells(formId, e, flip: flip).toSet();
      final body = _interior(line);
      final eyes = _cells(creatureArt[formId] ?? const [], on: 'e');
      final blush = <Cell>{};
      if (eyes.isNotEmpty && e != Expression.sick) {
        final low = eyes.map((c) => c.y).reduce((a, b) => a > b ? a : b);
        final xs = eyes.map((c) => c.x).toList()..sort();
        for (final c in [(x: xs.first - 1, y: low + 1), (x: xs.last + 1, y: low + 1)]) {
          final at = flip ? (x: 15 - c.x, y: c.y) : c;
          if (body.contains(at)) blush.add(at);
        }
      }
      return StickerArt._(_dilate({...line, ...body}), body, blush, line);
    }();
  }

  static final _cache = <String, StickerArt>{};

  final Set<Cell> edge;
  final Set<Cell> body;
  final Set<Cell> blush;
  final Set<Cell> line;
}

const Map<String, Color> propColors = {
  'heart': Color(0xFFFF4D8D),
  'meal': Color(0xFFFFC24D),
  'meal_half': Color(0xFFFFC24D),
  'snack': Color(0xFFFF8AC4),
  'snack_half': Color(0xFFFF8AC4),
  'sick': Color(0xFF7BE05A),
  'zed': paper,
  'spark': Color(0xFFFFE14D),
  'note': Color(0xFF7C5CFF),
  'sweat': Color(0xFF5BC8FF),
  'pill': Color(0xFFFF6B6B),
  'halo': Color(0xFFFFE14D),
  'saucer': Color(0xFF9CF0D2),
  'poop': Color(0xFFC08552),
};

void _fill(Canvas canvas, Iterable<Cell> cells, double u, Offset o, Color color) {
  final p = Paint()
    ..isAntiAlias = false
    ..color = color;
  for (final c in cells) {
    canvas.drawRect(Rect.fromLTWH(o.dx + c.x * u, o.dy + c.y * u, u + 0.5, u + 0.5), p);
  }
}

void paintProp(Canvas canvas, String prop, double u, Offset o) {
  final cells = propCells(prop).toSet();
  if (cells.isEmpty) return;
  _fill(canvas, _dilate(cells), u, o, paper.withValues(alpha: prop == 'zed' ? 0.0 : 1));
  _fill(canvas, cells, u, o, propColors[prop] ?? ink);
}

void paintSticker(Canvas canvas, StickerArt art, Color body, double u, Offset o, {double dim = 0}) {
  Color d(Color c) => Color.lerp(c, const Color(0xFF0B0619), dim)!;
  _fill(canvas, art.edge, u, o + Offset(0, u * 1.2), ink.withValues(alpha: 0.25));
  _fill(canvas, art.edge, u, o, d(paper));
  _fill(canvas, art.body, u, o, d(body));
  _fill(canvas, art.blush, u, o, d(const Color(0xFFFF8FB0)));
  _fill(canvas, art.line, u, o, d(ink));
}

/// A static, cheap sticker. Used for icons, cards and previews.
class Sticker extends StatelessWidget {
  const Sticker(this.formId, {super.key, this.expression = Expression.normal, this.size = 96});

  final String formId;
  final Expression expression;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size.square(size),
      painter: _StickerPainter(StickerArt.of(formId, expression), bodyColor(formId)));
}

class _StickerPainter extends CustomPainter {
  const _StickerPainter(this.art, this.body);
  final StickerArt art;
  final Color body;

  @override
  void paint(Canvas canvas, Size size) {
    final u = (size.width / 18).floorToDouble();
    paintSticker(canvas, art, body, u, Offset(u, u));
  }

  @override
  bool shouldRepaint(_StickerPainter old) => old.art != art;
}

/// A fixed sprite from [rows], used for menu icons and props.
class PixelIcon extends StatelessWidget {
  const PixelIcon(this.rows, {super.key, this.size = 36, this.color = ink});

  final List<String> rows;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _IconPainter(rows, color));
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.rows, this.color);
  final List<String> rows;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final cell = (size.width / width).floorToDouble();
    final ox = ((size.width - cell * width) / 2).floorToDouble();
    final oy = ((size.height - cell * rows.length) / 2).floorToDouble();
    _fill(canvas, _cells(rows), cell, Offset(ox, oy), color);
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.rows != rows || old.color != color;
}

/// Display type: the 5x7 pixel font, as big as you like.
class PixelText extends StatelessWidget {
  const PixelText(this.text, {super.key, this.size = 28, this.color = ink});

  final String text;

  /// Height of one line in logical pixels.
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widest = lines.map((l) => l.length).reduce((a, b) => a > b ? a : b);
    final u = (size / 7).floorToDouble().clamp(1.0, 64.0);
    return Semantics(
      label: text.replaceAll('\n', ' '),
      header: true,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: CustomPaint(
          size: Size(widest * 6 * u, lines.length * 9 * u),
          painter: _TextPainter(lines, u, color),
        ),
      ),
    );
  }
}

class _TextPainter extends CustomPainter {
  const _TextPainter(this.lines, this.u, this.color);
  final List<String> lines;
  final double u;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (i, line) in lines.indexed) {
      _fill(canvas, textCells(line, y: i * 9), u, Offset.zero, color);
    }
  }

  @override
  bool shouldRepaint(_TextPainter old) => old.lines != lines || old.color != color;
}

/// PNG of a sticker on transparency, for the native home-screen widgets.
Future<Uint8List> creaturePng(String formId, Expression e,
    {int scale = 8, String? prop, int px = 0, int py = 0}) async {
  final recorder = ui.PictureRecorder();
  final size = 24.0 * scale;
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
  final u = scale.toDouble();
  final o = Offset(4 * u, 6 * u);
  paintSticker(canvas, StickerArt.of(formId, e), bodyColor(formId), u, o);
  if (prop != null) paintProp(canvas, prop, u, o + Offset(px * u, py * u));
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
