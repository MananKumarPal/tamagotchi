# Architecture

| Layer | Path | Job |
|---|---|---|
| Domain | `lib/domain` | Pure rules, simulation, games, forecast, reminder plan, widget JSON. No Flutter imports. |
| Data | `lib/data` | Versioned save codec, crash-safe file store. |
| Game | `lib/game/game_controller.dart` | Owns the live pet. Every change runs through one queue, then saves and publishes. |
| Platform | `lib/platform` | Clock, widget channel, notifications, sound, behind `GamePlatform`. |
| Art | `lib/art` | Sprites, animation manifest, LCD renderer, shells. |
| UI | `lib/ui` | `kit.dart` holds the components; the rest are screens. Reads the controller, sends commands. |

## Simulation

`Simulation.advance`, `apply` and `check` are the interface. All due moments are
absolute timestamps on `PetState`, fired in time order, so one long catch-up equals
many short steps (tested). Randomness is a hash of the saved seed and a saved
counter, so reopening the app cannot change an outcome.

Rule numbers live in `lib/domain/rules.dart`, tagged [M] manual, [S] specialist or
[D] design value. Rosters and evolution tables are data in `forms.dart`.

## Clocks

- Backward by up to 24 h: the pet holds still until real time catches up.
- Backward by more: treated as a corrected clock, timers rebase with no penalty.
- Forward by more than 45 days: the excess is skipped.
- There is no clock setting. Care pause in Settings is the deliberate way to stop time.

## Offline

Nothing in the app opens a network connection. Pets, settings and the widget files
all stay on the device unless the player exports a save.
