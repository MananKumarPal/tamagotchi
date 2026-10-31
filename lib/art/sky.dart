import 'package:flutter/material.dart';

import 'shells.dart';

/// The sky behind everything follows the player's real local time.
class SkyPalette {
  const SkyPalette(this.top, this.bottom, this.night);

  final Color top;
  final Color bottom;
  final bool night;
}

const _dawn = SkyPalette(Color(0xFFFF9EC4), Color(0xFFFFD98E), false);
const _day = SkyPalette(Color(0xFF58B4FF), Color(0xFFCDBBFF), false);
const _dusk = SkyPalette(Color(0xFFFF6FA8), Color(0xFF6A4DFF), false);
const _night = SkyPalette(Color(0xFF150B2E), Color(0xFF3F1F86), true);
const _lightsOff = SkyPalette(Color(0xFF0B0619), Color(0xFF1B1033), true);

SkyPalette skyFor(int hour, {bool lightsOff = false}) {
  if (lightsOff) return _lightsOff;
  if (hour >= 5 && hour < 8) return _dawn;
  if (hour >= 8 && hour < 17) return _day;
  if (hour >= 17 && hour < 20) return _dusk;
  return _night;
}

Color skyMix(Color c, Shell s) => Color.lerp(c, s.accent, 0.12)!;
