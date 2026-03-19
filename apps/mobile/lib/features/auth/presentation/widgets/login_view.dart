import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import 'falling_petals.dart';
import 'field_label.dart';
import 'login_input_decoration.dart';
import 'social_button.dart';
import 'google_logo_painter.dart';
import 'kakao_logo_painter.dart';

class LoginView extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController? confirmPasswordController;
  final bool isSignUp;
  final bool loading;
  final String? error;
  final String? info;
  final VoidCallback onAppleSignIn;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onKakaoSignIn;
  final VoidCallback onEmailAuth;
  final VoidCallback onToggleSignUp;
  final VoidCallback onForgotPassword;

  const LoginView({
    super.key,
    required this.emailController,
    required this.passwordController,
    this.confirmPasswordController,
    required this.isSignUp,
    required this.loading,
    required this.error,
    required this.info,
    required this.onAppleSignIn,
    required this.onGoogleSignIn,
    required this.onKakaoSignIn,
    required this.onEmailAuth,
    required this.onToggleSignUp,
    required this.onForgotPassword,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _showEmailForm = false;

  // Tagline color matching splash screen
  static const _taglineColor = Color(0xFFC4899A);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final iconSize = (screenWidth * 0.22).clamp(80.0, 110.0);
    final wordmarkWidth = (screenWidth * 0.30).clamp(100.0, 150.0);
    final iconRadius = iconSize * 0.23;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.authGradient,
        ),
        child: Stack(
          children: [
            // Cherry blossom petals background
            const Positioned.fill(
              child: FallingPetals(
                petalCount: 18,
                duration: Duration(milliseconds: 6000),
                loop: true,
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App icon (matching splash style)
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(iconRadius),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandPink.withValues(alpha: 0.3),
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
                      const SizedBox(height: 24),

                      // Logo wordmark with glow (matching splash)
                      Container(
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
                      const SizedBox(height: 10),
                      const Text(
                        '매일 한 단어, 봄처럼 피어나는 나의 일본어',
                        style: TextStyle(
                          fontSize: 14,
                          color: _taglineColor,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Login card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSizes.lg),
                        decoration: BoxDecoration(
                          color: AppColors.onGradient,
                          borderRadius:
                              BorderRadius.circular(AppSizes.cardRadius),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.overlay(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Error message (visible for OAuth errors too)
                            if (widget.error != null && !_showEmailForm)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  widget.error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.difficultyAdvanced,
                                  ),
                                ),
                              ),

                            // Apple Sign-In (top, black — Apple HIG)
                            SocialButton(
                              onPressed:
                                  widget.loading ? null : widget.onAppleSignIn,
                              icon: const Icon(
                                Icons.apple,
                                size: 22,
                                color: Colors.white,
                              ),
                              label: 'Apple로 계속하기',
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            const SizedBox(height: 10),

                            // Google
                            SocialButton(
                              onPressed:
                                  widget.loading ? null : widget.onGoogleSignIn,
                              icon: googleIcon(),
                              label: 'Google로 계속하기',
                            ),
                            const SizedBox(height: 10),

                            // Kakao
                            SocialButton(
                              onPressed:
                                  widget.loading ? null : widget.onKakaoSignIn,
                              icon: kakaoIcon(),
                              label: 'Kakao로 계속하기',
                              backgroundColor: AppColors.kakaoBg,
                              foregroundColor: AppColors.kakaoText,
                            ),
                            const SizedBox(height: 16),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppColors.overlay(0.15),
                                    height: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    '또는',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.overlay(0.4),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppColors.overlay(0.15),
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Email continue button (outline style)
                            if (!_showEmailForm)
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: widget.loading
                                      ? null
                                      : () =>
                                          setState(() => _showEmailForm = true),
                                  icon: Icon(
                                    Icons.email_outlined,
                                    size: 18,
                                    color: AppColors.overlay(0.6),
                                  ),
                                  label: Text(
                                    '이메일로 계속하기',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.overlay(0.7),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppColors.overlay(0.15),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),

                            // Email form (expanded)
                            if (_showEmailForm) ...[
                              const SizedBox(height: 4),
                              const FieldLabel(text: '이메일'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: widget.emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration:
                                    loginInputDecoration('hello@example.com'),
                              ),
                              const SizedBox(height: 12),
                              const FieldLabel(text: '비밀번호'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: widget.passwordController,
                                obscureText: true,
                                decoration: loginInputDecoration('6자 이상 입력'),
                              ),

                              // Confirm password (sign-up only)
                              if (widget.isSignUp &&
                                  widget.confirmPasswordController != null) ...[
                                const SizedBox(height: 12),
                                const FieldLabel(text: '비밀번호 확인'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: widget.confirmPasswordController,
                                  obscureText: true,
                                  decoration:
                                      loginInputDecoration('비밀번호를 다시 입력하세요'),
                                ),
                              ],

                              const SizedBox(height: 16),

                              // Error / Info messages
                              if (widget.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    widget.error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.difficultyAdvanced,
                                    ),
                                  ),
                                ),
                              if (widget.info != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    widget.info!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                              // Submit button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: widget.loading
                                      ? null
                                      : widget.onEmailAuth,
                                  child: widget.loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.onGradient,
                                          ),
                                        )
                                      : Text(
                                          widget.isSignUp ? '회원가입' : '로그인',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Forgot password
                              if (!widget.isSignUp)
                                GestureDetector(
                                  onTap: widget.onForgotPassword,
                                  child: Text(
                                    '비밀번호를 잊으셨나요?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.overlay(0.6),
                                    ),
                                  ),
                                ),
                              if (!widget.isSignUp) const SizedBox(height: 12),
                            ],

                            // Toggle sign-up / login
                            if (_showEmailForm)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.isSignUp
                                        ? '이미 계정이 있나요? '
                                        : '계정이 없나요? ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.overlay(0.6),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: widget.onToggleSignUp,
                                    child: Text(
                                      widget.isSignUp ? '로그인' : '회원가입',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
