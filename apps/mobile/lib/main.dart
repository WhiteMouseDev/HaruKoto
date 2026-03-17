import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/constants/app_config.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/haptic_service.dart';
import 'core/services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Kakao SDK 초기화
  KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  await LocalNotificationService.initialize();
  await LocalNotificationService.requestPermission();
  await SoundService().init();
  await HapticService().init();

  if (AppConfig.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.tracesSampleRate = 0.2;
      },
      appRunner: () => runApp(
        const ProviderScope(
          child: HarukotoApp(),
        ),
      ),
    );
  } else {
    runApp(
      const ProviderScope(
        child: HarukotoApp(),
      ),
    );
  }
}
