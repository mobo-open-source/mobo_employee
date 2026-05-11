import 'package:flutter/material.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/manager/manager_employees/model/model_fetch_manager_employee_details.dart';
import 'package:mobo_employees/features/manager/manager_employees/service/manager_employees_data_service.dart';

enum EmployeeFilter { atWork, absent, myTeam, myDepartment }

class ManagerEmployeesProvider extends ChangeNotifier {
  final TextEditingController searchEmployeeController =
      TextEditingController();

  static int? currentUserId;

  ModelManagerEmployeesResponse? modelManagerEmployeesResponse;

  String? errorMessage;

  int currentPage = 1;
  final int pageSize = 40;
  int totalRecords = 0;

  int get startCount =>
      totalRecords == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;
  int get endCount {
    final end = currentPage * pageSize;
    return end > totalRecords ? totalRecords : end;
  }

  String get paginationText =>
      totalRecords == 0 ? '0/0' : '$startCount–$endCount / $totalRecords';
  int get totalPages =>
      totalRecords == 0 ? 1 : (totalRecords / pageSize).ceil();

  bool get canGoPrevious => currentPage > 1;
  bool get canGoNext => currentPage < totalPages;
  bool initialLoading = false;
  bool isLoading = false;

  List<ModelFetchManagerEmployeeDetails> employees = [];

  Set<EmployeeFilter> activeFilters = {};
  Set<EmployeeFilter> draftFilters = {};

  bool _isAttendanceFilter(EmployeeFilter f) =>
      f == EmployeeFilter.atWork || f == EmployeeFilter.absent;

  bool _isScopeFilter(EmployeeFilter f) =>
      f == EmployeeFilter.myTeam || f == EmployeeFilter.myDepartment;

  changeInitialLoading() {
    initialLoading = true;
    notifyListeners();
  }

  static Future<Map<String, dynamic>> callKwWithCompany() async {
    final client = await OdooSessionManager.getClient();
    currentUserId = client!.sessionId?.userId;
    return callKwWithCompany();
  }

  final Map<EmployeeFilter, List<dynamic>> filterDomains = {
    EmployeeFilter.atWork: ["is_absent", "=", false],
    EmployeeFilter.absent: ["hr_presence_state_display", "=", "absent"],
    EmployeeFilter.myDepartment: ["member_of_department", "=", true],
  };



  List<dynamic> buildDomain() {
    final attendanceConditions = <List<dynamic>>[];
    final scopeConditions = <List<dynamic>>[];

    for (final filter in activeFilters) {
      List<dynamic>? condition;

      if (filter == EmployeeFilter.myTeam) {
        condition = ["parent_id.user_id", "=", currentUserId];
      } else {
        condition = filterDomains[filter];
      }

      if (condition == null) continue;

      if (_isAttendanceFilter(filter)) {
        attendanceConditions.add(condition);
      } else if (_isScopeFilter(filter)) {
        scopeConditions.add(condition);
      }
    }

    final domain = <dynamic>[];

    if (attendanceConditions.isNotEmpty) {
      for (int i = 0; i < attendanceConditions.length - 1; i++) {
        domain.add('|');
      }
      domain.addAll(attendanceConditions);
    }

    if (scopeConditions.isNotEmpty) {
      if (domain.isNotEmpty) domain.insert(0, '&');
      for (int i = 0; i < scopeConditions.length - 1; i++) {
        domain.add('|');
      }
      domain.addAll(scopeConditions);
    }

    return domain;
  }

  /// Pagination

  void nextPage() {
    if (!canGoNext) return;
    currentPage++;
    fetchEmployees();
  }

  void previousPage() {
    if (!canGoPrevious) return;
    currentPage--;
    fetchEmployees();
  }

  ///  NO client-side filtering

  List<dynamic> _buildOrDomain(List<List<dynamic>> conditions) {
    if (conditions.isEmpty) return [];
    if (conditions.length == 1) {
      return conditions.first;
    }
    final domain = <dynamic>[];
    for (int i = 0; i < conditions.length - 1; i++) {
      domain.add('|');
    }
    domain.addAll(conditions);
    return domain;
  }


  Future<void> fetchEmployees({bool reset = false, String search = ''}) async {
    final client = await OdooSessionManager.getClient();
    currentUserId = client?.sessionId?.userId;
    if (reset) {
      if (reset) currentPage = 1;
      notifyListeners();
    }
    employees.clear();
    final offset = (currentPage - 1) * pageSize;
    isLoading = true;
    notifyListeners();

    try {
      final response = await ManagerEmployeesDataService.fetchAllEmployees(
        domain: buildDomain(),
        offset: offset,
        search: search,
        limit: pageSize,
      );
      employees.clear();
      notifyListeners();
      employees.addAll(response.employees);
      totalRecords = await ManagerEmployeesDataService.fetchAllEmployeesCount(
        domain: buildDomain(),
        search: search,
      );
    } catch (e) {
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void prepareDraftFilters() {
    draftFilters = {...activeFilters};
  }

  String get filterLabel {
    if (activeFilters.isEmpty) return "No filters applied";
    return "${activeFilters.length} Active filters";
  }

  void toggleDraftFilter(EmployeeFilter filter) {
    if (draftFilters.contains(filter)) {
      draftFilters.remove(filter);
    } else {
      draftFilters.add(filter);
    }
    notifyListeners();
  }

  void applyDraftFilters() {
    activeFilters = {...draftFilters};
    fetchEmployees(reset: true);
  }

  void clearAllFilters() {
    activeFilters.clear();
    draftFilters.clear();
    fetchEmployees(reset: true);
  }

  void clearOnManagerLogout() {
    /// User session
    currentUserId = null;

    /// Search
    searchEmployeeController.clear();

    /// Filters
    activeFilters.clear();
    draftFilters.clear();

    /// Data
    employees.clear();
    modelManagerEmployeesResponse = null;

    /// Pagination
    currentPage = 1;
    totalRecords = 0;

    /// States
    initialLoading = false;
    isLoading = false;
    errorMessage = null;

    notifyListeners();
  }



  void updateSearch(String value) {
    fetchEmployees(reset: true, search: value);
  }

  void clearSearch() {
    searchEmployeeController.clear();
    fetchEmployees(reset: true);
  }

  Future<void> refreshEmployees() async {
    await fetchEmployees(reset: true);
  }
}
