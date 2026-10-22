import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

void main() {
  group('ConnectivityService.isConnectivityError', () {
    test('matches the typed connectivity exceptions', () {
      expect(
        ConnectivityService.isConnectivityError(NoInternetException('x')),
        isTrue,
      );
      expect(
        ConnectivityService.isConnectivityError(
          ServerUnreachableException('x'),
        ),
        isTrue,
      );
    });

    test('matches raw transport errors from the HTTP layer', () {
      expect(
        ConnectivityService.isConnectivityError(
          const SocketException('Connection refused'),
        ),
        isTrue,
      );
      expect(
        ConnectivityService.isConnectivityError(
          http.ClientException(
            'SocketException: Connection refused (OS Error: Connection '
            'refused, errno = 111), address = 10.0.20.120, port = 42098',
            Uri.parse('http://10.0.20.120:8020/web/dataset/call_kw'),
          ),
        ),
        isTrue,
      );
      expect(
        ConnectivityService.isConnectivityError(TimeoutException('slow')),
        isTrue,
      );
      expect(
        ConnectivityService.isConnectivityError(
          const HttpException('Connection closed while receiving data'),
        ),
        isTrue,
      );
    });

    test('matches a proxy HTML error page served while Odoo is down', () {
      expect(
        ConnectivityService.isConnectivityError(
          const FormatException(
            'Unexpected character',
            '<html><head><title>502 Bad Gateway</title></head></html>',
          ),
        ),
        isTrue,
      );
    });

    test('matches connectivity errors re-wrapped as plain exceptions', () {
      expect(
        ConnectivityService.isConnectivityError(
          Exception(
            'Failed to fetch administrator: '
            '${ServerUnreachableException('Unable to connect')}',
          ),
        ),
        isTrue,
      );
    });

    test('does not match errors returned by Odoo', () {
      expect(
        ConnectivityService.isConnectivityError(
          OdooException({
            'code': 200,
            'message': 'Odoo Server Error',
            'data': {
              'name': 'odoo.exceptions.AccessError',
              'message': 'You are not allowed to access this document.',
            },
          }),
        ),
        isFalse,
      );
      expect(
        ConnectivityService.isConnectivityError(
          const FormatException('Invalid date format', '2024-13-45'),
        ),
        isFalse,
      );
      expect(
        ConnectivityService.isConnectivityError(StateError('No session')),
        isFalse,
      );
    });
  });
}
