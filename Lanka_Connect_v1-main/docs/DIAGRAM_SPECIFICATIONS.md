# Lanka Connect – Diagram Specifications

Use this document as the reference for drawing each required diagram.

---

## 1. Class Diagram (High-Level)

Draw the following classes with their fields and data types, then connect them with the relationships listed below.

### Classes

**UserProfile**
```
- uid : String
- role : String  (seeker | provider | admin | guest)
- name : String
- contact : String
- district : String
- city : String
- skills : List<String>
- bio : String
- imageUrl : String
- fcmToken : String
- averageRating : double
- reviewCount : int
```

**ServicePost**
```
- id : String
- providerId : String
- title : String
- category : String
- price : double
- location : String
- description : String
- status : String  (pending | approved | rejected)
- imageUrls : List<String>
- rating : double
- reviewCount : int
- district : String
- city : String
- lat : double?
- lng : double?
```

**Booking**
```
- id : String
- serviceId : String
- providerId : String
- seekerId : String
- status : String  (pending | accepted | rejected | completed | cancelled)
- date : DateTime?
- amount : double?
- serviceTitle : String
- paymentStatus : String
- reviewed : bool
```

**Review**
```
- id : String
- bookingId : String
- serviceId : String
- providerId : String
- reviewerId : String
- rating : int  (1–5)
- comment : String
```

**ChatMessage**
```
- id : String
- chatId : String   (= bookingId)
- senderId : String
- text : String
- createdAt : DateTime
```

**Payment**
```
- id : String
- bookingId : String
- seekerId : String
- providerId : String
- amount : double
- currency : String  (LKR)
- status : String  (initiated | pending_gateway | success | failed | pending_verification | paid)
- method : String  (card | bank_transfer)
- gatewayOrderId : String?
- transferRef : String?
```

**Notification**
```
- id : String
- recipientId : String
- title : String
- body : String
- type : String
- referenceId : String
- isRead : bool
- createdAt : DateTime
```

**Offer**
```
- id : String
- title : String
- isActive : bool
- discountType : OfferDiscountType  (percentage | flat)
- discountValue : double
- targetServiceId : String?
- targetProviderId : String?
- targetCategory : String?
- minAmount : double?
- startsAt : DateTime?
- endsAt : DateTime?
```

### Enumerations

| Enum | Values |
|------|--------|
| `UserRole` | seeker, provider, admin, guest |
| `ServiceStatus` | pending, approved, rejected |
| `BookingStatus` | pending, accepted, rejected, completed, cancelled |
| `PaymentStatus` | initiated, pending_gateway, success, failed, pending_verification, paid |
| `OfferDiscountType` | percentage, flat |

### Relationships

| From | Relationship | To | Label |
|------|-------------|-----|-------|
| UserProfile (provider) | 1 ──── * | ServicePost | creates |
| UserProfile (seeker) | 1 ──── * | Booking | places |
| ServicePost | 1 ──── * | Booking | for |
| Booking | 1 ──── 0..1 | Review | has |
| Booking | 1 ──── * | ChatMessage | contains |
| Booking | 1 ──── 0..1 | Payment | settled by |
| UserProfile | 1 ──── * | Notification | receives |
| Offer | * ──── 0..1 | ServicePost | targets (optional) |
| Offer | * ──── 0..1 | UserProfile (provider) | targets (optional) |

---

## 2. Use Case Diagram

### Actors

- **Guest** – unauthenticated visitor (mobile app)
- **Seeker** – authenticated service buyer (mobile app)
- **Provider** – authenticated service seller (mobile app)
- **Admin** – platform administrator (web dashboard + mobile app)

### Use Cases per Actor

**Guest**
- Browse approved service listings
- Search services by keyword
- Filter services by category / location / price
- View service detail screen
- View service location on map
- Register new account

**Seeker** *(extends Guest)*
- Login / Logout
- Reset password via email
- Edit personal profile
- Browse & filter services (Near Me / map view)
- Book a service
- Cancel a pending booking
- Post a service request to a provider
- Chat with provider (per booking)
- Pay via credit/debit card (PayHere)
- Pay via bank transfer
- Save card token for future payments
- Apply discount offer at checkout
- Rate and review a completed booking
- View notification centre
- View booking history with status tabs

**Provider**
- Login / Logout
- Reset password via email
- Edit personal profile (skills, bio, bank details)
- Create service listing (title, category, price, images, GPS)
- Edit own service listing
- Delete own service listing
- View own listing moderation status
- Accept or reject an incoming booking
- Mark a booking as completed
- Chat with seeker (per booking)
- View provider dashboard (earnings, ratings, bookings)
- Manage provider bank account details

**Admin**
- Login to web administration dashboard
- View and search service moderation queue
- Approve a pending service listing
- Reject a pending service listing
- Manage promotional banners (create / edit / toggle active)
- Manage marketing promotions (create / edit)
- Manage discount offers (create / edit / target / time-bound)
- Verify bank transfer payments
- View and modify user accounts / roles
- View platform analytics (bookings, revenue, users)
- Trigger demo data seed

### Include / Extend relationships

- "Book a service" **includes** "View service detail"
- "Pay via card" **includes** "Apply discount offer at checkout"
- "Pay via bank transfer" **extends** "Admin: Verify bank transfer"
- "Rate and review" **extends** "Booking must be Completed"
- "Approve/Reject service" **extends** "Admin: View moderation queue"

---

## 3. UML State Machine Diagrams

Draw three separate state machine diagrams:

### 3a. Booking Status State Machine

```
[*] ──► pending
pending ──► accepted      (Provider accepts)
pending ──► rejected      (Provider rejects)
pending ──► cancelled     (Seeker cancels)
accepted ──► completed    (Provider marks complete)
accepted ──► cancelled    (Seeker cancels)
completed ──► [*]
rejected ──► [*]
cancelled ──► [*]
```

### 3b. Service Listing Status State Machine

```
[*] ──► pending           (Cloud Function setServicePendingOnCreate fires on create)
pending ──► approved      (Admin approves → notifyOnServiceApproval fires)
pending ──► rejected      (Admin rejects → notifyOnServiceApproval fires)
approved ──► [*]          (visible to seekers)
rejected ──► [*]          (hidden from seekers)
```

### 3c. Payment Status State Machine

```
--- Card Path ---
[*] ──► initiated
initiated ──► pending_gateway    (createPayHereCheckoutSession called)
pending_gateway ──► success      (payHereWebhook confirms)
pending_gateway ──► failed       (payHereWebhook confirms failure)
success ──► [*]
failed ──► [*]

--- Bank Transfer Path ---
[*] ──► initiated
initiated ──► pending_verification  (submitBankTransfer called)
pending_verification ──► paid       (Admin: verifyBankTransfer approves)
paid ──► [*]
```

---

## 4. ER Diagram

Draw entities as rectangles with PK/FK notation. Use crow's-foot notation for cardinality.

### Entities and Attributes

| Entity | Key Fields |
|--------|-----------|
| **users** | uid (PK), role, name, contact, district, city, skills[], bio, imageUrl, fcmToken, averageRating, reviewCount |
| **services** | id (PK), providerId (FK→users), title, category, price, location, description, status, imageUrls[], rating, reviewCount, district, city, lat, lng, createdAt |
| **bookings** | id (PK), serviceId (FK→services), providerId (FK→users), seekerId (FK→users), status, amount, date, serviceTitle, paymentStatus, reviewed, createdAt |
| **requests** | id (PK), seekerId (FK→users), providerId (FK→users), serviceId (FK→services), message, status, createdAt |
| **reviews** | id (PK), bookingId (FK→bookings), serviceId (FK→services), providerId (FK→users), reviewerId (FK→users), rating (1-5), comment, createdAt |
| **messages** | id (PK), chatId (FK→bookings), senderId (FK→users), text, createdAt |
| **notifications** | id (PK), recipientId (FK→users), title, body, type, referenceId, isRead, createdAt |
| **payments** | id (PK), bookingId (FK→bookings), seekerId (FK→users), providerId (FK→users), amount, currency, status, method, gatewayOrderId?, transferRef?, createdAt |
| **paymentReceipts** | id (PK), paymentId (FK→payments), seekerId (FK→users), smsStatus, emailStatus, createdAt |
| **providerBankAccounts** | id (PK), providerId (FK→users), bankName, accountHolderName, accountNumberMasked, accountNumberEncryptedRef, branch, createdAt |
| **savedPaymentMethods** | id (PK), seekerId (FK→users), cardBrand, lastFour, expiry, tokenRef, createdAt |
| **banners** | id (PK), title, imageUrl, ctaLink, isActive, targetRole, createdAt |
| **promotions** | id (PK), title, description, startsAt, endsAt, isActive, createdAt |
| **offers** | id (PK), title, isActive, discountType, discountValue, targetServiceId (FK→services)?, targetProviderId (FK→users)?, targetCategory?, minAmount?, startsAt, endsAt |

### Relationships

| Entity A | Cardinality | Entity B | Notes |
|----------|------------|---------|-------|
| users | 1 : N | services | One provider creates many listings |
| users (seeker) | 1 : N | bookings | One seeker places many bookings |
| users (provider) | 1 : N | bookings | One provider receives many bookings |
| services | 1 : N | bookings | One service has many bookings |
| bookings | 1 : 0..1 | reviews | A completed booking may have one review |
| bookings | 1 : N | messages | One booking has many chat messages |
| bookings | 1 : 0..1 | payments | One booking has at most one payment |
| payments | 1 : 0..1 | paymentReceipts | One payment has at most one receipt record |
| users | 1 : N | notifications | One user receives many notifications |
| users | 1 : N | providerBankAccounts | One provider may register multiple bank accounts |
| users | 1 : N | savedPaymentMethods | One seeker may save multiple cards |
| offers | 0..1 : N | services | Optional targeting to a specific service |
| offers | 0..1 : N | users (provider) | Optional targeting to a specific provider |

---

## 5. System Architecture Diagram

Draw as a layered architecture with three horizontal tiers and external services on the side.

### Layers (top to bottom)

```
┌─────────────────────────────────────────────────────────┐
│                    CLIENT TIER                           │
│                                                         │
│  ┌─────────────────────────┐  ┌──────────────────────┐  │
│  │  Mobile App             │  │  Web Admin Dashboard  │  │
│  │  Flutter (Dart)         │  │  Flutter Web (Dart)   │  │
│  │  Android + iOS          │  │  Firebase Hosting     │  │
│  └─────────────────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                 FIREBASE BACK-END TIER                   │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Firebase    │  │  Cloud       │  │  Firebase    │  │
│  │  Auth        │  │  Firestore   │  │  Storage     │  │
│  │              │  │  (13 colls.) │  │  (images)    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Cloud Functions v2  (Node.js 22, TypeScript)    │   │
│  │                                                   │   │
│  │  setServicePendingOnCreate  (Firestore trigger)   │   │
│  │  notifyOnServiceApproval    (Firestore trigger)   │   │
│  │  updateProviderRating       (Firestore trigger)   │   │
│  │  sendPushOnNotificationCreate (Firestore trigger) │   │
│  │  createPayHereCheckoutSession (Callable)          │   │
│  │  payHereWebhook             (HTTP endpoint)       │   │
│  │  submitBankTransfer         (Callable)            │   │
│  │  verifyBankTransfer         (Callable)            │   │
│  │  dispatchPaymentReceipts    (Callable)            │   │
│  │  seedDemoData               (Callable)            │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐                     │
│  │  Firebase    │  │  Firebase    │                     │
│  │  Cloud       │  │  Crashlytics │                     │
│  │  Messaging   │  │  (monitoring)│                     │
│  └──────────────┘  └──────────────┘                     │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              THIRD-PARTY INTEGRATION TIER                │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │ PayHere  │  │  Twilio  │  │SendGrid  │  │Google  │  │
│  │(Payments)│  │  (SMS)   │  │ (Email)  │  │Maps    │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Environment Strategy (show as side annotation)
- **Production** – Firebase project `lanka-connect-prod`
- **Staging** – Firebase project `lanka-connect-staging`
- **Emulator** – Local Firebase Emulator Suite
- Selected at compile time via `APP_ENV` build flag

---

## 6. Key Wireframe Screens

These are the minimum screens to wireframe. Sketch them as low-fidelity boxes/labels.

### Mobile Application Screens

| # | Screen | Key UI Elements |
|---|--------|-----------------|
| 1 | **Splash / Onboarding** | App logo, tagline, "Get Started" button, Login link |
| 2 | **Login / Register** | Tabs: Login / Register. Fields: Email, Password. Register adds: Name, Phone, Role picker (Seeker / Provider). Forgot password link. |
| 3 | **Home (Service List)** | Category horizontal scroll bar (9 icons), Search bar, Filter button, List of service cards (thumbnail, title, rating, price, distance), Map View toggle button |
| 4 | **Service Detail** | Top: image gallery carousel. Body: Title, Category badge, Price, Provider name + avatar + rating. Description text. Location embedded map. Reviews list (star + comment). Bottom: "Book Now" CTA button |
| 5 | **Service Map View** | Full-screen Google Map with pinned service markers. Tap marker → mini preview card. "List View" toggle. |
| 6 | **Booking List** | TabBar: All / Pending / Accepted / Completed / Cancelled / Rejected. Each row: Service title, Provider name, Amount, Status chip, Date |
| 7 | **Booking Detail** | Service name, Amount, Status badge, Seeker & Provider info, Timestamps. Action buttons (contextual): Accept / Reject / Complete / Cancel / Pay / Review / Chat |
| 8 | **Chat Screen** | Header: other party's name + service title. Scrollable message bubbles (sent right, received left). Composer row: text field + Send button |
| 9 | **Payment Screen** | Booking summary card (service, amount). Offer/Discount display. Tabs: Card Payment / Bank Transfer. Card tab: "Pay with PayHere" button + Saved cards list. Bank tab: Reference number field + Submit button. |
| 10 | **Provider Dashboard** | Stats cards row (Total Bookings, Revenue, Avg Rating). Level/badge widget. Monthly bookings bar chart. Recent bookings list. |
| 11 | **Notification Centre** | List of notification cards: Icon, Title, Body text, Timestamp. Unread items highlighted. "Mark all read" button. |
| 12 | **Profile / Edit Profile** | Avatar image (tap to change). Fields: Name, Contact, District, City, Bio, Skills (tags). Save button. |

### Web Administration Screens

| # | Screen | Key UI Elements |
|---|--------|-----------------|
| 13 | **Admin Dashboard** | Left sidebar: Services / Banners / Promotions / Offers / Users / Analytics. Top header: Admin name, logout. Main area: summary stat cards (Total Users, Total Bookings, Pending Services). |
| 14 | **Service Moderation** | TabBar: Pending / Approved / Rejected. Search bar. Table rows: Service title, Category, Provider, Price, Submitted time, SLA badge (green/amber/red), Approve button, Reject button. |

---

## 7. Wireframe Diagram (Navigation Flow)

Draw this as a connected box diagram showing navigation routes between screens.

```
Splash
  │
  ├──► Login / Register
  │         │
  │         ▼
  │    (Role-based routing)
  │         │
  │    ┌────┴──────┬──────────────┐
  │  Seeker     Provider       Admin
  │  Home         Provider       Web
  │    │          Dashboard      Dashboard
  │    │             │
  │    ├── Service Detail ──► Booking Detail ──► Chat
  │    │         │                   │
  │    │         └──► Pay Screen     └──► Review Screen
  │    │
  │    ├── Booking List ──► Booking Detail
  │    │
  │    ├── Notification Centre
  │    │
  │    ├── Service Map View
  │    │
  │    └── Profile Screen
  │
  └──► (Guest: Home, Service Detail – read only)
```

### Navigation routes summary

| From Screen | Action | To Screen |
|------------|--------|-----------|
| Splash | auto-route | Login (unauthenticated) or Home (authenticated) |
| Login | register link | Register |
| Register | success | Home (Seeker) or Provider Dashboard |
| Home | tap service card | Service Detail |
| Home | map toggle | Service Map View |
| Service Detail | "Book Now" | Booking Detail (new pending booking) |
| Booking Detail | "Pay" button | Payment Screen |
| Booking Detail | "Chat" button | Chat Screen |
| Booking Detail | "Review" button | Review Screen |
| Home (nav bar) | Bookings tab | Booking List |
| Home (nav bar) | Notifications tab | Notification Centre |
| Home (nav bar) | Profile tab | Profile Screen |
| Notification | tap | Deep link → relevant screen |
| Admin Dashboard | sidebar: Services | Service Moderation |
| Admin Dashboard | sidebar: Banners | Banner Management |
| Admin Dashboard | sidebar: Offers | Offer Management |
| Admin Dashboard | sidebar: Analytics | Analytics Screen |

---

## 8. Activity Diagram (Workflow View)

Draw three separate activity diagrams, one per key workflow.

### 8a. Service Booking Lifecycle Workflow

```
Start
  │
  ▼
[Seeker] Browse approved services
  │
  ▼
[Seeker] Open service detail → tap "Book Now"
  │
  ▼
[System] Create Booking (status = pending)
  │
  ▼
[System] Send push notification to Provider
  │
  ▼
[Provider] View incoming booking
  │
  ├── Reject ──► [System] Update status = rejected ──► Notify Seeker ──► End
  │
  └── Accept ──► [System] Update status = accepted ──► Notify Seeker
                   │
                   ▼
             [Seeker + Provider] Chat (optional)
                   │
                   ▼
             [Seeker] Pay for booking (card or bank transfer)
                   │
                   ▼
             [System] Payment confirmed / receipts dispatched
                   │
                   ▼
             [Provider] Marks booking as completed
                   │
                   ▼
             [System] Update status = completed ──► Notify Seeker
                   │
                   ▼
             [Seeker] Submits review (1–5 stars + comment)
                   │
                   ▼
             [System] Cloud Function updates Provider averageRating
                   │
                   ▼
                  End
```

### 8b. Service Listing Moderation Workflow

```
Start
  │
  ▼
[Provider] Fills service listing form and submits
  │
  ▼
[Cloud Function: setServicePendingOnCreate]
  Sets status = "pending" (server-side override)
  │
  ▼
[System] Listing appears in Admin moderation queue (SLA timer starts)
  │
  ▼
[Admin] Reviews listing on web dashboard
  │
  ├── Reject ──► [System] status = "rejected"
  │                  │
  │                  ▼
  │             [Cloud Function: notifyOnServiceApproval]
  │             Creates notification → FCM push to Provider
  │                  │
  │                  ▼
  │             [Provider] Receives rejection notification ──► End
  │
  └── Approve ──► [System] status = "approved"
                     │
                     ▼
               [Cloud Function: notifyOnServiceApproval]
               Creates notification → FCM push to Provider
                     │
                     ▼
               [Provider] Receives approval notification
                     │
                     ▼
               [System] Listing visible to all Seekers ──► End
```

### 8c. Card Payment Workflow

```
Start
  │
  ▼
[Seeker] Opens Payment screen for accepted booking
  │
  ▼
[System] Checks offers collection for applicable discount
  │
  ├── Offer found → displays discounted amount
  └── No offer → displays original amount
  │
  ▼
[Seeker] Taps "Pay with PayHere"
  │
  ▼
[Cloud Function: createPayHereCheckoutSession]
  Builds signed checkout session → returns URL
  │
  ▼
[Mobile App] Opens PayHere URL in browser
  │
  ▼
[PayHere Gateway] Seeker enters card details → payment processed
  │
  ├── Payment Failed ──► [payHereWebhook] sets status = "failed" ──► End
  │
  └── Payment Success
          │
          ▼
    [Cloud Function: payHereWebhook]
    Validates MD5 signature → updates status = "success"
          │
          ▼
    [System] Creates notification document
          │
          ▼
    [Cloud Function: sendPushOnNotificationCreate]
    Sends FCM push to Seeker
          │
          ▼
    [Cloud Function: dispatchPaymentReceipts]
    Twilio: sends SMS receipt to Seeker phone
    SendGrid: sends email receipt to Seeker email
          │
          ▼
         End
```

---

## 9. Sequence Diagram (Key Flow – Card Payment)

Participants (left to right):
`Seeker App` | `Cloud Functions` | `Firestore` | `PayHere Gateway` | `FCM` | `Twilio/SendGrid`

```
Seeker App          Cloud Functions        Firestore       PayHere Gateway     FCM       Twilio/SendGrid
    │                      │                   │                 │               │               │
    │──createPayHereCheckout─►                  │                 │               │               │
    │  {bookingId, amount}  │                   │                 │               │               │
    │                       │──read booking────►│                 │               │               │
    │                       │◄──booking data────│                 │               │               │
    │                       │──build signed     │                 │               │               │
    │                       │  checkout params  │                 │               │               │
    │◄──return checkoutUrl──│                   │                 │               │               │
    │                       │                   │                 │               │               │
    │──(open browser)───────────────────────────────────────────►│               │               │
    │                       │                   │                 │               │               │
    │                       │                   │    (Seeker enters card, PayHere processes)      │
    │                       │                   │                 │               │               │
    │                       │◄──POST /webhook───────────────────-│               │               │
    │                       │  {orderId, status,│                 │               │               │
    │                       │   md5hash}        │                 │               │               │
    │                       │ [verify MD5 sig]  │                 │               │               │
    │                       │──update payment──►│                 │               │               │
    │                       │  status="success" │                 │               │               │
    │                       │◄──ok──────────────│                 │               │               │
    │                       │──create notification doc──────────►│               │               │
    │                       │                   │                 │               │               │
    │                       │   (sendPushOnNotificationCreate fires)              │               │
    │                       │──read fcmToken────►│               │               │               │
    │                       │◄──token────────────│               │               │               │
    │                       │──send FCM push──────────────────────────────────►  │               │
    │◄──push notification───────────────────────────────────────────────────────│               │
    │                       │                   │                 │               │               │
    │                       │──dispatchReceipts─►│ (read seeker contact)         │               │
    │                       │──SMS──────────────────────────────────────────────────────────────►│
    │                       │──Email────────────────────────────────────────────────────────────►│
    │                       │                   │                 │               │        [receipt sent]
```

### Alternative Sequence: Admin Approves Bank Transfer

Participants: `Admin Web App` | `Cloud Functions` | `Firestore` | `FCM` | `Twilio/SendGrid`

```
Admin Web App     Cloud Functions       Firestore        FCM     Twilio/SendGrid
     │                   │                  │             │              │
     │──verifyBankTransfer►                 │             │              │
     │  {paymentId, approve}                │             │              │
     │                   │ [check admin role]             │              │
     │                   │──update payment─►│             │              │
     │                   │  status="paid"   │             │              │
     │                   │──create notification doc──────►│              │
     │                   │   (sendPush fires)             │              │
     │                   │──FCM push to Seeker────────────►              │
     │                   │──dispatchReceipts              │              │
     │                   │──SMS + Email──────────────────────────────────►
     │◄──success─────────│                  │             │              │
```

---

*Reference: all field names, collection names, Cloud Function names, and state values are taken directly from the production codebase.*
