import 'dart:convert';

import '../domain/pet_state.dart';
import '../domain/rules.dart';

enum WeightUnit { oz, g }

class Settings {
  const Settings({
    this.soundOn = true,
    this.notificationsOn = false,
    this.notificationsAsked = false,
    this.quietStartHour = 22,
    this.quietEndHour = 7,
    this.reducedMotion = false,
    this.unit = WeightUnit.oz,
    this.tutorialSeen = false,
    this.classicClockPause = false,
  });

  factory Settings.fromJson(Map<String, dynamic> j) {
    const d = Settings();
    return Settings(
      soundOn: j['soundOn'] as bool? ?? d.soundOn,
      notificationsOn: j['notificationsOn'] as bool? ?? d.notificationsOn,
      notificationsAsked: j['notificationsAsked'] as bool? ?? d.notificationsAsked,
      quietStartHour: j['quietStartHour'] as int? ?? d.quietStartHour,
      quietEndHour: j['quietEndHour'] as int? ?? d.quietEndHour,
      reducedMotion: j['reducedMotion'] as bool? ?? d.reducedMotion,
      unit: WeightUnit.values.asNameMap()[j['unit']] ?? d.unit,
      tutorialSeen: j['tutorialSeen'] as bool? ?? d.tutorialSeen,
      classicClockPause: j['classicClockPause'] as bool? ?? d.classicClockPause,
    );
  }

  final bool soundOn;
  final bool notificationsOn;
  final bool notificationsAsked;
  final int quietStartHour;
  final int quietEndHour;
  final bool reducedMotion;
  final WeightUnit unit;
  final bool tutorialSeen;
  final bool classicClockPause;

  Map<String, dynamic> toJson() => {
        'soundOn': soundOn,
        'notificationsOn': notificationsOn,
        'notificationsAsked': notificationsAsked,
        'quietStartHour': quietStartHour,
        'quietEndHour': quietEndHour,
        'reducedMotion': reducedMotion,
        'unit': unit.name,
        'tutorialSeen': tutorialSeen,
        'classicClockPause': classicClockPause,
      };

  Settings copyWith({
    bool? soundOn,
    bool? notificationsOn,
    bool? notificationsAsked,
    int? quietStartHour,
    int? quietEndHour,
    bool? reducedMotion,
    WeightUnit? unit,
    bool? tutorialSeen,
    bool? classicClockPause,
  }) =>
      Settings.fromJson({
        ...toJson(),
        'soundOn': ?soundOn,
        'notificationsOn': ?notificationsOn,
        'notificationsAsked': ?notificationsAsked,
        'quietStartHour': ?quietStartHour,
        'quietEndHour': ?quietEndHour,
        'reducedMotion': ?reducedMotion,
        'unit': ?unit?.name,
        'tutorialSeen': ?tutorialSeen,
        'classicClockPause': ?classicClockPause,
      });
}

class SaveFile {
  const SaveFile({required this.pet, required this.settings});
  final PetState? pet;
  final Settings settings;
}

typedef Migration = Map<String, dynamic> Function(Map<String, dynamic>);

/// Turns a [SaveFile] into versioned JSON text and back. Used for the save on
/// disk and for export/import, so both get the same validation.
class SaveCodec {
  SaveCodec._();

  static const int currentVersion = 1;

  /// Keyed by the version migrated *from*. None yet: schema 1 is the first.
  static const Map<int, Migration> migrations = {};

  static String encode(SaveFile f) => jsonEncode({
        'schemaVersion': currentVersion,
        'pet': f.pet?.toJson(),
        'settings': f.settings.toJson(),
      });

  /// Throws [FormatException] for anything that is not a usable save.
  static SaveFile decode(String text,
      {Map<int, Migration> migrations = SaveCodec.migrations}) {
    try {
      var j = jsonDecode(text) as Map<String, dynamic>;
      var version = j['schemaVersion'] as int;
      if (version > currentVersion) {
        throw const FormatException('Save is from a newer version of Eggling');
      }
      while (version < currentVersion) {
        final step = migrations[version];
        if (step == null) throw FormatException('No migration from $version');
        j = step(j);
        version++;
      }
      final pet = j['pet'] == null
          ? null
          : PetState.fromJson((j['pet'] as Map).cast<String, dynamic>());
      if (pet != null) _validate(pet);
      return SaveFile(
          pet: pet,
          settings: Settings.fromJson(
              (j['settings'] as Map).cast<String, dynamic>()));
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      throw FormatException('Not an Eggling save: $e');
    }
  }

  static void _validate(PetState p) {
    bool hearts(int n) => n >= 0 && n <= Rules.maxHearts;
    final ok = hearts(p.hunger) &&
        hearts(p.happiness) &&
        p.discipline >= 0 &&
        p.discipline <= 100 &&
        p.weight >= 0 &&
        p.weight <= Rules.maxWeight &&
        p.poops.length <= Rules.maxPoops &&
        p.age >= 0 &&
        p.roster.forms.any((f) => f.id == p.formId);
    if (!ok) throw const FormatException('Save contains impossible values');
  }
}
