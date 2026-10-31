# Assets

All art and sound is original to Eggling and generated from this repository.

| Asset | Source | Notes |
|---|---|---|
| 22 creatures and the egg | `lib/art/sprites.dart` | 16x16 one-bit. `e` and `m` cells anchor the face. |
| Props, menu icons, 5x7 font | `lib/art/sprites.dart` | Hand-drawn grids |
| Sticker look | `lib/art/sticker.dart` | Body fill, blush and die-cut edge are computed from the sprite |
| Sky and flavours | `lib/art/sky.dart`, `lib/art/shells.dart` | The sky follows local time |
| Animations | `lib/art/manifest.dart`, `lib/ui/pet_stage.dart` | 15 states with frames, timing, loop or return, trigger. Unknown names fall back to idle. |
| 12 sound cues | `tool/gen_sounds.dart` | Square-wave synthesis to WAV |
| App icon | `tool/gen_art_test.dart` | |

To replace art, edit the grids. `test/art_test.dart` checks sizes, faces, props and
that every form in both rosters is drawn.
