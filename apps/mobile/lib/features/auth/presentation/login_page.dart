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
  final _confirmPasswordController = TextEditingController();
  final _resetEmailController = TextEditingController();

  String? _error;
  String? _info;
  String? _resetMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  String _friendlyAuthError(String raw) {
    if (raw.contains('Invalid login credentials') ||
        raw.contains('invalid_credentials')) {
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    }
    if (raw.contains('Email not confirmed')) {
      return '이메일 인증이 완료되지 않았습니다. 가입 시 발송된 이메일을 확인해주세요.';
    }
    if (raw.contains('Database error')) {
      return '일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }
    if (raw.contains('취소')) {
      return '로그인이 취소되었습니다.';
    }
    if (raw.contains('User already registered')) {
      return '이미 가입된 계정입니다. 다른 로그인 방법을 시도해주세요.';
    }
    // Fallback: don't expose raw error
    return '로그인에 실패했습니다. 다시 시도해주세요.';
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

  Future<void> _handleAppleSignIn() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithApple();
    } on AuthException catch (e) {
      if (mounted) _showError(_friendlyAuthError(e.message));
    } catch (e) {
      if (mounted) _showError('Apple 로그인에 실패했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithGoogle();
    } on AuthException catch (e) {
      if (mounted) _showError(_friendlyAuthError(e.message));
    } catch (e) {
      if (mounted) _showError('Google 로그인에 실패했습니다. 다시 시도해주세요.');
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
      if (mounted) _showError(_friendlyAuthError(e.message));
    } catch (e) {
      if (mounted) _showError('Kakao 로그인에 실패했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    if (_isSignUp) {
      if (password.length < 6) {
        _showError('비밀번호는 6자 이상이어야 합니다.');
        return;
      }
      final confirm = _confirmPasswordController.text;
      if (password != confirm) {
        _showError('비밀번호가 일치하지 않습니다.');
        return;
      }
    }

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
          _showError('이미 가입된 이메일입니다. 소셜 로그인으로 가입하셨다면 해당 방법으로 로그인해주세요.');
        } else {
          _showInfo('확인 이메일을 발송했습니다. 이메일을 확인해주세요.');
        }
      } else {
        await repo.signInWithEmail(email: email, password: password);
      }
    } on AuthException catch (e) {
      if (mounted) _showError(_friendlyAuthError(e.message));
    } catch (e) {
      if (mounted) _showError('로그인에 실패했습니다. 다시 시도해주세요.');
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
      setState(() => _resetMessage = '비밀번호 재설정 이메일을 발송했습니다. 이메일을 확인해주세요.');
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
      confirmPasswordController: _confirmPasswordController,
      isSignUp: _isSignUp,
      loading: _loading,
      error: _error,
      info: _info,
      onAppleSignIn: _handleAppleSignIn,
      onGoogleSignIn: _handleGoogleSignIn,
      onKakaoSignIn: _handleKakaoSignIn,
      onEmailAuth: _handleEmailAuth,
      onToggleSignUp: () {
        setState(() {
          _isSignUp = !_isSignUp;
          _error = null;
          _info = null;
          _confirmPasswordController.clear();
        });
      },
      onForgotPassword: () {
        _resetEmailController.text = _emailController.text;
        setState(() {
          _showResetPassword = true;
          _resetMessage = null;
        });
      },
    );
  }
}
