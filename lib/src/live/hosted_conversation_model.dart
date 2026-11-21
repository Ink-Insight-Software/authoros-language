/// Calls the hosted conversation function (`companion/netlify/functions/chat.mts`).
///
/// No model key lives in the app: the function holds it. What leaves the device is the
/// prompt, which holds the author's own passages the character knows and the author's
/// message, so the app asks before using this and says so (see Settings).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/model_exception.dart';
import 'live_conversation.dart';
import 'live_prompt.dart';

class HostedConversationModel implements LiveModel {
  HostedConversationModel({
    required Uri endpoint,
    this.token,
    this.timeout = const Duration(seconds: 25),
    http.Client? client,
  }) : endpoint = _checked(endpoint),
       _client = client ?? http.Client();

  final Uri endpoint;

  /// Optional shared token the function can require, sent only in a header.
  final String? token;
  final Duration timeout;
  final http.Client _client;

  static bool _loopback(String h) =>
      h == 'localhost' || h == '127.0.0.1' || h == '::1' || h == '[::1]';

  static Uri _checked(Uri u) {
    if (u.scheme != 'https' && !(u.scheme == 'http' && _loopback(u.host))) {
      throw ArgumentError.value(u.toString(), 'endpoint', 'use https');
    }
    if (u.host.isEmpty) {
      throw ArgumentError.value(u.toString(), 'endpoint', 'no host');
    }
    return u;
  }

  @override
  Future<String> complete({
    required String system,
    required List<LiveMessage> messages,
    required int maxTokens,
  }) async {
    final http.Response r;
    try {
      r = await _client
          .post(
            endpoint,
            headers: {
              'content-type': 'application/json',
              if (token != null && token!.trim().isNotEmpty)
                'authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'system': system,
              'messages': [for (final m in messages) m.toJson()],
              'max_tokens': maxTokens,
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ModelException(ModelFailure.timedOut);
    } on Object catch (e) {
      throw ModelException(ModelFailure.unreachable, e.runtimeType.toString());
    }
    switch (r.statusCode) {
      case 200:
        break;
      case 401 || 403:
        throw const ModelException(ModelFailure.unauthorized);
      case 429:
        throw const ModelException(ModelFailure.limited);
      default:
        throw ModelException(ModelFailure.other, '${r.statusCode}');
    }
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(r.bodyBytes));
    } on Object {
      throw const ModelException(ModelFailure.other, 'unreadable reply');
    }
    if (body is Map && body['refused'] == true) {
      throw const ModelException(ModelFailure.refused);
    }
    final text = body is Map ? body['text'] : null;
    if (text is! String || text.trim().isEmpty) {
      throw const ModelException(ModelFailure.empty);
    }
    return text;
  }
}
