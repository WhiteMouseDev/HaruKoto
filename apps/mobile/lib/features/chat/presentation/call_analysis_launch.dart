import 'package:flutter/material.dart';

import '../providers/voice_call_session_provider.dart';
import 'call_analyzing_page.dart';

MaterialPageRoute<void> callAnalysisRoute(
  VoiceCallAnalysisRequest request,
) {
  return MaterialPageRoute(
    builder: (_) => CallAnalyzingPage(request: request),
  );
}

void openCallAnalysisPage(
  BuildContext context,
  VoiceCallAnalysisRequest request,
) {
  Navigator.of(context).pushReplacement(callAnalysisRoute(request));
}
