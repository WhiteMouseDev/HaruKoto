import 'gemini_live_audio_environment_stub.dart'
    if (dart.library.io) 'gemini_live_audio_environment_io.dart';

bool isGeminiLivePcmOutputSupported() {
  return !isIosSimulatorEnvironment();
}
