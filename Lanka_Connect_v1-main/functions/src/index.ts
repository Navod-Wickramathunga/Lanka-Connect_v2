import {setGlobalOptions} from "firebase-functions/v2";
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {createHash} from "node:crypto";
import twilio from "twilio";
import sgMail from "@sendgrid/mail";

initializeApp();
const db = getFirestore();
const NOTIFICATION_CHANNEL_ID = "lanka_connect_notifications_soft";
const NOTIFICATION_SOUND = "soft_notification";

setGlobalOptions({maxInstances: 10});

function buildPushData(
  notificationId: string,
  type: string,
  payload: unknown
): Record<string, string> {
  const data: Record<string, string> = {
    notificationId,
    type,
  };

  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return data;
  }

  for (const [key, value] of Object.entries(payload as Record<string, unknown>)) {
    if (value === null || value === undefined) {
      continue;
    }
    data[key] = typeof value === "string" ? value : JSON.stringify(value);
  }

  return data;
}

export const setServicePendingOnCreate = onDocumentCreated("services/{serviceId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    return;
  }

  const data = snapshot.data();
  if (data.status === "pending") {
    return;
  }

  await snapshot.ref.update({status: "pending"});
  logger.info("Forced new service status to pending", {
    serviceId: event.params.serviceId,
  });
});

export const notifyOnServiceApproval = onDocumentUpdated("services/{serviceId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) {
    return;
  }

  if (before.status === "approved" || after.status !== "approved") {
    return;
  }

  const providerId = (after.providerId ?? "").toString();
  if (!providerId) {
    logger.warn("Skipping service approval notification: missing providerId", {
      serviceId: event.params.serviceId,
    });
    return;
  }

  await db.collection("notifications").add({
    recipientId: providerId,
    senderId: "system",
    title: "Service approved",
    body: "Your service has been approved by admin.",
    type: "service_moderation",
    data: {
      serviceId: event.params.serviceId,
      status: "approved",
    },
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  logger.info("Created approval notification", {
    serviceId: event.params.serviceId,
    providerId,
  });
});

export const updateProviderRatingOnReviewCreate = onDocumentCreated("reviews/{reviewId}", async (event) => {
  const data = event.data?.data();
  if (!data) {
    return;
  }

  const providerId = (data.providerId ?? "").toString();
  const rawRating = data.rating;
  const rating = typeof rawRating === "number" ? rawRating : Number(rawRating);

  if (!providerId || Number.isNaN(rating) || rating < 1 || rating > 5) {
    logger.warn("Skipping rating aggregate update due to invalid review payload", {
      reviewId: event.params.reviewId,
      providerId,
      rawRating,
    });
    return;
  }

  const providerRef = db.collection("users").doc(providerId);

  await db.runTransaction(async (tx) => {
    const providerSnap = await tx.get(providerRef);
    const providerData = providerSnap.data() ?? {};

    const currentAverage = Number(providerData.averageRating ?? 0);
    const currentCount = Number(providerData.reviewCount ?? 0);
    const safeAverage = Number.isFinite(currentAverage) ? currentAverage : 0;
    const safeCount = Number.isFinite(currentCount) && currentCount > 0 ? currentCount : 0;

    const newCount = safeCount + 1;
    const newAverage = ((safeAverage * safeCount) + rating) / newCount;

    tx.set(providerRef, {
      averageRating: Number(newAverage.toFixed(2)),
      reviewCount: newCount,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  logger.info("Updated provider rating aggregate", {
    reviewId: event.params.reviewId,
    providerId,
  });
});

export const seedDemoData = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Sign in before seeding demo data.");
  }

  const callerRef = db.collection("users").doc(callerUid);
  const callerSnap = await callerRef.get();
  const callerRole = (callerSnap.data()?.role ?? "").toString().toLowerCase();
  if (callerRole !== "admin") {
    throw new HttpsError("permission-denied", "Only admin can seed demo data.");
  }

  const providerId = "demo_provider";
  const providerBankAccountId = "demo_provider_bank_primary";
  const approvedServiceOneId = "demo_service_cleaning";
  const approvedServiceTwoId = "demo_service_plumbing";
  const pendingServiceId = "demo_service_tutoring";
  const acceptedBookingId = `demo_booking_accepted_${callerUid.substring(0, 6)}`;
  const completedBookingId = `demo_booking_completed_${callerUid.substring(0, 6)}`;
  const reviewId = `demo_review_${callerUid.substring(0, 6)}`;

  const batch = db.batch();

  const providerRef = db.collection("users").doc(providerId);
  const providerBankRef = db.collection("providerBankAccounts")
    .doc(providerBankAccountId);
  batch.set(providerRef, {
    role: "provider",
    name: "Demo Provider",
    contact: "+94770000000",
    district: "Colombo",
    city: "Maharagama",
    skills: ["Home Cleaning", "Plumbing"],
    bio: "Demo profile for presentation and testing.",
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  batch.set(providerBankRef, {
    providerId,
    bankName: "Bank of Ceylon",
    accountName: "Demo Provider",
    accountNumberMasked: "****5678",
    branch: "Maharagama",
    isActive: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  const serviceOneRef = db.collection("services").doc(approvedServiceOneId);
  batch.set(serviceOneRef, {
    providerId,
    title: "Home Deep Cleaning",
    category: "Cleaning",
    price: 3500,
    district: "Colombo",
    city: "Nugegoda",
    location: "Nugegoda, Colombo",
    description: "Apartment and house deep cleaning service.",
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  const serviceTwoRef = db.collection("services").doc(approvedServiceTwoId);
  batch.set(serviceTwoRef, {
    providerId,
    title: "Quick Plumbing Fix",
    category: "Plumbing",
    price: 2500,
    district: "Gampaha",
    city: "Kadawatha",
    location: "Kadawatha, Gampaha",
    description: "Leak repairs and basic plumbing maintenance.",
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  const pendingServiceRef = db.collection("services").doc(pendingServiceId);
  batch.set(pendingServiceRef, {
    providerId,
    title: "Math Tutoring (O/L)",
    category: "Tutoring",
    price: 2000,
    district: "Colombo",
    city: "Dehiwala",
    location: "Dehiwala, Colombo",
    description: "One-to-one O/L maths support sessions.",
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  const acceptedBookingRef = db.collection("bookings").doc(acceptedBookingId);
  batch.set(acceptedBookingRef, {
    serviceId: approvedServiceOneId,
    providerId,
    seekerId: callerUid,
    amount: 3500,
    status: "accepted",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  const completedBookingRef = db.collection("bookings").doc(completedBookingId);
  batch.set(completedBookingRef, {
    serviceId: approvedServiceTwoId,
    providerId,
    seekerId: callerUid,
    amount: 2500,
    status: "completed",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  const reviewRef = db.collection("reviews").doc(reviewId);
  batch.set(reviewRef, {
    bookingId: completedBookingId,
    serviceId: approvedServiceTwoId,
    providerId,
    reviewerId: callerUid,
    rating: 5,
    comment: "Reliable and quick service. Great for demo data.",
    createdAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  const notificationRef = db.collection("notifications").doc();
  batch.set(notificationRef, {
    recipientId: callerUid,
    senderId: "system",
    title: "Demo data ready",
    body: "Seed completed successfully. Refresh tabs to view sample data.",
    type: "system",
    data: {
      services: [approvedServiceOneId, approvedServiceTwoId, pendingServiceId],
      bookings: [acceptedBookingId, completedBookingId],
    },
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  await batch.commit();

  await serviceOneRef.update({
    status: "approved",
    updatedAt: FieldValue.serverTimestamp(),
  });
  await serviceTwoRef.update({
    status: "approved",
    updatedAt: FieldValue.serverTimestamp(),
  });

  logger.info("Seeded demo data for admin user", {callerUid});

  return {
    ok: true,
    providerId,
    services: [approvedServiceOneId, approvedServiceTwoId, pendingServiceId],
    bookings: [acceptedBookingId, completedBookingId],
    reviewId,
  };
});

// ── FCM Push Notification on Firestore notification creation ──
export const sendPushOnNotificationCreate = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const recipientId = (data.recipientId ?? "").toString();
    const title = (data.title ?? "Lanka Connect").toString();
    const body = (data.body ?? "").toString();

    if (!recipientId || recipientId === "__admins__") {
      // Admin channel notifications: send to all admins
      if (recipientId === "__admins__") {
        const adminsSnap = await db.collection("users")
          .where("role", "==", "admin")
          .get();

        const tokens: string[] = [];
        for (const adminDoc of adminsSnap.docs) {
          const adminData = adminDoc.data();
          if (adminData.fcmToken) {
            tokens.push(adminData.fcmToken);
          }
        }

        if (tokens.length > 0) {
          const pushData = buildPushData(
            event.params.notificationId,
            (data.type ?? "general").toString(),
            data.data
          );
          try {
            const response = await getMessaging().sendEachForMulticast({
              tokens,
              notification: {title, body},
              data: pushData,
              android: {
                priority: "high",
                notification: {
                  channelId: NOTIFICATION_CHANNEL_ID,
                  priority: "high",
                  sound: NOTIFICATION_SOUND,
                },
              },
              apns: {
                payload: {
                  aps: {
                    badge: 1,
                    sound: "default",
                  },
                },
              },
            });
            logger.info("Sent admin push notifications", {
              successCount: response.successCount,
              failureCount: response.failureCount,
            });
          } catch (err) {
            logger.error("Failed to send admin push", {error: err});
          }
        }
      }
      return;
    }

    // Single recipient: look up their FCM token
    const recipientDoc = await db.collection("users").doc(recipientId).get();
    const recipientData = recipientDoc.data();
    const fcmToken = recipientData?.fcmToken;

    if (!fcmToken) {
      logger.info("No FCM token for recipient, skipping push", {recipientId});
      return;
    }

    try {
      const pushData = buildPushData(
        event.params.notificationId,
        (data.type ?? "general").toString(),
        data.data
      );
      await getMessaging().send({
        token: fcmToken,
        notification: {title, body},
        data: pushData,
        android: {
          priority: "high",
          notification: {
            channelId: NOTIFICATION_CHANNEL_ID,
            priority: "high",
            sound: NOTIFICATION_SOUND,
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: "default",
            },
          },
        },
      });

      logger.info("Push notification sent", {
        notificationId: event.params.notificationId,
        recipientId,
      });
    } catch (err) {
      logger.error("Failed to send push notification", {
        notificationId: event.params.notificationId,
        recipientId,
        error: err,
      });
    }
  }
);

type PaymentMethodType = "card" | "saved_card" | "bank_transfer";
type PaymentStatus =
  "initiated" |
  "pending_gateway" |
  "success" |
  "failed" |
  "pending_verification" |
  "paid";
type OfferDiscountType = "percentage" | "flat";
type OfferRecord = {
  id: string;
  title: string;
  isActive: boolean;
  discountType: OfferDiscountType;
  discountValue: number;
  targetServiceId?: string;
  targetProviderId?: string;
  targetCategory?: string;
  minAmount?: number;
  startsAt?: Date;
  endsAt?: Date;
};
type AppliedOfferResult = {
  offerId: string;
  discountAmount: number;
  grossAmount: number;
  netAmount: number;
  meta: Record<string, unknown>;
};

/**
 * Reads a required environment variable and throws when missing.
 * @param {string} name Environment variable key.
 * @return {string} Non-empty env value.
 */
function envStrict(name: string): string {
  const value = process.env[name];
  if (!value || !value.trim()) {
    throw new HttpsError("failed-precondition", `Missing environment variable: ${name}`);
  }
  return value.trim();
}

/**
 * Produces uppercase MD5 digest.
 * @param {string} input Raw input text.
 * @return {string} Uppercase MD5 hash.
 */
function md5(input: string): string {
  return createHash("md5").update(input).digest("hex").toUpperCase();
}

/**
 * Normalizes local phone values into E.164-like format.
 * @param {string} value Phone input.
 * @return {string} Normalized phone value.
 */
function normalizePhone(value: string): string {
  const raw = value.replace(/[^0-9+]/g, "");
  if (raw.startsWith("+")) return raw;
  if (raw.startsWith("0")) return `+94${raw.slice(1)}`;
  return `+94${raw}`;
}

/**
 * Parses a date-like Firestore/admin value into a valid Date.
 * @param {unknown} value Raw stored value.
 * @return {Date|undefined} Parsed date when valid.
 */
function parseDateValue(value: unknown): Date | undefined {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value;
  }
  if (
    typeof value === "object" &&
    value !== null &&
    "toDate" in value &&
    typeof value.toDate === "function"
  ) {
    const parsed = value.toDate();
    if (parsed instanceof Date && !Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  return undefined;
}

/**
 * Converts unknown numeric input into a finite number.
 * @param {unknown} value Raw value.
 * @param {number} fallback Value returned when parsing fails.
 * @return {number} Finite number.
 */
function toFiniteNumber(value: unknown, fallback = 0): number {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

/**
 * Maps Firestore offer documents into server-side offer records.
 * @param {string} id Offer document ID.
 * @param {Record<string, unknown>} data Firestore payload.
 * @return {OfferRecord} Parsed offer.
 */
function offerFromMap(
  id: string,
  data: Record<string, unknown>,
): OfferRecord {
  const rawType = (data.discountType ?? "").toString().toLowerCase();
  return {
    id,
    title: (data.title ?? "Offer").toString(),
    isActive: data.isActive === true,
    discountType: rawType === "flat" ? "flat" : "percentage",
    discountValue: toFiniteNumber(data.discountValue),
    targetServiceId: (data.targetServiceId ?? "").toString().trim() || undefined,
    targetProviderId:
      (data.targetProviderId ?? "").toString().trim() || undefined,
    targetCategory: (data.targetCategory ?? "").toString().trim() || undefined,
    minAmount:
      data.minAmount == null ? undefined : toFiniteNumber(data.minAmount),
    startsAt: parseDateValue(data.startsAt),
    endsAt: parseDateValue(data.endsAt),
  };
}

/**
 * Derives a payable offer from a legacy promotion tile.
 * @param {string} id Promotion document ID.
 * @param {Record<string, unknown>} data Promotion payload.
 * @return {OfferRecord|undefined} Parsed offer when supported.
 */
function offerFromPromotion(
  id: string,
  data: Record<string, unknown>,
): OfferRecord | undefined {
  const discountLabel = (data.discount ?? "").toString().trim();
  if (!discountLabel) {
    return undefined;
  }

  const percentageMatch = /(\d+(?:\.\d+)?)\s*%/.exec(discountLabel);
  const normalized = discountLabel.replace(/,/g, "");
  const amountMatch = /(\d+(?:\.\d+)?)/.exec(normalized);
  const targetCategory =
    (data.linkedCategory ?? "").toString().trim() || undefined;

  if (percentageMatch) {
    const discountValue = toFiniteNumber(percentageMatch[1]);
    if (discountValue <= 0) {
      return undefined;
    }
    return {
      id: `promo_${id}`,
      title: (data.title ?? "Promotion").toString(),
      isActive: true,
      discountType: "percentage",
      discountValue,
      targetCategory,
    };
  }

  const discountValue = toFiniteNumber(amountMatch?.[1]);
  if (discountValue <= 0) {
    return undefined;
  }
  return {
    id: `promo_${id}`,
    title: (data.title ?? "Promotion").toString(),
    isActive: true,
    discountType: "flat",
    discountValue,
    targetCategory,
  };
}

/**
 * Loads active offers, with a promotion fallback for older demo data.
 * @return {Promise<OfferRecord[]>} Active payable offers.
 */
async function loadActiveOffers(): Promise<OfferRecord[]> {
  const offersSnap = await db.collection("offers").get();
  const offers = offersSnap.docs
    .map((doc) => offerFromMap(doc.id, doc.data()))
    .filter((offer) => offer.isActive);
  if (offers.length > 0) {
    return offers;
  }

  const promotionsSnap = await db.collection("promotions")
    .where("active", "==", true)
    .get();
  return promotionsSnap.docs
    .map((doc) => offerFromPromotion(doc.id, doc.data()))
    .filter((offer): offer is OfferRecord => offer !== undefined);
}

/**
 * Checks whether an offer can apply to a booking checkout.
 * @param {Object} input Eligibility inputs.
 * @param {OfferRecord} input.offer Candidate offer.
 * @param {Date} input.now Current server time.
 * @param {number} input.grossAmount Original booking amount.
 * @param {string} input.serviceId Service ID.
 * @param {string} input.providerId Provider ID.
 * @param {string} input.category Service category.
 * @return {boolean} True when offer applies.
 */
function isOfferEligible(input: {
  offer: OfferRecord;
  now: Date;
  grossAmount: number;
  serviceId: string;
  providerId: string;
  category: string;
}): boolean {
  const {offer, now, grossAmount, serviceId, providerId, category} = input;
  if (offer.startsAt && now < offer.startsAt) return false;
  if (offer.endsAt && now > offer.endsAt) return false;
  if (offer.minAmount != null && grossAmount < offer.minAmount) return false;
  if (offer.targetServiceId && offer.targetServiceId !== serviceId) {
    return false;
  }
  if (offer.targetProviderId && offer.targetProviderId !== providerId) {
    return false;
  }
  if (
    offer.targetCategory &&
    offer.targetCategory.trim().toLowerCase() !== category.trim().toLowerCase()
  ) {
    return false;
  }
  return true;
}

/**
 * Calculates the discount amount for a single offer.
 * @param {OfferRecord} offer Offer to evaluate.
 * @param {number} grossAmount Original booking amount.
 * @return {number} Discount amount bounded to the gross amount.
 */
function offerDiscountAmount(offer: OfferRecord, grossAmount: number): number {
  if (offer.discountType === "flat") {
    return Math.min(Math.max(offer.discountValue, 0), grossAmount);
  }
  const percent = Math.min(Math.max(offer.discountValue, 0), 100);
  return Math.min(Math.max((grossAmount * percent) / 100, 0), grossAmount);
}

/**
 * Resolves the best available offer for a booking checkout.
 * @param {Object} input Resolution inputs.
 * @param {OfferRecord[]} input.offers Active offers.
 * @param {number} input.grossAmount Original booking amount.
 * @param {string} input.serviceId Service ID.
 * @param {string} input.providerId Provider ID.
 * @param {string} input.category Service category.
 * @return {AppliedOfferResult|undefined} Best discount, if any.
 */
function resolveBestOffer(input: {
  offers: OfferRecord[];
  grossAmount: number;
  serviceId: string;
  providerId: string;
  category: string;
}): AppliedOfferResult | undefined {
  const {offers, grossAmount, serviceId, providerId, category} = input;
  const now = new Date();
  let bestOffer: OfferRecord | undefined;
  let bestDiscount = 0;

  for (const offer of offers) {
    if (!isOfferEligible({
      offer,
      now,
      grossAmount,
      serviceId,
      providerId,
      category,
    })) {
      continue;
    }

    const discountAmount = offerDiscountAmount(offer, grossAmount);
    if (discountAmount > bestDiscount) {
      bestDiscount = discountAmount;
      bestOffer = offer;
    }
  }

  if (!bestOffer || bestDiscount <= 0) {
    return undefined;
  }

  const netAmount = Math.max(grossAmount - bestDiscount, 0);
  return {
    offerId: bestOffer.id,
    discountAmount: bestDiscount,
    grossAmount,
    netAmount,
    meta: {
      title: bestOffer.title,
      discountType: bestOffer.discountType,
      discountValue: bestOffer.discountValue,
      targetServiceId: bestOffer.targetServiceId ?? null,
      targetProviderId: bestOffer.targetProviderId ?? null,
      targetCategory: bestOffer.targetCategory ?? null,
    },
  };
}

/**
 * Checks if the user profile role is admin.
 * @param {string} uid User ID.
 * @return {Promise<boolean>} Whether user is admin.
 */
async function isAdminUid(uid: string): Promise<boolean> {
  const snap = await db.collection("users").doc(uid).get();
  return (snap.data()?.role ?? "").toString().toLowerCase() === "admin";
}

/**
 * Loads a saved payment method owned by the caller.
 * @param {string} uid Current user ID.
 * @param {string} paymentMethodId Saved method document ID.
 * @return {Promise<Object>} Saved gateway token and display metadata.
 */
async function getSavedPaymentMethod(uid: string, paymentMethodId: string): Promise<{
  tokenRef: string;
  brand: string;
  last4: string;
}> {
  const methodSnap = await db.collection("users")
    .doc(uid)
    .collection("savedPaymentMethods")
    .doc(paymentMethodId)
    .get();
  if (!methodSnap.exists) {
    throw new HttpsError("not-found", "Saved payment method not found.");
  }

  const method = methodSnap.data() ?? {};
  if ((method.status ?? "").toString() !== "active") {
    throw new HttpsError(
      "failed-precondition",
      "Saved payment method is not active.",
    );
  }

  const tokenRef = (method.tokenRef ?? "").toString().trim();
  if (!tokenRef) {
    throw new HttpsError(
      "failed-precondition",
      "Saved payment method is missing its gateway token.",
    );
  }

  return {
    tokenRef,
    brand: (method.brand ?? "CARD").toString(),
    last4: (method.last4 ?? "").toString(),
  };
}

/**
 * Writes a single SMS/email receipt delivery log row.
 * @param {Object} input Receipt log payload.
 * @return {Promise<void>} Resolves when persisted.
 */
async function writeReceiptLog(input: {
  paymentId: string;
  bookingId: string;
  userId: string;
  channel: "sms" | "email";
  destinationMasked: string;
  status: "sent" | "failed";
  providerMessageId?: string;
  errorCode?: string;
}): Promise<void> {
  await db.collection("paymentReceipts").add({
    paymentId: input.paymentId,
    bookingId: input.bookingId,
    userId: input.userId,
    channel: input.channel,
    destinationMasked: input.destinationMasked,
    status: input.status,
    providerMessageId: input.providerMessageId ?? null,
    errorCode: input.errorCode ?? null,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Masks email destination in logs.
 * @param {string} email Raw email.
 * @return {string} Masked email.
 */
function maskEmail(email: string): string {
  const [local, domain] = email.split("@");
  if (!local || !domain) return "***";
  if (local.length <= 2) return `${local[0]}***@${domain}`;
  return `${local.slice(0, 2)}***@${domain}`;
}

/**
 * Masks phone destination in logs.
 * @param {string} phone Raw phone.
 * @return {string} Masked phone.
 */
function maskPhone(phone: string): string {
  if (phone.length <= 4) return "***";
  return `***${phone.slice(-4)}`;
}

const PASSWORD_RESET_RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const PASSWORD_RESET_RATE_LIMIT_MAX_PER_EMAIL = 3;
const PASSWORD_RESET_RATE_LIMIT_MAX_PER_IP = 20;

/**
 * Masks source IP address in logs.
 * @param {string} ip Raw IP value.
 * @return {string} Masked IP.
 */
function maskIp(ip: string): string {
  if (!ip) return "***";
  if (ip.includes(":")) {
    const parts = ip.split(":").filter(Boolean);
    if (parts.length <= 2) return "***";
    return `${parts.slice(0, 2).join(":")}:***`;
  }
  const parts = ip.split(".");
  if (parts.length !== 4) return "***";
  return `${parts[0]}.${parts[1]}.*.*`;
}

/**
 * Normalizes user email for auth lookup and anti-abuse keys.
 * @param {string} email Raw email input.
 * @return {string} Lower-cased and trimmed email.
 */
function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

/**
 * Extracts request caller IP.
 * @param {Object} request Callable request object.
 * @return {string} Caller IP or fallback marker.
 */
function callerIp(request: {
  rawRequest?: {
    headers?: Record<string, string | string[] | undefined>;
    ip?: string;
  };
}): string {
  const forwarded = request.rawRequest?.headers?.["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.trim().length > 0) {
    return forwarded.split(",")[0].trim();
  }
  if (Array.isArray(forwarded) && forwarded.length > 0) {
    return forwarded[0].split(",")[0].trim();
  }
  return (request.rawRequest?.ip ?? "").toString().trim() || "unknown";
}

/**
 * Applies windowed rate limit for reset-email requests.
 * @param {string} key Unique key (email or ip hash).
 * @param {number} maxAttempts Allowed max attempts per window.
 * @param {number} nowMs Epoch milliseconds.
 * @return {Promise<boolean>} Whether current request should be blocked.
 */
async function isRateLimited(
  key: string,
  maxAttempts: number,
  nowMs: number,
): Promise<boolean> {
  const docRef = db.collection("passwordResetRateLimits").doc(key);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    const data = snap.data() ?? {};
    const windowStartMs = Number(data.windowStartMs ?? 0);
    const attempts = Number(data.attempts ?? 0);
    const inWindow = windowStartMs > 0 &&
      (nowMs - windowStartMs) < PASSWORD_RESET_RATE_LIMIT_WINDOW_MS;
    const nextWindowStartMs = inWindow ? windowStartMs : nowMs;
    const nextAttempts = inWindow ? attempts + 1 : 1;
    const blocked = inWindow && attempts >= maxAttempts;

    tx.set(docRef, {
      windowStartMs: nextWindowStartMs,
      attempts: blocked ? attempts : nextAttempts,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return blocked;
  });
}

/**
 * Resolves current app origin for first-party reset links.
 * @return {string} Base URL without trailing slash.
 */
function resetBaseUrl(): string {
  const configured = process.env.PASSWORD_RESET_BASE_URL;
  if (configured && configured.trim()) {
    return configured.trim().replace(/\/+$/, "");
  }
  const projectId = process.env.GCLOUD_PROJECT ?? "";
  if (projectId.trim()) {
    return `https://${projectId.trim()}.firebaseapp.com`;
  }
  return "https://lankaconnect-app.firebaseapp.com";
}

/**
 * Renders the password reset email HTML.
 * @param {Object} input Render input.
 * @return {string} HTML body.
 */
function renderPasswordResetHtml(input: {
  resetUrl: string;
  displayEmail: string;
}): string {
  const escapedUrl = input.resetUrl.replace(/"/g, "&quot;");
  const escapedEmail = input.displayEmail.replace(/[<>]/g, "");

  return `
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Reset your Lanka Connect password</title>
  </head>
  <body style="margin:0;padding:0;background:#f3f7f9;font-family:Arial,sans-serif;color:#102235;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0"
            cellpadding="0" style="max-width:620px;background:#ffffff;
            border:1px solid #d8e3ea;border-radius:18px;overflow:hidden;">
            <tr>
              <td style="padding:28px 28px 18px;background:linear-gradient(135deg,#0b5d57,#143b58);color:#f4fbfa;">
                <p style="margin:0 0 8px 0;font-size:12px;
                  letter-spacing:.4px;text-transform:uppercase;
                  color:#ffd58a;">Lanka Connect</p>
                <h1 style="margin:0;font-size:28px;line-height:1.2;font-weight:700;">Reset your password</h1>
              </td>
            </tr>
            <tr>
              <td style="padding:26px 28px;">
                <p style="margin:0 0 14px 0;font-size:16px;line-height:1.45;">
                  We received a request to reset the password for <strong>${escapedEmail}</strong>.
                </p>
                <p style="margin:0 0 22px 0;font-size:15px;line-height:1.45;color:#5d7285;">
                  If this was you, use the button below. If not, you can safely ignore this email.
                </p>
                <p style="margin:0 0 24px 0;">
                  <a href="${escapedUrl}" style="display:inline-block;
                    padding:12px 22px;background:#0f766e;color:#ffffff;
                    text-decoration:none;border-radius:10px;
                    font-weight:700;">Reset Password</a>
                </p>
                <p style="margin:0 0 8px 0;font-size:13px;
                  line-height:1.45;color:#5d7285;">Link not working?
                  Copy and paste this URL into your browser:</p>
                <p style="margin:0 0 18px 0;font-size:12px;line-height:1.55;word-break:break-all;">
                  <a href="${escapedUrl}" style="color:#0f5c54;">${escapedUrl}</a>
                </p>
                <p style="margin:0;font-size:12px;line-height:1.5;
                  color:#7a4b00;background:#fff7e7;
                  border:1px solid #f3ddaa;padding:10px 12px;
                  border-radius:10px;">
                  For security, this link expires soon and can be used once.
                </p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

/**
 * Renders plain text for password reset email.
 * @param {Object} input Render input.
 * @return {string} Plain text body.
 */
function renderPasswordResetText(input: {resetUrl: string}): string {
  return [
    "Lanka Connect password reset",
    "",
    "A request was received to reset your password.",
    `Reset password: ${input.resetUrl}`,
    "",
    "If you did not request this, you can ignore this email.",
    "This link expires soon and can be used once.",
  ].join("\n");
}

/** Requests a password reset email without leaking account existence. */
export const requestPasswordResetEmail = onCall(async (request) => {
  const rawEmail = (request.data?.email ?? "").toString();
  const email = normalizeEmail(rawEmail);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "A valid email is required.");
  }

  const ip = callerIp(request);
  const nowMs = Date.now();
  const emailKey = `email_${md5(email)}`;
  const ipKey = `ip_${md5(ip)}`;

  const [blockedByEmail, blockedByIp] = await Promise.all([
    isRateLimited(emailKey, PASSWORD_RESET_RATE_LIMIT_MAX_PER_EMAIL, nowMs),
    isRateLimited(ipKey, PASSWORD_RESET_RATE_LIMIT_MAX_PER_IP, nowMs),
  ]);
  if (blockedByEmail || blockedByIp) {
    logger.warn("Password reset request throttled", {
      emailMasked: maskEmail(email),
      ipMasked: maskIp(ip),
      blockedByEmail,
      blockedByIp,
    });
    return {ok: true};
  }

  try {
    const resetLink = await getAuth().generatePasswordResetLink(email);
    const resetLinkUrl = new URL(resetLink);
    const oobCode = resetLinkUrl.searchParams.get("oobCode");
    if (!oobCode) {
      logger.error("Missing oobCode in generated reset link", {
        emailMasked: maskEmail(email),
      });
      return {ok: true};
    }

    const resetUrl =
      `${resetBaseUrl()}/reset-password?oobCode=${encodeURIComponent(oobCode)}`;
    sgMail.setApiKey(envStrict("SENDGRID_API_KEY"));
    await sgMail.send({
      to: email,
      from: envStrict("SENDGRID_FROM_EMAIL"),
      subject: "Reset your Lanka Connect password",
      text: renderPasswordResetText({resetUrl}),
      html: renderPasswordResetHtml({
        resetUrl,
        displayEmail: maskEmail(email),
      }),
    });
    logger.info("Password reset email sent", {
      emailMasked: maskEmail(email),
      ipMasked: maskIp(ip),
    });
  } catch (error) {
    const code = (error as {code?: string})?.code ?? "";
    if (code === "auth/user-not-found") {
      logger.info("Password reset requested for unknown account", {
        emailMasked: maskEmail(email),
        ipMasked: maskIp(ip),
      });
      return {ok: true};
    }
    logger.error("Password reset request failed", {
      emailMasked: maskEmail(email),
      ipMasked: maskIp(ip),
      error,
    });
    throw new HttpsError("internal", "Could not process reset request.");
  }

  return {ok: true};
});

/**
 * Sends payment receipt through SMS and email providers.
 * @param {Object} input Receipt dispatch payload.
 * @return {Promise<Object>} Dispatch status for both channels.
 */
async function sendPaymentReceipt(input: {
  paymentId: string;
  bookingId: string;
  userId: string;
  amount: number;
  status: "success" | "paid";
  transactionId: string;
}): Promise<{
  smsSent: boolean;
  emailSent: boolean;
  smsMessageId?: string;
  emailMessageId?: string;
}> {
  const userSnap = await db.collection("users").doc(input.userId).get();
  const profile = userSnap.data() ?? {};
  const authUser = await getAuth().getUser(input.userId).catch(() => null);
  const email = (profile.email ?? authUser?.email ?? "").toString().trim();
  const phone = normalizePhone((profile.contact ?? "").toString().trim());
  const paidAt = new Date().toISOString();
  const shortBooking = input.bookingId.length > 6 ?
    input.bookingId.substring(0, 6) :
    input.bookingId;

  let smsSent = false;
  let emailSent = false;
  let smsMessageId: string | undefined;
  let emailMessageId: string | undefined;

  if (phone.length >= 10) {
    try {
      const twilioClient = twilio(
        envStrict("TWILIO_ACCOUNT_SID"),
        envStrict("TWILIO_AUTH_TOKEN"),
      );
      const sms = await twilioClient.messages.create({
        from: envStrict("TWILIO_FROM_NUMBER"),
        to: phone,
        body:
          `Lanka Connect receipt: booking ${shortBooking}, ` +
          `LKR ${input.amount.toFixed(2)}, status ${input.status}, ` +
          `tx ${input.transactionId}, ${paidAt}.`,
      });
      smsSent = true;
      smsMessageId = sms.sid;
      await writeReceiptLog({
        paymentId: input.paymentId,
        bookingId: input.bookingId,
        userId: input.userId,
        channel: "sms",
        destinationMasked: maskPhone(phone),
        status: "sent",
        providerMessageId: sms.sid,
      });
    } catch (error) {
      logger.error("SMS receipt failed", {paymentId: input.paymentId, error});
      await writeReceiptLog({
        paymentId: input.paymentId,
        bookingId: input.bookingId,
        userId: input.userId,
        channel: "sms",
        destinationMasked: maskPhone(phone),
        status: "failed",
        errorCode: "sms_send_failed",
      });
    }
  }

  if (email.length > 0) {
    try {
      sgMail.setApiKey(envStrict("SENDGRID_API_KEY"));
      const [mailResponse] = await sgMail.send({
        to: email,
        from: envStrict("SENDGRID_FROM_EMAIL"),
        subject: "Lanka Connect Payment Receipt",
        text: [
          "Payment completed successfully.",
          `Booking ID: ${input.bookingId}`,
          `Amount: LKR ${input.amount.toFixed(2)}`,
          `Status: ${input.status}`,
          `Transaction ID: ${input.transactionId}`,
          `Paid At: ${paidAt}`,
        ].join("\n"),
      });
      emailSent = true;
      emailMessageId =
        (mailResponse.headers["x-message-id"] ?? "").toString() || undefined;
      await writeReceiptLog({
        paymentId: input.paymentId,
        bookingId: input.bookingId,
        userId: input.userId,
        channel: "email",
        destinationMasked: maskEmail(email),
        status: "sent",
        providerMessageId: emailMessageId,
      });
    } catch (error) {
      logger.error("Email receipt failed", {paymentId: input.paymentId, error});
      await writeReceiptLog({
        paymentId: input.paymentId,
        bookingId: input.bookingId,
        userId: input.userId,
        channel: "email",
        destinationMasked: maskEmail(email),
        status: "failed",
        errorCode: "email_send_failed",
      });
    }
  }

  return {smsSent, emailSent, smsMessageId, emailMessageId};
}

/**
 * Creates in-app payment notifications for both seeker and provider.
 * @param {Object} input Notification context.
 * @return {Promise<void>}
 */
async function notifyPaymentParties(input: {
  bookingId: string;
  seekerId: string;
  providerId: string;
  amount: number;
  status: "success" | "paid";
}): Promise<void> {
  const shortId = input.bookingId.length > 6 ?
    input.bookingId.substring(0, 6) :
    input.bookingId;
  const batch = db.batch();
  const seekerRef = db.collection("notifications").doc();
  batch.set(seekerRef, {
    recipientId: input.seekerId,
    senderId: "system",
    title: "Payment successful",
    body: `Your payment of LKR ${input.amount.toFixed(2)} for booking ${shortId} was successful.`,
    type: "payment",
    data: {bookingId: input.bookingId},
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });
  const providerRef = db.collection("notifications").doc();
  batch.set(providerRef, {
    recipientId: input.providerId,
    senderId: "system",
    title: "Payment received",
    body: `Payment of LKR ${input.amount.toFixed(2)} received for booking ${shortId}.`,
    type: "payment",
    data: {bookingId: input.bookingId},
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
}

/**
 * Loads and validates booking ownership/payment context for the caller.
 * @param {string} bookingId Booking identifier.
 * @param {string} uid Current user ID.
 * @return {Promise<Object>} Booking reference and payment fields.
 */
async function bookingPaymentContext(bookingId: string, uid: string): Promise<{
  bookingRef: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
  booking: FirebaseFirestore.DocumentData;
  paymentFields: {
    bookingId: string;
    serviceId: string;
    providerId: string;
    seekerId: string;
    amount: number;
    grossAmount: number;
    discountAmount: number;
    netAmount: number;
    currency: string;
  };
}> {
  const bookingRef = db.collection("bookings").doc(bookingId);
  const bookingSnap = await bookingRef.get();
  if (!bookingSnap.exists) {
    throw new HttpsError("not-found", "Booking not found.");
  }
  const booking = bookingSnap.data() ?? {};
  const seekerId = (booking.seekerId ?? "").toString();
  if (seekerId !== uid) {
    throw new HttpsError("permission-denied", "Only booking seeker can pay.");
  }
  const status = (booking.status ?? "").toString();
  if (status !== "accepted") {
    throw new HttpsError(
      "failed-precondition",
      "Booking must be accepted before payment.",
    );
  }
  const paymentStatus = (booking.paymentStatus ?? "").toString();
  if (
    paymentStatus === "pending_gateway" ||
    paymentStatus === "pending_verification" ||
    paymentStatus === "initiated"
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Payment is already in progress for this booking.",
    );
  }
  if (paymentStatus === "paid" || paymentStatus === "success") {
    throw new HttpsError(
      "failed-precondition",
      "This booking is already paid.",
    );
  }
  const amount = Number(booking.netAmount ?? booking.amount ?? 0);
  return {
    bookingRef,
    booking,
    paymentFields: {
      bookingId,
      serviceId: (booking.serviceId ?? "").toString(),
      providerId: (booking.providerId ?? "").toString(),
      seekerId,
      amount,
      grossAmount: Number(booking.grossAmount ?? booking.amount ?? amount),
      discountAmount: Number(booking.discountAmount ?? 0),
      netAmount: amount,
      currency: "LKR",
    },
  };
}

/** Applies the best eligible offer to a booking on the server side. */
export const applyBestOfferToBooking = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const data = request.data as {bookingId?: string};
  const bookingId = (data.bookingId ?? "").toString().trim();
  if (!bookingId) {
    throw new HttpsError("invalid-argument", "bookingId is required.");
  }

  const {bookingRef, booking, paymentFields} = await bookingPaymentContext(
    bookingId,
    uid,
  );
  const serviceId = paymentFields.serviceId;
  const providerId = paymentFields.providerId;
  const grossAmount = toFiniteNumber(booking.amount);
  if (!serviceId || !providerId || grossAmount <= 0) {
    throw new HttpsError(
      "failed-precondition",
      "Booking does not have a valid payable amount.",
    );
  }

  const serviceSnap = await db.collection("services").doc(serviceId).get();
  if (!serviceSnap.exists) {
    throw new HttpsError("not-found", "Service not found.");
  }
  const service = serviceSnap.data() ?? {};
  const offers = await loadActiveOffers();
  const applied = resolveBestOffer({
    offers,
    grossAmount,
    serviceId,
    providerId,
    category: (service.category ?? "").toString(),
  });
  if (!applied) {
    throw new HttpsError(
      "failed-precondition",
      "No active offer is available for this booking.",
    );
  }

  await bookingRef.set({
    appliedOfferId: applied.offerId,
    discountAmount: applied.discountAmount,
    grossAmount: applied.grossAmount,
    netAmount: applied.netAmount,
    appliedOfferMeta: applied.meta,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  return applied;
});

/** Clears an applied booking offer before a payment attempt starts. */
export const clearBookingOffer = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const data = request.data as {bookingId?: string};
  const bookingId = (data.bookingId ?? "").toString().trim();
  if (!bookingId) {
    throw new HttpsError("invalid-argument", "bookingId is required.");
  }

  const {bookingRef, booking} = await bookingPaymentContext(bookingId, uid);
  const grossAmount = toFiniteNumber(booking.amount);
  if (grossAmount <= 0) {
    throw new HttpsError(
      "failed-precondition",
      "Booking does not have a valid payable amount.",
    );
  }

  await bookingRef.set({
    appliedOfferId: FieldValue.delete(),
    discountAmount: FieldValue.delete(),
    grossAmount: FieldValue.delete(),
    netAmount: FieldValue.delete(),
    appliedOfferMeta: FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  return {
    cleared: true,
    grossAmount,
  };
});

/** Creates a PayHere checkout attempt and returns redirect URL. */
export const createPayHereCheckoutSession = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const data = request.data as {
    bookingId?: string;
    paymentMethodId?: string;
    saveCard?: boolean;
    payerEmail?: string;
    payerPhone?: string;
    methodType?: PaymentMethodType;
  };
  const bookingId = (data.bookingId ?? "").toString().trim();
  if (!bookingId) {
    throw new HttpsError("invalid-argument", "bookingId is required.");
  }
  const {bookingRef, paymentFields} = await bookingPaymentContext(bookingId, uid);
  const paymentRef = db.collection("payments").doc();
  const paymentMethodId = (data.paymentMethodId ?? "").toString().trim();
  const savedMethod = paymentMethodId ?
    await getSavedPaymentMethod(uid, paymentMethodId) :
    null;
  const methodType: PaymentMethodType = paymentMethodId ?
    "saved_card" :
    (data.methodType ?? "card");
  const attemptId = paymentRef.id;

  await paymentRef.set({
    ...paymentFields,
    payerId: uid,
    methodType,
    status: "pending_gateway" as PaymentStatus,
    gateway: "payhere",
    gatewayRefs: {
      attemptId,
      tokenId: savedMethod?.tokenRef ?? null,
      savedMethodId: paymentMethodId || null,
    },
    saveCard: data.saveCard === true && paymentMethodId === "",
    payerEmail: (data.payerEmail ?? "").toString().trim(),
    payerPhone: normalizePhone((data.payerPhone ?? "").toString().trim()),
    paymentMethodSummary: savedMethod == null ? null : {
      brand: savedMethod.brand,
      last4: savedMethod.last4,
    },
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await bookingRef.set({
    paymentStatus: "pending_gateway",
    paymentAttemptId: attemptId,
    paymentUpdatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  const merchantId = envStrict("PAYHERE_MERCHANT_ID");
  const amountText = paymentFields.netAmount.toFixed(2);
  const currency = "LKR";
  const secretHash = md5(envStrict("PAYHERE_MERCHANT_SECRET"));
  const hash = md5(`${merchantId}${attemptId}${amountText}${currency}${secretHash}`);
  const baseUrl = envStrict("PAYHERE_CHECKOUT_BASE_URL");
  const checkoutUrl =
    `${baseUrl}?merchant_id=${encodeURIComponent(merchantId)}` +
    `&order_id=${encodeURIComponent(attemptId)}` +
    `&amount=${encodeURIComponent(amountText)}` +
    `&currency=${currency}&hash=${hash}`;

  return {
    checkoutUrl,
    paymentAttemptId: attemptId,
    expiresAt: Date.now() + (15 * 60 * 1000),
  };
});

/** Creates a bank-transfer payment attempt pending admin verification. */
export const submitBankTransfer = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const data = request.data as {
    bookingId?: string;
    bankAccountId?: string;
    transferReference?: string;
    paidAmount?: number;
    paidAt?: {seconds?: number; nanoseconds?: number};
  };
  const bookingId = (data.bookingId ?? "").toString().trim();
  const bankAccountId = (data.bankAccountId ?? "").toString().trim();
  const transferReference = (data.transferReference ?? "").toString().trim();
  if (!bookingId || !bankAccountId || !transferReference) {
    throw new HttpsError(
      "invalid-argument",
      "bookingId, bankAccountId and transferReference are required.",
    );
  }
  if (!/^[A-Za-z0-9\-_/]{6,}$/.test(transferReference)) {
    throw new HttpsError("invalid-argument", "Invalid transfer reference format.");
  }

  const {bookingRef, paymentFields} = await bookingPaymentContext(bookingId, uid);
  const paidAmount = Number(data.paidAmount ?? 0);
  if (
    !Number.isFinite(paidAmount) ||
    Math.abs(paidAmount - paymentFields.netAmount) > 0.009
  ) {
    throw new HttpsError("invalid-argument", "Paid amount must match payable amount.");
  }

  const bankSnap = await db.collection("providerBankAccounts")
    .doc(bankAccountId)
    .get();
  if (!bankSnap.exists) {
    throw new HttpsError("not-found", "Provider bank account not found.");
  }
  const bank = bankSnap.data() ?? {};
  if (
    (bank.providerId ?? "").toString() !== paymentFields.providerId ||
    bank.isActive !== true
  ) {
    throw new HttpsError("failed-precondition", "Invalid provider bank account.");
  }

  const paymentRef = db.collection("payments").doc();
  await paymentRef.set({
    ...paymentFields,
    payerId: uid,
    methodType: "bank_transfer" as PaymentMethodType,
    status: "pending_verification" as PaymentStatus,
    gateway: "bank_transfer",
    bankTransfer: {
      bankAccountId,
      transferReference,
      paidAmount,
      paidAt: data.paidAt ?
        new Date((data.paidAt.seconds ?? 0) * 1000) :
        FieldValue.serverTimestamp(),
    },
    gatewayRefs: {
      attemptId: paymentRef.id,
      transactionId: transferReference,
    },
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await bookingRef.set({
    paymentStatus: "pending_verification",
    paymentAttemptId: paymentRef.id,
    paymentUpdatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  return {
    paymentAttemptId: paymentRef.id,
    status: "pending_verification",
  };
});

/** Admin-only approval/rejection of pending bank-transfer attempts. */
export const verifyBankTransfer = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!(await isAdminUid(uid))) {
    throw new HttpsError(
      "permission-denied",
      "Only admin can verify bank transfer.",
    );
  }
  const data = request.data as {
    paymentAttemptId?: string;
    approved?: boolean;
    note?: string;
  };
  const paymentAttemptId = (data.paymentAttemptId ?? "").toString().trim();
  if (!paymentAttemptId) {
    throw new HttpsError("invalid-argument", "paymentAttemptId is required.");
  }
  const approved = data.approved === true;
  const paymentRef = db.collection("payments").doc(paymentAttemptId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    throw new HttpsError("not-found", "Payment attempt not found.");
  }
  const payment = paymentSnap.data() ?? {};
  if ((payment.gateway ?? "").toString() !== "bank_transfer") {
    throw new HttpsError(
      "failed-precondition",
      "Payment is not a bank transfer.",
    );
  }
  if ((payment.status ?? "").toString() !== "pending_verification") {
    throw new HttpsError(
      "failed-precondition",
      "Payment is not pending verification.",
    );
  }
  const bookingId = (payment.bookingId ?? "").toString();
  if (!bookingId) {
    throw new HttpsError("failed-precondition", "Payment has no booking reference.");
  }
  const bookingRef = db.collection("bookings").doc(bookingId);

  const nextStatus: PaymentStatus = approved ? "paid" : "failed";
  await paymentRef.update({
    status: nextStatus,
    verification: {
      verifiedBy: uid,
      note: (data.note ?? "").toString(),
      verifiedAt: FieldValue.serverTimestamp(),
    },
    updatedAt: FieldValue.serverTimestamp(),
  });

  if (approved) {
    await bookingRef.set({
      paymentStatus: "paid",
      paymentAttemptId,
      paymentUpdatedAt: FieldValue.serverTimestamp(),
      paidAt: FieldValue.serverTimestamp(),
      grossAmount: Number(payment.grossAmount ?? payment.amount ?? 0),
      discountAmount: Number(payment.discountAmount ?? 0),
      netAmount: Number(payment.netAmount ?? payment.amount ?? 0),
    }, {merge: true});

    const receipt = await sendPaymentReceipt({
      paymentId: paymentAttemptId,
      bookingId,
      userId: (payment.seekerId ?? "").toString(),
      amount: Number(payment.netAmount ?? payment.amount ?? 0),
      status: "paid",
      transactionId:
        (payment.gatewayRefs?.transactionId ?? paymentAttemptId).toString(),
    });
    await paymentRef.update({
      receipt: {
        smsSent: receipt.smsSent,
        emailSent: receipt.emailSent,
        smsMessageId: receipt.smsMessageId ?? null,
        emailMessageId: receipt.emailMessageId ?? null,
        sentAt: FieldValue.serverTimestamp(),
      },
      updatedAt: FieldValue.serverTimestamp(),
    });

    await notifyPaymentParties({
      bookingId,
      seekerId: (payment.seekerId ?? "").toString(),
      providerId: (payment.providerId ?? "").toString(),
      amount: Number(payment.netAmount ?? payment.amount ?? 0),
      status: "paid",
    });
  } else {
    await bookingRef.set({
      paymentStatus: "failed",
      paymentAttemptId,
      paymentUpdatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  return {status: nextStatus};
});

/** Handles PayHere gateway callbacks, verifies signature, and finalizes payments. */
export const payHereWebhook = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  try {
    const merchantId = envStrict("PAYHERE_MERCHANT_ID");
    const secretHash = md5(envStrict("PAYHERE_MERCHANT_SECRET"));
    const payload = req.body as Record<string, unknown>;
    const orderId = (payload.order_id ?? "").toString();
    const paymentId = orderId.trim();
    const statusCode = (payload.status_code ?? "").toString();
    const amount = Number(payload.payhere_amount ?? 0).toFixed(2);
    const currency = (payload.payhere_currency ?? "LKR").toString();
    const receivedSig = (payload.md5sig ?? "").toString().toUpperCase();
    const expectedSig = md5(
      `${merchantId}${orderId}${amount}${currency}${statusCode}${secretHash}`,
    );

    if (!paymentId) {
      res.status(400).send("missing order_id");
      return;
    }
    if (!receivedSig || receivedSig !== expectedSig) {
      logger.warn("Webhook signature mismatch", {paymentId});
      res.status(401).send("invalid signature");
      return;
    }

    const paymentRef = db.collection("payments").doc(paymentId);
    const paymentSnap = await paymentRef.get();
    if (!paymentSnap.exists) {
      res.status(404).send("payment not found");
      return;
    }
    const payment = paymentSnap.data() ?? {};
    const isSuccess = statusCode === "2";
    const newStatus: PaymentStatus = isSuccess ? "success" : "failed";
    const transactionId =
      (payload.payment_id ?? payload.custom_1 ?? paymentId).toString();

    await paymentRef.update({
      status: newStatus,
      gatewayRefs: {
        attemptId: paymentId,
        transactionId,
        tokenId:
          (payload.card_token ?? payload.token_id ?? payment.gatewayRefs?.tokenId ?? null),
        cardLast4: (payload.card_no ?? "").toString().slice(-4),
        cardBrand: (payload.card_type ?? "").toString(),
      },
      updatedAt: FieldValue.serverTimestamp(),
    });
    const bookingId = (payment.bookingId ?? "").toString();
    if (bookingId) {
      await db.collection("bookings").doc(bookingId).set({
        paymentStatus: isSuccess ? "paid" : "failed",
        paymentAttemptId: paymentId,
        paymentUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    if (isSuccess) {
      if (!bookingId) {
        throw new HttpsError("failed-precondition", "Payment has no booking reference.");
      }
      await db.collection("bookings").doc(bookingId).set({
        paymentStatus: "paid",
        paidAt: FieldValue.serverTimestamp(),
        grossAmount: Number(payment.grossAmount ?? payment.amount ?? 0),
        discountAmount: Number(payment.discountAmount ?? 0),
        netAmount: Number(payment.netAmount ?? payment.amount ?? 0),
      }, {merge: true});

      const saveCard = payment.saveCard === true;
      const tokenId = (payload.card_token ??
        payload.token_id ??
        payment.gatewayRefs?.tokenId ??
        "").toString().trim();
      if (saveCard && tokenId) {
        const savedMethodsRef = db.collection("users")
          .doc((payment.seekerId ?? "").toString())
          .collection("savedPaymentMethods");
        const existingMethodSnap = await savedMethodsRef
          .where("tokenRef", "==", tokenId)
          .limit(1)
          .get();
        const targetRef = existingMethodSnap.docs.length > 0 ?
          existingMethodSnap.docs[0].ref :
          savedMethodsRef.doc();
        await targetRef.set({
          userId: (payment.seekerId ?? "").toString(),
          gateway: "payhere",
          tokenRef: tokenId,
          brand: (payload.card_type ?? "CARD").toString(),
          last4: (payload.card_no ?? "").toString().slice(-4),
          expiryMonth: Number(payload.expiry_month ?? 0) || null,
          expiryYear: Number(payload.expiry_year ?? 0) || null,
          isDefault: true,
          status: "active",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }

      const receipt = await sendPaymentReceipt({
        paymentId,
        bookingId,
        userId: (payment.seekerId ?? "").toString(),
        amount: Number(payment.netAmount ?? payment.amount ?? 0),
        status: "success",
        transactionId,
      });
      await paymentRef.update({
        receipt: {
          smsSent: receipt.smsSent,
          emailSent: receipt.emailSent,
          smsMessageId: receipt.smsMessageId ?? null,
          emailMessageId: receipt.emailMessageId ?? null,
          sentAt: FieldValue.serverTimestamp(),
        },
        updatedAt: FieldValue.serverTimestamp(),
      });

      await notifyPaymentParties({
        bookingId,
        seekerId: (payment.seekerId ?? "").toString(),
        providerId: (payment.providerId ?? "").toString(),
        amount: Number(payment.netAmount ?? payment.amount ?? 0),
        status: "success",
      });
    }

    res.status(200).send("ok");
  } catch (error) {
    logger.error("payHereWebhook failed", {error});
    res.status(500).send("internal error");
  }
});
