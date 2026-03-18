import 'package:flutter/material.dart';
import '../../../../core/constants/sizes.dart';

class HomeSkeleton extends StatefulWidget {
  const HomeSkeleton({super.key});

  @override
  State<HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<HomeSkeleton>
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

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // 1. Header skeleton (greeting + bell)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmer(theme, width: 80, height: 16),
                    const SizedBox(height: 6),
                    _shimmer(theme, width: 140, height: 22),
                  ],
                ),
              ),
              _shimmerCircle(theme, size: 44),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),

        // 2. Streak card skeleton
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pageHorizontal,
          ),
          child: _shimmerCard(theme, height: 100),
        ),
        const SizedBox(height: AppSizes.md),

        // 3. Quick start card skeleton (taller)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pageHorizontal,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _shimmerCard(theme, height: 260)),
              const SizedBox(width: 0),
              _shimmerCard(theme, width: 52, height: 156, radius: 12),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),

        // 4. Weekly chart skeleton
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pageHorizontal,
          ),
          child: _shimmerCard(theme, height: 200),
        ),
        const SizedBox(height: AppSizes.md),

        // 5. Shortcut grid skeleton
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pageHorizontal,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              4,
              (_) => Column(
                children: [
                  _shimmerRoundedRect(theme, size: 52),
                  const SizedBox(height: 8),
                  _shimmer(theme, width: 40, height: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmer(
    ThemeData theme, {
    required double width,
    required double height,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _animation.value, 0),
              end: Alignment(-1.0 + 2.0 * _animation.value + 1.0, 0),
              colors: [
                theme.colorScheme.surfaceContainerHigh,
                theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                theme.colorScheme.surfaceContainerHigh,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _shimmerCircle(ThemeData theme, {required double size}) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _animation.value, 0),
              end: Alignment(-1.0 + 2.0 * _animation.value + 1.0, 0),
              colors: [
                theme.colorScheme.surfaceContainerHigh,
                theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                theme.colorScheme.surfaceContainerHigh,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _shimmerRoundedRect(ThemeData theme, {required double size}) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _animation.value, 0),
              end: Alignment(-1.0 + 2.0 * _animation.value + 1.0, 0),
              colors: [
                theme.colorScheme.surfaceContainerHigh,
                theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                theme.colorScheme.surfaceContainerHigh,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _shimmerCard(
    ThemeData theme, {
    double? width,
    required double height,
    double radius = AppSizes.cardRadius,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _animation.value, 0),
              end: Alignment(-1.0 + 2.0 * _animation.value + 1.0, 0),
              colors: [
                theme.colorScheme.surfaceContainerHigh,
                theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                theme.colorScheme.surfaceContainerHigh,
              ],
            ),
          ),
        );
      },
    );
  }
}
