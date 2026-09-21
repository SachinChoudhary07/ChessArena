import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';

/// Returns a short-lived OAuth2 access-token that can be used as the
/// `Authorization: Bearer <token>` header when calling the FCM HTTP v1 API.
///
/// This loads the `lib/Firebase/serverKey.json` service-account file that you
/// added to the project and exchanges it for an access-token with the
/// `https://www.googleapis.com/auth/firebase.messaging` scope.
///
/// ⚠️  DO **NOT** ship this code (and the JSON) in a production mobile build –
///     anyone could extract your admin credentials.  This helper is meant for
///     testing / server environments only.  In production you should move
///     message sending to a trusted backend (Cloud Functions or your server).
Future<String> generateFcmAccessToken() async {
  // 1. Load service-account JSON (ensure it is included in pubspec assets).
  final jsonString = await rootBundle.loadString('lib/Firebase/serverKey.json');
  final jsonMap = json.decode(jsonString) as Map<String, dynamic>;

  // 2. Create credentials object.
  final credentials = ServiceAccountCredentials.fromJson(jsonMap);

  // 3. Required scope for FCM.
  const scopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
  ];

  // 4. Exchange for an access-token.
  final client = await clientViaServiceAccount(credentials, scopes);
  final token = client.credentials.accessToken.data;
  client.close();

  return token; // valid ~1h
} 