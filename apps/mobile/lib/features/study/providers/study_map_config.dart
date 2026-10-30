import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set to false to restore the previous list on both learning surfaces.
/// Presentation only: no environment, API, or stored progress changes.
const studyMapEnabled = true;

final studyMapEnabledProvider = Provider<bool>((ref) => studyMapEnabled);
