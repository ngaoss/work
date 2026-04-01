import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://work.deepcode.vn/api';

  print('--- Testing Login ---');
  final loginResp = await http.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': 'test@example.com', 'password': 'password123'}),
  );

  print('Status: ${loginResp.statusCode}');
  print('Body: ${loginResp.body}');

  if (loginResp.statusCode == 200) {
    final loginData = jsonDecode(loginResp.body);
    final token = loginData['token'];
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    print('\n--- Testing GET /users/me ---');
    final meResp = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: headers,
    );
    print('Body: ${meResp.body}');

    print('\n--- Testing GET /posts ---');
    final postsResp = await http.get(
      Uri.parse('$baseUrl/posts'),
      headers: headers,
    );
    print('Body: ${postsResp.body}');

    print('\n--- Testing GET /reels ---');
    final reelsResp = await http.get(
      Uri.parse('$baseUrl/reels'),
      headers: headers,
    );
    print('Body: ${reelsResp.body}');
  }
}
