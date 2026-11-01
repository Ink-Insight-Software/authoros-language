/// Calls your own model server (`model/serve.py`).
///
/// The server and the token are the author's own. The token goes only in the
/// `Authorization` header; it is never put in a URL, a log or an exception. A token
/// would cross the network in the clear over plain `http`, so that is refused for
/// anything but this machine: put your own TLS in front of the server.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'chat_models.dart';
import 'model_exception.dart';

class OwnModelClient {
  OwnModelClient({
    required Uri server,
    required this.token,
    this.timeout = const Duration(seconds: 15),
    this.temperature = 0.8,
    this.maxNewTokens = 40,
    http.Client? client,
  }) : server = _checked(server),
       _client = client ?? http.Client();

  final Uri server;
  final String token;
  final Duration timeout;
  final double temperature;
  final int maxNewTokens;
  final http.Client _client;

  /// Whether `http` is acceptable for [host]: only this machine.
  static bool isLoopback(String host) =>
      host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == '[::1]';

  static Uri _checked(Uri u) {
    if (u.scheme != 'https' && !(u.scheme == 'http' && isLoopback(u.host))) {
      throw ArgumentError.value(
        u.toString(),
        'server',
        'use https, or http only for this machine: a token must not cross a '
            'network unencrypted',
      );
    }
    if (u.host.isEmpty) {
      throw ArgumentError.value(u.toString(), 'server', 'no host');
    }
    return u;
  }

  Uri _url(String path) => Uri(
    scheme: server.scheme,
    host: server.host,
    port: server.hasPort ? server.port : null,
    path: '${server.path.replaceAll(RegExp(r'/+$'), '')}$path',
  );

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    'authorization': 'Bearer $token',
  };

  /// Whether the server answers.
  Future<bool> healthy() async {
    try {
      final r = await _client.get(_url('/healthz')).timeout(timeout);
      return r.statusCode == 200;
    } on Object {
      return false;
    }
  }

  /// One line from the model for [request]. Throws [ModelException] when the server
  /// cannot give one. What it returns has not been checked: see `ChatGuard`.
  Future<String> say(ChatRequest request) async {
    if (token.trim().isEmpty) {
      throw const ModelException(ModelFailure.unauthorized, 'no token');
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            _url('/v1/say'),
            headers: _headers,
            body: jsonEncode({
              'moment': request.moment.name,
              'author': request.authorLine,
              'voice': request.tone.name,
              'length': request.length.name,
              'temperature': temperature,
              'max_new_tokens': maxNewTokens,
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
      final text = (body as Map)['text'];
      if (text is! String || text.trim().isEmpty) {
        throw const ModelException(ModelFailure.empty);
      }
      return text.trim();
    } on ModelException {
      rethrow;
    } on Object {
      throw const ModelException(ModelFailure.other, 'unreadable reply');
    }
  }

  void close() => _client.close();
}
