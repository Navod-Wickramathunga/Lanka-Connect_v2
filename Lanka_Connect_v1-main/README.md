# Lanka Connect

Full-stack Flutter + Firebase service marketplace demo.

## Spark/Free Demo Mode (Recommended)

This app now runs end-to-end on Firebase Spark/free without deployed Cloud Functions.

- Demo seeding runs in-app via Firestore writes.
- Service moderation notifications are written in-app.
- Provider rating aggregates (`averageRating`, `reviewCount`) are updated in-app when reviews are submitted.

## Quick Start

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Configure Firebase for this app:
```bash
firebase login
flutterfire configure --project=lankaconnect-app --platforms=android,ios
```

The following files are machine-local and must be regenerated on each machine:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

3. Run Firebase preflight validation:
```bash
powershell -ExecutionPolicy Bypass -File scripts/firebase_preflight.ps1
```

4. Install Cloud Functions dependencies:
```bash
cd functions
npm install
cd ..
```

5. Deploy backend config:
```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

6. Run app (default production if no `APP_ENV` is passed):
```bash
flutter run
```

Preferred environment scripts:
```bash
# staging
powershell -ExecutionPolicy Bypass -File scripts/run_app_staging.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_web_staging.ps1

# production
powershell -ExecutionPolicy Bypass -File scripts/run_app_production.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_web_production.ps1
```

## Testing With Emulators (isolated test backend)

Use emulators only for local testing. Emulator users/data do not sync with production Firebase.

Run against local emulators:
```bash
powershell -ExecutionPolicy Bypass -File scripts/start_emulators.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_app_with_emulators.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_web_with_emulators.ps1
```

For physical Android devices on Wi-Fi, pass your PC LAN IP:
```bash
powershell -ExecutionPolicy Bypass -File scripts/run_app_with_emulators.ps1 -EmulatorHost 192.168.x.x
```

For web emulator testing with a non-localhost host override:
```bash
powershell -ExecutionPolicy Bypass -File scripts/run_web_with_emulators.ps1 -EmulatorHost 192.168.x.x
```

These emulator scripts now pass both:
- `--dart-define=APP_ENV=emulator`
- `--dart-define=USE_FIREBASE_EMULATORS=true`

To use the same account on app and hosted web, sign in/create users in production mode only.

Optional (Blaze/advanced): deploy Cloud Functions
```bash
firebase deploy --only functions
```

## Environment Model (`APP_ENV`)

The app supports three runtime environments:
- `APP_ENV=staging`
- `APP_ENV=production`
- `APP_ENV=emulator`

Production UI hides environment labels; staging and emulator show backend labels to prevent mistakes.

## Firebase Projects and Aliases

`.firebaserc` aliases:
- `staging`
- `production`

Before deploying, set real project IDs in `.firebaserc` and generate environment-specific FlutterFire files:

```bash
flutterfire configure --project=<staging-project-id> --platforms=android,ios,web --out=lib/firebase_options_staging.dart
flutterfire configure --project=<production-project-id> --platforms=android,ios,web --out=lib/firebase_options_production.dart
```

## CI/CD Promotion Flow

- Push to `develop`: auto deploy to **staging**
- Push to `main` or tag `v*`: deploy to **production** via GitHub `production` environment approval gate

For full setup details, see `FIREBASE_SETUP.md`.

## Demo Readiness Flow

1. Sign in as an `admin` user.
2. On Home app bar, tap the dataset icon to run demo seeding.
3. Verify demo data:
- `Services` tab: approved and pending sample services
- `Bookings` tab: accepted and completed sample bookings
- `Notifications`: "Demo data ready" message

## Submission Features

- In-app backend effects (Spark-friendly): new services are saved with `status: pending`.
- In-app backend effects (Spark-friendly): provider is notified when admin approves a service.
- In-app backend effects (Spark-friendly): provider `averageRating` and `reviewCount` are updated on review submission.
- In-app backend effects (Spark-friendly): admin dataset action seeds demo data without callable Functions.
- Firestore composite indexes in `firestore.indexes.json`
- Improved loading/empty/error states in core screens
- Stronger form validation (password, price, lat/lng, review comment, chat text)
- Guardrail: service creation is restricted to `status: pending` by both app code and Firestore rules

## Report Assets

Use `REPORT_SCREENSHOTS.md` as the screenshot checklist for your report.
