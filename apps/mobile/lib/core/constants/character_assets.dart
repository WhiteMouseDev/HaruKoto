/// Maps character IDs/names to local asset paths.
/// Falls back to null if no local asset is available.
abstract final class CharacterAssets {
  static const _basePath = 'assets/images/characters';

  static const _assets = <String, String>{
    'haru': '$_basePath/haru-avatar.png',
    'sora': '$_basePath/sora-avatar.png',
    'yuki': '$_basePath/yuki-avatar.png',
    'kaito': '$_basePath/kaito-avatar.png',
    'mio': '$_basePath/mio-avatar.png',
    'ren': '$_basePath/ren-avatar.png',
    'aoi': '$_basePath/aoi-avatar.png',
    'riku': '$_basePath/riku-avatar.png',
  };

  /// Returns local asset path for a character name/id (case-insensitive).
  /// Returns null if no local asset exists.
  static String? pathFor(String? nameOrId) {
    if (nameOrId == null) return null;
    final key = nameOrId.toLowerCase().trim();
    // Try direct match first
    if (_assets.containsKey(key)) return _assets[key];
    // Try matching start of name (e.g. "하루" matches "haru")
    for (final entry in _assets.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
