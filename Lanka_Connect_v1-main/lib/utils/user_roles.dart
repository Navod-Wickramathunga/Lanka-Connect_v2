class UserRoles {
  static const String seeker = 'seeker';
  static const String provider = 'provider';
  static const String admin = 'admin';
  static const String guest = 'guest';

  static String normalize(dynamic rawRole) {
    final role = (rawRole ?? '').toString().trim().toLowerCase();
    if (role == 'provider' || role == 'service provider') return provider;
    if (role == 'admin') return admin;
    if (role == 'guest') return guest;
    return seeker;
  }
}
