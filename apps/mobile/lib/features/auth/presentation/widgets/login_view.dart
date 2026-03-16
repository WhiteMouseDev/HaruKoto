import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import 'field_label.dart';
import 'login_input_decoration.dart';
import 'social_button.dart';
import 'google_logo_painter.dart';
import 'kakao_logo_painter.dart';

class LoginView extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isSignUp;
  final bool loading;
  final String? error;
  final String? info;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onKakaoSignIn;
  final VoidCallback onEmailAuth;
  final VoidCallback onToggleSignUp;
  final VoidCallback onForgotPassword;

  const LoginView({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.isSignUp,
    required this.loading,
    required this.error,
    required this.info,
    required this.onGoogleSignIn,
    required this.onKakaoSignIn,
    required this.onEmailAuth,
    required this.onToggleSignUp,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.authGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandPink.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/icon.png'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SvgPicture.asset(
                    'assets/logo-wordmark.svg',
                    width: 120,
                    colorFilter: const ColorFilter.mode(
                      AppColors.brandPink,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '매일 한 단어, 봄처럼 피어나는 나의 일본어',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.overlay(0.5),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.lg),
                    decoration: BoxDecoration(
                      color: AppColors.onGradient,
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
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
                        SocialButton(
                          onPressed: loading ? null : onGoogleSignIn,
                          icon: googleIcon(),
                          label: 'Google로 계속하기',
                        ),
                        const SizedBox(height: 10),
                        SocialButton(
                          onPressed: loading ? null : onKakaoSignIn,
                          icon: kakaoIcon(),
                          label: 'Kakao로 계속하기',
                          backgroundColor: AppColors.kakaoBg,
                          foregroundColor: AppColors.kakaoText,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                                child: Divider(
                                    color: AppColors.overlay(0.2), height: 1)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '또는',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.overlay(0.5),
                                ),
                              ),
                            ),
                            Expanded(
                                child: Divider(
                                    color: AppColors.overlay(0.2), height: 1)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const FieldLabel(text: '이메일'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: loginInputDecoration('hello@example.com'),
                        ),
                        const SizedBox(height: 12),
                        const FieldLabel(text: '비밀번호'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: loginInputDecoration('6자 이상 입력'),
                        ),
                        const SizedBox(height: 16),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.difficultyAdvanced,
                              ),
                            ),
                          ),
                        if (info != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              info!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: loading ? null : onEmailAuth,
                            child: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onGradient,
                                    ),
                                  )
                                : Text(
                                    isSignUp ? '회원가입' : '로그인',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!isSignUp)
                          GestureDetector(
                            onTap: onForgotPassword,
                            child: Text(
                              '비밀번호를 잊으셨나요?',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.overlay(0.6),
                              ),
                            ),
                          ),
                        if (!isSignUp) const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isSignUp ? '이미 계정이 있나요? ' : '계정이 없나요? ',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.overlay(0.6),
                              ),
                            ),
                            GestureDetector(
                              onTap: onToggleSignUp,
                              child: Text(
                                isSignUp ? '로그인' : '회원가입',
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
      ),
    );
  }
}
