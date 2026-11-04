import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/api/api_error.dart';

DioException _error(Object? body) {
  final request = RequestOptions(path: '/x');
  return DioException(requestOptions: request, response: Response(requestOptions: request, statusCode: 400, data: body));
}

void main() {
  test('business-rule message is shown as is', () {
    expect(apiErrorMessage(_error({'message': 'This dam already has an open breeding record'}), 'x'), 'This dam already has an open breeding record');
  });

  test('validation errors show the details, not "Bad Request Exception"', () {
    final body = {'message': 'Bad Request Exception', 'details': ['amount must be a positive decimal string', 'expenseAccountId must be a string']};
    expect(apiErrorMessage(_error(body), 'x'), 'amount must be a positive decimal string\nexpenseAccountId must be a string');
  });

  test('a helpful message plus details shows both', () {
    final body = {'message': 'The draft is incomplete or invalid.', 'details': ['expenseAccountId must be a string']};
    expect(apiErrorMessage(_error(body), 'x'), 'The draft is incomplete or invalid.\nexpenseAccountId must be a string');
  });

  test('network errors fall back', () {
    expect(apiErrorMessage(DioException(requestOptions: RequestOptions(path: '/x')), 'Could not reach the server'), 'Could not reach the server');
    expect(apiErrorMessage(StateError('boom'), 'fallback'), 'fallback');
  });
}
