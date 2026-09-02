/// Form validators shared by the auth and sell forms.
///
/// Each returns null when the value is acceptable, or the message to show
/// under the field. Bounds here mirror the ones in `firestore.rules` — a
/// client-side check is a courtesy, the rules are the enforcement.
library;

class Validators {
  Validators._();

  /// Firebase Auth's own minimum. Rejecting shorter passwords here turns a
  /// round-trip failure into an instant inline message.
  static const int minPasswordLength = 6;

  static const int maxNameLength = 80;
  static const int maxTitleLength = 120;
  static const int maxDescriptionLength = 2000;
  static const double maxPrice = 99999;

  static final RegExp _email = RegExp(
    r'^[\w.!#$%&’*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$',
  );

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email address';
    if (!_email.hasMatch(text)) {
      return 'That doesn\'t look like an email address';
    }
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter your password';
    if (text.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    return null;
  }

  /// Password check for the login form, which shouldn't lecture an existing
  /// user about a rule that changed after they signed up.
  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password';
    return null;
  }

  static String? fullName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your name';
    if (text.length > maxNameLength) {
      return 'Keep it under $maxNameLength characters';
    }
    return null;
  }

  static String? listingTitle(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Give your listing a title';
    if (text.length > maxTitleLength) {
      return 'Keep it under $maxTitleLength characters';
    }
    return null;
  }

  static String? description(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > maxDescriptionLength) {
      return 'Keep it under $maxDescriptionLength characters';
    }
    return null;
  }

  static String? price(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter a price';

    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter a number, e.g. 24.50';
    if (parsed < 0) return 'Price can\'t be negative';
    if (parsed > maxPrice) return 'Enter a price under £${maxPrice.toInt()}';
    return null;
  }

  /// Optional field — blank is fine, but a value has to be reasonable.
  static String? university(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > 120) return 'Keep it under 120 characters';
    return null;
  }
}
