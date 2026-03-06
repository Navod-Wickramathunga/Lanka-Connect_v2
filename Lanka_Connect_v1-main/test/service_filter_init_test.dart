import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/screens/services/service_list_screen.dart';

void main() {
  test('ServiceListScreen accepts initial filter parameters', () {
    const screen = ServiceListScreen(
      initialCategory: 'Cleaning',
      initialDistrict: 'Colombo',
      initialCity: 'Maharagama',
      initialNearMe: true,
      autoApplyInitialFilters: true,
    );

    expect(screen.initialCategory, 'Cleaning');
    expect(screen.initialDistrict, 'Colombo');
    expect(screen.initialCity, 'Maharagama');
    expect(screen.initialNearMe, isTrue);
    expect(screen.autoApplyInitialFilters, isTrue);
  });
}
