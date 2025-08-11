// Utility for validating phone numbers with pluggable strategies (SOLID).

/// Strategy interface (Open/Closed principle)
abstract class PhoneValidationStrategy {
  bool isValid(String phone);
}

/// Ukrainian mobile numbers (+380XXXXXXXXX)
class UaPhoneValidationStrategy implements PhoneValidationStrategy {
  final RegExp _uaReg = RegExp(r'^\+?380\d{9}$');
  @override
  bool isValid(String phone) => _uaReg.hasMatch(phone);
}

/// Registry + facade for phone validation
class PhoneValidator {
  PhoneValidator._();

  static final Map<String, PhoneValidationStrategy> _strategies = {
    'UA': UaPhoneValidationStrategy(),
  };

  /// Validate phone. Country can be passed (e.g., 'UA') or auto-detected by prefix.
  static bool validate(String phone, {String? countryCode}) {
    final code = countryCode ?? _detectCountry(phone);
    final strategy = _strategies[code];
    return strategy?.isValid(phone) ?? false;
  }

  /// Add/override validation strategy at runtime (e.g., when додамо нові країни).
  static void register(String code, PhoneValidationStrategy strategy) {
    _strategies[code] = strategy;
  }

  static String? _detectCountry(String phone) {
    if (phone.startsWith('+380')) return 'UA';
    // add other prefixes later
    return null;
  }
} 