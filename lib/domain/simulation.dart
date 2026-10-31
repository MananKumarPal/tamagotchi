import 'dart:math' as math;

import 'pet_state.dart';
import 'rules.dart';

/// The game. A pure, deterministic function of saved state, commands and time.
///
/// Everything due is kept as an absolute timestamp on [PetState] and fired in
/// chronological order, so one long catch-up after the app was closed equals
/// any number of small steps. [offsetMinutes] is the device's UTC offset, used
/// only to place bedtimes in local time.
class Simulation {
  Simulation._();

  static PetState newEgg({
    required String id,
    required RuleProfile profile,
    required String shell,
    required String name,
    required int seed,
    required int at,
  }) =>
      PetState(
        id: id,
        profile: profile,
        shell: shell,
        name: name,
        seed: seed,
        createdAt: at,
        hatchAt: at + Rules.eggMinutes * minuteMs,
        lastSimulatedAt: at,
      );

  /// Brings [state] up to [now]. Never fails; odd clocks are absorbed.
  static Outcome advance(PetState state, int now, int offsetMinutes) {
    final run = _Run(state.copy(), offsetMinutes);
    run.advanceTo(now);
    return Outcome(run.s, run.events);
  }

  /// Advances to [at], then applies [command]. A rejected command leaves the
  /// advanced state and reports why.
  static Outcome apply(
      PetState state, Command command, int at, int offsetMinutes) {
    final run = _Run(state.copy(), offsetMinutes);
    if (command is SetPaused && state.isPaused) {
      if (!command.paused) run.resume(at);
      return Outcome(run.s, run.events);
    }
    run.advanceTo(at);
    final rejection = check(run.s, command);
    if (rejection != null) {
      return Outcome(run.s, run.events, rejection: rejection);
    }
    run.perform(command, math.max(at, run.s.lastSimulatedAt));
    run.advanceTo(run.s.lastSimulatedAt);
    return Outcome(run.s, run.events);
  }

  /// Why [command] would be refused right now, or null if it is allowed.
  static Rejection? check(PetState s, Command c) {
    if (s.isPaused) return Rejection.paused;
    if (s.isDeparted) return Rejection.departed;
    if (c is SetPaused) return null;
    if (s.isEgg) return c is HatchNow ? null : Rejection.notHatched;
    if (c is HatchNow) return Rejection.notHatched;
    if (c is FinishGame) return null;
    if (c is SetLights) {
      return c.on == s.lightsOn ? Rejection.lightsAlready : null;
    }
    if (s.isAsleep) return Rejection.asleep;
    return switch (c) {
      FeedMeal() => s.misbehaving
          ? Rejection.misbehaving
          : s.hunger >= Rules.maxHearts
              ? Rejection.full
              : null,
      StartGame() => s.misbehaving ? Rejection.misbehaving : null,
      Clean() => s.poops.isEmpty ? Rejection.nothingToClean : null,
      GiveMedicine() => s.sick ? null : Rejection.notSick,
      Scold() => s.misbehaving ? null : Rejection.notMisbehaving,
      _ => null,
    };
  }

  /// The next moment anything changes without player input.
  static int? nextDueAt(PetState s) => _Run(s, 0).nextDue();
}

class _Run {
  _Run(this.s, this.offsetMinutes);

  final PetState s;
  final int offsetMinutes;
  final List<PetEvent> events = [];

  StageRules get rules => Rules.stage(s.stage);

  void emit(EventKind kind, int at, [String? detail]) =>
      events.add(PetEvent(kind, at, detail));

  // Timekeeping ------------------------------------------------------------

  void advanceTo(int requestedNow) {
    if (s.isPaused) return;
    var now = requestedNow;
    final last = s.lastSimulatedAt;
    if (now < last) {
      final back = last - now;
      if (back <= Rules.clockHoldMs) {
        emit(EventKind.clockHeld, now);
        return;
      }
      shiftEverything(-back);
      s.lastSimulatedAt = now;
      rescheduleSleep(now);
      emit(EventKind.clockRebased, now);
      return;
    }
    final excess = now - last - Rules.maxCatchUpMs;
    if (excess > 0) {
      shiftEverything(excess);
      s.lastSimulatedAt = last + excess;
      rescheduleSleep(s.lastSimulatedAt);
      emit(EventKind.clockRebased, now);
    }
    if (s.nextBedAt == null && !s.isAsleep && !s.isDeparted && !s.isEgg) {
      scheduleBed(s.lastSimulatedAt);
    }
    for (var guard = 0; guard < Rules.maxEventsPerAdvance; guard++) {
      final due = nextDue();
      if (due == null || due > now) break;
      final t = math.max(due, s.lastSimulatedAt);
      s.lastSimulatedAt = t;
      fire(due, t);
    }
    if (now > s.lastSimulatedAt) s.lastSimulatedAt = now;
  }

  void resume(int at) {
    final delta = at - s.pausedAt!;
    s.pausedAt = null;
    shiftEverything(delta);
    s.lastSimulatedAt = at;
    rescheduleSleep(at);
    emit(EventKind.resumed, at);
  }

  int? nextDue() {
    if (s.isPaused || s.isDeparted) return null;
    if (s.isEgg) return s.hatchAt;
    final due = <int?>[
      for (final c in s.calls) c.deadline,
      s.nextWakeAt,
      if (!s.isAsleep) ...awakeTimers(),
      if (!s.isAsleep) s.stageEndAt,
      if (!s.isAsleep) s.nextNapAt,
      if (!s.isAsleep) s.nextBedAt,
    ].nonNulls;
    return due.isEmpty ? null : due.reduce(math.min);
  }

  List<int?> awakeTimers() => [
        s.nextHungerAt,
        s.nextHappyAt,
        s.nextPoopAt,
        s.nextIllnessAt,
        s.nextMisbehaveAt,
        s.nextRecallAt,
        s.poopOverflowAt,
        s.starveAt,
        s.illnessDeathAt,
      ];

  int? plus(int? t, int delta) => t == null ? null : t + delta;

  /// Timers that only run while awake pause for the length of a sleep.
  void shiftAwakeTimers(int d) {
    s.nextHungerAt = plus(s.nextHungerAt, d);
    s.nextHappyAt = plus(s.nextHappyAt, d);
    s.nextPoopAt = plus(s.nextPoopAt, d);
    s.nextIllnessAt = plus(s.nextIllnessAt, d);
    s.nextMisbehaveAt = plus(s.nextMisbehaveAt, d);
    s.nextRecallAt = plus(s.nextRecallAt, d);
    s.poopOverflowAt = plus(s.poopOverflowAt, d);
    s.starveAt = plus(s.starveAt, d);
    s.illnessDeathAt = plus(s.illnessDeathAt, d);
  }

  void shiftEverything(int d) {
    shiftAwakeTimers(d);
    s.hatchAt += d;
    s.stageEndAt = plus(s.stageEndAt, d);
    s.nextNapAt = plus(s.nextNapAt, d);
    s.nextBedAt = plus(s.nextBedAt, d);
    s.nextWakeAt = plus(s.nextWakeAt, d);
    s.sleepStartedAt = plus(s.sleepStartedAt, d);
    s.calls = [
      for (final c in s.calls)
        ActiveCall(c.reason, c.startedAt + d, c.deadline + d)
    ];
  }

  int localMinute(int t) =>
      (t ~/ minuteMs + offsetMinutes) % Duration.minutesPerDay;

  int nextLocal(int t, int hour) {
    final diff = (hour * 60 - localMinute(t)) % Duration.minutesPerDay;
    final step = diff == 0 ? Duration.minutesPerDay : diff;
    return (t ~/ minuteMs + step) * minuteMs;
  }

  bool inBedWindow(int t) {
    final f = s.form;
    final m = localMinute(t);
    return m >= f.bedHour * 60 || m < f.wakeHour * 60;
  }

  void scheduleBed(int t) {
    final f = s.form;
    if (!f.hasBedtime) {
      s.nextBedAt = null;
    } else {
      s.nextBedAt = inBedWindow(t) ? t : nextLocal(t, f.bedHour);
    }
  }

  void rescheduleSleep(int t) {
    if (s.isAsleep) {
      if (s.sleep == SleepKind.night) s.nextWakeAt = nextLocal(t, s.form.wakeHour);
    } else {
      s.nextBedAt = null;
      scheduleBed(t);
    }
  }

  // Seeded randomness -------------------------------------------------------

  int roll(int bound) {
    s.rollCounter++;
    var z = (s.seed + s.rollCounter * 0x9E3779B9) & 0xFFFFFFFF;
    z = ((z ^ (z >> 15)) * 0x2C1B3C6D) & 0xFFFFFFFF;
    z = ((z ^ (z >> 12)) * 0x297A2D39) & 0xFFFFFFFF;
    z = (z ^ (z >> 15)) & 0xFFFFFFFF;
    return z % bound;
  }

  int heartInterval() {
    final trim = roll(Rules.heartJitterPercent + 1);
    return rules.heartDecayMinutes * minuteMs * (100 - trim) ~/ 100;
  }

  // Scheduled events --------------------------------------------------------

  void fire(int due, int t) {
    if (s.isEgg) return hatch(t);
    for (final c in List.of(s.calls)) {
      if (c.deadline == due) return expire(c, t);
    }
    if (s.nextWakeAt == due) return wake(t);
    if (s.starveAt == due) return depart(DeathCause.starvation, t);
    if (s.illnessDeathAt == due) return depart(DeathCause.illness, t);
    if (s.stageEndAt == due) return leaveBaby(t);
    if (s.nextNapAt == due) return nap(t);
    if (s.nextBedAt == due) return bed(t);
    if (s.nextHungerAt == due) return loseHunger(t);
    if (s.nextHappyAt == due) return loseHappiness(t);
    if (s.nextPoopAt == due) return poop(t);
    if (s.nextIllnessAt == due) {
      s.nextIllnessAt = null;
      return fallSick(t);
    }
    if (s.poopOverflowAt == due) {
      s.poopOverflowAt = null;
      return fallSick(t);
    }
    if (s.nextRecallAt == due) {
      s.nextRecallAt = null;
      return raiseNeedCalls(t);
    }
    if (s.nextMisbehaveAt == due) return misbehave(t);
  }

  void hatch(int t) {
    final roster = s.roster;
    s
      ..stage = LifeStage.baby
      ..formId = roster.baby
      ..bornAt = t
      ..stageStartedAt = t
      ..stageEndAt = t + Rules.babyMinutes * minuteMs
      ..nextNapAt = t + Rules.babyNapAtMinutes * minuteMs
      ..nextPoopAt = t + Rules.babyFirstPoopMinutes * minuteMs
      ..nextIllnessAt = t + Rules.babyIllnessAtMinutes * minuteMs
      ..lifespanBonus = roll(Rules.lifespanSpread + 1)
      ..hiddenAge =
          Rules.hiddenMinAge + roll(Rules.hiddenMaxAge - Rules.hiddenMinAge + 1);
    emit(EventKind.hatched, t, s.formId);
    raiseNeedCalls(t);
    armStarve(t);
  }

  void armStarve(int t) {
    if (s.hunger == 0 && s.starveAt == null) {
      s.starveAt = t + Rules.neglectDeathMinutes * minuteMs;
    }
  }

  void addCall(CallReason reason, int t) {
    if (s.hasCall(reason)) return;
    s.calls = [
      ...s.calls,
      ActiveCall(reason, t, t + Rules.callWindowMinutes * minuteMs)
    ];
    emit(EventKind.callStarted, t, reason.name);
  }

  void clearCall(CallReason reason, int t) {
    if (!s.hasCall(reason)) return;
    s.calls = s.calls.where((c) => c.reason != reason).toList();
    emit(EventKind.callAnswered, t, reason.name);
  }

  void raiseNeedCalls(int t) {
    if (s.hunger == 0) addCall(CallReason.hunger, t);
    if (s.happiness == 0) addCall(CallReason.happiness, t);
  }

  void expire(ActiveCall call, int t) {
    s.calls = s.calls.where((c) => c.reason != call.reason).toList();
    if (call.reason == CallReason.misbehave) {
      emit(EventKind.ignoredMisbehaving, t);
      scheduleMisbehave(t);
      return;
    }
    final key = s.stage.name;
    s.careMistakes = {...s.careMistakes, key: (s.careMistakes[key] ?? 0) + 1};
    emit(EventKind.missedNeedCall, t, call.reason.name);
    if (call.reason != CallReason.lights) {
      s.nextRecallAt ??= t + Rules.recallMinutes * minuteMs;
    }
  }

  void loseHunger(int t) {
    s.hunger = math.max(0, s.hunger - 1);
    emit(EventKind.heartLost, t, 'hunger');
    s.nextHungerAt = s.hunger > 0 ? t + heartInterval() : null;
    if (s.hunger == 0) {
      addCall(CallReason.hunger, t);
      armStarve(t);
    }
  }

  void loseHappiness(int t) {
    s.happiness = math.max(0, s.happiness - 1);
    emit(EventKind.heartLost, t, 'happiness');
    s.nextHappyAt = s.happiness > 0 ? t + heartInterval() : null;
    if (s.happiness == 0) addCall(CallReason.happiness, t);
  }

  void poop(int t) {
    s.poops = [...s.poops, t];
    emit(EventKind.pooped, t);
    if (s.poops.length >= Rules.maxPoops) {
      s.nextPoopAt = null;
      s.poopOverflowAt = t + Rules.poopOverflowMinutes * minuteMs;
    } else {
      s.nextPoopAt = t + rules.poopIntervalMinutes * minuteMs;
    }
  }

  void fallSick(int t) {
    if (s.sick) return;
    s
      ..sick = true
      ..dosesGiven = 0
      ..illnessDeathAt = t + Rules.neglectDeathMinutes * minuteMs;
    emit(EventKind.fellSick, t);
  }

  void misbehave(int t) {
    s.nextMisbehaveAt = null;
    if (s.misbehaveChances <= 0 || s.discipline >= 100) return;
    if (s.hunger == 0 || s.happiness == 0 || s.misbehaving) {
      s.nextMisbehaveAt = t + Rules.misbehaveRetryMinutes * minuteMs;
      return;
    }
    s.misbehaveChances--;
    addCall(CallReason.misbehave, t);
  }

  void scheduleMisbehave(int t) {
    if (s.misbehaveChances <= 0 || s.discipline >= 100) {
      s.nextMisbehaveAt = null;
      return;
    }
    final spread = Rules.misbehaveMaxMinutes - Rules.misbehaveMinMinutes;
    s.nextMisbehaveAt =
        t + (Rules.misbehaveMinMinutes + roll(spread)) * minuteMs;
  }

  void nap(int t) {
    s
      ..nextNapAt = null
      ..sleep = SleepKind.nap
      ..sleepStartedAt = t
      ..nextWakeAt = t + Rules.babyNapLengthMinutes * minuteMs;
    dropCallsForSleep();
    emit(EventKind.fellAsleep, t, 'nap');
  }

  void bed(int t) {
    s
      ..nextBedAt = null
      ..sleep = SleepKind.night
      ..sleepStartedAt = t
      ..nextWakeAt = nextLocal(t, s.form.wakeHour)
      ..lightsOn = true;
    dropCallsForSleep();
    emit(EventKind.fellAsleep, t, 'night');
    addCall(CallReason.lights, t);
  }

  void dropCallsForSleep() {
    if (s.misbehaving) s.misbehaveChances++;
    s.calls = [];
  }

  void wake(int t) {
    // The baby's timers are minutes of age in the sources, so naps don't pause.
    final wasNight = s.sleep == SleepKind.night;
    if (wasNight) shiftAwakeTimers(t - s.sleepStartedAt!);
    s
      ..sleep = SleepKind.awake
      ..sleepStartedAt = null
      ..nextWakeAt = null
      ..lightsOn = true
      ..calls = []
      ..age = s.age + 1;
    emit(EventKind.woke, t);
    if (s.nextMisbehaveAt == null) scheduleMisbehave(t);
    if (wasNight) {
      growUp(t);
      if (s.isDeparted) return;
      scheduleBed(t);
    }
    raiseNeedCalls(t);
  }

  // Growth ------------------------------------------------------------------

  void enterStage(LifeStage stage, String formId, int t) {
    s
      ..stage = stage
      ..formId = formId
      ..stageStartedAt = t
      ..weight = math.max(s.weight, s.roster.form(formId).minWeight)
      ..misbehaveChances = Rules.stage(stage).misbehaveChances;
    if (!s.sick) {
      s.nextIllnessAt = t + roll(Rules.illnessWindowMinutes) * minuteMs;
    }
    if (s.nextPoopAt == null && s.poops.length < Rules.maxPoops) {
      s.nextPoopAt = t + rules.poopIntervalMinutes * minuteMs;
    }
    scheduleMisbehave(t);
    emit(EventKind.evolved, t, formId);
  }

  void leaveBaby(int t) {
    s.stageEndAt = null;
    enterStage(LifeStage.child, s.roster.child, t);
    s.nextBedAt = null;
    scheduleBed(t);
  }

  void growUp(int t) {
    final roster = s.roster;
    if (s.stage == LifeStage.child && s.age >= Rules.teenAtAge) {
      s.teenBranch = roster.branchFor(s.discipline);
      enterStage(LifeStage.teen,
          roster.teenFor(s.careMistakesIn(LifeStage.child)), t);
    } else if (s.stage == LifeStage.teen && s.age >= Rules.adultAtAge) {
      enterStage(
          LifeStage.adult,
          roster.adultFor(s.formId, s.teenBranch,
              s.careMistakesIn(LifeStage.teen), s.discipline),
          t);
    } else if (s.formId == roster.hiddenFrom &&
        s.discipline == 0 &&
        s.age >= s.hiddenAge) {
      enterStage(LifeStage.adult, roster.hidden, t);
    }
    if (s.stage == LifeStage.adult && s.age >= s.lifespan) {
      depart(DeathCause.oldAge, t);
    }
  }

  void depart(DeathCause cause, int t) {
    s
      ..stage = LifeStage.departed
      ..deathCause = cause
      ..departedAt = t
      ..sick = false
      ..sleep = SleepKind.awake
      ..sleepStartedAt = null
      ..calls = []
      ..nextHungerAt = null
      ..nextHappyAt = null
      ..nextPoopAt = null
      ..nextIllnessAt = null
      ..nextMisbehaveAt = null
      ..nextRecallAt = null
      ..nextNapAt = null
      ..nextBedAt = null
      ..nextWakeAt = null
      ..stageEndAt = null
      ..poopOverflowAt = null
      ..starveAt = null
      ..illnessDeathAt = null;
    emit(EventKind.departed, t, cause.name);
  }

  // Commands ----------------------------------------------------------------

  void changeWeight(int delta) {
    if (s.stage == LifeStage.baby) return;
    s.weight = (s.weight + delta).clamp(s.form.minWeight, Rules.maxWeight);
  }

  void addHunger(int t) {
    final wasEmpty = s.hunger == 0;
    s.hunger = math.min(Rules.maxHearts, s.hunger + 1);
    if (wasEmpty) {
      s
        ..nextHungerAt = t + heartInterval()
        ..starveAt = null;
      clearCall(CallReason.hunger, t);
    }
  }

  void addHappiness(int t) {
    final wasEmpty = s.happiness == 0;
    s.happiness = math.min(Rules.maxHearts, s.happiness + 1);
    if (wasEmpty) {
      s.nextHappyAt = t + heartInterval();
      clearCall(CallReason.happiness, t);
    }
  }

  void perform(Command c, int t) {
    switch (c) {
      case FeedMeal():
        addHunger(t);
        changeWeight(Rules.mealWeight);
        emit(EventKind.fedMeal, t);
      case FeedSnack():
        addHappiness(t);
        changeWeight(Rules.snackWeight);
        emit(EventKind.fedSnack, t);
      case SetLights(:final on):
        s.lightsOn = on;
        if (!on && s.sleep == SleepKind.night) {
          clearCall(CallReason.lights, t);
        }
        emit(EventKind.lightsChanged, t, on ? 'on' : 'off');
      case Clean():
        s.poops = [];
        s.poopOverflowAt = null;
        s.nextPoopAt ??= t + rules.poopIntervalMinutes * minuteMs;
        emit(EventKind.cleaned, t);
      case GiveMedicine():
        s.dosesGiven++;
        emit(EventKind.dosed, t);
        if (s.dosesGiven >= rules.medicineDoses) {
          s
            ..sick = false
            ..dosesGiven = 0
            ..illnessDeathAt = null;
          emit(EventKind.wasCured, t);
        }
      case Scold():
        s.discipline =
            math.min(100, s.discipline + Rules.disciplineStep);
        clearCall(CallReason.misbehave, t);
        emit(EventKind.scolded, t);
        scheduleMisbehave(t);
      case StartGame():
        s.gamesStarted++;
      case FinishGame(:final wins):
        changeWeight(Rules.gameWeight);
        if (wins >= Rules.gameWinsNeeded) {
          addHappiness(t);
          emit(EventKind.gameWon, t);
        } else {
          emit(EventKind.gameLost, t);
        }
      case HatchNow():
        s.hatchAt = t;
      case SetPaused():
        s.pausedAt = t;
        emit(EventKind.paused, t);
    }
  }
}
