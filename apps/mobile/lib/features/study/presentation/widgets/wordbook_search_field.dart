import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';

class WordbookSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool _wrongAnswers;

  const WordbookSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  }) : _wrongAnswers = false;

  const WordbookSearchField.wrongAnswers({
    super.key,
    required this.controller,
    required this.onChanged,
  }) : _wrongAnswers = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final searchStyle = TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: 14,
      height: 1.5,
      letterSpacing: 0,
      color: light ? AppColors.redesignForeground : colors.onSurface,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_wrongAnswers ? 4 : 8),
      borderSide: BorderSide(
        color: light ? AppColors.redesignOutline : colors.outline,
      ),
    );

    return Padding(
      padding: _wrongAnswers ? EdgeInsets.zero : AppSizes.pageHorizontalEdge,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: _wrongAnswers ? searchStyle : null,
        maxLength: _wrongAnswers ? 100 : null,
        inputFormatters: [
          if (_wrongAnswers)
            TextInputFormatter.withFunction(
              (before, after) => after.text.runes.length > 100 ? before : after,
            ),
        ],
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: _wrongAnswers ? '오답을 검색해 보세요!' : '단어 검색...',
          counterText: _wrongAnswers ? '' : null,
          hintStyle: _wrongAnswers
              ? searchStyle
              : TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 13,
                  color: light
                      ? AppColors.redesignMutedForeground
                      : colors.onSurfaceVariant,
                ),
          isDense: _wrongAnswers ? true : null,
          prefixIconConstraints:
              _wrongAnswers ? const BoxConstraints.tightFor(width: 38) : null,
          prefixIcon: _wrongAnswers
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14),
                  child: Icon(
                    LucideIcons.search,
                    size: 16,
                    color: light
                        ? const Color(0xFF545461)
                        : colors.onSurfaceVariant,
                  ),
                )
              : const Icon(LucideIcons.search, size: 18),
          filled: false,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: _wrongAnswers ? 13.5 : 12,
          ),
        ),
      ),
    );
  }
}
