import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_timeoff_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/services/manager_calendar_service.dart';

import '../../attendance/service/administrator_attendance_service.dart';
import '../model/leaveMyCalender.dart';
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

  // Leave balance fields
  double paidMaxLeaves = 0;
  double paidRemainingMyLeave = 0;
  double compRemainingMyLeaves = 0;
  double pendingMyRequest = 0;
  double compMaxMyLeaves = 0;
  String paidOffValidUntil = '';
  String compensatoryValidUntil = '';

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
    } catch (_) {}
  }

  /// Navigates to the next month in the calendar and refreshes events.
  void goToNextMyMonth() async {
    try {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      await fetchLeaveMyCalendarEventsFunction();
      notifyListeners();
    } catch (_) {}
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
    } catch (_) {}
  }

  /// Performs the initial data load for the leave page, including summary, events, and history.
  ///
  /// Set [isRefresh] to true to force a reload even if data was previously loaded.
  Future loadInitialOfMyCalender({bool isRefresh = false}) async {
    if (isRefresh == false) {
      if (_isInitialLoadDone) return;
    }
    _isLoading = true;
    notifyListeners();

    try {
      final session = await OdooSessionManager.getCurrentSession();
      final version = session!.odooSession.serverVersion;
      if (version.contains("19")) {
        final result = await services.fetchMySummary();
        final allocationData = result['allocation_data'] as List? ?? [];
        pendingMyRequest = (result['allocation_request_amount'] ?? 0)
            .toDouble();
        for (var item in allocationData) {
          final leaveName = item[0];
          final leaveData = item[1] as Map<String, dynamic>;
          switch (leaveName) {
            case "Paid Time Off":
              paidRemainingMyLeave =
                  (leaveData['virtual_remaining_leaves'] ?? 0).toDouble();
              paidMaxLeaves = (leaveData['remaining_leaves'] ?? 0).toDouble();
              paidOffValidUntil = leaveData['closest_allocation_expire'] ?? "";
              break;

            case "Training Time Off":
              compRemainingMyLeaves =
                  (leaveData['virtual_remaining_leaves'] ?? 0).toDouble();
              compMaxMyLeaves = (leaveData['remaining_leaves'] ?? 0).toDouble();
              compensatoryValidUntil =
                  leaveData['closest_allocation_expire'] ?? "";
              break;
          }
        }
      } else {
        final emp = await OdooSessionManager.callKwWithCompany({
          'model': 'hr.employee',
          'method': 'search_read',
          'args': [],
          'kwargs': {
            'domain': [
              ['user_id', '=', session!.userId],
            ],
            'fields': ['id', 'name'],
            'limit': 1,
          },
        });

        final employeeId = emp[0]['id'];
        final summary = await services.fetchTimeOffDashboard(employeeId);

        paidRemainingMyLeave = summary['paid_available'];
        paidOffValidUntil = summary['paid_valid_until'];
        compRemainingMyLeaves = summary['training_available'];
        compensatoryValidUntil = summary['training_valid_until'];
        pendingMyRequest = double.parse(
          summary['pending_allocations'].toString(),
        );
        notifyListeners();
      }
      await fetchLeaveMyCalendarEventsFunction(showLoader: false);
      await fetchUserUnusualDays();
      await fetchMyTimeOff(isRefresh: true);
    } catch (_) {
    } finally {
      _isLoading = false;
      _isInitialLoadDone = true;
      notifyListeners();
    }
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
    } catch (_) {
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
      fetchMyTimeOff();
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
    await fetchMyTimeOff(isRefresh: true);
  }

  /// Fetches the user's time-off request history from the server.
  Future<void> fetchMyTimeOff({bool isRefresh = false}) async {
    final session = await OdooSessionManager.getCurrentSession();
    final userId = session?.userId.toInt();
    try {
      _isLoading = true;
      notifyListeners();

      final data = await ManagerCalendarService.fetchLeaveTimeOffDetails(
        domain: [
          ['user_id', '=', userId],
        ],
      );

      _timeOffList
        ..clear()
        ..addAll(data);
    } catch (_) {
      _timeOffList.clear();
    } finally {
      _isLoading = false;
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
    paidMaxLeaves = 0;
    paidRemainingMyLeave = 0;
    compRemainingMyLeaves = 0;
    pendingMyRequest = 0;
    compMaxMyLeaves = 0;
    paidOffValidUntil = '';
    compensatoryValidUntil = '';
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
    try {
      _isSaveMyTimeOffLoading = true;
      notifyListeners();

      final employeeId = await LeaveService().fetchEmployeeId();
      final leaveTypeId = modelTimeOffType?.id;

      if (employeeId == null) return "Employee not found";
      if (leaveTypeId == null) return "Select leave type";

      int? attachmentId;
      if (_attachedFile != null) {
        attachmentId = await _createAttachment();
      }

      final session = await OdooSessionManager.getCurrentSession();
      final versionStr = session!.odooSession.serverVersion;
      final majorVersion = int.tryParse(versionStr.split('.').first) ?? 19;

      final fromDate = _convertToOdooDate(fromDateController.text);
      final toDate = _convertToOdooDate(toDateController.text);

      Map<String, dynamic> payload;

      if (majorVersion >= 19) {
        payload = {
          'employee_id': employeeId,
          'holiday_status_id': leaveTypeId,
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
        payload = {
          'employee_id': employeeId,
          'holiday_status_id': leaveTypeId,
          'request_date_from': "$fromDate 08:00:00",
          'request_date_to': "$toDate 17:00:00",
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
      await fetchMyTimeOff();

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

  String _convertToOdooDate(String text) {
    final now = DateTime.now();
    final parsed = DateFormat('MMM dd').parse(text);
    final fullDate = DateTime(now.year, parsed.month, parsed.day);
    return DateFormat('yyyy-MM-dd').format(fullDate);
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
