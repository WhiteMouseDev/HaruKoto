import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

const kAppUrl = 'https://app.harukoto.co.kr';
const kBrandPink = Color(0xFFFFB7C5);
const kLightBg = Color(0xFFFCF6F5);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const HarukotoApp());
}

class HarukotoApp extends StatelessWidget {
  const HarukotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '하루코토',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kBrandPink),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

/* ─────────────────────────────────────────
   Splash Screen
   ───────────────────────────────────────── */
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const WebViewScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFCF6F5), Color(0xFFFFF0F3), Color(0xFFFFE4EC)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: kBrandPink.withValues(alpha: 0.3),
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
                  const SizedBox(height: 24),
                  // App name (SVG wordmark)
                  SvgPicture.asset(
                    'assets/logo-wordmark.svg',
                    width: 140,
                    colorFilter: const ColorFilter.mode(
                      kBrandPink,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '매일 한 단어, 봄처럼 피어나는 나의 일본어',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black.withValues(alpha: 0.5),
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

/* ─────────────────────────────────────────
   WebView Screen
   ───────────────────────────────────────── */
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  Color _topColor = kLightBg;
  Color _bottomColor = kLightBg;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Color _parseHex(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      if (data['type'] == 'setTheme') {
        final top = _parseHex(data['topColor'] as String);
        final bottom = _parseHex(data['bottomColor'] as String);
        final isLight = (data['statusBar'] ?? 'dark') == 'light';

        setState(() {
          _topColor = top;
          _bottomColor = bottom;
        });
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isLight ? Brightness.light : Brightness.dark,
        ));
      }
    } catch (_) {}
  }

  /// 카카오앱 등 외부 앱 URL scheme 처리
  Future<void> _launchExternalUrl(String url) async {
    // Android intent:// URL 처리
    if (url.startsWith('intent://')) {
      // intent:// URL에서 scheme 추출하여 일반 URL로 변환
      final schemeMatch = RegExp(r'scheme=([^;]+)').firstMatch(url);
      if (schemeMatch != null) {
        final scheme = schemeMatch.group(1)!;
        final cleanUrl = url.replaceFirst('intent://', '$scheme://').split('#Intent')[0];
        final uri = Uri.parse(cleanUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      // 앱이 없으면 fallback URL로 이동
      final fallback = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(url);
      if (fallback != null) {
        final fallbackUrl = Uri.decodeFull(fallback.group(1)!);
        _controller.loadRequest(Uri.parse(fallbackUrl));
      }
      return;
    }

    // 일반 커스텀 URL scheme (kakaokompassauth://, kakaolink:// 등)
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _initWebView() {
    _controller = WebViewController(
      onPermissionRequest: (request) {
        request.grant();
      },
    )
      ..setBackgroundColor(kLightBg)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('HarukotoBridge',
          onMessageReceived: _onBridgeMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;

            // 카카오앱 등 커스텀 URL scheme 처리
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              _launchExternalUrl(url);
              return NavigationDecision.prevent;
            }

            // 앱 URL 허용
            if (url.startsWith(kAppUrl)) return NavigationDecision.navigate;
            // Supabase OAuth 허용
            if (url.contains('supabase.co')) return NavigationDecision.navigate;
            // 카카오 OAuth 허용
            if (url.contains('kakao.com')) return NavigationDecision.navigate;
            // 구글 OAuth 허용
            if (url.contains('accounts.google.com')) return NavigationDecision.navigate;
            // 포트원 + PG사 결제 허용
            if (url.contains('portone.io')) return NavigationDecision.navigate;
            if (url.contains('tosspayments.com')) return NavigationDecision.navigate;
            if (url.contains('toss.im')) return NavigationDecision.navigate;
            if (url.contains('kakaopay.com')) return NavigationDecision.navigate;
            if (url.contains('naverpay.com')) return NavigationDecision.navigate;
            if (url.contains('payco.com')) return NavigationDecision.navigate;
            if (url.contains('inicis.com')) return NavigationDecision.navigate;
            if (url.contains('nice.co.kr')) return NavigationDecision.navigate;
            if (url.contains('niceapi.co.kr')) return NavigationDecision.navigate;
            if (url.contains('samsungpay.com')) return NavigationDecision.navigate;
            if (url.contains('hanacard.co.kr')) return NavigationDecision.navigate;
            if (url.contains('shinhancard.com')) return NavigationDecision.navigate;
            if (url.contains('lottecard.co.kr')) return NavigationDecision.navigate;
            if (url.contains('hyundaicard.com')) return NavigationDecision.navigate;
            if (url.contains('kbcard.com')) return NavigationDecision.navigate;
            if (url.contains('bccard.com')) return NavigationDecision.navigate;
            if (url.contains('nhcard.co.kr')) return NavigationDecision.navigate;
            if (url.contains('citibank.co.kr')) return NavigationDecision.navigate;
            // 그 외 차단
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(kAppUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            // 상단 SafeArea 영역 (status bar)
            Container(
              color: _topColor,
              height: MediaQuery.of(context).padding.top,
            ),
            // WebView
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: kBrandPink),
                    ),
                ],
              ),
            ),
            // 하단 SafeArea 영역 (home indicator)
            Container(
              color: _bottomColor,
              height: MediaQuery.of(context).padding.bottom,
            ),
          ],
        ),
      ),
    );
  }
}
