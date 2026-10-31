import 'rules.dart';

/// One creature form. All names and art are original to Eggling.
class PetForm {
  const PetForm(this.id, this.name, this.stage, this.minWeight,
      {this.bedHour = 0, this.wakeHour = 0, this.blurb = ''});

  final String id;
  final String name;
  final LifeStage stage;
  final int minWeight;

  /// Local bed and wake hours. Baby forms have no bedtime and both stay 0.
  final int bedHour;
  final int wakeHour;
  final String blurb;

  bool get hasBedtime => bedHour != wakeHour;
}

class EvolutionRow {
  const EvolutionRow(this.from, this.branch, this.minCare, this.maxCare,
      this.minDiscipline, this.maxDiscipline, this.to);

  final String from;
  final int branch;
  final int minCare;
  final int maxCare;
  final int minDiscipline;
  final int maxDiscipline;
  final String to;

  bool matches(String form, int b, int care, int discipline) =>
      form == from &&
      b == branch &&
      care >= minCare &&
      care <= maxCare &&
      discipline >= minDiscipline &&
      discipline <= maxDiscipline;
}

const _any = 999;

/// The tree for one rule profile, with the structure of the 1996-97 charts.
class Roster {
  const Roster({
    required this.profile,
    required this.baby,
    required this.child,
    required this.goodTeen,
    required this.poorTeen,
    required this.hiddenFrom,
    required this.hidden,
    required this.adultRows,
    required this.forms,
  });

  final RuleProfile profile;
  final String baby;
  final String child;
  final String goodTeen;
  final String poorTeen;
  final String hiddenFrom;
  final String hidden;
  final List<EvolutionRow> adultRows;
  final List<PetForm> forms;

  PetForm form(String id) => forms.firstWhere((f) => f.id == id);

  /// Care mistakes here are those made while a child.
  String teenFor(int careAsChild) => careAsChild <= 1 ? goodTeen : poorTeen;

  int branchFor(int discipline) => discipline >= 75 ? 1 : 2;

  /// Care mistakes here are those made while a teen.
  String adultFor(String teen, int branch, int care, int discipline) =>
      adultRows.firstWhere((r) => r.matches(teen, branch, care, discipline)).to;

  static Roster of(RuleProfile profile) =>
      profile == RuleProfile.classicA ? classicA : classicB;
}

List<EvolutionRow> _rows({
  required String good,
  required String poor,
  required List<String> adults,
  required List<String> poorTeenBands,
}) {
  final [a100, a75, aLow, b100, b75, bLow] = adults;
  final [p100, p75, pLow, p2100, p2Low] = poorTeenBands;
  return [
    EvolutionRow(good, 1, 0, 2, 100, 100, a100),
    EvolutionRow(good, 1, 0, 2, 75, 75, a75),
    EvolutionRow(good, 1, 0, 2, 0, 50, aLow),
    EvolutionRow(good, 1, 3, _any, 100, 100, b100),
    EvolutionRow(good, 1, 3, _any, 75, 75, b75),
    EvolutionRow(good, 1, 3, _any, 0, 50, bLow),
    EvolutionRow(good, 2, 0, 2, 100, 100, a75),
    EvolutionRow(good, 2, 0, 2, 0, 75, aLow),
    EvolutionRow(good, 2, 3, _any, 100, 100, b75),
    EvolutionRow(good, 2, 3, _any, 0, 75, bLow),
    EvolutionRow(poor, 1, 0, _any, 100, 100, p100),
    EvolutionRow(poor, 1, 0, _any, 75, 75, p75),
    EvolutionRow(poor, 1, 0, _any, 0, 50, pLow),
    EvolutionRow(poor, 2, 0, _any, 100, 100, p2100),
    EvolutionRow(poor, 2, 0, _any, 0, 75, p2Low),
  ];
}

const _egg = PetForm('egg', 'Egg', LifeStage.egg, 5);

final Roster classicA = Roster(
  profile: RuleProfile.classicA,
  baby: 'mote',
  child: 'bunlet',
  goodTeen: 'tuffin',
  poorTeen: 'beakle',
  hiddenFrom: 'wispur',
  hidden: 'old_tobb',
  adultRows: _rows(
    good: 'tuffin',
    poor: 'beakle',
    adults: ['lumo', 'fennet', 'wispur', 'grumbo', 'slinko', 'mopple'],
    poorTeenBands: ['grumbo', 'slinko', 'mopple', 'slinko', 'mopple'],
  ),
  forms: const [
    _egg,
    PetForm('mote', 'Mote', LifeStage.baby, 5,
        blurb: 'A speck with opinions.'),
    PetForm('bunlet', 'Bunlet', LifeStage.child, 10,
        bedHour: 20, wakeHour: 9, blurb: 'All ears and bounce.'),
    PetForm('tuffin', 'Tuffin', LifeStage.teen, 20,
        bedHour: 21, wakeHour: 9, blurb: 'Wears its crest with pride.'),
    PetForm('beakle', 'Beakle', LifeStage.teen, 20,
        bedHour: 21, wakeHour: 9, blurb: 'Pecks first, asks later.'),
    PetForm('lumo', 'Lumo', LifeStage.adult, 30,
        bedHour: 22, wakeHour: 9, blurb: 'Glows when pleased.'),
    PetForm('fennet', 'Fennet', LifeStage.adult, 30,
        bedHour: 22, wakeHour: 9, blurb: 'Hears dinner from three rooms away.'),
    PetForm('wispur', 'Wispur', LifeStage.adult, 30,
        bedHour: 23, wakeHour: 11, blurb: 'Stays up. Sleeps in. No regrets.'),
    PetForm('grumbo', 'Grumbo', LifeStage.adult, 20,
        bedHour: 22, wakeHour: 9, blurb: 'Round, slow, content.'),
    PetForm('slinko', 'Slinko', LifeStage.adult, 10,
        bedHour: 22, wakeHour: 9, blurb: 'Mostly neck.'),
    PetForm('mopple', 'Mopple', LifeStage.adult, 20,
        bedHour: 22, wakeHour: 10, blurb: 'Fluffy and hard to steer.'),
    PetForm('old_tobb', 'Old Tobb', LifeStage.adult, 30,
        bedHour: 22, wakeHour: 9, blurb: 'Nobody ever told Tobb what to do.'),
  ],
);

final Roster classicB = Roster(
  profile: RuleProfile.classicB,
  baby: 'glim',
  child: 'tadlet',
  goodTeen: 'spiklet',
  poorTeen: 'nibbin',
  hiddenFrom: 'zephyx',
  hidden: 'nocto',
  adultRows: _rows(
    good: 'spiklet',
    poor: 'nibbin',
    adults: ['aurelle', 'hoplin', 'zephyx', 'bramblo', 'puddo', 'inkling'],
    poorTeenBands: ['bramblo', 'inkling', 'puddo', 'inkling', 'puddo'],
  ),
  forms: const [
    _egg,
    PetForm('glim', 'Glim', LifeStage.baby, 5,
        blurb: 'A flicker that wants snacks.'),
    PetForm('tadlet', 'Tadlet', LifeStage.child, 10,
        bedHour: 20, wakeHour: 9, blurb: 'Wiggles instead of walking.'),
    PetForm('spiklet', 'Spiklet', LifeStage.teen, 20,
        bedHour: 21, wakeHour: 9, blurb: 'Sharp hair, soft heart.'),
    PetForm('nibbin', 'Nibbin', LifeStage.teen, 20,
        bedHour: 21, wakeHour: 9, blurb: 'Has eaten part of the menu.'),
    PetForm('aurelle', 'Aurelle', LifeStage.adult, 30,
        bedHour: 22, wakeHour: 9, blurb: 'Carries itself like a small sun.'),
    PetForm('hoplin', 'Hoplin', LifeStage.adult, 30,
        bedHour: 22, wakeHour: 9, blurb: 'Never uses two steps if one hop will do.'),
    PetForm('zephyx', 'Zephyx', LifeStage.adult, 30,
        bedHour: 23, wakeHour: 11, blurb: 'Drifts in late, and on purpose.'),
    PetForm('bramblo', 'Bramblo', LifeStage.adult, 20,
        bedHour: 22, wakeHour: 9, blurb: 'Prickly outside, also prickly inside.'),
    PetForm('puddo', 'Puddo', LifeStage.adult, 10,
        bedHour: 22, wakeHour: 9, blurb: 'Mostly a puddle with a face.'),
    PetForm('inkling', 'Inkling', LifeStage.adult, 20,
        bedHour: 22, wakeHour: 10, blurb: 'Eight arms, one idea.'),
    PetForm('nocto', 'Nocto', LifeStage.adult, 30,
        bedHour: 22, wakeHour: 9, blurb: 'Came back from somewhere dark.'),
  ],
);
