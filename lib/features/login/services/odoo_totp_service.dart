import 'dart:convert';

import 'package:http/http.dart' as http;

/// Outcome of a two-factor verification attempt.
class TotpVerifyResult {
  /// True only when Odoo finalized the session (MFA passed server-side).
  final bool success;

  /// The *rotated* session id. Odoo calls `Session.finalize()` on a
  /// successful code, which sets `should_rotate = True`, so the session id
  /// after 2FA is NOT the same one the password step handed us — this is
  /// the one that must be persisted and used for all later RPC calls.
  final String? sessionId;

  /// `/web/session/get_session_info` payload for the finalized session,
  /// ready to hand to `LoginProvider.onLoginSuccessFromSession`.
  final Map<String, dynamic>? sessionInfo;

  /// Odoo's own rendered rejection text when it refuses the code (wrong
  /// code, expired/rate-limited, bad format), or our own message for
  /// transport-level problems.
  final String? errorMessage;

  /// True when Odoo actively rejected the code (so the user should retry
  /// with a fresh code), as opposed to a network/parse failure.
  final bool codeRejected;

  const TotpVerifyResult._({
    required this.success,
    this.sessionId,
    this.sessionInfo,
    this.errorMessage,
    this.codeRejected = false,
  });

  factory TotpVerifyResult.ok({
    required String sessionId,
    required Map<String, dynamic> sessionInfo,
  }) =>
      TotpVerifyResult._(
        success: true,
        sessionId: sessionId,
        sessionInfo: sessionInfo,
      );

  factory TotpVerifyResult.rejected(String message) => TotpVerifyResult._(
        success: false,
        errorMessage: message,
        codeRejected: true,
      );

  factory TotpVerifyResult.failed(String message) => TotpVerifyResult._(
        success: false,
        errorMessage: message,
      );
}

/// Drives Odoo's two-factor (TOTP) login entirely over HTTP, with no
/// embedded browser. Matches Odoo's own `/web/login/totp` form fields and
/// `/web/session/authenticate` contract, which are stable across Odoo
/// 17-19: all three return `{'uid': None}` (not an error) with a
/// `pre_uid`-bearing `session_id` cookie when 2FA is required — that
/// cookie is the handle this whole flow is built on.
class OdooTotpService {
  final http.Client _client;

  OdooTotpService({http.Client? client}) : _client = client ?? http.Client();

  void dispose() => _client.close();

  static String _base(String serverUrl) {
    var url = serverUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Pulls `session_id` out of a response's Set-Cookie header(s). Matches
  /// by name rather than splitting on commas, since cookie attributes
  /// (e.g. `Expires=Wed, 21 Oct ...`) can legitimately contain them.
  static String? _sessionIdFrom(http.BaseResponse response) {
    final raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'session_id=([^;,\s]+)').firstMatch(raw);
    final value = match?.group(1);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// Odoo renders the CSRF token as
  /// `<input type="hidden" name="csrf_token" value="..."/>`. Locate that
  /// specific tag first, then read its `value`, so attribute order can't
  /// break the match.
  static String? _csrfTokenFrom(String html) {
    final tag = RegExp(
      r'<input[^>]*name="csrf_token"[^>]*>',
      caseSensitive: false,
    ).firstMatch(html)?.group(0);
    if (tag == null) return null;
    return RegExp(r'value="([^"]*)"').firstMatch(tag)?.group(1);
  }

  /// Reads Odoo's own rejection text out of the re-rendered form, so the
  /// user sees the real reason (wrong code vs. rate-limited vs. bad
  /// format) instead of one guessed message.
  static String? _errorFrom(String html) {
    final match = RegExp(
      r'alert-danger[^>]*>(.*?)</p>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    final inner = match?.group(1);
    if (inner == null) return null;
    final text = inner.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return text.isEmpty ? null : text;
  }

  /// Binds a fresh session to [database] the same way a browser does (via
  /// `/web/login`'s `ensure_db()`). Needed on multi-database servers: the
  /// 2FA path never sets `session.db` itself, and Odoo doesn't read `?db=`
  /// during normal dispatch. Returns null if the server issued no cookie;
  /// callers proceed without one (fine on single-database servers).
  Future<String?> _primeSessionDatabase({
    required String base,
    required String database,
  }) async {
    try {
      final uri = Uri.parse('$base/web/login?db=$database');
      final request = http.Request('GET', uri)
        // ensure_db() answers with a redirect that carries the new
        // session cookie; following it would hide that response's headers.
        ..followRedirects = false
        ..headers.addAll(const {'ngrok-skip-browser-warning': 'true'});
      final response =
          await http.Response.fromStream(await _client.send(request));
      return _sessionIdFrom(response);
    } catch (e) {
      return null;
    }
  }

  /// Step 1 — password step. Establishes the MFA-pending session and
  /// returns its `session_id`, or null if the server never handed one out.
  ///
  /// A 2FA-enabled account yields `result.uid == null` here by design (see
  /// the class docs); that is the expected, successful outcome for this
  /// step, not an error.
  Future<String?> startMfaSession({
    required String serverUrl,
    required String database,
    required String username,
    required String password,
  }) async {
    final base = _base(serverUrl);
    final primedSessionId =
        await _primeSessionDatabase(base: base, database: database);

    final uri = Uri.parse('$base/web/session/authenticate');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        // Inert against normal Odoo hosts; skips the interstitial an
        // ngrok tunnel would otherwise serve in place of Odoo's response
        // when the server URL points at a dev tunnel.
        'ngrok-skip-browser-warning': 'true',
        if (primedSessionId != null) 'Cookie': 'session_id=$primedSessionId',
      },
      body: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'db': database,
          'login': username,
          'password': password,
        },
      }),
    );

    // Prefer whatever cookie this response carries, since storing
    // `pre_uid` marks the session dirty and Odoo re-issues it; fall back to
    // the primed one when the response repeats no cookie.
    final sessionId = _sessionIdFrom(response) ?? primedSessionId;
    return sessionId;
  }

  /// GETs `/web/login/totp` and scrapes its CSRF token. Null when the form
  /// wasn't rendered (a redirect, an error page, or unparseable markup).
  Future<String?> _fetchCsrfToken({
    required Uri totpUri,
    required String cookieHeader,
  }) async {
    try {
      final request = http.Request('GET', totpUri)
        ..followRedirects = false
        ..headers.addAll({
          'Cookie': cookieHeader,
          'ngrok-skip-browser-warning': 'true',
        });
      final response =
          await http.Response.fromStream(await _client.send(request));
      if (response.statusCode >= 300) return null;
      return _csrfTokenFrom(response.body);
    } catch (e) {
      return null;
    }
  }

  /// POSTs the code the same way Odoo's own form does. Null on a transport
  /// failure (as opposed to any HTTP response, which is returned as-is).
  Future<http.Response?> _postCode({
    required Uri totpUri,
    required String cookieHeader,
    required String csrfToken,
    required String code,
    required bool rememberDevice,
  }) async {
    try {
      final request = http.Request('POST', totpUri)
        // Success is a 303 to the authenticated landing page, and that
        // response carries the rotated session cookie — following it
        // silently would discard it, so handle the redirect ourselves.
        ..followRedirects = false
        ..headers.addAll({
          'Cookie': cookieHeader,
          'ngrok-skip-browser-warning': 'true',
        })
        ..bodyFields = {
          'csrf_token': csrfToken,
          'totp_token': code,
          if (rememberDevice) 'remember': '1',
          'redirect': '',
        };
      return await http.Response.fromStream(await _client.send(request));
    } catch (e) {
      return null;
    }
  }

  /// Returns session_info when [sessionId] is a fully logged-in session,
  /// or null otherwise (including when Odoo rejects the call because the
  /// session is still MFA-pending — `get_session_info` is an `auth='user'`
  /// route, so a pending session errors there rather than answering).
  Future<Map<String, dynamic>?> _sessionInfoIfAuthenticated({
    required String serverUrl,
    required String sessionId,
  }) async {
    try {
      final info = await fetchSessionInfo(
        serverUrl: serverUrl,
        sessionId: sessionId,
      );
      final uid = info['uid'];
      if (uid == null || uid == false) return null;
      return info;
    } catch (_) {
      return null;
    }
  }

  /// Steps 2 & 3 — fetch a CSRF token bound to [sessionId], then post the
  /// code to `/web/login/totp` exactly as Odoo's own form does.
  Future<TotpVerifyResult> verifyCode({
    required String serverUrl,
    required String database,
    required String sessionId,
    required String code,
    bool rememberDevice = false,
  }) async {
    final base = _base(serverUrl);
    final totpUri = Uri.parse('$base/web/login/totp');
    final cookieHeader = 'session_id=$sessionId';

    // ── Step 2: GET the form for a CSRF token tied to this session ──────
    // Odoo derives the token from the session id, so it has to come from a
    // request made on *this* session.
    String? csrfToken = await _fetchCsrfToken(
      totpUri: totpUri,
      cookieHeader: cookieHeader,
    );
    if (csrfToken == null) {
      // Form wasn't rendered — usually a lost/expired session, but the
      // session could also already be finalized, so confirm with Odoo first.
      final recovered = await _sessionInfoIfAuthenticated(
        serverUrl: serverUrl,
        sessionId: sessionId,
      );
      if (recovered != null) {
        return TotpVerifyResult.ok(
          sessionId: sessionId,
          sessionInfo: recovered,
        );
      }
      return TotpVerifyResult.failed(
        'Your login session expired before the code could be verified. '
        'Please sign in again.',
      );
    }

    // ── Step 3: POST the code ───────────────────────────────────────────
    var postResponse = await _postCode(
      totpUri: totpUri,
      cookieHeader: cookieHeader,
      csrfToken: csrfToken,
      code: code,
      rememberDevice: rememberDevice,
    );

    // A rejected CSRF token comes back as 400, not a wrong code -- retry
    // once with a fresh token before surfacing anything.
    if (postResponse != null && postResponse.statusCode == 400) {
      csrfToken = await _fetchCsrfToken(
        totpUri: totpUri,
        cookieHeader: cookieHeader,
      );
      if (csrfToken != null) {
        postResponse = await _postCode(
          totpUri: totpUri,
          cookieHeader: cookieHeader,
          csrfToken: csrfToken,
          code: code,
          rememberDevice: rememberDevice,
        );
      }
    }

    if (postResponse == null) {
      return TotpVerifyResult.failed(
        'Could not reach the server. Please check your connection and try again.',
      );
    }

    final status = postResponse.statusCode;
    final isRedirect = status >= 300 && status < 400;

    if (!isRedirect) {
      if (status == 400) {
        return TotpVerifyResult.failed(
          'The login session expired before the code could be verified. '
          'Please sign in again.',
        );
      }
      // Odoo re-rendered the form, which it only does when it refused the
      // code (wrong/expired code, bad format, or the per-user verification
      // rate limit). Surface its own wording.
      final odooError = _errorFrom(postResponse.body);
      return TotpVerifyResult.rejected(
        odooError ?? 'Invalid authentication code. Please try again.',
      );
    }

    // A redirect back to the login page means the session was lost, not
    // verified. Compare the path exactly (not `.contains`): portal users'
    // own success redirect is "/web/login_successful", which would
    // otherwise match a "/web/login" substring check.
    final location = postResponse.headers['location'] ?? '';
    final locationPath = Uri.tryParse(location)?.path ?? location;
    if (locationPath == '/web/login' || locationPath == '/web/login/') {
      return TotpVerifyResult.failed(
        'Your login session expired before the code could be verified. '
        'Please sign in again.',
      );
    }

    // Success. `finalize()` rotated the session, so prefer the new cookie
    // and only fall back to the pre-MFA one if the server didn't send one.
    final finalSessionId = _sessionIdFrom(postResponse) ?? sessionId;

    // ── Step 4: confirm with Odoo that the session is really logged in ──
    // `uid` is only a real user id once MFA has actually passed
    // server-side, which makes it the authoritative success signal —
    // unlike the mere presence of a session cookie, which is already true
    // while 2FA is still pending.
    try {
      final sessionInfo = await fetchSessionInfo(
        serverUrl: serverUrl,
        sessionId: finalSessionId,
      );
      final uid = sessionInfo['uid'];
      if (uid == null || uid == false) {
        return TotpVerifyResult.rejected(
          'Invalid authentication code. Please try again.',
        );
      }
      return TotpVerifyResult.ok(
        sessionId: finalSessionId,
        sessionInfo: sessionInfo,
      );
    } catch (e) {
      return TotpVerifyResult.failed(
        'Signed in, but could not load your session. Please try again.',
      );
    }
  }

  /// `/web/session/get_session_info` for [sessionId].
  Future<Map<String, dynamic>> fetchSessionInfo({
    required String serverUrl,
    required String sessionId,
  }) async {
    final uri = Uri.parse('${_base(serverUrl)}/web/session/get_session_info');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Cookie': 'session_id=$sessionId',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': const {},
      }),
    );

    final decoded = jsonDecode(response.body);
    final result = decoded is Map ? decoded['result'] : null;
    if (result == null) {
      throw Exception('Failed to fetch session info');
    }
    return Map<String, dynamic>.from(result as Map);
  }
}
