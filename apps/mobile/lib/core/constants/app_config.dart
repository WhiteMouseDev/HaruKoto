abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  static const kakaoNativeAppKey =
      String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

  static const googleServerClientId =
      '842843944454-stgesdh75b31fs28bi8qnkrqftv1ergv.apps.googleusercontent.com';
}
