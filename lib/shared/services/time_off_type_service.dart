import 'package:mobo_employees/core/services/odoo_session_manager.dart';

/// Odoo 20 moved time-off types from `hr.leave.type` onto
/// `hr.work.entry.type`, and renamed the `holiday_status_id` field on
/// `hr.leave` / `hr.leave.allocation` to `work_entry_type_id`. Keeps that
/// version split in one place for the employee and manager leave forms.
class TimeOffTypeService {
  /// The `hr.leave` / `hr.leave.allocation` field holding the time-off type.
  static String typeField(int majorVersion) =>
      majorVersion >= 20 ? 'work_entry_type_id' : 'holiday_status_id';

  /// Country whose types apply, per server/database/company — `null` means
  /// the generic (country-less) types. Cached because the employee form
  /// searches types on every keystroke.
  static final Map<String, int?> _typeCountryCache = {};

  /// Fetches the Odoo 20 time-off types [employeeId] can request, as raw
  /// `web_search_read` records with `id`, `display_name` and
  /// `requires_allocation`.
  ///
  /// Mirrors the `work_entry_type_id` domain on Odoo 20's own leave form:
  /// types selectable in time off, for the company's country (or the
  /// generic ones when that country has none), that either need no
  /// allocation or have a valid one with balance left (or allow negative).
  static Future<List<Map<String, dynamic>>> fetchSelectableTypes({
    required int? employeeId,
    String query = '',
  }) async {
    final countryId = await _typeCountryId();

    final response = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.work.entry.type',
      'method': 'web_search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['time_off_selectable', '=', true],
          ['country_id', '=', countryId ?? false],
          '|',
          ['requires_allocation', '=', false],
          '&',
          ['has_valid_allocation', '=', true],
          '|',
          ['allows_negative', '=', true],
          ['virtual_remaining_leaves', '>', 0],
          if (query.trim().isNotEmpty) ['display_name', 'ilike', query],
        ],
        'specification': {
          'display_name': {},
          'requires_allocation': {},
        },
        'order': 'sequence ASC, id ASC',
        'context': {'employee_id': employeeId},
      },
    });

    if (response is Map && response['records'] is List) {
      return (response['records'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  /// Odoo 20 offers only the types of the company's country when it has
  /// any, otherwise only the generic ones (`hr.leave`
  /// `_compute_allowed_work_entry_type_ids`).
  static Future<int?> _typeCountryId() async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return null;

    final companyId = session.companyId;
    final cacheKey = '${session.serverUrl}|${session.database}|$companyId';
    if (_typeCountryCache.containsKey(cacheKey)) {
      return _typeCountryCache[cacheKey];
    }

    final company = await OdooSessionManager.callKwWithCompany({
      'model': 'res.company',
      'method': 'read',
      'args': [
        [companyId],
      ],
      'kwargs': {
        'fields': ['country_id'],
      },
    });
    final country = company is List && company.isNotEmpty
        ? company.first['country_id']
        : null;
    final companyCountryId = country is List && country.isNotEmpty
        ? country.first as int
        : null;

    int? typeCountryId;
    if (companyCountryId != null) {
      final count = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.work.entry.type',
        'method': 'search_count',
        'args': [
          [
            ['country_id', '=', companyCountryId],
          ],
        ],
        'kwargs': {'limit': 1},
      });
      if (count is int && count > 0) typeCountryId = companyCountryId;
    }

    _typeCountryCache[cacheKey] = typeCountryId;
    return typeCountryId;
  }
}
