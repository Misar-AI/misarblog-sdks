import "dart:convert";
import "package:http/http.dart" as http;

class TokenResult {
  final String token;
  final int expiresAt;

  const TokenResult({required this.token, required this.expiresAt});

  factory TokenResult.fromJson(Map<String, dynamic> json) =>
      TokenResult(token: json["token"] as String, expiresAt: json["expiresAt"] as int);
}

Future<TokenResult> refreshToken(String token, {String baseUrl = "https://misar.blog"}) async {
  final response = await http.post(
    Uri.parse("$baseUrl/api/auth/refresh"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"token": token}),
  );
  if (response.statusCode != 200) {
    throw Exception("Refresh failed: ${response.statusCode}");
  }
  return TokenResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
}
