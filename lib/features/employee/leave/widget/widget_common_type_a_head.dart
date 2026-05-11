import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_employees/core/const/all_design.dart';

class WidgetCommonTypeAHead<T> extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isDarkTheme;
  final bool hideOnEmpty;
  final Future<List<T>> Function(String) suggestionsCallback;
  final Widget Function(BuildContext, T) suggestionItemBuilder;
  final void Function(T) onSelected;
  final Widget Function(
    BuildContext context,
    TextEditingController controller,
    FocusNode focusNode,
  )
  fieldBuilder;

  const WidgetCommonTypeAHead({
    super.key,
    required this.label,
    required this.controller,
    required this.isDarkTheme,
    required this.hideOnEmpty,
    required this.suggestionsCallback,
    required this.suggestionItemBuilder,
    required this.onSelected,
    required this.fieldBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.color6A7282,
          ),
        ),
        const SizedBox(height: 10),
        TypeAheadField<T>(
          hideOnEmpty: hideOnEmpty,
          hideOnLoading: false,
          hideOnError: true,
          hideOnUnfocus: false,
          hideWithKeyboard: false,
          constraints: const BoxConstraints(maxHeight: 220),
          controller: controller,
          debounceDuration: const Duration(milliseconds: 100),
          suggestionsCallback: suggestionsCallback,
          onSelected: onSelected,
          builder: fieldBuilder,
          listBuilder: (context, children) {
            return FocusScope(
              canRequestFocus: false,
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: children,
              ),
            );
          },
          itemBuilder: (context, item) => suggestionItemBuilder(context, item),
          decorationBuilder: (context, child) {
            return Material(
              elevation: 1,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: child,
            );
          },
          emptyBuilder: (context) {
            return const ListTile(title: Text("No data found"));
          },
          loadingBuilder: (context) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ],
    );
  }
}
