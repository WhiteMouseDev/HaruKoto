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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.authGradient,
        ),
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
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandPink.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset('assets/icon.png'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Phase 2: Logo wordmark
              FadeTransition(
                opacity: _logoFade,
                child: SlideTransition(
                  position: _logoSlide,
                  child: SvgPicture.asset(
                    'assets/logo-wordmark.svg',
                    width: 140,
                    colorFilter: const ColorFilter.mode(
                      AppColors.brandPink,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Phase 3: Tagline — per-character bloom fade
              AnimatedBuilder(
                animation: _taglineProgress,
                builder: (context, _) {
                  return _BloomText(
                    text: _tagline,
                    progress: _taglineProgress.value,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.overlay(0.6),
                      fontWeight: FontWeight.w400,
                    ),
                  );
                },
              ),
            ],
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
        // Each character starts and ends at a staggered time
        final charStart = i / (charCount + 5);
        final charEnd = (i + 6) / (charCount + 5);
        final t = ((progress - charStart) / (charEnd - charStart))
            .clamp(0.0, 1.0);

        // Ease the per-character progress
        final eased = Curves.easeOut.transform(t);

        return Opacity(
          opacity: eased,
          child: Transform.scale(
            scale: 0.7 + 0.3 * eased,
            child: Text(chars[i], style: style),
          ),
        );
      }),
    );
  }
}
