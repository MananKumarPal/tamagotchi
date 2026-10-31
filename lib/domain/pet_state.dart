import 'forms.dart';
import 'rules.dart';

enum CallReason { hunger, happiness, lights, misbehave }

enum SleepKind { awake, nap, night }

enum DeathCause { oldAge, starvation, illness }

enum Rejection {
  notHatched,
  departed,
  paused,
  asleep,
  full,
  misbehaving,
  nothingToClean,
  notSick,
  notMisbehaving,
  lightsAlready,
}

class ActiveCall {
  const ActiveCall(this.reason, this.startedAt, this.deadline);

  factory ActiveCall.fromJson(Map<String, dynamic> j) => ActiveCall(
      CallReason.values.byName(j['reason'] as String),
      j['startedAt'] as int,
      j['deadline'] as int);

  final CallReason reason;
  final int startedAt;
  final int deadline;

  Map<String, dynamic> toJson() =>
      {'reason': reason.name, 'startedAt': startedAt, 'deadline': deadline};
}

/// The whole saved pet. Treat as immutable outside `simulation.dart`, which
/// works on private copies. All times are epoch milliseconds.
class PetState {
  PetState({
    required this.id,
    required this.profile,
    required this.shell,
    required this.name,
    required this.seed,
    required this.createdAt,
    required this.hatchAt,
    required this.lastSimulatedAt,
  })  : stageStartedAt = createdAt,
        formId = 'egg';

  String id;
  RuleProfile profile;
  String shell;
  String name;
  int seed;
  int rollCounter = 0;
  int gamesStarted = 0;

  LifeStage stage = LifeStage.egg;
  String formId;
  int teenBranch = 0;
  int createdAt;
  int hatchAt;
  int? bornAt;
  int stageStartedAt;
  int lastSimulatedAt;

  int hunger = 0;
  int happiness = 0;
  int discipline = 0;
  int weight = Rules.startWeight;
  int age = 0;
  Map<String, int> careMistakes = {};
  Map<String, int> disciplineMisses = {};
  int misbehaveChances = 0;

  List<int> poops = [];
  bool sick = false;
  int dosesGiven = 0;
  bool lightsOn = true;
  SleepKind sleep = SleepKind.awake;
  int? sleepStartedAt;
  List<ActiveCall> calls = [];

  int? nextHungerAt;
  int? nextHappyAt;
  int? nextPoopAt;
  int? nextIllnessAt;
  int? nextMisbehaveAt;
  int? nextRecallAt;
  int? nextNapAt;
  int? nextBedAt;
  int? nextWakeAt;
  int? stageEndAt;
  int? poopOverflowAt;
  int? starveAt;
  int? illnessDeathAt;

  int? pausedAt;
  int lifespanBonus = 0;
  int hiddenAge = 0;

  DeathCause? deathCause;
  int? departedAt;

  /// Widget action ids already applied, so a re-read queue cannot double feed.
  List<String> appliedActions = [];

  bool get isAsleep => sleep != SleepKind.awake;
  bool get isPaused => pausedAt != null;
  bool get isDeparted => stage == LifeStage.departed;
  bool get isEgg => stage == LifeStage.egg;
  bool get isCalling => calls.isNotEmpty;
  Roster get roster => Roster.of(profile);
  PetForm get form => roster.form(formId);

  bool get misbehaving => hasCall(CallReason.misbehave);
  bool hasCall(CallReason r) => calls.any((c) => c.reason == r);

  int careMistakesIn(LifeStage s) => careMistakes[s.name] ?? 0;
  int get totalCareMistakes =>
      careMistakes.values.fold(0, (sum, n) => sum + n);

  int get lifespan {
    final adultMistakes = careMistakesIn(LifeStage.adult);
    final years = Rules.lifespanBase + lifespanBonus - adultMistakes;
    return years < Rules.lifespanMin ? Rules.lifespanMin : years;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile': profile.name,
        'shell': shell,
        'name': name,
        'seed': seed,
        'rollCounter': rollCounter,
        'gamesStarted': gamesStarted,
        'stage': stage.name,
        'formId': formId,
        'teenBranch': teenBranch,
        'createdAt': createdAt,
        'hatchAt': hatchAt,
        'bornAt': bornAt,
        'stageStartedAt': stageStartedAt,
        'lastSimulatedAt': lastSimulatedAt,
        'hunger': hunger,
        'happiness': happiness,
        'discipline': discipline,
        'weight': weight,
        'age': age,
        'careMistakes': careMistakes,
        'disciplineMisses': disciplineMisses,
        'misbehaveChances': misbehaveChances,
        'poops': poops,
        'sick': sick,
        'dosesGiven': dosesGiven,
        'lightsOn': lightsOn,
        'sleep': sleep.name,
        'sleepStartedAt': sleepStartedAt,
        'calls': calls.map((c) => c.toJson()).toList(),
        'nextHungerAt': nextHungerAt,
        'nextHappyAt': nextHappyAt,
        'nextPoopAt': nextPoopAt,
        'nextIllnessAt': nextIllnessAt,
        'nextMisbehaveAt': nextMisbehaveAt,
        'nextRecallAt': nextRecallAt,
        'nextNapAt': nextNapAt,
        'nextBedAt': nextBedAt,
        'nextWakeAt': nextWakeAt,
        'stageEndAt': stageEndAt,
        'poopOverflowAt': poopOverflowAt,
        'starveAt': starveAt,
        'illnessDeathAt': illnessDeathAt,
        'pausedAt': pausedAt,
        'lifespanBonus': lifespanBonus,
        'hiddenAge': hiddenAge,
        'deathCause': deathCause?.name,
        'departedAt': departedAt,
        'appliedActions': appliedActions,
      };

  factory PetState.fromJson(Map<String, dynamic> j) {
    final s = PetState(
      id: j['id'] as String,
      profile: RuleProfile.values.byName(j['profile'] as String),
      shell: j['shell'] as String,
      name: j['name'] as String,
      seed: j['seed'] as int,
      createdAt: j['createdAt'] as int,
      hatchAt: j['hatchAt'] as int,
      lastSimulatedAt: j['lastSimulatedAt'] as int,
    );
    final causeName = j['deathCause'] as String?;
    return s
      ..rollCounter = j['rollCounter'] as int
      ..gamesStarted = j['gamesStarted'] as int
      ..stage = LifeStage.values.byName(j['stage'] as String)
      ..formId = j['formId'] as String
      ..teenBranch = j['teenBranch'] as int
      ..bornAt = j['bornAt'] as int?
      ..stageStartedAt = j['stageStartedAt'] as int
      ..hunger = j['hunger'] as int
      ..happiness = j['happiness'] as int
      ..discipline = j['discipline'] as int
      ..weight = j['weight'] as int
      ..age = j['age'] as int
      ..careMistakes = (j['careMistakes'] as Map).cast<String, int>()
      ..disciplineMisses = (j['disciplineMisses'] as Map).cast<String, int>()
      ..misbehaveChances = j['misbehaveChances'] as int
      ..poops = (j['poops'] as List).cast<int>()
      ..sick = j['sick'] as bool
      ..dosesGiven = j['dosesGiven'] as int
      ..lightsOn = j['lightsOn'] as bool
      ..sleep = SleepKind.values.byName(j['sleep'] as String)
      ..sleepStartedAt = j['sleepStartedAt'] as int?
      ..calls = (j['calls'] as List)
          .map((c) => ActiveCall.fromJson((c as Map).cast<String, dynamic>()))
          .toList()
      ..nextHungerAt = j['nextHungerAt'] as int?
      ..nextHappyAt = j['nextHappyAt'] as int?
      ..nextPoopAt = j['nextPoopAt'] as int?
      ..nextIllnessAt = j['nextIllnessAt'] as int?
      ..nextMisbehaveAt = j['nextMisbehaveAt'] as int?
      ..nextRecallAt = j['nextRecallAt'] as int?
      ..nextNapAt = j['nextNapAt'] as int?
      ..nextBedAt = j['nextBedAt'] as int?
      ..nextWakeAt = j['nextWakeAt'] as int?
      ..stageEndAt = j['stageEndAt'] as int?
      ..poopOverflowAt = j['poopOverflowAt'] as int?
      ..starveAt = j['starveAt'] as int?
      ..illnessDeathAt = j['illnessDeathAt'] as int?
      ..pausedAt = j['pausedAt'] as int?
      ..lifespanBonus = j['lifespanBonus'] as int
      ..hiddenAge = j['hiddenAge'] as int
      ..deathCause =
          causeName == null ? null : DeathCause.values.byName(causeName)
      ..departedAt = j['departedAt'] as int?
      ..appliedActions = (j['appliedActions'] as List).cast<String>();
  }

  PetState copy() => PetState.fromJson(toJson());
}

enum EventKind {
  hatched,
  fedMeal,
  fedSnack,
  playedRound,
  gameWon,
  gameLost,
  heartLost,
  callStarted,
  callAnswered,
  missedNeedCall,
  ignoredMisbehaving,
  scolded,
  pooped,
  cleaned,
  fellAsleep,
  woke,
  lightsChanged,
  fellSick,
  dosed,
  wasCured,
  evolved,
  departed,
  paused,
  resumed,
  clockHeld,
  clockRebased,
}

class PetEvent {
  const PetEvent(this.kind, this.at, [this.detail]);

  final EventKind kind;
  final int at;
  final String? detail;

  @override
  String toString() => '$kind${detail == null ? '' : '($detail)'}';
}

class Outcome {
  const Outcome(this.state, this.events, {this.rejection});

  final PetState state;
  final List<PetEvent> events;
  final Rejection? rejection;

  bool get accepted => rejection == null;
}

sealed class Command {
  const Command();
}

class FeedMeal extends Command {
  const FeedMeal();
}

class FeedSnack extends Command {
  const FeedSnack();
}

class SetLights extends Command {
  const SetLights(this.on);
  final bool on;
}

class Clean extends Command {
  const Clean();
}

class GiveMedicine extends Command {
  const GiveMedicine();
}

class Scold extends Command {
  const Scold();
}

class StartGame extends Command {
  const StartGame();
}

/// A completed game. Quitting sends no command, so it changes nothing.
class FinishGame extends Command {
  const FinishGame(this.wins);
  final int wins;
}

/// Skips the rest of the egg wait. The default is the classic five minutes.
class HatchNow extends Command {
  const HatchNow();
}

class SetPaused extends Command {
  const SetPaused(this.paused);
  final bool paused;
}
