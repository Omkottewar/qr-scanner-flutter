Drop the three QR 4 Emergency images here with these exact filenames:

- `logo.png`        — QR 4 Emergency circular logo. Also the source for the
                      Android/iOS launcher icon (see `flutter_launcher_icons`
                      block in `pubspec.yaml`). Use a square PNG, ideally
                      1024x1024, with the circular badge centered.
- `no_parking.png`  — Car with no-parking QR sticker (used in "WRONG PARKING" carousel slide)
- `accident.png`    — Crashed car with QR sticker (used in "ACCIDENT EMERGENCY" carousel slide)

After updating `logo.png`, regenerate the launcher icons from the same file:

    flutter pub get
    dart run flutter_launcher_icons

Then `flutter run`. The in-app badges (home + login) update on hot restart;
the launcher icon requires a full reinstall on the device.
