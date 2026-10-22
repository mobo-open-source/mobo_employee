import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/core/exceptions/app_exceptions.dart';
import 'package:mobo_employees/core/models/database_expiry.dart';

void main() {
  /// The server's clock when the payloads below were captured.
  final now = DateTime.utc(2026, 10, 16, 11, 5);

  group('DatabaseExpiry.ensureActive', () {
    test('lets a database through when session_info has no expiry keys', () {
      /// Community, or a portal user: Odoo sends no warning/expiration_*.
      expect(() => DatabaseExpiry.ensureActive({'uid': 7}, now: now), returnsNormally);
    });

    test('lets a database through when the expiry is unset (false)', () {
      expect(
        () => DatabaseExpiry.ensureActive({
          'warning': 'admin',
          'expiration_date': false,
          'expiration_reason': false,
        }, now: now),
        returnsNormally,
      );
    });

    test('lets a database through while the subscription is running', () {
      expect(
        () => DatabaseExpiry.ensureActive({
          'warning': 'user',
          'expiration_date': '2026-11-12 10:17:32',
          'expiration_reason': 'trial',
        }, now: now),
        returnsNormally,
      );
    });

    test('blocks an expired subscription, as sent by Odoo 20', () {
      expect(
        () => DatabaseExpiry.ensureActive({
          'warning': 'admin',
          'expiration_date': '2026-10-01 08:00:00',
          'expiration_reason': 'renewal',
        }, now: now),
        throwsA(
          isA<DatabaseExpiredException>()
              .having((e) => e.expirationDate, 'expirationDate',
                  DateTime.utc(2026, 10, 1, 8))
              .having((e) => e.reason, 'reason', 'renewal')
              .having((e) => e.message, 'message',
                  contains("subscription has expired")),
        ),
      );
    });

    test('blocks an expired trial and says it was a trial', () {
      /// A bare date means midnight UTC.
      expect(
        () => DatabaseExpiry.ensureActive({
          'warning': 'user',
          'expiration_date': '2026-10-01',
          'expiration_reason': 'trial',
        }, now: now),
        throwsA(
          isA<DatabaseExpiredException>()
              .having((e) => e.expirationDate, 'expirationDate',
                  DateTime.utc(2026, 10, 1))
              .having((e) => e.message, 'message', contains('trial')),
        ),
      );
    });

    test('is an AuthException, so generic error handling shows its message', () {
      expect(
        () => DatabaseExpiry.ensureActive({
          'expiration_date': '2026-10-01 08:00:00',
        }, now: now),
        throwsA(isA<AuthException>()),
      );
    });

    test('never blocks on a date it cannot read (as in Odoo)', () {
      for (final garbage in ['', 'soon', '31/12/2026', null, 12345]) {
        expect(
          () => DatabaseExpiry.ensureActive({'expiration_date': garbage}, now: now),
          returnsNormally,
          reason: 'expiration_date: $garbage',
        );
      }
    });
  });

  group('DatabaseExpiry.isExpiredAt follows Odoo\'s daysLeft <= 0 rule', () {
    /// Odoo rounds the days left to whole days: the web client locks the
    /// database from 12 hours before the stored expiry.
    DatabaseExpiry endingIn(Duration d) =>
        DatabaseExpiry(expirationDate: now.add(d), reason: 'renewal');

    test('a day left is active', () {
      expect(endingIn(const Duration(days: 1)).isExpiredAt(now), isFalse);
    });

    test('just over 12 hours left is still active', () {
      expect(endingIn(const Duration(hours: 12, minutes: 1)).isExpiredAt(now), isFalse);
    });

    test('exactly 12 hours left is still active (0.5 rounds up)', () {
      expect(endingIn(const Duration(hours: 12)).isExpiredAt(now), isFalse);
    });

    test('just under 12 hours left is blocked', () {
      expect(endingIn(const Duration(hours: 11, minutes: 59)).isExpiredAt(now), isTrue);
    });

    test('expired a moment ago and long ago are blocked', () {
      expect(endingIn(const Duration(seconds: -1)).isExpiredAt(now), isTrue);
      expect(endingIn(const Duration(days: -30)).isExpiredAt(now), isTrue);
    });

    test('no date never expires', () {
      expect(const DatabaseExpiry().isExpiredAt(now), isFalse);
    });

    test('uses the given clock, not a wrong device clock', () {
      const info = {'expiration_date': '2026-10-20 00:00:00'};
      expect(
        () => DatabaseExpiry.ensureActive(info, now: DateTime.utc(2026, 10, 16)),
        returnsNormally,
      );
      expect(
        () => DatabaseExpiry.ensureActive(info, now: DateTime.utc(2026, 10, 25)),
        throwsA(isA<DatabaseExpiredException>()),
      );
    });
  });
}
