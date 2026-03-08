# UAT Execution Log

Use this sheet during user acceptance testing with sample users.

## Session Metadata

- Date:
- Build:
- Environment: `staging` / `production`
- Facilitator:
- Observers:
- Total participants:

## Participant Matrix

| Participant ID | Role | Device | App Version | Consent Recorded |
|---|---|---|---|---|
| UAT-01 | Seeker |  |  | Yes/No |
| UAT-02 | Provider |  |  | Yes/No |
| UAT-03 | Admin |  |  | Yes/No |

## Scenario Checklist

Mark each scenario as `Pass`, `Fail`, or `Blocked`.

| Scenario | Expected Result | Status | Notes / Evidence |
|---|---|---|---|
| Sign in with assigned role | Correct dashboard opens |  |  |
| Provider creates service | Service saved as `pending` |  |  |
| Admin approves service | Provider gets notification |  |  |
| Seeker creates booking | Booking visible to seeker + provider |  |  |
| Provider accepts booking | Booking moves to `accepted` |  |  |
| Seeker opens payment screen | Amount + methods rendered |  |  |
| Card payment initiation | Checkout redirect is opened |  |  |
| Bank transfer submission | Attempt saved as `pending_verification` |  |  |
| Admin verifies transfer | Booking moves to `paid` |  |  |
| Booking chat | Messages visible to participants only |  |  |
| Seeker submits review | Provider aggregate rating updates |  |  |

## Satisfaction Snapshot

Use a 1-5 scale (1 = poor, 5 = excellent).

| Participant ID | Ease of Use | Performance | Trust in Payment Flow | Overall |
|---|---|---|---|---|
| UAT-01 |  |  |  |  |
| UAT-02 |  |  |  |  |
| UAT-03 |  |  |  |  |

## Defects and Action Items

| ID | Severity | Description | Owner | Target Date | Status |
|---|---|---|---|---|---|
| UAT-DEF-01 |  |  |  |  | Open/In Progress/Closed |

## Sign-off

- Product owner sign-off:
- Technical supervisor sign-off:
- Decision: `Accepted` / `Accepted with conditions` / `Not accepted`
