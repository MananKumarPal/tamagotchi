/// Every tunable number in the simulation. Comments carry the confidence label
/// of each value: [S] specialist source, [M] official
/// manual, [D] Eggling design value with no usable source.
library;

const int minuteMs = 60 * 1000;
const int hourMs = 60 * minuteMs;
const int dayMs = 24 * hourMs;

enum RuleProfile { classicA, classicB }

enum LifeStage { egg, baby, child, teen, adult, departed }

class StageRules {
  const StageRules({
    required this.heartDecayMinutes,
    required this.poopIntervalMinutes,
    required this.medicineDoses,
    required this.misbehaveChances,
  });

  final int heartDecayMinutes;
  final int poopIntervalMinutes;
  final int medicineDoses;
  final int misbehaveChances;
}

class Rules {
  Rules._();

  static const int maxHearts = 4; // [M]
  static const int maxWeight = 99; // [S]
  static const int disciplineStep = 25; // [S]

  static const int eggMinutes = 5; // [M]
  static const int callWindowMinutes = 15; // [S]
  static const int recallMinutes = 90; // [D]

  static const int babyMinutes = 65; // [S]
  static const int babyNapAtMinutes = 40; // [S]
  static const int babyNapLengthMinutes = 5; // [S]
  static const int babyFirstPoopMinutes = 15; // [S]
  static const int babyIllnessAtMinutes = 33; // [S]

  static const int startWeight = 5; // [S]
  static const int mealWeight = 1; // [S]
  static const int snackWeight = 2; // [S]
  static const int gameWeight = -1; // [S]

  static const int gameRounds = 5; // [M]
  static const int gameWinsNeeded = 3; // [M]

  static const int teenAtAge = 3; // [S]
  static const int adultAtAge = 6; // [S]
  static const int hiddenMinAge = 8; // [S]
  static const int hiddenMaxAge = 12; // [S]

  static const int maxPoops = 4; // [S]
  static const int poopOverflowMinutes = 60; // [D]
  static const int illnessWindowMinutes = 24 * 60; // [D]
  static const int neglectDeathMinutes = 12 * 60; // [D]

  static const int lifespanBase = 16; // [D]
  static const int lifespanSpread = 6; // [D]
  static const int lifespanMin = 9; // [D]

  static const int heartJitterPercent = 20; // [D]
  static const int misbehaveMinMinutes = 60; // [D]
  static const int misbehaveMaxMinutes = 180; // [D]
  static const int misbehaveRetryMinutes = 30; // [D]

  /// Backward clock jumps up to this size hold the simulation until real time
  /// catches up. Larger ones are treated as a corrected clock and rebased.
  static const int clockHoldMs = dayMs;
  static const int maxCatchUpMs = 45 * dayMs;
  static const int maxEventsPerAdvance = 200000;

  static StageRules stage(LifeStage stage) => switch (stage) {
        // Baby decay [S]; poop, doses for baby [S]; the rest [D], adult poop [S].
        LifeStage.baby => const StageRules(
            heartDecayMinutes: 3,
            poopIntervalMinutes: 30,
            medicineDoses: 2,
            misbehaveChances: 0),
        LifeStage.child => const StageRules(
            heartDecayMinutes: 35,
            poopIntervalMinutes: 60,
            medicineDoses: 2,
            misbehaveChances: 3),
        LifeStage.teen => const StageRules(
            heartDecayMinutes: 50,
            poopIntervalMinutes: 120,
            medicineDoses: 2,
            misbehaveChances: 2),
        _ => const StageRules(
            heartDecayMinutes: 65,
            poopIntervalMinutes: 180,
            medicineDoses: 2,
            misbehaveChances: 0),
      };
}
