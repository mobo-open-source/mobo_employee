import 'package:flutter/material.dart';

/// Placeholder shown when a user has no profile photo: a solid circle in the
/// app's primary color carrying their initials, sized by [diameter].
class InitialsAvatar extends StatelessWidget {
  final String? name;
  final double diameter;
  final Color? background;
  final Color foreground;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.diameter = 40,
    this.background,
    this.foreground = Colors.white,
  });

  /// First letter of the first two words (e.g. "John Doe" -> "JD"), or just
  /// the first letter for a single-word name (e.g. "Administrator" -> "A").
  static String initialsFor(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background ?? Theme.of(context).primaryColor,
      ),
      child: Text(
        initialsFor(name),
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: diameter * 0.4,
        ),
      ),
    );
  }
}
