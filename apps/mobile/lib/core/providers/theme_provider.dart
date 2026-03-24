import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_settings_provider.dart';

final themeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(deviceSettingsProvider).themeMode,
);
