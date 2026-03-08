# Demo APK Build Runbook

## Purpose

Generate a presentation-ready Android APK from the production flavor.

## Preconditions

- Flutter SDK installed and available in PATH.
- Android SDK + build tools configured.
- Project dependencies resolved (`flutter pub get`).
- Firebase production config file present:
  - `android/app/src/production/google-services.json`

## Build Command

```bash
flutter build apk --release --flavor production --dart-define=APP_ENV=production
```

## Output Artifact

- Primary APK path:
  - `build/app/outputs/flutter-apk/app-production-release.apk`

## Optional Version Stamping

Use explicit version metadata for presentation builds:

```bash
flutter build apk --release --flavor production --dart-define=APP_ENV=production --build-name=1.0.1 --build-number=2
```

## Validation Checklist

- App launches on physical device.
- Login works against target Firebase project.
- Booking list loads correctly.
- Payment screen opens and renders methods.
- No crash on startup/navigation.

## Notes

- If `android/keystore.properties` is missing, this project falls back to debug signing for release builds.
- For store submission, configure proper release keystore and signing credentials.
