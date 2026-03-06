class Validators {
  static String? requiredField(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? numberField(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number';
    }
    return null;
  }

  static String? emailField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    // More robust email validation per RFC 5322
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? phoneField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(
      value.trim().replaceAll(RegExp(r'[\s\-\(\)]'), ''),
    )) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? priceField(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid price';
    }
    if (parsed <= 0) {
      return 'Price must be greater than 0';
    }
    return null;
  }

  static String? passwordField(String? value, {required bool isLogin}) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (!isLogin && value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? minLengthField(String? value, int min, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    if (value.trim().length < min) {
      return '$label must be at least $min characters';
    }
    return null;
  }

  static String? optionalLatitude(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < -90 || parsed > 90) {
      return 'Latitude must be between -90 and 90';
    }
    return null;
  }

  static String? optionalLongitude(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < -180 || parsed > 180) {
      return 'Longitude must be between -180 and 180';
    }
    return null;
  }

  static String? cardNumberField(String? value) {
    final raw = (value ?? '').replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) {
      return 'Card number is required';
    }
    if (!RegExp(r'^[0-9]{13,19}$').hasMatch(raw)) {
      return 'Enter a valid card number';
    }
    if (!_luhnCheck(raw)) {
      return 'Card number is invalid';
    }
    return null;
  }

  static String? expiryField(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'Expiry is required';
    }
    final match = RegExp(r'^([0-9]{2})\/([0-9]{2})$').firstMatch(raw);
    if (match == null) {
      return 'Use MM/YY';
    }
    final month = int.tryParse(match.group(1)!);
    final year2 = int.tryParse(match.group(2)!);
    if (month == null || year2 == null || month < 1 || month > 12) {
      return 'Enter a valid expiry date';
    }
    final now = DateTime.now();
    final year = 2000 + year2;
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59, 999);
    if (endOfMonth.isBefore(now)) {
      return 'Card has expired';
    }
    return null;
  }

  static String? cvvField(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'CVV is required';
    }
    if (!RegExp(r'^[0-9]{3,4}$').hasMatch(raw)) {
      return 'Enter a valid CVV';
    }
    return null;
  }

  static String? bankReferenceField(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'Transfer reference is required';
    }
    if (raw.length < 6) {
      return 'Reference must be at least 6 characters';
    }
    if (!RegExp(r'^[A-Za-z0-9\-_\/]+$').hasMatch(raw)) {
      return 'Use letters, numbers, -, _, / only';
    }
    return null;
  }

  static String normalizePhoneToE164(
    String value, {
    String defaultCountryCode = '+94',
  }) {
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) {
      return digits;
    }
    if (digits.startsWith('0')) {
      return '$defaultCountryCode${digits.substring(1)}';
    }
    return '$defaultCountryCode$digits';
  }

  static bool _luhnCheck(String digits) {
    var sum = 0;
    var alternate = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = int.parse(digits[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }
}
