class AppUser {
  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
  });
}
