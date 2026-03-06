import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/models/offer.dart';
import 'package:lanka_connect/utils/offer_service.dart';

void main() {
  Offer makeOffer({
    required String id,
    required OfferDiscountType type,
    required double value,
    bool isActive = true,
    String? category,
    double? minAmount,
    DateTime? startsAt,
    DateTime? endsAt,
  }) {
    return Offer(
      id: id,
      title: id,
      isActive: isActive,
      discountType: type,
      discountValue: value,
      targetCategory: category,
      minAmount: minAmount,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  test('chooses best eligible offer and does not stack', () {
    final offers = [
      makeOffer(id: 'flat200', type: OfferDiscountType.flat, value: 200),
      makeOffer(id: 'percent10', type: OfferDiscountType.percentage, value: 10),
    ];

    final result = OfferService.resolveBestOffer(
      offers: offers,
      grossAmount: 4000,
      serviceId: 's1',
      providerId: 'p1',
      category: 'Cleaning',
    );

    expect(result, isNotNull);
    expect(result!.offerId, 'percent10');
    expect(result.discountAmount, 400);
    expect(result.netAmount, 3600);
  });

  test('respects min amount and expiry', () {
    final now = DateTime.now();
    final offers = [
      makeOffer(
        id: 'expired',
        type: OfferDiscountType.flat,
        value: 1000,
        endsAt: now.subtract(const Duration(days: 1)),
      ),
      makeOffer(
        id: 'min5000',
        type: OfferDiscountType.flat,
        value: 500,
        minAmount: 5000,
      ),
    ];

    final result = OfferService.resolveBestOffer(
      offers: offers,
      grossAmount: 3000,
      serviceId: 's1',
      providerId: 'p1',
      category: 'Cleaning',
    );

    expect(result, isNull);
  });
}
