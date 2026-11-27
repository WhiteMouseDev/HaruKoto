import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/haru_button_styles.dart';

class ReminderTimeDialog extends StatefulWidget {
  const ReminderTimeDialog({super.key, required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<ReminderTimeDialog> createState() => _ReminderTimeDialogState();
}

class _ReminderTimeDialogState extends State<ReminderTimeDialog> {
  static const _periods = ['오전', '오후'];
  static final _hours = List.generate(12, (index) => '${index + 1}');
  static final _minutes =
      List.generate(60, (index) => index.toString().padLeft(2, '0'));

  late int _periodIndex = widget.initialTime.period.index;
  late int _hourIndex = (widget.initialTime.hour + 11) % 12;
  late int _minute = widget.initialTime.minute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final outline = light ? AppColors.redesignOutline : colors.outline;
    final actionStyle = HaruButtonStyles.primary(
      context,
      size: HaruButtonSize.regular,
    ).copyWith(
      // Center the visible Pretendard glyphs within the 48pt capsule.
      padding:
          const WidgetStatePropertyAll(EdgeInsets.fromLTRB(20, 11, 20, 13)),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: const BoxConstraints(maxWidth: 335),
      backgroundColor: light ? AppColors.lightCard : colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.sheetRadius),
      ),
      child: Semantics(
        label: '리마인더 시간 설정',
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 114,
                    child: _TimeWheel(
                      label: '오전 또는 오후',
                      values: _periods,
                      index: _periodIndex,
                      fontSize: 24,
                      selectedWeight: FontWeight.w600,
                      onChanged: (value) =>
                          setState(() => _periodIndex = value),
                    ),
                  ),
                  Expanded(
                    flex: 52,
                    child: _TimeWheel(
                      label: '시',
                      values: _hours,
                      index: _hourIndex,
                      fontSize: 36,
                      looping: true,
                      onChanged: (value) => setState(() => _hourIndex = value),
                    ),
                  ),
                  Expanded(
                    flex: 46,
                    child: ExcludeSemantics(
                      child: Center(
                        child: Text(':',
                            style: _wheelStyle(
                              36,
                              FontWeight.w500,
                              foreground,
                            )),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 50,
                    child: _TimeWheel(
                      label: '분',
                      values: _minutes,
                      index: _minute,
                      fontSize: 36,
                      looping: true,
                      onChanged: (value) => setState(() => _minute = value),
                    ),
                  ),
                  const Spacer(flex: 33),
                ],
              ),
              const SizedBox(height: AppSizes.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: actionStyle.copyWith(
                        backgroundColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        foregroundColor: WidgetStatePropertyAll(foreground),
                        side:
                            WidgetStatePropertyAll(BorderSide(color: outline)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: FilledButton(
                      style: actionStyle,
                      onPressed: () => Navigator.pop(
                        context,
                        TimeOfDay(
                          hour: (_hourIndex + 1) % 12 + _periodIndex * 12,
                          minute: _minute,
                        ),
                      ),
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _wheelStyle(double size, FontWeight weight, Color color) => TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -size * 0.025,
      color: color,
    );

class _TimeWheel extends StatefulWidget {
  const _TimeWheel({
    required this.label,
    required this.values,
    required this.index,
    required this.fontSize,
    required this.onChanged,
    this.looping = false,
    this.selectedWeight = FontWeight.w500,
  });

  final String label;
  final List<String> values;
  final int index;
  final double fontSize;
  final ValueChanged<int> onChanged;
  final bool looping;
  final FontWeight selectedWeight;

  @override
  State<_TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<_TimeWheel> {
  static const _itemHeight = 60.0;
  late final _controller =
      FixedExtentScrollController(initialItem: widget.index);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(int step) {
    _controller.animateToItem(
      _controller.selectedItem + step,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final selected =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final muted =
        light ? const Color(0xFF999999) : theme.colorScheme.onSurfaceVariant;
    final count = widget.values.length;
    final canIncrease = widget.looping || widget.index < count - 1;
    final canDecrease = widget.looping || widget.index > 0;
    final previous = (widget.index - 1) % count;
    final next = (widget.index + 1) % count;
    final children = List.generate(count, (index) {
      final active = index == widget.index;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (canDecrease && index == previous) {
            _move(-1);
          } else if (canIncrease && index == next) {
            _move(1);
          }
        },
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.values[index],
              maxLines: 1,
              style: _wheelStyle(
                widget.fontSize,
                active ? widget.selectedWeight : FontWeight.w300,
                active ? selected : muted,
              ),
            ),
          ),
        ),
      );
    });

    return Semantics(
      label: widget.label,
      value: widget.values[widget.index],
      increasedValue: canIncrease ? widget.values[next] : null,
      decreasedValue: canDecrease ? widget.values[previous] : null,
      onIncrease: canIncrease ? () => _move(1) : null,
      onDecrease: canDecrease ? () => _move(-1) : null,
      excludeSemantics: true,
      child: SizedBox(
        height: _itemHeight * 3,
        child: ListWheelScrollView.useDelegate(
          controller: _controller,
          physics: const FixedExtentScrollPhysics(),
          itemExtent: _itemHeight,
          diameterRatio: 1000,
          perspective: 0.001,
          overAndUnderCenterOpacity: 1,
          onSelectedItemChanged: widget.onChanged,
          childDelegate: widget.looping
              ? ListWheelChildLoopingListDelegate(children: children)
              : ListWheelChildListDelegate(children: children),
        ),
      ),
    );
  }
}
