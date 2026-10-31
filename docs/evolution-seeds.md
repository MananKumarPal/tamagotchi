# Evolution seeds

Every chart row below is reproduced by `test/evolution_seeds_test.dart` with seed 7:
a full simulated run that enters the teen stage with the listed branch, care mistakes
and discipline, then grows up at age 6.

Discipline and care, not the seed, select the adult. The seed changes timing only.

| Mode | Teen | Branch | Care mistakes as teen | Discipline | Adult |
|---|---|---|---|---|---|
| Classic A | tuffin | v1 | 0-2 | 100 | lumo |
| Classic A | tuffin | v1 | 0-2 | 75 | fennet |
| Classic A | tuffin | v1 | 0-2 | 0-50 | wispur |
| Classic A | tuffin | v1 | 3+ | 100 | grumbo |
| Classic A | tuffin | v1 | 3+ | 75 | slinko |
| Classic A | tuffin | v1 | 3+ | 0-50 | mopple |
| Classic A | tuffin | v2 | 0-2 | 100 | fennet |
| Classic A | tuffin | v2 | 0-2 | 0-75 | wispur |
| Classic A | tuffin | v2 | 3+ | 100 | slinko |
| Classic A | tuffin | v2 | 3+ | 0-75 | mopple |
| Classic A | beakle | v1 | any | 100 | grumbo |
| Classic A | beakle | v1 | any | 75 | slinko |
| Classic A | beakle | v1 | any | 0-50 | mopple |
| Classic A | beakle | v2 | any | 100 | slinko |
| Classic A | beakle | v2 | any | 0-75 | mopple |
| Classic B | spiklet | v1 | 0-2 | 100 | aurelle |
| Classic B | spiklet | v1 | 0-2 | 75 | hoplin |
| Classic B | spiklet | v1 | 0-2 | 0-50 | zephyx |
| Classic B | spiklet | v1 | 3+ | 100 | bramblo |
| Classic B | spiklet | v1 | 3+ | 75 | puddo |
| Classic B | spiklet | v1 | 3+ | 0-50 | inkling |
| Classic B | spiklet | v2 | 0-2 | 100 | hoplin |
| Classic B | spiklet | v2 | 0-2 | 0-75 | zephyx |
| Classic B | spiklet | v2 | 3+ | 100 | puddo |
| Classic B | spiklet | v2 | 3+ | 0-75 | inkling |
| Classic B | nibbin | v1 | any | 100 | bramblo |
| Classic B | nibbin | v1 | any | 75 | inkling |
| Classic B | nibbin | v1 | any | 0-50 | puddo |
| Classic B | nibbin | v2 | any | 100 | inkling |
| Classic B | nibbin | v2 | any | 0-75 | puddo |

Hidden adults: `test/simulation_test.dart` raises seed 7 from birth with no scolding and reaches Old Tobb. Nocto follows the same rule from Zephyx.
