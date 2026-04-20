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

final voiceCallStartContextReaderProvider =
    Provider<VoiceCallStartContextReader>((ref) {
  return VoiceCallStartContextReader(
    readPreferences: () => ref.read(userPreferencesProvider),
    readProfile: () => ref.read(profileDetailProvider),
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
  })  : _readPreferences = readPreferences,
        _readProfile = readProfile;

  final VoiceCallPreferencesReader _readPreferences;
  final VoiceCallProfileReader _readProfile;

  VoiceCallStartContext read() {
    final preferences = _readPreferences();
    final profileAsync = _readProfile();
    final nickname = profileAsync.hasValue
        ? profileAsync.value!.profile.nickname
        : _fallbackUserNickname;

    return VoiceCallStartContext(
      callSettings: preferences.callSettings,
      userNickname: nickname,
      jlptLevel: preferences.jlptLevel,
    );
  }
}
