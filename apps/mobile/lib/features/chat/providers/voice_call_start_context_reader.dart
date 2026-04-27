import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_preferences_provider.dart';
import '../../../core/settings/call_settings.dart';
import '../../../core/settings/user_preferences.dart';
import '../../my/data/models/profile_detail_model.dart';
import '../../my/providers/my_provider.dart';
import 'voice_call_connection_service.dart';

const _fallbackUserNickname = '학습자';

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
    final profile = await _resolveProfile();
    final nickname = _nicknameFrom(profile);

    return VoiceCallStartContext(
      callSettings: preferences.callSettings,
      userNickname: nickname,
      jlptLevel: preferences.jlptLevel,
    );
  }

  Future<ProfileDetailModel?> _resolveProfile() async {
    final profileAsync = _readProfile();
    if (profileAsync.hasValue) {
      return profileAsync.value;
    }

    try {
      return await _readProfileFuture();
    } catch (_) {
      return null;
    }
  }

  String _nicknameFrom(ProfileDetailModel? profile) {
    final nickname = profile?.profile.nickname.trim();
    if (nickname == null || nickname.isEmpty) {
      return _fallbackUserNickname;
    }
    return nickname;
  }
}
