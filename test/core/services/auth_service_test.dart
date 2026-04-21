import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:servisio_core/core/services/auth_service.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late AuthService authService;
  late MockFirebaseAuth mockAuth;
  late FakeGoogleSignIn fakeGoogleSignIn;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    fakeGoogleSignIn = FakeGoogleSignIn();
    authService = AuthService(auth: mockAuth, googleSignIn: fakeGoogleSignIn);
  });

  group('AuthService', () {
    test('signInWithGoogle - success', () async {
      fakeGoogleSignIn.mockUser = FakeGoogleSignInAccount(
        email: 'test@example.com',
        id: '123',
        displayName: 'Test User',
      );

      final result = await authService.signInWithGoogle();
      
      expect(result, isNotNull);
      expect(result!.user, isNotNull);
      expect(fakeGoogleSignIn.signInCalled, isTrue);
    });

    test('signInWithGoogle - user cancelled', () async {
      fakeGoogleSignIn.mockUser = null;

      final result = await authService.signInWithGoogle();
      
      expect(result, isNull);
      expect(fakeGoogleSignIn.signInCalled, isTrue);
    });

    test('signInSilently - success', () async {
      fakeGoogleSignIn.mockUser = FakeGoogleSignInAccount(
        email: 'silent@example.com',
        id: '456',
      );

      final result = await authService.signInSilently();
      
      expect(result, isNotNull);
      expect(result!.user, isNotNull);
      expect(fakeGoogleSignIn.silentSignInCalled, isTrue);
    });

    test('signOut - calls both auth and google sign out', () async {
      await authService.signOut();
      expect(fakeGoogleSignIn.signOutCalled, isTrue);
    });

    test('canSignInSilently - returns true if firebase user exists', () async {
      // MockFirebaseAuth.signInWithCustomToken() isn't perfect, but we can just use a mock user
      final mockAuthWithUser = MockFirebaseAuth(signedIn: true);
      final serviceWithUser = AuthService(auth: mockAuthWithUser, googleSignIn: fakeGoogleSignIn);
      
      expect(await serviceWithUser.canSignInSilently(), isTrue);
    });

    test('canSignInSilently - returns true if google user exists', () async {
      fakeGoogleSignIn.mockUser = FakeGoogleSignInAccount(email: 'a@b.com', id: '1');
      expect(await authService.canSignInSilently(), isTrue);
    });
  });
}
