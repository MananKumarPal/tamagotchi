# Widgets

The Dart simulation is the only simulation. Native code never computes game rules.

## Contract (schema 1)

Both platforms keep three things in shared storage: the App Group container on
iOS, `filesDir/widget` on Android.

| File | Writer | Contents |
|---|---|---|
| `snapshot.json` | App | Pet name and flavour colours (`accent`, `soft`) plus forecast entries: `at`, `pose`, `hint`, `hunger`, `happy`, `canFeed`, `canPlay` |
| `pose_<pose>.png` | App | Current form at 8x, for idle, happy, call, sick, sleep, egg, departed |
| `actions.jsonl` | Widget | One `{"id","type","at"}` per line. Types: `meal`, `snack` |

`lib/domain/widget_codec.dart` owns this format. Changing it means updating
`ios/EgglingWidget/EgglingWidget.swift` and `EgglingWidgetProvider.kt` too.

## How a tap works

1. The widget appends the action to disk, and only then redraws.
2. It shows the snapshot plus queued taps, and says "Saved. Applied when you open Eggling".
3. On next open, the app replays each tap at its own timestamp, saves, acks the
   queue, then publishes. Ack comes first so a tap is never shown twice.
4. Applied ids are stored on the pet, so a crash before the ack cannot apply one twice.

A tap that turns out to be invalid, for instance if the pet had already fallen
asleep, is consumed and does nothing.

## Limits

- **iOS** renders a timeline of snapshots. The system decides when it refreshes.
  Interactive buttons need iOS 17.
- **Android** flavour tints need API 31; older versions keep the default colours.
- **Android** uses RemoteViews, a 30-minute periodic update and an inexact alarm
  for the next forecast change. Doze can delay it.
- Neither widget animates continuously, and a late refresh never costs care
  mistakes: mistakes come only from the simulation's timestamps.
- A widget tap cannot prevent a call whose deadline has passed by the time it was tapped.
- If the app is not opened for 24 hours past the forecast, the widget asks you to check in.
- Forecasts assume no further care. Baby stages change so often that 48 entries
  may cover only a few hours.
