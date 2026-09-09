import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({required Uri baseUrl, required http.Client httpClient})
    : assert(baseUrl.hasScheme),
      _baseUrl = baseUrl,
      _httpClient = httpClient;

  final Uri _baseUrl;
  final http.Client _httpClient;

  Uri uriFor(String path, {Map<String, String> queryParameters = const {}}) {
    final base = _baseUrl.toString().endsWith('/')
        ? _baseUrl
        : Uri.parse('${_baseUrl.toString()}/');
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    final uri = base.resolve(relativePath);

    if (queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: queryParameters);
  }

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, String> queryParameters = const {},
  }) async {
    return _sendJsonRequest(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
  }) async {
    return _sendJsonRequest(method: 'POST', path: path, requestBody: body);
  }

  Future<Map<String, Object?>> deleteJson(String path) async {
    return _sendJsonRequest(method: 'DELETE', path: path);
  }

  Future<Map<String, Object?>> _sendJsonRequest({
    required String method,
    required String path,
    Map<String, String> queryParameters = const {},
    Map<String, Object?>? requestBody,
  }) async {
    final uri = uriFor(path, queryParameters: queryParameters);
    final http.Response response;

    try {
      _debugLog('api_request_start method=$method uri=$uri');
      response = await _send(method: method, uri: uri, body: requestBody);
    } catch (error) {
      _debugLog(
        'api_request_failure method=$method uri=$uri '
        'causeType=${error.runtimeType} cause=$error',
      );
      throw ApiException.network(cause: error);
    }

    _debugLog(
      'api_request_end method=$method uri=$uri statusCode=${response.statusCode}',
    );

    final body = _decodeObject(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final error = _ApiErrorBody.fromJson(body);
    throw ApiException.http(
      statusCode: response.statusCode,
      code: error.code,
      message: error.message ?? 'API request failed.',
    );
  }

  Future<http.Response> _send({
    required String method,
    required Uri uri,
    Map<String, Object?>? body,
  }) {
    final headers = {
      'accept': 'application/json',
      if (body != null) 'content-type': 'application/json',
    };

    return switch (method) {
      'GET' => _httpClient.get(uri, headers: headers),
      'POST' => _httpClient.post(uri, headers: headers, body: jsonEncode(body)),
      'DELETE' => _httpClient.delete(uri, headers: headers),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported method.'),
    };
  }

  Map<String, Object?> _decodeObject(String body) {
    if (body.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      throw const FormatException('Expected a JSON object.');
    } catch (error) {
      throw ApiException.invalidJson(cause: error);
    }
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[ApiClient] $message');
    }
  }
}

class _ApiErrorBody {
  const _ApiErrorBody({this.code, this.message});

  factory _ApiErrorBody.fromJson(Map<String, Object?> json) {
    final code = json['code'];
    final message = json['message'];

    return _ApiErrorBody(
      code: code is String ? code : null,
      message: message is String ? message : null,
    );
  }

  final String? code;
  final String? message;
}
