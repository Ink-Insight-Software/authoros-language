/// A [ModelClient] for the Anthropic Messages API, called with the author's own
/// key. The key is held by the caller and sent only as the request header; this
/// class never stores, logs or returns it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'model_client.dart';

class AnthropicClient implements ModelClient {
  AnthropicClient({
    required this.apiKey,
    this.model = 'claude-haiku-5-5',
    this.timeout = const Duration(seconds: 20),
    http.Client? client,
    Uri? endpoint,
  }) : _client = client ?? http.Client(),
       endpoint =
           endpoint ?? Uri.parse('https://api.anthropic.com/v1/messages');

  /// The author's own key.
  final String apiKey;
  final String model;
  final Duration timeout;
  final Uri endpoint;
  final http.Client _client;

  @override
  String get provider => 'Anthropic';

  @override
  Future<String> complete(ModelPrompt prompt, {int maxTokens = 300}) async {
    if (apiKey.trim().isEmpty) {
      throw const ModelException(ModelFailure.unauthorized, 'no key');
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey.trim(),
              'anthropic-version': '2023-06-01',
              // The author's own key, from their own browser.
              'anthropic-dangerous-direct-browser-access': 'true',
            },
            body: jsonEncode({
              'model': model,
              'max_tokens': maxTokens,
              'system': prompt.system,
              'messages': [
                {'role': 'user', 'content': prompt.user},
              ],
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ModelException(ModelFailure.timedOut);
    } on Object catch (e) {
      throw ModelException(ModelFailure.unreachable, e.runtimeType.toString());
    }
    switch (response.statusCode) {
      case 200:
        break;
      case 401 || 403:
        throw const ModelException(ModelFailure.unauthorized);
      case 429:
        throw const ModelException(ModelFailure.limited);
      default:
        throw ModelException(ModelFailure.other, '${response.statusCode}');
    }
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final content = (body as Map)['content'];
      final text = [
        for (final block in content as List)
          if (block is Map && block['type'] == 'text') block['text'],
      ].join().trim();
      if (text.isEmpty) throw const ModelException(ModelFailure.empty);
      return text;
    } on ModelException {
      rethrow;
    } on Object {
      throw const ModelException(ModelFailure.other, 'unreadable reply');
    }
  }
}
