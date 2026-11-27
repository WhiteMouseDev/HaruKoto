import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/haru_typography.dart';
import '../../../../shared/widgets/haru_button_styles.dart';
import '../../data/models/wordbook_entry_model.dart';

typedef WordbookEntryFields = ({
  String word,
  String reading,
  String meaningKo,
});

Future<bool> showWordbookEntryDialog(
  BuildContext context, {
  WordbookEntryModel? entry,
  required Future<void> Function(WordbookEntryFields fields) onSave,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _WordbookEntryDialog(entry: entry, onSave: onSave),
      ) ??
      false;
}

class _WordbookEntryDialog extends StatefulWidget {
  const _WordbookEntryDialog({required this.entry, required this.onSave});

  final WordbookEntryModel? entry;
  final Future<void> Function(WordbookEntryFields fields) onSave;

  @override
  State<_WordbookEntryDialog> createState() => _WordbookEntryDialogState();
}

class _WordbookEntryDialogState extends State<_WordbookEntryDialog> {
  final _form = GlobalKey<FormState>();
  late final _word = TextEditingController(text: widget.entry?.word);
  late final _reading = TextEditingController(text: widget.entry?.reading);
  late final _meaning = TextEditingController(text: widget.entry?.meaningKo);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _word.dispose();
    _reading.dispose();
    _meaning.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final word = _word.text.trim();
    final reading = _reading.text.trim();
    final fields = (
      word: word,
      reading: reading.isEmpty ? word : reading,
      meaningKo: _meaning.text.trim(),
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSave(fields);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final apiError = switch (error) {
        final ApiException exception => exception,
        final DioException exception =>
          ApiException.fromDioException(exception),
        _ => null,
      };
      final message = switch (apiError) {
        ApiException(errorCode: 'WORDBOOK_EDIT_UNAVAILABLE') =>
          '단어 수정 기능을 사용할 수 없어요. 잠시 후 다시 시도해 주세요.',
        ApiException(statusCode: 409) => '이미 단어장에 있는 단어예요.',
        ApiException(statusCode: 404) => '저장할 단어를 찾을 수 없어요.',
        ApiException(
          statusCode: null,
          errorCode: 'NETWORK_TIMEOUT' || 'NETWORK_ERROR'
        ) =>
          apiError.userMessage,
        _ => '저장하지 못했어요. 잠시 후 다시 시도해 주세요.',
      };
      setState(() {
        _error = message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.entry != null;
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final outline = light ? AppColors.redesignOutline : colors.outline;
    return PopScope<bool>(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints.tightFor(width: 335),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        titlePadding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        title: Text(
          editing ? '단어 수정' : '단어 추가',
          textAlign: TextAlign.center,
          style: HaruTypography.krTitle2.copyWith(color: foreground),
        ),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                label: '단어',
                hint: '예) 食べる',
                controller: _word,
                outline: outline,
                requiredMessage: '단어를 입력해 주세요.',
              ),
              const SizedBox(height: AppSizes.gap),
              _field(
                label: '읽기',
                hint: '예) たべる',
                controller: _reading,
                outline: outline,
              ),
              const SizedBox(height: AppSizes.gap),
              _field(
                label: '뜻',
                hint: '예) 먹다',
                controller: _meaning,
                outline: outline,
                requiredMessage: '뜻을 입력해 주세요.',
                submitField: true,
              ),
              if (_error case final error?) ...[
                const SizedBox(height: AppSizes.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: HaruTypography.krBody3.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Row(
            spacing: AppSizes.sm,
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: foreground,
                    side: BorderSide(color: outline),
                    minimumSize: const Size(0, 48),
                    shape: const StadiumBorder(),
                    textStyle: HaruTypography.krCompactButton,
                  ),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
              ),
              Expanded(
                child: FilledButton(
                  style: HaruButtonStyles.primary(
                    context,
                    size: HaruButtonSize.regular,
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '저장 중' : (editing ? '저장' : '추가')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    required Color outline,
    String? requiredMessage,
    bool submitField = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Text(label, style: HaruTypography.krBody3)),
        const SizedBox(height: AppSizes.xs),
        Semantics(
          label: label,
          child: TextFormField(
            controller: controller,
            enabled: !_saving,
            textInputAction:
                submitField ? TextInputAction.done : TextInputAction.next,
            style: HaruTypography.krBody3,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              hintText: hint,
              hintStyle: HaruTypography.krBody3,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.gap,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                borderSide: BorderSide(color: outline),
              ),
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? requiredMessage : null,
            onFieldSubmitted: submitField ? (_) => _save() : null,
          ),
        ),
      ],
    );
  }
}
