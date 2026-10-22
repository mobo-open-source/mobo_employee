import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobo_employees/core/exceptions/odoo_error_mapper.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/core/services/user_access_service.dart';
import 'package:mobo_employees/core/utils/date_range_validator.dart';
import 'package:mobo_employees/features/employee/leave/model/model_time_off_balance.dart';
import 'package:mobo_employees/features/employee/leave/service/leave_service.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_allocation_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_leave_calendar_event.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_employees.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_time_off_type.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_timeoff_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/services/manager_calendar_service.dart';
import 'package:mobo_employees/features/employee/attendance/service/administrator_attendance_service.dart';
import 'package:mobo_employees/shared/widgets/snackbars/custom_snackbar.dart';
import 'package:mobo_employees/core/const/keys/global_keys.dart';
import 'package:mobo_employees/shared/services/time_off_type_service.dart';

/// State holder for the manager-side leave approvals feature.
///
/// Backs three tabs (calendar, time-off requests, allocations) with data from
/// [ManagerCalendarService], owns the form state for the "add time off" flow
/// (employee/leave-type pickers, date range, attachment), and tracks per-row
/// loading flags so the UI can show spinners on individual approve/refuse
/// actions without blocking the rest of the list.
class ManagerApprovalsProvider extends ChangeNotifier {
  int _selectedTabIndex = 0;
  int? serverMajorVersion;
  int? selectedEmployeeId;

  List<TimeOffBalance> _timeOffBalances = [];
  int _pendingAllocationCount = 0;

  /// Whether the last read of the balance cards failed (and none has
  /// succeeded since). The cards on screen are then the last good ones, or
  /// none at all.
  bool _timeOffDataFailed = false;

  /// Numbers the balance reads, so that when two overlap (page entry, pull
  /// to refresh, an approval) only the newest one may update the cards.
  int _timeOffDataRequest = 0;

  bool _isLoading = false;
  bool _isInitialLoadDone = false;
  bool _isTimeOffInitialLoaded = false;
  bool _isCalendarInitialLoaded = false;
  bool _isTimeOffLoading = false;
  bool _isCalendarLoading = false;
  bool _isSaveMyTimeOffLoading = false;
  bool _isAllocationLoading = false;
  bool _isEmployeesLoading = false;

  /// Set when the last full load of the Calendar tab (events, balance cards,
  /// unusual days) failed, e.g. server unreachable; the tab shows it in
  /// place of its content until a retry succeeds.
  Object? loadError;

  /// Set when the last load of the Time Off tab's request list failed; the
  /// tab shows it in place of the list until a retry succeeds.
  Object? timeOffLoadError;

  /// Set when the last load of the Allocation tab's list failed; the tab
  /// shows it in place of the list until a retry succeeds.
  Object? allocationLoadError;

  File? _attachedFile;
  File? get attachedFile => _attachedFile;

  TextEditingController employeeController = TextEditingController();
  TextEditingController departmentController = TextEditingController();
  TextEditingController leaveTypeController = TextEditingController();
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();

  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;
  DateTime? fromDate;
  DateTime? toDate;

  String? _attachedFileName;
  String? get attachedFileName => _attachedFileName;

  final Map<int, Uint8List?> _employeeImageCache = {};
  final Map<DateTime, bool> _unusualDays = {};
  final Set<int> _validatingIds = {};
  final Set<int> _refusingIds = {};

  LeaveCalendarEvent? leaveCalendarEvent;

  final List<ModelTimeOffData> _timeOffList = [];
  final List<ModelAllocationData> _allocationList = [];
  final List<LeaveCalendarEvent> _calendarEvents = [];
  List<Employee> _employees = [];
  List<ModelTimeOffAddTimeOffType> _leaveTypes = [];

  /// Returns the cached avatar bytes for [userId], or `null` if not loaded yet
  /// or the employee has no image. Use [loadEmployeeImage] to populate.
  Uint8List? getEmployeeImage(int userId) => _employeeImageCache[userId];

  /// Whether an approve/validate call is currently in flight for [leaveId].
  bool isValidating(int leaveId) => _validatingIds.contains(leaveId);

  /// Whether a refuse call is currently in flight for [leaveId].
  bool isRefusing(int leaveId) => _refusingIds.contains(leaveId);

  bool get isLoading => _isLoading;
  bool get isInitialLoadDone => _isInitialLoadDone;
  bool get isTimeOffInitialLoaded => _isTimeOffInitialLoaded;
  bool get isTimeOffLoading => _isTimeOffLoading;
  bool get isCalendarLoading => _isCalendarLoading;
  bool get isSaveMyTimeOffLoading => _isSaveMyTimeOffLoading;
  bool get isAllocationLoading => _isAllocationLoading;
  bool get isEmployeesLoading => _isEmployeesLoading;

  int get selectedTabIndex => _selectedTabIndex;

  /// The signed-in user's own balance per time off type, as on Odoo's
  /// Time Off dashboard.
  List<TimeOffBalance> get timeOffBalances => _timeOffBalances;

  /// Odoo's "Pending Allocations": the user's own allocation requests
  /// awaiting approval.
  int get pendingAllocationCount => _pendingAllocationCount;

  /// True when the balance cards couldn't be read, so the page shows a retry
  /// in their place rather than silently showing nothing.
  bool get timeOffDataFailed => _timeOffDataFailed;

  List<ModelTimeOffData> get timeOffList => _timeOffList;
  List<LeaveCalendarEvent> get calendarEvents => _calendarEvents;
  List<Employee> get employees => _employees;
  List<ModelTimeOffAddTimeOffType> get leaveTypes => _leaveTypes;
  List<ModelAllocationData> get allocationList => _allocationList;

  Map<DateTime, bool> get unusualDays => _unusualDays;

  DateTime get currentMonth => _currentMonth;
  DateTime? get selectedDate => _selectedDate;

  /// Advances the calendar by one month and refetches its events.
  Future<void> goToNextMonth() async {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    await _fetchMonthEvents();
  }

  /// Moves the calendar back one month and refetches its events.
  Future<void> goToPreviousMonth() async {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    await _fetchMonthEvents();
  }

  /// Fetches the events of the month just navigated to; if the server
  /// can't be reached the Calendar tab shows [loadError] instead of an
  /// empty month.
  Future<void> _fetchMonthEvents() async {
    try {
      await fetchLeaveCalendarEventsFunction();
    } catch (e) {
      loadError = e;
      notifyListeners();
    }
  }

  /// Switches the active tab and lazy-loads its data on first visit.
  ///
  /// No-op if [index] equals the current tab. The time-off tab (1) is
  /// fetched once and gated by [_isTimeOffInitialLoaded], or again after a
  /// failed load; the allocations tab (2) is refetched every time it is
  /// selected.
  void setTab(int index) {
    if (_selectedTabIndex == index) return;
    _selectedTabIndex = index;
    if (index == 1 && (!_isTimeOffInitialLoaded || timeOffLoadError != null)) {
      fetchTimeOffDetails();
      _isTimeOffInitialLoaded = true;
    }
    if (index == 2) {
      fetchAllocationDetails();
    }
    notifyListeners();
  }

  /// Loads "unusual days" (e.g. public holidays / non-working days) into
  /// [unusualDays] for calendar shading. Failures clear nothing and are
  /// swallowed, except an unreachable server, which is rethrown.
  Future<void> fetchUnusualDays() async {
    try {
      final service = AdministratorAttendanceService();
      final result = await service.fetchUnusualDays();
      _unusualDays.clear();
      if (result != null) {
        for (final day in result.records) {
          _unusualDays[day.date] = day.isUnusual;
        }
      }
      notifyListeners();
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
    }
  }

  /// Loads the manager's own Time Off dashboard figures: a balance per time
  /// off type and the pending allocation requests count.
  ///
  /// Set [showLoader] to `false` for background refreshes that should not
  /// flip the page-level spinner. A failed read never wipes the cards: it
  /// keeps the last good figures and raises [timeOffDataFailed], and a read
  /// that was overtaken by a newer one is dropped. An unreachable server is
  /// rethrown and leaves everything as it was.
  Future<void> fetchTimeOffData({bool showLoader = true}) async {
    final request = ++_timeOffDataRequest;
    if (showLoader) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final dashboard = await _readTimeOffDashboard();
      if (request != _timeOffDataRequest) return;
      _timeOffBalances = dashboard.balances;
      _pendingAllocationCount = dashboard.pendingAllocations;
      _timeOffDataFailed = false;
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      if (request == _timeOffDataRequest) _timeOffDataFailed = true;
    } finally {
      if (showLoader) _isLoading = false;
      notifyListeners();
    }
  }

  /// Reads the dashboard, trying once more after a short pause: on entering
  /// the page several calls start together, and when the session needs
  /// renewing one of them can fail while another renews it.
  Future<TimeOffDashboard> _readTimeOffDashboard() async {
    try {
      return await _readDashboard();
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      await Future.delayed(_timeOffRetryDelay);
      return _readDashboard();
    }
  }

  /// The retry offered when the balance cards failed to load.
  Future<void> retryTimeOffData() async {
    _timeOffDataFailed = false;
    _isLoading = true;
    notifyListeners();
    try {
      await fetchTimeOffData(showLoader: false);
    } catch (_) {
      /// Unreachable server: the cards stay as they were, still marked failed.
      _timeOffDataFailed = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches calendar events, summary counters, and unusual days in
  /// parallel behind the page loader the first time; later calls (the page
  /// being shown again) refresh in place via [_refreshInPlace]. After a
  /// failed load ([loadError] set), every call retries the full load.
  Future<void> loadInitialData() async {
    if (_isInitialLoadDone && loadError == null) {
      /// Returning to Approvals: requests may have been created, approved
      /// or refused (here or in Odoo) since the counters were read.
      try {
        await _refreshInPlace();
      } catch (_) {
        /// In-place refresh: figures that couldn't be re-read (server
        /// unreachable) keep their last loaded values.
      }
      return;
    }

    _isInitialLoadDone = true;
    _isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      await Future.wait([
        fetchLeaveCalendarEventsFunction(showLoader: true),
        fetchTimeOffData(showLoader: false),
        fetchUnusualDays(),
        _loadAllocationAccess(),
      ]);
    } catch (e) {
      loadError = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refetches calendar, summary, and unusual days without showing a
  /// page-level loader — intended for pull-to-refresh. Also reloads the
  /// request list of the tab on screen. If the server can't be reached,
  /// the Calendar tab shows [loadError] as after a failed initial load.
  Future<void> refreshAll() async {
    try {
      await _refreshInPlace();
    } catch (e) {
      loadError = e;
      notifyListeners();
    }
  }

  /// Re-reads the Calendar tab's events, cards and unusual days, plus the
  /// request list of the tab on screen, without any loader. Rethrows when
  /// the server can't be reached; the request lists record their own
  /// failure instead.
  Future<void> _refreshInPlace() async {
    await Future.wait([
      fetchLeaveCalendarEventsFunction(showLoader: false),
      fetchTimeOffData(showLoader: false),
      fetchUnusualDays(),
      if (_selectedTabIndex == 1) fetchTimeOffDetails(),
      if (_selectedTabIndex == 2) fetchAllocationDetails(),
    ]);
    notifyListeners();
  }

  /// Re-reads what the Calendar tab shows — the Paid Time Off /
  /// Compensatory / Pending cards and the per-day events — after any change
  /// that moves them: a request or allocation created, approved or refused.
  Future<void> _refreshCalendarCounts() async {
    try {
      await Future.wait([
        fetchLeaveCalendarEventsFunction(showLoader: false),
        fetchTimeOffData(showLoader: false),
      ]);
    } catch (_) {
      /// In-place refresh after an action: figures that couldn't be re-read
      /// (server unreachable) keep their last loaded values, and the
      /// action's own result is still reported.
    }
    notifyListeners();
  }

  bool _canCreateAllocation = false;

  /// Whether this user may create allocations — Time Off Officer or above,
  /// who gets the "New" button on Odoo's Allocations list.
  bool get canCreateAllocation => _canCreateAllocation;

  Future<void> _loadAllocationAccess() async {
    _canCreateAllocation = await UserAccessService.hasGroup(
      UserAccessService.timeOffOfficer,
    );
    notifyListeners();
  }

  /// Call after an allocation was created from the app.
  Future<void> onAllocationCreated() async {
    await Future.wait([fetchAllocationDetails(), _refreshCalendarCounts()]);
  }

  /// Populates [employees] with the list the manager can create time-off for.
  ///
  /// [isEmployeesLoading] keeps the employee picker disabled until this
  /// completes — otherwise a tap during a slow fetch caches an empty
  /// suggestion list in the typeahead that never refreshes.
  Future<void> fetchEmployees() async {
    if (_isEmployeesLoading) return;
    _isEmployeesLoading = true;
    notifyListeners();
    try {
      final data =
          await ManagerCalendarService.fetchManagerAddTimeOffEmployees();
      _employees = data;
    } catch (_) {
    } finally {
      _isEmployeesLoading = false;
      notifyListeners();
    }
  }

  /// Loads leave types valid for [selectedEmployeeId] into [leaveTypes].
  ///
  /// Must be called only after an employee is selected — dereferences
  /// [selectedEmployeeId] without a null check.
  Future<void> fetchLeaveTypes() async {
    try {
      final data =
          await ManagerCalendarService.fetchLeaveTypesByEmployeeInAddTimeOff(
            employeeId: selectedEmployeeId!.toInt(),
          );
      _leaveTypes = data;
      notifyListeners();
    } catch (_) {}
  }

  /// Resets the from/to date fields and their controllers to today.
  void setDefaultDates() {
    final now = DateTime.now();
    fromDate = now;
    toDate = now;
    fromDateController.text = _formatDate(now);
    toDateController.text = _formatDate(now);
    notifyListeners();
  }

  /// Fetches calendar events for the month covering [_currentMonth] and
  /// stores them in [calendarEvents].
  ///
  /// Re-entrancy guard: returns immediately if a fetch is already in flight.
  /// Pass [showLoader] = `false` for silent background refreshes. On error
  /// the existing event list is cleared; an unreachable server is rethrown
  /// and leaves it as it was.
  Future<void> fetchLeaveCalendarEventsFunction({
    bool showLoader = true,
  }) async {
    if (_isCalendarLoading) return;

    if (showLoader) {
      _isCalendarLoading = true;
      notifyListeners();
    }

    try {
      final from = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final to = DateTime(
        _currentMonth.year,
        _currentMonth.month + 1,
        0,
        23,
        59,
      );
      final events = await ManagerCalendarService.fetchLeaveCalendarEvents(
        from: from,
        to: to,
      );
      _calendarEvents
        ..clear()
        ..addAll(events);
      _isCalendarInitialLoaded = true;
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      _calendarEvents.clear();
    } finally {
      if (showLoader) {
        _isCalendarLoading = false;
        notifyListeners();
      }
    }
  }

  /// Initialises [fromDate] / [toDate] to today only if they aren't already
  /// set. Unlike [setDefaultDates], this preserves any user selection.
  void initDefaultDates() {
    if (fromDate == null || toDate == null) {
      final now = DateTime.now();
      fromDate = now;
      toDate = now;
      fromDateController.text = _formatDate(now);
      toDateController.text = _formatDate(now);
    }
  }

  /// Reads the active Odoo server version and caches the major component in
  /// [serverMajorVersion] for version-gated UI/RPC behavior.
  Future<void> loadServerVersion() async {
    final client = await OdooSessionManager.getClient();
    final version = client!.sessionId!.serverVersion;
    serverMajorVersion = int.parse(version.split('.').first);
    notifyListeners();
  }

  /// Loads the pending time-off requests visible to this manager into
  /// [timeOffList]. Toggles [isTimeOffLoading]; on error clears the list
  /// and records the failure in [timeOffLoadError]. Never throws.
  Future<void> fetchTimeOffDetails() async {
    try {
      _isTimeOffLoading = true;
      timeOffLoadError = null;
      notifyListeners();
      final data = await ManagerCalendarService.fetchLeaveTimeOffDetails();
      _timeOffList
        ..clear()
        ..addAll(data);
      await _preloadEmployeeImages(_timeOffList.map((e) => e.employeeId));
      _isTimeOffInitialLoaded = true;
    } catch (e) {
      _timeOffList.clear();
      timeOffLoadError = e;
    } finally {
      _isTimeOffLoading = false;
      notifyListeners();
    }
  }

  /// Turns a raw RPC failure into something worth showing the user.
  String _readableActionError(Object e) {
    return OdooErrorMapper.serverMessage(
      e,
      fallback: 'Failed to update the request. Please try again.',
    );
  }

  /// Shows a snackbar via the app's global `navigatorKey` rather than a
  /// row's local `context`, since the list rebuilds into its loading state
  /// (disposing row contexts) before this is reached.
  void _showActionSnack({required bool success, required String message}) {
    final navContext = navigatorKey.currentContext;
    if (navContext == null) return;
    if (success) {
      CustomSnackbar.showSuccess(navContext, message);
    } else {
      CustomSnackbar.showError(navContext, message);
    }
  }

  /// Approves the leave request [leaveId] and refreshes the list.
  ///
  /// Picks the right Odoo action based on [state]: `validate1` calls
  /// `action_validate` (final approval), anything else calls
  /// `action_approve` (manager approval, may still need second-level
  /// validation). Re-entrancy is guarded via [_validatingIds] so the per-row
  /// spinner only triggers once.
  Future<void> validateTimeOff(BuildContext context, int leaveId, String state) async {
    if (_validatingIds.contains(leaveId)) return;
    _validatingIds.add(leaveId);
    notifyListeners();
    try {
      if (state == "validate1") {
        await ManagerCalendarService.actionValidate(leaveId);
      } else {
        await ManagerCalendarService.actionApprove(leaveId);
      }
      await Future.wait([fetchTimeOffDetails(), _refreshCalendarCounts()]);
      _showActionSnack(success: true, message: 'Time off request approved');
    } catch (e) {
      _showActionSnack(success: false, message: _readableActionError(e));
    } finally {
      _validatingIds.remove(leaveId);
      notifyListeners();
    }
  }

  /// Refuses the leave request [leaveId] and refreshes the list.
  /// Guarded against double-tap via [_refusingIds].
  Future<void> refuseTimeOff(BuildContext context, int leaveId) async {
    if (_refusingIds.contains(leaveId)) return;
    _refusingIds.add(leaveId);
    notifyListeners();
    try {
      await ManagerCalendarService.actionRefuse(leaveId);
      await Future.wait([fetchTimeOffDetails(), _refreshCalendarCounts()]);
      _showActionSnack(success: true, message: 'Time off request refused');
    } catch (e) {
      _showActionSnack(success: false, message: _readableActionError(e));
    } finally {
      _refusingIds.remove(leaveId);
      notifyListeners();
    }
  }

  /// Loads the manager's allocation requests into [allocationList] and
  /// kicks off avatar fetches for any employee not yet cached. On error
  /// clears the list and records the failure in [allocationLoadError].
  /// Never throws.
  Future<void> fetchAllocationDetails() async {
    try {
      _isAllocationLoading = true;
      allocationLoadError = null;
      notifyListeners();

      final data =
          await ManagerCalendarService.fetchManagerLeaveAllocationDetailsView();
      _allocationList
        ..clear()
        ..addAll(data);
      await _preloadEmployeeImages(_allocationList.map((e) => e.employeeId));
    } catch (e) {
      _allocationList.clear();
      allocationLoadError = e;
    } finally {
      _isAllocationLoading = false;
      notifyListeners();
    }
  }

  /// Opens the system file picker and stores the chosen file in
  /// [attachedFile] / [attachedFileName] for upload with the leave request.
  /// No-op if the user cancels or an error occurs.
  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        _attachedFile = File(result.files.single.path!);
        _attachedFileName = result.files.single.name;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Reads the balance cards' figures; swapped out in tests.
  final Future<TimeOffDashboard> Function() _readDashboard;

  /// The manager's own balances, with the "Pending" figure replaced by the
  /// allocation requests awaiting approval in the Allocation tab — Odoo's
  /// own figure counts only the manager's own requests. If that count can't
  /// be read, Odoo's figure stays.
  static Future<TimeOffDashboard> _readDashboardWithTeamPending() async {
    final dashboard = await LeaveService.fetchMyTimeOffDashboard();
    try {
      return TimeOffDashboard(
        balances: dashboard.balances,
        pendingAllocations:
            await ManagerCalendarService.fetchPendingAllocationCount(),
      );
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return dashboard;
    }
  }

  /// Pause before the single retry of a failed balance read.
  final Duration _timeOffRetryDelay;

  /// Creates the provider with from/to dates pre-filled to today.
  ///
  /// [readTimeOffDashboard] and [timeOffRetryDelay] exist for tests; the app
  /// uses the defaults.
  ManagerApprovalsProvider({
    Future<TimeOffDashboard> Function()? readTimeOffDashboard,
    Duration timeOffRetryDelay = const Duration(milliseconds: 800),
  }) : _readDashboard = readTimeOffDashboard ?? _readDashboardWithTeamPending,
       _timeOffRetryDelay = timeOffRetryDelay {
    setDefaultDates();
  }

  /// Submits the "add time off" form as a new `hr.leave` record in `confirm`
  /// state.
  ///
  /// Validates that an employee, leave type, and date range are selected,
  /// uploads any attached file via [_createAttachment] and links it through
  /// the `supported_attachment_ids` X2Many command, then refreshes the
  /// time-off list.
  ///
  /// Returns `null` on success, or a user-facing error string for any
  /// validation failure or backend exception. Backend errors are best-effort
  /// extracted from the raw exception text — the parsing is fragile by
  /// design (Odoo error formats vary across versions) and falls back to
  /// "Something went wrong".
  Future<String?> saveLeave() async {
    final rangeError = dateRangeError;
    if (rangeError != null) return rangeError;

    try {
      _isSaveMyTimeOffLoading = true;
      notifyListeners();

      if (selectedEmployeeId == null) return "Select employee";

      final selectedLeaveType = _leaveTypes.firstWhere(
        (e) => e.name == leaveTypeController.text,
        orElse: () => ModelTimeOffAddTimeOffType(id: 0, name: ''),
      );

      if (selectedLeaveType.id == 0) return "Select leave type";

      if (fromDate == null || toDate == null) {
        return "Select valid dates";
      }

      int? attachmentId;
      if (_attachedFile != null) {
        attachmentId = await _createAttachment();
      }

      final majorVersion = await OdooSessionManager.getServerMajorVersion();
      final values = {
        'employee_id': selectedEmployeeId,
        'state': 'confirm',
        TimeOffTypeService.typeField(majorVersion): selectedLeaveType.id,
        'request_date_from': _formatDate(fromDate!),
        'request_date_to': _formatDate(toDate!),
        'name': descriptionController.text,
        'supported_attachment_ids': attachmentId != null
            ? [
                [4, attachmentId],
              ]
            : [],
      };

      await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'create',
        'args': [values],
        'kwargs': {},
      });

      clearForm();
      await Future.wait([fetchTimeOffDetails(), _refreshCalendarCounts()]);

      return null;
    } catch (e) {
      return OdooErrorMapper.serverMessage(e);
    } finally {
      _isSaveMyTimeOffLoading = false;
      notifyListeners();
    }
  }

  /// Odoo's message when "From" is after "To", for the form to show inline;
  /// `null` while the range is valid.
  String? get dateRangeError =>
      DateRangeValidator.isStartAfterEnd(fromDate, toDate)
      ? DateRangeValidator.timeOffMessage
      : null;

  /// Resets every field of the "add time off" form to its initial state,
  /// including controllers, selected employee, attachment, and dates.
  void clearForm() {
    employeeController.clear();
    departmentController.clear();
    leaveTypeController.clear();
    descriptionController.clear();
    selectedEmployeeId = null;
    _attachedFile = null;
    _attachedFileName = null;
    setDefaultDates();
  }

  /// Whether [saveLeave] has its required fields filled in. Drives the
  /// enabled state of the submit button.
  bool get isSubmitEnabled {
    return selectedEmployeeId != null &&
        leaveTypeController.text.trim().isNotEmpty &&
        fromDate != null &&
        toDate != null;
  }

  /// Uploads [_attachedFile] as an `ir.attachment` bound to `hr.leave` and
  /// returns its id. Returns `null` if no file is attached.
  Future<int?> _createAttachment() async {
    if (_attachedFile == null) return null;

    final bytes = await _attachedFile!.readAsBytes();
    final base64File = base64Encode(bytes);

    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'ir.attachment',
      'method': 'create',
      'args': [
        {
          'name': _attachedFileName,
          'type': 'binary',
          'datas': base64File,
          'res_model': 'hr.leave',
        },
      ],
      'kwargs': {},
    });

    return result as int?;
  }

  /// Drops the currently attached file from the form.
  void removeFile() {
    _attachedFile = null;
    _attachedFileName = null;
    notifyListeners();
  }

  /// Sets [fromDate] and keeps [fromDateController]'s text (the Odoo wire
  /// format the submit payload reads from) in sync. Called by [MoboDateField].
  void setFromDate(DateTime date) {
    fromDate = date;
    fromDateController.text = _formatDate(date);
    notifyListeners();
  }

  /// Sets [toDate] and keeps [toDateController]'s text in sync.
  void setToDate(DateTime date) {
    toDate = date;
    toDateController.text = _formatDate(date);
    notifyListeners();
  }

  /// Formats [date] as `YYYY-MM-DD`, the wire format Odoo expects.
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  /// Fetches and decodes the avatar for [employeeId] into the cache.
  ///
  /// Stores `null` for employees with no image so the cache also serves as
  /// a "tried, not available" marker, preventing repeat fetches.
  Future<void> loadEmployeeImage(int employeeId) async {
    if (_employeeImageCache.containsKey(employeeId)) return;

    final base64Image =
        await ManagerCalendarService.fetchEmployeeUserProfileImage(employeeId);

    if (base64Image != null && base64Image.isNotEmpty) {
      _employeeImageCache[employeeId] = base64Decode(base64Image);
    } else {
      _employeeImageCache[employeeId] = null;
    }

    notifyListeners();
  }

  /// Fetches and decodes avatars for every one of [employeeIds] not
  /// already cached, in a single batched request, so the list and its
  /// avatars appear together instead of popping in one by one.
  Future<void> _preloadEmployeeImages(Iterable<int> employeeIds) async {
    final idsToFetch = employeeIds
        .toSet()
        .where((id) => !_employeeImageCache.containsKey(id))
        .toList();
    if (idsToFetch.isEmpty) return;

    final images = await ManagerCalendarService.fetchEmployeeUserProfileImages(
      idsToFetch,
    );

    for (final id in idsToFetch) {
      final base64Image = images[id];
      _employeeImageCache[id] = (base64Image != null && base64Image.isNotEmpty)
          ? base64Decode(base64Image)
          : null;
    }
  }

  /// Approves the allocation request [allocationId] and refreshes the list.
  /// Re-entrancy guarded via [_validatingIds]. The [context] is currently
  /// unused but kept for parity with the refuse counterpart and future
  /// snackbar/dialog hooks.
  Future<void> validateAllocation(
    BuildContext context,
    int allocationId,
  ) async {
    if (_validatingIds.contains(allocationId)) return;

    _validatingIds.add(allocationId);
    notifyListeners();

    try {
      await ManagerCalendarService.actionApproveAllocation(allocationId);
      await Future.wait([fetchAllocationDetails(), _refreshCalendarCounts()]);
      _showActionSnack(success: true, message: 'Allocation request approved');
    } catch (e) {
      _showActionSnack(success: false, message: _readableActionError(e));
    } finally {
      _validatingIds.remove(allocationId);
      notifyListeners();
    }
  }

  /// Refuses the allocation request [allocationId] and refreshes the list.
  /// Guarded against double-tap via [_refusingIds].
  Future<void> refuseAllocation(BuildContext context, int allocationId) async {
    if (_refusingIds.contains(allocationId)) return;

    _refusingIds.add(allocationId);
    notifyListeners();

    try {
      await ManagerCalendarService.actionRefuseAllocation(allocationId);
      await Future.wait([fetchAllocationDetails(), _refreshCalendarCounts()]);
      _showActionSnack(success: true, message: 'Allocation request refused');
    } catch (e) {
      _showActionSnack(success: false, message: _readableActionError(e));
    } finally {
      _refusingIds.remove(allocationId);
      notifyListeners();
    }
  }

  /// Marks [date] as the day whose events should appear in
  /// [selectedDateEvents]. Time-of-day is dropped to keep comparisons stable.
  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  /// Closes the selected day's time off list.
  void clearSelectedDate() {
    _selectedDate = null;
    notifyListeners();
  }

  /// Calendar events whose `[dateFrom, dateTo]` range covers [selectedDate],
  /// using day-only comparisons. Empty when no date is selected or events
  /// have null bounds.
  List<LeaveCalendarEvent> get selectedDateEvents {
    if (_selectedDate == null) return [];
    final normalized = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    );

    return calendarEvents.where((e) {
      if (e.dateFrom == null || e.dateTo == null) return false;
      final from = DateTime(
        e.dateFrom!.year,
        e.dateFrom!.month,
        e.dateFrom!.day,
      );
      final to = DateTime(e.dateTo!.year, e.dateTo!.month, e.dateTo!.day);
      return !normalized.isBefore(from) && !normalized.isAfter(to);
    }).toList();
  }

  /// Wipes every piece of provider state on manager logout so the next
  /// manager session starts clean — counters, caches, in-flight markers,
  /// initial-load gates, and selected tab/date.
  void clearOnManagerLogout() {
    _selectedTabIndex = 0;
    _currentMonth = DateTime.now();
    _selectedDate = null;

    _isLoading = false;
    _isTimeOffLoading = false;
    _isInitialLoadDone = false;

    loadError = null;
    timeOffLoadError = null;
    allocationLoadError = null;

    _timeOffBalances = [];
    _pendingAllocationCount = 0;
    _timeOffDataFailed = false;
    _timeOffDataRequest++;

    _calendarEvents.clear();
    _timeOffList.clear();
    _unusualDays.clear();

    _validatingIds.clear();
    _refusingIds.clear();

    _employeeImageCache.clear();

    leaveCalendarEvent = null;
    serverMajorVersion = null;

    _isTimeOffInitialLoaded = false;
    _isCalendarInitialLoaded = false;
    _canCreateAllocation = false;
    _allocationList.clear();

    notifyListeners();
  }

  /// Public passthrough to [notifyListeners] for callers that mutate the
  /// provider's public fields directly (e.g. `selectedEmployeeId`) and need
  /// to trigger a rebuild without going through a setter.
  void notify() {
    notifyListeners();
  }
}
