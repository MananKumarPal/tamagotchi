import 'package:flutter/material.dart';

/// Colour flavours. Cosmetic only: the choice never affects what hatches.
class Shell {
  const Shell(this.id, this.name, this.accent, this.soft);

  final String id;
  final String name;

  /// The loud colour: primary buttons, alerts, celebration.
  final Color accent;

  /// A pale version for cards and quiet surfaces.
  final Color soft;
}

const Color ink = Color(0xFF1B1033);
const Color paper = Color(0xFFFFFFFF);

const List<Shell> shells = [
  Shell('mint', 'Soda', Color(0xFF3DF5C0), Color(0xFFD8FFF2)),
  Shell('coral', 'Peach Ring', Color(0xFFFF8A5C), Color(0xFFFFE6DA)),
  Shell('plum', 'Grape Jelly', Color(0xFFB08CFF), Color(0xFFEDE4FF)),
  Shell('lemon', 'Sour Lime', Color(0xFFD4FF3A), Color(0xFFF5FFD0)),
  Shell('sky', 'Blue Raz', Color(0xFF5B9DFF), Color(0xFFDDEBFF)),
  Shell('pebble', 'Bubblegum', Color(0xFFFF6FC1), Color(0xFFFFE0F2)),
];

Shell shellById(String id) =>
    shells.firstWhere((s) => s.id == id, orElse: () => shells.first);
