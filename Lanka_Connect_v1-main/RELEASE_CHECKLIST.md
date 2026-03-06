# Lanka Connect — Release / Store Publishing Checklist

Use this checklist when preparing a build for Google Play or Apple App Store.

---

## 1. App Identity

- [x] Change `applicationId` from `com.example.lanka_connect` to `com.lankaconnect.app`
- [ ] Update iOS bundle identifier in Xcode to match (`com.lankaconnect.app`)
- [ ] Register the app on [Google Play Console](https://play.google.com/console)
- [ ] Register the app on [App Store Connect](https://appstoreconnect.apple.com)

## 2. Signing (Android)

1. Generate an upload keystore:
   ```
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA ^
     -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/keystore.properties`:
   ```properties
   storeFile=../upload-keystore.jks
   storePassword=<your-password>
   keyAlias=upload
   keyPassword=<your-password>
   ```
3. **Never commit** `upload-keystore.jks` or `keystore.properties` to version control.

## 3. Signing (iOS)

- [ ] Set up an Apple Developer account and provisioning profiles.
- [ ] Configure signing in Xcode → Runner → Signing & Capabilities.

## 4. Version Bumping

Before each release update `pubspec.yaml`:
```yaml
version: 1.1.0+2   # <major>.<minor>.<patch>+<buildNumber>
```
`versionCode` on Android auto-reads from `flutter.versionCode`.

## 5. App Icon & Splash Screen

- [ ] Replace `android/app/src/main/res/mipmap-*` with production icons.
- [ ] Replace `ios/Runner/Assets.xcassets/AppIcon.appiconset` images.
- [ ] Consider adding `flutter_launcher_icons` and `flutter_native_splash` packages.

## 6. Build Commands

```bash
# Android App Bundle (recommended for Play Store)
flutter build appbundle --release

# iOS Archive
flutter build ipa --release

# Web (Firebase Hosting)
flutter build web --release --dart-define=APP_ENV=production
firebase use production
firebase deploy --only hosting
```

## 6A. Environment Promotion

- [ ] Staging project configured and mapped as `staging` in `.firebaserc`
- [ ] Production project configured and mapped as `production` in `.firebaserc`
- [ ] `develop` branch deploys automatically to staging
- [ ] `main`/`v*` deploy requires GitHub `production` environment approval
- [ ] FlutterFire env files regenerated:
  - `lib/firebase_options_staging.dart`
  - `lib/firebase_options_production.dart`

## 7. Store Listing Assets

- [ ] App title: **Lanka Connect**
- [ ] Short description (80 chars)
- [ ] Full description (4000 chars)
- [ ] Screenshots: phone (min 2), tablet (optional), web
- [ ] Feature graphic: 1024×500
- [ ] Privacy Policy URL (required): host at `https://lankaconnect.web.app/privacy`
- [ ] Category: Business / Local Services

## 8. Pre-Submit Validation

- [ ] `flutter analyze` — zero issues
- [ ] Run all unit tests: `flutter test`
- [ ] Run integration tests with emulators
- [ ] Test release build on a physical device
- [ ] Verify production run uses `APP_ENV=production`
- [ ] Verify staging run uses `APP_ENV=staging`
- [ ] Verify Firebase production project credentials (`google-services.json` / `GoogleService-Info.plist`)
- [ ] Confirm Firestore security rules are deployed (`firebase deploy --only firestore:rules`)
- [ ] Confirm Storage rules deployed (`firebase deploy --only storage`)
- [ ] Confirm Cloud Functions deployed (`firebase deploy --only functions`)

## 9. Post-Release

- [ ] Enable Crashlytics dashboard monitoring
- [ ] Set up Play Console crash / ANR alerts
- [ ] Tag the release in Git: `git tag v1.0.0 && git push --tags`
