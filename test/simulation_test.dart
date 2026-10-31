import 'package:eggling/domain/forms.dart';
import 'package:eggling/domain/pet_state.dart';
import 'package:eggling/domain/rules.dart';
import 'package:eggling/domain/simulation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

PetState hatched() => run(newEgg(), t0 + mins(5));

void main() {
  group('hatching', () {
    test('egg hatches after five minutes with empty hearts, calling', () {
      final s = run(newEgg(), t0 + mins(4));
      expect(s.isEgg, isTrue);
      final h = hatched();
      expect(h.stage, LifeStage.baby);
      expect(h.formId, 'mote');
      expect(h.hunger, 0);
      expect(h.happiness, 0);
      expect(h.hasCall(CallReason.hunger), isTrue);
      expect(h.hasCall(CallReason.happiness), isTrue);
    });

    test('care actions are refused in the egg', () {
      final o = Simulation.apply(newEgg(), const FeedMeal(), t0 + 1, 0);
      expect(o.rejection, Rejection.notHatched);
    });
  });

  group('feeding', () {
    test('meal adds a heart; baby weight never changes', () {
      final h = hatched();
      final s = act(h, const FeedMeal(), t0 + mins(5));
      expect(s.hunger, 1);
      expect(s.weight, 5);
      expect(s.hasCall(CallReason.hunger), isFalse);
    });

    test('meal is refused at full hunger, snack is not refused', () {
      var s = hatched();
      final at = t0 + mins(5);
      for (var i = 0; i < 4; i++) {
        s = act(s, const FeedMeal(), at);
      }
      expect(Simulation.apply(s, const FeedMeal(), at, 0).rejection,
          Rejection.full);
      for (var i = 0; i < 6; i++) {
        s = act(s, const FeedSnack(), at);
      }
      expect(s.happiness, 4);
    });

    test('after baby, meals add 1 and snacks add 2 weight', () {
      var s = raise(newEgg(), t0 + mins(70));
      expect(s.stage, LifeStage.child);
      final w = s.weight;
      final at = s.lastSimulatedAt;
      s = act(s, const FeedSnack(), at);
      expect(s.weight, w + 2);
    });
  });

  group('calls and care mistakes', () {
    test('an unanswered need call becomes one care mistake after 15 minutes', () {
      final o = Simulation.advance(hatched(), t0 + mins(5 + 15), 0);
      expect(o.state.careMistakesIn(LifeStage.baby), 2); // hunger and happiness
      expect(o.events.where((e) => e.kind == EventKind.missedNeedCall).length, 2);
    });

    test('a call answered in time leaves no mistake', () {
      var s = hatched();
      s = act(s, const FeedMeal(), t0 + mins(10));
      s = act(s, const FeedSnack(), t0 + mins(10));
      s = run(s, t0 + mins(21));
      expect(s.careMistakesIn(LifeStage.baby), 0);
    });

    test('an unmet need calls again later', () {
      final o = Simulation.advance(hatched(), t0 + mins(5 + 200), 0);
      final hungerCalls = o.events.where(
          (e) => e.kind == EventKind.callStarted && e.detail == 'hunger');
      expect(hungerCalls.length, greaterThan(1));
    });
  });

  group('poop and illness', () {
    test('baby poops at 15 and 45 minutes after hatching, with no call', () {
      var s = raiseWithoutCleaning(t0 + mins(5 + 16));
      expect(s.poops.length, 1);
      s = raiseWithoutCleaning(t0 + mins(5 + 46));
      expect(s.poops.length, 2);
    });

    test('clean removes all poop and needs poop to exist', () {
      var s = raiseWithoutCleaning(t0 + mins(5 + 16));
      s = act(s, const Clean(), s.lastSimulatedAt);
      expect(s.poops, isEmpty);
      expect(Simulation.apply(s, const Clean(), s.lastSimulatedAt, 0).rejection,
          Rejection.nothingToClean);
    });

    test('baby falls sick at 33 minutes and needs two doses', () {
      var s = raiseWithoutCleaning(t0 + mins(5 + 34));
      expect(s.sick, isTrue);
      s = act(s, const GiveMedicine(), s.lastSimulatedAt);
      expect(s.sick, isTrue);
      s = act(s, const GiveMedicine(), s.lastSimulatedAt);
      expect(s.sick, isFalse);
    });

    test('medicine is refused when healthy', () {
      expect(Simulation.apply(hatched(), const GiveMedicine(), t0 + mins(5), 0)
          .rejection, Rejection.notSick);
    });

    test('four poops left for an hour cause illness', () {
      var s = raise(newEgg(), clock(0, 12));
      expect(s.stage, LifeStage.child);
      s = s.copy()
        ..poops = [1, 2, 3]
        ..sick = false
        ..nextIllnessAt = null
        ..nextPoopAt = s.lastSimulatedAt;
      final later = run(s, s.lastSimulatedAt + mins(61));
      expect(later.poops.length, 4);
      expect(later.sick, isTrue);
    });
  });

  group('sleep', () {
    test('baby naps at 40 minutes and ages on waking', () {
      var s = raise(newEgg(), t0 + mins(5 + 41));
      expect(s.sleep, SleepKind.nap);
      expect(s.age, 0);
      s = raise(s, t0 + mins(5 + 46));
      expect(s.sleep, SleepKind.awake);
      expect(s.age, 1);
    });

    test('child sleeps at 8pm with a light call, wakes at 9am and ages', () {
      var s = raise(newEgg(), clock(0, 19, 59));
      final age = s.age;
      s = run(s, clock(0, 20));
      expect(s.sleep, SleepKind.night);
      expect(s.hasCall(CallReason.lights), isTrue);
      s = act(s, const SetLights(false), clock(0, 20, 5));
      s = run(s, clock(1, 9));
      expect(s.isAsleep, isFalse);
      expect(s.lightsOn, isTrue);
      expect(s.age, age + 1);
      expect(s.careMistakesIn(LifeStage.child), 0);
    });

    test('leaving lights on for 15 minutes is a care mistake', () {
      var s = raise(newEgg(), clock(0, 19, 59));
      final before = s.careMistakesIn(LifeStage.child);
      s = run(s, clock(0, 20, 16));
      expect(s.careMistakesIn(LifeStage.child), before + 1);
    });

    test('lights turned off before bedtime do not stop the call', () {
      var s = raise(newEgg(), clock(0, 19, 59));
      s = act(s, const SetLights(false), clock(0, 19, 59));
      s = run(s, clock(0, 20));
      expect(s.hasCall(CallReason.lights), isTrue);
    });

    test('only lights work while asleep', () {
      var s = raise(newEgg(), clock(0, 20));
      for (final c in [const FeedMeal(), const FeedSnack(), const Clean()]) {
        expect(Simulation.apply(s, c, clock(0, 20, 1), 0).rejection,
            Rejection.asleep);
      }
    });

    test('hearts do not decay during sleep', () {
      var s = raise(newEgg(), clock(0, 20, 10));
      final hunger = s.hunger;
      s = run(s, clock(1, 8, 59));
      expect(s.hunger, hunger);
    });
  });

  group('discipline', () {
    PetState misbehavingPet() {
      var s = raise(newEgg(), clock(0, 19), scold: false);
      var now = s.lastSimulatedAt;
      while (!s.misbehaving) {
        now += mins(5);
        s = raise(s, now, scold: false);
      }
      return s;
    }

    test('scolding a misbehaving pet adds 25 and ends the call', () {
      final m = misbehavingPet();
      final s = act(m, const Scold(), m.lastSimulatedAt);
      expect(s.discipline, 25);
      expect(s.misbehaving, isFalse);
    });

    test('scolding without misbehaving grants nothing', () {
      final o = Simulation.apply(hatched(), const Scold(), t0 + mins(6), 0);
      expect(o.rejection, Rejection.notMisbehaving);
      expect(o.state.discipline, 0);
    });

    test('a misbehaving pet refuses meals and games', () {
      final m = misbehavingPet();
      final s = m.copy()..hunger = 2;
      final at = m.lastSimulatedAt;
      expect(Simulation.apply(s, const FeedMeal(), at, 0).rejection,
          Rejection.misbehaving);
      expect(Simulation.apply(s, const StartGame(), at, 0).rejection,
          Rejection.misbehaving);
    });

    test('missing a misbehaving call is not a care mistake', () {
      final m = misbehavingPet();
      final before = m.totalCareMistakes;
      final s = run(m, m.lastSimulatedAt + mins(16));
      expect(s.misbehaving, isFalse);
      expect(s.totalCareMistakes, before);
    });
  });

  group('game effects', () {
    PetState child() => raise(newEgg(), clock(0, 14));

    test('three wins add happiness and lose a weight unit', () {
      var s = child().copy()..happiness = 1;
      final w = s.weight;
      s = act(s, const FinishGame(3), s.lastSimulatedAt);
      expect(s.happiness, 2);
      expect(s.weight, w - 1);
    });

    test('two wins lose weight only', () {
      var s = child().copy()..happiness = 1;
      final w = s.weight;
      s = act(s, const FinishGame(2), s.lastSimulatedAt);
      expect(s.happiness, 1);
      expect(s.weight, w - 1);
    });

    test('weight cannot fall below the form minimum', () {
      var s = child().copy()..weight = 10;
      s = act(s, const FinishGame(5), s.lastSimulatedAt);
      expect(s.weight, 10);
    });
  });

  group('death', () {
    test('twelve awake hours at empty hunger is fatal', () {
      final s = run(hatched(), t0 + mins(5) + 2 * dayMs);
      expect(s.isDeparted, isTrue);
      expect(s.deathCause, isNotNull);
      expect(Simulation.apply(s, const FeedMeal(), s.lastSimulatedAt, 0).rejection,
          Rejection.departed);
    });

    test('untreated illness is fatal when needs are met', () {
      final s = raise(newEgg(), t0 + dayMs * 3, medicate: false);
      expect(s.deathCause, DeathCause.illness);
    });

    test('old age arrives at the lifespan on waking', () {
      var s = raise(newEgg(), clock(30, 12));
      expect(s.isDeparted, isTrue);
      expect(s.deathCause, DeathCause.oldAge);
      expect(s.age, s.lifespan);
    });
  });

  group('time', () {
    test('catch-up in one jump equals many small steps', () {
      final start = hatched();
      final jump = run(start, t0 + dayMs * 2);
      expect(jump.deathCause, isNotNull);
      var steps = start;
      for (var at = t0 + mins(11); at < t0 + dayMs * 2; at += mins(7)) {
        steps = run(steps, at);
      }
      steps = run(steps, t0 + dayMs * 2);
      expect(steps.toJson(), jump.toJson());
    });

    test('same seed and input give the same pet; another seed may not', () {
      final a = raise(newEgg(seed: 11), clock(3, 12));
      final b = raise(newEgg(seed: 11), clock(3, 12));
      expect(a.toJson(), b.toJson());
    });

    test('a save/load round trip in the middle changes nothing', () {
      final start = raise(newEgg(), clock(1, 12));
      final direct = run(start, clock(4, 12));
      final reloaded = run(PetState.fromJson(start.toJson()), clock(4, 12));
      expect(reloaded.toJson(), direct.toJson());
    });

    test('a small backward clock change holds the pet still', () {
      final s = raise(newEgg(), clock(0, 15));
      final o = Simulation.advance(s, clock(0, 14), 0);
      expect(o.state.lastSimulatedAt, s.lastSimulatedAt);
      expect(o.events.single.kind, EventKind.clockHeld);
    });

    test('a large backward change rebases timers without penalties', () {
      final s = raise(newEgg(), clock(0, 15));
      final back = s.lastSimulatedAt - 5 * dayMs;
      final o = Simulation.advance(s, back, 0);
      expect(o.state.lastSimulatedAt, back);
      expect(o.state.totalCareMistakes, s.totalCareMistakes);
      expect(o.events.last.kind, EventKind.clockRebased);
    });

    test('pausing stops time and resuming shifts every timer', () {
      var s = raise(newEgg(), clock(0, 15));
      final hunger = s.hunger;
      s = act(s, const SetPaused(true), clock(0, 15));
      s = run(s, clock(5, 15));
      expect(s.hunger, hunger);
      expect(s.isPaused, isTrue);
      expect(Simulation.apply(s, const FeedMeal(), clock(5, 15), 0).rejection,
          Rejection.paused);
      s = Simulation.apply(s, const SetPaused(false), clock(5, 15), 0).state;
      expect(s.isPaused, isFalse);
      expect(s.isDeparted, isFalse);
      expect(run(s, clock(5, 15, 1)).totalCareMistakes, s.totalCareMistakes);
    });

    test('a daylight or zone shift moves bedtime by local time', () {
      var s = raise(newEgg(), clock(0, 12));
      // At UTC+5, 8pm local is 15:00 in test time.
      final o = Simulation.advance(s.copy()..nextBedAt = null, clock(0, 15, 1), 300);
      expect(o.state.sleep, SleepKind.night);
    });
  });

  group('evolution', () {
    test('baby always becomes the child at 65 minutes', () {
      final s = run(hatched(), t0 + mins(5 + 65));
      expect(s.stage, LifeStage.child);
      expect(s.formId, 'bunlet');
    });

    test('Classic A and Classic B use different rosters', () {
      final s = run(newEgg(profile: RuleProfile.classicB), t0 + mins(5));
      expect(s.formId, 'glim');
    });

    test('a careful, disciplined pet reaches the top adult in Classic A', () {
      final s = raise(newEgg(), clock(7, 12));
      expect(s.stage, LifeStage.adult);
      expect(s.formId, 'lumo');
    });

    test('a careful, disciplined pet reaches the top adult in Classic B', () {
      final s = raise(newEgg(profile: RuleProfile.classicB), clock(7, 12));
      expect(s.formId, 'aurelle');
    });

    test('never scolding gives the hidden adult path', () {
      final s = raise(newEgg(), clock(13, 12), scold: false);
      expect(s.formId, 'old_tobb');
    });

    test('care mistakes as a child lead to the poor-care teen', () {
      expect(classicA.teenFor(1), 'tuffin');
      expect(classicA.teenFor(2), 'beakle');
    });

    const chart = [
      // teen, branch, care, discipline, adult
      ('tuffin', 1, 2, 100, 'lumo'),
      ('tuffin', 1, 0, 75, 'fennet'),
      ('tuffin', 1, 1, 50, 'wispur'),
      ('tuffin', 1, 3, 100, 'grumbo'),
      ('tuffin', 1, 4, 75, 'slinko'),
      ('tuffin', 1, 5, 0, 'mopple'),
      ('tuffin', 2, 0, 100, 'fennet'),
      ('tuffin', 2, 2, 75, 'wispur'),
      ('tuffin', 2, 3, 100, 'slinko'),
      ('tuffin', 2, 3, 75, 'mopple'),
      ('beakle', 1, 9, 100, 'grumbo'),
      ('beakle', 1, 0, 75, 'slinko'),
      ('beakle', 1, 0, 25, 'mopple'),
      ('beakle', 2, 0, 100, 'slinko'),
      ('beakle', 2, 0, 75, 'mopple'),
    ];
    for (final (teen, branch, care, disc, adult) in chart) {
      test('Classic A: $teen v$branch, $care mistakes, $disc% is $adult', () {
        expect(classicA.adultFor(teen, branch, care, disc), adult);
      });
    }

    test('Classic B differs: poor teen 75% goes to Inkling, low to Puddo', () {
      expect(classicB.adultFor('nibbin', 1, 0, 75), 'inkling');
      expect(classicB.adultFor('nibbin', 1, 0, 25), 'puddo');
      expect(classicB.adultFor('spiklet', 1, 4, 75), 'puddo');
    });
  });
}

/// Raises a fresh baby, answering needs but leaving poop and illness alone.
PetState raiseWithoutCleaning(int until) {
  var s = newEgg();
  var now = t0;
  while (now < until) {
    now += mins(1);
    s = run(s, now);
    if (s.isEgg || s.isAsleep) continue;
    if (s.hasCall(CallReason.hunger)) s = act(s, const FeedMeal(), now);
    if (s.hasCall(CallReason.happiness)) s = act(s, const FeedSnack(), now);
  }
  return s;
}
