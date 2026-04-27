import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_preferences_provider.dart';
import '../../../core/settings/call_settings.dart';
import '../../../core/settings/user_preferences.dart';
import '../../my/data/models/profile_detail_model.dart';
import '../../my/providers/my_provider.dart';
import 'voice_call_connection_service.dart';

const _fallbackUserNickname = '학습자';
const _profileLoadTimeout = Duration(seconds: 3);

typedef VoiceCallPreferencesReader = UserPreferences Function();
typedef VoiceCallProfileReader = AsyncValue<ProfileDetailModel> Function();
typedef VoiceCallProfileFutureReader = Future<ProfileDetailModel> Function();

final voiceCallStartContextReaderProvider =
    Provider<VoiceCallStartContextReader>((ref) {
  return VoiceCallStartContextReader(
    readPreferences: () => ref.read(userPreferencesProvider),
    readProfile: () => ref.read(profileDetailProvider),
    readProfileFuture: () => ref.read(profileDetailProvider.future),
  );
});

class VoiceCallStartContext {
  const VoiceCallStartContext({
    required this.callSettings,
    required this.userNickname,
    required this.jlptLevel,
  });

  final CallSettings callSettings;
  final String userNickname;
  final String jlptLevel;

  VoiceCallConnectionInput toConnectionInput(VoiceCallSessionRequest request) {
    return VoiceCallConnectionInput(
      request: request,
      callSettings: callSettings,
      userNickname: userNickname,
      jlptLevel: jlptLevel,
    );
  }
}

class VoiceCallStartContextReader {
  const VoiceCallStartContextReader({
    required VoiceCallPreferencesReader readPreferences,
    required VoiceCallProfileReader readProfile,
    required VoiceCallProfileFutureReader readProfileFuture,
  })  : _readPreferences = readPreferences,
        _readProfile = readProfile,
        _readProfileFuture = readProfileFuture;

  final VoiceCallPreferencesReader _readPreferences;
  final VoiceCallProfileReader _readProfile;
  final VoiceCallProfileFutureReader _readProfileFuture;

  Future<VoiceCallStartContext> read() async {
    final preferences = _readPreferences();
    final profile = await _loadProfile();

    return VoiceCallStartContext(
      callSettings: profile?.callSettings ?? preferences.callSettings,
      userNickname: _normalizeNickname(profile?.nickname),
      jlptLevel: profile?.jlptLevel ?? preferences.jlptLevel,
    );
  }

  Future<ProfileInfo?> _loadProfile() async {
    final profileAsync = _readProfile();
    if (profileAsync.hasValue) {
      return profileAsync.value!.profile;
    }

    try {
      final detail = await _readProfileFuture().timeout(_profileLoadTimeout);
      return detail.profile;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  String _normalizeNickname(String? nickname) {
    final trimmed = nickname?.trim() ?? '';
    return trimmed.isEmpty ? _fallbackUserNickname : trimmed;
  }
}
