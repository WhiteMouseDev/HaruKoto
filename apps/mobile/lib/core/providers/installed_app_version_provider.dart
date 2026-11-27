import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _versionChannel = MethodChannel('com.harukoto.app/app_version');

final installedAppVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final metadata = await _versionChannel.invokeMethod<Object?>('getVersion');
    if (metadata is! Map<Object?, Object?>) return null;
    final version = metadata['version'];
    if (version is! String || version.trim().isEmpty) return null;
    final build = metadata['buildNumber'];
    return build is String && build.trim().isNotEmpty
        ? '${version.trim()} (${build.trim()})'
        : version.trim();
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
});
