import 'dart:convert';

import 'package:http/http.dart' as http;

import '../exceptions/app_exceptions.dart';

/// The Odoo modules this app can't work without, and the check that a
/// database has them.
///
/// The check reads `/web/session/modules` rather than querying
/// `ir.module.module`: that model is readable by `base.group_system` only
/// (17, 18 and 20 alike), so for an ordinary employee the query is refused
/// and a check built on it silently passes. The endpoint only needs a
/// logged-in user of any kind, and lists every module the database has
/// installed.
class RequiredModules {
  RequiredModules._();

  /// Technical name -> the name Odoo shows in its Apps menu.
  static const Map<String, String> labels = {
    'hr': 'Employee',
    'hr_attendance': 'Attendance',
    'hr_holidays': 'Time Off',
  };

  static List<String> get names => labels.keys.toList();

  /// The required modules the database behind [sessionId] doesn't have.
  ///
  /// Empty when everything is installed, and also when the server can't say
  /// (unreachable, an unexpected reply): an unanswered check isn't proof of a
  /// missing module, so it must not lock anyone out.
  static Future<List<String>> findMissing({
    required String serverUrl,
    required String sessionId,
    http.Client? client,
  }) async {
    if (sessionId.isEmpty) return const [];

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .post(
            Uri.parse('$serverUrl/web/session/modules'),
            headers: {
              'Content-Type': 'application/json',
              'Cookie': 'session_id=$sessionId',
            },
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'call',
              'params': const {},
              'id': DateTime.now().microsecondsSinceEpoch,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);
      final result = decoded is Map ? decoded['result'] : null;
      if (result is! List) return const [];

      final installed = result.map((e) => e.toString()).toSet();
      return names.where((m) => !installed.contains(m)).toList();
    } catch (_) {
      return const [];
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Throws [RequiredModulesMissingException] when the database behind
  /// [sessionId] lacks a required module. Call it right after the server has
  /// accepted the credentials and before any "logged in" state is saved.
  static Future<void> ensureInstalled({
    required String serverUrl,
    required String sessionId,
    http.Client? client,
  }) async {
    final missing = await findMissing(
      serverUrl: serverUrl,
      sessionId: sessionId,
      client: client,
    );
    if (missing.isEmpty) return;
    throw RequiredModulesMissingException(
      messageFor(missing),
      missingModules: missing,
    );
  }

  /// What the sign-in screen tells the user.
  static String messageFor(List<String> missing) {
    final shown = missing.map((m) => labels[m] ?? m).toList();
    final plural = shown.length > 1;
    final listed = plural
        ? '${shown.sublist(0, shown.length - 1).join(', ')} and ${shown.last}'
        : shown.single;
    return 'The $listed module${plural ? 's are' : ' is'} not installed on '
        'this database. Please ask your administrator to install '
        '${plural ? 'them' : 'it'}, then try again.';
  }
}
