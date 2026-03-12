import 'package:flutter/material.dart';
import '../../core/constants/sizes.dart';

class AppSkeleton extends StatefulWidget {
  final int itemCount;
  final List<double>? itemHeights;

  const AppSkeleton({
    super.key,
    this.itemCount = 5,
    this.itemHeights,
  });

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultHeights = [60.0, 120.0, 120.0, 200.0, 120.0];

    return ListView(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      children: List.generate(widget.itemCount, (i) {
        final height =
            widget.itemHeights != null && i < widget.itemHeights!.length
                ? widget.itemHeights![i]
                : (i < defaultHeights.length ? defaultHeights[i] : 120.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.md),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 + 2.0 * _animation.value, 0),
                    end: Alignment(
                        -1.0 + 2.0 * _animation.value + 1.0, 0),
                    colors: [
                      theme.colorScheme.surfaceContainerHigh,
                      theme.colorScheme.surfaceContainerHigh
                          .withValues(alpha: 0.5),
                      theme.colorScheme.surfaceContainerHigh,
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
