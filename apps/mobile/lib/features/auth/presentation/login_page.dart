import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _isSignUp = false;
  bool _loading = false;
  bool _showResetPassword = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();

  String? _error;
  String? _info;
  String? _resetMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _error = message;
      _info = null;
    });
  }

  void _showInfo(String message) {
    setState(() {
      _info = message;
      _error = null;
    });
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithGoogle();
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Google 로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleKakaoSignIn() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithKakao();
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Kakao 로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      if (_isSignUp) {
        final response =
            await repo.signUpWithEmail(email: email, password: password);
        if (response.user != null &&
            (response.user!.identities?.isEmpty ?? false)) {
          _showError(
              '이미 가입된 이메일입니다. 소셜 로그인으로 가입하셨다면 해당 방법으로 로그인해주세요.');
        } else {
          _showInfo('확인 이메일을 발송했습니다. 이메일을 확인해주세요.');
        }
      } else {
        await repo.signInWithEmail(email: email, password: password);
      }
    } on AuthException catch (e) {
      if (mounted) {
        if (e.message.contains('Invalid login credentials') ||
            e.message.contains('invalid_credentials')) {
          _showError(
              '이메일 또는 비밀번호가 올바르지 않습니다. 소셜 로그인(Google/Kakao)으로 가입하셨다면 해당 방법으로 로그인해주세요.');
        } else if (e.message.contains('Email not confirmed')) {
          _showError('이메일 인증이 완료되지 않았습니다. 가입 시 발송된 이메일을 확인해주세요.');
        } else {
          _showError(e.message);
        }
      }
    } catch (e) {
      if (mounted) _showError('오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _resetEmailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.resetPassword(email);
      setState(
          () => _resetMessage = '비밀번호 재설정 이메일을 발송했습니다. 이메일을 확인해주세요.');
    } on AuthException catch (e) {
      setState(() => _resetMessage = e.message);
    } catch (_) {
      setState(() => _resetMessage = '오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showResetPassword) {
      return _buildResetPasswordView();
    }
    return _buildLoginView();
  }

  Widget _buildLoginView() {
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
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
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
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Social Login Buttons
                        _SocialButton(
                          onPressed: _loading ? null : _handleGoogleSignIn,
                          icon: _googleIcon(),
                          label: 'Google로 계속하기',
                        ),
                        const SizedBox(height: 10),
                        _SocialButton(
                          onPressed: _loading ? null : _handleKakaoSignIn,
                          icon: _kakaoIcon(),
                          label: 'Kakao로 계속하기',
                          backgroundColor: const Color(0xFFFEE500),
                          foregroundColor: const Color(0xFF191919),
                        ),
                        const SizedBox(height: 20),

                        // Divider "또는"
                        Row(
                          children: [
                            Expanded(
                                child: Divider(
                                    color: Colors.grey.shade300, height: 1)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '또는',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                            Expanded(
                                child: Divider(
                                    color: Colors.grey.shade300, height: 1)),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Email field
                        _buildLabel('이메일'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration('hello@example.com'),
                        ),
                        const SizedBox(height: 12),

                        // Password field
                        _buildLabel('비밀번호'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: _inputDecoration('6자 이상 입력'),
                        ),
                        const SizedBox(height: 16),

                        // Error / Info
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        if (_info != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _info!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleEmailAuth,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _isSignUp ? '회원가입' : '로그인',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Forgot password
                        if (!_isSignUp)
                          GestureDetector(
                            onTap: () {
                              _resetEmailController.text =
                                  _emailController.text;
                              setState(() {
                                _showResetPassword = true;
                                _resetMessage = null;
                              });
                            },
                            child: Text(
                              '비밀번호를 잊으셨나요?',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        if (!_isSignUp) const SizedBox(height: 12),

                        // Toggle sign up / sign in
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignUp ? '이미 계정이 있나요? ' : '계정이 없나요? ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isSignUp = !_isSignUp;
                                  _error = null;
                                  _info = null;
                                });
                              },
                              child: Text(
                                _isSignUp ? '로그인' : '회원가입',
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

  Widget _buildResetPasswordView() {
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
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandPink.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/icon.png'),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
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
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildLabel('이메일'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _resetEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration('hello@example.com'),
                        ),
                        const SizedBox(height: 16),

                        if (_resetMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _resetMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed:
                                _loading ? null : _handleResetPassword,
                            child: Text(
                              _loading ? '발송 중...' : '재설정 링크 보내기',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showResetPassword = false;
                              _resetMessage = null;
                            });
                          },
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

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  Widget _googleIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }

  Widget _kakaoIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _KakaoLogoPainter()),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.white,
          foregroundColor: foregroundColor ?? Colors.black87,
          side: BorderSide(
            color: backgroundColor != null
                ? backgroundColor!
                : Colors.grey.shade300,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    // Blue
    final bluePath = Path()
      ..moveTo(22.56 * s, 12.25 * s)
      ..cubicTo(22.56 * s, 11.47 * s, 22.49 * s, 10.72 * s, 22.36 * s,
          10.0 * s)
      ..lineTo(12 * s, 10.0 * s)
      ..lineTo(12 * s, 14.26 * s)
      ..lineTo(17.92 * s, 14.26 * s)
      ..cubicTo(17.66 * s, 15.63 * s, 16.89 * s, 16.78 * s, 15.72 * s,
          17.58 * s)
      ..lineTo(15.72 * s, 20.35 * s)
      ..lineTo(19.29 * s, 20.35 * s)
      ..cubicTo(21.37 * s, 18.43 * s, 22.56 * s, 15.61 * s, 22.56 * s,
          12.25 * s)
      ..close();
    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF4285F4));

    // Green
    final greenPath = Path()
      ..moveTo(12 * s, 23 * s)
      ..cubicTo(14.97 * s, 23 * s, 17.46 * s, 22.02 * s, 19.28 * s,
          20.34 * s)
      ..lineTo(15.71 * s, 17.57 * s)
      ..cubicTo(14.73 * s, 18.23 * s, 13.48 * s, 18.63 * s, 12 * s,
          18.63 * s)
      ..cubicTo(9.14 * s, 18.63 * s, 6.71 * s, 16.7 * s, 5.84 * s,
          14.1 * s)
      ..lineTo(2.18 * s, 14.1 * s)
      ..lineTo(2.18 * s, 16.94 * s)
      ..cubicTo(
          3.99 * s, 20.53 * s, 7.7 * s, 23 * s, 12 * s, 23 * s)
      ..close();
    canvas.drawPath(greenPath, Paint()..color = const Color(0xFF34A853));

    // Yellow
    final yellowPath = Path()
      ..moveTo(5.84 * s, 14.09 * s)
      ..cubicTo(
          5.62 * s, 13.43 * s, 5.49 * s, 12.73 * s, 5.49 * s, 12 * s)
      ..cubicTo(
          5.49 * s, 11.27 * s, 5.62 * s, 10.57 * s, 5.84 * s, 9.91 * s)
      ..lineTo(5.84 * s, 7.07 * s)
      ..lineTo(2.18 * s, 7.07 * s)
      ..cubicTo(
          1.43 * s, 8.55 * s, 1 * s, 10.22 * s, 1 * s, 12 * s)
      ..cubicTo(
          1 * s, 13.78 * s, 1.43 * s, 15.45 * s, 2.18 * s, 16.93 * s)
      ..lineTo(5.84 * s, 14.09 * s)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFFBBC05));

    // Red
    final redPath = Path()
      ..moveTo(12 * s, 5.38 * s)
      ..cubicTo(13.62 * s, 5.38 * s, 15.06 * s, 5.94 * s, 16.21 * s,
          7.02 * s)
      ..lineTo(19.36 * s, 3.87 * s)
      ..cubicTo(17.45 * s, 2.09 * s, 14.97 * s, 1 * s, 12 * s, 1 * s)
      ..cubicTo(
          7.7 * s, 1 * s, 3.99 * s, 3.47 * s, 2.18 * s, 7.07 * s)
      ..lineTo(5.84 * s, 9.91 * s)
      ..cubicTo(
          6.71 * s, 7.31 * s, 9.14 * s, 5.38 * s, 12 * s, 5.38 * s)
      ..close();
    canvas.drawPath(redPath, Paint()..color = const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KakaoLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final path = Path()
      ..moveTo(12 * s, 3 * s)
      ..cubicTo(6.48 * s, 3 * s, 2 * s, 6.48 * s, 2 * s, 10.5 * s)
      ..cubicTo(2 * s, 13.13 * s, 3.74 * s, 15.44 * s, 6.35 * s, 16.74 * s)
      ..cubicTo(6.22 * s, 17.22 * s, 5.51 * s, 19.81 * s, 5.48 * s,
          20.01 * s)
      ..cubicTo(5.48 * s, 20.01 * s, 5.46 * s, 20.09 * s, 5.52 * s,
          20.12 * s)
      ..cubicTo(5.58 * s, 20.15 * s, 5.65 * s, 20.13 * s, 5.65 * s,
          20.13 * s)
      ..cubicTo(5.82 * s, 20.11 * s, 8.8 * s, 18.05 * s, 9.29 * s,
          17.7 * s)
      ..cubicTo(10.17 * s, 17.83 * s, 11.08 * s, 17.9 * s, 12 * s,
          17.9 * s)
      ..cubicTo(17.52 * s, 17.9 * s, 22 * s, 14.42 * s, 22 * s, 10.4 * s)
      ..cubicTo(22 * s, 6.48 * s, 17.52 * s, 3 * s, 12 * s, 3 * s)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF191919));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
