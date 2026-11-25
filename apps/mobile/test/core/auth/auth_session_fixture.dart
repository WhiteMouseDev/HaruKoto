import 'dart:convert';

String fixtureAccessToken(String sessionId, int issuedAt,
    {String userId = 'learner'}) {
  String encode(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  final header = encode({'alg': 'HS256'});
  final claims = encode(
    {'sub': userId, 'session_id': sessionId, 'iat': issuedAt},
  );
  return '$header.$claims.AA';
}
