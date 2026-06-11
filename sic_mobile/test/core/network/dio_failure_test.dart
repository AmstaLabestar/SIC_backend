import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/core/network/dio_failure.dart';

DioException _http(int status, [Object? data]) {
  final options = RequestOptions(path: '/');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: data,
    ),
  );
}

void main() {
  group('mapDioErrorToFailure', () {
    test('erreur non-Dio -> ServerFailure', () {
      expect(mapDioErrorToFailure(Exception('x')), isA<ServerFailure>());
    });

    test('timeout / connectionError -> NetworkFailure', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(mapDioErrorToFailure(e), isA<NetworkFailure>());
    });

    test('401 -> AuthFailure', () {
      expect(mapDioErrorToFailure(_http(401)), isA<AuthFailure>());
    });

    test('404 -> NotFoundFailure', () {
      expect(mapDioErrorToFailure(_http(404)), isA<NotFoundFailure>());
    });

    test('400 -> ValidationFailure avec le message du backend', () {
      final failure = mapDioErrorToFailure(_http(400, {'message': 'invalide'}));
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'invalide');
    });

    test('500 -> ServerFailure', () {
      expect(mapDioErrorToFailure(_http(500)), isA<ServerFailure>());
    });
  });
}
