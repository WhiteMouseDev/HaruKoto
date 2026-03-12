import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import 'widgets/login_view.dart';
import 'widgets/reset_password_view.dart';

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
        final response = await repo.signUpWithEmail(
            email: email, password: password);
        if (response.user != null &&
            (response.user!.identities?.isEmpty ?? false)) {
          _showError(
              '이미 가입된 이메일입니다. 소셜 로그인으로 가입하셨다면 해당 방법으로 로그인해주세요.');
        } else {
          _showInfo('확인 이메일을 발송했습니다. 이메일을 확인해주세요.');
        }
      } else {
        await repo.signInWithEmail(
            email: email, password: password);
      }
    } on AuthException catch (e) {
      if (mounted) {
        if (e.message.contains('Invalid login credentials') ||
            e.message.contains('invalid_credentials')) {
          _showError(
              '이메일 또는 비밀번호가 올바르지 않습니다. 소셜 로그인(Google/Kakao)으로 가입하셨다면 해당 방법으로 로그인해주세요.');
        } else if (e.message
            .contains('Email not confirmed')) {
          _showError(
              '이메일 인증이 완료되지 않았습니다. 가입 시 발송된 이메일을 확인해주세요.');
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
      setState(() => _resetMessage =
          '비밀번호 재설정 이메일을 발송했습니다. 이메일을 확인해주세요.');
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
      return ResetPasswordView(
        resetEmailController: _resetEmailController,
        loading: _loading,
        resetMessage: _resetMessage,
        onResetPassword: _handleResetPassword,
        onBack: () {
          setState(() {
            _showResetPassword = false;
            _resetMessage = null;
          });
        },
      );
    }
    return LoginView(
      emailController: _emailController,
      passwordController: _passwordController,
      isSignUp: _isSignUp,
      loading: _loading,
      error: _error,
      info: _info,
      onGoogleSignIn: _handleGoogleSignIn,
      onKakaoSignIn: _handleKakaoSignIn,
      onEmailAuth: _handleEmailAuth,
      onToggleSignUp: () {
        setState(() {
          _isSignUp = !_isSignUp;
          _error = null;
          _info = null;
        });
      },
      onForgotPassword: () {
        _resetEmailController.text =
            _emailController.text;
        setState(() {
          _showResetPassword = true;
          _resetMessage = null;
        });
      },
    );
  }
}
