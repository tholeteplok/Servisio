import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';

/// Firebase Auth Service — handles Google Sign-In and auth state.
/// Replaces the old Google-Drive-only AuthService.
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              // ✅ SEC-CONFIG: serverClientId is required to get idToken for Firebase Auth on some platforms
              serverClientId: '791196654233-5okqrgofucg31k1hk226ns7hn3qgl5pg.apps.googleusercontent.com',
              scopes: [
                'email',
                'https://www.googleapis.com/auth/drive.appdata',
              ],
            );


  /// Stream untuk listen auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Get ID Token Result (untuk Custom Claims)
  Future<IdTokenResult?> getIdTokenResult({bool forceRefresh = false}) async {
    final user = currentUser;
    if (user == null) return null;
    return await user.getIdTokenResult(forceRefresh);
  }

  /// Get Current Role from Custom Claims
  Future<String?> getCurrentUserRole() async {
    final result = await getIdTokenResult(forceRefresh: true);
    return result?.claims?['role'] as String?;
  }

  /// Get Current BengkelId from Custom Claims
  Future<String?> getCurrentUserBengkelId() async {
    final result = await getIdTokenResult(forceRefresh: true);
    return result?.claims?['bengkelId'] as String?;
  }

  /// Legacy alias for signInWithGoogle
  Future<UserCredential?> signIn() => signInWithGoogle();

  /// Google Sign-In → Firebase Auth
  Future<UserCredential?> signInWithGoogle() async {
    try {
      appLogger.info('Initiating Google Sign-In UI...', context: 'AuthService');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Waktu habis saat mencoba masuk ke akun Google. Silakan coba lagi.'),
      );
      
      if (googleUser == null) {
        appLogger.info('Google Sign-In cancelled by user', context: 'AuthService');
        return null;
      }

      appLogger.info('Fetching Google Authentication tokens...', context: 'AuthService');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Waktu habis saat mengambil token autentikasi.'),
      );
      
      if (googleAuth.idToken == null) {
        appLogger.error('idToken is null. Potential misconfiguration in Firebase console / serverClientId.', context: 'AuthService');
        throw Exception('Gagal mendapatkan ID Token. Periksa konfigurasi Firebase (SHA-1).');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      appLogger.info('Signing into Firebase with credential...', context: 'AuthService');
      final userCredential = await _auth.signInWithCredential(credential).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Gagal menghubungi server Firebase. Periksa koneksi internet Anda.'),
      );
      
      appLogger.info('Firebase Sign-In successful', context: 'AuthService');
      return userCredential;

    } catch (e) {
      appLogger.error('Google Sign-In Error', context: 'AuthService', error: e);
      rethrow;
    }
  }

  /// ✅ FIX L-06: Silent sign-in without double prompt
  /// Returns null silently without showing any UI prompt
  /// Use [canSignInSilently] to check if silent sign-in is possible
  Future<UserCredential?> signInSilently() async {
    // 1. If already signed in to Firebase, return immediately
    if (_auth.currentUser != null) {
      appLogger.info('Silent Sign-In: Already signed in to Firebase', context: 'AuthService');
      return UserCredentialImpl(
        user: _auth.currentUser,
        credential: null,
      );
    }

    // 2. Check if Google account is available without prompting
    final canSilentSignIn = await _canSignInSilentlyInternal();
    if (!canSilentSignIn) {
      appLogger.info('Silent Sign-In: No Google account available, skipping', context: 'AuthService');
      return null;
    }

    // 3. Attempt silent sign-in
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) {
        appLogger.info('Silent Sign-In: Google signInSilently returned null', context: 'AuthService');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      appLogger.info('Silent Sign-In: Success for user ${userCredential.user?.uid}', context: 'AuthService');
      return userCredential;
    } catch (e) {
      // Silent failure - don't show any error dialog
      appLogger.debug('Silent Sign-In Error (not shown to user)', context: 'AuthService', error: e);
      return null;
    }
  }

  /// ✅ FIX L-06: Check if silent sign-in is possible without showing UI
  /// Use this before calling signInSilently to know if it will succeed
  Future<bool> canSignInSilently() async {
    // Already signed in to Firebase
    if (_auth.currentUser != null) return true;
    
    return _canSignInSilentlyInternal();
  }

  /// Internal method to check Google account availability
  /// Does NOT show any UI prompt
  Future<bool> _canSignInSilentlyInternal() async {
    try {
      // Try to get the current user from Google Sign-In
      // This will return null if user is not signed in to Google,
      // but won't show any UI prompt
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      return googleUser != null;
    } catch (e) {
      appLogger.info('canSignInSilently check failed', context: 'AuthService', error: e);
      return false;
    }
  }

  /// Sign Out — clears both Google + Firebase sessions
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Get Authenticated HTTP Client for Google APIs (Drive)
  /// Throws exception if user is not signed in, instead of auto-prompting.
  Future<http.Client> getAuthenticatedClient() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
    if (googleUser == null) {
      // ✅ Throw exception instead of auto sign-in
      throw Exception('User must be signed in to Google first. Please sign in from settings.');
    }

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw Exception('Failed to get authenticated client');
    }
    return client;
  }

  /// Explicit sign-in (triggered by user action)
  Future<GoogleSignInAccount?> explicitSignIn() async {
    return await _googleSignIn.signIn();
  }
}



/// Helper class to create UserCredential from existing user
class UserCredentialImpl implements UserCredential {
  @override
  final User? user;
  
  @override
  final AuthCredential? credential;
  
  @override
  final AdditionalUserInfo? additionalUserInfo;
  
  UserCredentialImpl({this.user, this.credential, this.additionalUserInfo});
}

