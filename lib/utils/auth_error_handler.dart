import 'package:flutter/widgets.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class AuthErrorHandler {
  static String getErrorMessage(BuildContext context, String errorCode) {
    final l10n = AppLocalizations.of(context)!;

    switch (errorCode) {
      case 'user-not-found':
        return l10n.authErrorUserNotFound;
      case 'wrong-password':
        return l10n.authErrorWrongPassword;
      case 'email-already-in-use':
        return l10n.authErrorEmailAlreadyInUse;
      case 'invalid-email':
        return l10n.authErrorInvalidEmail;
      case 'weak-password':
        return l10n.authErrorWeakPassword;
      case 'too-many-requests':
        return l10n.authErrorTooManyRequests;
      case 'generic-error':
      default:
        return l10n.authErrorGeneric;
    }
  }
}
