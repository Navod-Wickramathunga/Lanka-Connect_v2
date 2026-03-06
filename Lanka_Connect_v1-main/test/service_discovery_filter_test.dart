import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/models/service_discovery_filter.dart';

void main() {
  test('normalizes discovery filter input safely', () {
    const filter = ServiceDiscoveryFilter(
      category: '  Cleaning  ',
      query: '  deep clean ',
      district: '  Colombo ',
      city: ' Maharagama ',
      nearMe: true,
      autoApply: true,
    );

    expect(filter.normalizedCategory, 'Cleaning');
    expect(filter.normalizedQuery, 'deep clean');
    expect(filter.normalizedDistrict, 'Colombo');
    expect(filter.normalizedCity, 'Maharagama');
    expect(filter.nearMe, isTrue);
    expect(filter.autoApply, isTrue);
  });
}
