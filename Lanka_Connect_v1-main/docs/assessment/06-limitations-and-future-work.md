# Limitations and Future Work

## Current Limitations

1. Push notifications are still primarily document-driven.
- Notification records are created in Firestore and read in-app.
- Full FCM delivery lifecycle (token rotation, background delivery analytics) needs expansion.

2. Payment hardening is functional but not complete.
- Gateway checkout + webhook + bank-transfer verification are implemented.
- Refund workflows, dispute handling, and reconciliation dashboards are not yet implemented.

3. Integration execution remains target-dependent.
- `integration_test` is currently validated mostly on Android device/emulator targets.
- A wider CI matrix (device farm and repeatable web strategy) is still pending.

4. Operational observability can be improved.
- Logging exists in Cloud Functions, but centralized alerting/SLO dashboards are limited.

## Future Work

1. Add payment reliability enhancements.
- Introduce explicit idempotency keys and retry-safe state transitions.
- Add refund APIs and settlement exports for finance reporting.

2. Complete FCM production push pipeline.
- Persist/manage device tokens securely.
- Add segmented targeting and delivery/engagement reporting.

3. Improve backend governance and monitoring.
- Add Cloud Logging metrics and alert policies for payment failures and webhook anomalies.
- Track moderation and support SLAs via dashboard panels.

4. Expand QA automation.
- Run emulator-backed integration suites in CI on every release branch.
- Add deterministic seed/teardown workflows and regression snapshots.
