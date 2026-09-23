import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../models/appsession.dart';
import '../utils/server_url_utils.dart';
import 'connectivity_service.dart';
import 'odoo_session_manager.dart';
import 'secure_storage_service.dart';

class SessionService extends ChangeNotifier {
  static final SessionService instance = SessionService._internal();
  factory SessionService() => instance;
  SessionService._internal();

  /// Changes in switching account 2FA
  bool _isServerUnreachable = false;
  bool get isServerUnreachable => _isServerUnreachable;

  /// Till here 2FA

  AppSessionData? _currentSession;
  bool _isInitialized = false;
  List<Map<String, dynamic>> _storedAccounts = [];

  AppSessionData? get currentSession => _currentSession;
  bool get isInitialized => _isInitialized;
  bool get hasValidSession => _currentSession != null;
  List<Map<String, dynamic>> get storedAccounts => _storedAccounts;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    /// Set up session callbacks
    OdooSessionManager.setSessionCallbacks(
      onSessionUpdated: (sessionModel) {
        updateSession(sessionModel);
      },
      onSessionCleared: () {
        clearSession();
      },
    );

    /// Load current session
    _currentSession = await OdooSessionManager.getCurrentSession();

    /// Load stored accounts
    await _loadStoredAccounts();

    /// Migrate passwords from SharedPreferences to secure storage
    await _migratePasswordsToSecureStorage();

    /// Auto-store current session if not already stored
    if (_currentSession != null) {
      await _autoStoreCurrentSession();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Changes in switching account 2FA
  void setServerUnreachable(bool unreachable) {
    if (_isServerUnreachable != unreachable) {
      _isServerUnreachable = unreachable;
      notifyListeners();
    }
  }

  Future<void> checkConnectivity() async {
    if (_currentSession == null) return;
    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(
        _currentSession!.serverUrl,
      );
      setServerUnreachable(false);
    } catch (e) {
      setServerUnreachable(true);
    }
  }

  /// Till here 2FA

  void updateSession(AppSessionData newSession) {
    _currentSession = newSession;
    notifyListeners();
  }

  void clearSession() {
    _currentSession = null;
    notifyListeners();
  }

  /// Each step is isolated so a failure in one can never skip [clearSession].
  /// Clears all stored accounts/passwords but leaves the remembered server
  /// URL/database history alone, so the sign-in screen keeps it pre-filled.
  Future<void> logout() async {
    try {
      /// Clear the session on the backend
      await OdooSessionManager.logout();
    } catch (e) {}

    try {
      /// Clear stored accounts for privacy
      await _clearStoredAccountsData();
    } catch (e) {}

    try {
      /// Clear password caches
      await _clearPasswordCaches();
    } catch (e) {}

    /// Clear session service state
    clearSession();
  }

  /// Account management methods

  Future<void> _loadStoredAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> storedAccountsJson =
          prefs.getStringList('stored_accounts') ?? [];

      _storedAccounts = storedAccountsJson
          .map((json) {
            try {
              final decoded = Map<String, dynamic>.from(jsonDecode(json));
              return decoded;
            } catch (e) {
              return null;
            }
          })
          .where((account) => account != null)
          .cast<Map<String, dynamic>>()
          .toList();

      /// Clean up any duplicate accounts
      await _cleanupDuplicateAccounts();

      notifyListeners();
    } catch (e) {
      _storedAccounts = [];
    }
  }

  Future<void> _autoStoreCurrentSession() async {
    if (_currentSession == null) return;

    /// Check if current session is already stored
    final currentExists = _storedAccounts.any(
      (account) =>
          account['userId'] == _currentSession!.userId.toString() &&
          account['serverUrl'] == _currentSession!.serverUrl &&
          account['database'] == _currentSession!.database,
    );

    if (!currentExists) {
      await storeAccount(
        _currentSession!,
        '',
      ); /// Store with empty password initially
    }
  }

  Future<void> _cleanupDuplicateAccounts() async {
    final uniqueAccounts = <String, Map<String, dynamic>>{};

    for (final account in _storedAccounts) {
      final userId = account['userId']?.toString() ?? '';
      /// Normalize so accounts stored before normalization existed still merge.
      final serverUrl = normalizeServerUrl(account['serverUrl']?.toString() ?? '');
      final database = account['database']?.toString() ?? '';

      if (userId.isEmpty || serverUrl.isEmpty || database.isEmpty) {
        continue;
      }

      final key = '${userId}_${serverUrl}_$database';

      if (!uniqueAccounts.containsKey(key)) {
        uniqueAccounts[key] = account;
      } else {
        final existing = uniqueAccounts[key]!;
        final currentHasPassword =
            account['password']?.toString().isNotEmpty == true;
        final existingHasPassword =
            existing['password']?.toString().isNotEmpty == true;

        if (currentHasPassword && !existingHasPassword) {
          uniqueAccounts[key] = account;
        }
      }
    }

    final originalCount = _storedAccounts.length;
    _storedAccounts = uniqueAccounts.values.toList();

    if (_storedAccounts.length != originalCount) {
      await _saveStoredAccountsWithRetry();
    }
  }

  Future<void> storeAccount(
    AppSessionData session,
    String password, {
    bool markAsCurrent = true,
  }) async {
    try {
      String? imageBase64;
      String userDisplayName = session.userLogin;

      /// Try to fetch user details including image
      try {
        /// Isolated client scoped to this session, not the shared/global
        /// client which may be authenticated as a different account.
        final client = OdooClient(
          session.serverUrl,
          sessionId: session.odooSession,
        );

        final userDetails = await client.callKw({
          'model': 'res.users',
          'method': 'read',
          'args': [
            [session.userId],
            ['name', 'image_1920'],
          ],
          'kwargs': {},
        });

        if (userDetails is List && userDetails.isNotEmpty) {
          final user = userDetails.first as Map;
          final n = user['name'];
          if (n != null && n != false) {
            userDisplayName = n.toString();
          }
          final img = user['image_1920'];
          if (img != null && img != false) {
            imageBase64 = img.toString();
          }
        }
      } catch (e) {}

      /// `url` and `serverUrl` share the same normalized value so this
      /// record stays consistent with dedup/comparison logic elsewhere.
      final normalizedUrl = normalizeServerUrl(session.serverUrl);

      /// Create account data (WITHOUT password - stored securely)
      final accountData = {
        'id': session.userId.toString(),
        'name': userDisplayName,
        'email': session.userLogin,
        'url': normalizedUrl,
        'database': session.database,
        'username': session.userLogin,
        'isCurrent': markAsCurrent,
        'lastLogin': DateTime.now().toIso8601String(),
        'imageBase64': imageBase64?.isNotEmpty == true ? imageBase64 : null,
        /// Keep compatibility fields
        'userId': session.userId.toString(),
        'userName': userDisplayName,
        'serverUrl': normalizedUrl,
        /// DON'T store password here - use secure storage
        'sessionId': session.sessionId,
      };

      /// Mark all other accounts as not current only if this account is being marked as current
      if (markAsCurrent) {
        for (var account in _storedAccounts) {
          account['isCurrent'] = false;
        }
      }

      /// Check if account already exists (same normalization as
      /// `_cleanupDuplicateAccounts`'s dedup key).
      final existingIndex = _storedAccounts.indexWhere(
        (account) =>
            account['userId']?.toString() == accountData['userId'] &&
            normalizeServerUrl(account['serverUrl']?.toString() ?? '') == normalizedUrl &&
            account['database'] == accountData['database'],
      );

      if (existingIndex != -1) {
        _storedAccounts[existingIndex] = accountData;
      } else {
        _storedAccounts.insert(0, accountData);
      }

      await _cleanupDuplicateAccounts();
      await _saveStoredAccountsWithRetry();

      /// Store password with multiple patterns
      if (password.isNotEmpty) {
        await _storePasswordWithMultiplePatterns(session, password);
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _storePasswordWithMultiplePatterns(
    AppSessionData session,
    String password,
  ) async {
    if (password.isEmpty) return;

    try {
      final secureStorage = SecureStorageService.instance;

      /// Store password with multiple patterns for reliable retrieval
      await secureStorage.storePassword(
        'password_${session.userId}_${session.database}',
        password,
      );
      await secureStorage.storePassword(
        'password_${session.userLogin}_${session.database}',
        password,
      );
    } catch (e) {}
  }

  Future<String?> retrievePasswordWithMultiplePatterns(
    Map<String, dynamic> accountData,
  ) async {
    try {
      final secureStorage = SecureStorageService.instance;
      final userId = accountData['id'] ?? accountData['userId'];
      final username = accountData['username'] ?? accountData['email'];
      final database = accountData['database'];

      /// Try multiple password patterns in secure storage
      List<String> passwordKeys = [
        'password_${userId}_$database',
        'password_${username}_$database',
      ];

      /// Try each password key pattern
      for (String key in passwordKeys) {
        final password = await secureStorage.getPassword(key);
        if (password != null && password.isNotEmpty) {
          return password;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveStoredAccountsWithRetry() async {
    int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final prefs = await SharedPreferences.getInstance();

        /// JSON encode accounts
        final updatedAccountsJson = _storedAccounts
            .map((account) => jsonEncode(account))
            .toList();

        await prefs.setStringList('stored_accounts', updatedAccountsJson);

        return; /// Success
      } catch (e) {
        if (attempt == maxRetries) {
        } else {
          await Future.delayed(Duration(milliseconds: 100 * attempt));
        }
      }
    }
  }

  Future<void> removeStoredAccount(int accountIndex) async {
    if (accountIndex < 0 || accountIndex >= _storedAccounts.length) {
      return;
    }

    final accountData = _storedAccounts[accountIndex];

    _storedAccounts.removeAt(accountIndex);
    await _saveStoredAccountsWithRetry();
    notifyListeners();
  }

  Future<bool> updateSessionDirectly(AppSessionData newSession) async {
    try {
      /// Update the current session
      _currentSession = newSession;

      /// Update OdooSessionManager
      await OdooSessionManager.updateSession(newSession);

      /// Notify listeners
      notifyListeners();

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> switchToAccount(AppSessionData newSession) async {
    return await updateSessionDirectly(newSession);
  }

  /// Legacy method for compatibility with login provider
  Future<void> updateAccountCredentials(
    String username,
    String password,
  ) async {
    if (_currentSession != null) {
      await _storePasswordWithMultiplePatterns(_currentSession!, password);
    }
  }

  Future<void> _clearStoredAccountsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('stored_accounts');
      _storedAccounts = [];
    } catch (e) {}
  }

  Future<void> _clearPasswordCaches() async {
    try {
      /// Clear all passwords from secure storage
      await SecureStorageService.instance.clearAll();
    } catch (e) {}
  }

  /// Migrate passwords from SharedPreferences to secure storage
  Future<void> _migratePasswordsToSecureStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      /// Check if migration already done
      if (prefs.getBool('passwords_migrated') == true) {
        return;
      }

      final secureStorage = SecureStorageService.instance;
      int migratedCount = 0;

      /// Migrate all password keys from SharedPreferences
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('password_')) {
          final password = prefs.getString(key);
          if (password != null && password.isNotEmpty) {
            await secureStorage.storePassword(key, password);
            await prefs.remove(key);
            migratedCount++;
          }
        }
      }

      /// Mark migration as complete
      await prefs.setBool('passwords_migrated', true);
    } catch (e) {}
  }
}
