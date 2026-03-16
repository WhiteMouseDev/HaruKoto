import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Phase 1: Icon (0.0 ~ 0.4)
  late final Animation<double> _iconFade;
  late final Animation<double> _iconScale;

  // Phase 2: Logo wordmark (0.25 ~ 0.6)
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;

  // Phase 3: Tagline per-character bloom (0.45 ~ 1.0)
  late final Animation<double> _taglineProgress;

  static const _tagline = '매일 한 단어, 봄처럼 피어나는 나의 일본어';

  // Warm pink-gray for tagline (harmonizes with brand pink on light gradient)
  static const _taglineColor = Color(0xFFC4899A);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Phase 1: Icon — scale up + fade in
    _iconFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _iconScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    // Phase 2: Logo — fade in + slide up
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.6, curve: Curves.easeOut),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // Phase 3: Tagline — drives per-character bloom
    _taglineProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Responsive sizing: scale with screen width, clamped
    final iconSize = (screenWidth * 0.28).clamp(90.0, 140.0);
    final wordmarkWidth = (screenWidth * 0.35).clamp(110.0, 170.0);
    final iconRadius = iconSize * 0.23;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.authGradient,
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Phase 1: App icon
                FadeTransition(
                  opacity: _iconFade,
                  child: ScaleTransition(
                    scale: _iconScale,
                    child: Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(iconRadius),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.brandPink.withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(iconRadius),
                        child: Image.asset('assets/icon.png'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Phase 2: Logo wordmark (with subtle glow)
                FadeTransition(
                  opacity: _logoFade,
                  child: SlideTransition(
                    position: _logoSlide,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.brandPink.withValues(alpha: 0.15),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: SvgPicture.asset(
                        'assets/logo-wordmark.svg',
                        width: wordmarkWidth,
                        colorFilter: const ColorFilter.mode(
                          AppColors.brandPink,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Phase 3: Tagline — per-character bloom → single Text
                AnimatedBuilder(
                  animation: _taglineProgress,
                  builder: (context, _) {
                    final progress = _taglineProgress.value;
                    // Once animation completes, render as single Text
                    // to avoid kerning mismatch from per-character Row
                    if (progress >= 1.0) {
                      return const Text(
                        _tagline,
                        style: TextStyle(
                          fontSize: 15,
                          color: _taglineColor,
                          fontWeight: FontWeight.w400,
                        ),
                      );
                    }
                    return _BloomText(
                      text: _tagline,
                      progress: progress,
                      style: const TextStyle(
                        fontSize: 15,
                        color: _taglineColor,
                        fontWeight: FontWeight.w400,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-character bloom effect: each character fades in sequentially
/// with a slight scale-up, like petals opening.
class _BloomText extends StatelessWidget {
  final String text;
  final double progress; // 0.0 ~ 1.0
  final TextStyle? style;

  const _BloomText({
    required this.text,
    required this.progress,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final chars = text.characters.toList();
    final charCount = chars.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(charCount, (i) {
        // Wider stagger: charCount+10 for more visible per-character bloom
        final charStart = i / (charCount + 10);
        final charEnd = (i + 8) / (charCount + 10);
        final t =
            ((progress - charStart) / (charEnd - charStart)).clamp(0.0, 1.0);

        final eased = Curves.easeOut.transform(t);

        return RepaintBoundary(
          child: Opacity(
            opacity: eased,
            child: Transform.scale(
              // Stronger bloom: 0.5 → 1.0 for more visible "petal opening"
              scale: 0.5 + 0.5 * eased,
              child: Text(chars[i], style: style),
            ),
          ),
        );
      }),
    );
  }
}
