# Firebase Setup Guide

This file contains the exact setup and deployment steps for Lanka Connect.

## 1) Prerequisites

- Flutter SDK installed
- Node.js 22+ installed
- Firebase CLI installed (`npm i -g firebase-tools`)
- FlutterFire CLI installed (`dart pub global activate flutterfire_cli`)
- A Firebase project (`lankaconnect-app`)

## 2) Configure Firebase App Files

From project root:

```bash
firebase login
flutterfire configure --project=lankaconnect-app --platforms=android,ios
```

This generates/updates:
- `lib/firebase_options.dart` (legacy single-env setup)
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Policy for this repository:
- Do not commit `lib/firebase_options.dart`.
- Do not commit `android/app/google-services.json`.
- Do not commit `ios/Runner/GoogleService-Info.plist`.

If any file above is missing, regenerate with:

```bash
flutterfire configure --project=lankaconnect-app --platforms=android,ios
```

Before run/build, validate your machine setup:

```bash
powershell -ExecutionPolicy Bypass -File scripts/firebase_preflight.ps1
```

## 3) Install Dependencies

```bash
flutter pub get
cd functions
npm install
cd ..
```

## 4) Environment-specific FlutterFire config (staging + production)

Generate both runtime option files:

```bash
flutterfire configure --project=<staging-project-id> --platforms=android,ios,web --out=lib/firebase_options_staging.dart
flutterfire configure --project=<production-project-id> --platforms=android,ios,web --out=lib/firebase_options_production.dart
```

App environment is selected with `--dart-define=APP_ENV=<staging|production|emulator>`.

## 5) Deploy Firestore + Functions

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage:rules,functions
```

For alias-based deploys:

```bash
firebase use staging
firebase deploy --only hosting,firestore:rules,firestore:indexes,storage

firebase use production
firebase deploy --only hosting,firestore:rules,firestore:indexes,storage
```

## 6) Run the App

```bash
flutter run
```

Preferred scripts:

```bash
powershell -ExecutionPolicy Bypass -File scripts/run_app_staging.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_app_production.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_app_with_emulators.ps1
```

## 7) Seed Demo Data (for presentation)

- Sign in as an admin user.
- In Home screen app bar, click the dataset icon.
- The app calls Cloud Function `seedDemoData` and inserts demo records.

Created demo entities include:
- provider profile (`users/demo_provider`)
- 3 services (2 approved, 1 pending)
- 2 bookings for the current admin user (accepted + completed)
- 1 review
- 1 notification to confirm seed completed

## 8) Firestore Indexes

If you add new compound Firestore queries and see "index required":

1. Open the error link from Flutter/console log.
2. Add index to `firestore.indexes.json`.
3. Redeploy indexes:

```bash
firebase deploy --only firestore:indexes
```

## 9) Emulator (Optional)

```bash
firebase emulators:start
```

Configured ports:
- Auth: `9099`
- Firestore: `8080`
- Storage: `9199`
- Functions: `5001`
- Emulator UI: `4000`

## Security Note

Do not commit sensitive Firebase config files to public repos.

## Google Maps Checklist

For Android map rendering issues (blank tiles/no map), verify:

1. **Maps SDK for Android** is enabled in Google Cloud.
2. **Billing** is enabled for the project.
3. API key restrictions include:
   - Application restriction: Android app
   - Package: `com.example.lanka_connect`
   - Correct SHA-1 for debug/release keystores
4. Runtime config files used by the app are:
   - `android/app/google-services.json`
   - `lib/firebase_options.dart`
5. `.firebase_templates/*` files are templates only and not runtime sources.
