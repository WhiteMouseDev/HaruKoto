import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../data/models/stage_model.dart';

class StageNode extends StatefulWidget {
  static const double nodeSize = 64.0;

  final StageModel stage;
  final VoidCallback? onTap;

  const StageNode({super.key, required this.stage, this.onTap});

  @override
  State<StageNode> createState() => _StageNodeState();
}

class _StageNodeState extends State<StageNode>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  bool get _isActive => !widget.stage.isLocked && !widget.stage.isCompleted;

  @override
  void initState() {
    super.initState();
    if (_isActive) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stage = widget.stage;
    const size = StageNode.nodeSize;

    return GestureDetector(
      onTap: widget.onTap != null
          ? () {
              HapticService().light();
              widget.onTap!();
            }
          : null,
      child: SizedBox(
        width: size + 20, // extra for glow + label
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Node circle
            SizedBox(
              width: size + 16, // room for pulse glow
              height: size + 16,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse ring (active only)
                  if (_isActive && _pulseController != null)
                    AnimatedBuilder(
                      animation: _pulseController!,
                      builder: (context, child) {
                        return Container(
                          width: size + 12 * _pulseController!.value,
                          height: size + 12 * _pulseController!.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                  alpha:
                                      0.3 * (1 - _pulseController!.value)),
                              width: 3,
                            ),
                          ),
                        );
                      },
                    ),
                  // Main circle
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _bgColor(theme),
                      boxShadow: _isActive
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(child: _buildContent(theme)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Stage title
            Text(
              stage.title,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    _isActive ? FontWeight.w600 : FontWeight.normal,
                color: stage.isLocked
                    ? theme.colorScheme.onSurface
                        .withValues(alpha: 0.3)
                    : theme.colorScheme.onSurface
                        .withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _bgColor(ThemeData theme) {
    if (widget.stage.isLocked) {
      return theme.colorScheme.surfaceContainerHigh;
    }
    if (widget.stage.isCompleted) {
      return AppColors.success(theme.brightness);
    }
    return theme.colorScheme.primary;
  }

  Widget _buildContent(ThemeData theme) {
    if (widget.stage.isLocked) {
      return Icon(LucideIcons.lock,
          size: 22,
          color:
              theme.colorScheme.onSurface.withValues(alpha: 0.3));
    }
    if (widget.stage.isCompleted) {
      return const Icon(LucideIcons.check,
          size: 28, color: Colors.white);
    }
    // Active
    return Text(
      '${widget.stage.stageNumber}',
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}
