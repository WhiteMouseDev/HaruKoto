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

  static const _koreanNameAliases = <String, String>{
    '하루': 'haru',
    '소라': 'sora',
    '유키': 'yuki',
    '카이토': 'kaito',
    '미오': 'mio',
    '렌': 'ren',
    '아오이': 'aoi',
    '리쿠': 'riku',
  };

  /// Returns local asset path for a character name/id (case-insensitive).
  /// Returns null if no local asset exists.
  static String? pathFor(String? nameOrId) {
    if (nameOrId == null) return null;
    final raw = nameOrId.trim();
    if (raw.isEmpty) return null;
    final key = raw.toLowerCase();

    // Try direct match first
    if (_assets.containsKey(key)) return _assets[key];

    // Try Korean name -> romaji mapping.
    final alias = _koreanNameAliases[raw] ?? _koreanNameAliases[key];
    if (alias != null && _assets.containsKey(alias)) return _assets[alias];

    // Try Korean name contained in a longer display name.
    for (final entry in _koreanNameAliases.entries) {
      if (raw.contains(entry.key)) return _assets[entry.value];
    }

    // Try matching start of name (e.g. "하루" matches "haru")
    for (final entry in _assets.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
