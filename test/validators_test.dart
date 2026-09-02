import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/utils/validators.dart';

void main() {
  group('email', () {
    test('accepts ordinary and university addresses', () {
      expect(Validators.email('student@university.edu'), isNull);
      expect(Validators.email('a.b-c@sub.uni.ac.uk'), isNull);
      expect(Validators.email('  spaced@uni.edu  '), isNull);
    });

    test('rejects blanks and malformed addresses', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('   '), isNotNull);
      expect(Validators.email('no-at-sign.edu'), isNotNull);
      expect(Validators.email('no@tld'), isNotNull);
      expect(Validators.email('two@@at.edu'), isNotNull);
    });
  });

  group('password', () {
    test('enforces the Firebase minimum on signup', () {
      expect(Validators.password('123456'), isNull);
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password(''), isNotNull);
      expect(Validators.password(null), isNotNull);
    });

    test('login only requires a value', () {
      // An account created before the rule changed still has to be able to
      // sign in, so login must not apply the length minimum.
      expect(Validators.loginPassword('short'), isNull);
      expect(Validators.loginPassword(''), isNotNull);
    });
  });

  group('fullName', () {
    test('requires something and caps the length', () {
      expect(Validators.fullName('Amina Khan'), isNull);
      expect(Validators.fullName('  '), isNotNull);
      expect(Validators.fullName('a' * Validators.maxNameLength), isNull);
      expect(
        Validators.fullName('a' * (Validators.maxNameLength + 1)),
        isNotNull,
      );
    });
  });

  group('price', () {
    test('accepts valid amounts', () {
      expect(Validators.price('0'), isNull);
      expect(Validators.price('24.50'), isNull);
      expect(Validators.price(' 12 '), isNull);
      expect(Validators.price(Validators.maxPrice.toStringAsFixed(0)), isNull);
    });

    test('rejects the inputs that used to post a free item', () {
      // `double.tryParse(...) ?? 0.0` turned each of these into £0.00.
      expect(Validators.price('abc'), isNotNull);
      expect(Validators.price(''), isNotNull);
      expect(Validators.price('  '), isNotNull);
      expect(Validators.price('12,50'), isNotNull);
    });

    test('rejects out-of-range amounts', () {
      expect(Validators.price('-1'), isNotNull);
      expect(Validators.price((Validators.maxPrice + 1).toString()), isNotNull);
    });

    test('bounds match what firestore.rules will accept', () {
      // The rules cap price at 99999; a client-side limit above that would
      // produce a confusing permission-denied instead of an inline message.
      expect(Validators.maxPrice, 99999);
    });
  });

  group('listingTitle and description', () {
    test('title is required and capped', () {
      expect(Validators.listingTitle('Campbell Biology'), isNull);
      expect(Validators.listingTitle(''), isNotNull);
      expect(
        Validators.listingTitle('a' * (Validators.maxTitleLength + 1)),
        isNotNull,
      );
    });

    test('description is optional but capped', () {
      expect(Validators.description(''), isNull);
      expect(Validators.description(null), isNull);
      expect(
        Validators.description('a' * (Validators.maxDescriptionLength + 1)),
        isNotNull,
      );
    });
  });
}
