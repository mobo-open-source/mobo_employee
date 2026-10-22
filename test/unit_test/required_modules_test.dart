import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobo_employees/core/exceptions/app_exceptions.dart';
import 'package:mobo_employees/core/services/required_modules_service.dart';

/// A client that answers `/web/session/modules` with [result], as Odoo 17, 18
/// and 20 do: a JSON-RPC envelope around the list of installed modules.
MockClient _modulesServer(List<String> result) => MockClient(
  (_) async => http.Response(
    jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}),
    200,
  ),
);

void main() {
  const server = 'https://odoo.example.com';

  group('RequiredModules.findMissing', () {
    test('finds nothing missing when every required module is installed', () async {
      final missing = await RequiredModules.findMissing(
        serverUrl: server,
        sessionId: 'abc',
        client: _modulesServer(['base', 'web', 'hr', 'hr_attendance', 'hr_holidays']),
      );
      expect(missing, isEmpty);
    });

    test('reports Time Off when hr_holidays is not installed', () async {
      final missing = await RequiredModules.findMissing(
        serverUrl: server,
        sessionId: 'abc',
        client: _modulesServer(['base', 'web', 'hr', 'hr_attendance']),
      );
      expect(missing, ['hr_holidays']);
    });

    test('reports every required module on a database without HR', () async {
      final missing = await RequiredModules.findMissing(
        serverUrl: server,
        sessionId: 'abc',
        client: _modulesServer(['base', 'web', 'sale']),
      );
      expect(missing, ['hr', 'hr_attendance', 'hr_holidays']);
    });

    test('posts to /web/session/modules with the session cookie', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'result': <String>[]}), 200);
      });

      await RequiredModules.findMissing(
        serverUrl: server,
        sessionId: 'abc',
        client: client,
      );

      expect(seen.method, 'POST');
      expect(seen.url.toString(), '$server/web/session/modules');
      expect(seen.headers['Cookie'], 'session_id=abc');
      expect(jsonDecode(seen.body)['method'], 'call');
    });

    test('does not block when the server answers with an error', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'error': {'code': 100}}), 200),
      );
      expect(
        await RequiredModules.findMissing(
          serverUrl: server,
          sessionId: 'abc',
          client: client,
        ),
        isEmpty,
      );
    });

    test('does not block when the reply is not JSON', () async {
      final client = MockClient((_) async => http.Response('<html>', 502));
      expect(
        await RequiredModules.findMissing(
          serverUrl: server,
          sessionId: 'abc',
          client: client,
        ),
        isEmpty,
      );
    });

    test('does not block when the server cannot be reached', () async {
      final client = MockClient((_) async => throw http.ClientException('down'));
      expect(
        await RequiredModules.findMissing(
          serverUrl: server,
          sessionId: 'abc',
          client: client,
        ),
        isEmpty,
      );
    });

    test('does not call the server without a session', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      final missing = await RequiredModules.findMissing(
        serverUrl: server,
        sessionId: '',
        client: client,
      );
      expect(missing, isEmpty);
      expect(called, isFalse);
    });
  });

  group('RequiredModules.ensureInstalled', () {
    test('returns normally when every required module is installed', () async {
      await expectLater(
        RequiredModules.ensureInstalled(
          serverUrl: server,
          sessionId: 'abc',
          client: _modulesServer(['hr', 'hr_attendance', 'hr_holidays']),
        ),
        completes,
      );
    });

    test('throws RequiredModulesMissingException naming the missing modules', () async {
      await expectLater(
        RequiredModules.ensureInstalled(
          serverUrl: server,
          sessionId: 'abc',
          client: _modulesServer(['hr', 'hr_attendance']),
        ),
        throwsA(
          isA<RequiredModulesMissingException>()
              .having((e) => e.missingModules, 'missingModules', ['hr_holidays'])
              .having((e) => e.message, 'message', contains('Time Off')),
        ),
      );
    });
  });

  group('RequiredModules.messageFor', () {
    test('speaks of one module in the singular', () {
      expect(
        RequiredModules.messageFor(['hr_holidays']),
        'The Time Off module is not installed on this database. '
        'Please ask your administrator to install it, then try again.',
      );
    });

    test('joins several modules with "and"', () {
      expect(
        RequiredModules.messageFor(['hr', 'hr_attendance', 'hr_holidays']),
        'The Employee, Attendance and Time Off modules are not installed on '
        'this database. Please ask your administrator to install them, then '
        'try again.',
      );
    });

    test('keeps the technical name of a module it has no label for', () {
      expect(
        RequiredModules.messageFor(['hr_unknown']),
        contains('hr_unknown'),
      );
    });
  });
}
