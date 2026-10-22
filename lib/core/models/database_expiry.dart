import 'package:intl/intl.dart';

import '../exceptions/app_exceptions.dart';

/// When an Odoo Enterprise database's subscription ends, as the server
/// reports it in `session_info` (`expiration_date`, `expiration_reason`).
///
/// Odoo's own web client blocks a database whose subscription has run out,
/// but only in its UI: the RPC API keeps answering, so without this check
/// the app would let users into a database Odoo itself locks. Only internal
/// users of an Enterprise database get these keys (18, 19 and 20 alike);
/// without them — Community, or a database with no date — there is nothing
/// to enforce and the database counts as active, as in Odoo.
class DatabaseExpiry {
  /// End of the subscription (UTC); null when the server sent no usable date.
  final DateTime? expirationDate;

  /// Odoo's `expiration_reason`; null when absent.
  final String? reason;

  const DatabaseExpiry({this.expirationDate, this.reason});

  factory DatabaseExpiry.fromSessionInfo(Map<dynamic, dynamic> sessionInfo) {
    final rawReason = sessionInfo['expiration_reason'];
    return DatabaseExpiry(
      expirationDate: _parseOdooUtc(sessionInfo['expiration_date']),
      reason: rawReason is String && rawReason.isNotEmpty ? rawReason : null,
    );
  }

  /// A trial/demo database, as opposed to one with a registered subscription
  /// (Odoo's "unregistered").
  bool get isTrial => reason == null || reason == 'trial' || reason == 'demo';

  /// Odoo's own rule (enterprise_subscription_service.js): the days left are
  /// rounded to whole days and the database is blocked once that reaches 0.
  /// An unparsable or missing date never blocks.
  bool isExpiredAt(DateTime now) {
    final date = expirationDate;
    if (date == null) return false;
    final daysLeft =
        date.difference(now.toUtc()).inMilliseconds / Duration.millisecondsPerDay;
    return daysLeft.round() <= 0;
  }

  /// What the sign-in screen tells the user.
  String get message {
    final date = expirationDate;
    final until = date == null
        ? ''
        : ' (valid until ${DateFormat('d MMM yyyy').format(date.toLocal())})';
    return isTrial
        ? 'The trial of this database has ended$until. '
              'Please contact your administrator to register a subscription.'
        : 'This database\'s subscription has expired$until. '
              'Please contact your administrator to renew it.';
  }

  /// Throws [DatabaseExpiredException] when [sessionInfo] — the payload of
  /// `/web/session/authenticate` or `/web/session/get_session_info` — says
  /// the database has expired. [now] should be the server's clock when
  /// known, so a wrong device clock can neither lock out nor let in.
  static void ensureActive(Map<dynamic, dynamic> sessionInfo, {DateTime? now}) {
    final expiry = DatabaseExpiry.fromSessionInfo(sessionInfo);
    if (!expiry.isExpiredAt(now ?? DateTime.now())) return;
    throw DatabaseExpiredException(
      expiry.message,
      expirationDate: expiry.expirationDate,
      reason: expiry.reason,
    );
  }

  /// Odoo sends datetimes as naive UTC "yyyy-MM-dd HH:mm:ss" strings, and a
  /// date alone ("yyyy-MM-dd") means midnight UTC. Anything else, including
  /// the `false` of an unset value, is no date.
  static DateTime? _parseOdooUtc(dynamic raw) {
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    final withTime = text.contains(':') ? text : '$text 00:00:00';
    final iso = withTime.replaceFirst(' ', 'T');
    final hasZone = iso.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(iso);
    return DateTime.tryParse(hasZone ? iso : '${iso}Z')?.toUtc();
  }
}
