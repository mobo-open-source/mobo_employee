import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_allocation_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_leave_calendar_event.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_employees.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_time_off_type.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_timeoff_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/services/manager_calendar_service.dart';
import 'package:mobo_employees/features/employee/attendance/service/administrator_attendance_service.dart';

/// State holder for the manager-side leave approvals feature.
///
/// Backs three tabs (calendar, time-off requests, allocations) with data from
/// [ManagerCalendarService], owns the form state for the "add time off" flow
/// (employee/leave-type pickers, date range, attachment), and tracks per-row
/// loading flags so the UI can show spinners on individual approve/refuse
/// actions without blocking the rest of the list.
class ManagerApprovalsProvider extends ChangeNotifier {
  int _selectedTabIndex = 0;
  int _pendingRequests = 0;
  int? serverMajorVersion;
  int? selectedEmployeeId;

  double _remainingLeaves = 0;
  double paidRemainingMyLeave = 0;
  double compRemainingMyLeaves = 0;
  double pendingMyRequest = 0;
  double compMaxMyLeaves = 0;
  double _maxLeaves = 0;
  double paidMaxLeaves = 0;
  double _compensatoryLeaves = 0;
  double _compensatoryMaxLeaves = 0;
  double _allocationRequestCount = 0;

  bool _isLoading = false;
  bool _isInitialLoadDone = false;
  bool _isTimeOffInitialLoaded = false;
  bool _isCalendarInitialLoaded = false;
  bool _isTimeOffLoading = false;
  bool _isCalendarLoading = false;
  bool _isSaveMyTimeOffLoading = false;
  bool _isAllocationLoading = false;

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

  String paidOffValidUntil = '';
  String compensatoryValidUntil = '';

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

  int get selectedTabIndex => _selectedTabIndex;
  int get pendingRequests => _pendingRequests;

  double get remainingLeaves => _remainingLeaves;
  double get maxLeaves => _maxLeaves;
  double get compensatoryLeaves => _compensatoryLeaves;
  double get compensatoryMaxLeaves => _compensatoryMaxLeaves;
  double get allocationRequestCount => _allocationRequestCount;

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
    await fetchLeaveCalendarEventsFunction();
  }

  /// Moves the calendar back one month and refetches its events.
  Future<void> goToPreviousMonth() async {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    await fetchLeaveCalendarEventsFunction();
  }

  /// Switches the active tab and lazy-loads its data on first visit.
  ///
  /// No-op if [index] equals the current tab. The time-off tab (1) is
  /// fetched once and gated by [_isTimeOffInitialLoaded]; the allocations
  /// tab (2) is refetched every time it is selected.
  void setTab(int index) {
    if (_selectedTabIndex == index) return;
    _selectedTabIndex = index;
    if (index == 1 && !_isTimeOffInitialLoaded) {
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
  /// swallowed.
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
    } catch (_) {}
  }

  /// Loads the manager's own time-off summary counters (remaining/max leaves,
  /// pending requests, compensatory balances, allocation request count).
  ///
  /// Set [showLoader] to `false` for background refreshes that should not
  /// flip the page-level spinner. On error, every counter is reset to 0.
  Future<void> fetchTimeOffData({bool showLoader = true}) async {
    if (showLoader) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final timeOffData = await ManagerCalendarService.fetchTimeOffSummary();
      _remainingLeaves = timeOffData['virtual_remaining_leaves'] ?? 0;
      _maxLeaves = timeOffData['max_leaves'] ?? 0;
      _pendingRequests = (timeOffData['pending_leaves'] ?? 0).toInt();
      _compensatoryLeaves = timeOffData['compensatory_leaves'] ?? 0;
      _compensatoryMaxLeaves = timeOffData['compensatory_max_leaves'] ?? 0;
      _allocationRequestCount = timeOffData['allocation_request_amount'] ?? 0;
    } catch (_) {
      _remainingLeaves = 0;
      _maxLeaves = 0;
      _pendingRequests = 0;
      _compensatoryLeaves = 0;
      _compensatoryMaxLeaves = 0;
      _allocationRequestCount = 0;
    } finally {
      if (showLoader) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// One-shot loader that fetches calendar events, summary counters, and
  /// unusual days in parallel. Guarded by [_isInitialLoadDone] so it runs
  /// at most once per provider lifetime; use [refreshAll] for subsequent
  /// pull-to-refresh actions.
  Future<void> loadInitialData() async {
    if (_isInitialLoadDone) return;

    _isInitialLoadDone = true;
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        fetchLeaveCalendarEventsFunction(showLoader: true),
        fetchTimeOffData(showLoader: false),
        fetchUnusualDays(),
      ]);
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refetches calendar, summary, and unusual days without showing a
  /// page-level loader — intended for pull-to-refresh.
  Future<void> refreshAll() async {
    try {
      await Future.wait([
        fetchLeaveCalendarEventsFunction(showLoader: false),
        fetchTimeOffData(showLoader: false),
        fetchUnusualDays(),
      ]);
    } catch (_) {}
  }

  /// Populates [employees] with the list the manager can create time-off for.
  Future<void> fetchEmployees() async {
    try {
      final data =
          await ManagerCalendarService.fetchManagerAddTimeOffEmployees();
      _employees = data;
      notifyListeners();
    } catch (_) {}
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
  /// the existing event list is cleared.
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
    } catch (_) {
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
  /// [timeOffList]. Toggles [isTimeOffLoading] and clears the list on error.
  Future<void> fetchTimeOffDetails() async {
    try {
      _isTimeOffLoading = true;
      notifyListeners();
      final data = await ManagerCalendarService.fetchLeaveTimeOffDetails();
      _timeOffList
        ..clear()
        ..addAll(data);
      _isTimeOffInitialLoaded = true;
    } catch (_) {
      _timeOffList.clear();
    } finally {
      _isTimeOffLoading = false;
      notifyListeners();
    }
  }

  /// Approves the leave request [leaveId] and refreshes the list.
  ///
  /// Picks the right Odoo action based on [state]: `validate1` calls
  /// `action_validate` (final approval), anything else calls
  /// `action_approve` (manager approval, may still need second-level
  /// validation). Re-entrancy is guarded via [_validatingIds] so the per-row
  /// spinner only triggers once.
  Future<void> validateTimeOff(int leaveId, String state) async {
    if (_validatingIds.contains(leaveId)) return;
    _validatingIds.add(leaveId);
    notifyListeners();
    try {
      if (state == "validate1") {
        await ManagerCalendarService.actionValidate(leaveId);
      } else {
        await ManagerCalendarService.actionApprove(leaveId);
      }
      await fetchTimeOffDetails();
    } catch (_) {
    } finally {
      _validatingIds.remove(leaveId);
      notifyListeners();
    }
  }

  /// Refuses the leave request [leaveId] and refreshes the list.
  /// Guarded against double-tap via [_refusingIds].
  Future<void> refuseTimeOff(int leaveId) async {
    if (_refusingIds.contains(leaveId)) return;
    _refusingIds.add(leaveId);
    notifyListeners();
    try {
      await ManagerCalendarService.actionRefuse(leaveId);
      await fetchTimeOffDetails();
    } catch (_) {
    } finally {
      _refusingIds.remove(leaveId);
      notifyListeners();
    }
  }

  /// Loads the manager's allocation requests into [allocationList] and
  /// kicks off avatar fetches for any employee not yet cached.
  Future<void> fetchAllocationDetails() async {
    try {
      _isAllocationLoading = true;
      notifyListeners();

      final data =
          await ManagerCalendarService.fetchManagerLeaveAllocationDetailsView();
      _allocationList
        ..clear()
        ..addAll(data);
      for (var item in _allocationList) {
        if (!_employeeImageCache.containsKey(item.employeeId)) {
          loadEmployeeImage(item.employeeId);
        }
      }
    } catch (_) {
      _allocationList.clear();
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

  /// Creates the provider with from/to dates pre-filled to today.
  ManagerApprovalsProvider() {
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

      final values = {
        'employee_id': selectedEmployeeId,
        'state': 'confirm',
        'holiday_status_id': selectedLeaveType.id,
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
      await fetchTimeOffDetails();

      return null;
    } catch (e) {
      String errorMessage = "Something went wrong";

      try {
        final errorStr = e.toString();

        if (errorStr.contains("message:")) {
          errorMessage = errorStr.split("message:").last;
        }

        if (errorMessage.contains(", arguments")) {
          errorMessage = errorMessage.split(", arguments").first;
        }

        final lines = errorMessage.split("\n");
        List<String> cleanedLines = [];

        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            cleanedLines.add(trimmed);
          }
          if (cleanedLines.length == 2) break;
        }

        errorMessage = cleanedLines.join(" ");
        errorMessage = errorMessage.replaceAll(" - To Approve", "");
        errorMessage = errorMessage
            .replaceAll("\\n", " ")
            .replaceAll(RegExp(r"\s+"), " ")
            .trim();
      } catch (_) {}

      return errorMessage;
    } finally {
      _isSaveMyTimeOffLoading = false;
      notifyListeners();
    }
  }

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

  /// Shows the themed date picker and writes the result back to [controller]
  /// and the matching [fromDate] / [toDate] field. Initial date is whichever
  /// value is currently set, falling back to today.
  Future<void> chooseDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime today = DateTime.now();

    DateTime initialDate = today;

    if (controller == fromDateController && fromDate != null) {
      initialDate = fromDate!;
    } else if (controller == toDateController && toDate != null) {
      initialDate = toDate!;
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            datePickerTheme: DatePickerThemeData(
              dividerColor: Colors.transparent,
              headerBackgroundColor: Theme.of(context).primaryColor,
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      controller.text = _formatDate(pickedDate);
      if (controller == fromDateController) {
        fromDate = pickedDate;
      } else if (controller == toDateController) {
        toDate = pickedDate;
      }
      notifyListeners();
    }
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
      await fetchAllocationDetails();
    } catch (_) {
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
      await fetchAllocationDetails();
    } catch (_) {
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

    _remainingLeaves = 0;
    _maxLeaves = 0;
    _pendingRequests = 0;
    _compensatoryLeaves = 0;
    _compensatoryMaxLeaves = 0;
    _allocationRequestCount = 0;

    paidRemainingMyLeave = 0;
    compRemainingMyLeaves = 0;
    pendingMyRequest = 0;
    compMaxMyLeaves = 0;
    paidMaxLeaves = 0;

    paidOffValidUntil = '';
    compensatoryValidUntil = '';

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

    notifyListeners();
  }

  /// Public passthrough to [notifyListeners] for callers that mutate the
  /// provider's public fields directly (e.g. `selectedEmployeeId`) and need
  /// to trigger a rebuild without going through a setter.
  void notify() {
    notifyListeners();
  }
}
