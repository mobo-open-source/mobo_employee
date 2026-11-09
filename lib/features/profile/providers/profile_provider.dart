import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/core/services/session_service.dart';
import 'package:mobo_employees/core/utils/odoo_binary_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ProfileProvider extends ChangeNotifier {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  Uint8List? _userAvatar;
  String? _error;
  Object? _loadError;
  bool _hasInternet = true;
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  static const String _cacheKeyUser = 'user_profile';
  static const String _cacheKeyUserWriteDate = 'user_profile_write_date';
  static const String _cacheKeyPendingUserUpdates =
      'user_profile_pending_users';
  static const String _cacheKeyPendingPartnerUpdates =
      'user_profile_pending_partner';
  static const String _cacheKeyHrFields = 'user_profile_hr_fields';

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get userData => _userData;
  Uint8List? get userAvatar => _userAvatar;
  String? get error => _error;

  /// The error the last [fetchUserProfile] failed with, for the screen's
  /// error state; null after a successful read.
  Object? get loadError => _loadError;
  bool get hasInternet => _hasInternet;
  List<Map<String, dynamic>> get countries => _countries;
  List<Map<String, dynamic>> get states => _states;
  bool get isLoadingCountries => _isLoadingCountries;
  bool get isLoadingStates => _isLoadingStates;

  String normalizeForEdit(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'true' : '';
    final s = value.toString().trim();
    return (s.toLowerCase() == 'false' || s.isEmpty) ? '' : s;
  }

  /// Pending offline updates (merged per model)
  Map<String, dynamic> _pendingUserUpdates = {};
  Map<String, dynamic> _pendingPartnerUpdates = {};

  /// Normalize partner update keys to match server schema
  /// e.g., map legacy/mobile_phone to standard 'mobile'
  Map<String, dynamic> _normalizePartnerUpdates(Map<String, dynamic> updates) {
    final out = <String, dynamic>{};
    updates.forEach((key, value) {
      String k = key;
      if (k == 'mobile_phone') k = 'mobile';
      out[k] = value;
    });
    return out;
  }

  /// Whether `res.partner.mobile` exists on this server (removed in Odoo 19).
  /// Tri-state so "not probed yet" is distinguishable from "confirmed absent".
  bool _mobileFieldResolved = false;
  String? _mobileFieldName;

  /// True once the server has been probed and it really has no mobile field.
  bool get serverHasNoMobileField =>
      _mobileFieldResolved && _mobileFieldName == null;

  /// Forgets the probe result; must be re-run on account switch since the
  /// field's existence is per-server.
  void resetMobileFieldDetection() {
    _mobileFieldResolved = false;
    _mobileFieldName = null;
  }

  /// Resolves the mobile field name via `fields_get` (not `ir.model.fields`,
  /// which a plain employee has no access to). Throws on probe failure so
  /// callers can tell "absent" apart from "unknown".
  Future<String?> _resolvePartnerMobileFieldName() async {
    if (_mobileFieldResolved) return _mobileFieldName;

    final fieldsInfo = await OdooSessionManager.callKwWithCompany({
      'model': 'res.partner',
      'method': 'fields_get',
      'args': [],
      'kwargs': {
        'allfields': ['mobile_phone', 'x_studio_mobile_phone', 'mobile'],
        'attributes': <String>[],
      },
    });

    final present = <String>{
      if (fieldsInfo is Map) for (final k in fieldsInfo.keys) k.toString(),
    };

    // A custom/Studio field wins over the standard one when both exist.
    _mobileFieldName = const ['mobile_phone', 'x_studio_mobile_phone', 'mobile']
        .cast<String?>()
        .firstWhere((f) => present.contains(f), orElse: () => null);
    _mobileFieldResolved = true;
    return _mobileFieldName;
  }

  /// Best-effort variant for the read path, where a failed probe should
  /// just mean "don't request the field this time" rather than an error.
  Future<String?> _getPartnerMobileFieldName() async {
    try {
      return await _resolvePartnerMobileFieldName();
    } catch (_) {
      return null;
    }
  }

  /// The connected server's major Odoo version, used to gate version-specific
  /// UI (see `isOdoo17`).
  int? _serverMajorVersion;
  bool get isOdoo17 => _serverMajorVersion == 17;

  Future<void> _resolveServerVersion() async {
    if (_serverMajorVersion != null) return;
    try {
      _serverMajorVersion = await OdooSessionManager.getServerMajorVersion();
    } catch (_) {
      // Leave unresolved so the next fetch retries.
    }
  }

  /// Whether the HR module is installed, adding `job_title` / `work_phone` /
  /// `private_*` fields on `res.users` (related to `hr.employee`). Detected
  /// via `fields_get`, not `ir.model.fields`, which a plain employee can't
  /// access.
  bool _hrFieldsResolved = false;
  bool _hasJobTitleField = false;
  bool _hasWorkPhoneField = false;
  bool _hasEmployeeIdField = false;
  bool _hasPrivateAddressFields = false;

  /// Whether `res.users.job_title` itself is writable (true on 17/18, false
  /// on 19 — detected via `fields_get`'s `readonly` attribute rather than
  /// guessed from a version number).
  bool _jobTitleWritableViaUsers = false;
  bool get jobTitleWritableViaUsers => _jobTitleWritableViaUsers;

  bool get hasJobTitleField => _hasJobTitleField;
  bool get hasWorkPhoneField => _hasWorkPhoneField;
  bool get hasPrivateAddressFields => _hasPrivateAddressFields;

  /// Whether the current account actually has an `hr.employee` linked, as
  /// opposed to `_hasEmployeeIdField`, which only means the field exists.
  bool get _hasLinkedEmployee {
    final id = _userData?['employee_id'];
    return id is List && id.isNotEmpty && id[0] != null;
  }

  /// Whether a job_title edit should also be mirrored directly onto
  /// `hr.employee.job_title` -- the fallback needed only when
  /// `res.users.job_title` can't carry the write (Odoo 19). Only succeeds
  /// for HR "Officer" accounts (`hr.group_hr_user`); see
  /// `writeEmployeeJobTitleBestEffort`.
  bool get canWriteEmployeeJobTitle =>
      _hasJobTitleField && !_jobTitleWritableViaUsers && _hasLinkedEmployee;

  /// Forgets the probe result (and its persisted cache) so it's re-detected
  /// on account switch, since HR presence is a per-server fact.
  void resetHrFieldDetection() {
    _hrFieldsResolved = false;
    _hasJobTitleField = false;
    _hasWorkPhoneField = false;
    _hasEmployeeIdField = false;
    _hasPrivateAddressFields = false;
    _jobTitleWritableViaUsers = false;
    unawaited(_clearHrFieldsCache());
  }

  static const List<String> _privateAddressFieldNames = [
    'private_street',
    'private_street2',
    'private_city',
    'private_zip',
    'private_state_id',
    'private_country_id',
  ];

  Map<String, bool> _hrFieldsSnapshot() => {
        'hasJobTitleField': _hasJobTitleField,
        'hasWorkPhoneField': _hasWorkPhoneField,
        'hasEmployeeIdField': _hasEmployeeIdField,
        'hasPrivateAddressFields': _hasPrivateAddressFields,
        'jobTitleWritableViaUsers': _jobTitleWritableViaUsers,
      };

  void _applyHrFieldsSnapshot(Map<String, dynamic> map) {
    _hasJobTitleField = map['hasJobTitleField'] == true;
    _hasWorkPhoneField = map['hasWorkPhoneField'] == true;
    _hasEmployeeIdField = map['hasEmployeeIdField'] == true;
    _hasPrivateAddressFields = map['hasPrivateAddressFields'] == true;
    _jobTitleWritableViaUsers = map['jobTitleWritableViaUsers'] == true;
  }

  /// Loads a previously-persisted probe result for the active account.
  /// Returns whether one was found and applied.
  Future<bool> _loadHrFieldsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKeyHrFields);
      if (raw == null || raw.isEmpty) return false;
      _applyHrFieldsSnapshot(jsonDecode(raw) as Map<String, dynamic>);
      _hrFieldsResolved = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveHrFieldsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyHrFields, jsonEncode(_hrFieldsSnapshot()));
    } catch (_) {
    }
  }

  Future<void> _clearHrFieldsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKeyHrFields);
    } catch (_) {
    }
  }

  /// Resolves which HR fields exist/are writable, once per account.
  /// Persisted so a cold start (offline included) has an answer immediately.
  Future<void> _resolveHrFields() async {
    if (_hrFieldsResolved) return;

    if (await _loadHrFieldsCache()) {
      // Refresh in the background in case HR was installed/uninstalled,
      // without blocking the caller on a round-trip.
      unawaited(_probeHrFields());
      return;
    }

    await _probeHrFields();
  }

  Future<void> _probeHrFields() async {
    try {
      // `fields_get` covers existence and writability (`readonly`) in one
      // call and needs no `ir.model.access` grant, unlike `ir.model.fields`.
      final fieldsInfo = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'fields_get',
        'args': [],
        'kwargs': {
          'allfields': [
            'job_title',
            'work_phone',
            'employee_id',
            ..._privateAddressFieldNames,
          ],
          'attributes': ['readonly'],
        },
      });

      final info = <String, dynamic>{
        if (fieldsInfo is Map)
          for (final entry in fieldsInfo.entries) entry.key.toString(): entry.value,
      };

      bool isReadonly(String name) {
        final desc = info[name];
        return desc is Map && desc['readonly'] == true;
      }

      // `fields_get` only says a field exists. Some related HR fields also
      // need a group to *read* (on Odoo 19 the `private_*` address fields
      // require HR Officer), and requesting one the user can't read fails
      // the whole profile read — so confirm readability per group too.
      final session = await OdooSessionManager.getCurrentSession();
      final uid = session?.userId;
      Future<bool> readable(List<String> fields) async {
        if (uid == null) return true;
        try {
          await OdooSessionManager.callKwWithCompany({
            'model': 'res.users',
            'method': 'read',
            'args': [
              [uid],
              fields,
            ],
            'kwargs': {},
          });
          return true;
        } catch (e) {
          if (_isAccessError(e)) return false;
          rethrow;
        }
      }

      _hasJobTitleField =
          info.containsKey('job_title') && await readable(['job_title']);
      _hasWorkPhoneField =
          info.containsKey('work_phone') && await readable(['work_phone']);
      _hasEmployeeIdField =
          info.containsKey('employee_id') && await readable(['employee_id']);
      _jobTitleWritableViaUsers = _hasJobTitleField && !isReadonly('job_title');
      _hasPrivateAddressFields =
          _privateAddressFieldNames.every(info.containsKey) &&
          await readable(_privateAddressFieldNames);
      _hrFieldsResolved = true;
      await _saveHrFieldsCache();
    } catch (_) {
      // Leave unresolved so the next fetch retries the probe instead of
      // permanently assuming HR isn't installed.
    }
  }

  Future<Map<String, dynamic>> _preparePartnerUpdatesForServer(
    Map<String, dynamic> normalized,
  ) async {
    // Map our internal 'mobile' to whichever field server supports
    if (!normalized.containsKey('mobile')) return normalized;

    // Don't swallow a probe failure: an unknown field must fail loudly and
    // be queued for retry rather than silently dropping the mobile number.
    final fieldName = await _resolvePartnerMobileFieldName();

    if (fieldName == null) {
      // Confirmed absent (Odoo 19); drop it rather than merging into `phone`.
      final copy = Map<String, dynamic>.from(normalized);
      copy.remove('mobile');
      return copy;
    }
    if (fieldName == 'mobile') return normalized;
    final copy = Map<String, dynamic>.from(normalized);
    final value = copy.remove('mobile');
    copy[fieldName] = value;
    return copy;
  }

  /// Update multiple contact fields at once (on res.partner)
  Future<void> updatePartnerFields(Map<String, dynamic> updates) async {
    try {
      if (_userData == null) return;

      final partnerId = _userData!['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        throw Exception('Partner ID not found');
      }

      final normalized = _normalizePartnerUpdates(updates);

      // Always attempt the real write first rather than pre-guessing
      // offline status — a local server (LAN/emulator-only Odoo, no
      // public-internet route) can be perfectly reachable while a generic
      // "do I have internet" probe reports false, which used to skip the
      // write and silently queue it forever. Genuine connectivity failures
      // are still caught below and queued exactly the same way.
      final toSend = await _preparePartnerUpdatesForServer(normalized);
      await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'write',
        'args': [
          [partnerId[0]],
          toSend,
        ],
        'kwargs': {},
      });

      await _refreshAfterWrite(normalized);
    } catch (e) {
      if (!_isConnectivityError(e)) {
        _error = 'Failed to update profile: $e';
        rethrow;
      }
      // Queue only on connectivity failure.
      final normalized = _normalizePartnerUpdates(updates);
      _mergeInto(_pendingPartnerUpdates, normalized);
      await _savePendingUpdates();
      await _applyLocalUserUpdates(normalized);
    }
  }

  Future<void> initialize() async {
    _startConnectivityListener();
    await loadCachedUser();
    await _loadPendingUpdates();
    await fetchUserProfile();
    await loadCountries();
  }

  /// Loads the profile if nothing is in memory yet. `ClearProviders` wipes
  /// this provider on app entry and on company/account changes, and the
  /// full [initialize] used to run only when the Profile screen opened, so
  /// the appbar avatar and dashboard greeting card fell back to "?"/initials
  /// until the user visited Profile. App shells call this on start.
  Future<void> ensureLoaded() async {
    _startConnectivityListener();
    // Show the cached copy immediately when memory was wiped, so a slow or
    // failed network read doesn't leave the avatar/name blank.
    if (_userData == null) {
      await loadCachedUser();
      await _loadPendingUpdates();
    }
    await fetchUserProfile();
  }

  void _startConnectivityListener() {
    // Idempotent: initialize()/ensureLoaded() run on every Profile visit
    // and shell start, and each call used to stack another listener.
    if (_connectivitySub != null) return;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final hasNet = await _checkInternet();
      _hasInternet = hasNet;
      notifyListeners();
      if (hasNet) {
        await _processPendingUpdates();
      }
    });

    _checkInternet().then((hasNet) {
      _hasInternet = hasNet;
      notifyListeners();
    });
  }

  /// Delegates to the shared [ConnectivityService] (same check used by
  /// session/offline handling elsewhere in the app) instead of a private
  /// DNS lookup against a single external host, purely so the "You are
  /// offline" banner and the "Sync" action reflect the same notion of
  /// connectivity as the rest of the app.
  ///
  /// This is informational only now — no save path branches on it anymore.
  /// It used to gate every write ("if no internet, queue locally instead of
  /// calling Odoo"), which is the wrong check for this purpose: a generic
  /// "do I have internet" probe can report false against a perfectly
  /// reachable local/LAN-only Odoo server (no public-internet route at
  /// all), and — since it was only re-evaluated on a
  /// `Connectivity().onConnectivityChanged` event, not before each save —
  /// a single false negative anywhere in the session latched every later
  /// edit into the offline-only local queue, so saves looked successful
  /// while nothing ever reached the server. Every write below now always
  /// attempts the real RPC first and queues only when that attempt itself
  /// fails with a genuine connectivity error (see `_isConnectivityError`).
  Future<bool> _checkInternet() =>
      ConnectivityService.instance.hasInternetAccess();

  Future<void> loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKeyUser);
      if (cached != null && cached.isNotEmpty) {
        final data =
            normalizeOdooBinaries(jsonDecode(cached)) as Map<String, dynamic>;
        final session = await OdooSessionManager.getCurrentSession();
        if (session != null && !_belongsTo(data, session.userId)) {
          // Left behind by a different account — never show it as this one.
          await prefs.remove(_cacheKeyUser);
          return;
        }
        _userData = data;
        final img = data['image_1920'];
        if (img != null && img is String && img.isNotEmpty && img != 'false') {
          try {
            _userAvatar = base64Decode(img);
          } catch (_) {}
        }
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
    }
  }

  /// Treats null/''/the literal string 'false' (Odoo's empty-field RPC
  /// value) as "not set".
  String? _val(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return (s.isEmpty || s == 'false') ? null : s;
  }

  /// Whether [data] is the profile of user [uid]. The cache is one
  /// SharedPreferences slot, so without this check a profile left behind by
  /// a previous account was shown (and edited) as the current user's.
  bool _belongsTo(Map<String, dynamic>? data, int uid) =>
      data != null && data['id']?.toString() == uid.toString();

  bool _isAccessError(Object e) {
    final s = e.toString();
    return s.contains('AccessError') ||
        s.contains('do not have enough rights');
  }

  List<String> _userReadFields() => [
        'name',
        'login',
        'email',
        // phone/mobile live on res.partner; fetched from the partner below
        'website',
        'function',
        if (_hasJobTitleField) 'job_title',
        if (_hasWorkPhoneField) 'work_phone',
        if (_hasEmployeeIdField) 'employee_id',
        if (_hasPrivateAddressFields) ..._privateAddressFieldNames,
        'image_1920',
        'company_id',
        'partner_id',
      ];

  /// The fields an Odoo AccessError says the user can't read. Odoo 17 and 18
  /// list every denied field in one message (`access the fields "x,y,z"`);
  /// Odoo 20 names a single one (`access the field "x"`).
  @visibleForTesting
  static Set<String> deniedFieldsIn(String message) {
    final names = RegExp(r'access the fields? "([a-zA-Z0-9_,]+)"')
        .firstMatch(message)
        ?.group(1);
    if (names == null) return {};
    return names.split(',').where((name) => name.isNotEmpty).toSet();
  }

  /// If [e] is an AccessError on any of the optional HR fields, stops
  /// requesting those fields (groups) and returns true so the read can retry.
  bool _dropDeniedOptionalField(Object e) {
    if (!_isAccessError(e)) return false;
    var dropped = false;
    for (final field in deniedFieldsIn(e.toString())) {
      if (field == 'job_title' && _hasJobTitleField) {
        _hasJobTitleField = false;
        _jobTitleWritableViaUsers = false;
        dropped = true;
      } else if (field == 'work_phone' && _hasWorkPhoneField) {
        _hasWorkPhoneField = false;
        dropped = true;
      } else if (field == 'employee_id' && _hasEmployeeIdField) {
        _hasEmployeeIdField = false;
        dropped = true;
      } else if (_privateAddressFieldNames.contains(field) &&
          _hasPrivateAddressFields) {
        _hasPrivateAddressFields = false;
        dropped = true;
      }
    }
    return dropped;
  }

  /// Reads the user's own row, dropping any optional HR field the user isn't
  /// allowed to read (e.g. `private_street` needs HR Officer on Odoo 19)
  /// instead of failing the whole profile read, which left the screen stuck
  /// on stale cached data.
  Future<dynamic> _readUserRow(int userId) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await OdooSessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'read',
          'args': [
            [userId],
            _userReadFields(),
          ],
          'kwargs': {},
        });
      } catch (e) {
        if (attempt >= 4 || !_dropDeniedOptionalField(e)) rethrow;
        await _saveHrFieldsCache();
      }
    }
  }

  /// Returns true only when fresh data was actually read from the server, so
  /// a save can tell "saved and re-read" apart from "saved, but the re-read
  /// failed and the screen would still show the old values".
  Future<bool> fetchUserProfile({bool forceRefresh = false}) async {
    var refreshed = false;
    int? currentUid;
    // Only show loading state if we have no cached data
    // This allows silent background refresh when data exists
    if (_userData == null) {
      _isLoading = true;
    }
    _error = null;
    _loadError = null;
    notifyListeners();

    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Must run before the read below: requesting HR fields unconditionally
      // throws on installs without the HR module.
      await _resolveHrFields();
      await _resolveServerVersion();

      currentUid = session.userId;

      // Read basic user fields from res.users (exclude unsupported fields like 'mobile')
      final res = await _readUserRow(session.userId);

      if (res is List && res.isNotEmpty) {
        final data = res.first as Map<String, dynamic>;

        // Prefer HR's job_title over the generic Contacts function, when set.
        final jobTitle = _val(data['job_title']);
        if (jobTitle != null) data['function'] = jobTitle;

        final partner = data['partner_id'];
        if (partner != null && partner is List && partner.isNotEmpty) {
          try {
            // Determine which mobile field exists to avoid invalid field errors
            final mobileFieldName = await _getPartnerMobileFieldName();
            final fields = <String>[
              'phone',
              'street',
              'street2',
              'city',
              'zip',
              'state_id',
              'country_id',
            ];
            if (mobileFieldName != null) fields.add(mobileFieldName);

            final partnerRes = await OdooSessionManager.callKwWithCompany({
              'model': 'res.partner',
              'method': 'read',
              'args': [
                [partner[0]],
                fields,
              ],
              'kwargs': {},
            });

            if (partnerRes is List && partnerRes.isNotEmpty) {
              final partnerData = partnerRes.first as Map<String, dynamic>;
              data['phone'] = partnerData['phone'];
              String? mobileValue;
              if (mobileFieldName != null) {
                final mv = partnerData[mobileFieldName];
                if (mv != null && mv.toString().isNotEmpty && mv != 'false') {
                  mobileValue = mv.toString();
                }
              }
              // If server has no mobile field, keep empty so UI treats it as separate and editable
              data['mobile'] = mobileValue ?? '';
              data['street'] = partnerData['street'];
              data['street2'] = partnerData['street2'];
              data['city'] = partnerData['city'];
              data['zip'] = partnerData['zip'];
              data['state_id'] = partnerData['state_id'];
              data['country_id'] = partnerData['country_id'];
            }
          } catch (e) {
          }
        }

        final workPhone = _val(data['work_phone']);
        if (workPhone != null) data['phone'] = workPhone;

        // Prefer the Employee's private address over the Contact's, when set.
        if (_hasPrivateAddressFields) {
          final privateStreet = _val(data['private_street']);
          if (privateStreet != null) data['street'] = privateStreet;
          final privateStreet2 = _val(data['private_street2']);
          if (privateStreet2 != null) data['street2'] = privateStreet2;
          final privateCity = _val(data['private_city']);
          if (privateCity != null) data['city'] = privateCity;
          final privateZip = _val(data['private_zip']);
          if (privateZip != null) data['zip'] = privateZip;
          final privateState = data['private_state_id'];
          if (privateState is List && privateState.isNotEmpty) {
            data['state_id'] = privateState;
          }
          final privateCountry = data['private_country_id'];
          if (privateCountry is List && privateCountry.isNotEmpty) {
            data['country_id'] = privateCountry;
          }
        }

        _userData = data;
        final img = data['image_1920'];
        if (img != null && img is String && img.isNotEmpty && img != 'false') {
          try {
            _userAvatar = base64Decode(img);
          } catch (_) {}
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKeyUser, jsonEncode(data));
        refreshed = true;

        // Keep the saved-accounts list (switch accounts) showing the same
        // name/photo as the server.
        final rawImage = data['image_1920'];
        await SessionService.instance.updateStoredAccountProfile(
          userId: session.userId,
          serverUrl: session.serverUrl,
          database: session.database,
          name: _val(data['name']),
          imageBase64: rawImage is String && rawImage != 'false'
              ? rawImage
              : null,
        );
      }
    } catch (e) {
      _error = 'Failed to fetch user profile: $e';
      _loadError = e;
      // Falling back to the in-memory copy is only valid for the same user.
      if (currentUid != null && !_belongsTo(_userData, currentUid)) {
        _userData = null;
        _userAvatar = null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return refreshed;
  }

  /// Maps server field names in a just-written update onto the keys the UI
  /// reads (`fetchUserProfile` folds `work_phone` into `phone` and
  /// `job_title` into `function`), so a local apply shows up on screen.
  Map<String, dynamic> _toDisplayKeys(Map<String, dynamic> updates) {
    final out = Map<String, dynamic>.from(updates);
    if (updates.containsKey('work_phone')) out['phone'] = updates['work_phone'];
    if (updates.containsKey('job_title')) out['function'] = updates['job_title'];
    return out;
  }

  /// After a successful write: re-read from the server, and if that re-read
  /// fails, apply what was written locally so the app never keeps showing
  /// the pre-edit values for data the server has already accepted.
  Future<void> _refreshAfterWrite(Map<String, dynamic> written) async {
    if (await fetchUserProfile(forceRefresh: true)) return;
    await _applyLocalUserUpdates(_toDisplayKeys(written));
  }

  Future<void> loadCountries() async {
    _isLoadingCountries = true;
    notifyListeners();

    try {
      _countries = await fetchCountries();
    } catch (e) {
    } finally {
      _isLoadingCountries = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchCountries() async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.country',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['id', 'name', 'code'],
          'order': 'name ASC',
        },
      });
      return result is List ? result.cast<Map<String, dynamic>>() : [];
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadStates(int countryId) async {
    _isLoadingStates = true;
    notifyListeners();

    try {
      _states = await fetchStates(countryId);
    } catch (e) {
    } finally {
      _isLoadingStates = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchStates(int countryId) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.country.state',
        'method': 'search_read',
        'args': [
          [
            ['country_id', '=', countryId],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name', 'code'],
          'order': 'name ASC',
        },
      });
      return result is List ? result.cast<Map<String, dynamic>>() : [];
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProfileImage(String base64Image) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) return;

      // Always attempt the real write first — see the note in
      // [updatePartnerFields]; the catch block below queues on a genuine
      // connectivity failure.
      await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [session.userId],
          {'image_1920': base64Image},
        ],
        'kwargs': {},
      });

      try {
        _userAvatar = base64Decode(base64Image);
      } catch (_) {}
      _userData ??= {};
      _userData!['image_1920'] = base64Image;
      notifyListeners();

      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      if (!_isConnectivityError(e)) {
        _error = 'Failed to update profile photo: $e';
        rethrow;
      }
      // Queue on connectivity failure too
      _pendingUserUpdates['image_1920'] = base64Image;
      await _savePendingUpdates();
      try {
        _userAvatar = base64Decode(base64Image);
      } catch (_) {}
      _userData ??= {};
      _userData!['image_1920'] = base64Image;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyUser, jsonEncode(_userData));
      notifyListeners();
    }
  }

  Future<void> updateProfileField(String field, dynamic value) async {
    try {
      if (_userData == null) return;

      final partnerId = _userData!['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        throw Exception('Partner ID not found');
      }

      await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'write',
        'args': [
          [partnerId[0]],
          {field: value},
        ],
        'kwargs': {},
      });

      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      _error = 'Failed to update $field: $e';
      rethrow;
    }
  }

  /// Maps generic address keys to `res.users`'s private-address field names.
  Map<String, dynamic> _toPrivateAddressUpdates(
    Map<String, dynamic> addressData,
  ) {
    const keyMap = {
      'street': 'private_street',
      'street2': 'private_street2',
      'city': 'private_city',
      'zip': 'private_zip',
      'state_id': 'private_state_id',
      'country_id': 'private_country_id',
    };
    final out = <String, dynamic>{};
    addressData.forEach((key, value) {
      final mapped = keyMap[key];
      if (mapped != null) out[mapped] = value;
    });
    return out;
  }

  Future<void> updateAddressFields(Map<String, dynamic> addressData) async {
    try {
      if (_userData == null) return;

      final partnerId = _userData!['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        throw Exception('Partner ID not found');
      }

      // Mirrored via `res.users` (never `hr.employee` directly — plain
      // employees have no ACL access to `hr.employee`).
      final userAddressUpdates =
          _hasPrivateAddressFields ? _toPrivateAddressUpdates(addressData) : null;

      // Always attempt the real write first — see the note in
      // [updatePartnerFields]; the catch block below queues on a genuine
      // connectivity failure.
      await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'write',
        'args': [
          [partnerId[0]],
          addressData,
        ],
        'kwargs': {},
      });

      if (userAddressUpdates != null) {
        final session = await OdooSessionManager.getCurrentSession();
        if (session != null && session.userId != null) {
          await OdooSessionManager.callKwWithCompany({
            'model': 'res.users',
            'method': 'write',
            'args': [
              [session.userId],
              userAddressUpdates,
            ],
            'kwargs': {},
          });
        }
      }

      await _refreshAfterWrite(addressData);
    } catch (e) {
      if (!_isConnectivityError(e)) {
        _error = 'Failed to update address: $e';
        rethrow;
      }
      // Queue on connectivity failure and update local cache
      _mergeInto(_pendingPartnerUpdates, addressData);
      if (_hasPrivateAddressFields) {
        _mergeInto(_pendingUserUpdates, _toPrivateAddressUpdates(addressData));
      }
      await _savePendingUpdates();
      await _applyLocalUserUpdates(addressData);
    }
  }

  /// Best-effort mirror of a job_title edit onto `hr.employee.job_title`,
  /// used only when `res.users.job_title` can't carry the write (see
  /// `canWriteEmployeeJobTitle`). Failure is swallowed, not surfaced.
  Future<void> writeEmployeeJobTitleBestEffort(String value) async {
    try {
      if (_userData == null) return;
      final employeeId = _userData!['employee_id'];
      if (employeeId is! List || employeeId.isEmpty || employeeId[0] == null) {
        return;
      }

      await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'write',
        'args': [
          [employeeId[0]],
          {'job_title': value},
        ],
        'kwargs': {},
      });

      await _refreshAfterWrite({'job_title': value});
    } catch (_) {
      // Most commonly an AccessError for a non-HR-officer account.
    }
  }

  /// Update multiple profile fields at once (on res.users)
  Future<void> updateProfileFields(Map<String, dynamic> updates) async {
    // Name and email are mandatory: refuse blanks here too, so they can
    // neither reach Odoo nor sit in the offline queue to be sent later.
    for (final entry in const {'name': 'Name', 'email': 'Email'}.entries) {
      if (!updates.containsKey(entry.key)) continue;
      final value = updates[entry.key];
      if (value == null || value.toString().trim().isEmpty) {
        throw Exception('${entry.value} is required');
      }
    }

    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) {
        throw Exception('No active session');
      }

      // Always attempt the real write first — see the note in
      // [updatePartnerFields]; the catch block below queues on a genuine
      // connectivity failure.
      await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [session.userId],
          updates,
        ],
        'kwargs': {},
      });

      await _refreshAfterWrite(updates);
    } catch (e) {
      if (!_isConnectivityError(e)) {
        _error = 'Failed to update profile: $e';
        rethrow;
      }
      // Queue only on connectivity failure.
      _mergeInto(_pendingUserUpdates, updates);
      await _savePendingUpdates();
      await _applyLocalUserUpdates(updates);
    }
  }

  /// Load the related company (parent_id) for the user's partner
  Future<Map<String, dynamic>?> loadRelatedCompany() async {
    try {
      if (_userData == null) return null;

      final partnerId = _userData!['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        return null;
      }

      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'read',
        'args': [
          [partnerId[0]],
        ],
        'kwargs': {
          'fields': ['parent_id'],
        },
      });

      if (res is List && res.isNotEmpty) {
        final row = res.first as Map<String, dynamic>;
        if (row['parent_id'] is List &&
            (row['parent_id'] as List).length >= 2 &&
            row['parent_id'][0] != null) {
          return {
            'id': row['parent_id'][0],
            'name': row['parent_id'][1]?.toString(),
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update the related company (parent_id) for the user's partner
  Future<void> updateRelatedCompany(int? companyId) async {
    try {
      if (_userData == null) return;

      final partnerId = _userData!['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        throw Exception('Partner ID not found');
      }

      await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'write',
        'args': [
          [partnerId[0]],
          {'parent_id': companyId ?? false},
        ],
        'kwargs': {},
      });

      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      _error = 'Failed to update related company: $e';
      rethrow;
    }
  }

  /// Format address fields into a single display string
  String formatAddress(Map<String, dynamic> data) {
    final parts = [
      if (data['street'] != null &&
          data['street'].toString().isNotEmpty &&
          data['street'].toString().toLowerCase() != 'false')
        data['street'],
      if (data['street2'] != null &&
          data['street2'].toString().isNotEmpty &&
          data['street2'].toString().toLowerCase() != 'false')
        data['street2'],
      if (data['city'] != null &&
          data['city'].toString().isNotEmpty &&
          data['city'].toString().toLowerCase() != 'false')
        data['city'],
      if (data['state_id'] is List &&
          data['state_id'].length > 1 &&
          data['state_id'][1] != null &&
          data['state_id'][1].toString().isNotEmpty &&
          data['state_id'][1].toString().toLowerCase() != 'false')
        data['state_id'][1],
      if (data['zip'] != null &&
          data['zip'].toString().isNotEmpty &&
          data['zip'].toString().toLowerCase() != 'false')
        data['zip'],
      if (data['country_id'] is List &&
          data['country_id'].length > 1 &&
          data['country_id'][1] != null &&
          data['country_id'][1].toString().isNotEmpty &&
          data['country_id'][1].toString().toLowerCase() != 'false')
        data['country_id'][1],
    ];
    return parts.isNotEmpty ? parts.join(', ') : 'No address set';
  }

  void clearStates() {
    _states = [];
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      _error = 'Logout failed: $e';
      rethrow;
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  /// Reset provider state to initial values (called when cache is cleared)
  void resetState() {
    _isLoading = true;
    _userData = null;
    _userAvatar = null;
    _error = null;
    _loadError = null;
    _hasInternet = true;
    _countries = [];
    _states = [];
    _isLoadingCountries = false;
    _isLoadingStates = false;
    // Clear queued edits and per-server probes — they belong to the
    // outgoing account, not the incoming one.
    _pendingUserUpdates.clear();
    _pendingPartnerUpdates.clear();
    resetMobileFieldDetection();
    resetHrFieldDetection();
    _serverMajorVersion = null;
    notifyListeners();
  }

  /// Expose sync status and manual trigger for UI
  bool get hasPendingUpdates =>
      _pendingUserUpdates.isNotEmpty || _pendingPartnerUpdates.isNotEmpty;

  Future<void> processPendingUpdates() => _processPendingUpdates();

  /// True only for genuine connectivity failures (dropped connection, DNS,
  /// timeout, server down). Determines whether a failed save is queued for
  /// retry or surfaced as a real error.
  bool _isConnectivityError(Object e) =>
      ConnectivityService.isConnectivityError(e);

  void _mergeInto(Map<String, dynamic> target, Map<String, dynamic> src) {
    for (final e in src.entries) {
      target[e.key] = e.value;
    }
  }

  Future<void> _loadPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final u = prefs.getString(_cacheKeyPendingUserUpdates);
      final p = prefs.getString(_cacheKeyPendingPartnerUpdates);
      if (u != null && u.isNotEmpty) {
        _pendingUserUpdates = Map<String, dynamic>.from(jsonDecode(u));
      }
      if (p != null && p.isNotEmpty) {
        _pendingPartnerUpdates = Map<String, dynamic>.from(jsonDecode(p));
      }
    } catch (e) {
    }
  }

  Future<void> _savePendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKeyPendingUserUpdates,
        jsonEncode(_pendingUserUpdates),
      );
      await prefs.setString(
        _cacheKeyPendingPartnerUpdates,
        jsonEncode(_pendingPartnerUpdates),
      );
    } catch (e) {
    }
  }

  Future<void> _processPendingUpdates() async {
    if (_pendingUserUpdates.isEmpty && _pendingPartnerUpdates.isEmpty) return;
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) return;

      if (_pendingUserUpdates.isNotEmpty) {
        await OdooSessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'write',
          'args': [
            [session.userId],
            _pendingUserUpdates,
          ],
          'kwargs': {},
        });
        _pendingUserUpdates.clear();
      }

      if (_userData != null && _pendingPartnerUpdates.isNotEmpty) {
        final partnerId = _userData!['partner_id'];
        if (partnerId is List && partnerId.isNotEmpty) {
          final normalized = _normalizePartnerUpdates(_pendingPartnerUpdates);
          final toSend = await _preparePartnerUpdatesForServer(normalized);
          await OdooSessionManager.callKwWithCompany({
            'model': 'res.partner',
            'method': 'write',
            'args': [
              [partnerId[0]],
              toSend,
            ],
            'kwargs': {},
          });
          _pendingPartnerUpdates.clear();
        }
      }

      await _savePendingUpdates();
      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
    }
  }

  Future<void> _applyLocalUserUpdates(Map<String, dynamic> updates) async {
    try {
      if (_userData == null) return;
      updates.forEach((key, value) {
        _userData![key] = value;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyUser, jsonEncode(_userData));
      notifyListeners();
    } catch (e) {
    }
  }
}
