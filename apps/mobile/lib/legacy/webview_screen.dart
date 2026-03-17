import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants/app_config.dart';
import '../core/constants/colors.dart';

const _kAppUrl = 'https://app.harukoto.co.kr';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  Color _topColor = AppColors.lightBackground;
  Color _bottomColor = AppColors.lightBackground;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: AppConfig.googleServerClientId,
  );

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
      final type = data['type'] as String?;

      if (type == 'setTheme') {
        final top = _parseHex(data['topColor'] as String);
        final bottom = _parseHex(data['bottomColor'] as String);
        final isLight = (data['statusBar'] ?? 'dark') == 'light';

        setState(() {
          _topColor = top;
          _bottomColor = bottom;
        });
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.light : Brightness.dark,
        ));
      } else if (type == 'googleSignIn') {
        _handleGoogleSignIn();
      }
    } catch (e) {
      debugPrint('[WebView] Failed to handle message: $e');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return;

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken != null) {
        unawaited(_controller.runJavaScript(
          'window.handleGoogleIdToken && window.handleGoogleIdToken("$idToken");',
        ));
      }
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    if (url.startsWith('intent://')) {
      final schemeMatch = RegExp(r'scheme=([^;]+)').firstMatch(url);
      if (schemeMatch != null) {
        final scheme = schemeMatch.group(1)!;
        final cleanUrl =
            url.replaceFirst('intent://', '$scheme://').split('#Intent')[0];
        final uri = Uri.parse(cleanUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      final fallback =
          RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(url);
      if (fallback != null) {
        final fallbackUrl = Uri.decodeFull(fallback.group(1)!);
        unawaited(_controller.loadRequest(Uri.parse(fallbackUrl)));
      }
      return;
    }

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
      ..setBackgroundColor(AppColors.lightBackground)
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

            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              _launchExternalUrl(url);
              return NavigationDecision.prevent;
            }

            if (url.startsWith(_kAppUrl)) return NavigationDecision.navigate;
            if (url.contains('supabase.co')) return NavigationDecision.navigate;
            if (url.contains('kakao.com')) return NavigationDecision.navigate;
            if (url.contains('accounts.google.com')) {
              return NavigationDecision.prevent;
            }
            if (url.contains('portone.io')) return NavigationDecision.navigate;
            if (url.contains('tosspayments.com')) {
              return NavigationDecision.navigate;
            }
            if (url.contains('toss.im')) return NavigationDecision.navigate;
            if (url.contains('kakaopay.com')) {
              return NavigationDecision.navigate;
            }
            if (url.contains('naverpay.com')) {
              return NavigationDecision.navigate;
            }
            if (url.contains('payco.com')) return NavigationDecision.navigate;
            if (url.contains('inicis.com')) return NavigationDecision.navigate;
            if (url.contains('nice.co.kr')) return NavigationDecision.navigate;
            if (url.contains('niceapi.co.kr')) {
              return NavigationDecision.navigate;
            }
            if (url.contains('samsungpay.com')) {
              return NavigationDecision.navigate;
            }
            if (url.contains('hanacard.co.kr')) {
              return NavigationDecision.navigate;
            }
            if (url.contains('shinhancard.com')) {
              return NavigationDecision.navigate;
            }
            if (url.contains('lottecard.co.kr')) {
              return NavigationDecision.navigate;
            }
            if (url.contains('hyundaicard.com')) {
              return NavigationDecision.navigate;
            }
            if (url.contains('kbcard.com')) return NavigationDecision.navigate;
            if (url.contains('bccard.com')) return NavigationDecision.navigate;
            if (url.contains('nhcard.co.kr')) {
              return NavigationDecision.navigate;
            }
            if (url.contains('citibank.co.kr')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(_kAppUrl));
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
            Container(
              color: _topColor,
              height: MediaQuery.of(context).padding.top,
            ),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.brandPink),
                    ),
                ],
              ),
            ),
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
