import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService();
});

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get displayName => _user?.displayName;
  String? get email => _user?.email;
  String? get photoUrl => _user?.photoURL;

  /// Initialize - listen to auth state changes
  Future<void> initialize() async {
    _user = _auth.currentUser;

    // Link existing user to RevenueCat
    if (_user != null) {
      await _linkToRevenueCat(_user!.uid);
    }

    // Listen for auth state changes
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  // Google Sign-in
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false; // User cancelled
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;

      // Link to RevenueCat
      if (_user != null) {
        await _linkToRevenueCat(_user!.uid);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = "Sign-In failed. Place try again.";
      debugPrint('[AuthService] Google sign-in error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Apple Sign-In (iOS only)
  Future<bool> signInWithApple() async {
    if (!Platform.isIOS) {
      _error = 'Apple Sign-In is only available on IOS';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Generate Nonce for security
      final rawNonce = _generateNonce();
      final nonce = _sha256OfString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        nonce: nonce
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      _user = userCredential.user;

      // Apple may provide name on first sign-in - update profile
      if (_user != null && (_user!.displayName == null || _user!.displayName!.isEmpty)) {
        final firstName = appleCredential.givenName ?? '';
        final lastName = appleCredential.familyName ?? '';
        final fullName = '$firstName $lastName'.trim();
        if (fullName.isNotEmpty) {
          await _user!.updateDisplayName(fullName);
          await _user!.reload();
          _user = _auth.currentUser;
        }
      }

      // Link to RevenueCat
      if (_user != null) {
        await _linkToRevenueCat(_user!.uid);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        _isLoading = false;
        notifyListeners();
        return false; // User cancelled
      }
      _error = 'Apple Sign-In failed.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Sign-in failed. Please try again';
      debugPrint('[AuthService] Apple sign-in error: $e');
      notifyListeners();
      return false;
    }
  }

  // Sign out from all Providers;
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    try {
      await _auth.signOut();
    }  catch (_) {}

    // Reset RevenueCat to anonymous
    if(Purchases.isConfigured) {
      try {
        await Purchases.logOut();
      } catch (_) {}
    }

    _user = null;
    _error = null;
    notifyListeners();
  }

  /// Link Firebase UID to RevenueCat for cross-device purchase sync
  Future<void> _linkToRevenueCat(String uid) async {
    if(!Purchases.isConfigured) {
      debugPrint('[AuthService] RevenueCat not configured, skipped login');
      return;
    }
    try {
      await Purchases.logIn(uid);
      debugPrint('[AuthService] Linked RevenueCat to user: $uid');
    } catch (e) {
      debugPrint('[AuthService] RevenueCat login error $e');
    }
  }

  /// Generate a random nonce for Apple Sign-In
  String _generateNonce([int length = 32]) {
    const charSet = '1234567890ABCDEFGHIJKLMNIOQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charSet[random.nextInt(charSet.length)]).join();
  }

  /// SHA256 hash for Apple Sign-In nonce
  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
