import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps Firebase Auth. All methods return [AuthResult].
/// UI never touches FirebaseAuth directly — only calls this service.
class AuthService {
  static final _auth = FirebaseAuth.instance;

  // FIX: serverClientId must be the web client (type 3) from google-services.json.
  // Without this, Google Sign-In fails on release APKs.
  static final _google = GoogleSignIn(
    scopes: ['email'],
    serverClientId: '97643516725-sgj5jvgp25l2ekclj2rg6hkfk0140i4f.apps.googleusercontent.com',
  );

  // ── Current user ──────────────────────────────────────────────────────────
  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Email + Password sign-up ──────────────────────────────────────────────
  static Future<AuthResult> createWithEmail(
      String name, String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user?.updateDisplayName(name.trim());
      await cred.user?.sendEmailVerification();
      await _auth.signOut();
      return AuthResult.ok(
        message: 'Account created! Check your inbox ($email) for a verification link, then log in.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_emailError(e.code));
    } catch (_) {
      return AuthResult.error('Something went wrong. Try again.');
    }
  }

  // ── Email + Password login ────────────────────────────────────────────────
  static Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user?.reload();
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        await _auth.signOut();
        return AuthResult.error(
          'Email not verified. A new verification link has been sent to $email.',
        );
      }
      return AuthResult.ok(message: 'Welcome back!');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_emailError(e.code));
    } catch (_) {
      return AuthResult.error('Something went wrong. Try again.');
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  static Future<AuthResult> signInWithGoogle() async {
    try {
      // NOTE: Do NOT call _google.signOut() here before signIn().
      // Pre-signout resets OAuth state mid-flow on some Android versions,
      // causing silent failures or account picker not appearing correctly.

      final googleUser = await _google.signIn();
      if (googleUser == null) return AuthResult.error('Sign-in cancelled.');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      return AuthResult.ok(message: 'Signed in with Google!');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_emailError(e.code));
    } on PlatformException catch (e) {
      // Surface the actual platform error code so it's visible in logs/debugger.
      debugPrint('Google Sign-In PlatformException: ${e.code} — ${e.message}');
      if (e.code == 'sign_in_canceled' || e.code == 'sign_in_cancelled') {
        return AuthResult.error('Sign-in cancelled.');
      }
      if (e.code == 'network_error') {
        return AuthResult.error('No internet connection.');
      }
      return AuthResult.error('Google sign-in failed (${e.code}). Try again.');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('network')) {
        return AuthResult.error('No internet connection.');
      }
      if (msg.contains('canceled') || msg.contains('cancelled')) {
        return AuthResult.error('Sign-in cancelled.');
      }
      return AuthResult.error('Google sign-in failed. Please try again.');
    }
  }

  // ── Resend verification email ─────────────────────────────────────────────
  static Future<AuthResult> resendVerificationEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user?.sendEmailVerification();
      await _auth.signOut();
      return AuthResult.ok(message: 'Verification email resent to $email.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_emailError(e.code));
    } catch (_) {
      return AuthResult.error('Could not resend email. Try again.');
    }
  }

  // ── Password reset ────────────────────────────────────────────────────────
  static Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.ok(message: 'Password reset email sent to $email.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_emailError(e.code));
    } catch (_) {
      return AuthResult.error('Could not send reset email. Try again.');
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  // ── Change password ───────────────────────────────────────────────────────
  static Future<AuthResult> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: currentPassword,
      );
      final user = _auth.currentUser;
      if (user == null) return AuthResult.error('No user signed in.');
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return AuthResult.ok(message: 'Password updated successfully.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_emailError(e.code));
    } catch (_) {
      return AuthResult.error('Could not update password. Try again.');
    }
  }

  // ── Human-readable Firebase error messages ────────────────────────────────
  static String _emailError(String code) => switch (code) {
    'user-not-found'         => 'No account found with that email.',
    'wrong-password'         => 'Incorrect password.',
    'email-already-in-use'   => 'An account already exists with that email.',
    'invalid-email'          => 'Enter a valid email address.',
    'weak-password'          => 'Password must be at least 6 characters.',
    'invalid-credential'     => 'Email or password is incorrect.',
    'user-disabled'          => 'This account has been disabled.',
    'too-many-requests'      => 'Too many attempts. Wait a moment and try again.',
    'network-request-failed' => 'No internet connection.',
    _                        => 'Authentication error. Try again.',
  };
}

/// Result wrapper — avoids try/catch in UI code.
class AuthResult {
  final bool success;
  final String? error;
  final String? message;
  const AuthResult._(this.success, this.error, this.message);
  factory AuthResult.ok({String? message}) => AuthResult._(true, null, message);
  factory AuthResult.error(String msg)     => AuthResult._(false, msg, null);
}
