import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import 'field_label.dart';
import 'login_input_decoration.dart';

class ResetPasswordView extends StatelessWidget {
  final TextEditingController resetEmailController;
  final bool loading;
  final String? resetMessage;
  final VoidCallback onResetPassword;
  final VoidCallback onBack;

  const ResetPasswordView({
    super.key,
    required this.resetEmailController,
    required this.loading,
    required this.resetMessage,
    required this.onResetPassword,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFCF6F5),
              Color(0xFFFFF0F3),
              Color(0xFFFFE4EC),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandPink
                              .withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(20),
                      child:
                          Image.asset('assets/icon.png'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(AppSizes.lg),
                    decoration: BoxDecoration(
                      color: AppColors.onGradient,
                      borderRadius: BorderRadius.circular(
                          AppSizes.cardRadius),
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
                        const Text(
                          '비밀번호 재설정',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '가입한 이메일을 입력하면 재설정 링크를 보내드립니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.overlay(0.6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const FieldLabel(text: '이메일'),
                        const SizedBox(height: 6),
                        TextField(
                          controller:
                              resetEmailController,
                          keyboardType:
                              TextInputType.emailAddress,
                          decoration:
                              loginInputDecoration(
                                  'hello@example.com'),
                        ),
                        const SizedBox(height: 16),
                        if (resetMessage != null)
                          Padding(
                            padding:
                                const EdgeInsets.only(
                                    bottom: 12),
                            child: Text(
                              resetMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    AppColors.overlay(0.6),
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: loading
                                ? null
                                : onResetPassword,
                            child: Text(
                              loading
                                  ? '발송 중...'
                                  : '재설정 링크 보내기',
                              style: const TextStyle(
                                  fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: onBack,
                          child: const Text(
                            '← 로그인으로 돌아가기',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
