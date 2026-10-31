import 'package:eggling/domain/forms.dart';
import 'package:eggling/domain/pet_state.dart';
import 'package:eggling/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Reproducible full-life runs through the real simulator. The table in
/// docs/evolution-seeds.md comes from these. Teens enter the chart from a
/// seeded start; the discipline and care needed are set just before growing.
PetState adultFrom(RuleProfile p, String teen, int branch, int care, int disc, int seed) {
  var s = raise(newEgg(profile: p, seed: seed), clock(2, 12));
  s = s.copy()
    ..stage = LifeStage.teen
    ..formId = teen
    ..teenBranch = branch
    ..careMistakes = {'teen': care}
    ..discipline = disc
    ..misbehaveChances = 0
    ..nextMisbehaveAt = null
    ..age = 5;
  return raise(s, clock(4, 12));
}

void main() {
  for (final roster in [classicA, classicB]) {
    for (final r in roster.adultRows) {
      test('${roster.profile.name} seed 7: ${r.from} v${r.branch} reaches ${r.to}', () {
        final s = adultFrom(roster.profile, r.from, r.branch, r.minCare, r.maxDiscipline, 7);
        expect(s.formId, r.to);
      });
    }
  }
}
