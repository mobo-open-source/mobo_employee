import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';

/// Labeled text input matching the mobo design system. Used for single-line
/// fields and — with `maxLines > 1` — for description/notes fields.
class MoboFormField extends StatefulWidget {
  final String label;
  final bool isRequired;
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final dynamic prefixIcon;
  final Widget? suffixWidget;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool isDark;

  const MoboFormField({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    this.isDark = false,
    this.isRequired = false,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixWidget,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<MoboFormField> createState() => _MoboFormFieldState();
}

class _MoboFormFieldState extends State<MoboFormField> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 8),
        _buildInput(),
      ],
    );
  }

  Widget _buildLabel() {
    return Text.rich(
      TextSpan(
        text: widget.label,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: widget.isDark ? Colors.white70 : const Color(0xFF7F7F7F),
        ),
        children: widget.isRequired
            ? [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildInput() {
    final hasPrefixIcon = widget.prefixIcon != null;
    final isMultiline = widget.maxLines > 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      clipBehavior: Clip.antiAlias,
      constraints: isMultiline
          ? const BoxConstraints()
          : const BoxConstraints(minHeight: 50, maxHeight: 50),
      decoration: BoxDecoration(
        color: AppColors.inputFill(widget.isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFocused ? AppColors.appColor : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          TextFormField(
            focusNode: _focusNode,
            controller: widget.controller,
            maxLines: widget.maxLines,
            minLines: widget.maxLines > 1 ? widget.maxLines : 1,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            keyboardType: widget.maxLines > 1
                ? TextInputType.multiline
                : widget.keyboardType,
            textInputAction: widget.textInputAction,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            cursorColor: AppColors.appColor,
            textAlignVertical:
                isMultiline ? null : TextAlignVertical.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              isDense: !isMultiline,
              filled: false,
              fillColor: Colors.transparent,
              hintText: widget.hintText,
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
              prefixIcon: hasPrefixIcon
                  ? Padding(
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: HugeIcon(
                        icon: widget.prefixIcon,
                        color: widget.isDark
                            ? Colors.grey[400]!
                            : Colors.grey[600]!,
                        size: 20,
                      ),
                    )
                  : null,
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: isMultiline ? null : widget.suffixWidget,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: isMultiline
                  ? EdgeInsets.only(
                      left: hasPrefixIcon ? 0 : 16,
                      right: widget.suffixWidget != null ? 48 : 16,
                      top: 16,
                      bottom: 16,
                    )
                  : EdgeInsets.symmetric(
                      horizontal: hasPrefixIcon ? 0 : 16,
                      vertical: 12,
                    ),
            ),
            validator: widget.validator,
          ),
          if (widget.suffixWidget != null && isMultiline)
            Positioned(
              top: 0,
              right: 0,
              child: widget.suffixWidget!,
            ),
        ],
      ),
    );
  }
}
