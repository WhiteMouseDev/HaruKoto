import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../data/models/stage_model.dart';
import '../study_page.dart';
import 'serpentine_path_painter.dart';
import 'stage_node.dart';

class SerpentinePathView extends StatefulWidget {
  final List<StageModel> stages;
  final StudyCategory category;
  final String jlptLevel;
  final void Function(StageModel stage) onStageTap;

  const SerpentinePathView({
    super.key,
    required this.stages,
    required this.category,
    required this.jlptLevel,
    required this.onStageTap,
  });

  @override
  State<SerpentinePathView> createState() => _SerpentinePathViewState();
}

class _SerpentinePathViewState extends State<SerpentinePathView> {
  final _scrollController = ScrollController();

  static const _pattern = [0.5, 0.7, 0.85, 0.7, 0.5, 0.3, 0.15, 0.3];
  static const _rowHeight = 110.0;
  static const _topPad = 40.0;
  static const _bottomPad = 80.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Offset> _calculatePositions(double width) {
    return List.generate(widget.stages.length, (i) {
      final x = width * _pattern[i % _pattern.length];
      final y = _topPad + i * _rowHeight;
      return Offset(x, y);
    });
  }

  double _totalHeight() {
    return _topPad + widget.stages.length * _rowHeight + _bottomPad;
  }

  void _scrollToActive() {
    final activeIndex =
        widget.stages.indexWhere((s) => !s.isLocked && !s.isCompleted);
    if (activeIndex < 0) return;
    final targetY = _topPad + activeIndex * _rowHeight - 200;
    _scrollController.animateTo(
      targetY.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final positions = _calculatePositions(width);
        final totalHeight = _totalHeight();

        return SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 40),
          child: SizedBox(
            width: width,
            height: totalHeight,
            child: Stack(
              children: [
                // Connecting path
                CustomPaint(
                  size: Size(width, totalHeight),
                  painter: SerpentinePathPainter(
                    positions: positions,
                    stages: widget.stages,
                    completedColor:
                        AppColors.success(theme.brightness),
                    activeColor: theme.colorScheme.primary,
                    lockedColor: theme.colorScheme.onSurface
                        .withValues(alpha: 0.15),
                  ),
                ),
                // Stage nodes
                for (int i = 0; i < widget.stages.length; i++)
                  Positioned(
                    left: positions[i].dx - StageNode.nodeSize / 2,
                    top: positions[i].dy - StageNode.nodeSize / 2,
                    child: StageNode(
                      stage: widget.stages[i],
                      onTap: widget.stages[i].isLocked
                          ? null
                          : () => widget.onStageTap(widget.stages[i]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
