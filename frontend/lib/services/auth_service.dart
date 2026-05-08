import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps Firebase Auth. All methods return [AuthResult].
/// UI never touches FirebaseAuth directly — only calls this service.
///
/// AUTH FLOW (email/password):
///   Sign Up → creates account → sends verification email → user verifies → can log in
///   Log In  → checks emailVerified → blocks unverified accounts
///
/// PASSWORD NOTE: Plately uses Firebase's own password system.
/// The user's email password is NOT used — Firebase stores a separate
/// hashed password for the Plately app only. The email is just the identifier.
class AuthService {
  static final _auth   = FirebaseAuth.instance;
  static final _google = GoogleSignIn();

  // ── Current user ──────────────────────────────────────────────────────────
  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Email + Password sign-up ──────────────────────────────────────────────
  /// Creates account, sets display name, sends verification email.
  /// Returns ok() — user must verify email before logging in.
  static Future<AuthResult> createWithEmail(
      String name, String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user?.updateDisplayName(name.trim());

      // Send verification email — user clicks link in their inbox
      await cred.user?.sendEmailVerification();

      // Sign out immediately so they can't bypass verification
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
  /// Signs in only if the email is verified. Unverified accounts are blocked
  /// and a new verification email is sent automatically.
  static Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);

      // Reload to get latest emailVerified flag from Firebase
      await cred.user?.reload();
      final user = _auth.currentUser;

      if (user != null && !user.emailVerified) {
        // Resend verification email and block login
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
  /// Google accounts are auto-verified — no email step needed.
  static Future<AuthResult> signInWithGoogle() async {
    try {
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
    } catch (_) {
      return AuthResult.error('Google sign-in failed. Try again.');
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

  // ── Change password (re-authenticate first) ───────────────────────────────
  // Firebase requires recent authentication before sensitive operations.
  // Re-sign-in with current password, then call updatePassword.
  static Future<AuthResult> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Re-authenticate to get fresh credentials
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: currentPassword,
      );
      final user = _auth.currentUser;
      if (user == null) return AuthResult.error('No user signed in.');
      await user.reauthenticateWithCredential(credential);
      // Now update the password
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
  final String? message;  // success message for snackbar
  const AuthResult._(this.success, this.error, this.message);
  factory AuthResult.ok({String? message}) => AuthResult._(true, null, message);
  factory AuthResult.error(String msg)     => AuthResult._(false, msg, null);
}
