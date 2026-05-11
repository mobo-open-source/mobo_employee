import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/const/all_design.dart';

class CommonActivityTabSelector extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool isDarkTheme;

  const CommonActivityTabSelector({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(
          tabs.length,
          (index) => _ActivityTabItem(
            text: tabs[index],
            isSelected: selectedIndex == index,
            onTap: () => onChanged(index),
            isDarkTheme: isDarkTheme,
            index: index,
          ),
        ),
      ),
    );
  }
}

class _ActivityTabItem extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkTheme;
  final int index;

  const _ActivityTabItem({
    required this.text,
    required this.isSelected,
    required this.onTap,
    required this.isDarkTheme,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('activity_tab_$index'),
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.blackColor : AppColors.colorEDEDEB,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.blackColor : AppColors.colorEDEDEB,
              width: 1,
            ),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.whiteColor : AppColors.blackColor,
            ),
          ),
        ),
      ),
    );
  }
}
