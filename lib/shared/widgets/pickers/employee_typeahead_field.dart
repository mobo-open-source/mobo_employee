import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../avatars/initials_avatar.dart';
import 'mobo_typeahead_field.dart';

/// Employee search field — thin wrapper around [MoboTypeaheadField]. The
/// employee list is already fully loaded by the caller, so filtering here is
/// a local client-side match rather than another network round-trip.
class EmployeeTypeaheadField<T> extends StatelessWidget {
  final List<T> employees;
  final T? selectedEmployee;
  final ValueChanged<T?> onChanged;
  final String Function(T) displayName;
  final Uint8List? Function(T) avatarBytes;
  final bool Function(T a, T b)? compareFn;
  final bool isDark;
  final String hintText;

  /// Optional label rendered above the field, matching [MoboFormField] /
  /// [MoboDateField]'s label styling. Omit for callers that render their
  /// own label separately.
  final String? label;
  final bool isRequired;

  const EmployeeTypeaheadField({
    super.key,
    required this.employees,
    required this.selectedEmployee,
    required this.onChanged,
    required this.displayName,
    required this.avatarBytes,
    this.compareFn,
    this.isDark = false,
    this.hintText = 'Search employee...',
    this.label,
    this.isRequired = false,
  });

  Future<List<T>> _search(String pattern) async {
    final term = pattern.trim().toLowerCase();
    if (term.isEmpty) return employees;
    return employees
        .where((e) => displayName(e).toLowerCase().contains(term))
        .toList();
  }

  Widget _avatar(T employee, {double radius = 12}) {
    final bytes = avatarBytes(employee);
    if (bytes != null && bytes.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes));
    }
    return InitialsAvatar(name: displayName(employee), diameter: radius * 2);
  }

  @override
  Widget build(BuildContext context) {
    return MoboTypeaheadField<T>(
      selectedItem: selectedEmployee,
      onChanged: onChanged,
      isDark: isDark,
      hintText: hintText,
      emptyText: 'No employees found',
      displayText: displayName,
      compareFn: compareFn,
      label: label,
      isRequired: isRequired,
      suggestionsCallback: _search,
      unselectedLeadingIcon: Icon(Icons.person_outline_rounded,
          size: 17, color: isDark ? Colors.white38 : Colors.black38),
      selectedLeadingBuilder: (employee) =>
          Padding(padding: const EdgeInsets.all(9), child: _avatar(employee)),
      itemBuilder: (ctx, emp) => _EmployeeTile<T>(
        employee: emp,
        isDark: isDark,
        displayName: displayName,
        avatarBytes: avatarBytes,
      ),
    );
  }
}

class _EmployeeTile<T> extends StatelessWidget {
  final T employee;
  final bool isDark;
  final String Function(T) displayName;
  final Uint8List? Function(T) avatarBytes;

  const _EmployeeTile({
    required this.employee,
    required this.isDark,
    required this.displayName,
    required this.avatarBytes,
  });

  @override
  Widget build(BuildContext context) {
    final name = displayName(employee);
    final bytes = avatarBytes(employee);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: bytes != null && bytes.isNotEmpty
          ? CircleAvatar(radius: 16, backgroundImage: MemoryImage(bytes))
          : InitialsAvatar(name: name, diameter: 32),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87),
      ),
    );
  }
}
