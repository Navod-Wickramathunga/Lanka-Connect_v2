import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_connect/utils/profile_identity.dart';

class _FakeUser implements User {
  _FakeUser({this.displayNameValue, this.emailValue, this.photoUrlValue});

  final String? displayNameValue;
  final String? emailValue;
  final String? photoUrlValue;

  @override
  String? get displayName => displayNameValue;

  @override
  String? get email => emailValue;

  @override
  String? get photoURL => photoUrlValue;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ProfileIdentity.displayNameFrom', () {
    test('prefers explicit Firestore display name', () {
      final result = ProfileIdentity.displayNameFrom({
        'displayName': 'Portal User',
        'name': 'Ignored Name',
      }, authUser: _FakeUser(displayNameValue: 'Auth Name'));

      expect(result, 'Portal User');
    });

    test('falls back to auth display name and email prefix', () {
      expect(
        ProfileIdentity.displayNameFrom(
          const {},
          authUser: _FakeUser(displayNameValue: 'Auth Name'),
        ),
        'Auth Name',
      );

      expect(
        ProfileIdentity.displayNameFrom(
          const {},
          authUser: _FakeUser(emailValue: 'user@example.com'),
        ),
        'user',
      );
    });
  });

  group('ProfileIdentity.profileImageUrlFrom', () {
    test('prefers Firestore image url when present', () {
      final result = ProfileIdentity.profileImageUrlFrom(
        {'imageUrl': 'https://cdn.example.com/firestore.png'},
        authUser: _FakeUser(photoUrlValue: 'https://cdn.example.com/auth.png'),
      );

      expect(result, 'https://cdn.example.com/firestore.png');
    });

    test('falls back to auth photo url when Firestore image is empty', () {
      final result = ProfileIdentity.profileImageUrlFrom(
        {'imageUrl': '   '},
        authUser: _FakeUser(photoUrlValue: 'https://cdn.example.com/auth.png'),
      );

      expect(result, 'https://cdn.example.com/auth.png');
    });
  });
}
