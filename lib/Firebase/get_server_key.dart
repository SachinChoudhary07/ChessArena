import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';

/// Returns a short-lived OAuth2 access-token for FCM HTTP v1 API.
///
/// Loads `lib/Firebase/serverKey.json` (gitignored service account).
///
/// ⚠️ Prefer moving FCM sends to a trusted backend for production.
Future<String> generateFcmAccessToken() async {
  final jsonString =
      await rootBundle.loadString('lib/Firebase/serverKey.json');
  final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
  final credentials = ServiceAccountCredentials.fromJson(jsonMap);
  const scopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
  ];
  final client = await clientViaServiceAccount(credentials, scopes);
  final token = client.credentials.accessToken.data;
  client.close();
  return token;
}
