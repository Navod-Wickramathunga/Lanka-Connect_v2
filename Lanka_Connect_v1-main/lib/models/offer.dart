import 'package:cloud_firestore/cloud_firestore.dart';

enum OfferDiscountType { percentage, flat }

class Offer {
  const Offer({
    required this.id,
    required this.title,
    required this.isActive,
    required this.discountType,
    required this.discountValue,
    this.targetServiceId,
    this.targetProviderId,
    this.targetCategory,
    this.minAmount,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String title;
  final bool isActive;
  final OfferDiscountType discountType;
  final double discountValue;
  final String? targetServiceId;
  final String? targetProviderId;
  final String? targetCategory;
  final double? minAmount;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory Offer.fromMap(String id, Map<String, dynamic> data) {
    OfferDiscountType parseType(dynamic value) {
      final normalized = (value ?? '').toString().toLowerCase();
      return normalized == 'flat'
          ? OfferDiscountType.flat
          : OfferDiscountType.percentage;
    }

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return Offer(
      id: id,
      title: (data['title'] ?? 'Offer').toString(),
      isActive: (data['isActive'] ?? false) == true,
      discountType: parseType(data['discountType']),
      discountValue: (data['discountValue'] is num)
          ? (data['discountValue'] as num).toDouble()
          : 0,
      targetServiceId: data['targetServiceId']?.toString(),
      targetProviderId: data['targetProviderId']?.toString(),
      targetCategory: data['targetCategory']?.toString(),
      minAmount: (data['minAmount'] is num)
          ? (data['minAmount'] as num).toDouble()
          : null,
      startsAt: parseDate(data['startsAt']),
      endsAt: parseDate(data['endsAt']),
    );
  }
}

class AppliedOfferResult {
  const AppliedOfferResult({
    required this.offerId,
    required this.discountAmount,
    required this.grossAmount,
    required this.netAmount,
    required this.meta,
  });

  final String offerId;
  final double discountAmount;
  final double grossAmount;
  final double netAmount;
  final Map<String, dynamic> meta;
}
