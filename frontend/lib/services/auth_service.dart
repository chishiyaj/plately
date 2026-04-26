// Firebase Auth wrapper — Google Sign-In + Email/Password
// TODO: add firebase_auth and google_sign_in to pubspec.yaml before using

class AuthService {
  // Sign in with email + password
  // Returns null on success, error string on failure
  static Future<String?> signInEmail(String email, String password) async {
    try {
      // TODO: FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password)
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Create account with email + password
  static Future<String?> createAccount(String email, String password, String username) async {
    try {
      // TODO: FirebaseAuth.instance.createUserWithEmailAndPassword(...)
      // TODO: update displayName to username
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Google Sign-In
  static Future<String?> signInGoogle() async {
    try {
      // TODO: GoogleSignIn().signIn() then signInWithCredential
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Sign out
  static Future<void> signOut() async {
    // TODO: FirebaseAuth.instance.signOut()
  }

  // Get current user ID
  static String? get currentUserId {
    // TODO: return FirebaseAuth.instance.currentUser?.uid;
    return 'mock-user-001';
  }
}
