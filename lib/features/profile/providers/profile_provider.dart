import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ProfileProvider extends ChangeNotifier {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  Uint8List? _userAvatar;
  String? _error;
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

    /// A custom/Studio field wins over the standard one when both exist.
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
      /// Leave unresolved so the next fetch retries.
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
      /// Refresh in the background in case HR was installed/uninstalled,
      /// without blocking the caller on a round-trip.
      unawaited(_probeHrFields());
      return;
    }

    await _probeHrFields();
  }

  Future<void> _probeHrFields() async {
    try {
      /// `fields_get` covers existence and writability (`readonly`) in one
      /// call and needs no `ir.model.access` grant, unlike `ir.model.fields`.
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

      _hasJobTitleField = info.containsKey('job_title');
      _hasWorkPhoneField = info.containsKey('work_phone');
      _hasEmployeeIdField = info.containsKey('employee_id');
      _jobTitleWritableViaUsers = _hasJobTitleField && !isReadonly('job_title');
      _hasPrivateAddressFields =
          _privateAddressFieldNames.every(info.containsKey);
      _hrFieldsResolved = true;
      await _saveHrFieldsCache();
    } catch (_) {
      /// Leave unresolved so the next fetch retries the probe instead of
      /// permanently assuming HR isn't installed.
    }
  }

  Future<Map<String, dynamic>> _preparePartnerUpdatesForServer(
    Map<String, dynamic> normalized,
  ) async {
    /// Map our internal 'mobile' to whichever field server supports
    if (!normalized.containsKey('mobile')) return normalized;

    /// Don't swallow a probe failure: an unknown field must fail loudly and
    /// be queued for retry rather than silently dropping the mobile number.
    final fieldName = await _resolvePartnerMobileFieldName();

    if (fieldName == null) {
      /// Confirmed absent (Odoo 19); drop it rather than merging into `phone`.
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

      /// Ensure keys are normalized before any processing
      final normalized = _normalizePartnerUpdates(updates);

      /// Offline-first: if no internet, queue changes and apply locally
      if (!_hasInternet) {
        _mergeInto(_pendingPartnerUpdates, normalized);
        await _savePendingUpdates();
        await _applyLocalUserUpdates(normalized);
        return;
      }

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

      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      if (!_isConnectivityError(e)) {
        _error = 'Failed to update profile: $e';
        rethrow;
      }
      /// Queue only on connectivity failure.
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

  void _startConnectivityListener() {
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

    /// Initial check
    _checkInternet().then((hasNet) {
      _hasInternet = hasNet;
      notifyListeners();
    });
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKeyUser);
      if (cached != null && cached.isNotEmpty) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
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

  Future<void> fetchUserProfile({bool forceRefresh = false}) async {
    /// Only show loading state if we have no cached data
    /// This allows silent background refresh when data exists
    if (_userData == null) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      /// Must run before the read below: requesting HR fields unconditionally
      /// throws on installs without the HR module.
      await _resolveHrFields();
      await _resolveServerVersion();

      /// Read basic user fields from res.users (exclude unsupported fields like 'mobile')
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [session.userId],
          [
            'name',
            'login',
            'email',
            /// phone/mobile live on res.partner; we will fetch them from partner below
            'website',
            'function',
            if (_hasJobTitleField) 'job_title',
            if (_hasWorkPhoneField) 'work_phone',
            if (_hasEmployeeIdField) 'employee_id',
            if (_hasPrivateAddressFields) ..._privateAddressFieldNames,
            'image_1920',
            'company_id',
            'partner_id',
          ],
        ],
        'kwargs': {},
      });

      if (res is List && res.isNotEmpty) {
        final data = res.first as Map<String, dynamic>;

        /// Prefer HR's job_title over the generic Contacts function, when set.
        final jobTitle = _val(data['job_title']);
        if (jobTitle != null) data['function'] = jobTitle;

        /// If partner is linked, fetch phone/mobile from res.partner and merge for UI compatibility
        final partner = data['partner_id'];
        if (partner != null && partner is List && partner.isNotEmpty) {
          try {
            /// Determine which mobile field exists to avoid invalid field errors
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
              /// Merge phone/mobile (and a few address fields if needed by UI)
              data['phone'] = partnerData['phone'];
              /// Derive unified 'mobile' for UI using whichever field exists
              String? mobileValue;
              if (mobileFieldName != null) {
                final mv = partnerData[mobileFieldName];
                if (mv != null && mv.toString().isNotEmpty && mv != 'false') {
                  mobileValue = mv.toString();
                }
              }
              /// If server has no mobile field, keep empty so UI treats it as separate and editable
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

        /// Prefer the Employee's private address over the Contact's, when set.
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
      }
    } catch (e) {
      _error = 'Failed to fetch user profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

      /// Offline-first: queue and apply locally
      if (!_hasInternet) {
        _pendingUserUpdates['image_1920'] = base64Image;
        await _savePendingUpdates();
        /// Apply locally for instant UI
        try {
          _userAvatar = base64Decode(base64Image);
        } catch (_) {}
        _userData ??= {};
        _userData!['image_1920'] = base64Image;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKeyUser, jsonEncode(_userData));
        notifyListeners();
        return;
      }

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
      /// Queue on connectivity failure too
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

      /// Mirrored via `res.users` (never `hr.employee` directly — plain
      /// employees have no ACL access to `hr.employee`).
      final userAddressUpdates =
          _hasPrivateAddressFields ? _toPrivateAddressUpdates(addressData) : null;

      /// Offline-first: queue and apply locally if no internet
      if (!_hasInternet) {
        _mergeInto(_pendingPartnerUpdates, addressData);
        if (userAddressUpdates != null) {
          _mergeInto(_pendingUserUpdates, userAddressUpdates);
        }
        await _savePendingUpdates();
        await _applyLocalUserUpdates(addressData);
        return;
      }

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

      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      if (!_isConnectivityError(e)) {
        _error = 'Failed to update address: $e';
        rethrow;
      }
      /// Queue on connectivity failure and update local cache
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
      if (_userData == null || !_hasInternet) return;
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

      await fetchUserProfile(forceRefresh: true);
    } catch (_) {
      /// Most commonly an AccessError for a non-HR-officer account.
    }
  }

  /// Update multiple profile fields at once (on res.users)
  Future<void> updateProfileFields(Map<String, dynamic> updates) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) {
        throw Exception('No active session');
      }

      if (!_hasInternet) {
        _mergeInto(_pendingUserUpdates, updates);
        await _savePendingUpdates();
        await _applyLocalUserUpdates(updates);
        return;
      }

      await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [session.userId],
          updates,
        ],
        'kwargs': {},
      });

      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      if (!_isConnectivityError(e)) {
        _error = 'Failed to update profile: $e';
        rethrow;
      }
      /// Queue only on connectivity failure.
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
    _hasInternet = true;
    _countries = [];
    _states = [];
    _isLoadingCountries = false;
    _isLoadingStates = false;
    /// Clear queued edits and per-server probes — they belong to the
    /// outgoing account, not the incoming one.
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

  /// ---------- Offline helpers ----------

  /// True only for genuine connectivity failures (dropped connection, DNS,
  /// timeout). Determines whether a failed save is queued for retry or
  /// surfaced as a real error.
  bool _isConnectivityError(Object e) {
    if (e is SocketException || e is TimeoutException) return true;
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('timeout') ||
        s.contains('connection refused') ||
        s.contains('network is unreachable') ||
        s.contains('failed host lookup') ||
        s.contains('connection reset');
  }

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

      /// Apply partner pending
      if (_userData != null && _pendingPartnerUpdates.isNotEmpty) {
        final partnerId = _userData!['partner_id'];
        if (partnerId is List && partnerId.isNotEmpty) {
          /// Normalize any legacy keys before sending
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
