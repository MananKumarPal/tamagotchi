import 'dart:convert';

import 'pet_state.dart';
import 'projection.dart';

/// The JSON contract shared with the native widgets. Documented in
/// docs/widgets.md; Swift and Kotlin readers must follow [schema] changes.
class WidgetCodec {
  WidgetCodec._();

  static const int schema = 1;

  static String encodeEmpty({required int seq}) => jsonEncode(
      {'schema': schema, 'seq': seq, 'pet': null, 'entries': <Object>[]});

  static String encodeSnapshot(PetState s, int offsetMinutes,
      {required int seq, String accent = '#D4FF3A', String soft = '#EDE4FF'}) {
    final entries = Projection.timeline(s, offsetMinutes);
    return jsonEncode({
      'schema': schema,
      'seq': seq,
      'pet': {
        'id': s.id,
        'name': s.name,
        'form': s.form.name,
        'shell': s.shell,
        'accent': accent,
        'soft': soft,
      },
      'entries': [
        for (final e in entries)
          {
            'at': e.at,
            'pose': e.pose,
            'hint': e.hint,
            'hunger': e.hunger,
            'happy': e.happiness,
            'asleep': e.asleep,
            'calling': e.calling,
            'sick': e.sick,
            'poops': e.poops,
            'canFeed': e.canFeed,
            'canPlay': e.canPlay,
          }
      ],
    });
  }

  static Command? _command(String type) => switch (type) {
        'meal' => const FeedMeal(),
        'snack' => const FeedSnack(),
        'clean' => const Clean(),
        _ => null,
      };

  /// One JSON object per line from the native queue, oldest first. Lines this
  /// version cannot read are dropped rather than wedging the queue.
  static List<WidgetAction> decodeActions(List<String> lines) {
    final actions = <WidgetAction>[];
    for (final line in lines) {
      try {
        final j = jsonDecode(line) as Map<String, dynamic>;
        final command = _command(j['type'] as String);
        if (command == null) continue;
        actions.add(WidgetAction(j['id'] as String, command, j['at'] as int));
      } on Object {
        continue;
      }
    }
    return actions..sort((a, b) => a.at.compareTo(b.at));
  }
}
