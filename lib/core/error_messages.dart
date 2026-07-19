import '../data/api_client.dart';

/// Central mapping from raw thrown errors to human-readable strings the
/// user should actually see. Every screen that shows a SnackBar or an
/// inline error should route through [ErrorMessages.friendly] so we
/// stop leaking things like "SocketException: Failed host lookup" or
/// "Instance of 'ApiException'".
///
/// Rules of thumb:
///   • Never show a raw Dart type name to a user.
///   • Never show a stack trace substring.
///   • For validation errors from the backend (400 responses), TRUST
///     the server's message — it was written for humans.
///   • For network / timeout / 5xx, generalise: users don't need to
///     know the exact HTTP status code, they need to know what to do
///     (retry, wait, check connection, contact support).
class ErrorMessages {
  ErrorMessages._();

  /// Returns a display-ready single-line message for any thrown error.
  static String friendly(Object? error) {
    if (error == null) return 'Something went wrong. Please try again.';

    // Our own API exceptions — richest signal available.
    if (error is ApiException) {
      return _fromApi(error);
    }

    final s = error.toString();
    final lower = s.toLowerCase();

    // ── Network / connectivity ────────────────────────────────────────
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('no address associated with hostname')) {
      return "Couldn't reach our server. Check your internet connection and try again.";
    }
    if (lower.contains('timeoutexception') ||
        lower.contains('network timeout')) {
      return 'The request is taking longer than expected. Please try again.';
    }
    if (lower.contains('clientexception') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed')) {
      return 'Network error — please try again in a moment.';
    }
    if (lower.contains('handshake') || lower.contains('certificate')) {
      return 'Secure connection failed. Please try again on a stable network.';
    }

    // ── Payment domain ────────────────────────────────────────────────
    if (lower.contains('invalid payment signature')) {
      return 'Payment verification failed. If your card was charged, please contact support with your payment ID.';
    }
    if (lower.contains('razorpay authentication failed')) {
      return "Our payment gateway isn't configured right. Please contact support.";
    }
    if (lower.contains('vehicle already exists') ||
        lower.contains('vehicle number already registered')) {
      return 'This vehicle number is already registered. If you were just charged, contact support with your payment ID for a refund.';
    }
    if (lower.contains('could not be completed in time') ||
        lower.contains('customer timed out') ||
        lower.contains('payment timed out')) {
      return 'Your UPI payment took too long to confirm. If your bank showed a debit, Razorpay will refund it within 5-7 working days.';
    }
    if (lower.contains('order not ready')) {
      return "Couldn't prepare the payment. Please try again.";
    }
    if (lower.contains('amount must be at least')) {
      return 'The payment amount is invalid. Please contact support.';
    }

    // ── Auth domain ───────────────────────────────────────────────────
    if (lower.contains('session expired')) {
      return s; // ApiClient already writes a friendly one.
    }
    if (lower.contains('no active otp') || lower.contains('otp expired')) {
      return 'This login code is no longer valid. Tap Resend to get a new one.';
    }
    if (lower.contains('too many wrong attempts')) {
      return 'Too many wrong tries. Tap Resend to request a new OTP.';
    }
    if (lower.contains('invalid otp') || lower.contains('otp must be 4 digits')) {
      return 'That code doesn\'t match. Double-check and try again.';
    }
    if (lower.contains('could not deliver otp') ||
        lower.contains('could not send otp')) {
      return "We couldn't send the OTP right now. Please try again in a moment.";
    }
    if (lower.contains('user already exists with this number')) {
      return 'This number is already registered. Please log in instead.';
    }

    // ── Form / validation ─────────────────────────────────────────────
    if (lower.contains('formatexception') ||
        lower.contains('unexpected character')) {
      return 'Received an unexpected response. Please try again.';
    }
    if (lower.contains('errors are') && lower.contains('validation')) {
      return 'Please check the highlighted fields and try again.';
    }

    // Fallback — clean up the exception prefix if present.
    return _cleanup(s);
  }

  static String _fromApi(ApiException e) {
    final code = e.statusCode ?? 0;
    final msg = e.message;
    final lower = msg.toLowerCase();

    // ApiClient already crafts "Session expired." — pass through.
    if (lower.contains('session expired')) return msg;

    // 429 (rate limit) — never show the raw copy, always ask user to slow down.
    if (code == 429) {
      return "You're doing that too fast. Please wait a moment and try again.";
    }

    // 5xx family — hide the specifics, tell the user what to do.
    if (code >= 500 && code < 600) {
      // Preserve messages that are already human-facing (e.g., the
      // Razorpay 502 wrapper).
      if (lower.contains('razorpay') || lower.contains('server is having trouble')) {
        return _cleanup(msg);
      }
      if (code == 502 || code == 503 || code == 504) {
        return 'Our server is temporarily unavailable. Please try again in a minute.';
      }
      return "Something went wrong on our side. We're looking into it — please try again.";
    }

    // 401 that made it past the AUTH_INVALID branch — treat as denied
    // rather than "log out".
    if (code == 401) {
      return msg.isEmpty ? 'Access denied. Please log in again.' : _cleanup(msg);
    }

    if (code == 403) return "You don't have permission to do that.";
    if (code == 404) return "We couldn't find what you were looking for.";

    // 400s — the backend's message was written for humans, trust it
    // but strip the "Exception:" prefix if any.
    if (code >= 400 && code < 500) {
      return _cleanup(msg.isEmpty ? 'Something isn\'t right with that request.' : msg);
    }

    return _cleanup(msg.isEmpty ? 'Something went wrong. Please try again.' : msg);
  }

  static String _cleanup(String s) {
    var out = s.trim();
    // Strip common Dart prefixes we accidentally leak.
    const prefixes = ['Exception: ', 'ApiException: ', 'FormatException: '];
    for (final p in prefixes) {
      if (out.startsWith(p)) {
        out = out.substring(p.length);
        break;
      }
    }
    if (out.isEmpty) return 'Something went wrong. Please try again.';
    // Uppercase the first letter for polish.
    if (out.isNotEmpty) {
      final first = out[0];
      if (first.toLowerCase() == first) {
        out = first.toUpperCase() + out.substring(1);
      }
    }
    // Trim trailing periods so the caller can compose with UI framing.
    // Actually — keep the period; most callers just show it as-is.
    return out;
  }
}
