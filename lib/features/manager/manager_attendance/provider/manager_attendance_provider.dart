import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:mobo_employees/features/manager/manager_attendance/model/model_fetch_manager_attendance_groupby_data.dart';
import 'package:mobo_employees/features/manager/manager_attendance/model/model_fetch_manger_attendance_employee_group_by.dart';
import 'package:mobo_employees/features/manager/manager_attendance/model/model_manager_attendance_data.dart';
import 'package:mobo_employees/features/manager/manager_attendance/service/manager_attendance_data_service.dart';

enum AttendanceGroupBy { month, employee }

extension AttendanceGroupByX on AttendanceGroupBy {
  String get label {
    switch (this) {
      case AttendanceGroupBy.month:
        return 'Month';
      case AttendanceGroupBy.employee:
        return 'Employee';
    }
  }
}

enum AttendanceFilter { myTeam, today, thisWeek, checkedIn, checkedOut }

extension AttendanceFilterX on AttendanceFilter {
  String get label {
    switch (this) {
      case AttendanceFilter.myTeam:
        return 'My Team';
      case AttendanceFilter.today:
        return 'Today';
      case AttendanceFilter.thisWeek:
        return 'This Week';
      case AttendanceFilter.checkedIn:
        return 'Checked In';
      case AttendanceFilter.checkedOut:
        return 'Checked Out';
    }
  }
}

class ManagerAttendanceProvider extends ChangeNotifier {
  final TextEditingController searchController = TextEditingController();

  int _currentPage = 0;
  int totalMonthGroups = 0;
  int totalEmployeeGroups = 0;
  int totalMonthCount = 0;
  int totalAttendanceCount = 0;

  int _groupLimit = 40;
  int _groupOffset = 0;

  static const int monthGroupLimit = 100;
  static const int employeeGroupLimit = 40;

  int _monthOffset = 0;
  int _employeeOffset = 0;

  String draftSearch = '';
  String currentSearch = '';

  bool isLoading = false;
  bool isGroupLoading = false;
  bool initialLoadDone = false;

  /// Dedicated first-load flag, kept separate from `isLoading`/
  /// `isGroupLoading` since those double as reentrancy guards elsewhere.
  bool isFirstLoad = true;
  bool hasMoreMonths = true;
  bool hasMoreEmployees = true;
  bool hasMoreGroups = true;

  DateTime? draftSelectedMonth;
  DateTime? selectedMonth; /// optional future use

  Timer? _searchDebounce;

  int get pageSize => employeeGroupLimit;

  /// Grouped attendance (read_group)
  ModelAttendanceGroupByData? modelAttendanceGroupByData;
  ModelAttendanceGroupByEmployeeData? modelAttendanceGroupByEmployeeData;

  /// Attendance list (search_read)
  ModelManagerAttendanceData? modelManagerAttendanceData;

  bool get hasMonthGroup => groupBy.contains(AttendanceGroupBy.month);
  bool get hasEmployeeGroup => groupBy.contains(AttendanceGroupBy.employee);

  List<AttendanceGroupBy> draftGroupBy = [];
  List<AttendanceGroupBy> groupBy = [];

  Set<AttendanceFilter> activeFilters = {};
  Set<AttendanceFilter> draftFilters = {};

  /// Current manager's user id (for the "My Team" filter). Populated once
  /// during [initialLoad].
  int? currentUserId;

  /// Custom "Attendance Date" range from the Filter tab's date pickers.
  DateTime? filterStartDate;
  DateTime? filterEndDate;
  DateTime? draftFilterStartDate;
  DateTime? draftFilterEndDate;

  Future<void> _ensureCurrentUser() async {
    if (currentUserId != null) return;
    final client = await OdooSessionManager.getClient();
    currentUserId = client?.sessionId?.userId;
  }

  String _fmtDateTime(DateTime d) => DateFormat('yyyy-MM-dd HH:mm:ss').format(d);

  /// ANDs together domain fragments (each a leaf or a '&'/'|'-prefixed group).
  List<dynamic> _domainAnd(List<List<dynamic>> fragments) {
    final nonEmpty = fragments.where((f) => f.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return [];
    if (nonEmpty.length == 1) return nonEmpty.first;
    final result = <dynamic>[];
    for (var i = 0; i < nonEmpty.length - 1; i++) {
      result.add('&');
    }
    for (final f in nonEmpty) {
      result.addAll(f);
    }
    return result;
  }

  /// "Today" / "This Week" quick schedule filters, resolved against
  /// [check_in]. If both are selected, the wider (this-week) range wins.
  List<dynamic>? get _scheduleFragment {
    final hasToday = activeFilters.contains(AttendanceFilter.today);
    final hasWeek = activeFilters.contains(AttendanceFilter.thisWeek);
    if (!hasToday && !hasWeek) return null;

    final now = DateTime.now();
    DateTime start;
    if (hasWeek) {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(monday.year, monday.month, monday.day);
    } else {
      start = DateTime(now.year, now.month, now.day);
    }
    final end = hasWeek ? start.add(const Duration(days: 7)) : start.add(const Duration(days: 1));

    return ['&', ['check_in', '>=', _fmtDateTime(start)], ['check_in', '<', _fmtDateTime(end)]];
  }

  /// "Checked In" / "Checked Out" status filter, OR'd together if both
  /// are selected (matching the employees list's OR-of-status convention).
  List<dynamic>? get _statusFragment {
    final conds = <List<dynamic>>[];
    if (activeFilters.contains(AttendanceFilter.checkedIn)) {
      conds.add(['check_out', '=', false]);
    }
    if (activeFilters.contains(AttendanceFilter.checkedOut)) {
      conds.add(['check_out', '!=', false]);
    }
    if (conds.isEmpty) return null;
    if (conds.length == 1) return [conds.first];
    return ['|', ...conds];
  }

  /// Custom "Attendance Date" range from the Filter tab's date pickers.
  List<dynamic>? get _customDateRangeFragment {
    if (filterStartDate == null && filterEndDate == null) return null;
    final conds = <List<dynamic>>[];
    if (filterStartDate != null) {
      final s = DateTime(filterStartDate!.year, filterStartDate!.month, filterStartDate!.day);
      conds.add(['check_in', '>=', _fmtDateTime(s)]);
    }
    if (filterEndDate != null) {
      final e = DateTime(filterEndDate!.year, filterEndDate!.month, filterEndDate!.day)
          .add(const Duration(days: 1));
      conds.add(['check_in', '<', _fmtDateTime(e)]);
    }
    if (conds.length == 1) return [conds.first];
    return ['&', ...conds];
  }

  /// Base domain (active employees + active filters) shared by every fetch.
  List<dynamic> get baseDomain {
    final fragments = <List<dynamic>>[
      [['employee_id.active', '=', true]],
    ];

    if (activeFilters.contains(AttendanceFilter.myTeam) && currentUserId != null) {
      fragments.add([['employee_id.parent_id.user_id', '=', currentUserId]]);
    }

    final schedule = _scheduleFragment;
    if (schedule != null) fragments.add(schedule);

    final status = _statusFragment;
    if (status != null) fragments.add(status);

    final customRange = _customDateRangeFragment;
    if (customRange != null) fragments.add(customRange);

    return _domainAnd(fragments);
  }

  final Map<String, ModelManagerAttendanceData> _groupAttendanceCache = {};
  final Map<String, ModelAttendanceGroupByEmployeeData> _employeeGroupCache =
      {};
  final Set<String> _loadingGroupAttendance = {};
  final Set<String> _loadingGroupNodes = {};
  final Set<int> _loadingEmployees = {};
  final Set<String> _loadingMonths = {};

  final Map<int, ModelManagerAttendanceData> _employeeDetailsCache = {};
  final Map<String, ModelAttendanceGroupByData> _monthGroupCache = {};

  /// Cache detailed attendance per month
  final Map<String, ModelManagerAttendanceData> _monthDetailsCache = {};
  final Map<int, Uint8List?> _employeeImageCache = {};

  ModelAttendanceGroupByData? getMonthGroups(List<dynamic> domain) =>
      _monthGroupCache[_domainKey(domain)];
  ModelAttendanceGroupByEmployeeData? getEmployeeGroups(List<dynamic> domain) =>
      _employeeGroupCache[_domainKey(domain)];
  ModelManagerAttendanceData? getEmployeeDetails(int id) =>
      _employeeDetailsCache[id];
  ModelManagerAttendanceData? getMonthDetails(String month) =>
      _monthDetailsCache[month];

  static const List<AttendanceGroupBy> defaultGroupBy = [
    AttendanceGroupBy.month,
    AttendanceGroupBy.employee,
  ];

  bool hasGroupBy(AttendanceGroupBy g) => groupBy.contains(g);
  bool isEmployeeLoading(int id) => _loadingEmployees.contains(id);
  bool isMonthLoading(String month) => _loadingMonths.contains(month);

  Uint8List? getEmployeeImage(int userId) => _employeeImageCache[userId];


  Future<void> setInitialGroupByByVersion() async {
    final client = await OdooSessionManager.getClient();
    final String serverVersionString = client!.sessionId!.serverVersion;
    final int majorVersion = int.parse(serverVersionString.split('.').first);

    if (majorVersion <= 17) {
      /// Odoo 17 → Employee first
      groupBy = [AttendanceGroupBy.employee];
      draftGroupBy = [AttendanceGroupBy.employee];
    } else {
      /// Odoo 18+ → Month → Employee
      groupBy = [AttendanceGroupBy.month, AttendanceGroupBy.employee];

      draftGroupBy = [AttendanceGroupBy.month, AttendanceGroupBy.employee];
    }

    notifyListeners();
  }

  String _domainKey(List<dynamic> domain) {
    return '${domain.toString()}|search=$currentSearch';
  }

  Future<void> fetchTotalMonthGroups() async {
    final res =
        await ManagerAttendanceDataService.fetchManagerGroupByAttendancesData(
          limit: 0,
          offset: 0,
          search: currentSearch,
          domain: baseDomain,
        );

    totalMonthGroups = res.groups.length; /// read_group returns total length
    notifyListeners();
  }

  Future<void> fetchTotalEmployeeGroups({List<dynamic>? domain}) async {
    final res =
        await ManagerAttendanceDataService.fetchManagerAttendanceGroupByEmployee(
          limit: 0,
          offset: 0,
          search: currentSearch,
          domain: domain,
        );

    totalEmployeeGroups = res.groups.length;
    notifyListeners();
  }

  void updateSearch(String value) {
    currentSearch = value;
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 100), () {
      totalMonthGroups = 0;
      totalEmployeeGroups = 0;
      /// clear caches
      _monthGroupCache.clear();
      _employeeGroupCache.clear();
      _groupAttendanceCache.clear();
      _loadingGroupNodes.clear();
      _loadingGroupAttendance.clear();

      _monthDetailsCache.clear();
      _employeeDetailsCache.clear();
      _loadingMonths.clear();
      _loadingEmployees.clear();

      _groupOffset = 0;
      hasMoreGroups = true;

      if (groupBy.isEmpty) {
        fetchAllAttendances(silent: true);
      } else {
        fetchRootGroups();
      }

      notifyListeners(); ///  ONLY after debounce
    });
  }



  Future<void> fetchMonthGroupsForDomain(List<dynamic> domain) async {
    final key = _domainKey(domain);
    if (_monthGroupCache.containsKey(key)) return;
    if (_loadingGroupNodes.contains(key)) return;

    _loadingGroupNodes.add(key);
    notifyListeners();

    try {
      final res =
          await ManagerAttendanceDataService.fetchManagerGroupByAttendancesData(
            limit: _groupLimit,
            offset: 0,
            search: currentSearch,
            domain: domain,
          );

      _monthGroupCache[key] = res;
    } catch (e) {}

    _loadingGroupNodes.remove(key);
    notifyListeners();
  }

  Future<void> fetchEmployeeGroupsForDomain(List<dynamic> domain) async {
    final key = _domainKey(domain);
    if (_employeeGroupCache.containsKey(key)) return;
    if (_loadingGroupNodes.contains(key)) return;

    _loadingGroupNodes.add(key);
    notifyListeners();

    try {
      final res =
          await ManagerAttendanceDataService.fetchManagerAttendanceGroupByEmployee(
            limit: _groupLimit,
            offset: 0,
            domain: domain,
            search: currentSearch,
          );

      _employeeGroupCache[key] = res;
    } catch (e) {}

    _loadingGroupNodes.remove(key);
    notifyListeners();
  }

  bool get canGoNext {
    if (groupBy.isEmpty) {
      return (_currentPage + 1) * pageSize < totalAttendanceCount;
    }
    return groupBy.first == AttendanceGroupBy.month
        ? hasMoreMonths
        : hasMoreEmployees;
  }

  bool get canGoPrev {
    if (groupBy.isEmpty) {
      return _currentPage > 0;
    }
    return groupBy.first == AttendanceGroupBy.month
        ? _monthOffset > 0
        : _employeeOffset > 0;
  }

  Map<String, List<AttendanceRecord>> get recordsGroupedByMonth {
    final Map<String, List<AttendanceRecord>> grouped = {};
    if (modelManagerAttendanceData == null) return grouped;
    for (final record in modelManagerAttendanceData!.attendanceRecords) {
      if (record.checkIn == null) continue;
      final monthKey = DateFormat('MMMM yyyy').format(record.checkIn!);
      grouped.putIfAbsent(monthKey, () => []);
      grouped[monthKey]!.add(record);
    }
    return grouped;
  }

  Map<String, int> get monthWiseCounts {
    final Map<String, int> temp = {};

    final groups = modelAttendanceGroupByData?.groups ?? [];

    for (final g in groups) {
      final key = g.monthLabel;
      temp[key] = (temp[key] ?? 0) + g.count;
    }

    ///  Sort months DESC (latest first)
    final sortedEntries = temp.entries.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMMM yyyy').parse(a.key);
        final dateB = DateFormat('MMMM yyyy').parse(b.key);
        return dateB.compareTo(dateA); /// DESC
      });

    return Map.fromEntries(sortedEntries);
  }


  Future<void> loadNextPage() async {
    if (groupBy.isEmpty) {
      if (!canGoNext) return;
      _currentPage++;
      await fetchAllAttendances();
      return;
    }

    if (groupBy.first == AttendanceGroupBy.month) {
      await fetchNextMonthGroups();
    } else {
      await fetchEmployeeGroups();
    }
  }

  void toggleDraftGroupBy(AttendanceGroupBy value) {
    if (draftGroupBy.contains(value)) {
      draftGroupBy.remove(value);
    } else {
      draftGroupBy.add(value);
    }
    notifyListeners();
  }

  AttendanceGroupBy mapLabelToGroup(String label) {
    switch (label) {
      case 'Month':
        return AttendanceGroupBy.month;
      case 'Employee':
        return AttendanceGroupBy.employee;
      default:
        throw Exception('Unknown group: $label');
    }
  }

  Future<void> fetchTotalMonthCount() async {
    try {
      final response =
          await ManagerAttendanceDataService.fetchManagerGroupByAttendancesData(
            limit: _groupLimit,
            offset: 0,
            search: currentSearch,
          );

      totalMonthCount = response.groups.length;
      notifyListeners();
    } catch (e) {}
  }

  Future<void> fetchEmployeeGroupsWithDomain({
    required List<dynamic> domain,
    bool reset = false,
  }) async {
    if (isGroupLoading) return;

    if (reset) {
      _groupOffset = 0;
      hasMoreGroups = true;
    }

    isGroupLoading = true;
    notifyListeners();

    try {
      final res =
          await ManagerAttendanceDataService.fetchManagerAttendanceGroupByEmployee(
            limit: _groupLimit,
            offset: _groupOffset,
            search: currentSearch,

            domain: domain,
          );

      modelAttendanceGroupByEmployeeData = res;
      _groupOffset += _groupLimit;
    } catch (e) {}

    isGroupLoading = false;
    notifyListeners();
  }

  Future<void> fetchAttendanceForDomain(List<dynamic> domain) async {
    final key = _domainKey(domain);

    if (_groupAttendanceCache.containsKey(key)) return;
    if (_loadingGroupAttendance.contains(key)) return;

    _loadingGroupAttendance.add(key);
    notifyListeners();

    try {
      final data =
          await ManagerAttendanceDataService.fetchManagerAttendancesData(
            domain: domain,
            search: currentSearch,
          );

      _groupAttendanceCache[key] = data;
    } catch (e) {}

    _loadingGroupAttendance.remove(key);
    notifyListeners();
  }

  ModelManagerAttendanceData? getGroupAttendance(List<dynamic> domain) {
    return _groupAttendanceCache[_domainKey(domain)];
  }

  bool isGroupAttendanceLoading(List<dynamic> domain) {
    return _loadingGroupAttendance.contains(_domainKey(domain));
  }

  Future<void> fetchAttendanceForEmployee({
    required int employeeId,
    required List<dynamic> extraDomain,
  }) async {
    if (_employeeDetailsCache.containsKey(employeeId)) return;

    _loadingEmployees.add(employeeId);
    notifyListeners();

    try {
      final data =
          await ManagerAttendanceDataService.fetchManagerAttendancesData(
            limit: 40,
            domain: [
              ['employee_id', '=', employeeId],
              ...extraDomain,
            ],
            search: currentSearch,
          );

      _employeeDetailsCache[employeeId] = data;
    } catch (e) {
    } finally {
      _loadingEmployees.remove(employeeId);
      notifyListeners();
    }
  }

  void resetDraftFilters() {
    /// draftGroupBy = AttendanceGroupBy.none;
    draftGroupBy.clear();
    groupBy.clear();
    draftFilters.clear();
    activeFilters.clear();
    filterStartDate = null;
    filterEndDate = null;
    draftFilterStartDate = null;
    draftFilterEndDate = null;
    draftSearch = '';
    draftSelectedMonth = null;
    notifyListeners();
  }

  void applyDraftFilters() {
    groupBy = List.from(draftGroupBy);
    activeFilters = {...draftFilters};

    currentSearch = draftSearch;
    selectedMonth = draftSelectedMonth;
    totalMonthGroups = 0;
    totalEmployeeGroups = 0;
    _monthOffset = 0;
    _employeeOffset = 0;
    hasMoreMonths = true;
    hasMoreEmployees = true;

    _groupOffset = 0;
    hasMoreGroups = true;

    /// clear caches
    _monthGroupCache.clear();
    _employeeGroupCache.clear();
    _groupAttendanceCache.clear();
    _loadingGroupNodes.clear();
    _loadingGroupAttendance.clear();

    _monthDetailsCache.clear();
    _employeeDetailsCache.clear();
    _loadingMonths.clear();
    _loadingEmployees.clear();

    if (groupBy.isEmpty) {
      fetchAllAttendances();
    } else {
      fetchRootGroups();
    }
    notifyListeners();
  }

  /// Applies filters, group-by and date range from the filter sheet.
  Future<void> applyFilterAndGroupBy(
    Set<AttendanceFilter> filters,
    Set<AttendanceGroupBy> group,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    activeFilters = {...filters};
    draftFilters = {...filters};
    groupBy = group.toList();
    draftGroupBy = group.toList();
    filterStartDate = startDate;
    filterEndDate = endDate;
    draftFilterStartDate = startDate;
    draftFilterEndDate = endDate;

    totalMonthGroups = 0;
    totalEmployeeGroups = 0;
    _monthOffset = 0;
    _employeeOffset = 0;
    hasMoreMonths = true;
    hasMoreEmployees = true;

    _groupOffset = 0;
    hasMoreGroups = true;

    _monthGroupCache.clear();
    _employeeGroupCache.clear();
    _groupAttendanceCache.clear();
    _loadingGroupNodes.clear();
    _loadingGroupAttendance.clear();

    _monthDetailsCache.clear();
    _employeeDetailsCache.clear();
    _loadingMonths.clear();
    _loadingEmployees.clear();

    if (groupBy.isEmpty) {
      await fetchAllAttendances();
    } else {
      await fetchRootGroups();
    }
    notifyListeners();
  }

  Future<void> fetchRootGroups() async {
    final first = groupBy.first;

    if (first == AttendanceGroupBy.month) {
      _monthOffset = 0;
      hasMoreMonths = true;
      await fetchTotalMonthGroups(); /// month total
      await fetchNextMonthGroups(reset: true);
    } else if (first == AttendanceGroupBy.employee) {
      _employeeOffset = 0;
      hasMoreEmployees = true;

      await fetchTotalEmployeeGroups(domain: baseDomain); /// administrator total
      await fetchEmployeeGroups(reset: true);
    }
  }

///reset filters
  void resetFilters() {
    currentSearch = '';
    searchController.clear();
    _searchDebounce?.cancel();

    /// Restore default grouping
    groupBy = List.from(defaultGroupBy);
    draftGroupBy = List.from(defaultGroupBy);
    activeFilters.clear();
    draftFilters.clear();

    _monthOffset = 0;
    _employeeOffset = 0;
    hasMoreMonths = true;
    hasMoreEmployees = true;

    _monthDetailsCache.clear();
    _employeeDetailsCache.clear();
    _loadingMonths.clear();
    _loadingEmployees.clear();

    fetchRootGroups();
    notifyListeners();
  }

  int get activeFilterCount {
    int count = 0;
    if (groupBy.isNotEmpty) {
      count += groupBy.length;
    }
    if (selectedMonth != null) {
      count++;
    }
    count += activeFilters.length;
    if (filterStartDate != null || filterEndDate != null) {
      count++;
    }
    return count;
  }

  String get filterLabel {
    final count = activeFilterCount;

    if (count == 0) {
      return 'No filters applied';
    }

    if (count == 1) {
      return '1 filter applied';
    }

    return '$count filters applied';
  }



  Future<void> fetchAllAttendances({bool silent = false}) async {
    if (!silent) {

      isLoading = true;
      notifyListeners();
    }

    try {
      final domain = baseDomain;

      ///Get TOTAL COUNT
      totalAttendanceCount =
          await ManagerAttendanceDataService.fetchManagerAttendanceCount(
            domain: domain,
            search: currentSearch,
          );

      /// Get PAGINATED DATA
      final res =
          await ManagerAttendanceDataService.fetchManagerAttendancesData(
            domain: domain,
            limit: pageSize,
            offset: _currentPage * pageSize,
            search: currentSearch,
          );

      modelManagerAttendanceData = res;

      for (
        int i = 0;
        i < (modelManagerAttendanceData?.attendanceRecords.length ?? 0);
        i++
      ) {
        final r = modelManagerAttendanceData!.attendanceRecords[i];
      }
    } catch (e) {}

    if (!silent) {
      isLoading = false;
      notifyListeners();
    }
  }



  void prepareDraftFilters() {
    draftGroupBy = List.from(groupBy);
    draftFilters = {...activeFilters};
    draftFilterStartDate = filterStartDate;
    draftFilterEndDate = filterEndDate;
    draftSearch = currentSearch;
    draftSelectedMonth = selectedMonth;
  }

  Future<void> fetchEmployeeGroups({bool reset = false}) async {
    if (isGroupLoading || !hasMoreEmployees) return;

    if (reset) {
      _employeeOffset = 0;
      hasMoreEmployees = true;

    }

    isGroupLoading = true;
    notifyListeners();

    try {
      final res =
          await ManagerAttendanceDataService.fetchManagerAttendanceGroupByEmployee(
            limit: employeeGroupLimit,
            offset: _employeeOffset,
            search: currentSearch,
            domain: baseDomain,
          );

      if (res.groups.isEmpty) {
        hasMoreEmployees = false;
      } else {
        _employeeOffset += employeeGroupLimit;
        modelAttendanceGroupByEmployeeData = res;
      }

    } catch (e) {
    } finally {
      isGroupLoading = false;
      notifyListeners();
    }
  }


  String get pageCountLabel {
    if (groupBy.isEmpty) {
      if (totalAttendanceCount == 0) return '0-0/0';

      final from = (_currentPage * pageSize) + 1;
      final to = ((_currentPage + 1) * pageSize).clamp(1, totalAttendanceCount);

      return '$from-$to/$totalAttendanceCount';
    }

    /// grouped logic unchanged
    if (groupBy.first == AttendanceGroupBy.month) {
      if (totalMonthGroups == 0) return '0-0/0';

      final from = _monthOffset == 0 ? 1 : _monthOffset - monthGroupLimit + 1;
      final to = _monthOffset.clamp(1, totalMonthGroups);

      return '$from-$to/$totalMonthGroups';
    } else {
      if (totalEmployeeGroups == 0) return '0-0/0';

      final from = _employeeOffset == 0
          ? 1
          : _employeeOffset - employeeGroupLimit + 1;
      final to = _employeeOffset.clamp(1, totalEmployeeGroups);

      return '$from-$to/$totalEmployeeGroups';
    }
  }


  Future<void> loadPrevPage() async {
    if (isGroupLoading) return;

    if (groupBy.isEmpty) {
      if (_currentPage == 0) return;
      _currentPage--;
      await fetchAllAttendances();
      return;
    }

    isGroupLoading = true;
    notifyListeners();

    try {
      if (groupBy.first == AttendanceGroupBy.month) {
        if (_monthOffset <= monthGroupLimit) return;

        _monthOffset = (_monthOffset - monthGroupLimit).clamp(
          0,
          totalMonthCount,
        );

        modelAttendanceGroupByData =
            await ManagerAttendanceDataService.fetchManagerGroupByAttendancesData(
              limit: monthGroupLimit,
              offset: _monthOffset - monthGroupLimit,
              search: currentSearch,
            );
      } else {
        if (_employeeOffset <= employeeGroupLimit) return;

        _employeeOffset = (_employeeOffset - employeeGroupLimit).clamp(
          0,
          _employeeOffset,
        );

        modelAttendanceGroupByEmployeeData =
            await ManagerAttendanceDataService.fetchManagerAttendanceGroupByEmployee(
              limit: employeeGroupLimit,
              offset: _employeeOffset - employeeGroupLimit,
              search: currentSearch,
            );
      }
    } finally {
      isGroupLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAttendanceForGroup({
    required String monthLabel,
    required List<dynamic> extraDomain,
  }) async {
    _loadingMonths.add(monthLabel);

    notifyListeners();

    try {
      final data =
          await ManagerAttendanceDataService.fetchManagerAttendancesData(
            domain: extraDomain,
            search: currentSearch,

          );

      _monthDetailsCache[monthLabel] = data;

    } catch (e) {}
    _loadingMonths.remove(monthLabel);

    notifyListeners();
  }

  Future<void> fetchAttendanceForMonth(List<dynamic> domain) async {
    isLoading = true;
    notifyListeners();

    try {
      modelManagerAttendanceData =
          await ManagerAttendanceDataService.fetchManagerAttendancesData(
            domain: domain,
          );
    } catch (e) {}

    isLoading = false;
    notifyListeners();
  }

  String formatTimeAMPM(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('hh:mm a').format(date);
  }

  String formatWorkedHours(double hours) {
    if (hours <= 0) return '00:00';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String getMonthLabel(dynamic value) {
    if (value == null) return '-';

    /// Odoo may return List [value, label]
    if (value is List && value.length > 1) {
      return value[1].toString();
    }

    /// Or String directly
    if (value is String) {
      return value;
    }

    return '-';
  }

  Future<void> fetchNextMonthGroups({bool reset = false}) async {
    if (isGroupLoading || !hasMoreMonths) return;

    if (reset) {
      _monthOffset = 0;
      hasMoreMonths = true;
      _groupOffset = 0;
      hasMoreGroups = true;
      modelAttendanceGroupByData = null;
      _monthDetailsCache.clear();
    }

    isGroupLoading = true;
    notifyListeners();

    try {
      final response =
          await ManagerAttendanceDataService.fetchManagerGroupByAttendancesData(
            limit: monthGroupLimit,
            offset: _monthOffset,
            search: currentSearch,
            domain: baseDomain,
          );

      if (response.groups.isEmpty) {

        hasMoreMonths = false;
      } else {
        _monthOffset += monthGroupLimit;

        modelAttendanceGroupByData = response;


      }
    } catch (e) {
    } finally {
      isGroupLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadEmployeeImage(int employeeId) async {
    if (_employeeImageCache.containsKey(employeeId)) return;

    final base64Image =
        await ManagerAttendanceDataService.fetchEmployeeUserProfileImage(
          employeeId,
        );

    if (base64Image != null && base64Image.isNotEmpty) {
      _employeeImageCache[employeeId] = base64Decode(base64Image);
    } else {
      _employeeImageCache[employeeId] = null;
    }
    notifyListeners();
  }

  Future<void> refreshPage() async {
    isLoading = true;

    totalMonthGroups = 0;
    totalEmployeeGroups = 0;
    /// clear caches
    _monthGroupCache.clear();
    _employeeGroupCache.clear();
    _groupAttendanceCache.clear();
    _loadingGroupNodes.clear();
    _loadingGroupAttendance.clear();

    _groupOffset = 0;
    hasMoreGroups = true;
    modelManagerAttendanceData = null;
    _monthDetailsCache.clear();
    _employeeDetailsCache.clear();
    _loadingMonths.clear();
    _loadingEmployees.clear();
    notifyListeners();

    if (groupBy.isEmpty) {
      await fetchAllAttendances();
    } else {
      await fetchRootGroups();
    }

    isLoading = false;
    notifyListeners();
  }

  void loadData() {
    groupBy = List.from(defaultGroupBy);
    draftGroupBy = List.from(defaultGroupBy);
    notifyListeners();
  }

  Future<void> initialLoad() async {
    if (initialLoadDone) return;
    initialLoadDone = true;

    try {
      await _ensureCurrentUser();
      await setInitialGroupByByVersion();

      await fetchRootGroups();
    } finally {
      // Always clear, even on error, so the shimmer can't get stuck.
      isFirstLoad = false;
      notifyListeners();
    }
  }

  ///  Usually also required
  void clearSearch() {
    searchController.clear();
    currentSearch = '';
    _searchDebounce?.cancel();

    _monthDetailsCache.clear();
    _employeeDetailsCache.clear();
    _loadingMonths.clear();
    _loadingEmployees.clear();

    if (groupBy.isEmpty) {
      fetchAllAttendances();
    } else {
      fetchRootGroups();
    }

    notifyListeners();
  }

  Future<void> clearAllFilters() async {
    ///  RESET TO DEFAULT, NOT EMPTY
    /// groupBy = List.from(defaultGroupBy);
    /// draftGroupBy = List.from(defaultGroupBy);
    activeFilters.clear();
    draftFilters.clear();
    filterStartDate = null;
    filterEndDate = null;
    draftFilterStartDate = null;
    draftFilterEndDate = null;

    currentSearch = '';
    draftSearch = '';
    selectedMonth = null;
    draftSelectedMonth = null;

    searchController.clear();
    _searchDebounce?.cancel();

    _monthOffset = 0;
    _employeeOffset = 0;
    hasMoreMonths = true;
    hasMoreEmployees = true;

    totalMonthGroups = 0;
    totalEmployeeGroups = 0;

    _monthGroupCache.clear();
    _employeeGroupCache.clear();
    _groupAttendanceCache.clear();
    _loadingGroupNodes.clear();
    _loadingGroupAttendance.clear();

    _monthDetailsCache.clear();
    _employeeDetailsCache.clear();
    _loadingMonths.clear();
    _loadingEmployees.clear();

    notifyListeners();


  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void clearOnManagerLogout() {
    /// Cancel timers
    _searchDebounce?.cancel();
    _searchDebounce = null;

    /// Search
    searchController.clear();
    currentSearch = '';
    draftSearch = '';

    /// Filters
    groupBy.clear();
    draftGroupBy.clear();
    activeFilters.clear();
    draftFilters.clear();
    filterStartDate = null;
    filterEndDate = null;
    draftFilterStartDate = null;
    draftFilterEndDate = null;
    selectedMonth = null;
    draftSelectedMonth = null;
    currentUserId = null;

    /// Pagination
    _currentPage = 0;
    _groupOffset = 0;
    _monthOffset = 0;
    _employeeOffset = 0;

    hasMoreGroups = true;
    hasMoreMonths = true;
    hasMoreEmployees = true;

    /// Totals
    totalAttendanceCount = 0;
    totalMonthCount = 0;
    totalMonthGroups = 0;
    totalEmployeeGroups = 0;

    /// Loading states
    isLoading = false;
    isGroupLoading = false;

    /// API models
    modelAttendanceGroupByData = null;
    modelAttendanceGroupByEmployeeData = null;
    modelManagerAttendanceData = null;

    /// Caches
    _monthGroupCache.clear();
    _employeeGroupCache.clear();
    _groupAttendanceCache.clear();
    _monthDetailsCache.clear();
    _employeeDetailsCache.clear();

    /// Loading trackers
    _loadingGroupNodes.clear();
    _loadingGroupAttendance.clear();
    _loadingMonths.clear();
    _loadingEmployees.clear();

    /// Image cache
    _employeeImageCache.clear();

    /// Lifecycle
    initialLoadDone = false;

    notifyListeners();
  }


}
