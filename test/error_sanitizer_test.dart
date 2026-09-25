import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jlg_mobile/core/utils/error_sanitizer.dart';

void main() {
  group('ErrorSanitizer SSI Tests', () {
    test('extractErrorMessage handles TimeoutException safely', () {
      final msg = ErrorSanitizer.extractErrorMessage(TimeoutException('timeout'));
      expect(msg, contains("délai d'attente a expiré"));
    });

    test('extractErrorMessage masks SocketException and connection refused', () {
      final msg = ErrorSanitizer.extractErrorMessage(Exception('SocketException: OS Error: Connection refused'));
      expect(msg, contains("Impossible de joindre le serveur"));
    });

    test('parseHttpResponseError masks 500 internal server errors without leaking backend stack traces', () {
      final response = http.Response('{"detail": "Internal Server Error: sqlalchemy.exc.OperationalError: server closed the connection unexpectedly"}', 500);
      final msg = ErrorSanitizer.parseHttpResponseError(response);
      expect(msg, contains("difficulté temporaire"));
      expect(msg, isNot(contains("sqlalchemy")));
      expect(msg, isNot(contains("OperationalError")));
    });

    test('sanitizeDetailString masks database tracebacks in 400 bad request responses', () {
      const dbError = 'psycopg2.errors.ForeignKeyViolation: insert or update on table violates foreign key constraint';
      final sanitized = ErrorSanitizer.sanitizeDetailString(dbError);
      expect(sanitized, "Une erreur de traitement de données est survenue sur le serveur.");
      expect(sanitized, isNot(contains("psycopg2")));
    });

    test('parseHttpResponseError preserves clean, human-readable API validation messages', () {
      final response = http.Response('{"detail": "Stock insuffisant pour ce produit"}', 400);
      final msg = ErrorSanitizer.parseHttpResponseError(response);
      expect(msg, "Stock insuffisant pour ce produit");
    });

    test('parseHttpResponseError handles 401 unauthorized gracefully', () {
      final response = http.Response('{"detail": "Invalid token"}', 401);
      final msg = ErrorSanitizer.parseHttpResponseError(response);
      expect(msg, contains("Session expirée ou identifiants invalides"));
    });

    test('parseHttpResponseError handles 403 forbidden gracefully', () {
      final response = http.Response('{"detail": "Forbidden"}', 403);
      final msg = ErrorSanitizer.parseHttpResponseError(response);
      expect(msg, contains("Accès refusé"));
    });

    test('parseHttpResponseError parses Pydantic validation error lists safely', () {
      const pydanticJson = '{"detail": [{"loc": ["body", "quantite"], "msg": "value must be greater than 0"}]}';
      final response = http.Response(pydanticJson, 422);
      final msg = ErrorSanitizer.parseHttpResponseError(response);
      expect(msg, contains("Champ 'quantite': value must be greater than 0"));
    });
  });
}
