import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_employees/app/app_entry.dart';
import 'package:mobo_employees/shared/providers/clear_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/login_provider.dart';
import '../services/odoo_totp_service.dart';

/// Two-factor (TOTP) step of login. Talks to Odoo's `/web/login/totp`
/// endpoint over plain HTTP via [OdooTotpService].
class TotpPage extends StatefulWidget {
  final String serverUrl;
  final String database;
  final String username;
  final String password;
  final String protocol;

  /// Whether this TOTP challenge belongs to an "add account" / "switch
  /// account" flow, which needs providers wiped before landing on [AppEntry].
  final bool addaccount;

  const TotpPage({
    super.key,
    required this.serverUrl,
    required this.database,
    required this.username,
    required this.password,
    required this.protocol,
    this.addaccount = false,
  });

  @override
  State<TotpPage> createState() => _TotpPageState();
}

class _TotpPageState extends State<TotpPage> {
  final _totpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _totpService = OdooTotpService();

  String? _error;
  bool _verifying = false;
  bool _isButtonEnabled = false;

  /// The MFA-pending `session_id` from the password step. Odoo requires the
  /// code to be posted on the *same* session that holds `pre_uid`, so this
  /// is established once up front and reused for each attempt.
  String? _pendingSessionId;
  Future<String?>? _pendingSessionFuture;

  @override
  void initState() {
    super.initState();
    /// Warm the pending session in the background so the first Authenticate
    /// press doesn't pay for it. Failures here are retried silently when
    /// the user submits a code, in _ensurePendingSession.
    _pendingSessionFuture = _startPendingSession();
  }

  Future<String?> _startPendingSession() async {
    try {
      final sessionId = await _totpService.startMfaSession(
        serverUrl: widget.serverUrl,
        database: widget.database,
        username: widget.username,
        password: widget.password,
      );
      _pendingSessionId = sessionId;
      return sessionId;
    } catch (e) {
      return null;
    }
  }

  /// Returns a usable MFA-pending session id, retrying the password step
  /// once if the warm-up in initState didn't produce one.
  Future<String?> _ensurePendingSession() async {
    if (_pendingSessionId != null) return _pendingSessionId;

    final warmed = await (_pendingSessionFuture ?? _startPendingSession());
    if (warmed != null) return warmed;

    /// Retry once — the warm-up may have raced app start or a brief
    /// connectivity blip.
    _pendingSessionFuture = _startPendingSession();
    return _pendingSessionFuture;
  }

  /// Drops the pending session so the next attempt re-runs the password
  /// step. Both the id and the cached future must be cleared, or
  /// [_ensurePendingSession] would hand back the discarded session.
  void _invalidatePendingSession() {
    _pendingSessionId = null;
    _pendingSessionFuture = null;
  }

  Future<void> _submitTotp() async {
    if (_verifying) return;

    final totp = _totpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(totp)) {
      setState(() => _error = 'Please enter a valid 6-digit code');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final sessionId = await _ensurePendingSession();
      if (!mounted) return;

      if (sessionId == null) {
        setState(() {
          _error =
              'Could not reach the server. Please check your connection and try again.';
        });
        return;
      }

      final result = await _totpService.verifyCode(
        serverUrl: widget.serverUrl,
        database: widget.database,
        sessionId: sessionId,
        code: totp,
      );
      if (!mounted) return;

      if (!result.success) {
        /// A rejected code leaves the session usable (Odoo only rotates it
        /// on success); any other failure means it can't be trusted.
        if (!result.codeRejected) _invalidatePendingSession();
        setState(() {
          _error = result.errorMessage ??
              'Invalid authentication code. Please try again.';
        });
        return;
      }

      await _finalizeLogin(
        sessionId: result.sessionId!,
        sessionInfo: result.sessionInfo!,
      );
      if (!mounted) return;

      if (widget.addaccount) {
        await ClearProviders.clearAllProviders(context);
        if (!mounted) return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppEntry()),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Authentication failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Persists the verified session and hands it to [LoginProvider], which
  /// stores/switches the account exactly as it does for a fresh password
  /// login.
  Future<void> _finalizeLogin({
    required String sessionId,
    required Map<String, dynamic> sessionInfo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sessionId', sessionId);
    await prefs.setString('username', widget.username);
    await prefs.setString('url', widget.serverUrl);
    await prefs.setString('database', widget.database);
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt(
        'loginTimestamp', DateTime.now().millisecondsSinceEpoch);

    if (!mounted) return;
    await context.read<LoginProvider>().onLoginSuccessFromSession(
          sessionInfo,
          login: widget.username,
          password2: widget.password,
          serverUrls: widget.serverUrl,
          databses: widget.database,
          sessionId: sessionId,
        );
  }

  @override
  void dispose() {
    _totpController.dispose();
    _totpService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[950] : Colors.grey[50],
                  image: DecorationImage(
                    image: const AssetImage('assets/images/loginbg.png'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      isDark ? Colors.black : Colors.white,
                      BlendMode.dstATop,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                ignoring: _verifying,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      height: 64,
                      width: 64,
                      alignment: Alignment.center,
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        color: _verifying ? Colors.white54 : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const HugeIcon(
          icon: HugeIcons.strokeRoundedTwoFactorAccess,
          color: Colors.white,
          size: 48,
        ),
        const SizedBox(height: 24),
        Text(
          'Two-factor Authentication',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 25,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'To login, enter below the six-digit authentication code provided by your Authenticator app.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.white70,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.serverUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Server: ${widget.serverUrl}',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.white60,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _totpController,
            keyboardType: TextInputType.number,
            enabled: !_verifying,
            cursorColor: Colors.black,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'TOTP is required';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _isButtonEnabled = value.trim().isNotEmpty;
                _formKey.currentState?.validate();
                if (_error != null) _error = null;
              });
            },
            decoration: InputDecoration(
              hintText: 'Enter TOTP Code',
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black.withOpacity(.4),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child:
                    HugeIcon(icon: HugeIcons.strokeRoundedSmsCode, size: 20),
              ),
              prefixIconColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? Colors.black26
                    : Colors.black54,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              errorStyle: const TextStyle(color: Colors.white),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red[900]!, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _error != null ? 48 : 0,
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedAlertCircle,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed:
                  (_verifying || !_isButtonEnabled) ? null : _submitTotp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black.withOpacity(0.2),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _verifying
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Authenticating',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        LoadingAnimationWidget.staggeredDotsWave(
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    )
                  : Text(
                      'Authenticate',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
