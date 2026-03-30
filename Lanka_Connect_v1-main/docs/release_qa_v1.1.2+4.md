# Release QA - v1.1.2+4

## Release Notes

- Refreshed mobile login UI while keeping the Lanka Connect product name.
- Hardened shared back navigation for mobile and web pushed pages.
- Exposed seeker-entered scheduling details in provider request and booking views.
- Synced profile images across app and web sessions using Firestore and auth fallbacks.
- Added Sri Lanka district and city cascading for provider profile editing.
- Improved notification center behavior with remove, clear all, details, and related-page routing.
- Stopped blocking startup on location permission; nearby flows now request it only when needed.
- Kept banner and promotion management on web admin only.
- Version bumped to `1.1.2+4`.

## Notification Sound

- Added a softer Android notification sound for foreground local alerts and Android FCM push delivery.
- iOS continues to use the standard system notification sound so alerts stay in the normal notification range.

## Automated QA

- Run `flutter analyze`.
- Run `flutter test`.
- Confirm notification routing tests cover chat, payment, request, booking, and fallback cases.
- Confirm widget tests cover shared web back-button visibility, notification toolbar and item actions, and profile identity fallbacks.

## Manual QA - Web

- Sign in and sign up reject malformed email addresses with the corrected error copy.
- Pushed pages show a back button; shell tab switches do not show a false back action.
- Theme toggle remains visible in light mode.
- Profile image appears after re-login when the image exists only in auth or Firestore.
- Admin web still exposes banner and promotion management.

## Manual QA - Mobile

- Seeker booking flow can return using the back button.
- Nearby services request location only when the feature is used.
- Disabled device location shows the fallback and open-settings path.
- Provider request and booking cards show date, time, and notes from seeker submissions.
- Notification list supports remove, clear all, detail dialog, and related-page navigation.
- Provider profile city options change when district changes.

## Regression Checks

- Existing users without profile images still get initials avatars.
- Legacy district and city values do not crash profile rendering.
- Partial notification payloads still open safely and fall back to Notifications when needed.
- Notification-triggered routes work even when the current navigator stack is shallow.
