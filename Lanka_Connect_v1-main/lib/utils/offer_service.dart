import '../models/offer.dart';
import 'firestore_refs.dart';

class OfferService {
  const OfferService._();

  static Future<List<Offer>> loadActiveOffers() async {
    final snapshot = await FirestoreRefs.offers().get();
    return snapshot.docs
        .map((doc) => Offer.fromMap(doc.id, doc.data()))
        .where((offer) => offer.isActive)
        .toList();
  }

  static AppliedOfferResult? resolveBestOffer({
    required List<Offer> offers,
    required double grossAmount,
    required String serviceId,
    required String providerId,
    required String category,
  }) {
    final now = DateTime.now();
    Offer? bestOffer;
    double bestDiscount = 0;

    for (final offer in offers) {
      if (!_isEligible(
        offer: offer,
        now: now,
        grossAmount: grossAmount,
        serviceId: serviceId,
        providerId: providerId,
        category: category,
      )) {
        continue;
      }

      final discount = _discountAmount(offer, grossAmount);
      if (discount > bestDiscount) {
        bestDiscount = discount;
        bestOffer = offer;
      }
    }

    if (bestOffer == null || bestDiscount <= 0) return null;
    final net = (grossAmount - bestDiscount).clamp(0, grossAmount).toDouble();
    return AppliedOfferResult(
      offerId: bestOffer.id,
      discountAmount: bestDiscount,
      grossAmount: grossAmount,
      netAmount: net,
      meta: {
        'title': bestOffer.title,
        'discountType': bestOffer.discountType.name,
        'discountValue': bestOffer.discountValue,
        'targetServiceId': bestOffer.targetServiceId,
        'targetProviderId': bestOffer.targetProviderId,
        'targetCategory': bestOffer.targetCategory,
      },
    );
  }

  static bool _isEligible({
    required Offer offer,
    required DateTime now,
    required double grossAmount,
    required String serviceId,
    required String providerId,
    required String category,
  }) {
    if (offer.startsAt != null && now.isBefore(offer.startsAt!)) return false;
    if (offer.endsAt != null && now.isAfter(offer.endsAt!)) return false;
    if (offer.minAmount != null && grossAmount < offer.minAmount!) return false;
    if (offer.targetServiceId != null && offer.targetServiceId != serviceId) {
      return false;
    }
    if (offer.targetProviderId != null &&
        offer.targetProviderId != providerId) {
      return false;
    }
    if (offer.targetCategory != null &&
        offer.targetCategory!.trim().toLowerCase() !=
            category.trim().toLowerCase()) {
      return false;
    }
    return true;
  }

  static double _discountAmount(Offer offer, double grossAmount) {
    if (offer.discountType == OfferDiscountType.flat) {
      return offer.discountValue.clamp(0, grossAmount);
    }
    final percent = offer.discountValue.clamp(0, 100);
    return (grossAmount * percent / 100).clamp(0, grossAmount);
  }
}
