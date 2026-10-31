#!/bin/zsh
# Resizes build/art/icon.png into the iOS and Android icon sets.
set -e
src=build/art/icon.png
ios=ios/Runner/Assets.xcassets/AppIcon.appiconset
for f in $ios/*.png; do
  size=$(sips -g pixelWidth "$f" | tail -1 | awk '{print $2}')
  sips -z "$size" "$size" "$src" --out "$f" >/dev/null
done
for pair in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  sips -z "${pair#*:}" "${pair#*:}" "$src" --out "android/app/src/main/res/mipmap-${pair%:*}/ic_launcher.png" >/dev/null
done
