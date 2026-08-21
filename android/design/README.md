# Icon sources

SVG masters for the app icon. Regenerate the PNGs from these rather than
editing the PNGs by hand.

* `icon.svg` — the full icon, green field with the beacon-and-trail mark.
  Source for the legacy launcher icons and the Play Store 512x512.
* `icon-adaptive-foreground.svg` — the same mark alone on a 432x432 canvas,
  scaled to sit inside the adaptive-icon safe zone (the launcher crops to a
  circle or squircle). Paired with `@color/ic_launcher_background`.
* `splash-logo.svg` — the mark in darker tints for the white splash screen.

## Why this mark, not the township seal

The first release used the official Warrington Township seal as the app
icon. Google Play rejected it under the Impersonation policy ("Misleading
Icon"): a government seal on an app published from a non-township developer
account implies an official endorsement. The seal was also on the splash
screen and was replaced there too.

Keep the seal out of the icon, the splash screen, the Play listing graphics,
and the app title unless the app is actually published from a township-owned
developer account with written permission on file.

## Regenerating

```sh
cd android
# legacy launcher icons
for pair in "mdpi 48" "hdpi 72" "xhdpi 96" "xxhdpi 144" "xxxhdpi 192"; do
  set -- $pair
  rsvg-convert -w $2 -h $2 design/icon.svg -o app/src/main/res/mipmap-$1/ic_launcher.png
  rsvg-convert -w $2 -h $2 design/icon.svg -o app/src/main/res/mipmap-$1/ic_launcher_round.png
done
# adaptive foregrounds
for pair in "mdpi 108" "hdpi 162" "xhdpi 216" "xxhdpi 324" "xxxhdpi 432"; do
  set -- $pair
  rsvg-convert -w $2 -h $2 design/icon-adaptive-foreground.svg \
    -o app/src/main/res/mipmap-$1/ic_launcher_foreground.png
done
# splash + Play Store icon
rsvg-convert -w 432 -h 432 design/splash-logo.svg -o app/src/main/res/drawable/splash_logo.png
rsvg-convert -w 512 -h 512 design/icon.svg -o ../play-listing/app-icon-512.png
```
