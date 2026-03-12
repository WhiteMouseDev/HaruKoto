import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';

class CallAnalyzingPage extends StatefulWidget {
  const CallAnalyzingPage({super.key});

  @override
  State<CallAnalyzingPage> createState() => _CallAnalyzingPageState();
}

class _CallAnalyzingPageState extends State<CallAnalyzingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String _status = '통화 내용을 분석하고 있어요...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _startAnalysis();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    // Phase 1: Transcription
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _status = 'AI가 피드백을 생성하고 있어요...';
      _progress = 0.5;
    });

    // Phase 2: Feedback generation
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _status = '거의 다 됐어요!';
      _progress = 0.85;
    });

    // Phase 3: Complete
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _progress = 1.0;
    });

    // Navigate back (will be replaced with feedback page navigation later)
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with spinner
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.25),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 56,
                      backgroundColor: Color(0xFF1E293B),
                      child: Text('🦊', style: TextStyle(fontSize: 48)),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (_, child) => Transform.rotate(
                          angle: _controller.value * 6.28,
                          child: child,
                        ),
                        child: const Icon(
                          LucideIcons.rotateCw,
                          color: Color(0xFF34D399),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),

              // Status text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _status,
                  key: ValueKey(_status),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onGradientMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSizes.lg),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: AppColors.onGradient.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF34D399),
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.lg),

              // Progress dots
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.3, end: 1.0),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOut,
                    builder: (_, value, child) => Opacity(
                      opacity: value,
                      child: child,
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF34D399),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
