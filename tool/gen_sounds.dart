// Generates the original square-wave cues in assets/sounds.
// Run with: dart run tool/gen_sounds.dart
import 'dart:io';
import 'dart:typed_data';

const rate = 22050;

/// Each cue is a list of (frequency Hz, milliseconds). Frequency 0 is a rest.
const cues = <String, List<(int, int)>>{
  'select': [(1760, 30)],
  'confirm': [(1320, 45), (1976, 70)],
  'cancel': [(988, 45), (659, 80)],
  'call': [(2093, 90), (0, 50), (2093, 90), (0, 50), (2093, 130)],
  'eat': [(523, 60), (0, 40), (587, 60), (0, 40), (659, 90)],
  'happy': [(1047, 70), (1319, 70), (1568, 70), (2093, 140)],
  'sick': [(392, 140), (370, 140), (349, 220)],
  'medicine': [(880, 60), (1175, 60), (880, 60), (1397, 120)],
  'evolve': [(523, 90), (659, 90), (784, 90), (1047, 90), (1319, 90), (1568, 220)],
  'death': [(784, 220), (659, 220), (523, 260), (392, 520)],
  'game': [(1175, 50), (1568, 70)],
  'lose': [(494, 110), (392, 180)],
};

Uint8List wav(List<(int, int)> notes) {
  final samples = BytesBuilder();
  for (final (freq, ms) in notes) {
    final n = rate * ms ~/ 1000;
    for (var i = 0; i < n; i++) {
      final high = freq > 0 && (i * freq * 2 ~/ rate).isOdd;
      final fade = n - i < 80 ? (n - i) / 80 : 1.0;
      samples.addByte(freq == 0 ? 128 : (128 + (high ? 48 : -48) * fade).round());
    }
  }
  final data = samples.takeBytes();
  final h = ByteData(44);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      h.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  h.setUint32(4, 36 + data.length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  h.setUint32(16, 16, Endian.little);
  h.setUint16(20, 1, Endian.little);
  h.setUint16(22, 1, Endian.little);
  h.setUint32(24, rate, Endian.little);
  h.setUint32(28, rate, Endian.little);
  h.setUint16(32, 1, Endian.little);
  h.setUint16(34, 8, Endian.little);
  tag(36, 'data');
  h.setUint32(40, data.length, Endian.little);
  return (BytesBuilder()
        ..add(h.buffer.asUint8List())
        ..add(data))
      .takeBytes();
}

void main() {
  cues.forEach((name, notes) {
    File('assets/sounds/$name.wav').writeAsBytesSync(wav(notes));
  });
}
