import 'dart:io';

import 'save_codec.dart';

/// Crash-safe storage for the authoritative save. A write lands in a temp file
/// and renames over the old one, whose contents are kept as `save.bak`.
class SaveStore {
  SaveStore(this.dir);

  final Directory dir;

  File get _main => File('${dir.path}/save.json');
  File get _backup => File('${dir.path}/save.bak');
  File get _temp => File('${dir.path}/save.json.tmp');

  Future<void> write(SaveFile save) async {
    await _temp.writeAsString(SaveCodec.encode(save), flush: true);
    if (_main.existsSync()) await _main.rename(_backup.path);
    await _temp.rename(_main.path);
  }

  /// The newest readable save, or null when there has never been one.
  Future<SaveFile?> read() async {
    for (final file in [_main, _backup]) {
      if (!file.existsSync()) continue;
      try {
        return SaveCodec.decode(await file.readAsString());
      } on FormatException {
        continue;
      }
    }
    return null;
  }
}
