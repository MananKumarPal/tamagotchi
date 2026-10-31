import '../art/sprites.dart';

const int maxNameLength = 10;

String cleanName(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// What is wrong with [raw] as a pet name, or null if it is fine.
String? nameProblem(String raw) =>
    cleanName(raw).isEmpty ? 'your pet needs a name' : null;

/// The pixel font only has capitals, digits and some punctuation. Anything
/// else (accents, emoji, other scripts) must use system type or shows as `?`.
bool fitsPixelFont(String text) =>
    text.toUpperCase().split('').every(pixelFont.containsKey);

String withArticle(String noun) =>
    '${'aeiou'.contains(noun[0].toLowerCase()) ? 'an' : 'a'} $noun';

String counted(int n, String one, String many) => '$n ${n == 1 ? one : many}';
