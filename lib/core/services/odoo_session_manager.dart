import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../exceptions/app_exceptions.dart';
import '../models/appsession.dart';
import '../models/database_expiry.dart';
import '../utils/odoo_binary_utils.dart';
import '../utils/server_url_utils.dart';
import 'secure_storage_service.dart';
import 'connectivity_service.dart';
import 'odoo_metadata_service.dart';
import 'required_modules_service.dart';

enum LoginStatus { success, twoFactorEnabled, failed }

/// Thrown by [OdooSessionManager._authenticateDetectingMfa] when the server
/// accepted the password but requires a second factor. Odoo returns this
/// as a successful `{'uid': None}` result rather than an RPC error.
class MfaRequiredException implements Exception {
  @override
  String toString() => 'Two-factor authentication is required.';
}

class OdooSessionManager {
  //// Session state
  static OdooClient? _client;
  static AppSessionData? _cachedSession;
  static bool _isRefreshing = false;
  static DateTime? _lastAuthTime;

  /// Retry configuration
  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(milliseconds: 500);
  static const Duration _sessionCacheValidDuration = Duration(minutes: 5);

  /// Without a connection timeout, a request to a server whose host is
  /// down (no TCP reset) waits on the OS default of ~2 minutes before
  /// failing, keeping screens on their loading shimmer the whole time.
  /// This bounds only connection setup, not slow responses.
  static const Duration _connectionTimeout = Duration(seconds: 12);

  static OdooClient _newClient(String serverUrl, {OdooSession? sessionId}) {
    final httpClient = HttpClient()..connectionTimeout = _connectionTimeout;
    return OdooClient(
      serverUrl,
      sessionId: sessionId,
      httpClient: IOClient(httpClient),
    );
  }

  /// Callbacks for session events
  static Function(AppSessionData)? _onSessionUpdated;
  static Function()? _onSessionCleared;

  /// Set callbacks for session lifecycle events
  static void setSessionCallbacks({
    Function(AppSessionData)? onSessionUpdated,
    Function()? onSessionCleared,
  }) {
    _onSessionUpdated = onSessionUpdated;
    _onSessionCleared = onSessionCleared;
  }

  /// Check if an error is retryable
  static bool _isRetryableError(Object e) {
    if (e is SocketException) return true;
    if (e is TimeoutException) return true;
    if (e is http.ClientException) return true;

    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('connection reset') ||
        errorStr.contains('timed out') ||
        errorStr.contains('connection refused');
  }

  /// Restore a previously saved session and force a company context
  static Future<bool> restoreSession({required int companyId}) async {
    if (companyId <= 0) return false;

    final saved = await getCurrentSession();
    if (saved == null) return false;

    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(saved.serverUrl);

      final OdooClient client = _newClient(
        saved.serverUrl,
        sessionId: saved.odooSession,
      );

      List<int> allowed = [...saved.allowedCompanyIds];

      // If the allowed list is empty, we might need to fetch defaults.
      // But if it's populated, we trust the user's selection and just ensure the active company is added.
      if (allowed.isEmpty && saved.userId != 0) {
        try {
          final userCompanies = await _fetchUserCompanies(client, saved.userId);
          final loadedAllowed =
              (userCompanies['company_ids'] as List<int>? ?? []);
          if (loadedAllowed.isNotEmpty) allowed = loadedAllowed;
        } catch (e) {}
      }

      if (!allowed.contains(companyId)) {
        allowed.add(companyId);
      }

      final refreshed = saved.copyWith(
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        selectedCompanyId: companyId,
        allowedCompanyIds: <int>{...allowed}.toList(),
        isStockUser: saved.isStockUser,
      );

      _client = client;
      _cachedSession = refreshed;
      _lastAuthTime = DateTime.now();
      await refreshed.saveToPrefs();
      ConnectivityService.instance.setCurrentServerUrl(refreshed.serverUrl);
      _onSessionUpdated?.call(refreshed);
      return true;
    } on NoInternetException catch (_) {
      return false;
    } on ServerUnreachableException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if an error is authentication-related
  static bool _isAuthError(Object e) {
    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('401') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('access denied') ||
        errorStr.contains('invalid session') ||
        errorStr.contains('session expired') ||
        errorStr.contains('authentication') ||
        errorStr.contains('forbidden') ||
        errorStr.contains('403');
  }

  /// Get current session from cache or storage
  static Future<AppSessionData?> getCurrentSession() async {
    if (_cachedSession != null) return _cachedSession;

    try {
      final saved = await AppSessionData.fromPrefs();
      if (saved == null) return null;

      if (saved.odooSession.id.isNotEmpty) {
        final session = AppSessionData(
          odooSession: saved.odooSession,
          password: saved.password,
          serverUrl: saved.serverUrl,
          database: saved.database,
        );
        return session;
      }

      final client = _newClient(saved.serverUrl);
      final odooSession = await client.authenticate(
        saved.database,
        saved.userLogin,
        saved.password,
      );

      final sessionData = AppSessionData(
        odooSession: odooSession,
        password: saved.password,
        serverUrl: saved.serverUrl,
        database: saved.database,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        selectedCompanyId: saved.selectedCompanyId,
        allowedCompanyIds: saved.allowedCompanyIds,
        isStockUser: saved.isStockUser,
      );

      _client = client;
      _cachedSession = sessionData;
      _lastAuthTime = DateTime.now();
      ConnectivityService.instance.setCurrentServerUrl(saved.serverUrl);

      return sessionData;
    } catch (e) {
      return null;
    }
  }

  /// Check if current session is valid (not expired)
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  /// Login and save session


  static Future<LoginStatus> loginAndSaveSession({
    required String serverUrl,
    required String database,
    required String userLogin,
    required String password,
    bool autoLoadCompanies = true,
    bool otp = false,
    OdooClient? odooClient,
    String? sessionId,
  }) async {
    if (serverUrl.isEmpty || database.isEmpty || userLogin.isEmpty) {
      throw Exception('Invalid login parameters');
    }

    String normalizedUrl = normalizeServerUrl(serverUrl);

    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(normalizedUrl);
    } catch (e) {
      rethrow;
    }

    OdooClient client;
    if (!otp) {
      client = _newClient(normalizedUrl);
    } else {
      client = odooClient!;
    }

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        OdooSession odooSession;
        if (!otp) {
          odooSession = await _authenticateDetectingMfa(
            client,
            database,
            userLogin,
            password,
          );
          // A 2FA-enabled user gets a NEW client above (carrying the
          // pending-MFA session cookie) rather than mutating the existing
          // one, since OdooClient exposes no public session setter.
          client = _newClient(client.baseURL, sessionId: odooSession);
        } else {
          odooSession = client.sessionId!;
        }


        int? selectedCompanyId;
        List<int> allowedCompanyIds = [];

        if (autoLoadCompanies) {
          try {
            final userInfo = await _fetchUserCompanies(
              client,
              odooSession.userId,
            );

            // Only override if company 1 is actually allowed, otherwise keep 1 as default.
            final fetchedAllowed =
                (userInfo['company_ids'] as List?)?.cast<int>() ?? [];

            if (fetchedAllowed.contains(3)) {
              selectedCompanyId = userInfo['company_id'];
              allowedCompanyIds = fetchedAllowed;
            } else {
              selectedCompanyId = userInfo['company_id'] ?? 1;
              allowedCompanyIds = fetchedAllowed.isNotEmpty
                  ? fetchedAllowed
                  : [userInfo['company_id']];
            }
          } catch (e) {

          }
        }

        bool isStockUser = false;


        final sessionData = AppSessionData(
          odooSession: odooSession,
          password: password,
          serverUrl: normalizedUrl,
          database: database,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
          selectedCompanyId: selectedCompanyId,
          allowedCompanyIds: allowedCompanyIds,
          isStockUser: isStockUser,
        );

        await sessionData.saveToPrefs();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastServerUrl', normalizedUrl);
        await prefs.setString('lastDatabase', database);

        _client = client;
        _cachedSession = sessionData;
        _lastAuthTime = DateTime.now();

        ConnectivityService.instance.setCurrentServerUrl(normalizedUrl);
        _onSessionUpdated?.call(sessionData);

        return LoginStatus.success;
      } catch (e) {
        if (e is MfaRequiredException) {
          return LoginStatus.twoFactorEnabled;
        }

        // An expired database or a missing module is a verdict, not a
        // transient failure: don't retry it or fold it into "login failed".
        if (e is DatabaseExpiredException ||
            e is RequiredModulesMissingException) {
          rethrow;
        }

        if (e is FormatException && e.toString().contains('<html>')) {
          throw Exception(
            'Server returned HTML instead of JSON. Please check server URL and ensure Odoo is running.',
          );
        }

        // Don't retry credential errors
        if (e.toString().toLowerCase().contains('access denied') ||
            e.toString().toLowerCase().contains('wrong login/password') ||
            e.toString().toLowerCase().contains('invalid database')) {
          return LoginStatus.failed;
        }

        if (attempt < _maxRetries && _isRetryableError(e)) {
          final delay = _baseDelay * attempt;
          await Future.delayed(delay);
          continue;
        }

        if (e is NoInternetException || e is ServerUnreachableException) {
          rethrow;
        }
        return LoginStatus.failed;
      }
    }

    return LoginStatus.failed;
  }

  /// Fetch user's company information from Odoo
  static Future<Map<String, dynamic>> _fetchUserCompanies(
    OdooClient client,
    int userId,
  ) async {
    try {
      final result = await client.callKw({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [userId],
          ['company_id', 'company_ids'],
        ],
        'kwargs': {},
      });

      if (result is List && result.isNotEmpty) {
        final userData = result[0];

        // Extract company_id (can be int or [id, name])
        int? companyId;
        if (userData['company_id'] is int) {
          companyId = userData['company_id'];
        } else if (userData['company_id'] is List &&
            userData['company_id'].isNotEmpty) {
          companyId = userData['company_id'][0];
        }

        List<int> companyIds = [];
        if (userData['company_ids'] is List) {
          companyIds = (userData['company_ids'] as List)
              .map((e) => e is int ? e : null)
              .whereType<int>()
              .toList();
        }

        return {'company_id': companyId, 'company_ids': companyIds};
      }

      return {};
    } catch (e) {
      return {};
    }
  }

  /// Authenticates like [OdooClient.authenticate], but detects a pending
  /// 2FA challenge deterministically: Odoo returns a successful
  /// `{'uid': None}` result in that case, which [OdooClient.authenticate]
  /// doesn't special-case.
  static Future<OdooSession> _authenticateDetectingMfa(
    OdooClient client,
    String database,
    String login,
    String password,
  ) async {
    final uri = Uri.parse('${client.baseURL}/web/session/authenticate');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {'db': database, 'login': login, 'password': password},
        'id': DateTime.now().microsecondsSinceEpoch,
      }),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (decoded['error'] != null) {
      throw OdooException(decoded['error']);
    }

    final result = decoded['result'];
    if (result is! Map || result['uid'] == null) {
      throw MfaRequiredException();
    }

    final sessionInfo = Map<String, dynamic>.from(result);
    var session = OdooSession.fromSessionInfo(sessionInfo);

    // The real session id lives in the Set-Cookie header, not the JSON
    // body — mirrors OdooClient's own private cookie handling.
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final lookForCommaExpression = RegExp(r'(?<=)(,)(?=[^;]+?=)');
      for (final cookieStr in setCookie.split(lookForCommaExpression)) {
        try {
          final cookie = Cookie.fromSetCookieValue(cookieStr);
          if (cookie.name == 'session_id') {
            session = session.updateSessionId(cookie.value);
          }
        } catch (_) {}
      }
    }

    // Refuse an expired database here, before any caller can save the
    // session: this is the one point every password sign-in passes through.
    // The server's own clock (Date header) decides, not the device's.
    try {
      DatabaseExpiry.ensureActive(sessionInfo, now: _serverTime(response));
    } on DatabaseExpiredException {
      await discardServerSession(client.baseURL, session.id);
      rethrow;
    }

    // Likewise refuse a database without the Employee, Attendance or Time
    // Off modules: the app has nothing to show for it. Needs the session
    // just opened, so it can only run after the credentials were accepted.
    try {
      await RequiredModules.ensureInstalled(
        serverUrl: client.baseURL,
        sessionId: session.id,
      );
    } on RequiredModulesMissingException {
      await discardServerSession(client.baseURL, session.id);
      rethrow;
    }

    return session;
  }

  /// The server's current time from a response's `Date` header, or null.
  static DateTime? _serverTime(http.Response response) {
    final raw = response.headers['date'];
    if (raw == null) return null;
    try {
      return HttpDate.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Ends a server-side session that was opened but must not be used (an
  /// expired database), so no authenticated session is left behind. Best
  /// effort: the sign-in is already refused whether or not this succeeds.
  static Future<void> discardServerSession(
    String serverUrl,
    String sessionId,
  ) async {
    if (sessionId.isEmpty) return;
    try {
      await http
          .post(
            Uri.parse('$serverUrl/web/session/destroy'),
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
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Authenticate without saving (for account switching)
  static Future<AppSessionData?> authenticate({
    required String serverUrl,
    required String database,
    required String username,
    required String password,
  }) async {
    if (serverUrl.isEmpty || database.isEmpty || username.isEmpty) {
      throw Exception('Invalid authentication parameters');
    }

    if (password.isEmpty) {
      throw Exception('Empty password - account needs re-authentication');
    }

    String normalizedUrl = normalizeServerUrl(serverUrl);

    await ConnectivityService.instance.ensureInternetOrThrow();
    await ConnectivityService.instance.ensureServerReachable(normalizedUrl);

    final client = _newClient(normalizedUrl);

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final odooSession = await _authenticateDetectingMfa(
          client,
          database,
          username,
          password,
        );

        final sessionData = AppSessionData(
          odooSession: odooSession,
          password: password,
          serverUrl: normalizedUrl,
          database: database,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );

        _cachedSession = sessionData;
        ConnectivityService.instance.setCurrentServerUrl(normalizedUrl);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastServerUrl', normalizedUrl);
        await prefs.setString('lastDatabase', database);

        return sessionData;
      } catch (e) {
        if (e is DatabaseExpiredException ||
            e is RequiredModulesMissingException) {
          rethrow;
        }

        if (e is FormatException && e.toString().contains('<html>')) {
          throw Exception(
            'Server returned HTML instead of JSON. Please check server URL.',
          );
        }

        if (e.toString().toLowerCase().contains('access denied') ||
            e.toString().toLowerCase().contains('wrong login/password')) {
          throw e;
        }

        if (attempt < _maxRetries && _isRetryableError(e)) {
          final delay = _baseDelay * attempt;
          await Future.delayed(delay);
          continue;
        }

        throw e;
      }
    }

    throw Exception('Authentication failed after $_maxRetries attempts');
  }

  /// Update current session (for account switching)
  static Future<void> updateSession(AppSessionData newSession) async {
    _cachedSession = newSession;
    await newSession.saveToPrefs();

    _client = null;
    _lastAuthTime = null;

    ConnectivityService.instance.setCurrentServerUrl(newSession.serverUrl);
    _onSessionUpdated?.call(newSession);
  }

  /// Refresh expired session by re-authenticating
  static Future<bool> refreshSession() async {
    // Prevent concurrent refresh attempts
    if (_isRefreshing) {
      await Future.delayed(const Duration(milliseconds: 500));
      return await isSessionValid();
    }

    _isRefreshing = true;
    try {
      final session = await getCurrentSession();

      if (session == null) {
        throw StateError('No Odoo session available. Please login.');
      }

      try {
        await ConnectivityService.instance.ensureInternetOrThrow();
        await ConnectivityService.instance.ensureServerReachable(
          session.serverUrl,
        );

        final client = _newClient(session.serverUrl);
        final newOdooSession = await client.authenticate(
          session.database,
          session.userLogin,
          session.password,
        );

        _client = client;

        final refreshedSession = session.copyWith(
          odooSession: newOdooSession,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );

        _cachedSession = refreshedSession;
        _lastAuthTime = DateTime.now();
        await refreshedSession.saveToPrefs();
        _onSessionUpdated?.call(refreshedSession);

        ConnectivityService.instance.setCurrentServerUrl(
          refreshedSession.serverUrl,
        );

        return true;
      } on NoInternetException catch (e) {
        return false;
      } on ServerUnreachableException catch (e) {
        return false;
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// Get authenticated client (nullable version)
  static Future<OdooClient?> getClient() async {
    try {
      return await getClientEnsured();
    } catch (e) {
      return null;
    }
  }

  /// Get authenticated client (throws on error)
  /// Reuses existing client when valid, only re-authenticates when necessary
  static Future<OdooClient> getClientEnsured() async {
    final session = await getCurrentSession();
    if (session == null) {
      throw StateError('No Odoo session available. Please login.');
    }

    if (session.isExpired) {
      final refreshed = await refreshSession();
      if (!refreshed) {
        if (_client == null) {
          _client = _newClient(session.serverUrl);
        }
        return _client!;
      }
    }

    if (_client != null &&
        _lastAuthTime != null &&
        DateTime.now().difference(_lastAuthTime!) <
            _sessionCacheValidDuration) {
      return _client!;
    }

    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(
        session.serverUrl,
      );

      OdooClient client;
      final saved = await AppSessionData.fromPrefs();
      if (saved != null) {
        client = _newClient(session.serverUrl, sessionId: session.odooSession);
      } else {
        client = _newClient(session.serverUrl);

        for (int attempt = 1; attempt <= _maxRetries; attempt++) {
          try {
            await client.authenticate(
              session.database,
              session.userLogin,
              session.password,
            );
            break;
          } catch (e) {
            if (attempt >= _maxRetries || !_isRetryableError(e)) rethrow;
            final delay = _baseDelay * attempt;
            await Future.delayed(delay);
          }
        }
      }

      _client = client;
      _lastAuthTime = DateTime.now();

      final updatedSession = session.copyWith(
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );
      _cachedSession = updatedSession;
      await updatedSession.saveToPrefs();

      return client;
    } on NoInternetException {
      return _uncachedClient(session);
    } on ServerUnreachableException {
      return _uncachedClient(session);
    }
  }

  /// Client returned when the reachability probes fail: the request still
  /// gets to try with the saved session, since an on-premise server can be
  /// reachable without public internet, and if the server really is down
  /// the request fails and [callWithSession] reports it. Not stored in
  /// [_client], so it can't outlive the outage; it used to be stored
  /// without the session id, which turned every call after recovery into
  /// a "session expired" re-authentication.
  static OdooClient _uncachedClient(AppSessionData session) =>
      _newClient(session.serverUrl, sessionId: session.odooSession);

  /// Execute action with auto session refresh on auth errors.
  ///
  /// Connectivity failures (see [ConnectivityService.isConnectivityError])
  /// are rethrown as [NoInternetException] or [ServerUnreachableException]
  /// so screens can show a "can't reach the server" state instead of
  /// loading indefinitely.
  static Future<T> callWithSession<T>(
    Future<T> Function(OdooClient client) action,
  ) async {
    try {
      final result = await _callWithAuthRetry(action);
      ConnectivityService.instance.reportServerReachable(true);
      return result;
    } catch (e, stack) {
      if (!ConnectivityService.isConnectivityError(e)) rethrow;
      final mapped = await ConnectivityService.instance.toConnectivityException(
        e,
      );
      Error.throwWithStackTrace(mapped, stack);
    }
  }

  static Future<T> _callWithAuthRetry<T>(
    Future<T> Function(OdooClient client) action,
  ) async {
    final client = await getClientEnsured();

    try {
      return _normalizeBinaries(await action(client));
    } catch (e) {
      // Don't retry on connectivity issues
      if (ConnectivityService.isConnectivityError(e)) rethrow;

      if (_isAuthError(e)) {
        final refreshed = await refreshSession();
        if (refreshed) {
          final newClient = await getClientEnsured();
          return _normalizeBinaries(await action(newClient));
        } else {}
      }

      rethrow;
    }
  }

  /// Converts Odoo 20 binary maps in RPC results to base64 strings in place.
  static T _normalizeBinaries<T>(T result) {
    normalizeOdooBinaries(result);
    return result;
  }

  /// Safe wrapper for callKw with automatic company context injection
  /// This is the recommended method for all RPC calls to ensure proper multi-company support
  static Future<dynamic> safeCallKw(Map<String, dynamic> payload) {
    return callKwWithCompany(payload);
  }

  /// Safe wrapper for callKw WITHOUT company context injection
  /// Use this only for system-level calls that should not be company-filtered
  /// (e.g., fetching company list, user authentication, etc.)
  static Future<dynamic> safeCallKwWithoutCompany(
    Map<String, dynamic> payload,
  ) {
    return callWithSession((client) => client.callKw(payload));
  }

  /// Safe wrapper for callRPC
  static Future<dynamic> safeCallRPC(
    String path,
    String method,
    Map<String, dynamic> args,
  ) {
    return callWithSession((client) => client.callRPC(path, method, args));
  }

  /// Fetch the list of allowed companies (id, name) for the current user.
  /// This performs:
  /// 1) Read user's company_ids
  /// 2) search_read on res.company for id, name
  static Future<List<Map<String, dynamic>>> getAllowedCompaniesList() async {
    final client = await getClientEnsured();
    final session = await getCurrentSession();
    if (session == null) return [];

    final info = await _fetchUserCompanies(client, session.userId);
    final ids = (info['company_ids'] as List<int>? ?? []);
    if (ids.isEmpty) return [];

    // Use safeCallKwWithoutCompany since we're fetching company list itself
    final companiesRes = await safeCallKwWithoutCompany({
      'model': 'res.company',
      'method': 'search_read',
      'args': [
        [
          ['id', 'in', ids],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'name'],
        'order': 'name asc',
      },
    });

    if (companiesRes is List) {
      return companiesRes.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Convenience helper to retrieve companies and the currently selected company id
  /// for populating dropdowns.
  /// Returns a map: { 'companies': List<Map<String,dynamic>>, 'selectedCompanyId': int? }
  static Future<Map<String, dynamic>> getCompaniesForDropdown() async {
    final companies = await getAllowedCompaniesList();
    final selectedId = await getSelectedCompanyId();
    return {'companies': companies, 'selectedCompanyId': selectedId};
  }

  /// Make authenticated HTTP request with retry logic
  Future<http.Response> makeAuthenticatedRequest(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final session = await getCurrentSession();
    if (session == null) {
      throw Exception('No active Odoo session');
    }

    final headers = {
      'Cookie': 'session_id=${session.sessionId}',
      'Content-Type': 'application/json',
      'Accept':
          'application/pdf,application/octet-stream,application/json;q=0.9,*/*;q=0.8',
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': '${session.serverUrl}/web',
      'User-Agent': 'Mozilla/5.0 (Linux; Android) FlutterApp/1.0',
    };

    http.Response? lastResponse;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final uri = Uri.parse(url);
        final future = body != null
            ? http.post(uri, headers: headers, body: jsonEncode(body))
            : http.get(uri, headers: headers);
        final response = await future.timeout(const Duration(seconds: 20));

        final contentType = response.headers['content-type'] ?? '';
        final isHtml =
            contentType.contains('text/html') ||
            (response.bodyBytes.isNotEmpty &&
                String.fromCharCodes(
                  response.bodyBytes.take(64),
                ).toLowerCase().contains('<!doctype html'));

        if (isHtml && attempt < _maxRetries) {
          await refreshSession();
          final delay = _baseDelay * attempt;
          await Future.delayed(delay);
          continue;
        }

        if ([502, 503, 504].contains(response.statusCode) &&
            attempt < _maxRetries) {
          lastResponse = response;
          final delay = _baseDelay * attempt;
          await Future.delayed(delay);
          continue;
        }

        return response;
      } catch (e) {
        if (attempt >= _maxRetries || !_isRetryableError(e)) rethrow;
        final delay = _baseDelay * attempt;
        await Future.delayed(delay);
      }
    }

    if (lastResponse != null) return lastResponse;
    throw Exception('Request to $url failed after $_maxRetries attempts');
  }

  /// Get selected company ID from current session or preferences
  static Future<int?> getSelectedCompanyId() async {
    // First check if we have it in the cached session
    final session = await getCurrentSession();
    if (session?.companyId != null) {
      return session!.companyId;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('selected_company_id');
    } catch (_) {
      return null;
    }
  }

  /// Get selected allowed company IDs from current session or preferences
  static Future<List<int>> getSelectedAllowedCompanyIds() async {
    // First check if we have it in the cached session
    final session = await getCurrentSession();
    if (session != null && session.allowedCompanyIds.isNotEmpty) {
      return session.allowedCompanyIds;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('selected_allowed_company_ids') ?? [];
      return raw.map((e) => int.tryParse(e) ?? -1).where((e) => e > 0).toList();
    } catch (_) {
      return [];
    }
  }

  /// Update company selection in current session
  static Future<void> updateCompanySelection({
    required int companyId,
    required List<int> allowedCompanyIds,
  }) async {
    final session = await getCurrentSession();
    if (session == null) {
      return;
    }

    List<int> finalAllowedIds = [...allowedCompanyIds];
    if (!finalAllowedIds.contains(companyId)) {
      finalAllowedIds.add(companyId);
    }

    final updatedSession = session.copyWith(
      selectedCompanyId: companyId,
      allowedCompanyIds: finalAllowedIds,
    );

    _cachedSession = updatedSession;
    await updatedSession.saveToPrefs();

    _onSessionUpdated?.call(updatedSession);
  }

  /// Clear company selection from session
  static Future<void> clearCompanySelection() async {
    final session = await getCurrentSession();
    if (session == null) return;

    final updatedSession = session.copyWith(
      selectedCompanyId: null,
      allowedCompanyIds: [],
    );

    _cachedSession = updatedSession;
    await updatedSession.saveToPrefs();

    _onSessionUpdated?.call(updatedSession);
  }

  /// The `allowed_company_ids` to send: [allowed] without duplicates, with
  /// [active] included (added last when missing) and, when [activeFirst],
  /// moved to the front, where Odoo reads the current company from.
  static List<int> orderAllowedCompanies(
    List<int> allowed,
    int active, {
    required bool activeFirst,
  }) {
    final ids = <int>[...allowed];
    if (!ids.contains(active)) ids.add(active);
    if (activeFirst) {
      ids
        ..remove(active)
        ..insert(0, active);
    }
    return <int>{...ids}.toList();
  }

  /// Call Odoo method with company context
  /// Automatically injects company_id and allowed_company_ids into the request context
  ///
  /// Odoo's current company (`env.company`) is the FIRST entry of
  /// `allowed_company_ids`, and per-user data such as "my employee" is
  /// resolved against it. The saved list keeps companies in the order they
  /// were ticked, with the active one often last, so a call that reads the
  /// user's own records (their time off balance, say) should pass
  /// [activeCompanyFirst] or it gets the data of whichever company happens
  /// to head the list — typically none.
  static Future<dynamic> callKwWithCompany(
    Map<String, dynamic> payload, {
    int? companyId,
    List<int>? allowedCompanyIds,
    bool activeCompanyFirst = false,
  }) async {
    final map = Map<String, dynamic>.from(payload);

    Map<String, dynamic> kwargs = {};
    final rawKwargs = map['kwargs'];
    if (rawKwargs is Map) {
      kwargs = rawKwargs.map((key, value) => MapEntry(key.toString(), value));
    }

    Map<String, dynamic> ctx = {};
    final rawCtx = kwargs['context'];
    if (rawCtx is Map) {
      ctx = rawCtx.map((key, value) => MapEntry(key.toString(), value));
    }

    int? selectedCompany = companyId;
    List<int>? allowed = allowedCompanyIds;

    if (selectedCompany == null || allowed == null) {
      final session = await getCurrentSession();
      selectedCompany ??= session?.companyId ?? await getSelectedCompanyId();
      allowed ??= session?.allowedCompanyIds.isNotEmpty == true
          ? session!.allowedCompanyIds
          : await getSelectedAllowedCompanyIds();
    }

    if (selectedCompany != null) {
      ctx['company_id'] = selectedCompany;

      ctx['allowed_company_ids'] = orderAllowedCompanies(
        allowed ?? const [],
        selectedCompany,
        activeFirst: activeCompanyFirst,
      );
    }

    kwargs['context'] = ctx;
    map['kwargs'] = kwargs;

    return callWithSession((client) => client.callKw(map));
  }

  /// Logout and clear session. Each step is isolated in its own try/catch
  /// so a failure in one (e.g. secure storage) never skips the rest,
  /// particularly clearing `isLoggedIn`.
  static Future<void> logout() async {
    try {
      final session = _cachedSession ?? await getCurrentSession();
      if (session?.userId != null) {
        await SecureStorageService.instance.deletePassword(
          'session_password_${session!.userId}',
        );
      }
    } catch (_) {}

    _client = null;
    _cachedSession = null;
    _isRefreshing = false;
    _lastAuthTime = null;

    try {
      await clearAccountScopedState();
    } catch (_) {}

    ConnectivityService.instance.setCurrentServerUrl(null);

    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in accountScopedPrefKeys) {
        await prefs.remove(key);
      }
    } catch (_) {}

    _onSessionCleared?.call();
  }

  /// Preference keys that belong to ONE logged-in account and must never
  /// outlive it (includes pending offline edits and per-server caches).
  static const List<String> accountScopedPrefKeys = [
    'sessionId',
    'userLogin',
    'database',
    'serverUrl',
    'userId',
    'expiresAt',
    'isLoggedIn',
    'selected_company_id',
    'selected_allowed_company_ids',
    'pending_company_id',
    'user_profile',
    'user_profile_pending_users',
    'user_profile_pending_partner',
    'user_profile_hr_fields',
  ];

  /// Drops every trace of the outgoing account that isn't the session
  /// itself — call before activating a different account (the session keys
  /// are overwritten by the incoming account's own save).
  static Future<void> clearAccountScopedState() async {
    OdooMetadataService.reset();

    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in const [
        'pending_company_id',
        'user_profile',
        'user_profile_pending_users',
        'user_profile_pending_partner',
        'user_profile_hr_fields',
      ]) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  static int _parseMajorVersionStatic(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) return int.tryParse(match.group(0)!) ?? 0;
    return 0;
  }

  /// The connected server's major Odoo version (17, 18, 19, ...), parsed
  /// from the active session's `server_version`. Returns 0 when there's no
  /// active session or the version string can't be parsed -- callers should
  /// treat that as "unknown", not as a specific version.
  static Future<int> getServerMajorVersion() async {
    final session = await getCurrentSession();
    final version = session?.odooSession.serverVersion;
    if (version == null || version.isEmpty) return 0;
    return _parseMajorVersionStatic(version);
  }

  /// Clear cached client
  static void clearClientCache() {
    _client = null;
    _lastAuthTime = null;
  }

  /// Get last used server URL
  static Future<String?> getLastServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastServerUrl');
  }

  /// Get last used database
  static Future<String?> getLastDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastDatabase');
  }

  /// Set last server info
  static Future<void> setLastServerInfo({
    required String serverUrl,
    required String database,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastServerUrl', serverUrl);
    await prefs.setString('lastDatabase', database);
  }

  static Future<void> saveSessionFromExistingSession(
    OdooClient client,
    OdooSession session,
    String serverUrl,
    String password,
  ) async {
    // Normalize so the same server can't be saved under differently
    // formatted URLs across login paths.
    serverUrl = normalizeServerUrl(serverUrl);

    final sessionData = AppSessionData(
      odooSession: session,
      password: password,
      serverUrl: serverUrl,
      database: session.dbName,
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      selectedCompanyId: session.companyId,
      isStockUser: false,
      allowedCompanyIds: session.allowedCompanies.map((s) => s.id).toList(),
    );

    await sessionData.saveToPrefs();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastServerUrl', serverUrl);
    await prefs.setString('lastDatabase', session.dbName);

    _client = client;
    _cachedSession = sessionData;
    _lastAuthTime = DateTime.now();

    ConnectivityService.instance.setCurrentServerUrl(serverUrl);
    _onSessionUpdated?.call(sessionData);
  }
}
