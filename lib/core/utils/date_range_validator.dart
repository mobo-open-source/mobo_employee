/// Client-side date range checks for create forms, using the exact messages
/// Odoo raises for the same constraint so the app and the web client agree.
class DateRangeValidator {
  /// `hr.leave` SQL constraint `date_check2`.
  static const String timeOffMessage =
      'The start date must be before or equal to the end date.';

  /// `hr.leave.allocation._check_date_from_date_to`.
  static const String allocationMessage =
      'The Start Date of the Validity Period must be anterior to the End Date.';

  /// `hr.attendance._check_validity_check_in_check_out`.
  static const String attendanceMessage =
      '"Check Out" time cannot be earlier than "Check In" time.';

  /// Whether [start] falls on a later calendar day than [end]. Same-day
  /// ranges are valid, as in Odoo. A missing bound is never an error here —
  /// required-field checks are the form's job.
  static bool isStartAfterEnd(DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return s.isAfter(e);
  }
}
