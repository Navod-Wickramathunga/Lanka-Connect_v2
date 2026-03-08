# Thesis Chapter: System Architecture and Testing Results

## 1. Architectural Overview

Lanka Connect is implemented as a Flutter multi-platform client with Firebase as the primary
backend platform. The architecture follows a hybrid model:

- Direct client-to-Firebase access for core CRUD use cases (service browsing, booking lists, chat, profile management).
- Cloud Functions for server-controlled workflows where trust boundaries are required (payment initiation, payment verification, webhook handling, receipt dispatch).

This separation preserves fast product iteration while reducing risk for payment-related state
transitions and external-provider integrations.

## 2. Core Components

1. Presentation Layer (Flutter UI)
- Role-aware screens for seeker, provider, and admin users.
- Stateful and stream-based widgets bound to Firestore collections.

2. Application Service Layer
- Utility services for offers, notifications, reviews, and validation.
- Payment UI orchestration for card checkout, saved cards, and bank transfer submission.

3. Data and Integration Layer
- Firebase Auth: identity and session management.
- Cloud Firestore: transactional data store for bookings, payments, reviews, messages, and notifications.
- Cloud Storage: media asset management.
- Cloud Functions: callable and HTTP endpoints for secure payment workflows.
- External providers: PayHere (gateway), Twilio (SMS), SendGrid (email receipts).

## 3. Payment Subsystem Architecture

The payment subsystem is designed as an event-driven state model:

1. Client submits payment request for an accepted booking.
2. Cloud Function creates `payments/{attemptId}` and marks booking payment as pending.
3. Completion path:
- Card path: PayHere webhook validates signature and finalizes status.
- Bank transfer path: admin verification callable finalizes status.
4. Booking payment fields (`paymentStatus`, `paymentAttemptId`, amounts, timestamps) are synchronized.
5. Receipt delivery is attempted over SMS and email; delivery logs are persisted.

This approach prevents client-side tampering of sensitive payment transitions and centralizes audit
traces in Firestore.

## 4. Testing Strategy

Testing was executed as a layered strategy:

1. Unit tests
- Validators, role helpers, model parsing, utility functions.

2. Widget tests
- Authentication entry and selected screen rendering/interaction.

3. Integration tests
- Emulator-backed flow tests for rules and core scenario behavior.
- Device-targeted validation for notifications and booking/service flows.

4. Manual UAT
- Scenario checklist executed by representative user roles (seeker/provider/admin), including booking lifecycle and payment outcomes.

## 5. Testing Results Summary

- Unit and widget suites pass in local execution (`flutter test`).
- Integration suites are available under `integration_test/` and validated on emulator-backed targets.
- Payment flow assertions now include:
  - Duplicate-attempt blocking through booking payment state checks.
  - Pending and paid state visibility in UI.
  - Booking state synchronization on successful and failed payment finalization.

## 6. Key Engineering Outcomes

1. Security posture improved through backend-enforced payment transitions.
2. UX quality improved with explicit loading, pending, paid, failed, and empty states in payment screens.
3. Assessment documentation aligned with the implemented architecture (client + Cloud Functions runtime).

## 7. Remaining Work

- Formalize CI automation for full integration matrix.
- Add refund/dispute workflows and finance reconciliation tooling.
- Extend UAT execution with a larger sample and statistically reported satisfaction metrics.
