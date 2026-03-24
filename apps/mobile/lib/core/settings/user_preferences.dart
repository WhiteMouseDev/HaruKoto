class UserPreferences {
  const UserPreferences({
    this.showFurigana = true,
  });

  final bool showFurigana;

  UserPreferences copyWith({
    bool? showFurigana,
  }) {
    return UserPreferences(
      showFurigana: showFurigana ?? this.showFurigana,
    );
  }
}
