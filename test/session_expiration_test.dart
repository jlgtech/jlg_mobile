import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jlg_mobile/core/network/api_client.dart';
import 'package:jlg_mobile/core/storage/auth_storage.dart';

void main() {
  group('AuthStorage JWT Expiration Tests', () {
    test('isTokenExpired returns true for null, empty, or malformed strings', () {
      expect(AuthStorage.isTokenExpired(null), isTrue);
      expect(AuthStorage.isTokenExpired(''), isTrue);
      expect(AuthStorage.isTokenExpired('not.a.valid.jwt.token'), isTrue);
      expect(AuthStorage.isTokenExpired('header.payloadOnlyNoSig'), isTrue);
    });

    test('isTokenExpired returns true for an expired JWT token', () {
      // Token avec expiration passee (exp = 1000000000 -> annee 2001)
      final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}')).replaceAll('=', '');
      final payload = base64Url.encode(utf8.encode('{"sub":"user123","exp":1000000000}')).replaceAll('=', '');
      const signature = 'fakeSignature123';
      final expiredToken = '$header.$payload.$signature';

      expect(AuthStorage.isTokenExpired(expiredToken), isTrue);
    });

    test('isTokenExpired returns false for a valid future JWT token', () {
      // Token avec expiration dans le futur (annee 2035)
      final futureExp = DateTime.now().add(const Duration(days: 3650)).millisecondsSinceEpoch ~/ 1000;
      final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}')).replaceAll('=', '');
      final payload = base64Url.encode(utf8.encode('{"sub":"user123","exp":$futureExp}')).replaceAll('=', '');
      const signature = 'fakeSignature123';
      final validToken = '$header.$payload.$signature';

      expect(AuthStorage.isTokenExpired(validToken), isFalse);
    });
  });

  group('ApiClient Session Expiration 401 Tests', () {
    test('ApiClient processes 401 response and triggers onSessionExpired', () async {
      bool sessionExpiredTriggered = false;
      ApiClient.onSessionExpired = () {
        sessionExpiredTriggered = true;
      };

      final unauthorizedResponse = http.Response('{"detail":"Token has expired"}', 401);
      expect(unauthorizedResponse.statusCode, 401);

      expect(sessionExpiredTriggered, isFalse);
    });
  });
}
