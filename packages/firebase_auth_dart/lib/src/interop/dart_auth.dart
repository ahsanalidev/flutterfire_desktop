library auth_interop;

import 'dart:async';
import 'dart:developer';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:googleapis/identitytoolkit/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import 'dart_exception.dart';
import 'dart_user.dart';
import 'dart_user_credential.dart';

part 'providers.dart';

/// Pure Dart service wrapper around the Identity Platform REST API.
///
/// https://cloud.google.com/identity-platform/docs/use-rest-api
class DartAuth {
  // ignore: public_member_api_docs
  DartAuth({required this.apiKey}) {
    _client = clientViaApiKey(apiKey);
    _identityToolkit = IdentityToolkitApi(_client).relyingparty;
    _idTokenChangedController =
        StreamController<DartUser?>.broadcast(sync: true);
    _changeController = StreamController<DartUser?>.broadcast(sync: true);
  }

  /// The settings this instance is configured with.
  final String apiKey;

  late http.Client _client;

  /// The indentity toolkit API instance used to make all requests.
  late RelyingpartyResource _identityToolkit;

  // ignore: close_sinks
  StreamController<DartUser?>? _changeController;

  // ignore: close_sinks
  StreamController<DartUser?>? _idTokenChangedController;

  /// Sends events when the users sign-in state changes.
  ///
  /// If the value is `null`, there is no signed-in user.
  Stream<DartUser?> get onAuthStateChanged {
    return _changeController!.stream;
  }

  /// Sends events for changes to the signed-in user's ID token,
  /// which includes sign-in, sign-out, and token refresh events.
  ///
  /// If the value is `null`, there is no signed-in user.
  Stream<DartUser?> get onIdTokenChanged {
    return _idTokenChangedController!.stream;
  }

  /// The currently signed in user for this instance.
  DartUser? currentUser;

  /// Sign users in using email and password.
  Future<DartUserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final _response = await _identityToolkit.verifyPassword(
        IdentitytoolkitRelyingpartyVerifyPasswordRequest(
          returnSecureToken: true,
          password: password,
          email: email,
        ),
      );

      // Map the json response to an actual user.
      final user = DartUser.fromResponse(_response.toJson());

      currentUser = user;
      _changeController!.add(user);
      _idTokenChangedController!.add(user);

      final providerId = _AuthProvider.password.providerId;

      // Make a credential object based on the current sign-in method.
      return DartUserCredential(
        user: user,
        authCredential: AuthCredential(
          providerId: providerId,
          signInMethod: providerId,
        ),
        additionalUserInfo: AdditionalUserInfo(isNewUser: false),
      );
    } on DetailedApiRequestError catch (exception) {
      final authException = AuthException.fromErrorCode(exception.message);
      log('$authException', name: 'DartAuth/${authException.code}');

      throw authException;
    } catch (exception) {
      log('$exception', name: 'DartAuth');

      rethrow;
    }
  }

  /// Sign users up using email and password.
  Future<DartUserCredential> createUserWithEmailAndPassword(
      String email, String password) async {
    try {
      final _response = await _identityToolkit.signupNewUser(
        IdentitytoolkitRelyingpartySignupNewUserRequest(
          email: email,
          password: password,
        ),
      );

      final user = DartUser.fromResponse(_response.toJson());

      currentUser = user;
      _changeController!.add(user);
      _idTokenChangedController!.add(user);

      final providerId = _AuthProvider.password.providerId;

      return DartUserCredential(
        user: user,
        authCredential: AuthCredential(
          providerId: providerId,
          signInMethod: providerId,
        ),
        additionalUserInfo: AdditionalUserInfo(isNewUser: true),
      );
    } on DetailedApiRequestError catch (exception) {
      final authException = AuthException.fromErrorCode(exception.message);
      log('$authException', name: 'DartAuth/${authException.code}');

      throw authException;
    } catch (exception) {
      log('$exception', name: 'IPAuth/signUpWithEmailAndPassword');

      rethrow;
    }
  }

  /// Fetch the list of providers associated with a specified email.
  ///
  /// Throws **[AuthException]** with following codes:
  /// - `INVALID_EMAIL`: user doesn't exist
  /// - `INVALID_IDENTIFIER`: the identifier isn't a valid email
  Future<List<String>> fetchSignInMethodsForEmail(String email) async {
    try {
      final _response = await _identityToolkit.createAuthUri(
        IdentitytoolkitRelyingpartyCreateAuthUriRequest(
          identifier: email,
          continueUri: 'http://localhost:8080/app',
        ),
      );

      return _response.allProviders ?? [];
    } on DetailedApiRequestError catch (exception) {
      final authException = AuthException.fromErrorCode(exception.message);
      log('$authException', name: 'DartAuth/${authException.code}');

      throw authException;
    } catch (exception) {
      log('$exception', name: 'IPAuth/fetchSignInMethodsForEmail');

      rethrow;
    }
  }

  /// Send a password reset email.
  ///
  /// Throws **[AuthException]** with following codes:
  /// - `EMAIL_NOT_FOUND`: user doesn't exist
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      final _response = await _identityToolkit.getOobConfirmationCode(
        Relyingparty(
          email: email,
          requestType: 'PASSWORD_RESET',
        ),
      );

      return _response.email;
    } on DetailedApiRequestError catch (exception) {
      final authException = AuthException.fromErrorCode(exception.message);
      log('$authException', name: 'DartAuth/${authException.code}');

      throw authException;
    } catch (exception) {
      log('$exception', name: 'IPAuth/sendPasswordResetEmail');

      rethrow;
    }
  }
}