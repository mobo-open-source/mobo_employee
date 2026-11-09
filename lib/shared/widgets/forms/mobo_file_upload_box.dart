import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

import 'dashed_border_box.dart';

/// A labelled file field: a subtle dotted-border box with an upload icon and
/// "Attach File" — as the events app's upload box — that becomes the chosen
/// file's name (with the Mobo delete icon) once one is picked.
///
/// This replaced a separate "Attach File" button under a "File" label, and a
/// filename chip shown above it.
class MoboFileUploadBox extends StatelessWidget {
  final String label;

  /// The picked file's name; null while nothing is attached.
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final bool isDark;

  const MoboFileUploadBox({
    super.key,
    required this.onPick,
    required this.onRemove,
    required this.isDark,
    this.label = 'File',
    this.fileName,
  });

  /// Height of the empty box.
  static const double height = 80;

  /// Matches the form fields' corners.
  static const double radius = 12;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : const Color(0xFF7F7F7F),
          ),
        ),
        const SizedBox(height: 8),
        fileName == null ? _emptyBox() : _fileChip(fileName!),
      ],
    );
  }

  /// "Attach File" in a dotted box.
  Widget _emptyBox() {
    final contentColor = isDark ? Colors.white : AppColors.color000000;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(radius),
      child: DashedBorderBox(
        borderRadius: radius,
        color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: AppColors.inputFill(isDark),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedFileUpload,
                  size: 22,
                  color: contentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Attach File',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: contentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The chosen file: its name, and the delete icon the other Mobo apps use for
  /// removing an attachment (a bin, in red) to take it back out.
  Widget _fileChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill(isDark),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file,
            size: 18,
            color: isDark ? Colors.white : AppColors.color000000,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : AppColors.color000000,
              ),
            ),
          ),
          Tooltip(
            message: 'Delete attachment',
            child: InkResponse(
              onTap: onRemove,
              radius: 20,
              // A bin is a small target: the padding makes it easy to hit.
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedDelete02,
                  size: 20,
                  color: isDark ? StatusColors.errorIcon : StatusColors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
