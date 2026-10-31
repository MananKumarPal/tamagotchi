import '../domain/pet_state.dart';
import '../domain/rules.dart';

/// All player-facing copy, in one place so it can be translated. The voice is
/// lowercase and dry, but it always says what to do next.
class S {
  S._();

  static const appName = 'Eggling';
  static const modeA = 'Classic A';
  static const modeB = 'Classic B';

  static String mode(RuleProfile p) => p == RuleProfile.classicA ? modeA : modeB;

  static String modeGame(RuleProfile p) => p == RuleProfile.classicA
      ? 'guess which way your pet turns'
      : 'is the next number higher or lower?';

  static String modeSummary(RuleProfile p) => p == RuleProfile.classicA
      ? 'eleven creatures. plays left-or-right.'
      : 'eleven other creatures. plays higher-or-lower.';

  static String rejection(Rejection r, String name) => switch (r) {
        Rejection.notHatched => 'still an egg. give it a sec.',
        Rejection.departed => '$name has gone on.',
        Rejection.paused => 'care pause is on. turn it off in settings.',
        Rejection.asleep => 'shh, $name is asleep. only the light works.',
        Rejection.full => '$name is stuffed.',
        Rejection.misbehaving => '$name refuses. scold them first.',
        Rejection.nothingToClean => 'nothing to clean.',
        Rejection.notSick => '$name is not sick.',
        Rejection.notMisbehaving => '$name did nothing wrong.',
        Rejection.lightsAlready => 'the light is already like that.',
      };

  static String call(CallReason r, String name) => switch (r) {
        CallReason.hunger => '$name is starving. give a meal.',
        CallReason.happiness => '$name is sad. give a snack or play.',
        CallReason.lights => '$name fell asleep. turn the light off.',
        CallReason.misbehave => 'all hearts fine, still yelling. scold them.',
      };

  static String departure(PetState p) {
    final years = '${p.age} ${p.age == 1 ? 'year' : 'years'}';
    final how = switch (p.deathCause) {
      DeathCause.oldAge => 'a long, full life',
      DeathCause.starvation => 'too long without food',
      DeathCause.illness => 'an illness nobody treated',
      null => 'a small life',
    };
    final where = p.profile == RuleProfile.classicA
        ? 'floated off above the clouds'
        : 'went home in a tiny saucer';
    return '${p.name} $where.\n$years old, after $how.';
  }

  static const privacy =
      'your pet, its history and your settings are stored only on this phone, '
      'in the app\'s private storage and in a small shared file the home-screen '
      'widget reads.\n\n'
      'eggling has no account, ads or analytics, and never sends anything over '
      'the network. exporting a save creates a file that goes wherever you send '
      'it. nothing else leaves the device.';

  static String aboutMode(RuleProfile p) =>
      '${mode(p)} follows published descriptions of a 1990s handheld pet rule '
      'set. ${modeSummary(p)}\n\n'
      'taken from those descriptions: four hearts that start empty, 15-minute '
      'call windows, meal and snack effects, baby timings, sleep times, the '
      'evolution chart, and five-round games needing three wins.\n\n'
      'eggling\'s own estimates, because no reliable number exists: how fast '
      'hearts fall after the baby stage, how long neglect takes to be fatal, '
      'lifespan, medicine doses after the baby stage, and how often an older '
      'pet acts up.\n\n'
      'not modelled: anniversary rerelease behaviour, such as snacks that '
      'shorten life.\n\n'
      'time keeps running while the app is closed. care pause in settings stops '
      'it completely, and age and evolution wait too. changing the phone\'s '
      'clock does not undo care mistakes.';

  static const glossary = <(String, String, String)>[
    ('food', 'feed', 'meal fills a hunger heart. snack fills a joy heart and adds more weight.'),
    ('game', 'play', 'win three of five rounds for a joy heart. every finished game burns off a little weight.'),
    ('clean', 'clean', 'clears all the mess. leave it too long and your pet can get ill.'),
    ('light', 'light', 'turn it off after your pet falls asleep.'),
    ('medicine', 'meds', 'give them when your pet looks sick, until it clears.'),
    ('scold', 'scold', 'only for yelling with nothing wrong. at other times it does nothing.'),
    ('meter', 'stats', 'age, weight, discipline and hearts.'),
  ];

  static const tutorial = <(String, String)>[
    ('it lives on real time', 'your pet grows and gets hungry even with the app closed. the sky matches your actual day.'),
    ('read the bubble', 'the speech bubble says what your pet wants. buttons that matter right now start jumping.'),
    ('15 minutes to answer', 'calls you miss become care mistakes. they shape what your pet becomes and how long it lives.'),
    ('scold bad behaviour', 'sometimes it yells with full hearts, or refuses food. scold it then, and only then.'),
    ('light off at bedtime', 'when your pet falls asleep, tap light. it comes back on by itself.'),
  ];
}
