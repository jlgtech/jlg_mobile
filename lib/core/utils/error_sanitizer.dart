import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Centralized utility for handling and sanitizing exceptions and API error messages.
/// Ensures strict compliance with Information Systems Security (SSI) guidelines:
/// - Never exposes internal stack traces, database details, internal IPs, or python tracebacks.
/// - Provides clear, human-readable, and secure localized error messages.
class ErrorSanitizer {
  /// Extract a safe, user-friendly error message from an HTTP response, Exception, or Error.
  static String extractErrorMessage(dynamic errorOrResponse) {
    if (errorOrResponse is http.Response) {
      return parseHttpResponseError(errorOrResponse);
    }

    if (errorOrResponse is TimeoutException) {
      return "Le délai d'attente a expiré. Veuillez vérifier votre connexion réseau.";
    }

    if (errorOrResponse is Exception || errorOrResponse is Error) {
      final str = errorOrResponse.toString().toLowerCase();
      if (str.contains('socketexception') ||
          str.contains('clientexception') ||
          str.contains('connection refused') ||
          str.contains('failed host lookup') ||
          str.contains('network is unreachable')) {
        return "Impossible de joindre le serveur. Veuillez vérifier votre connexion réseau.";
      }
      if (str.contains('formatexception') || str.contains('syntaxerror')) {
        return "Le format de la réponse serveur est invalide.";
      }
      // Never expose raw internal system details to end users
      return "Une erreur de communication est survenue. Veuillez réessayer.";
    }

    return "Une erreur inattendue est survenue.";
  }

  /// Parse HTTP response status codes and API payloads safely.
  static String parseHttpResponseError(http.Response response) {
    final status = response.statusCode;

    // 401 Unauthorized / Token Expired
    if (status == 401) {
      return "Session expirée ou identifiants invalides. Veuillez vous reconnecter.";
    }

    // 403 Forbidden
    if (status == 403) {
      return "Accès refusé. Vous n'avez pas les autorisations requises.";
    }

    // 404 Not Found
    if (status == 404) {
      return "La ressource demandée n'existe pas ou n'est plus disponible.";
    }

    // 500+ Internal Server Error / Gateway Failures
    if (status >= 500) {
      return "Le serveur rencontre une difficulté temporaire (HTTP $status). Veuillez réessayer ultérieurement.";
    }

    // Attempt to extract detail from JSON response
    try {
      if (response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final detail = data['detail'] ?? data['message'] ?? data['error'];
          if (detail != null) {
            if (detail is String) {
              return sanitizeDetailString(detail);
            } else if (detail is List && detail.isNotEmpty) {
              final first = detail.first;
              if (first is Map && first['msg'] != null) {
                final field = (first['loc'] is List && (first['loc'] as List).isNotEmpty)
                    ? (first['loc'] as List).last.toString()
                    : '';
                final msg = first['msg'].toString();
                return field.isNotEmpty ? "Champ '$field': $msg" : msg;
              }
            }
          }
        }
      }
    } catch (_) {
      // Ignore FormatException for non-JSON response bodies (e.g. 502 Bad Gateway HTML)
    }

    return "Impossible de traiter la demande (HTTP $status).";
  }

  /// Sanitize raw string details to prevent exposing database or internal backend details.
  static String sanitizeDetailString(String rawDetail) {
    final lower = rawDetail.toLowerCase();
    if (lower.contains('sqlalchemy') ||
        lower.contains('psycopg2') ||
        lower.contains('traceback') ||
        lower.contains('internal server error') ||
        lower.contains('foreign key constraint') ||
        lower.contains('unique constraint') ||
        lower.contains('operationalerror') ||
        lower.contains('syntax error') ||
        lower.contains('exception in') ||
        lower.contains('file "/')) {
      return "Une erreur de traitement de données est survenue sur le serveur.";
    }
    return rawDetail;
  }
}
