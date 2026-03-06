class ServiceDiscoveryFilter {
  const ServiceDiscoveryFilter({
    this.category,
    this.query,
    this.district,
    this.city,
    this.nearMe,
    this.autoApply = false,
  });

  final String? category;
  final String? query;
  final String? district;
  final String? city;
  final bool? nearMe;
  final bool autoApply;

  String get normalizedCategory => (category ?? '').trim();
  String get normalizedQuery => (query ?? '').trim();
  String get normalizedDistrict => (district ?? '').trim();
  String get normalizedCity => (city ?? '').trim();
}
