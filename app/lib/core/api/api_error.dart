import 'package:dio/dio.dart';

/// A message already resolved to plain text by the caller (e.g. the offline
/// outbox reporting that the server rejected a queued write) — distinct
/// from a raw [DioException] so [apiErrorMessage] can show it verbatim
/// instead of falling back to a generic message.
class AppMessageException implements Exception {
  const AppMessageException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Turns a backend error into text for the user. The API's error body is
/// `{ message, details? }` (see HttpExceptionFilter): `details` lists
/// field-level problems (validation errors, an incomplete draft). For plain
/// validation failures the top-level `message` is only "Bad Request
/// Exception", so `details` is preferred whenever it is present.
String apiErrorMessage(Object error, String fallback) {
  if (error is AppMessageException) return error.message;
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      final details = data['details'];
      final detailText = details is List ? details.whereType<String>().join('\n') : '';
      final genericMessage = message is String && RegExp(r'^[A-Za-z ]*Exception$').hasMatch(message);
      if (message is String && message.isNotEmpty && !genericMessage) {
        return detailText.isEmpty ? message : '$message\n$detailText';
      }
      if (detailText.isNotEmpty) return detailText;
      if (message is List && message.isNotEmpty) return message.join('\n');
    }
  }
  return fallback;
}
