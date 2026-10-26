import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/exceptions/odoo_error_mapper.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/core/utils/date_range_validator.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_timeoff_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/services/manager_calendar_service.dart';
import 'package:mobo_employees/shared/services/time_off_type_service.dart';

import '../../attendance/service/administrator_attendance_service.dart';
import '../model/leaveMyCalender.dart';
import '../model/model_time_off_balance.dart';
import '../model/model_time_off_type.dart';
import '../service/leave_service.dart';

/// Provider class that manages the state and business logic for the Employee Leave page.
/// This provider handles:
/// - Fetching leave summaries and balances.
/// - Managing calendar events for leaves.
/// - Fetching and storing time-off request history.
/// - Submitting new leave requests with optional attachments.
/// - Managing form state for leave applications.
class LeavePageProvider extends ChangeNotifier {
  int _selectedTabIndex = 0;

  /// The index of the currently selected tab (0: My Calendar, 1: Time Off).
  int get selectedTabIndex => _selectedTabIndex;

  File? _attachedFile;

  /// The file attached to the current leave application.
  File? get attachedFile => _attachedFile;

  String? _attachedFileName;

  /// The name of the file attached to the current leave application.
  String? get attachedFileName => _attachedFileName;

  bool _isSaveMyTimeOffLoading = false;

  /// Whether a leave application submission is in progress.
  bool get isSaveMyTimeOffLoading => _isSaveMyTimeOffLoading;

  final Map<DateTime, bool> _unusualDays = {};

  /// A map of dates to a boolean indicating if they are "unusual" days (e.g., holidays).
  Map<DateTime, bool> get unusualDays => _unusualDays;

  /// Controller for the leave type field in the application form.
  final TextEditingController leaveTypeController = TextEditingController();

  /// Controller for the "From" date field in the application form.
  final TextEditingController fromDateController = TextEditingController();

  /// Controller for the "To" date field in the application form.
  final TextEditingController toDateController = TextEditingController();

  /// Controller for the description/reason field in the application form.
  final TextEditingController descriptionController = TextEditingController();

  /// The currently selected leave type model for a new application.
  ModelTimeOffType? modelTimeOffType;

  /// The "From"/"To" dates backing [MoboDateField], kept in sync with
  /// [fromDateController]/[toDateController]'s displayed text.
  DateTime? fromDate;
  DateTime? toDate;

  bool _isLoading = false;

  /// Whether a general data loading operation is in progress.
  bool get isLoading => _isLoading;

  DateTime _currentMonth = DateTime.now();

  /// The month currently being viewed in the leave calendar.
  DateTime get currentMonth => _currentMonth;

  bool _isInitialLoadDone = false;

  /// Whether the initial data load for the provider has been completed.
  bool get isInitialLoadDone => _isInitialLoadDone;

  /// Set when loading failed because the server couldn't be reached; the
  /// page shows it in place of its content until a reload succeeds.
  Object? loadError;

  /// Records [e] as [loadError] when it's a connectivity failure. Other
  /// errors keep the existing behaviour of showing whatever did load.
  void _recordConnectivityFailure(Object e) {
    if (!ConnectivityService.isConnectivityError(e)) return;
    loadError = e;
    notifyListeners();
  }

  /// The user's balance per time off type, as on Odoo's Time Off dashboard.
  List<TimeOffBalance> timeOffBalances = [];

  /// The user's own time off requests awaiting approval (same figure as the
  /// dashboard's "Leave Requests" card).
  int pendingMyRequest = 0;

  final List<LeaveMyCalenderModel> _calendarEvents = [];

  /// The list of leave events for the current month.
  List<LeaveMyCalenderModel> get calendarEvents => _calendarEvents;

  DateTime? _selectedDate;

  /// The date currently selected in the calendar view.
  DateTime? get selectedDate => _selectedDate;

  /// Instance of the leave service for making API calls.
  final services = LeaveService();

  /// Selects a date in the calendar and notifies listeners.
  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  /// Returns a list of leave events occurring on the [selectedDate].
  List<LeaveMyCalenderModel> get selectedDateEvents {
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

  /// Navigates to the previous month in the calendar and refreshes events.
  void goToPreviousMyMonth() async {
    try {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      await fetchLeaveMyCalendarEventsFunction();
      notifyListeners();
    } catch (e) {
      _recordConnectivityFailure(e);
    }
  }

  /// Navigates to the next month in the calendar and refreshes events.
  void goToNextMyMonth() async {
    try {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      await fetchLeaveMyCalendarEventsFunction();
      notifyListeners();
    } catch (e) {
      _recordConnectivityFailure(e);
    }
  }

  /// Fetches "unusual" days (holidays, non-working days) from the server.
  Future<void> fetchUserUnusualDays() async {
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

  /// Performs the initial data load for the leave page, including summary, events, and history.
  ///
  /// Set [isRefresh] to true to force a reload even if data was previously loaded.
  Future loadInitialOfMyCalender({bool isRefresh = false}) async {
    if (isRefresh == false) {
      if (_isInitialLoadDone) return;
    }
    _isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      /// A failing summary (e.g. no allocations yet) must not keep the
      /// calendar and the request list from loading.
      try {
        await _loadSummary();
      } catch (e) {
        if (ConnectivityService.isConnectivityError(e)) rethrow;
      }
      await fetchLeaveMyCalendarEventsFunction(showLoader: false);
      await fetchUserUnusualDays();
      await fetchMyTimeOff(isRefresh: true, showLoader: false);
    } catch (e) {
      _recordConnectivityFailure(e);
    } finally {
      _isLoading = false;
      _isInitialLoadDone = true;
      notifyListeners();
    }
  }

  /// Re-reads the summary cards, the calendar and the request list in
  /// place (no shimmer) — after the user submits a request, or when they
  /// come back to the page and requests may have been approved/refused.
  /// If the server can't be reached, what's on screen stays as it was.
  Future<void> refreshInPlace() async {
    try {
      await _loadSummary();
    } catch (_) {}
    try {
      await Future.wait([
        fetchLeaveMyCalendarEventsFunction(showLoader: false),
        fetchMyTimeOff(showLoader: false),
      ]);
    } catch (_) {}
    notifyListeners();
  }

  /// Loads the balance cards and the "Pending" requests count.
  Future<void> _loadSummary() async {
    final results = await Future.wait([
      LeaveService.fetchMyTimeOffDashboard(),
      LeaveService.fetchMyPendingRequestCount(),
    ]);
    timeOffBalances = (results[0] as TimeOffDashboard).balances;
    pendingMyRequest = results[1] as int;
    notifyListeners();
  }

  /// Refreshes the calendar and summary data.
  Future refreshMyCalender() async {
    try {
      await loadInitialOfMyCalender(isRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches leave events for the currently viewed month.
  Future<void> fetchLeaveMyCalendarEventsFunction({
    bool showLoader = true,
  }) async {
    if (showLoader) {
      _isLoading = true;
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

      final events = await services.fetchMyLeaveCalendarEvents(
        from: from,
        to: to,
      );

      _calendarEvents
        ..clear()
        ..addAll(events);
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      _calendarEvents.clear();
    } finally {
      if (showLoader) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  final List<ModelTimeOffData> _timeOffList = [];

  /// The list of time-off request records for the user.
  List<ModelTimeOffData> get timeOffList => _timeOffList;

  List<ModelTimeOffType> _timeOffTypes = [];

  /// The available types of leave (e.g., Sick, Paid).
  List<ModelTimeOffType> get timeOffTypes => _timeOffTypes;

  /// Loads available leave types and sets a default selection.
  Future<void> loadTimeOffTypes() async {
    _timeOffTypes = await LeaveService.fetchTimeOffTypes();
    if (_timeOffTypes.isNotEmpty) {
      final sickLeave = _timeOffTypes.firstWhere(
        (e) => e.displayName.contains('Sick ('),
        orElse: () => _timeOffTypes.first,
      );

      modelTimeOffType = sickLeave;
      leaveTypeController.text = sickLeave.displayName;
    }
    final now = DateTime.now();
    final formatted = _formatDate(now);
    fromDate = now;
    toDate = now;
    fromDateController.text = formatted;
    toDateController.text = formatted;
    notifyListeners();
  }

  /// Changes the active tab and fetches time-off records if the "Time Off" tab is selected.
  void setTab(int index) {
    if (_selectedTabIndex == index) return;

    _selectedTabIndex = index;

    if (index == 1) {
      refreshMyTimeOff();
    }

    notifyListeners();
  }

  /// Initializes the provider and adds listeners to form fields.
  LeavePageProvider() {
    leaveTypeController.addListener(_onFieldChanged);
    fromDateController.addListener(_onFieldChanged);
    toDateController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (modelTimeOffType != null &&
        leaveTypeController.text != modelTimeOffType!.displayName) {
      modelTimeOffType = null;
    }

    notifyListeners();
  }

  /// Refreshes the user's time-off records.
  Future<void> refreshMyTimeOff() async {
    try {
      await fetchMyTimeOff(isRefresh: true);
    } catch (e) {
      _recordConnectivityFailure(e);
    }
  }

  /// Fetches the user's time-off request history from the server.
  ///
  /// Same records as Odoo's "My Time Off" (`user_id = uid`).
  Future<void> fetchMyTimeOff({
    bool isRefresh = false,
    bool showLoader = true,
  }) async {
    final session = await OdooSessionManager.getCurrentSession();
    final userId = session?.userId.toInt();
    try {
      if (showLoader) {
        _isLoading = true;
        notifyListeners();
      }

      final data = await ManagerCalendarService.fetchLeaveTimeOffDetails(
        domain: [
          ['user_id', '=', userId],
        ],
      );

      _timeOffList
        ..clear()
        ..addAll(data);
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      _timeOffList.clear();
    } finally {
      if (showLoader) _isLoading = false;
      _isInitialLoadDone = true;
      notifyListeners();
    }
  }

  /// Picks a file to be attached to a leave request.
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

  /// Removes the currently attached file.
  void removeFile() {
    _attachedFile = null;
    _attachedFileName = null;
    notifyListeners();
  }

  /// Whether the leave request form is valid for submission.
  bool get isSubmitEnabled {
    final isLeaveTypeValid = modelTimeOffType != null;
    final isFromValid = fromDateController.text.trim().isNotEmpty;
    final isToValid = toDateController.text.trim().isNotEmpty;
    return isLeaveTypeValid && isFromValid && isToValid;
  }

  /// Odoo's message when "From" is after "To", for the form to show inline;
  /// `null` while the range is valid.
  String? get dateRangeError =>
      DateRangeValidator.isStartAfterEnd(fromDate, toDate)
      ? DateRangeValidator.timeOffMessage
      : null;

  /// Convenience method to notify listeners.
  void notifyListener() {
    notifyListeners();
  }

  /// Sets [fromDate] and keeps [fromDateController]'s displayed text in
  /// sync. Called by [MoboDateField].
  void setFromDate(DateTime date) {
    fromDate = date;
    fromDateController.text = _formatDate(date);
    notifyListeners();
  }

  /// Sets [toDate] and keeps [toDateController]'s displayed text in sync.
  void setToDate(DateTime date) {
    toDate = date;
    toDateController.text = _formatDate(date);
    notifyListeners();
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('MMM dd').format(d);
  }

  /// Resets the provider's state when the user logs out.
  void clearOnLogout() {
    _selectedTabIndex = 0;
    _isInitialLoadDone = false;
    loadError = null;
    timeOffBalances = [];
    pendingMyRequest = 0;
    _timeOffList.clear();
    _isLoading = false;
  }

  /// Uploads the attached file to the server and returns the attachment ID.
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

  /// Submits the current leave application to the server.
  /// Returns null on success, or an error message if the submission fails.
  Future<String?> saveLeave() async {
    final rangeError = dateRangeError;
    if (rangeError != null) return rangeError;

    try {
      _isSaveMyTimeOffLoading = true;
      notifyListeners();

      final employeeId = await LeaveService().fetchEmployeeId();
      final leaveTypeId = modelTimeOffType?.id;

      if (employeeId == null) return "Employee not found";
      if (leaveTypeId == null) return "Select leave type";
      if (this.fromDate == null || this.toDate == null) {
        return "Select valid dates";
      }

      int? attachmentId;
      if (_attachedFile != null) {
        attachmentId = await _createAttachment();
      }

      final session = await OdooSessionManager.getCurrentSession();
      final versionStr = session!.odooSession.serverVersion;
      final majorVersion = int.tryParse(versionStr.split('.').first) ?? 19;

      /// Use the picked dates themselves: re-parsing the "MMM dd" display
      /// text dropped the year, so a range crossing New Year was sent
      /// backwards and rejected by Odoo.
      final fromDate = DateFormat('yyyy-MM-dd').format(this.fromDate!);
      final toDate = DateFormat('yyyy-MM-dd').format(this.toDate!);

      Map<String, dynamic> payload;

      if (majorVersion >= 19) {
        payload = {
          'employee_id': employeeId,
          TimeOffTypeService.typeField(majorVersion): leaveTypeId,
          'request_date_from': fromDate,
          'request_date_to': toDate,
          'request_hour_from': 8,
          'request_hour_to': 17,
          'name': descriptionController.text,
          if (attachmentId != null)
            'supported_attachment_ids': [
              [4, attachmentId],
            ],
        };
      } else {
        /// `request_date_from`/`request_date_to` are plain Date fields on
        /// 17/18 (no time component) — Odoo computes the actual start/end
        /// datetime server-side from the employee's working calendar.
        /// Appending a time-of-day here made `hr.leave.create` reject the
        /// value outright.
        payload = {
          'employee_id': employeeId,
          TimeOffTypeService.typeField(majorVersion): leaveTypeId,
          'request_date_from': fromDate,
          'request_date_to': toDate,
          'name': descriptionController.text,
          if (attachmentId != null)
            'supported_attachment_ids': [
              [4, attachmentId],
            ],
        };
      }

      await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'create',
        'args': [payload],
        'kwargs': {},
      });

      clearForm();
      await refreshInPlace();

      return null;
    } catch (e) {
      return OdooErrorMapper.serverMessage(e);
    } finally {
      _isSaveMyTimeOffLoading = false;
      notifyListeners();
    }
  }

  /// Resets the leave application form and removes any attachments.
  void clearForm() {
    leaveTypeController.clear();
    fromDateController.clear();
    toDateController.clear();
    descriptionController.clear();
    modelTimeOffType = null;
    removeFile();
  }

  @override
  void dispose() {
    leaveTypeController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
