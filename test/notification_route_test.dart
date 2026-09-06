import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/features/notifications/data/notifications_repository.dart';

void main() {
  group('where a tapped notification goes', () {
    test('an auction opens that auction', () {
      const tap = NotificationTap(kind: 'auction', id: 'a1');

      expect(tap.route, '/bid-room/a1');
    });

    test('a chat opens the chat tab', () {
      const tap = NotificationTap(kind: 'chat', id: 'ben_amina');

      expect(tap.route, '/chat');
    });

    test('a kind this build has never heard of goes nowhere', () {
      // A newer server can send anything. Opening the app is a better answer
      // than routing at a screen that does not exist.
      const tap = NotificationTap(kind: 'tournament', id: 't1');

      expect(tap.route, isNull);
    });

    test('a known kind with no id goes nowhere either', () {
      // '/bid-room/' is not a route, and pushing it would land on nothing.
      const tap = NotificationTap(kind: 'auction', id: '');

      expect(tap.route, isNull);
    });

    test('an empty payload goes nowhere', () {
      const tap = NotificationTap(kind: '', id: '');

      expect(tap.route, isNull);
    });
  });
}
