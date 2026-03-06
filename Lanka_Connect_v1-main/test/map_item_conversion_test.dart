import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/utils/geo_utils.dart';
import 'package:lanka_connect/utils/location_lookup.dart';

void main() {
  test('extractPoint returns exact coordinates when valid', () {
    final point = GeoUtils.extractPoint({'lat': 6.9271, 'lng': 79.8612});
    expect(point, isNotNull);
    expect(point!.latitude, closeTo(6.9271, 0.0001));
    expect(point.longitude, closeTo(79.8612, 0.0001));
  });

  test('location lookup resolves approximate point from district/city', () {
    final resolvedCity = LocationLookup.resolve(city: 'Colombo', district: '');
    expect(resolvedCity, isNotNull);
    expect(resolvedCity!.isApproximate, isTrue);

    final resolvedDistrict = LocationLookup.resolve(
      city: '',
      district: 'Gampaha',
    );
    expect(resolvedDistrict, isNotNull);
    expect(resolvedDistrict!.isApproximate, isTrue);
  });
}
