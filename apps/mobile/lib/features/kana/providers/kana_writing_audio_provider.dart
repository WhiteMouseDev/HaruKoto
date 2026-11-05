import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tts_service.dart';

/// Uses the existing shared player and /kana/tts contract.
final kanaWritingTtsServiceProvider =
    Provider<TtsService>((ref) => TtsService());
