# Setup and build

Tested with Flutter 3.44.8, Xcode 26.3 and JDK 17.

- **iOS 15+**. The widget needs iOS 17. The WidgetKit target lives in
  `ios/EgglingWidget`; `ruby tool/add_ios_widget.rb` recreates it in the project
  and is safe to re-run.
- **Signing**: to run on a device, your team needs the App Group
  `group.com.manankumar.eggling` on both `com.manankumar.eggling` and
  `com.manankumar.eggling.widget`. Automatic signing normally creates it.
- **Android**: `release` still signs with the debug key. Add your own keystore
  in `android/app/build.gradle.kts` before publishing.

Regenerating assets:

```bash
dart run tool/gen_sounds.dart
```

```bash
flutter test tool/gen_art_test.dart && ./tool/install_icon.sh
```
